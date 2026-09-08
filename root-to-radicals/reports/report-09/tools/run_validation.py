from __future__ import annotations
import json
from datetime import datetime, timezone
from pathlib import Path
import platform
import sys
from time import perf_counter
import unittest
import sympy
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'python'))
class RecordedResult(unittest.TextTestResult):
    def __init__(self,*args,**kwargs):
        super().__init__(*args,**kwargs);self.records=[]
    def startTest(self,test):
        self.clock=perf_counter();self.status='PASS';super().startTest(test)
    def addError(self,test,err):self.status='ERROR';super().addError(test,err)
    def addFailure(self,test,err):self.status='FAIL';super().addFailure(test,err)
    def addSkip(self,test,reason):self.status='SKIP';super().addSkip(test,reason)
    def stopTest(self,test):
        self.records.append({'test':test.id(),'status':self.status,'seconds':round(perf_counter()-self.clock,6)})
        super().stopTest(test)
suite=unittest.defaultTestLoader.discover(str(ROOT/'tests'),pattern='test_*.py')
result=unittest.TextTestRunner(verbosity=2,resultclass=RecordedResult).run(suite)
report={'python':sys.version,'sympy':sympy.__version__,'platform':platform.platform(),
        'date':datetime.now(timezone.utc).date().isoformat(),'tests_run':result.testsRun,'successful':result.wasSuccessful(),
        'tests':result.records,'wolfram_kernel_tests':'NOT RUN: evaluator connector returned HTTP 404; no local kernel'}
(ROOT/'validation'/'test-results.json').write_text(json.dumps(report,indent=2))
raise SystemExit(0 if result.wasSuccessful() else 1)
