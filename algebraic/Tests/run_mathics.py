"""Run Algebraic.wlt in Mathics3, one statement at a time.

    python run_mathics.py            # from this directory, or anywhere
    python run_mathics.py other.wlt  # a different suite, same harness

`python -m mathics -f RunTests.wl` also works, but there the whole suite is
one `Get`, and a Python-level exception inside one test -- which Mathics
10.0.1 raises for a handful of constructs the package has to avoid, and which
no `Quiet` or `Check` can catch -- ends the run with no report.  This driver
mirrors the command-line evaluation loop of Mathics and wraps each top-level
statement of the suite in a try/except: an abort is reported as ABORTED with
the test it happened in, and the run continues.  Output is flushed after
every statement, so progress is visible while the run is going.

Each statement also gets a wall-clock limit (ALGEBRAIC_TEST_TIMEOUT
seconds, default 180): the kernel's own TimeConstrained does not stop a
long SymPy computation here, so the driver evaluates in a worker thread
and, past the limit, raises a BaseException in it -- which the
`except Exception` clauses on the way cannot swallow -- and reports the
statement as TIMEOUT.  The kernel's definitions survive; a memo the
statement was filling may be incomplete, which the next statement recomputes.

Exit code 0 when no test failed, aborted or timed out.
"""

from __future__ import annotations

import ctypes
import os
import sys
import threading
import time
import traceback


class HardTimeout(BaseException):
    """Raised inside the evaluation thread when a statement exceeds its limit."""


def async_raise(tid, exc_type):
    res = ctypes.pythonapi.PyThreadState_SetAsyncExc(ctypes.c_ulong(tid), ctypes.py_object(exc_type))
    if res > 1:
        ctypes.pythonapi.PyThreadState_SetAsyncExc(ctypes.c_ulong(tid), None)


def evaluate_bounded(evaluation, query, seconds):
    """Evaluate query; return "ok", "timeout", or the exception raised."""
    outcome = {}

    def run():
        try:
            evaluation.evaluate(query, timeout=None)
            outcome["result"] = "ok"
        except HardTimeout:
            outcome["result"] = "timeout"
        except BaseException as exc:  # reported by the caller
            outcome["result"] = exc

    worker = threading.Thread(target=run, daemon=True)
    worker.start()
    worker.join(seconds)
    if worker.is_alive():
        evaluation.stopped = True          # the cooperative stop first
        worker.join(5)
        deadline = time.time() + 120
        while worker.is_alive() and time.time() < deadline:
            async_raise(worker.ident, HardTimeout)
            worker.join(2)
        evaluation.stopped = False
        if worker.is_alive():
            return "stuck"
        return "timeout"
    return outcome.get("result", "ok")

HERE = os.path.dirname(os.path.abspath(__file__))
SUITE = os.path.join(HERE, "Algebraic.wlt")
HARNESS = os.path.join(HERE, "MathicsHarness.wl")


def main():
    os.chdir(HERE)
    from mathics.core.definitions import Definitions
    from mathics.core.evaluation import Evaluation, Output
    from mathics.core.load_builtin import import_and_load_builtins
    from mathics.core.parser import MathicsFileLineFeeder
    from mathics.eval.files_io.files import set_input_var

    import_and_load_builtins()
    definitions = Definitions(add_builtin=True)
    definitions.set_line_no(0)

    class PlainOutput(Output):
        def max_stored_size(self, output_settings):
            return None

        def out(self, out):
            text = getattr(out, "text", None)
            print(text if text is not None else str(out), flush=True)

    limit = float(os.environ.get("ALGEBRAIC_TEST_TIMEOUT", "180"))

    def feed(path):
        """Evaluate every top-level statement of a file; count Python aborts and timeouts."""
        aborted = 0
        set_input_var(path)
        definitions.set_inputfile(path)
        with open(path, encoding="utf-8") as f:
            feeder = MathicsFileLineFeeder(f)
            while not feeder.empty():
                evaluation = Evaluation(definitions, output=PlainOutput(), catch_interrupt=False)
                try:
                    query, source = evaluation.parse_feeder_returning_code(feeder)
                except Exception as exc:  # a parse failure is reported and skipped
                    print(f"ABORTED while parsing: {type(exc).__name__}: {exc}", flush=True)
                    aborted += 1
                    continue
                if query is None:
                    continue
                outcome = evaluate_bounded(evaluation, query, limit)
                head = (source or "").strip().splitlines()[0][:140] if source else "?"
                if outcome == "timeout":
                    aborted += 1
                    print(f"TIMEOUT (over {limit:.0f} s) in: {head}", flush=True)
                elif outcome == "stuck":
                    aborted += 1
                    print(f"TIMEOUT (over {limit:.0f} s, and the evaluation could not be stopped) in: {head}", flush=True)
                    print("The kernel is no longer usable; stopping here.", flush=True)
                    return aborted
                elif outcome != "ok":
                    aborted += 1
                    print(f"ABORTED (Python {type(outcome).__name__}: {outcome}) in: {head}", flush=True)
                    if os.environ.get("ALGEBRAIC_TRACEBACK"):
                        traceback.print_exception(outcome)
        return aborted

    t0 = time.time()
    feed(HARNESS)
    aborted = feed(os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else SUITE)
    evaluation = Evaluation(definitions, output=PlainOutput(), catch_interrupt=False)
    result = evaluation.parse_evaluate(f"mathicsSummary[{aborted}]", timeout=None)
    failures = result.last_eval if result is not None else None
    print(f"driver wall time: {time.time() - t0:.0f} s", flush=True)
    try:
        bad = int(str(failures))
    except (TypeError, ValueError):
        bad = 1
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
