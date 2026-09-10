#!/usr/bin/env python3
"""Retrieve the curated radical-denesting bibliography, preserving provenance.

Python 3.9+; standard library only. No credentials, paid services, or external
programs are needed. This script downloads explicit manifest URLs; it does not
claim to find every open copy on the internet. Unresolved citations remain in
the index. PDF/source pairs from arXiv use the same pinned version.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import csv
import gzip
import hashlib
import html
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import sys
import tarfile
import threading
import time
from typing import Any
import urllib.error
import urllib.parse
import urllib.request
import zipfile

MAX_BYTES = 150 * 1024 * 1024
MAX_EXPANDED_BYTES = 300 * 1024 * 1024
MAX_MEMBERS = 5000
USER_AGENT = 'RadicalBibliographyFetcher/1.0 (personal scholarly literature retrieval)'


def utc_now() -> str:
    return time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + '.partial')
    temp.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding='utf-8')
    os.replace(temp, path)


def safe_path(root: Path, name: str) -> Path:
    """Reject traversal, symlink escapes and Windows-specific path tricks."""
    if '\\' in name or ':' in name or '\x00' in name:
        raise ValueError(f'Unsafe path: {name!r}')
    rel = PurePosixPath(name)
    if rel.is_absolute() or '..' in rel.parts:
        raise ValueError(f'Unsafe path: {name!r}')
    result = root.joinpath(*rel.parts)
    try:
        result.resolve().relative_to(root.resolve())
    except ValueError:
        raise ValueError(f'Path escapes output directory: {name!r}')
    return result


def is_pdf(data: bytes) -> bool:
    head = data[:1024].lstrip()
    return head.startswith(b'%PDF-') and b'%%EOF' in data[-8192:]


def tex_like(data: bytes) -> bool:
    return bool(re.search(rb'\\(?:documentclass|documentstyle|begin\{document\}|input|def|newcommand)', data[:262144]))


def html_error(data: bytes, final_url: str) -> bool:
    text = data[:30000].decode('utf-8', errors='replace')
    m = re.search(r'<title[^>]*>(.*?)</title>', text, re.I | re.S)
    title = re.sub('<[^>]+>', '', m.group(1)).lower() if m else ''
    return any(s in title for s in ('access denied', 'just a moment', 'captcha', '403 forbidden', '404 not found'))


class Client:
    def __init__(self, timeout: float, retries: int, delay: float = 0.35):
        self.timeout, self.retries, self.delay = timeout, retries, delay
        self._guard = threading.Lock()
        self._hosts: dict[str, tuple[threading.Lock, float]] = {}

    def get(self, url: str) -> tuple[bytes, str, str]:
        parsed = urllib.parse.urlsplit(url)
        if parsed.scheme not in ('http', 'https') or parsed.username or parsed.password:
            raise ValueError('Only credential-free HTTP(S) URLs are allowed')
        host = (parsed.hostname or '').lower()
        if not host:
            raise ValueError('Missing hostname')
        with self._guard:
            lock = self._hosts.setdefault(host, (threading.Lock(), 0.0))[0]
        last_error: Exception = RuntimeError('No request was made')
        for attempt in range(self.retries + 1):
            try:
                # Keep requests to a given host serialized and conservatively paced.
                with lock:
                    pause = 3.1 if host.endswith('arxiv.org') else self.delay
                    with self._guard:
                        previous = self._hosts[host][1]
                    time.sleep(max(0.0, previous + pause - time.monotonic()))
                    request = urllib.request.Request(url, headers={
                        'User-Agent': USER_AGENT,
                        'Accept': 'application/pdf,application/x-tar,application/gzip,text/plain,text/html,*/*',
                        'Accept-Encoding': 'identity',
                    })
                    try:
                        with urllib.request.urlopen(request, timeout=self.timeout) as response:
                            size = response.headers.get('Content-Length')
                            if size and int(size) > MAX_BYTES:
                                raise ValueError('Response exceeds the configured size limit')
                            chunks, total = [], 0
                            while True:
                                chunk = response.read(128 * 1024)
                                if not chunk:
                                    break
                                total += len(chunk)
                                if total > MAX_BYTES:
                                    raise ValueError('Response exceeds the configured size limit')
                                chunks.append(chunk)
                            return b''.join(chunks), response.geturl(), response.headers.get('Content-Type', '')
                    finally:
                        with self._guard:
                            self._hosts[host] = (lock, time.monotonic())
            except Exception as exc:
                last_error = exc
                if isinstance(exc, urllib.error.HTTPError) and exc.code in (401, 403, 404, 410):
                    break
                if attempt < self.retries:
                    time.sleep(min(2 ** attempt, 8))
        raise last_error


def store_bytes(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.partial')
    temporary.write_bytes(data)
    os.replace(temporary, path)


def unpack_source(data: bytes, base: Path, source_directory: Path) -> dict[str, Any]:
    """Keep the untouched submission and safely unpack actual source files.

    arXiv source endpoints may return a tar archive, a gzipped TeX file, plain
    TeX, or a PDF-only submission. A PDF is never relabeled as a .tex file.
    Nothing in an archive is executed and symbolic/hard links are rejected.
    """
    if is_pdf(data):
        path = base.with_name(base.name + '.pdf')
        store_bytes(path, data)
        return {'path': path, 'source_kind': 'pdf_only', 'tex_count': 0, 'extracted_files': []}
    members: list[tuple[str, bytes]] = []
    compressed = data.startswith(b'\x1f\x8b')
    try:
        tf = tarfile.open(fileobj=io.BytesIO(data), mode='r:*')
    except tarfile.ReadError:
        tf = None
    if tf is not None:
        total = 0
        with tf:
            for n, entry in enumerate(tf):
                if n >= MAX_MEMBERS:
                    raise ValueError('Source archive contains too many members')
                safe_path(source_directory, entry.name)
                if entry.isdir():
                    continue
                if not entry.isfile():
                    raise ValueError('Source archive contains a link or special file')
                total += entry.size
                if total > MAX_EXPANDED_BYTES:
                    raise ValueError('Expanded source archive exceeds size limit')
                stream = tf.extractfile(entry)
                if stream is None:
                    raise ValueError('Could not read source archive member')
                payload = stream.read(entry.size + 1)
                if len(payload) != entry.size:
                    raise ValueError('Truncated source archive member')
                members.append((entry.name, payload))
        suffix, kind = ('.tar.gz', 'tar_gzip') if compressed else ('.tar', 'tar')
    elif zipfile.is_zipfile(io.BytesIO(data)):
        total = 0
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            entries = z.infolist()
            if len(entries) > MAX_MEMBERS:
                raise ValueError('Source ZIP contains too many members')
            for entry in entries:
                safe_path(source_directory, entry.filename)
                if entry.is_dir():
                    continue
                if (entry.external_attr >> 16) & 0o170000 == 0o120000:
                    raise ValueError('Source ZIP contains a symbolic link')
                total += entry.file_size
                if total > MAX_EXPANDED_BYTES:
                    raise ValueError('Expanded source ZIP exceeds size limit')
                members.append((entry.filename, z.read(entry)))
        suffix, kind = '.zip', 'zip'
    else:
        plain = data
        if compressed:
            with gzip.GzipFile(fileobj=io.BytesIO(data)) as gz:
                plain = gz.read(MAX_EXPANDED_BYTES + 1)
            if len(plain) > MAX_EXPANDED_BYTES:
                raise ValueError('Expanded source exceeds size limit')
        if not tex_like(plain):
            raise ValueError('Source response is neither a TeX file nor a recognized source archive')
        members = [('main.tex', plain)]
        suffix, kind = ('.tex.gz', 'gzip_tex') if compressed else ('.tex', 'plain_tex')
    # Archive paths and member sizes were checked before writing anything.
    path = base.with_name(base.name + suffix)
    store_bytes(path, data)
    extracted = []
    for name, content in members:
        target = safe_path(source_directory, name)
        store_bytes(target, content)
        extracted.append(str(target))
    return {'path': path, 'source_kind': kind,
            'tex_count': sum(name.lower().endswith('.tex') for name, _ in members),
            'extracted_files': extracted}


def validate(data: bytes, role: str, final_url: str) -> None:
    if not data:
        raise ValueError('Empty response')
    if role == 'pdf' and not is_pdf(data):
        raise ValueError('Not a complete PDF (possibly a login, error or anti-bot page)')
    if role == 'tex' and not tex_like(data):
        raise ValueError('Not a recognizable TeX source')
    if role == 'html' and html_error(data, final_url):
        raise ValueError('Server returned an error or anti-bot HTML page')
    if role == 'text' and data[:2048].lstrip().lower().startswith((b'<!doctype html', b'<html')):
        raise ValueError('Expected a source/text file but received HTML')


def asset_key(item_id: str, asset: dict[str, Any]) -> str:
    return item_id + '::' + asset['filename']


def run_asset(root: Path, item: dict[str, Any], asset: dict[str, Any], client: Client,
              prior: dict[str, Any]) -> dict[str, Any]:
    area = 'papers' if item['kind'] == 'literature' else 'web_resources'
    destdir = safe_path(root / area, item['folder'])
    requested_path = safe_path(destdir, asset['filename'])
    old = prior.get(asset_key(item['id'], asset), {})
    if old.get('ok') and old.get('path'):
        existing = safe_path(root, old['path'])
        if existing.is_file() and hashlib.sha256(existing.read_bytes()).hexdigest() == old.get('sha256'):
            return dict(old, reused=True)
    record = {'id': item['id'], 'role': asset['role'], 'filename': asset['filename'],
              'attempted_at': utc_now(), 'ok': False, 'attempts': [],
              'evidence': asset.get('evidence', ''), 'variant': asset.get('variant', '')}
    for url in asset['urls']:
        try:
            data, final_url, content_type = client.get(url)
            validate(data, asset['role'], final_url)
            if asset['role'] == 'source':
                source_result = unpack_source(data, requested_path, requested_path.parent / 'source')
                path = source_result.pop('path')
                source_result['extracted_files'] = [Path(p).relative_to(root).as_posix() for p in source_result['extracted_files']]
                record.update(source_result)
            else:
                path = requested_path
                store_bytes(path, data)
            record.update(ok=True, requested_url=url, final_url=final_url, content_type=content_type,
                          path=path.relative_to(root).as_posix(), bytes=len(data),
                          sha256=hashlib.sha256(data).hexdigest(), provenance='Retrieved from public URL by fetch_literature.py')
            write_json(path.with_name(path.name + '.provenance.json'), record)
            return record
        except Exception as exc:
            record['attempts'].append({'url': url, 'error': f'{type(exc).__name__}: {exc}'})
    return record


def arxiv_assets(root: Path, item: dict[str, Any], job: dict[str, Any], client: Client,
                 versions: dict[str, Any]) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    arxiv_id = job['id']
    saved = versions.get(arxiv_id, {})
    if saved.get('versioned_id'):
        chosen = saved['versioned_id']
        info = saved
    else:
        chosen = f"{arxiv_id}v{job.get('fallback_version', 1)}"
        info = {'versioned_id': chosen, 'resolved_at': utc_now(), 'resolution': 'explicit fallback version from manifest'}
        if job.get('resolve_latest', True):
            try:
                payload, final_url, _ = client.get(f'https://arxiv.org/abs/{arxiv_id}')
                text = payload.decode('utf-8', errors='replace')
                # Restrict matches to this paper: related-paper links cannot select another id.
                found = [int(n) for n in re.findall(re.escape(arxiv_id) + r'v(\d+)\b', text)]
                if not found:
                    raise ValueError('No version identifier found on arXiv abstract page')
                chosen = f'{arxiv_id}v{max(found)}'
                info.update(versioned_id=chosen, resolution='version resolved from arXiv abstract page', abstract_url=final_url)
                store_bytes(root / 'papers' / item['folder'] / ('arxiv_' + chosen) / 'abstract.html', payload)
            except Exception as exc:
                info['resolution_error'] = f'{type(exc).__name__}: {exc}'
    sub = 'arxiv_' + chosen
    assets = [
        {'role': 'pdf', 'filename': sub + '/paper.pdf',
         'urls': [f'https://arxiv.org/pdf/{chosen}'], 'evidence': 'arXiv PDF for pinned version ' + chosen},
        {'role': 'source', 'filename': sub + '/original_source',
         'urls': [f'https://arxiv.org/src/{chosen}', f'https://arxiv.org/e-print/{chosen}'],
         'evidence': 'arXiv submission source for the SAME pinned version ' + chosen},
    ]
    return assets, info


def actual_files(root: Path, item: dict[str, Any], results: dict[str, Any]) -> list[dict[str, Any]]:
    out = list(item.get('included_files', []))
    for record in results.values():
        if record.get('id') == item['id'] and record.get('ok') and record.get('path'):
            path = safe_path(root, record['path'])
            if path.is_file():
                out.append(record)
    return out


def make_index(root: Path, manifest: dict[str, Any], state: dict[str, Any]) -> None:
    rows, csv_rows = [], []
    results = state.get('results', {})
    for item in manifest['items']:
        files = actual_files(root, item, results)
        links = []
        for f in files:
            label = f.get('role', 'file')
            if label == 'ocr_tex':
                label = 'OCR TeX — not author source'
            if 'Recovered' in f.get('provenance', ''):
                label = 'Recovered ' + label
            links.append(f'<a href="{html.escape(urllib.parse.quote(f["path"], safe="/"))}">{html.escape(label)}</a>')
        attempts = [r for r in results.values() if r.get('id') == item['id']]
        failures = sum(not r.get('ok') for r in attempts)
        successful = sum(r.get('ok', False) for r in attempts)
        if files:
            status = f'{len(files)} included files'
            if failures:
                status += f'; {failures} failed requests'
        elif attempts:
            status = 'Download attempts failed' if failures else 'No file retained'
        elif item.get('assets') or item.get('arxiv_jobs'):
            status = 'Download pending — no file included'
        else:
            status = 'Full text unresolved — no file included'
        sources = []
        for a in item.get('assets', []):
            for url in a['urls']:
                sources.append((url, a['role'] + ': ' + a.get('evidence', '')))
        for a in item.get('landing_pages', []):
            sources.append((a['url'], a['note']))
        for job in item.get('arxiv_jobs', []):
            sources.append(('https://arxiv.org/abs/' + job['id'], 'arXiv PDF and source endpoints; retrieval pending unless shown above'))
        for doi in item.get('doi', []):
            sources.append(('https://doi.org/' + doi, 'DOI; metadata link is not a full-text download'))
        unique = {u: n for u, n in sources}
        source_html = ''.join('<p><a href="' + html.escape(u, quote=True) + '">' + html.escape(u) + '</a><br><small>' + html.escape(n) + '</small></p>' for u, n in unique.items())
        refs = ', '.join(str(e['report']) + ':' + e['key'] for e in item['bibliography_records'])
        notes = ' '.join(item.get('notes', []))
        cite_html = ''.join('<h4>' + html.escape(str(e['report']) + ' / ' + e['key']) + '</h4><pre>' + html.escape(e['latex']) + '</pre>' for e in item['bibliography_records'])
        search_text = (item['title'] + ' ' + item['id'] + ' ' + refs + ' ' + status).lower()
        rows.append(f'''<article data-search="{html.escape(search_text, quote=True)}"><div class="num">{item['number']:03}</div><div><h2>{html.escape(item['title'])}</h2><p class="status">{html.escape(status)}</p><p class="files">{' · '.join(links) or 'No local document'}</p><p>{html.escape(notes)}</p><details><summary>Source links, versions and citation provenance</summary>{source_html or '<p>No direct full-text URL was resolved.</p>'}<p><b>Original reference keys:</b> {html.escape(refs)}</p>{cite_html}</details></div></article>''')
        csv_rows.append([item['number'], item['id'], item['title'], item['kind'], status,
                         ' | '.join(f['path'] for f in files), ' | '.join(unique), refs, notes])
    n_pdf = sum(1 for i in manifest['items'] for f in actual_files(root, i, results) if f.get('role') == 'pdf')
    n_new = sum(bool(r.get('ok')) for r in results.values())
    n_failed = sum(not bool(r.get('ok')) for r in results.values())
    warning = ('This is the initial partial package: no new external HTTP download succeeded during preparation. '
               'Five PDFs and their OCR transcriptions were recovered from the user’s earlier articles.zip. '
               'Those OCR files are not original author TeX sources.')
    if n_new:
        warning = f'This package has been updated by the downloader: {n_new} successful asset retrievals and {n_failed} failed asset retrievals are recorded. Unresolved references remain listed; completeness is not implied.'
    document = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Radical denesting literature — file and retrieval index</title><style>
:root{font-family:Segoe UI,Arial,sans-serif;color:#243137;background:#f5f6f3}body{max-width:1100px;margin:36px auto;padding:0 24px}h1{font-size:30px;line-height:1.2}h2{font-size:18px;margin:0 0 6px}a{color:#176582;overflow-wrap:anywhere}header{border-bottom:3px solid #798f70;padding-bottom:20px}.warning{padding:16px;background:#fff4db;border-left:5px solid #b58435;line-height:1.5}.stats{font-size:18px}input{width:100%;box-sizing:border-box;padding:12px;font-size:17px;margin:18px 0;border:1px solid #b1bab1;border-radius:4px}article[hidden]{display:none}article{display:grid;grid-template-columns:50px 1fr;gap:12px;background:#fff;padding:20px;margin:10px 0;border:1px solid #e0e5dc;border-radius:4px}.num{font-size:19px;color:#71826b}.status{font-weight:600;color:#875c1c}.files{line-height:1.8}p{line-height:1.5;margin:8px 0}details{margin-top:12px}summary{cursor:pointer;color:#325d43}small{color:#626d65}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#f4f5f1;padding:12px;font-size:12px}footer{margin:30px 0;color:#687067}
</style><header><h1>Radical denesting literature</h1><p>File index, source links and bibliography provenance</p><p class="warning">''' + html.escape(warning) + f'''</p><p class="stats">107 reference groups · 278 original bibliography records · {n_pdf} locally included article PDFs</p><p>Compound citations may cover multiple publications or versions. “Source link found” does not mean “file downloaded”. Open <a href="README.md">README.md</a> for retrieval instructions, or <a href="index.csv">index.csv</a> for the tabular index.</p></header><input id="filter" placeholder="Filter by author, title, reference key or status" aria-label="Filter references">''' + '\n'.join(rows) + '''<footer>Preparation: 2026-09-05. Original reports and recovered files have separate provenance. Exact request outcomes are in download_state.json and the JSONL logs. No claim of an exhaustive worldwide open-access search.</footer><script>document.getElementById('filter').addEventListener('input',function(){const q=this.value.toLowerCase();document.querySelectorAll('article').forEach(a=>a.hidden=!a.dataset.search.includes(q));});</script></html>'''
    (root / 'index.html').write_text(document, encoding='utf-8')
    with (root / 'index.csv').open('w', encoding='utf-8-sig', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['number', 'key', 'title', 'kind', 'status', 'included_files', 'source_urls', 'original_reference_keys', 'notes'])
        writer.writerows(csv_rows)


def make_zip(root: Path, destination: Path) -> None:
    destination = destination.resolve()
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(destination.name + '.partial')
    with zipfile.ZipFile(temporary, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for p in sorted(root.rglob('*')):
            if not p.is_file() or p.is_symlink() or p.resolve() in (destination, temporary):
                continue
            if '__pycache__' in p.parts or p.name.endswith('.partial'):
                continue
            z.write(p, Path('radical_denesting_literature') / p.relative_to(root))
    os.replace(temporary, destination)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parent)
    parser.add_argument('--workers', type=int, default=4)
    parser.add_argument('--timeout', type=float, default=35)
    parser.add_argument('--retries', type=int, default=1)
    parser.add_argument('--only', help='Comma-separated reference keys, e.g. mordell,perucca,barbero')
    parser.add_argument('--no-web', action='store_true', help='Download literature only, excluding web/source-code reference pages')
    parser.add_argument('--try-unverified-pdfs', action='store_true', help='Also try unresolved explicit PDF leads in landing_pages')
    parser.add_argument('--index-only', action='store_true', help='Rebuild the local index without any network requests')
    parser.add_argument('--dry-run', action='store_true', help='Print selected references and exit without network requests')
    parser.add_argument('--no-zip', action='store_true')
    parser.add_argument('--zip', type=Path, help='Output ZIP path; default is next to the extracted package folder')
    args = parser.parse_args(argv)
    if args.workers < 1 or args.retries < 0 or args.timeout <= 0:
        parser.error('workers/timeout must be positive; retries must be nonnegative')
    root = args.root.resolve()
    manifest = json.loads((root / 'manifest.json').read_text(encoding='utf-8'))
    state_path = root / 'download_state.json'
    state = json.loads(state_path.read_text(encoding='utf-8')) if state_path.exists() else {
        'created_at': utc_now(), 'results': {}, 'arxiv_versions': {},
    }
    selected = set(args.only.split(',')) if args.only else None
    items = [i for i in manifest['items'] if (not selected or i['id'] in selected) and not (args.no_web and i['kind'] == 'web_resource')]
    if selected:
        unknown = selected - {i['id'] for i in manifest['items']}
        if unknown:
            parser.error('Unknown reference keys: ' + ', '.join(sorted(unknown)))
    if args.dry_run:
        for i in items:
            print(i['id'], len(i['assets']), 'explicit assets;', len(i.get('arxiv_jobs', [])), 'arXiv PDF/source pairs;', i['title'])
        return 0
    if not args.index_only:
        client = Client(args.timeout, args.retries)
        guard = threading.Lock()
        def remember(item: dict[str, Any], asset: dict[str, Any], record: dict[str, Any]) -> None:
            with guard:
                state['results'][asset_key(item['id'], asset)] = record
                state['updated_at'] = utc_now()
                write_json(state_path, state)
                with (root / 'download_log.jsonl').open('a', encoding='utf-8') as f:
                    f.write(json.dumps(record, ensure_ascii=False) + '\n')
            print(('OK  ' if record['ok'] else 'FAIL') + ' ' + item['id'] + ' / ' + asset['filename'], flush=True)
        def process(item: dict[str, Any]) -> None:
            try:
                jobs = list(item['assets'])
                for arxiv_job in item.get('arxiv_jobs', []):
                    assets, version = arxiv_assets(root, item, arxiv_job, client, state['arxiv_versions'])
                    with guard:
                        state['arxiv_versions'][arxiv_job['id']] = version
                        write_json(state_path, state)
                    jobs.extend(assets)
                if args.try_unverified_pdfs:
                    known = {u for a in jobs for u in a['urls']}
                    for n, lead in enumerate(item.get('landing_pages', []), 1):
                        url = lead['url']
                        if re.search(r'\.pdf(?:\?|$)', url, re.I) and url not in known:
                            jobs.append({'role': 'pdf', 'urls': [url], 'filename': f'unverified_lead_{n:02}.pdf', 'evidence': lead['note']})
                for asset in jobs:
                    record = run_asset(root, item, asset, client, state['results'])
                    remember(item, asset, record)
            except Exception as exc:
                # Unexpected per-reference errors must not abort the remaining collection.
                asset = {'filename': '_reference_error'}
                remember(item, asset, {'id': item['id'], 'ok': False, 'attempted_at': utc_now(), 'error': f'{type(exc).__name__}: {exc}'})
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
            list(pool.map(process, items))
    make_index(root, manifest, state)
    if not args.no_zip:
        destination = args.zip or root.parent / 'radical_denesting_literature.zip'
        make_zip(root, destination)
        print('ZIP:', destination.resolve())
    good = sum(bool(r.get('ok')) for r in state['results'].values())
    bad = sum(not bool(r.get('ok')) for r in state['results'].values())
    print(f'Recorded asset retrievals: {good} successful, {bad} failed. See index.html and download_state.json.')
    return 1 if bad and not args.index_only else 0


if __name__ == '__main__':
    raise SystemExit(main())
