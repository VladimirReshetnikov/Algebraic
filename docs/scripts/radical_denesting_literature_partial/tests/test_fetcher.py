"""Offline tests. Run: python -m unittest discover -s tests -v"""
from pathlib import Path
import functools
import gzip
import http.server
import importlib.util
import io
import json
import sys
import tarfile
import tempfile
import threading
import unittest
import zipfile

MODULE = Path(__file__).resolve().parents[1] / 'fetch_literature.py'
spec = importlib.util.spec_from_file_location('fetcher', MODULE)
f = importlib.util.module_from_spec(spec)
spec.loader.exec_module(f)
TEX = b'\\documentclass{article}\n\\begin{document}A source file.\\end{document}\n'
PDF = b'%PDF-1.4\nThis is a signature-check fixture, not a renderable PDF.\n%%EOF\n'

class FetcherTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
    def tearDown(self):
        self.tmp.cleanup()
    def test_pdf_rejection(self):
        self.assertTrue(f.is_pdf(PDF))
        self.assertFalse(f.is_pdf(b'<html>Subscription required</html>'))
        self.assertFalse(f.is_pdf(b'%PDF-1.4 truncated'))
        with self.assertRaises(ValueError):
            f.validate(b'<html>Login</html>', 'pdf', 'https://example.test/login')
    def test_plain_and_gzip_tex(self):
        for n,payload in [('plain',TEX),('compressed',gzip.compress(TEX))]:
            out = f.unpack_source(payload, self.root/n, self.root/(n+'_files'))
            self.assertEqual(out['tex_count'],1)
            self.assertEqual((self.root/(n+'_files')/'main.tex').read_bytes(),TEX)
            self.assertEqual(out['path'].read_bytes(),payload)
    def test_tar_and_auxiliary_file(self):
        b=io.BytesIO()
        with tarfile.open(fileobj=b,mode='w:gz') as t:
            for name,payload in [('article/main.tex',TEX),('article/refs.bib',b'@book{x,title={Example}}')]:
                info=tarfile.TarInfo(name);info.size=len(payload);t.addfile(info,io.BytesIO(payload))
        out=f.unpack_source(b.getvalue(),self.root/'source',self.root/'expanded')
        self.assertEqual(out['tex_count'],1)
        self.assertEqual(len(out['extracted_files']),2)
        self.assertTrue((self.root/'expanded/article/refs.bib').is_file())
    def test_archive_traversal_rejected_before_write(self):
        b=io.BytesIO()
        with tarfile.open(fileobj=b,mode='w:gz') as t:
            info=tarfile.TarInfo('../escape.tex');info.size=len(TEX);t.addfile(info,io.BytesIO(TEX))
        with self.assertRaises(ValueError):
            f.unpack_source(b.getvalue(),self.root/'source',self.root/'expanded')
        self.assertFalse((self.root/'escape.tex').exists())
        self.assertFalse((self.root/'source.tar.gz').exists())
    def test_zip_source(self):
        b=io.BytesIO()
        with zipfile.ZipFile(b,'w') as z:z.writestr('main.tex',TEX)
        out=f.unpack_source(b.getvalue(),self.root/'source',self.root/'expanded')
        self.assertEqual(out['source_kind'],'zip')
        self.assertEqual(out['tex_count'],1)
    def test_pdf_only_source(self):
        out=f.unpack_source(PDF,self.root/'source',self.root/'expanded')
        self.assertEqual(out['source_kind'],'pdf_only')
        self.assertEqual(out['tex_count'],0)
        self.assertFalse((self.root/'expanded').exists())
    def test_local_http_and_resume(self):
        served=self.root/'served';served.mkdir()
        (served/'paper.pdf').write_bytes(PDF)
        class Quiet(http.server.SimpleHTTPRequestHandler):
            def log_message(self,*args):pass
        handler=functools.partial(Quiet,directory=str(served))
        server=http.server.ThreadingHTTPServer(('127.0.0.1',0),handler)
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        try:
            url=f'http://127.0.0.1:{server.server_port}/paper.pdf'
            item={'id':'example','folder':'001_example','kind':'literature'}
            asset={'filename':'paper.pdf','role':'pdf','urls':[url]}
            client=f.Client(timeout=3,retries=0,delay=0)
            out=f.run_asset(self.root,item,asset,client,{})
            self.assertTrue(out['ok'])
            self.assertEqual((self.root/out['path']).read_bytes(),PDF)
            prior={f.asset_key('example',asset):out}
            again=f.run_asset(self.root,item,asset,client,prior)
            self.assertTrue(again['reused'])
        finally:
            server.shutdown();server.server_close();thread.join(timeout=3)
    def test_package_zip(self):
        root=self.root/'package';root.mkdir();(root/'hello.txt').write_text('hello')
        target=self.root/'out.zip';f.make_zip(root,target)
        with zipfile.ZipFile(target) as z:
            self.assertEqual(z.read('radical_denesting_literature/hello.txt'),b'hello')
            self.assertIsNone(z.testzip())

if __name__=='__main__':unittest.main()
