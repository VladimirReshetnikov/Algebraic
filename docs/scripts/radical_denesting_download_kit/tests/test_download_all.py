"""Offline tests only. All document bytes below are synthetic, not publications."""
import contextlib
import gzip
import io
import json
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import download_all as d

TEX = b'\\documentclass{article}\n\\begin{document}Synthetic test.\\end{document}\n'
PDF = b'%PDF-1.4\n% Synthetic format-test fixture, not a complete renderable document.\n%%EOF\n'

class MockFetcher:
    def __init__(self, responses):
        self.responses = responses
        self.calls = []
    def get(self, url):
        self.calls.append(url)
        value = self.responses[url]
        if isinstance(value, Exception):
            raise value
        return value, url, 'application/octet-stream'

def tar_bytes(members):
    b=io.BytesIO()
    with tarfile.open(fileobj=b, mode='w:gz') as t:
        for name, content in members:
            item=tarfile.TarInfo(name)
            item.size=len(content)
            t.addfile(item,io.BytesIO(content))
    return b.getvalue()

class FormatTests(unittest.TestCase):
    def test_pdf_checks(self):
        d.validate(PDF,'pdf')
        for payload in (b'',b'%PDF-1.4\ntruncated',b'<!doctype html><html>%PDF- %%EOF</html>'):
            with self.assertRaises(ValueError): d.validate(payload,'pdf')
    def test_challenge_rejected(self):
        with self.assertRaises(ValueError):
            d.validate(b'<html><title>Just a moment</title></html>','html')
    def test_source_text_not_html(self):
        d.validate(TEX,'text')
        with self.assertRaises(ValueError):d.validate(b'<html><title>Source</title></html>','text')
    def test_page_download_resolution(self):
        page=b'<html><meta name="citation_pdf_url" content="paper.pdf"><a href="paper.tex">LaTeX</a><a href="other.pdf">An unrelated reference</a></html>'
        self.assertEqual(d.resolve_candidates(page,'https://example.org/item/','pdf'),['https://example.org/item/paper.pdf'])
        self.assertEqual(d.resolve_candidates(page,'https://example.org/item/','tex'),['https://example.org/item/paper.tex'])
        self.assertEqual(d.resolve_candidates(page,'https://example.org/item/','pdf',['forbidden']),[])
    def test_obtain_fallback_and_resolver(self):
        f=MockFetcher({'https://example.org/bad':b'<html><title>Not found</title></html>', 'https://example.org/item':b'<html><a href="paper.pdf">PDF</a></html>', 'https://example.org/paper.pdf':PDF})
        data,url,errors=d.obtain(f,['https://example.org/bad','https://example.org/item'],'pdf','pdf')
        self.assertEqual(data,PDF);self.assertEqual(url,'https://example.org/paper.pdf');self.assertEqual(len(errors),1)

class SourceSafetyTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
    def tearDown(self):self.temp.cleanup()
    def test_tar_preserves_source_dependencies(self):
        data=tar_bytes([('project/main.tex',TEX),('project/bib.bib',b'@book{test}'),('project/fig.dat',b'123')])
        suffix,files=d.unpack_source(data,self.root)
        self.assertEqual(suffix,'.tar.gz');self.assertEqual(len(files),3)
        self.assertEqual((self.root/'project/main.tex').read_bytes(),TEX)
    def test_plain_and_gz_source(self):
        suffix,files=d.unpack_source(TEX,self.root/'plain','https://example.org/original.tex')
        self.assertEqual(suffix,'.tex');self.assertEqual(files[0].name,'original.tex')
        suffix,files=d.unpack_source(gzip.compress(TEX),self.root/'gz')
        self.assertEqual(suffix,'.tex.gz');self.assertEqual(files[0].read_bytes(),TEX)
    def test_tar_traversal(self):
        with self.assertRaises(ValueError):d.unpack_source(tar_bytes([('../escaped.tex',TEX)]),self.root)
        self.assertFalse((self.root.parent/'escaped.tex').exists())
    def test_tar_link_rejected(self):
        b=io.BytesIO()
        with tarfile.open(fileobj=b,mode='w') as t:
            x=tarfile.TarInfo('main.tex');x.type=tarfile.SYMTYPE;x.linkname='/tmp/elsewhere';t.addfile(x)
        with self.assertRaises(ValueError):d.unpack_source(b.getvalue(),self.root)
    def test_zip_traversal(self):
        b=io.BytesIO()
        with zipfile.ZipFile(b,'w') as z:z.writestr('../main.tex',TEX)
        with self.assertRaises(ValueError):d.unpack_source(b.getvalue(),self.root)
    def test_archive_without_tex_rejected(self):
        with self.assertRaises(ValueError):d.unpack_source(tar_bytes([('paper.pdf',PDF)]),self.root)
    def test_unsafe_paths(self):
        for name in ('../outside','/absolute','C:/Windows','a\\b','a/../../x','nul\x00name'):
            with self.assertRaises(ValueError):d.safe_path(self.root,name)

class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name)
        self.entry={'id':'test','folder':'001_test','title':'Synthetic test','notes':[],'cited_in':['test:1'],'discovery_pages':[],'search_status':'test'}
        self.manifest={'entries':[self.entry]}
        self.out=io.StringIO();self.capture=contextlib.redirect_stdout(self.out);self.capture.__enter__()
    def tearDown(self):self.capture.__exit__(None,None,None);self.temp.cleanup()
    def test_version_pinning(self):
        f=MockFetcher({'https://arxiv.org/abs/2511.02498':b'<html><title>Test</title>[v1] [v3] [v2]</html>'})
        self.assertEqual(d.pin_arxiv(f,'2511.02498'),'2511.02498v3')
        self.assertEqual(d.pin_arxiv(f,'2511.02498v1'),'2511.02498v1')
        self.assertEqual(len(f.calls),1)
    def test_no_version_refuses_pair(self):
        f=MockFetcher({'https://arxiv.org/abs/2511.02498':b'<html><title>Test</title>No versions</html>'})
        with self.assertRaises(ValueError):d.pin_arxiv(f,'2511.02498')
    def test_download_resume_and_modified_retry(self):
        u='https://example.org/paper.pdf';f=MockFetcher({u:PDF});r=d.Runner(self.root,self.manifest,f)
        a={'id':'paper','kind':'pdf','filename':'paper.pdf','urls':[u]}
        r.single(self.entry,a);r.single(self.entry,a)
        self.assertEqual(len(f.calls),1)
        self.assertEqual(r.state['assets']['test:paper']['status'],'resumed')
        (self.root/'001_test/paper.pdf').write_bytes(b'modified');r.single(self.entry,a)
        self.assertEqual(len(f.calls),2)
    def test_failure_records_no_download(self):
        u='https://example.org/paper.pdf';f=MockFetcher({u:OSError('offline fixture')});r=d.Runner(self.root,self.manifest,f)
        r.single(self.entry,{'id':'paper','kind':'pdf','filename':'paper.pdf','urls':[u]})
        self.assertEqual(r.state['assets']['test:paper']['status'],'failed')
        self.assertFalse((self.root/'001_test/paper.pdf').exists())
        r.report();summary=json.loads((self.root/'SUMMARY.json').read_text())
        self.assertEqual(summary['PDF_files'],0);self.assertEqual(summary['failed_tasks'],1)
    def test_arxiv_matching_paths_and_bytes(self):
        pid='2511.02498v1';f=MockFetcher({'https://arxiv.org/pdf/'+pid:PDF,'https://arxiv.org/src/'+pid:tar_bytes([('article.tex',TEX)])})
        r=d.Runner(self.root,self.manifest,f);r.arxiv(self.entry,{'id':'arxiv','arxiv_id':pid})
        base=self.root/'001_test/arxiv'/pid
        self.assertEqual((base/'paper.pdf').read_bytes(),PDF)
        self.assertEqual((base/'source/article.tex').read_bytes(),TEX)
        self.assertTrue((base/'source_original.tar.gz').is_file())
        self.assertEqual(len(r.state['assets']),2)
    def test_zip_contains_only_output_files(self):
        output=self.root/'collection';output.mkdir();(output/'README.md').write_text('test');(output/'unfinished.partial').write_text('partial')
        archive=self.root/'collection.zip';d.create_zip(output,archive)
        with zipfile.ZipFile(archive) as z:
            self.assertEqual(z.namelist(),['collection/README.md']);self.assertIsNone(z.testzip())

if __name__=='__main__':unittest.main()
