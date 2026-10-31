"""Per-application Mesa deployment: no system registry or driver changes."""
import json, os, pathlib, shutil, urllib.request
from prepare import ROOT, CACHE, LOCK, fetch, run

def stage_mesa():
    item=LOCK['mesa']
    archive=fetch(item)
    source=CACHE/'mesa'
    if not (source/'x64/opengl32.dll').exists():
        extractor=shutil.which('7z') or shutil.which('7zz') or str(pathlib.Path(os.environ.get('ProgramFiles','C:/Program Files'))/'7-Zip/7z.exe')
        run(extractor,'x','-y',f'-o{source}',archive)
    target=ROOT/'software-opengl'; target.mkdir(exist_ok=True)
    for name in ('opengl32.dll','libgallium_wgl.dll'):
        shutil.copy2(source/'x64'/name,target/name)
    notices=target/'licenses'; notices.mkdir(exist_ok=True)
    urls={
      'Mesa-LICENSE.html':'https://docs.mesa3d.org/license.html',
      'LLVM-LICENSE.txt':'https://raw.githubusercontent.com/llvm/llvm-project/llvmorg-21.1.0/llvm/LICENSE.TXT',
      'Distribution-LICENSE.txt':'https://raw.githubusercontent.com/pal1000/mesa-dist-win/26.0.3/LICENSE',
    }
    for name,url in urls.items():
        path=notices/name
        if not path.exists():
            with urllib.request.urlopen(url,timeout=60) as response: path.write_bytes(response.read())
    (target/'PROVENANCE.json').write_text(json.dumps(item,indent=2))
    # CI tests the exact local deployment used by the ZIP; no system-wide Mesa.
    info=json.loads((ROOT/'.sbcl-info.json').read_text())
    binary=pathlib.Path(info['executable']).parent
    for name in ('opengl32.dll','libgallium_wgl.dll'): shutil.copy2(target/name,binary/name)
    print('Per-application Mesa software OpenGL staged beside SBCL.')
