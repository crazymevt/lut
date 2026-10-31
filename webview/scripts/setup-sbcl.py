#!/usr/bin/env python3
"""Install an isolated SBCL for CI; use the same runtime in downloadable builds."""
import json, os, pathlib, platform, shutil, subprocess
from prepare import ROOT, CACHE, LOCK, fetch, extract, run

def main():
    system=platform.system()
    install=ROOT/'.sbcl'
    install.mkdir(exist_ok=True)
    if system=='Darwin':
        if not shutil.which('sbcl'): run('brew','install','sbcl')
        executable=pathlib.Path(shutil.which('sbcl'))
        # Homebrew's wrapper selects its matching SBCL_HOME.
        command=[str(executable),'--noinform','--non-interactive','--eval',
          '(format t "LUT-SBCL ~a~%" (sb-ext:posix-getenv "SBCL_HOME"))']
        output=subprocess.check_output(command,text=True)
        home=pathlib.Path(next(line.removeprefix('LUT-SBCL ') for line in output.splitlines() if line.startswith('LUT-SBCL ')))
    elif system=='Linux':
        archive=fetch(LOCK['sbcl']['linux'])
        extract(archive,CACHE/'sbcl-linux')
        source=next((CACHE/'sbcl-linux').iterdir())
        run('sh','install.sh',cwd=source,env={**os.environ,'INSTALL_ROOT':str(install.resolve())})
        executable=install/'bin/sbcl'
        home=install/'lib/sbcl'
    else:
        archive=fetch(LOCK['sbcl']['windows'])
        run('msiexec','/a',archive,'/qn',f'TARGETDIR={install.resolve()}')
        candidates=list(install.rglob('sbcl.exe'))
        if not candidates: raise RuntimeError('SBCL administrative extraction produced no executable')
        executable=candidates[0]
        home=next(install.rglob('sbcl.core')).parent
    info={'executable':str(executable.resolve()),'home':str(home.resolve())}
    (ROOT/'.sbcl-info.json').write_text(json.dumps(info,indent=2))
    if os.environ.get('GITHUB_PATH'):
        with open(os.environ['GITHUB_PATH'],'a') as f: f.write(str(executable.parent.resolve())+'\n')
        with open(os.environ['GITHUB_ENV'],'a') as f: f.write('SBCL_HOME='+str(home.resolve())+'\n')
    print(info)
if __name__=='__main__': main()
