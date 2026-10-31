#!/usr/bin/env python3
"""Create an offline test bundle with SBCL, Lisp sources and native libraries."""
import hashlib, json, os, pathlib, platform, shutil, subprocess, tarfile, zipfile
from prepare import ROOT

def copy_runtime_dependencies(web):
    # Ship runtime source trees, not upstream documentation themes or examples.
    deps=web/'deps'; deps.mkdir()
    lock=json.loads((ROOT/'dependencies-lock.json').read_text())
    entries=[(item['directory'],item['name']) for item in lock['lisp']]+[('raylib','raylib')]
    allowed={'src','alexandria-1','alexandria-2','apiv1','apiv2','libffi','toolchain'}
    for original,short in entries:
        target=deps/short; target.mkdir()
        for item in (ROOT/'deps'/original).iterdir():
            if item.is_dir() and item.name in allowed:
                shutil.copytree(item,target/item.name,ignore=shutil.ignore_patterns('*.fasl','__pycache__'))
            elif item.is_file() and item.suffix not in ('.fasl','.inputs'):
                shutil.copy2(item,target/item.name)
    for name_in in ('PROVENANCE.json','BINDING_PATCH.txt','PATCHES.txt'):
        shutil.copy2(ROOT/'deps'/name_in,deps/name_in)
    (deps/'RUNTIME_SUBSET.txt').write_text('Runtime source subset; upstream docs/examples/tests omitted. Dependency directories shortened; original archives and checksums are recorded in PROVENANCE.json.\n')

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
    (app/'docs').mkdir()
    shutil.copy2(repo/'docs/test-builds.md',app/'docs/test-builds.md')
    web=app/'webview'; web.mkdir()
    for name_in in ('lisp','scripts','tests','runtime'):
        shutil.copytree(ROOT/name_in,web/name_in,symlinks=False,
                        ignore=shutil.ignore_patterns('__pycache__','*.fasl','*.inputs','*.lib','*.a','cache','debug.log'))
    shutil.copy2(ROOT/'README.md',web/'README.md')
    copy_runtime_dependencies(web)
    home=pathlib.Path(info['home'])
    (bundle/'sbcl-home').mkdir()
    shutil.copy2(home/'sbcl.core',bundle/'sbcl-home/sbcl.core')
    shutil.copytree(home/'contrib',bundle/'sbcl-home/contrib')
    binary=bundle/'sbcl'; binary.mkdir()
    executable=pathlib.Path(info['executable'])
    shutil.copy2(executable,binary/executable.name)
    mesa_names={'opengl32.dll','libgallium_wgl.dll'}
    for dll in executable.parent.glob('*.dll'):
        if dll.name.lower() not in mesa_names: shutil.copy2(dll,binary/dll.name)
    # Preserve the runtime's distribution notices in addition to contrib notices.
    notices=bundle/'licenses'; notices.mkdir()
    shutil.copy2(ROOT/'.cache/SBCL_COPYING',notices/'SBCL-COPYING')
    for parent in (home,home.parent,executable.parent,ROOT/'.cache/sbcl-linux'):
        for pattern in ('COPYING','CREDITS','README','copyright'):
            for path in parent.glob(pattern):
                if path.is_file(): shutil.copy2(path,notices/('SBCL-'+path.name))
    if system=='Windows':
        hardware=bundle/'sbcl-hardware'
        shutil.copytree(binary,hardware)
        for name_in in mesa_names: shutil.copy2(ROOT/'software-opengl'/name_in,binary/name_in)
        shutil.copytree(ROOT/'software-opengl/licenses',notices/'Mesa')
        shutil.copy2(ROOT/'software-opengl/PROVENANCE.json',notices/'Mesa-PROVENANCE.json')
        redist=os.environ.get('VCToolsRedistDir')
        if redist:
            for directory in pathlib.Path(redist).glob('x64/Microsoft.VC*.CRT'):
                for dll in directory.glob('*.dll'):
                    for destination in (web/'runtime',binary,hardware): shutil.copy2(dll,destination/dll.name)
        launcher='''@echo off
setlocal
set "SBCL_HOME=%~dp0sbcl-home"
set "PATH=%~dp0app\\webview\\runtime;%~dp0sbcl;%PATH%"
set "LUT_WEBVIEW_CACHE=%LOCALAPPDATA%\\LUT\\c"
set "GALLIUM_DRIVER=llvmpipe"
"%~dp0sbcl\\sbcl.exe" --noinform --no-sysinit --no-userinit --script "%~dp0app\\webview\\scripts\\run.lisp"
if errorlevel 1 pause
'''
        (bundle/'Start LUT Webview.cmd').write_text(launcher,newline='\r\n')
        hardware_launcher=launcher.replace('sbcl\\sbcl.exe','sbcl-hardware\\sbcl.exe').replace('set "GALLIUM_DRIVER=llvmpipe"','set "GALLIUM_DRIVER="')
        (bundle/'Start with hardware OpenGL.cmd').write_text(hardware_launcher,newline='\r\n')
        # CI-only callers use --script directly, so failures never pause.
        (bundle/'test.cmd').write_text(launcher.replace('if errorlevel 1 pause','exit /b %errorlevel%'),newline='\r\n')
    else:
        launcher='''#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export SBCL_HOME="$HERE/sbcl-home"
export LD_LIBRARY_PATH="$HERE/app/webview/runtime${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export LUT_WEBVIEW_CACHE="${XDG_CACHE_HOME:-${HOME}/.cache}/lut-webview"
exec "$HERE/sbcl/sbcl" --noinform --no-sysinit --no-userinit --script "$HERE/app/webview/scripts/run.lisp"
'''
        (bundle/'start.sh').write_text(launcher); (bundle/'start.sh').chmod(0o755)
    (bundle/'READ ME.txt').write_text('''LUT / CEF development test build

Windows: extract the whole ZIP, then double-click Start LUT Webview.cmd.
This uses bundled Mesa software OpenGL and needs no system driver install.
Start with hardware OpenGL.cmd optionally uses your installed GPU driver.
Linux: extract the whole tar.gz, then run ./start.sh in a desktop session.
No Lisp installation, compiler, Quicklisp or build steps are needed.
The first launch compiles bundled Lisp sources into your user cache.

Linux target: x86-64 Fedora Workstation (glibc >= 2.38), X11 or XWayland.
A desktop graphics driver and standard desktop libraries are still required.
Native Wayland is not yet validated. Windows target: Windows 10/11 x64.

This is the unsandboxed development prototype for trusted test content.
All dependency licenses/provenance are included under app/webview/deps,
app/webview/runtime, sbcl-home, licenses, and app/LICENSE.
F12 releases browser focus so you can Tab back to LUT controls.
''')
    sha=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()
    (web/'BUILD_ID').write_text(sha[:12]+'\n',newline='\n')
    (bundle/'BUILD.json').write_text(json.dumps({'commit':sha,'platform':system,'architecture':'x86_64',
                                               'cef':(ROOT/'runtime/CEF_VERSION').read_text().strip()},indent=2))
    lengths=[(len(str(path.relative_to(dist))),str(path.relative_to(dist))) for path in bundle.rglob('*')]
    maximum=max(lengths)
    if maximum[0]>140:
        raise SystemExit(f'Bundle path too long ({maximum[0]}): {maximum[1]}')
    print(f'Maximum archive path length: {maximum[0]} characters',flush=True)
    archive=dist/(name+('.zip' if system=='Windows' else '.tar.gz'))
    if system=='Windows':
        with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as output:
            for path in bundle.rglob('*'):
                if path.is_file(): output.write(path,path.relative_to(dist))
    else:
        print(f'Compressing {archive.name}',flush=True)
        with tarfile.open(archive,'w:gz',compresslevel=3) as output: output.add(bundle,arcname=name)
    (dist/(archive.name+'.sha256')).write_text(hashlib.sha256(archive.read_bytes()).hexdigest()+'  '+archive.name+'\n')
    print(archive)
if __name__=='__main__': main()
