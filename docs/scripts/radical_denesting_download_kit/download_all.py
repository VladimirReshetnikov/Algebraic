#!/usr/bin/env python3
"""Download public copies listed in manifest.json; standard library, Python 3.9+.

This program was tested offline, not against the live remote servers. It does
not bypass authentication, paywalls or anti-bot challenges, and never executes
any downloaded source. Run --help for usage; --dry-run performs no networking.
"""
from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import socket
import stat
import sys
import tarfile
import tempfile
import time
from datetime import datetime, timezone
from html.parser import HTMLParser
from urllib.error import HTTPError, URLError
from urllib.parse import quote, unquote, urljoin, urlsplit
from urllib.request import Request, urlopen
import zipfile

VERSION = '1.0'
MAX_MEMBERS = 10000
SOURCE_LIMIT = 256 * 1024 * 1024
TEX_SUFFIXES = {'.tex', '.ltx'}


def utcnow() -> str:
    return datetime.now(timezone.utc).isoformat(timespec='seconds')


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def atomic_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + '.partial')
    tmp.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    os.replace(tmp, path)


def safe_path(root: Path, relative: str) -> Path:
    """Disallow traversal, Windows alternate streams and paths outside root."""
    if not relative or '\\' in relative or '\x00' in relative:
        raise ValueError('Unsafe empty, backslash or NUL-containing path')
    parts = PurePosixPath(relative).parts
    if PurePosixPath(relative).is_absolute() or any(p in ('..', '') or ':' in p for p in parts):
        raise ValueError('Unsafe archive/manifest path: ' + relative)
    dest = root.joinpath(*parts)
    dest.resolve().relative_to(root.resolve())
    # Existing symlinks anywhere below root must not redirect writes.
    for parent in [dest] + list(dest.parents):
        if parent == root.parent:
            break
        if parent.is_symlink():
            raise ValueError('Refusing to write through a symlink: ' + str(parent))
    return dest


def write_bytes(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + '.partial')
    with tmp.open('wb') as f:
        f.write(data)
    os.replace(tmp, path)


class Page(HTMLParser):
    def __init__(self, text: str):
        super().__init__(convert_charrefs=True)
        self.meta: dict[str, list[str]] = {}
        self.links: list[tuple[str, str]] = []
        self.title = ''
        self._title = False
        self._anchor: tuple[str, list[str]] | None = None
        self.feed(text)

    def handle_starttag(self, tag: str, attrs: list) -> None:
        d = {str(k).lower(): v or '' for k, v in attrs}
        if tag == 'meta':
            name = d.get('name', d.get('property', '')).lower()
            self.meta.setdefault(name, []).append(d.get('content', ''))
        elif tag == 'a' and d.get('href'):
            self._anchor = (d['href'], [])
        elif tag == 'title':
            self._title = True
        elif tag in ('iframe', 'embed'):
            src = d.get('src', '')
            if src:
                self.links.append((src, 'embedded document'))

    def handle_data(self, data: str) -> None:
        if self._title:
            self.title += data
        if self._anchor is not None:
            self._anchor[1].append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag == 'a' and self._anchor:
            self.links.append((self._anchor[0], ''.join(self._anchor[1])))
            self._anchor = None
        elif tag == 'title':
            self._title = False


def looks_html(data: bytes) -> bool:
    head = data[:8192].lstrip().lower()
    return b'<!doctype html' in head or b'<html' in head or b'<head' in head


def validate(data: bytes, kind: str) -> None:
    if not data:
        raise ValueError('Empty response')
    if kind == 'pdf':
        if b'%PDF-' not in data[:1024] or b'%%EOF' not in data[-16384:] or looks_html(data):
            raise ValueError('Not a complete-looking PDF (header/trailer check failed)')
    elif kind == 'html':
        if not looks_html(data):
            raise ValueError('Not an HTML page')
        page = Page(data.decode('utf-8', errors='replace'))
        if re.search(r'access denied|forbidden|not found|just a moment|attention required|captcha|robot check|service unavailable|sign[ -]?in|log[ -]?in', page.title, re.I):
            raise ValueError('Page appears to be an error, login or anti-bot challenge: ' + page.title.strip())
    elif kind == 'text':
        if looks_html(data) or b'%PDF-' in data[:1024] or b'\x00' in data[:8192]:
            raise ValueError('Expected source text, received HTML, PDF or binary data')
        data.decode('utf-8')
    elif kind == 'zip':
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            check_zip(z)
            bad = z.testzip()
            if bad:
                raise ValueError('Corrupt ZIP member: ' + bad)
    else:
        raise ValueError('Unknown validation kind: ' + kind)


def check_zip(z: zipfile.ZipFile) -> None:
    info = z.infolist()
    if len(info) > MAX_MEMBERS or sum(i.file_size for i in info) > SOURCE_LIMIT:
        raise ValueError('ZIP exceeds extraction safety limits')
    names = set()
    for i in info:
        safe_path(Path('/safety_check_root'), i.filename)
        if stat.S_ISLNK(i.external_attr >> 16):
            raise ValueError('ZIP contains a symbolic link')
        if i.filename in names and not i.is_dir():
            raise ValueError('ZIP contains duplicate member names')
        names.add(i.filename)


class Fetcher:
    def __init__(self, timeout: float = 30, max_bytes: int = 512 * 1024 * 1024):
        self.timeout = timeout
        self.max_bytes = max_bytes
        self.last_request: dict[str, float] = {}

    def get(self, url: str) -> tuple[bytes, str, str]:
        """Normal unauthenticated HTTP(S), bounded reads, polite retries."""
        p = urlsplit(url)
        if p.scheme not in ('http', 'https') or not p.netloc or p.username or p.password:
            raise ValueError('Only unauthenticated HTTP(S) URLs are supported')
        host = p.hostname or ''
        interval = 3.2 if host.endswith('arxiv.org') else 0.6
        last_error: Exception | None = None
        for attempt in range(3):
            remaining = interval - (time.monotonic() - self.last_request.get(host, 0))
            if remaining > 0:
                time.sleep(remaining)
            self.last_request[host] = time.monotonic()
            request = Request(url, headers={
                'User-Agent': 'RadicalDenestingBibliographyDownloader/' + VERSION + ' (personal scholarly archiving)',
                'Accept': '*/*', 'Accept-Encoding': 'identity'})
            try:
                with urlopen(request, timeout=self.timeout) as r:
                    length = r.headers.get('Content-Length')
                    if length and int(length) > self.max_bytes:
                        raise ValueError('Response exceeds --max-mb')
                    chunks = []
                    total = 0
                    while True:
                        chunk = r.read(1024 * 1024)
                        if not chunk:
                            break
                        total += len(chunk)
                        if total > self.max_bytes:
                            raise ValueError('Response exceeds --max-mb')
                        chunks.append(chunk)
                    data = b''.join(chunks)
                    if r.headers.get('Content-Encoding', '').lower() == 'gzip':
                        with gzip.GzipFile(fileobj=io.BytesIO(data)) as g:
                            data = g.read(self.max_bytes + 1)
                        if len(data) > self.max_bytes:
                            raise ValueError('Decoded response exceeds --max-mb')
                    return data, r.geturl(), r.headers.get('Content-Type', '')
            except HTTPError as exc:
                last_error = exc
                if exc.code not in (429, 500, 502, 503, 504) or attempt == 2:
                    raise
                wait = exc.headers.get('Retry-After', '')
                time.sleep(min(60, int(wait)) if wait.isdigit() else 3 * (attempt + 1))
            except (URLError, TimeoutError, OSError) as exc:
                last_error = exc
                # DNS and blocked-network failures do not improve by immediate retries.
                if isinstance(getattr(exc, 'reason', None), socket.gaierror) or attempt == 2:
                    raise
                time.sleep(2 * (attempt + 1))
        raise RuntimeError(str(last_error))


def resolve_candidates(data: bytes, base: str, target: str, patterns: list[str] | None = None) -> list[str]:
    page = Page(data.decode('utf-8', errors='replace'))
    out = []
    if target == 'pdf':
        for key in ('citation_pdf_url', 'eprints.document_url', 'wkhealth_pdf_url'):
            out.extend(page.meta.get(key, []))
    for href, label in page.links:
        path = unquote(urlsplit(href).path).lower()
        label = re.sub(r'\s+', ' ', label).strip().lower()
        if target == 'pdf':
            # Exact download labels are safer than following references to other papers.
            match = (label in ('pdf', 'pdf download', 'download pdf', 'view pdf', 'full text (pdf)',
                               'full text pdf', 'download full-text pdf', 'download full text pdf')
                     or (path.endswith('.pdf') and label in ('download', 'full text', 'full-text', 'read', ''))
                     or (path.endswith('.pdf') and label.endswith('.pdf'))
                     or (label == 'embedded document' and path.endswith('.pdf')))
        else:
            match = (label in ('latex', 'tex', 'tex source', 'latex source', 'download source', 'source')
                     or path.endswith(('.tex', '.tex.gz', '.ltx')))
        if match:
            out.append(href)
    results = []
    for href in out:
        url = urljoin(base, href)
        if urlsplit(url).scheme not in ('http', 'https'):
            continue
        if patterns and not any(p in url for p in patterns):
            continue
        if url not in results and url != base:
            results.append(url)
    return results[:8]


def obtain(fetcher: Fetcher, urls: list[str], kind: str,
           resolver: str | None = None, patterns: list[str] | None = None) -> tuple[bytes, str, list[str]]:
    errors = []
    queue = [(url, 0) for url in urls]
    seen = set()
    while queue:
        url, depth = queue.pop(0)
        if url in seen:
            continue
        seen.add(url)
        try:
            data, actual, content_type = fetcher.get(url)
            if resolver and looks_html(data):
                validate(data, 'html')
                candidates = resolve_candidates(data, actual, resolver, patterns)
                if depth < 2 and candidates:
                    queue[0:0] = [(u, depth + 1) for u in candidates]
                    continue
                raise ValueError('No usable ' + resolver + ' download link in the public page')
            if kind != 'source':
                validate(data, kind)
            else:
                # Detailed source validation happens during safe extraction.
                if looks_html(data) or b'%PDF-' in data[:1024]:
                    raise ValueError('No TeX source: received HTML or a PDF-only submission')
            return data, actual, errors
        except Exception as exc:
            errors.append(url + ' -> ' + type(exc).__name__ + ': ' + str(exc))
    raise RuntimeError('\n'.join(errors) or 'No download URL configured')


def unpack_source(data: bytes, directory: Path, hint: str = '') -> tuple[str, list[Path]]:
    """Write exact source bytes without executing them; return original suffix."""
    directory.mkdir(parents=True, exist_ok=True)
    files = []
    if zipfile.is_zipfile(io.BytesIO(data)):
        with zipfile.ZipFile(io.BytesIO(data)) as z:
            check_zip(z)
            for i in z.infolist():
                dest = safe_path(directory, i.filename)
                if i.is_dir():
                    dest.mkdir(parents=True, exist_ok=True)
                else:
                    write_bytes(dest, z.read(i))
                    files.append(dest)
        suffix = '.zip'
    else:
        try:
            tar = tarfile.open(fileobj=io.BytesIO(data), mode='r:*')
        except tarfile.ReadError:
            tar = None
        if tar is not None:
            with tar:
                members = tar.getmembers()
                if len(members) > MAX_MEMBERS or sum(m.size for m in members) > SOURCE_LIMIT:
                    raise ValueError('Source archive exceeds safety limits')
                names = set()
                for m in members:
                    dest = safe_path(directory, m.name)
                    if not (m.isfile() or m.isdir()):
                        raise ValueError('Source archive contains a link or special file: ' + m.name)
                    if m.name in names and not m.isdir():
                        raise ValueError('Source archive contains duplicate member names')
                    names.add(m.name)
                    if m.isdir():
                        dest.mkdir(parents=True, exist_ok=True)
                    else:
                        stream = tar.extractfile(m)
                        if stream is None:
                            raise ValueError('Missing archive member stream')
                        write_bytes(dest, stream.read())
                        files.append(dest)
            suffix = '.tar.gz' if data.startswith(b'\x1f\x8b') else '.tar'
        else:
            raw = data
            if data.startswith(b'\x1f\x8b'):
                with gzip.GzipFile(fileobj=io.BytesIO(data)) as g:
                    raw = g.read(SOURCE_LIMIT + 1)
                suffix = '.tex.gz'
            else:
                suffix = '.tex'
            if len(raw) > SOURCE_LIMIT or looks_html(raw) or b'%PDF-' in raw[:1024]:
                raise ValueError('Not an acceptable TeX source payload')
            if not re.search(rb'\\(?:documentclass|documentstyle|input|begin|def|newcommand|magnification|bye)\b', raw):
                raise ValueError('Unrecognized plain TeX source payload')
            name = Path(unquote(urlsplit(hint).path)).name
            if Path(name).suffix.lower() not in TEX_SUFFIXES:
                name = 'main.tex'
            dest = safe_path(directory, name)
            write_bytes(dest, raw)
            files.append(dest)
    if not any(p.suffix.lower() in TEX_SUFFIXES for p in files):
        raise ValueError('Downloaded submission archive contains no .tex/.ltx file')
    return suffix, files


def pin_arxiv(fetcher: Fetcher, identifier: str) -> str:
    if re.fullmatch(r'\d{4}\.\d{4,5}v\d+', identifier):
        return identifier
    if not re.fullmatch(r'\d{4}\.\d{4,5}', identifier):
        raise ValueError('Unsupported arXiv identifier: ' + identifier)
    data, actual, _ = fetcher.get('https://arxiv.org/abs/' + identifier)
    validate(data, 'html')
    text = data.decode('utf-8', errors='replace')
    versions = [int(v) for v in re.findall(r'\[v(\d+)\]', text)]
    versions += [int(v) for v in re.findall(re.escape(identifier) + r'v(\d+)', text)]
    if not versions:
        raise ValueError('Could not pin arXiv version; refusing an unversioned PDF/source pair')
    return identifier + 'v' + str(max(versions))


class Runner:
    def __init__(self, output: Path, manifest: dict, fetcher: Fetcher):
        self.output = output.resolve()
        self.manifest = manifest
        self.fetcher = fetcher
        self.output.mkdir(parents=True, exist_ok=True)
        self.state_path = self.output / 'download_state.json'
        self.state = json.loads(self.state_path.read_text(encoding='utf-8')) if self.state_path.exists() else {'assets': {}, 'arxiv_versions': {}}
        self.rows = []

    def save_state(self) -> None:
        self.state['updated_at'] = utcnow()
        atomic_json(self.state_path, self.state)

    def record(self, e: dict, aid: str, row: dict) -> None:
        row.update({'work_id': e['id'], 'asset_id': aid, 'title': e['title'], 'recorded_at': utcnow()})
        self.state['assets'][e['id'] + ':' + aid] = row
        self.rows.append(row)
        self.save_state()
        print('  ' + row['status'] + ': ' + aid, flush=True)

    def resume(self, e: dict, aid: str) -> bool:
        old = self.state['assets'].get(e['id'] + ':' + aid)
        if not old or old.get('status') not in ('downloaded', 'resumed'):
            return False
        for item in old.get('files', []):
            p = safe_path(self.output, item['path'])
            if not p.is_file() or file_digest(p) != item['sha256']:
                return False
        if not old.get('files'):
            return False
        row = dict(old)
        row['status'] = 'resumed'
        self.record(e, aid, row)
        return True

    def file_info(self, paths: list[Path]) -> list[dict]:
        return [{'path': p.relative_to(self.output).as_posix(), 'bytes': p.stat().st_size,
                 'sha256': file_digest(p)} for p in paths]

    def single(self, e: dict, a: dict) -> None:
        if self.resume(e, a['id']):
            return
        root = safe_path(self.output, e['folder'])
        filename = a['filename']
        kind = a['kind']
        resolver = 'pdf' if kind == 'resolve_pdf' else 'tex' if kind == 'resolve_tex' else None
        target_kind = 'pdf' if kind == 'resolve_pdf' else 'source' if kind in ('resolve_tex', 'source') else kind
        try:
            data, actual, attempts = obtain(self.fetcher, a['urls'], target_kind, resolver, a.get('allow_link_patterns'))
            dest = safe_path(root, filename)
            paths = []
            if target_kind == 'source':
                # Extract to a fresh staging directory so rejected archives leave no
                # apparently successful source tree behind.
                dest.parent.mkdir(parents=True, exist_ok=True)
                with tempfile.TemporaryDirectory(prefix='.source_staging_', dir=dest.parent) as temp:
                    staged = Path(temp)
                    suffix, staged_files = unpack_source(data, staged, actual)
                    for sf in staged_files:
                        rel = sf.relative_to(staged).as_posix()
                        target = safe_path(dest, rel)
                        write_bytes(target, sf.read_bytes())
                        paths.append(target)
                if suffix != '.tex':
                    archive = dest.with_name(dest.name + '_original' + suffix)
                    write_bytes(archive, data)
                    paths.insert(0, archive)
            else:
                write_bytes(dest, data)
                paths = [dest]
            row = {'status': 'downloaded', 'url': actual, 'kind': target_kind,
                   'files': self.file_info(paths), 'failed_attempts_before_success': attempts,
                   'validation': 'file-format and integrity checks only; bibliographic identity, completeness and reuse rights are not machine-certified'}
            self.record(e, a['id'], row)
        except Exception as exc:
            self.record(e, a['id'], {'status': 'failed', 'kind': target_kind, 'files': [], 'error': str(exc)})

    def arxiv(self, e: dict, a: dict) -> None:
        try:
            key = e['id'] + ':' + a['arxiv_id']
            pinned = self.state['arxiv_versions'].get(key)
            if not pinned:
                pinned = pin_arxiv(self.fetcher, a['arxiv_id'])
                self.state['arxiv_versions'][key] = pinned
                self.save_state()
            base = 'arxiv/' + pinned
            self.single(e, {'id': 'arxiv_pdf_' + pinned, 'kind': 'pdf', 'filename': base + '/paper.pdf',
                            'urls': ['https://arxiv.org/pdf/' + pinned]})
            self.single(e, {'id': 'arxiv_source_' + pinned, 'kind': 'source', 'filename': base + '/source',
                            'urls': ['https://arxiv.org/src/' + pinned, 'https://arxiv.org/e-print/' + pinned,
                                     'https://export.arxiv.org/e-print/' + pinned]})
        except Exception as exc:
            self.record(e, a['id'], {'status': 'failed', 'kind': 'arxiv_pair', 'files': [], 'error': str(exc)})

    def entry_readme(self, e: dict) -> None:
        root = safe_path(self.output, e['folder'])
        root.mkdir(parents=True, exist_ok=True)
        lines = ['# ' + e['title'], '', 'Bibliography group: `' + e['id'] + '`', '',
                 'Research status: ' + e['search_status'], '',
                 'This folder is NOT evidence that a PDF was downloaded. See download_state.json and download_results.csv.', '',
                 '## Notes', '']
        lines += [str(n) for n in e['notes'] if not n.startswith('Session outcome:')]
        lines += ['', '## Original report references', '', ', '.join(e['cited_in']), '', '## Finding aids', '']
        lines += [d['url'] + ' — ' + d['evidence'] for d in e['discovery_pages']]
        (root / 'README.md').write_text('\n\n'.join(lines) + '\n', encoding='utf-8')

    def report(self) -> None:
        atomic_json(self.output / 'bibliography_manifest.json', self.manifest)
        all_rows = list(self.state['assets'].values())
        fields = ['work_id', 'asset_id', 'title', 'status', 'kind', 'url', 'files', 'error', 'recorded_at']
        with (self.output / 'download_results.csv').open('w', newline='', encoding='utf-8-sig') as f:
            w = csv.DictWriter(f, fieldnames=fields, extrasaction='ignore')
            w.writeheader()
            for row in all_rows:
                r = dict(row)
                r['files'] = '; '.join(x['path'] for x in row.get('files', []))
                w.writerow(r)
        success = [r for r in all_rows if r['status'] in ('downloaded', 'resumed')]
        failed = [r for r in all_rows if r['status'] == 'failed']
        paths = {x['path'] for r in success for x in r.get('files', [])}
        summary = {
            'generated_at': utcnow(), 'successful_download_tasks': len(success), 'failed_tasks': len(failed),
            'actual_downloaded_files': len(paths),
            'PDF_files': sum(p.lower().endswith('.pdf') for p in paths),
            'TeX_files': sum(Path(p).suffix.lower() in TEX_SUFFIXES for p in paths),
            'works_with_successful_downloads': len({r['work_id'] for r in success}),
            'bibliography_groups': len(self.manifest['entries']),
            'important': 'Only successful tasks have downloaded files. Folder presence, metadata and links are not successful downloads. Format checks do not establish full-text completeness.'}
        atomic_json(self.output / 'SUMMARY.json', summary)
        text = '# Radical-denesting public-copy collection\n\n' + json.dumps(summary, indent=2, ensure_ascii=False)
        text += '\n\nRead download_results.csv and download_state.json for failures, URLs, hashes and actual files.\n'
        text += 'Source trees are uncompiled original source downloads. Do not execute unfamiliar code or TeX without reviewing it.\n'
        text += 'An Internet connection and public access are required; this program cannot make gated or missing works available.\n'
        (self.output / 'README.md').write_text(text, encoding='utf-8')
        print('\n' + json.dumps(summary, indent=2), flush=True)


def create_zip(output: Path, zip_path: Path) -> None:
    zip_path = zip_path.resolve()
    zip_path.parent.mkdir(parents=True, exist_ok=True)
    temp = zip_path.with_name(zip_path.name + '.partial')
    with zipfile.ZipFile(temp, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=True) as z:
        for path in sorted(output.rglob('*')):
            if path.is_file() and not path.is_symlink() and path.resolve() not in (zip_path, temp) and not path.name.endswith('.partial'):
                z.write(path, output.name + '/' + path.relative_to(output).as_posix())
    os.replace(temp, zip_path)
    print('ZIP written: ' + str(zip_path), flush=True)


def main(argv: list[str] | None = None) -> int:
    base = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--manifest', type=Path, default=base / 'manifest.json')
    parser.add_argument('--output', type=Path, default=base / 'radical_denesting_downloads')
    parser.add_argument('--zip', type=Path, dest='zip_path', help='Output ZIP path; default is OUTPUT.zip')
    parser.add_argument('--only', help='Comma-separated work IDs (see manifest.json)')
    parser.add_argument('--dry-run', action='store_true', help='Print planned tasks; no network, no output files')
    parser.add_argument('--try-publisher-probes', action='store_true', help='Also try uncertain publisher URLs without authentication')
    parser.add_argument('--timeout', type=float, default=30, help='Socket timeout in seconds (default 30)')
    parser.add_argument('--max-mb', type=int, default=512, help='Maximum bytes per HTTP response, in MiB (default 512)')
    parser.add_argument('--no-zip', action='store_true', help='Leave the downloaded directory without creating a ZIP')
    args = parser.parse_args(argv)
    if args.timeout <= 0 or args.max_mb <= 0:
        parser.error('--timeout and --max-mb must be positive')
    manifest = json.loads(args.manifest.read_text(encoding='utf-8'))
    selected = {item.strip() for item in args.only.split(',') if item.strip()} if args.only else {e['id'] for e in manifest['entries']}
    known = {e['id'] for e in manifest['entries']}
    if selected - known:
        parser.error('Unknown work IDs: ' + ', '.join(sorted(selected - known)))
    entries = [e for e in manifest['entries'] if e['id'] in selected]
    if args.dry_run:
        for e in entries:
            active = [a for a in e['downloads'] if args.try_publisher_probes or not a.get('optional')]
            print(e['folder'] + ' | ' + e['title'])
            for a in active:
                print('  ' + a['id'] + ' | ' + a['kind'] + ' | ' + a['filename'])
            if not active:
                print('  NO DOWNLOAD CONFIGURED; bibliography record retained')
        print('\nDRY RUN ONLY: no remote files were downloaded.')
        return 0
    runner = Runner(args.output, manifest, Fetcher(args.timeout, args.max_mb * 1024 * 1024))
    interrupted = False
    try:
        for number, e in enumerate(entries, 1):
            print(f'[{number}/{len(entries)}] {e["id"]}: {e["title"]}', flush=True)
            runner.entry_readme(e)
            for a in e['downloads']:
                if a.get('optional') and not args.try_publisher_probes:
                    continue
                if a['kind'] == 'arxiv_pair':
                    runner.arxiv(e, a)
                else:
                    runner.single(e, a)
    except KeyboardInterrupt:
        interrupted = True
        print('\nInterrupted; completed downloads are preserved for resume.', flush=True)
    finally:
        runner.report()
        if not args.no_zip:
            create_zip(runner.output, args.zip_path or Path(str(args.output) + '.zip'))
    # Partial failures are expected. A nonzero exit status makes them visible to automation.
    failed = any(r.get('status') == 'failed' for r in runner.state['assets'].values())
    return 130 if interrupted else 2 if failed else 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as exc:
        print(type(exc).__name__ + ': ' + str(exc), file=sys.stderr)
        sys.exit(1)
