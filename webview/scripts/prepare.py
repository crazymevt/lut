#!/usr/bin/env python3
"""Fetch pinned public Lisp/raylib dependencies and build the precompiled shim."""
import hashlib, json, os, pathlib, platform, shutil, subprocess, tarfile, time, urllib.request, zipfile
ROOT = pathlib.Path(__file__).resolve().parents[1]
LOCK = json.loads((ROOT/'dependencies-lock.json').read_text())
CACHE = ROOT/'.cache'
DEPS = ROOT/'deps'

def run(*args, **kw):
    subprocess.run([str(a) for a in args], check=True, **kw)

def fetch(item):
    CACHE.mkdir(exist_ok=True)
    target = CACHE / (item.get('name') or item['url'].rsplit('/',1)[-1])
    algorithm = 'sha256' if 'sha256' in item else 'sha1'
    expected = item[algorithm]
    for attempt in range(4):
        try:
            if not target.exists():
                with urllib.request.urlopen(item['url'], timeout=90) as src, target.open('wb') as out:
                    shutil.copyfileobj(src,out)
            if hashlib.new(algorithm,target.read_bytes()).hexdigest() != expected:
                target.unlink()
                raise ValueError(f'Checksum mismatch: {target.name}')
            return target
        except Exception:
            target.unlink(missing_ok=True)
            if attempt == 3: raise
            time.sleep(2*(attempt+1))

def extract(archive, target):
    target.mkdir(parents=True, exist_ok=True)
    if zipfile.is_zipfile(archive):
        with zipfile.ZipFile(archive) as z: z.extractall(target)
    else:
        with tarfile.open(archive) as t: t.extractall(target, filter='data')

def main():
    DEPS.mkdir(exist_ok=True)
    for item in LOCK['lisp']:
        if not (DEPS/item['directory']).exists(): extract(fetch(item),DEPS)
    # The pinned Babel KSC encoder invokes a nonexistent HANDLE-ERROR and
    # declares NIL as a code-point before reaching its error branch. Preserve
    # normal mapping and use Babel's existing encoding-error contract.
    babel=next(item for item in LOCK['lisp'] if item['name']=='babel')
    source_file=DEPS/babel['directory']/'src/enc-ksc-5601.lisp'
    source=source_file.read_text()
    old="""           for ksc-5601 of-type code-point = (utf8-to-ksc-5601 code)
           unless ksc-5601
             do (handle-error)"""
    new="""           for ksc-5601 of-type code-point =
             (or (utf8-to-ksc-5601 code)
                 (encoding-error code :ksc_5601 src i))"""
    if old in source:
        source_file.write_text(source.replace(old,new,1))
    elif new not in source:
        raise RuntimeError('Pinned Babel encoder no longer matches the documented patch')
    (DEPS/'PATCHES.txt').write_text('Babel: KSC_5601 encoder uses encoding-error for unrepresentable characters before applying the code-point type restriction. Original source/license retained; archive digest is in PROVENANCE.json. Raylib patches are recorded in BINDING_PATCH.txt.\n')
    binding = DEPS/'raylib'
    if not binding.exists():
        unpack = CACHE/'binding'
        extract(fetch(LOCK['binding']),unpack)
        shutil.copytree(next(unpack.iterdir()),binding)
        library = binding/'src/runtime/library.lisp'
        source = library.read_text()
        source = source.replace('  (append\n', '  (append\n   (let ((runtime (ignore-errors (asdf:system-relative-pathname "lut/webview" "webview/runtime/"))))\n     (when runtime (list runtime)))\n',1)
        needle = '(defun build-shim (library)'
        # Retain the upstream implementation, adding a precompiled-shim override
        # before its LET body. No consumer compiler is needed in packaged builds.
        pos = source.index('  (let* ((out (shim-library))',source.index(needle))
        source = source[:pos] + '''  (let ((prebuilt (or (uiop:getenv "RAYLIB_LISP_PREBUILT_SHIM")
                     (ignore-errors
                       (let ((path (asdf:system-relative-pathname "lut/webview"
                           #+darwin "webview/runtime/libraylib-shim.dylib"
                           #+windows "webview/runtime/libraylib-shim.dll"
                           #-(or darwin windows) "webview/runtime/libraylib-shim.so")))
                         (when (probe-file path) (namestring path)))))))
    (when prebuilt
      (unless (probe-file prebuilt) (error "Missing precompiled raylib shim: ~a" prebuilt))
      (return-from build-shim prebuilt)))
''' + source[pos:]
        library.write_text(source)
        scopes=binding/'src/lisp/scopes.lisp'
        scopes.write_text(scopes.read_text().replace('(close-window)\n      (release-app)',
            '(when (is-window-ready) (close-window))\n      (release-app)',1))
    system = platform.system()
    item = LOCK['raylib'][system]
    sdk = CACHE/item['directory']
    if not sdk.exists(): extract(fetch(item),CACHE)
    runtime = ROOT/'runtime'
    runtime.mkdir(exist_ok=True)
    for path in (sdk/'lib').iterdir():
        if path.suffix not in ('.a','.lib'):
            if path.is_symlink():
                destination=runtime/path.name
                if not destination.exists(): destination.symlink_to(os.readlink(path))
            else: shutil.copy2(path,runtime/path.name)
    build = ROOT/'build-raylib'
    run('cmake','-S',ROOT/'native/raylib','-B',build,f'-DRAYLIB_ROOT={sdk.as_posix()}',f'-DBINDING_ROOT={binding.as_posix()}', '-DCMAKE_BUILD_TYPE=Release')
    run('cmake','--build',build,'--config','Release','--parallel','4')
    run('cmake','--install',build,'--config','Release','--prefix',runtime)
    shutil.copy2(sdk/'LICENSE',runtime/'RAYLIB_LICENSE')
    (DEPS/'PROVENANCE.json').write_text(json.dumps(LOCK,indent=2))
    (DEPS/'BINDING_PATCH.txt').write_text('Pinned upstream raylib binding with bundled/precompiled library lookup and failed-window cleanup guard added by scripts/prepare.py. All upstream license files retained.\n')
    if os.environ.get('GITHUB_PATH'):
        with open(os.environ['GITHUB_PATH'],'a') as f: f.write(str(runtime.resolve())+'\n')
    if system == 'Windows':
        from software import stage_mesa
        stage_mesa()
    print('Pinned Lisp dependencies and native raylib shim ready.')
if __name__ == '__main__': main()
