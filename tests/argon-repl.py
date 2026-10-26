"""Integration check against Argon's real framed REPL (optional sibling checkout)."""
import io
from pathlib import Path
import signal
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parent.parent
worker = Path(sys.argv[1]) if len(sys.argv) > 1 else root.parent / 'argon/src/repl-worker.lisp'
if not worker.is_file():
    raise SystemExit('Pass the path to Argon src/repl-worker.lisp')
def timeout(signum, frame):
    raise TimeoutError('Argon integration check exceeded 40 seconds')

signal.signal(signal.SIGALRM, timeout)
signal.alarm(40)

def receive(stream):
    header = stream.readline()
    if not header or not header.strip().isdigit():
        raise AssertionError('Invalid REPL frame header: ' + repr(header))
    size = int(header)
    value = stream.read(size)
    assert len(value) == size, 'Truncated REPL frame'
    return value

with tempfile.TemporaryFile(mode='w+') as errors:
    process = subprocess.Popen(
        ['sbcl', '--noinform', '--non-interactive', '--load', str(worker)],
        cwd=root, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=errors, text=True)
    try:
        assert 'Argon isolated SBCL REPL' in receive(process.stdout)
        def evaluate(source):
            for field in ['eval', '', source]:
                process.stdin.write(str(len(field)) + '\n' + field)
            process.stdin.flush()
            return receive(io.StringIO(receive(process.stdout)))
        output = evaluate('(load "' + str(root / 'tests/combo-launch.lisp') + '")')
        assert 'Requested codepoints glyphs found: [1/2]' in output, output
        assert 'Launcher combobox worker, dropdown popup, selection and cleanup passed.' in output, output
        assert '[SIMPLE-ERROR:' not in output, output
        assert '42' in evaluate('(+ 20 22)'), 'REPL must remain usable after closing the demo'
        assert process.poll() is None, 'Argon worker must remain alive'
        # Match Argon's Stop action. EOF is treated as a transport error by
        # the server, so its exit status is not a LUT acceptance criterion.
        process.terminate()
        process.wait(timeout=10)
        process.stdin.close()
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
print('Argon protocol, formatted warning capture, dropdown launch/selection/cleanup and subsequent evaluation passed.')
