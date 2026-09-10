#!/usr/bin/env python3
"""Register a manually obtained file in the literature output directory.

Used when a route failed for the downloader (rate limit, bot block) but the file
was fetched by hand from the same URL. The file is copied into the record's
version folder, a receipt with its SHA-256 is written, and download_manifest.json
and download_status.csv are updated so that the manifest stays the single
authoritative account of what the dataset contains and where it came from.

Example:
  python register_manual_file.py --output ../../literature --record fateman72 \
      --asset pdf --version mit-lcs-tr-095-archive-org --kind pdf \
      --file "../../articles/MIT-LCS-TR-095.pdf" \
      --url "https://web.archive.org/web/20051217213927id_/http://www.lcs.mit.edu/publications/pubs/pdf/MIT-LCS-TR-095.pdf" \
      --note "Fetched manually via Tor on 2026-09-05 after HTTP 429."
"""
from __future__ import annotations

import argparse
import csv
import json
import shutil
import sys
from pathlib import Path

from download_all import SCRIPT_DIR, digest, is_pdf, slug, utcnow, write_json


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--catalog', type=Path, default=SCRIPT_DIR / 'catalog.json')
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--record', required=True)
    p.add_argument('--asset', required=True, help='asset id in the catalog (or a new id)')
    p.add_argument('--version', required=True)
    p.add_argument('--kind', choices=['pdf'], default='pdf')
    p.add_argument('--file', type=Path, required=True)
    p.add_argument('--url', required=True, help='URL the file was obtained from')
    p.add_argument('--note', default='')
    args = p.parse_args(argv)

    catalog = json.loads(args.catalog.read_text(encoding='utf-8'))
    record = next((r for r in catalog['records'] if r['id'] == args.record), None)
    if record is None:
        p.error(f'unknown record id {args.record!r}')
    data = args.file.read_bytes()
    if args.kind == 'pdf' and not is_pdf(data):
        p.error('the file does not look like a complete PDF')

    output = args.output.resolve()
    prefix = 'web_resources' if record['category'] == 'web_resource' else 'papers'
    base = output / prefix / (slug(record['id']) + '-' + slug(record['title'])) / slug(args.version)
    base.mkdir(parents=True, exist_ok=True)
    aid = slug(args.asset)
    dest = base / ('paper.pdf' if aid == 'pdf' else aid + '.pdf')
    shutil.copyfile(args.file, dest)
    write_json(base / 'bibliography.json', {'id': record['id'], 'title': record['title'],
                                            'citations': record['citations'], 'notes': record['notes']})
    result = {
        'record_id': record['id'], 'title': record['title'], 'asset_id': args.asset,
        'version': args.version, 'kind': args.kind, 'status': 'downloaded',
        'retrieval': {'requested_url': args.url, 'resolved_url': args.url, 'retrieved_at': utcnow(),
                      'method': 'manual download registered by register_manual_file.py',
                      'bytes': len(data), 'sha256': digest(data)},
        'resolution': {}, 'catalog_evidence_level': 'manual_download', 'note': args.note,
        'warnings': [], 'files': [{'path': dest.relative_to(output).as_posix(), 'role': args.kind,
                                   'bytes': len(data), 'sha256': digest(data)}]}
    write_json(base / ('.' + aid + '.receipt.json'), result)

    manifest_path = output / 'download_manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    manifest['results'] = [r for r in manifest['results']
                           if not (r['record_id'] == args.record and r['asset_id'] == args.asset
                                   and r.get('version') == args.version)]
    manifest['results'].append(result)
    successes = [r for r in manifest['results'] if r['status'] == 'downloaded']
    files = {f['path']: f for r in successes for f in r['files']}
    totals = manifest.get('totals', {})
    totals.update({'successful_assets': len(successes),
                   'failed_assets': sum(r['status'] == 'failed' for r in manifest['results']),
                   'pdf_files': sum(f['role'] == 'pdf' for f in files.values()),
                   'tex_files': sum(f['role'] == 'tex' for f in files.values()),
                   'records_with_downloads': len({r['record_id'] for r in successes})})
    manifest['totals'] = totals
    manifest['updated'] = utcnow()
    write_json(manifest_path, manifest)
    with (output / 'download_status.csv').open('w', newline='', encoding='utf-8-sig') as f:
        w = csv.DictWriter(f, fieldnames=['record_id', 'asset_id', 'kind', 'version', 'status', 'error'])
        w.writeheader()
        for r in manifest['results']:
            w.writerow({k: r.get(k, '') for k in w.fieldnames})
    print('registered', dest.relative_to(output).as_posix(), digest(data)[:16])
    print(json.dumps(totals, indent=1))
    return 0


if __name__ == '__main__':
    sys.exit(main())
