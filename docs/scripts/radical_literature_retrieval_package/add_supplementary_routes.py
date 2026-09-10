#!/usr/bin/env python3
"""Add download routes to catalog.json that only the sibling download kit knew about.

Idempotent: an asset is added only if its id is not already present on the record.
Sources: docs/scripts/radical_denesting_download_kit/manifest.json (routes verified
there by search or page inspection). Run once, then re-run download_all.py; completed
assets are resumed from their receipts, so only the new routes are attempted.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
CATALOG = HERE / 'catalog.json'

SUPPLEMENT = {
    'fateman72': [{
        'id': 'pdf-csail-direct', 'kind': 'pdf', 'version': 'mit-lcs-tr-095-csail',
        'urls': ['https://publications.csail.mit.edu/lcs/pubs/pdf/MIT-LCS-TR-095.pdf'],
        'evidence_level': 'search_indexed_pdf', 'enabled': True,
        'note': 'Direct CSAIL publication server copy of MIT-LCS-TR-095 (route from the download kit); avoids the archive.org rate limit.'}],
    'antipov': [{
        'id': 'pdf-mathnet', 'kind': 'pdf', 'version': 'mathnet-vspua-180',
        'urls': ['https://www.mathnet.ru/php/getFT.phtml?jrnid=vspua&option_lang=rus&paperid=180&what=fullt'],
        'evidence_level': 'candidate_unverified', 'enabled': True,
        'note': 'MathNet full text vspua180 (route from the download kit). The kit and this package differ on whether it is the cited Antipov--Pimenov paper; verify the title after download.'}],
    'krepkii': [{
        'id': 'pdf-spbu', 'kind': 'pdf', 'version': 'spbu-journal-11190',
        'urls': ['https://math-mech-astr-journal.spbu.ru/article/download/11190/7872/34789'],
        'evidence_level': 'search_indexed_pdf', 'enabled': True,
        'note': 'Vestnik SPbU Mathematics article download endpoint (route from the download kit).'}],
    'barbero': [
        {'id': 'pdf-arxiv', 'kind': 'pdf', 'version': 'arxiv-1401.1474v1',
         'urls': ['https://arxiv.org/pdf/1401.1474v1'],
         'evidence_level': 'repository_pdf_and_source_links', 'enabled': True,
         'note': 'arXiv preprint version, pinned to v1 (route from the download kit); the JIS publisher version is a separate asset.'},
        {'id': 'tex-source-arxiv', 'kind': 'source', 'version': 'arxiv-1401.1474v1',
         'urls': ['https://arxiv.org/src/1401.1474v1', 'https://arxiv.org/e-print/1401.1474v1'],
         'evidence_level': 'repository_pdf_and_source_links', 'enabled': True,
         'note': 'arXiv submission source for the same pinned version v1.'}],
}


def main() -> int:
    catalog = json.loads(CATALOG.read_text(encoding='utf-8'))
    by_id = {r['id']: r for r in catalog['records']}
    added = 0
    for rid, assets in SUPPLEMENT.items():
        record = by_id.get(rid)
        if record is None:
            print('record not found, skipped:', rid)
            continue
        present = {a['id'] for a in record['assets']}
        for asset in assets:
            if asset['id'] in present:
                continue
            record['assets'].append(asset)
            added += 1
            print('added', rid, '/', asset['id'])
    if added:
        CATALOG.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(f'{added} asset(s) added')
    return 0


if __name__ == '__main__':
    sys.exit(main())
