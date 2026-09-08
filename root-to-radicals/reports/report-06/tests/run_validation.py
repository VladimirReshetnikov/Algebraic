"""Run the suite and write the machine-readable record shipped with the archive."""
from pathlib import Path
import sys,unittest,time,json,platform
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'python'));sys.path.insert(0,str(ROOT/'tests'))
import sympy
import test_rootradicals as tests
class RecordingResult(unittest.TextTestResult):
    def startTest(self,test):super().startTest(test);self.started=time.monotonic()
    def stopTest(self,test):
        records.append({'test':test.id(),'seconds':round(time.monotonic()-self.started,6),
                        'passed':not any(t is test for t,_ in self.failures+self.errors)})
        super().stopTest(test)
records=[]
result=unittest.TextTestRunner(verbosity=2,resultclass=RecordingResult).run(tests.load_tests(None,None,None))
report={'python':platform.python_version(),'sympy':sympy.__version__,'platform':platform.platform(),
        'date':'2026-09-08','tests_run':result.testsRun,'failures':len(result.failures),
        'errors':len(result.errors),'success':result.wasSuccessful(),'records':records,
        'wolfram_kernel_tests':'Not executed: the available Wolfram service returned HTTP 404.'}
(ROOT/'validation'/'test-report.json').write_text(json.dumps(report,indent=2)+'\n')
raise SystemExit(0 if result.wasSuccessful() else 1)
