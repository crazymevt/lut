#!/usr/bin/env python3
"""Build/stage the development CEF bridge. Run through quiet-run where available."""
import argparse, hashlib, json, os, pathlib, platform, plistlib, shutil, subprocess, tarfile, urllib.request

VERSION = '156.0.15+gcf671c0+chromium-156.0.8078.80'
ROOT = pathlib.Path(__file__).resolve().parents[1]

def run(*args):
    subprocess.run([str(a) for a in args], check=True)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--cef-root', type=pathlib.Path)
    parser.add_argument('--runtime-dir', type=pathlib.Path, help='Stage a separate runtime without replacing an active one')
    parser.add_argument('--build-dir', type=pathlib.Path, help='Separate native build directory')
    parser.add_argument('--download', action='store_true', help='Download the pinned official SDK')
    args = parser.parse_args()
    system, machine = platform.system(), platform.machine().lower()
    key = {('Darwin','arm64'):'macosarm64', ('Darwin','x86_64'):'macosx64',
           ('Windows','amd64'):'windows64', ('Linux','x86_64'):'linux64',
           ('Linux','aarch64'):'linuxarm64'}.get((system,machine))
    if not key:
        raise SystemExit(f'Unsupported SDK target: {system}/{machine}')
    cache = ROOT / '.cache'
    cache.mkdir(exist_ok=True)
    sdk = args.cef_root
    if args.download:
        lock = json.loads((ROOT / 'sdk-lock.json').read_text())
        if lock['version'] != VERSION:
            raise SystemExit('SDK lock and build version differ')
        item = lock['platforms'][key]
        archive = cache / item['name']
        if not archive.exists():
            urllib.request.urlretrieve('https://cef-builds.spotifycdn.com/' + item['name'].replace('+','%2B'), archive)
        if hashlib.sha1(archive.read_bytes()).hexdigest() != item['sha1']:
            raise SystemExit('Official CEF index checksum mismatch')
        with tarfile.open(archive) as bundle:
            bundle.extractall(cache, filter='data')
        sdk = cache / item['name'].removesuffix('.tar.bz2')
        (cache / 'provenance.json').write_text(json.dumps({'version':VERSION, 'platform':key, **item}, indent=2))
    if not sdk:
        parser.error('provide --cef-root PATH or --download')
    sdk = sdk.resolve()
    header = (sdk / 'include/cef_version.h').read_text()
    if f'"{VERSION}"' not in header:
        raise SystemExit(f'This prototype requires CEF {VERSION}')
    build = (args.build_dir or ROOT / 'build').resolve()
    run('cmake', '-S', ROOT/'native', '-B', build, f'-DCEF_ROOT={sdk.as_posix()}', '-DCMAKE_BUILD_TYPE=Release',
        *(['-DPROJECT_ARCH=arm64' if machine == 'arm64' else '-DPROJECT_ARCH=x86_64'] if system == 'Darwin' else []))
    run('cmake', '--build', build, '--config', 'Release', '--parallel', '4')
    runtime = (args.runtime_dir or ROOT / 'runtime').resolve()
    run('cmake', '--install', build, '--config', 'Release', '--prefix', runtime)
    if system == 'Darwin':
        framework = 'Chromium Embedded Framework.framework'
        shutil.copytree(sdk/'Release'/framework, runtime/framework, symlinks=True, dirs_exist_ok=True)
        # CEF resolves its helper framework relative to the outer application bundle.
        app = runtime/'LUT Webview Helper.app'
        binary = app/'Contents/MacOS'
        binary.mkdir(parents=True, exist_ok=True)
        shutil.copy2(runtime/'lut_cef_helper', binary/'lut_cef_helper')
        frameworks = app/'Contents/Frameworks'
        frameworks.mkdir(exist_ok=True)
        link = frameworks/framework
        if not link.exists():
            link.symlink_to('../../../'+framework)
        with (app/'Contents/Info.plist').open('wb') as stream:
            plistlib.dump({'CFBundleExecutable':'lut_cef_helper', 'CFBundleIdentifier':'org.lut.webview.helper',
                          'CFBundleName':'LUT Webview Helper', 'CFBundlePackageType':'APPL',
                          'LSUIElement':True}, stream)
    else:
        for source in (sdk/'Release', sdk/'Resources'):
            if source.exists():
                shutil.copytree(source, runtime, dirs_exist_ok=True)
    for name in ('LICENSE.txt','CREDITS.html'):
        shutil.copy2(sdk/name, runtime/name)
    (runtime/'CEF_VERSION').write_text(VERSION+'\n')
    print(f'CEF runtime staged in {runtime}')

if __name__ == '__main__':
    main()
