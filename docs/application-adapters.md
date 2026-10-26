# Default applications and native window state

`launch-uri` and `launch-file` are explicit application actions. Nothing in document
link handling invokes them automatically. Handle `:link` events in the application
and decide whether to launch their targets.

`(default-application-capabilities)` returns fresh `:available-p`, `:backend`,
`:native-p` and `:command` fields. With `*default-application-command*` at `:auto`,
macOS uses `/usr/bin/open --`; other systems discover `xdg-open` on PATH. A
nonempty argv-prefix list configures a portable fallback, including on Windows.
`nil` disables launching. Program discovery checks path presence, not permissions,
target associations, or whether a graphical desktop is running. Configured
prefixes can include launcher options; LUT appends one target argument and never
invokes a shell. Windows has no automatic native launcher in this delivery;
configure a command explicitly. Linux/Windows execution remains unverified.

`launch-uri` accepts an absolute scheme-bearing string, rejects whitespace/control
characters and invalid ASCII scheme names, and passes the target literally.
`launch-file` resolves an existing file/directory to its absolute true pathname.
No file is created. Both return `t` and the backend after successful process
submission. This means the opener exited successfully, not that another
application finished loading the target. Opener invocation is synchronous and
can block while the helper runs; application workers may call it when appropriate.

Failures signal `target-launch-error`. Inspect `launch-error-reason` for
`:invalid-target`, `:unavailable`, `:process-error`, or `:nonzero-exit`;
`launch-error-target`, `launch-error-detail` and `launch-error-exit-code` provide
context. Invalid command configuration signals an ordinary configuration error.
Tests use a real printf helper and injected launcher failures; they do not open
browsers or arbitrary user files.

```lisp
(lut:default-application-capabilities)
(lut:launch-uri "https://example.com") ; explicit external action
(lut:launch-file #p"/existing/report.txt")
```

`window-state` returns the last observed `:normal` or `:maximized` and a second
availability value. Without an active native primary/worker route it returns
`:unavailable, nil`; a newly opening worker can report `:unavailable, t` until its
first observation arrives. `set-window-state` requests `:normal` or `:maximized`
and returns the window. The OS transition is asynchronous: observe subsequent
frames rather than assuming the setter completed it. The OS can refuse a request;
setters are not completion acknowledgments. Unsupported contexts signal
`unsupported-capability`. This is not a fullscreen or minimized-state API.

`normal-window-size` returns saved logical width and height, independent of
allocated `width`/`height` once a normal size has been recorded or explicitly
configured. Until then it falls back to current `width`/`height`, preserving
legacy pre-open setters for both `run` and `spawn-window`. Layout also changes
this fallback before any normal size has been saved. To configure a normal size
independent of pre-open layout, call `set-normal-window-size`.
`set-normal-window-size` sets positive logical dimensions before opening, resizes
an active normal window, or retains the dimensions for the next restore while
maximized. Native startup uses these dimensions. Restoring applies the saved
normal size, converted through `ui-scale`. Normal user resizing updates the saved
size from OS content dimensions. During maximize/restore, capture is suspended
for a short frame interval to avoid saving transient/maximized dimensions as the
normal size; later observations record actual OS sizes, including OS constraints.

Call active native operations on the GUI/controller thread (use `on-ui` from an
editor REPL). Worker roots use the same API; requests travel over private IPC and
observations return with frame/input packets. Generations reject older reports
while a newer size/state request is pending. Worker state is therefore eventually
consistent. No callbacks, native pointers or application persistence cross IPC.
A size returned after a stopped context remains available until disposal; state
availability becomes false. Applications decide when and where to persist it.

Run `lut-examples:application-adapters` to try the opt-in launcher and native
state buttons. Launching happens only when its explicit Open button is pressed.
