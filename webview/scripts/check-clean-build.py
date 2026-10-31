#!/usr/bin/env python3
"""Cold-cache compilation must not report undefined variables or functions."""
import os, pathlib, re, subprocess, tempfile
root=pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='lut-clean-build-') as cache:
    result=subprocess.run(['sbcl','--script',str(root/'tests/compile-clean.lisp')],
      env={**os.environ,'LUT_WEBVIEW_CACHE':cache},stdout=subprocess.PIPE,
      stderr=subprocess.STDOUT,encoding='utf-8',errors='replace',timeout=180)
    if result.returncode or re.search(r'undefined\s+(?:variables?|functions?)\b',result.stdout,re.I):
        print(result.stdout)
        raise SystemExit('Fresh compilation failed or reported undefined symbols')
    print(result.stdout.strip())
    print('PASS: fresh-cache build has no undefined-variable/function warnings.')
