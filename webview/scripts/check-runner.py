#!/usr/bin/env python3
import pathlib, subprocess
root=pathlib.Path(__file__).resolve().parents[1]
result=subprocess.run(['sbcl','--script',str(root/'tests/runner-failure.lisp')],
                      stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
                      encoding='utf-8',errors='replace',timeout=90)
if result.returncode==0 or 'intentional CI runner failure' not in result.stdout:
    print(result.stdout)
    raise SystemExit('Native runner did not propagate the intended failure as a nonzero process exit')
print('PASS: native runner failures produce a nonzero process exit.')
