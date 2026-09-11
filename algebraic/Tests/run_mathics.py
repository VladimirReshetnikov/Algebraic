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

Exit code 0 when no test failed or aborted.
"""

from __future__ import annotations

import os
import sys
import time
import traceback

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

    def feed(path):
        """Evaluate every top-level statement of a file; count Python aborts."""
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
                try:
                    evaluation.evaluate(query, timeout=None)
                except Exception as exc:
                    aborted += 1
                    head = (source or "").strip().splitlines()[0][:140] if source else "?"
                    print(f"ABORTED (Python {type(exc).__name__}: {exc}) in: {head}", flush=True)
                    if os.environ.get("ALGEBRAIC_TRACEBACK"):
                        traceback.print_exc()
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
