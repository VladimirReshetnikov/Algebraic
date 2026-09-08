#!/usr/bin/env python3
"""Unpacked-archive entry point; optionally supervises a hard-deadline worker.

max_seconds is a cooperative in-algorithm budget. hard_timeout_seconds applies
to this entry point only and kills an isolated worker even inside a CAS call.
"""
import io,json,math,subprocess,sys,time
from pathlib import Path

def main():
    payload=sys.stdin.read()
    if '--worker' not in sys.argv:
        try:
            data=json.loads(payload)
            limit=data.get('hard_timeout_seconds') if isinstance(data,dict) else None
        except (ValueError,TypeError):
            limit=None
        if limit is not None:
            if (isinstance(limit,bool) or not isinstance(limit,(int,float)) or
                    not math.isfinite(limit) or limit<=0):
                print(json.dumps({'status':'InvalidInput','message':'hard_timeout_seconds must be finite and positive.'}))
                return 2
            start=time.monotonic()
            try:
                p=subprocess.run([sys.executable,str(Path(__file__).resolve()),'--worker'],
                    input=payload,text=True,capture_output=True,timeout=limit)
            except subprocess.TimeoutExpired:
                print(json.dumps({'status':'ResourceLimit',
                    'message':'The isolated backend worker exceeded its hard deadline.',
                    'details':{'limit_seconds':limit},'elapsed_seconds':time.monotonic()-start}))
                return 2
            sys.stdout.write(p.stdout);sys.stderr.write(p.stderr)
            return p.returncode
    sys.stdin=io.StringIO(payload)
    from radicalsolve.__main__ import main as worker_main
    return worker_main()

if __name__=='__main__':raise SystemExit(main())
