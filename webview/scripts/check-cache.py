#!/usr/bin/env python3
"""Exercise CRLF build metadata with the same bootstrap shipped to consumers."""
import os, pathlib, shutil, subprocess, tempfile
root=pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='lut-cache-test-') as folder:
    fixture=pathlib.Path(folder)
    (fixture/'webview/scripts').mkdir(parents=True)
    (fixture/'webview/deps').mkdir()
    shutil.copy2(root/'scripts/bootstrap.lisp',fixture/'webview/scripts/bootstrap.lisp')
    (fixture/'lut.asd').write_text('(asdf:defsystem "lut")\n')
    (fixture/'webview/BUILD_ID').write_bytes(b'abc123\r\n')
    (fixture/'test.lisp').write_text('''(load "webview/scripts/bootstrap.lisp")
(assert (string= "abc123" (car (last (pathname-directory *lut-short-cache*)))))
(let ((output (asdf:apply-output-translations (merge-pathnames "sample.fasl"))))
  (assert (notany (lambda (ch) (< (char-code ch) 32)) (namestring output)))
  (assert (< (length (namestring output)) 160))
  (ensure-directories-exist output))
(format t "PASS: CRLF build ID produces a valid short cache directory.~%")
''')
    subprocess.run(['sbcl','--script','test.lisp'],cwd=fixture,check=True,
                   env={**os.environ,'LUT_WEBVIEW_CACHE':str(fixture/'cache')},timeout=60)
