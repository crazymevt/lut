#!/usr/bin/env python3
"""Build and configure LUT's default wakeable backend. No work happens at app startup."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[1]

def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)

def lisp_string(path):
    value = str(path.resolve()) + os.sep
    if any(ord(c) < 32 for c in value):
        raise ValueError('Control characters are not supported in build paths')
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=Path, help='Existing verified raylib archive')
    parser.add_argument('--cef-root', type=Path, default=os.environ.get('CEF_ROOT'))
    parser.add_argument('--download-cef', action='store_true', help='Explicitly permit downloading the pinned CEF SDK')
    parser.add_argument('--without-cef', action='store_true', help='Configure only raylib for applications without CEF')
    parser.add_argument('--wayland', action='store_true')
    args = parser.parse_args()
    version = json.loads((ROOT/'webview/sdk-lock.json').read_text())['version']
    target = {('Darwin', 'arm64'): 'macosarm64', ('Darwin', 'x86_64'): 'macosx64',
              ('Linux', 'x86_64'): 'linux64', ('Linux', 'aarch64'): 'linuxarm64',
              ('Windows', 'amd64'): 'windows64'}.get((platform.system(), platform.machine().lower()))
    if not target:
        parser.error('Unsupported build target; use a supported raylib/CEF toolchain')
    sdk = args.cef_root
    if sdk is None:
        candidates = sorted((ROOT/'webview/.cache').glob(f'cef_binary_{version}_{target}*'))
        sdk = next((p for p in candidates if (p/'include/cef_version.h').exists()), None)
    runtime_library = {'Darwin': 'liblut_cef.dylib', 'Linux': 'liblut_cef.so', 'Windows': 'lut_cef.dll'}[platform.system()]
    needs_cef = not args.without_cef and (sdk is not None or args.download_cef or
                                        (ROOT/'webview/runtime'/runtime_library).exists())
    if needs_cef and sdk is None and not args.download_cef:
        parser.error('CEF is installed but its SDK is missing. Set CEF_ROOT or run make event-backend-build CEF_DOWNLOAD=1')
    work = ROOT/'.event-build'
    work.mkdir(exist_ok=True)
    command = [sys.executable, ROOT/'tools/build-event-raylib.py']
    if args.archive: command += ['--archive', args.archive]
    if args.wayland: command += ['--wayland']
    run(*command)
    raylib = Path(json.loads((work/'raylib-build.json').read_text())['library_directory'])
    cef = None
    if needs_cef:
        digest = hashlib.sha256((version + target).encode())
        for source in sorted((ROOT/'webview/native').iterdir()):
            if source.is_file(): digest.update(source.name.encode() + source.read_bytes())
        identity = digest.hexdigest()[:16]
        cef = work/('cef-runtime-' + identity)
        if not (cef/'lut-setup.json').exists():
            stage = work/('cef-stage-' + uuid.uuid4().hex)
            command = [sys.executable, ROOT/'webview/scripts/build.py', '--runtime-dir', stage,
                       '--build-dir', work/('cef-build-' + identity)]
            if sdk is not None: command += ['--cef-root', sdk]
            else: command += ['--download']
            run(*command)
            (stage/'lut-setup.json').write_text(json.dumps({'version': version, 'target': target, 'source_hash': identity})+'\n')
            if cef.exists():
                raise RuntimeError(f'Incomplete existing runtime: {cef}; keep it intact and choose a clean build directory')
            stage.rename(cef)
        if not (cef/runtime_library).exists(): raise RuntimeError('Configured CEF runtime is incomplete')
    temporary = work/('event-backend-' + uuid.uuid4().hex + '.sexp')
    temporary.write_text(f'(:version 1 :raylib {lisp_string(raylib)} :cef {lisp_string(cef) if cef else "nil"})\n')
    temporary.replace(work/'event-backend.sexp')
    print('LUT event backend configured as the default for fresh Lisp processes.')
    print('Apps can use their ordinary launch command. Set LUT_EVENT_LOOP=0 for compatibility polling.')

if __name__ == '__main__':
    main()
