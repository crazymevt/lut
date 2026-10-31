#!/usr/bin/env python3
"""Create an offline test bundle with SBCL, Lisp sources and native libraries."""
import hashlib, json, os, pathlib, platform, shutil, subprocess, tarfile, zipfile
from prepare import ROOT

def main():
    system=platform.system()
    if system not in ('Windows','Linux'): raise SystemExit('Download bundles currently target Windows/Linux x64')
    info=json.loads((ROOT/'.sbcl-info.json').read_text())
    repo=ROOT.parent
    name='lut-webview-'+system.lower()+'-x64'
    dist=repo/'dist'; dist.mkdir(exist_ok=True)
    bundle=dist/name
    if bundle.exists(): shutil.rmtree(bundle)
    bundle.mkdir()
    app=bundle/'app'; app.mkdir()
    for name_in in ('lut.asd','LICENSE','src','assets'):
        source=repo/name_in
        if source.is_dir(): shutil.copytree(source,app/name_in)
        else: shutil.copy2(source,app/name_in)
    web=app/'webview'; web.mkdir()
    for name_in in ('lisp','scripts','tests','deps','runtime'):
        shutil.copytree(ROOT/name_in,web/name_in,symlinks=False,
                        ignore=shutil.ignore_patterns('__pycache__','*.fasl','*.inputs','*.lib','*.a','cache','debug.log'))
    shutil.copy2(ROOT/'README.md',web/'README.md')
    home=pathlib.Path(info['home'])
    shutil.copytree(home,bundle/'sbcl-home')
    binary=bundle/'sbcl'; binary.mkdir()
    executable=pathlib.Path(info['executable'])
    shutil.copy2(executable,binary/executable.name)
    for dll in executable.parent.glob('*.dll'): shutil.copy2(dll,binary/dll.name)
    # Preserve the runtime's distribution notices in addition to contrib notices.
    notices=bundle/'licenses'; notices.mkdir()
    for parent in (home,home.parent,executable.parent,ROOT/'.cache/sbcl-linux'):
        for pattern in ('COPYING','CREDITS','README','copyright'):
            for path in parent.glob(pattern):
                if path.is_file(): shutil.copy2(path,notices/('SBCL-'+path.name))
    if system=='Windows':
        redist=os.environ.get('VCToolsRedistDir')
        if redist:
            for directory in pathlib.Path(redist).glob('x64/Microsoft.VC*.CRT'):
                for dll in directory.glob('*.dll'): shutil.copy2(dll,web/'runtime'/dll.name)
        launcher='''@echo off
setlocal
set "SBCL_HOME=%~dp0sbcl-home"
set "PATH=%~dp0app\\webview\\runtime;%~dp0sbcl;%PATH%"
set "XDG_CACHE_HOME=%LOCALAPPDATA%\\LUT-Webview\\cache"
"%~dp0sbcl\\sbcl.exe" --noinform --no-sysinit --no-userinit --script "%~dp0app\\webview\\scripts\\run.lisp"
if errorlevel 1 pause
'''
        (bundle/'Start LUT Webview.cmd').write_text(launcher.replace('\n','\r\n'))
        # CI-only callers use --script directly, so failures never pause.
        (bundle/'test.cmd').write_text(launcher.replace('if errorlevel 1 pause','exit /b %errorlevel%').replace('\n','\r\n'))
    else:
        launcher='''#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export SBCL_HOME="$HERE/sbcl-home"
export LD_LIBRARY_PATH="$HERE/app/webview/runtime${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-${HOME}/.cache}"
exec "$HERE/sbcl/sbcl" --noinform --no-sysinit --no-userinit --script "$HERE/app/webview/scripts/run.lisp"
'''
        (bundle/'start.sh').write_text(launcher); (bundle/'start.sh').chmod(0o755)
    (bundle/'READ ME.txt').write_text('''LUT / CEF development test build

Windows: extract the whole ZIP, then double-click Start LUT Webview.cmd.
Linux: extract the whole tar.gz, then run ./start.sh in a desktop session.
No Lisp installation, compiler, Quicklisp or build steps are needed.
The first launch compiles bundled Lisp sources into your user cache.

Linux target: x86-64 Fedora Workstation (glibc >= 2.35), X11 or XWayland.
A desktop graphics driver and standard desktop libraries are still required.
Native Wayland is not yet validated. Windows target: Windows 10/11 x64.

This is the unsandboxed development prototype for trusted test content.
All dependency licenses/provenance are included under app/webview/deps,
app/webview/runtime, sbcl-home, licenses, and app/LICENSE.
F12 releases browser focus so you can Tab back to LUT controls.
''')
    sha=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()
    (bundle/'BUILD.json').write_text(json.dumps({'commit':sha,'platform':system,'architecture':'x86_64',
                                               'cef':(ROOT/'runtime/CEF_VERSION').read_text().strip()},indent=2))
    archive=dist/(name+('.zip' if system=='Windows' else '.tar.gz'))
    if system=='Windows':
        with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as output:
            for path in bundle.rglob('*'):
                if path.is_file(): output.write(path,path.relative_to(dist))
    else:
        with tarfile.open(archive,'w:gz') as output: output.add(bundle,arcname=name)
    (dist/(archive.name+'.sha256')).write_text(hashlib.sha256(archive.read_bytes()).hexdigest()+'  '+archive.name+'\n')
    print(archive)
if __name__=='__main__': main()
