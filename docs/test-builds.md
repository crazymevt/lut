# Cross-platform CI and downloadable webview test builds

The public repository is https://github.com/crazymevt/lut.
The `Cross-platform LUT webview` workflow runs on every branch push, pull request,
and manual dispatch. Its push filter includes branches explicitly, so pushing a
tag does not trigger it. Concurrent superseded runs on the same ref are cancelled.

Every platform builds the CEF bridge and the raylib CFFI shim from pinned inputs
and runs LUT's headless regression suite. An intentional native-runner failure
must produce a nonzero process exit, preventing interactive error handling from
masking failed smoke tests. Windows and Linux run the complete LUT
webview window test with software graphics on hosted runners. GitHub's macOS
ARM64 VM cannot provide raylib's OpenGL pixel format, so macOS instead runs the
real CEF offscreen bridge test (load, pointer, Unicode, keys, DPI pixels,
navigation, shutdown). This does not claim to test the macOS window compositor;
that path is tested locally on a Mac with a graphics-capable desktop session.

Windows and Linux bundles include SBCL, the Lisp dependency sources, the
precompiled raylib shim, raylib, CEF, helper executables, fonts, and their
licenses/provenance. A pinned binding patch locates those bundled libraries and
bypasses compilation of the C shim. The first launch compiles Lisp sources using
the included SBCL and writes the compiled cache under the user's cache directory.
No compiler, Quicklisp, Lisp installation, or source checkout is required.

CI tests each bundle after extraction into a different path containing a space.
Linux is additionally tested in a Fedora container with an Xvfb desktop. Native
Wayland is not tested; normal Fedora Workstation sessions can use XWayland.
The x86-64 Linux runtime requires glibc 2.38+ and normal desktop libraries (NSS,
GTK/ATK, X11/XWayland, ALSA and OpenGL/Mesa). Fedora Workstation supplies most of
these by default. Bare/minimal/server installations are outside the test target.
Windows targets Windows 10/11 x64. Its default launcher uses per-application
bundled Mesa software OpenGL; it does not require a compatible GPU driver or
change system graphics settings. `Start with hardware OpenGL.cmd` is an optional
launcher for machines with a working OpenGL driver. CI tests the bundled Mesa
DLLs without installing Mesa system-wide.

After **all three platform jobs pass**, a main-branch run publishes a prerelease
with the tested Windows ZIP, Linux tar.gz, and SHA-256 checksums. Pull requests and
other branches never publish a release. Build tags are created only after checks
pass and do not start another CI run. Archives are also retained as Actions
artifacts for 30 days; release downloads remain available until removed.

Download from https://github.com/crazymevt/lut/releases:

- Windows: extract the entire ZIP, then double-click `Start LUT Webview.cmd`.
- Fedora: extract the entire tar.gz, then run `./start.sh` in a desktop session.

Upstream documentation themes/examples are omitted from the runtime archive,
dependency directory names are shortened, and packaging rejects paths longer
than 140 characters. Compiled Lisp files use a flat per-build cache to avoid
recreating long source paths under Windows user profiles.

Keep the extracted directory intact. F12 releases browser focus, and Tab returns
to LUT controls. The included `BUILD.json` records the exact source commit.
These remain development builds with the Chromium sandbox disabled, intended
for the bundled local fixtures and trusted test content.

## Reproduce a CI build

With Python 3.12+, CMake and the platform toolchain installed:

```
python webview/scripts/setup-sbcl.py
python webview/scripts/prepare.py
sbcl --script webview/tests/headless.lisp
python webview/scripts/build.py --download
```

`setup-sbcl.py` writes `.sbcl-info.json` and is intended for CI; outside Actions,
use its reported executable and SBCL_HOME when invoking the isolated runtime.
`package.py` uses that runtime metadata to assemble the offline archive. See
`webview/README.md` for native test commands and widget limitations.
