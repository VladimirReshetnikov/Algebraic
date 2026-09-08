"""Run tests and save a machine-readable report beside the textual test log."""
from pathlib import Path
import datetime,json,platform,sys,time,unittest
import sympy
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"tests"))
class Result(unittest.TextTestResult):
    def __init__(self,*a,**kw): super().__init__(*a,**kw);self.records=[]
    def startTest(self,test): self.started=time.monotonic();super().startTest(test)
    def stopTest(self,test):
        status="passed"
        if any(t==test for t,_ in self.failures):status="failed"
        if any(t==test for t,_ in self.errors):status="error"
        self.records.append({"test":test.id(),"status":status,"seconds":time.monotonic()-self.started})
        super().stopTest(test)
suite=unittest.defaultTestLoader.loadTestsFromName("test_systematic_radicals")
t0=time.monotonic()
result=unittest.TextTestRunner(verbosity=2,resultclass=Result).run(suite)
report={"date":datetime.datetime.now(datetime.timezone.utc).isoformat(),"python":sys.version,
        "sympy":sympy.__version__,"platform":platform.platform(),"tests_run":result.testsRun,
        "success":result.wasSuccessful(),"elapsed_seconds":time.monotonic()-t0,"tests":result.records,
        "wolfram_tests":"Provided, but not executed: no usable Wolfram kernel was available."}
(ROOT/"validation"/"python_validation.json").write_text(json.dumps(report,indent=2))
sys.exit(0 if result.wasSuccessful() else 1)
