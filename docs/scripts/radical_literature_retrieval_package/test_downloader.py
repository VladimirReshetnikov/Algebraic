"""Offline tests only. No network or external literature is used."""
import gzip
import io
import json
from pathlib import Path
import stat
import tarfile
import tempfile
import unittest
import zipfile
import download_all as d

TEX = b'% synthetic test, not a paper\n\\documentclass{article}\n\\begin{document}Offline test.\\end{document}\n'
PDF = b'%PDF-1.4\n' + b'% synthetic test, not a paper\n' * 5 + b'%%EOF\n'

class DownloaderTests(unittest.TestCase):
    def test_pdf_validation(self):
        self.assertTrue(d.is_pdf(PDF))
        self.assertFalse(d.is_pdf(b'<html>Subscription required</html>'))
        self.assertFalse(d.is_pdf(PDF.replace(b'%%EOF', b'cut-off')))

    def test_plain_tex(self):
        with tempfile.TemporaryDirectory() as tmp:
            ext, paths, warn = d.extract_source(TEX, Path(tmp))
            self.assertEqual(ext, '.tex')
            self.assertEqual(paths[0].read_bytes(), TEX)

    def test_gzipped_tex(self):
        with tempfile.TemporaryDirectory() as tmp:
            ext, paths, warn = d.extract_source(gzip.compress(TEX), Path(tmp))
            self.assertEqual(ext, '.tex.gz')
            self.assertEqual(paths[0].read_bytes(), TEX)

    def test_tar_gz_source(self):
        b = io.BytesIO()
        with tarfile.open(fileobj=b, mode='w:gz') as tf:
            info = tarfile.TarInfo('article/main.tex'); info.size = len(TEX)
            tf.addfile(info, io.BytesIO(TEX))
        with tempfile.TemporaryDirectory() as tmp:
            ext, paths, warn = d.extract_source(b.getvalue(), Path(tmp))
            self.assertEqual(ext, '.tar.gz')
            self.assertEqual(paths[0].read_bytes(), TEX)

    def test_zip_source(self):
        b = io.BytesIO()
        with zipfile.ZipFile(b, 'w') as z:
            z.writestr('article/main.tex', TEX)
            z.writestr('article/figure.svg', '<svg></svg>')
        with tempfile.TemporaryDirectory() as tmp:
            ext, paths, warn = d.extract_source(b.getvalue(), Path(tmp))
            self.assertEqual(ext, '.zip')
            self.assertEqual(len(paths), 2)

    def test_reject_path_traversal(self):
        for name in ('../escape.tex', '/absolute.tex', '..\\escape.tex', 'C:/escape.tex'):
            b = io.BytesIO()
            with zipfile.ZipFile(b, 'w') as z:
                z.writestr(name, TEX)
            with tempfile.TemporaryDirectory() as tmp:
                with self.assertRaises(ValueError, msg=name):
                    d.extract_source(b.getvalue(), Path(tmp))

    def test_reject_tar_symlink(self):
        b = io.BytesIO()
        with tarfile.open(fileobj=b, mode='w') as tf:
            info = tarfile.TarInfo('escape'); info.type = tarfile.SYMTYPE; info.linkname = '/tmp'
            tf.addfile(info)
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError):
                d.extract_source(b.getvalue(), Path(tmp))

    def test_reject_zip_symlink(self):
        b = io.BytesIO()
        with zipfile.ZipFile(b, 'w') as z:
            info = zipfile.ZipInfo('escape'); info.create_system = 3
            info.external_attr = (stat.S_IFLNK | 0o777) << 16
            z.writestr(info, '/tmp')
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError):
                d.extract_source(b.getvalue(), Path(tmp))

    def test_reject_pdf_as_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError):
                d.extract_source(PDF, Path(tmp))

    def test_reject_archive_without_tex(self):
        b = io.BytesIO()
        with zipfile.ZipFile(b, 'w') as z:
            z.writestr('paper.pdf', PDF)
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError):
                d.extract_source(b.getvalue(), Path(tmp))

    def test_landing_parser(self):
        p = d.DownloadLinks('https://example.org/paper/index.html', 'pdf')
        p.feed('<meta name="citation_pdf_url" content="paper.pdf"><a href="unrelated.pdf">Reference 3</a>')
        self.assertEqual(p.links, ['https://example.org/paper/paper.pdf'])
        p = d.DownloadLinks('https://example.org/paper/index.html', 'source')
        p.feed('<a href="article-source.tex">latex</a>')
        self.assertEqual(p.links, ['https://example.org/paper/article-source.tex'])

    def test_catalog(self):
        catalog = json.loads((Path(__file__).parent/'catalog.json').read_text(encoding='utf-8'))
        self.assertEqual(len(catalog['records']), 105)
        self.assertEqual(catalog['external_files_downloaded_here'], 0)
        for r in catalog['records']:
            for a in r['assets']:
                for url in a.get('urls', []):
                    self.assertTrue(d.checked_url(url).startswith(('http://', 'https://')))
                if 'arxiv_version' in r:
                    self.assertTrue(all(r['arxiv_version'] in u for u in a['urls']))
        self.assertNotIn('PLACEHOLDER', json.dumps(catalog))

    def test_receipt_verification(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp); p=root/'paper.pdf'; p.write_bytes(PDF)
            receipt=root/'receipt.json'
            d.write_json(receipt, {'files':[d.saved_file(p,root,'pdf')]})
            self.assertIsNotNone(d.existing_receipt(receipt,root))
            p.write_bytes(b'damaged')
            self.assertIsNone(d.existing_receipt(receipt,root))

if __name__=='__main__':
    unittest.main(verbosity=2)
