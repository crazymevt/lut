#!/usr/bin/env python3
"""Build LUT's isolated raylib 6.2 event backend; never replace system raylib.
Run through quiet-run. Upstream source and licenses remain in ignored .event-build.
"""
import argparse, hashlib, json, os, pathlib, platform, shutil, subprocess, tarfile, urllib.request, uuid
ROOT = pathlib.Path(__file__).resolve().parents[1]
URL = 'https://github.com/raysan5/raylib/archive/refs/tags/6.2.tar.gz'
SHA256 = 'df7a13129b1bec9e73a6962efff170beba310ee6eab8f94cd000b7316b4db5ee'

def replace_once(path, old, new):
    text = path.read_text()
    if text.count(old) != 1:
        raise RuntimeError(f'Upstream patch context mismatch: {path}: {old!r}')
    path.write_text(text.replace(old, new, 1))

def record_build(work, library_dir):
    temporary=work/('raylib-build-'+uuid.uuid4().hex+'.json')
    temporary.write_text(json.dumps({'library_directory':str(library_dir)})+'\n')
    os.replace(temporary,work/'raylib-build.json')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', type=pathlib.Path)
    parser.add_argument('--wayland', action='store_true', help='Linux Wayland instead of X11')
    args=parser.parse_args()
    work=ROOT/'.event-build'; work.mkdir(exist_ok=True)
    archive=args.archive or work/'raylib-6.2.tar.gz'
    if not archive.exists(): urllib.request.urlretrieve(URL, archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest()!=SHA256:
        raise RuntimeError('raylib source SHA256 mismatch')
    bridge=ROOT/'native/raylib-events.inc'
    identity=hashlib.sha256((SHA256+platform.system()+platform.machine()+str(args.wayland)).encode()
                            +bridge.read_bytes()+pathlib.Path(__file__).read_bytes()).hexdigest()[:16]
    install=work/'versions'/identity
    library_dir=install/('bin' if platform.system()=='Windows' else 'lib')
    if (install/'lut-event-build.json').exists():
        record_build(work,library_dir)
        print('Reusing immutable backend. Set RAYLIB_LISP_LIBRARY_PATH to', library_dir)
        return
    source=work/'source'
    if source.exists(): shutil.rmtree(source)
    source.mkdir()
    with tarfile.open(archive) as bundle: bundle.extractall(source, filter='data')
    source=source/'raylib-6.2'
    core=source/'src/rcore.c'
    replace_once(core, '#include "raylib.h"', '#include "raylib.h"\nbool lutManualEvents = false;')
    replace_once(core, '    PollInputEvents();      // Poll user events (before next frame update)',
                 '    if (!lutManualEvents) PollInputEvents(); // LUT owns event dispatch when enabled')
    backend=source/'src/platforms/rcore_desktop_glfw.c'
    replace_once(backend, 'static PlatformData platform = { 0 };',
                 'static PlatformData platform = { 0 };\n#include "lut-events.inc"')
    replace_once(backend, '    if ((CORE.Window.eventWaiting) ||',
                 '    if (lutManualEvents) LUTDispatchEvents();\n    else if ((CORE.Window.eventWaiting) ||')
    shutil.copy2(ROOT/'native/raylib-events.inc', source/'src/platforms/lut-events.inc')
    build=work/'cmake'
    subprocess.run(['cmake','-S',str(source),'-B',str(build),'-DBUILD_SHARED_LIBS=ON',
                    '-DBUILD_EXAMPLES=OFF','-DUSE_EXTERNAL_GLFW=OFF','-DCMAKE_BUILD_TYPE=Release',
                    '-DCMAKE_INSTALL_PREFIX='+str(install), '-DCMAKE_INSTALL_LIBDIR=lib',
                    '-DGLFW_BUILD_WAYLAND='+('ON' if args.wayland else 'OFF'),
                    '-DGLFW_BUILD_X11='+('OFF' if args.wayland else 'ON')],check=True)
    subprocess.run(['cmake','--build',str(build),'--config','Release','--parallel','4'],check=True)
    subprocess.run(['cmake','--install',str(build),'--config','Release'],check=True)
    (install/'lut-event-build.json').write_text(json.dumps(dict(url=URL,sha256=SHA256,
        bridge_sha256=hashlib.sha256((ROOT/'native/raylib-events.inc').read_bytes()).hexdigest(),
        wayland=args.wayland),indent=2)+'\n')
    if platform.system()!='Windows':
        current=work/'current'
        if not current.exists() or current.is_symlink():
            temporary=work/('current-'+uuid.uuid4().hex)
            temporary.symlink_to(pathlib.Path('versions')/identity)
            os.replace(temporary,current)
    record_build(work,library_dir)
    print('Backend ready. Set RAYLIB_LISP_LIBRARY_PATH to', library_dir)
if __name__=='__main__': main()
