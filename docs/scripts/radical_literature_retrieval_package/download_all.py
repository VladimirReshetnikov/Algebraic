#!/usr/bin/env python3
"""Retrieve the public assets listed in catalog.json; Python 3.10+, standard library.

This program does not bypass paywalls or authentication, run downloaded code,
or compile TeX. A valid PDF signature is not a malware scan or proof of identity.
See README.md for scope, evidence levels, and limitations.
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import gzip
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import sys
import tarfile
import tempfile
import time
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import quote, unquote, urljoin, urlsplit, urlunsplit
from urllib.request import Request, build_opener, HTTPRedirectHandler, HTTPSHandler
import ssl
from html.parser import HTMLParser
import zipfile

SCRIPT_DIR = Path(__file__).resolve().parent

# Console streams on Windows may default to a legacy code page; titles contain characters such as the radical sign.
for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, 'reconfigure'):
        _stream.reconfigure(encoding='utf-8', errors='replace')
USER_AGENT = 'RadicalBibliographyDownloader/1.0 (personal scholarly retrieval; Python urllib)'
SOURCE_LIMIT = 512 * 1024 * 1024
MEMBER_LIMIT = 20000
FONT_EXTENSIONS = {'.ttf', '.otf', '.woff', '.woff2', '.pfb', '.pfm'}


def utcnow() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec='seconds')


def slug(text: str, limit: int = 65) -> str:
    return re.sub(r'[^A-Za-z0-9._-]+', '-', text).strip('.-')[:limit] or 'item'


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        while block := f.read(1024 * 1024):
            h.update(block)
    return h.hexdigest()


def write_json(path: Path, obj: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + '.tmp')
    temp.write_text(json.dumps(obj, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    temp.replace(path)


def checked_url(url: str) -> str:
    p = urlsplit(url)
    if p.scheme not in ('https', 'http') or not p.hostname or p.username or p.password:
        raise ValueError(f'Not an unauthenticated HTTP(S) URL: {url!r}')
    # Encode non-ASCII characters/spaces without double-encoding existing % escapes.
    return urlunsplit((p.scheme, p.netloc, quote(p.path, safe='/:%@!$&\'()*+,;=-._~'),
                       quote(p.query, safe='=&;%/:?@!$\'()*+,-._~'), ''))


class SafeRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return super().redirect_request(req, fp, code, msg, headers, checked_url(newurl))


class Fetcher:
    def __init__(self, timeout: float, retries: int, max_bytes: int, delay: float,
                 insecure_hosts: set[str] | None = None, insecure_all: bool = False,
                 user_agent: str = USER_AGENT):
        self.timeout, self.retries = timeout, retries
        self.max_bytes, self.delay = max_bytes, delay
        self.opener = build_opener(SafeRedirects())
        # Opt-in only: hosts whose certificate chain is not trusted by this Python
        # (for example a root missing from the local store). Recorded in provenance.
        self.insecure_hosts = {h.lower() for h in (insecure_hosts or set())}
        self.insecure_all = insecure_all
        self.user_agent = user_agent
        unverified = ssl.create_default_context()
        unverified.check_hostname = False
        unverified.verify_mode = ssl.CERT_NONE
        self.insecure_opener = build_opener(SafeRedirects(), HTTPSHandler(context=unverified))
        self.last_request: dict[str, float] = {}
        self.log: list[dict[str, Any]] = []

    def fetch(self, url: str) -> tuple[bytes, dict[str, Any]]:
        url = checked_url(url)
        host = urlsplit(url).hostname or ''
        bucket = 'arxiv.org' if host.endswith('arxiv.org') else host
        wait = max(3.2 if bucket == 'arxiv.org' else self.delay, 0.0)
        error: Exception | None = None
        for attempt in range(self.retries + 1):
            gap = wait - (time.monotonic() - self.last_request.get(bucket, 0))
            if gap > 0:
                time.sleep(gap)
            self.last_request[bucket] = time.monotonic()
            event: dict[str, Any] = {'time': utcnow(), 'url': url, 'attempt': attempt + 1}
            try:
                req = Request(url, headers={'User-Agent': self.user_agent, 'Accept': '*/*', 'Accept-Encoding': 'identity'})
                skip_tls = self.insecure_all or host.lower() in self.insecure_hosts
                opener = self.insecure_opener if skip_tls else self.opener
                with opener.open(req, timeout=self.timeout) as response:
                    final_url = checked_url(response.geturl())
                    declared = response.headers.get('Content-Length', '')
                    if declared.isdigit() and int(declared) > self.max_bytes:
                        raise ValueError('Declared file size exceeds --max-mb.')
                    data = bytearray()
                    while True:
                        block = response.read(min(1024 * 1024, self.max_bytes + 1 - len(data)))
                        if not block:
                            break
                        data.extend(block)
                        if len(data) > self.max_bytes:
                            raise ValueError('File exceeds --max-mb.')
                    meta = {'requested_url': url, 'resolved_url': final_url,
                            'retrieved_at': utcnow(), 'http_status': response.status,
                            'content_type': response.headers.get('Content-Type', ''),
                            'user_agent': self.user_agent,
                            'content_encoding': response.headers.get('Content-Encoding', ''),
                            'bytes': len(data), 'sha256': digest(data),
                            'tls_verification': ('SKIPPED by --insecure' if self.insecure_all else 'SKIPPED by --insecure-hosts') if skip_tls else 'verified'}
                    # HTTP transfer compression is separate from a gzip source file.
                    if meta['content_encoding'].lower() == 'gzip':
                        with gzip.GzipFile(fileobj=io.BytesIO(data)) as gz:
                            plain = gz.read(self.max_bytes + 1)
                        if len(plain) > self.max_bytes:
                            raise ValueError('HTTP decompressed body exceeds --max-mb.')
                        data = bytearray(plain)
                        meta.update(bytes=len(data), sha256=digest(data), http_gzip_decoded=True)
                event.update(status='received', bytes=len(data), resolved_url=final_url)
                self.log.append(event)
                return bytes(data), meta
            except (OSError, ValueError, HTTPError, URLError) as exc:
                error = exc
                event.update(status='failed', error=f'{type(exc).__name__}: {exc}')
                self.log.append(event)
                # Never keep asking for denied/not-found content as a login workaround.
                if isinstance(exc, HTTPError) and exc.code not in (408, 429, 500, 502, 503, 504):
                    break
                if isinstance(exc, ValueError):
                    break
                if attempt < self.retries:
                    retry_after = exc.headers.get('Retry-After', '') if isinstance(exc, HTTPError) else ''
                    pause = min(60, max(2 ** (attempt + 1), int(retry_after) if retry_after.isdigit() else 0))
                    time.sleep(pause)
        raise RuntimeError(f'Could not retrieve {url}: {error}')


def is_pdf(data: bytes) -> bool:
    # Both checks prevent truncated responses and HTML masquerading as .pdf.
    return len(data) > 100 and data.lstrip()[:1024].startswith(b'%PDF-') and b'%%EOF' in data[-65536:]


def is_tex(data: bytes) -> bool:
    head = data[:262144]
    if b'\x00' in head or re.search(br'<(?:!doctype\s+html|html|head)\b', head[:2048], re.I):
        return False
    return bool(re.search(br'\\(?:documentclass|documentstyle|begin\s*\{document\}|input\b|def\b|newcommand\b)', head))


def safe_member(name: str, root: Path) -> Path:
    name = name.replace('\\', '/')
    p = PurePosixPath(name)
    if (not name or p.is_absolute() or '..' in p.parts or any(':' in x for x in p.parts)
            or '\x00' in name):
        raise ValueError(f'Unsafe archive member: {name!r}')
    clean = [x for x in p.parts if x not in ('', '.')]
    if not clean:
        raise ValueError(f'Empty archive path: {name!r}')
    out = root.joinpath(*clean)
    out.resolve().relative_to(root.resolve())
    return out


def extract_source(data: bytes, root: Path) -> tuple[str, list[Path], list[str]]:
    """Extract only regular members; reject traversal, symlinks and expansion bombs.

    Returns an appropriate suffix for preserving the exact source response,
    the extracted regular files, and warnings. Does not execute anything.
    """
    root.mkdir(parents=True, exist_ok=True)
    warnings: list[str] = []
    files: list[Path] = []
    seen: set[str] = set()
    total = 0

    def put(name: str, stream, size: int) -> None:
        nonlocal total
        target = safe_member(name, root)
        key = str(target.relative_to(root)).casefold()  # Also safe on Windows.
        if key in seen:
            raise ValueError(f'Duplicate / case-colliding archive member: {name}')
        seen.add(key)
        if len(seen) > MEMBER_LIMIT or size < 0 or total + size > SOURCE_LIMIT:
            raise ValueError('Source archive exceeds member or expanded-size limit.')
        total += size
        if target.suffix.lower() in FONT_EXTENSIONS:
            warnings.append(f'Binary font omitted from extraction: {name}')
            return
        body = stream.read(size + 1)
        if len(body) != size:
            raise ValueError(f'Bad archive member size: {name}')
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(body)
        files.append(target)

    bio = io.BytesIO(data)
    if zipfile.is_zipfile(bio):
        with zipfile.ZipFile(io.BytesIO(data)) as zf:
            if len(zf.infolist()) > MEMBER_LIMIT:
                raise ValueError('Too many source archive members.')
            for m in zf.infolist():
                safe_member(m.filename, root)
                mode = m.external_attr >> 16
                if stat.S_ISLNK(mode):
                    raise ValueError(f'Source archive symlink rejected: {m.filename}')
                if m.is_dir():
                    continue
                if m.flag_bits & 1:
                    raise ValueError('Encrypted source archives are not supported.')
                with zf.open(m) as f:
                    put(m.filename, f, m.file_size)
        extension = '.zip'
    else:
        try:
            tf = tarfile.open(fileobj=io.BytesIO(data), mode='r:*')
        except tarfile.ReadError:
            tf = None
        if tf is not None:
            with tf:
                member_count = 0
                for m in tf:
                    member_count += 1
                    if member_count > MEMBER_LIMIT:
                        raise ValueError('Too many tar members.')
                    if m.name in ('.', './') and m.isdir():
                        continue
                    safe_member(m.name, root)
                    if m.isdir():
                        continue
                    if not m.isfile():
                        raise ValueError(f'Non-regular source member rejected: {m.name}')
                    f = tf.extractfile(m)
                    if f is None:
                        raise ValueError(f'Cannot read source member: {m.name}')
                    with f:
                        put(m.name, f, m.size)
            extension = ('.tar.gz' if data.startswith(b'\x1f\x8b') else '.tar.bz2' if data.startswith(b'BZh') else '.tar.xz' if data.startswith(b'\xfd7zXZ') else '.tar')
        else:
            plain = data
            extension = '.tex'
            if data.startswith(b'\x1f\x8b'):
                with gzip.GzipFile(fileobj=io.BytesIO(data)) as gz:
                    plain = gz.read(SOURCE_LIMIT + 1)
                if len(plain) > SOURCE_LIMIT:
                    raise ValueError('Expanded gzip source exceeds size limit.')
                extension = '.tex.gz'
            if not is_tex(plain):
                raise ValueError('Response is not a TeX source or supported source archive (it may be PDF-only or HTML).')
            put('main.tex', io.BytesIO(plain), len(plain))
    if not any(p.suffix.lower() in ('.tex', '.ltx') for p in files):
        raise ValueError('Source archive contains no .tex or .ltx files; not accepted as TeX source.')
    return extension, files, warnings


class DownloadLinks(HTMLParser):
    """Only explicit full-text/source links; no general crawling of references."""
    def __init__(self, base: str, wanted: str):
        super().__init__(convert_charrefs=True)
        self.base, self.wanted = base, wanted
        self.links: list[str] = []
        self.href: str | None = None
        self.text: list[str] = []

    def handle_starttag(self, tag, attrs):
        a = {k.lower(): v or '' for k, v in attrs}
        if tag == 'meta' and self.wanted == 'pdf':
            if a.get('name', '').lower() in ('citation_pdf_url', 'wkhealth_pdf_url'):
                self.links.append(urljoin(self.base, a.get('content', '')))
        if tag == 'a':
            self.href, self.text = a.get('href'), []
        if tag in ('iframe', 'embed') and self.wanted == 'pdf':
            u = a.get('src', '')
            if urlsplit(u).path.lower().endswith('.pdf'):
                self.links.append(urljoin(self.base, u))
        if tag == 'object' and self.wanted == 'pdf':
            u = a.get('data', '')
            if a.get('type') == 'application/pdf' or urlsplit(u).path.lower().endswith('.pdf'):
                self.links.append(urljoin(self.base, u))

    def handle_data(self, data):
        if self.href is not None:
            self.text.append(data)

    def handle_endtag(self, tag):
        if tag != 'a' or self.href is None:
            return
        label = ' '.join(' '.join(self.text).split()).strip().lower()
        path = urlsplit(self.href).path.lower()
        if self.wanted == 'source':
            matched = bool(re.fullmatch(r'(?:latex|tex|tex source|source|download (?:latex|tex|source))', label))
        else:
            matched = bool(re.fullmatch(r'(?:\[?pdf\]?|download(?: full[- ]text)? pdf|full[- ]text(?: \(pdf\))?|view pdf|pdf download|download)', label))
            # A bare "download" can be a citation export; require an explicit PDF path.
            if label == 'download' and not path.endswith('.pdf'):
                matched = False
        if matched:
            self.links.append(urljoin(self.base, self.href))
        self.href, self.text = None, []


def json_fetch(fetcher: Fetcher, url: str) -> Any:
    return json.loads(fetcher.fetch(url)[0].decode('utf-8'))


def resolve_asset(asset: dict[str, Any], fetcher: Fetcher) -> tuple[list[str], dict[str, tuple[bytes, dict[str, Any]]], dict[str, Any]]:
    urls = list(asset.get('urls', []))
    cache: dict[str, tuple[bytes, dict[str, Any]]] = {}
    provenance: dict[str, Any] = {}
    resolver = asset.get('resolver')
    if not resolver:
        return urls, cache, provenance
    kind = resolver['type']
    if kind == 'landing':
        url = resolver['url']
        blob, meta = fetcher.fetch(url)
        provenance['landing_page'] = meta
        if asset['kind'] == 'pdf' and is_pdf(blob):
            cache[url] = (blob, meta)
            urls.insert(0, url)
        else:
            parser = DownloadLinks(meta['resolved_url'], resolver.get('wanted', asset['kind']))
            parser.feed(blob.decode('utf-8', errors='replace'))
            urls.extend(parser.links[:8])
    elif kind == 'nasa':
        ident = resolver['id']
        data = json_fetch(fetcher, f'https://ntrs.nasa.gov/api/citations/{quote(ident)}')
        provenance['nasa_id'] = ident
        for item in data.get('downloads', []):
            links = item.get('links', {})
            for key in ('pdf', 'original'):
                value = links.get(key)
                if isinstance(value, str):
                    urls.append(urljoin('https://ntrs.nasa.gov', value))
    elif kind == 'internet_archive':
        ident = resolver['id']
        data = json_fetch(fetcher, f'https://archive.org/metadata/{quote(ident)}')
        if data.get('is_dark') or data.get('metadata', {}).get('access-restricted-item') == 'true':
            raise ValueError('Archive item is access-restricted; not attempting restricted files.')
        candidates = [f for f in data.get('files', []) if f.get('name', '').lower().endswith('.pdf') and not f.get('private')]
        candidates.sort(key=lambda f: (f.get('format') != 'Text PDF', f.get('source') != 'original', int(f.get('size', 0) or 0)))
        urls.extend(f"https://archive.org/download/{quote(ident)}/{quote(f['name'])}" for f in candidates[:3])
        provenance['internet_archive_id'] = ident
    elif kind == 'github':
        repo, branch = resolver['repo'], resolver.get('branch', 'master')
        data = json_fetch(fetcher, f'https://api.github.com/repos/{repo}/commits/{quote(branch, safe="")}')
        sha = data['sha']
        if not re.fullmatch(r'[0-9a-fA-F]{40,64}', sha):
            raise ValueError('Invalid Git commit identifier returned.')
        urls.append(f'https://codeload.github.com/{repo}/zip/{sha}')
        provenance.update(github_repository=repo, github_commit=sha)
    else:
        raise ValueError(f'Unknown resolver: {kind}')
    urls = list(dict.fromkeys(u for u in urls if u.startswith(('http://', 'https://'))))
    if not urls:
        raise ValueError('No explicit matching download link resolved; manual inspection is needed.')
    return urls, cache, provenance


def saved_file(path: Path, output: Path, role: str) -> dict[str, Any]:
    return {'path': path.relative_to(output).as_posix(), 'role': role,
            'bytes': path.stat().st_size, 'sha256': file_digest(path)}


def existing_receipt(receipt_path: Path, output: Path) -> dict[str, Any] | None:
    try:
        data = json.loads(receipt_path.read_text(encoding='utf-8'))
        if not data.get('files'):
            return None
        for f in data['files']:
            p = safe_member(f['path'], output)
            if not p.is_file() or p.is_symlink() or file_digest(p) != f['sha256']:
                return None
        data['resumed'] = True
        return data
    except (OSError, ValueError, KeyError):
        return None


def store_asset(record: dict[str, Any], asset: dict[str, Any], data: bytes,
                meta: dict[str, Any], provenance: dict[str, Any], base: Path, output: Path) -> dict[str, Any]:
    aid, kind = slug(asset['id']), asset['kind']
    files: list[dict[str, Any]] = []
    warnings: list[str] = []
    if kind == 'pdf':
        if not is_pdf(data):
            raise ValueError('Not a complete PDF: PDF header / EOF missing (possibly login, error, or truncated data).')
        path = base / ('paper.pdf' if aid == 'pdf' else aid + '.pdf')
        path.write_bytes(data)
        files.append(saved_file(path, output, 'pdf'))
    elif kind in ('source', 'github_bundle'):
        # Validation and extraction occur in a temporary folder before anything is accepted.
        with tempfile.TemporaryDirectory(prefix='radical-source-') as temp:
            temp_root = Path(temp)
            extension, members, warnings = extract_source(data, temp_root)
            dest = base / ('source' if kind == 'source' else 'source-snapshot')
            if dest.exists():
                if dest.is_symlink():
                    raise ValueError('Refusing an existing symlink source directory.')
                shutil.rmtree(dest)
            shutil.copytree(temp_root, dest)
            path = base / (aid + extension)
            path.write_bytes(data)
            files.append(saved_file(path, output, 'original_source_response'))
            for member in members:
                p = dest / member.relative_to(temp_root)
                role = 'tex' if p.suffix.lower() in ('.tex', '.ltx') else 'source_member'
                files.append(saved_file(p, output, role))
            if kind == 'github_bundle':
                main_pdfs = sorted(dest.rglob('Elements.pdf'))
                if main_pdfs:
                    body = main_pdfs[0].read_bytes()
                    if not is_pdf(body):
                        raise ValueError('The main PDF bundled with the source is not a complete PDF.')
                    paired = base / 'paper.pdf'
                    paired.write_bytes(body)
                    files.append(saved_file(paired, output, 'pdf'))
                else:
                    warnings.append('No Elements.pdf was found in this source snapshot; source retrieved, PDF not paired.')
    elif kind in ('web', 'source_code'):
        head = data[:4096].decode('utf-8', errors='replace')
        html_like = bool(re.search(r'<(?:!doctype\s+html|html|head)\b', head, re.I))
        if kind == 'web':
            if not html_like:
                raise ValueError('Expected an HTML web page; received another format.')
            title = re.search(r'<title[^>]*>(.*?)</title>', head, re.I | re.S)
            if title and re.search(r'just a moment|access denied|verify you are human|attention required', title[1], re.I):
                raise ValueError('Challenge / denial page returned, not saved as a resource.')
            extension = '.html'
        else:
            if html_like or b'\x00' in data[:4096]:
                raise ValueError('Expected program source text; received HTML or binary data.')
            extension = Path(unquote(urlsplit(meta['resolved_url']).path)).suffix.lower()
            if extension not in ('.py', '.mac', '.lisp', '.spad', '.input', '.txt', '.c', '.h', '.rst', '.md'):
                extension = '.txt'
        path = base / (aid + extension)
        path.write_bytes(data)
        files.append(saved_file(path, output, kind))
    else:
        raise ValueError(f'Unsupported asset kind: {kind}')
    return {'record_id': record['id'], 'title': record['title'], 'asset_id': asset['id'],
            'version': asset['version'], 'kind': kind, 'status': 'downloaded',
            'retrieval': meta, 'resolution': provenance, 'catalog_evidence_level': asset['evidence_level'],
            'note': asset.get('note', ''), 'warnings': warnings, 'files': files}


def download_asset(record: dict[str, Any], asset: dict[str, Any], fetcher: Fetcher, output: Path) -> dict[str, Any]:
    prefix = 'web_resources' if record['category'] == 'web_resource' else 'papers'
    base = output / prefix / (slug(record['id']) + '-' + slug(record['title'])) / slug(asset['version'])
    base.mkdir(parents=True, exist_ok=True)
    receipt = base / ('.' + slug(asset['id']) + '.receipt.json')
    old = existing_receipt(receipt, output)
    if old:
        return old
    write_json(base / 'bibliography.json', {'id': record['id'], 'title': record['title'], 'citations': record['citations'], 'notes': record['notes']})
    urls, cache, provenance = resolve_asset(asset, fetcher)
    errors: list[str] = []
    for url in urls:
        try:
            data, meta = cache[url] if url in cache else fetcher.fetch(url)
            result = store_asset(record, asset, data, meta, provenance, base, output)
            result['prior_candidate_errors'] = errors
            write_json(receipt, result)
            return result
        except (OSError, ValueError, RuntimeError, tarfile.TarError, zipfile.BadZipFile) as exc:
            errors.append(f'{url}: {type(exc).__name__}: {exc}')
    raise RuntimeError(' | '.join(errors) or 'No downloadable candidate.')


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--catalog', type=Path, default=SCRIPT_DIR / 'catalog.json')
    p.add_argument('--output', type=Path, default=SCRIPT_DIR / 'literature')
    p.add_argument('--zip', dest='zip_path', type=Path, help='ZIP the successfully downloaded files plus manifests; no ZIP is made on zero success.')
    p.add_argument('--only', help='Comma-separated catalog IDs, e.g. cavallo,barbero,landauMiller')
    p.add_argument('--dry-run', action='store_true', help='List planned assets; make no network requests and no output files.')
    p.add_argument('--include-candidates', action='store_true', help='Also attempt unverified / potentially restricted URLs, without authentication or bypass.')
    p.add_argument('--no-web', action='store_true', help='Skip web-resource records, but retain books such as Euclid.')
    p.add_argument('--timeout', type=float, default=35.0)
    p.add_argument('--retries', type=int, default=1)
    p.add_argument('--max-mb', type=float, default=256.0)
    p.add_argument('--delay', type=float, default=0.5)
    p.add_argument('--insecure-hosts', default='', help='Comma-separated hosts for which TLS certificate verification is skipped (opt-in; recorded in provenance).')
    p.add_argument('--user-agent', default=USER_AGENT, help='User-Agent header to send (recorded in provenance). Some public sites reject non-browser agents.')
    p.add_argument('--insecure', action='store_true', help='Skip TLS certificate verification for ALL hosts (recorded in provenance). Use only when the local trust store is known to be incomplete.')
    args = p.parse_args(argv)
    if args.timeout <= 0 or args.retries < 0 or args.max_mb <= 0 or args.delay < 0:
        p.error('Timeout/size must be positive; retries/delay must be nonnegative.')
    catalog = json.loads(args.catalog.read_text(encoding='utf-8'))
    records = catalog['records']
    selected = set(filter(None, (args.only or '').split(',')))
    unknown = selected - {r['id'] for r in records}
    if unknown:
        p.error('Unknown record IDs: ' + ', '.join(sorted(unknown)))
    records = [r for r in records if (not selected or r['id'] in selected) and not (args.no_web and r['category'] == 'web_resource')]
    plans: list[tuple[dict[str, Any], dict[str, Any]]] = []
    skipped: list[dict[str, Any]] = []
    for r in records:
        for a in r['assets']:
            candidate = a['evidence_level'] == 'candidate_unverified' or not a.get('enabled', True)
            if candidate and not args.include_candidates:
                skipped.append({'record_id': r['id'], 'asset_id': a['id'], 'reason': 'candidate disabled; use --include-candidates'})
            else:
                plans.append((r, a))
    if args.dry_run:
        for r, a in plans:
            print(f"{r['id']:16} {a['kind']:14} {a['version']:30} {a['id']}")
            for u in a.get('urls', []):
                print('  ' + u)
            if a.get('resolver'):
                print('  resolver: ' + json.dumps(a['resolver']))
        print(f'\n{len(plans)} planned assets; {len(skipped)} optional candidates skipped. NO NETWORK REQUESTS MADE.')
        return 0

    output = args.output.resolve()
    if output == SCRIPT_DIR:
        p.error('--output must be a separate directory, not the retrieval-package directory itself.')
    output.mkdir(parents=True, exist_ok=True)
    fetcher = Fetcher(args.timeout, args.retries, int(args.max_mb * 1024 * 1024), args.delay,
                      set(filter(None, args.insecure_hosts.split(','))), args.insecure, args.user_agent)
    results: list[dict[str, Any]] = []
    start = utcnow()
    interrupted = False
    try:
        for index, (r, a) in enumerate(plans, 1):
            print(f"[{index}/{len(plans)}] {r['id']} / {a['id']}", flush=True)
            try:
                result = download_asset(r, a, fetcher, output)
                print('  ' + ('RESUMED' if result.get('resumed') else 'DOWNLOADED'), flush=True)
            except (OSError, ValueError, RuntimeError, KeyError, tarfile.TarError, zipfile.BadZipFile) as exc:
                result = {'record_id': r['id'], 'asset_id': a['id'], 'kind': a['kind'], 'version': a['version'],
                          'status': 'failed', 'error': f'{type(exc).__name__}: {exc}'}
                print('  FAILED: ' + str(exc)[:220], flush=True)
            results.append(result)
            write_json(output / 'download_manifest.json', {'started': start, 'updated': utcnow(), 'results': results, 'skipped': skipped})
            write_json(output / 'request_log.json', fetcher.log)
    except KeyboardInterrupt:
        interrupted = True
        print('\nInterrupted. Verified completed files can be resumed by repeating the command.', file=sys.stderr)

    successes = [r for r in results if r['status'] == 'downloaded']
    files = {f['path']: f for r in successes for f in r['files']}
    totals = {'successful_assets': len(successes), 'failed_assets': sum(r['status'] == 'failed' for r in results),
              'pdf_files': sum(f['role'] == 'pdf' for f in files.values()),
              'tex_files': sum(f['role'] == 'tex' for f in files.values()),
              'records_with_downloads': len({r['record_id'] for r in successes}),
              'selected_records_without_any_asset_route': [r['id'] for r in records if not r['assets']],
              'candidate_assets_skipped': len(skipped), 'interrupted': interrupted}
    write_json(output / 'download_manifest.json', {'started': start, 'finished': utcnow(), 'totals': totals,
        'results': results, 'skipped': skipped,
        'limitations': 'Success means response-format validation, not scholarly identity validation or proof of exhaustive coverage. Failed and unlocated items remain unresolved.'})
    write_json(output / 'request_log.json', fetcher.log)
    write_json(output / 'catalog_used.json', catalog)
    with (output / 'download_status.csv').open('w', newline='', encoding='utf-8-sig') as f:
        w = csv.DictWriter(f, fieldnames=['record_id', 'asset_id', 'kind', 'version', 'status', 'error'])
        w.writeheader()
        for r in results:
            w.writerow({k: r.get(k, '') for k in w.fieldnames})
    (output / 'README.txt').write_text('This directory contains actual downloaded responses and provenance.\n'
        'See download_manifest.json for precise success/failure and version information.\n'
        'HTML pages are not PDFs. Source archives are untrusted: review before compiling or executing.\n'
        'Not every bibliographic record is available, and retrieval is not a proof of completeness.\n' + json.dumps(totals, indent=2) + '\n', encoding='utf-8')
    if args.zip_path and successes:
        target = args.zip_path.resolve()
        target.parent.mkdir(parents=True, exist_ok=True)
        archive_files = set(files)
        for name in ['download_manifest.json', 'download_status.csv', 'request_log.json', 'catalog_used.json', 'README.txt']:
            archive_files.add(name)
        for rel in list(files):
            # Include each successful folder's citation metadata and resume receipts.
            parent = (output / rel).parent
            while parent != output and output in parent.parents:
                if (parent / 'bibliography.json').is_file():
                    archive_files.add((parent / 'bibliography.json').relative_to(output).as_posix())
                    archive_files.update(q.relative_to(output).as_posix() for q in parent.glob('.*.receipt.json'))
                parent = parent.parent
        with zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
            for rel in sorted(archive_files):
                path = safe_member(rel, output)
                if path.resolve() != target:
                    zf.write(path, arcname='literature/' + rel)
        print(f'ZIP: {target} ({target.stat().st_size:,} bytes)')
    elif args.zip_path:
        print('NO ZIP CREATED: no external asset was successfully retrieved.', file=sys.stderr)
    print(json.dumps(totals, indent=2))
    if interrupted:
        return 130
    return 0 if successes and not totals['failed_assets'] else 2


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError) as exc:
        print(f'Error: {exc}', file=sys.stderr)
        sys.exit(1)
