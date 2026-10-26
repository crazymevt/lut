# Commands and shared actions

A command is a nonvisual action with an identifier, label, optional shortcut and
context-sensitive availability. Buttons, menu buttons and shortcuts can invoke
the same command. Application data and policies stay outside the toolkit.

```lisp
(let* ((window (lut:make-widget 'lut:window))
       (model (list :count 0 :allowed t))
       (button (lut:add-child window (lut:make-widget 'lut:button)))
       (command (lut:make-command :increment "Increment"
                  (lambda (command context)
                    (declare (ignore command))
                    (incf (getf context :count)))
                  :enabled-when (lambda (command context)
                                  (declare (ignore command))
                                  (getf context :allowed))
                  :shortcut :f6)))
  (lut:bind-command window command :widget button :context model)
  window)
```

Commands inherit the existing `id`, `enabled-p`, `dispose` and connection
ownership machinery. Do not add them as visual children. `command-label`,
`command-action`, `command-predicate` and `command-shortcut` are mutable. Actions
and predicates are function designators taking `(command context)`; symbolic
functions are looked up at invocation, permitting ordinary live redefinition.
Predicates and context providers should be pure and inexpensive.

## Context and availability

`command-available-p` requires a live command, `enabled-p` true, a non-NIL action,
and a true predicate result when a predicate exists. Each invocation rechecks
availability; a stale enabled button cannot bypass it.

`bind-command` accepts either constant `:context` data (defaulting to the window)
or `:context-function`, a function taking the window and returning current data.
The latter takes precedence when supplied. A shared command can have different
contexts and enabled states in different windows or controls. Pass the active
application model explicitly when clicking a toolbar changes keyboard focus;
LUT does not infer an editor, document or workspace from focus.

A binding owns the control's label and local enabled flag until unbound. Changing
the command's label, action, predicate or master enabled flag refreshes its bound
controls. Input dispatch and rendering also refresh controls automatically.
After changing external data, call `refresh-commands` if you need to inspect
control state before another event/frame. Ancestor disabling still applies.

`invoke-command` returns two values: whether execution occurred, and the action's
primary result. An action returning NIL can execute successfully. Direct calls
are application operations and do not apply window/modal restrictions. Errors
propagate; action side effects are not rolled back.

## Controls, menus and shortcuts

Bind the same command to additional buttons, using `:shortcut-p nil` when the
first binding already registers its shortcut. A `menu-bar` uses ordinary button
children, which accept these bindings. A bound button inside a `context-menu`
automatically dismisses that menu after successful execution.

Bindings add an activation handler; pre-existing handlers remain. A control may
have only one active command binding. Controls can be bound while detached;
they become enabled after adoption by the supplied window and a refresh. Removing
a reusable menu/control leaves its binding registered but inactive until it is
reattached. Dispose transient menus rather than retaining unused bindings.

Shortcuts run through the existing root key event mechanism. Modal overlays and
native modal dialogs suppress parent shortcuts. Active drag sessions retain
priority. A disabled command does not consume a shortcut; the first registered
enabled binding that handles it wins, including ordering with existing `bind-key`
handlers. Successful execution consumes the event before normal widget input. Shortcuts
use command availability rather than a bound control's visibility or inherited
UI disabled state; express application restrictions in the command predicate.

A keyword such as `:f6` or `:control-s` uses existing normalized key names. For
clipboard commands those names can be `:copy`, `:paste`, etc. Exact modifier
specifications use the base key and independent event flags:

```lisp
(setf (lut:command-shortcut command) '(:key :s :super t))
```

This matches Super/Cmd+S with Control, Alt and Shift all false. Omitted modifiers
mean false; allowed keys are `:key`, `:control`, `:alt`, `:super`, `:shift`, with
boolean modifier values. On macOS the compatible keyword `:control-s` still
matches Cmd+S too; use an exact specification to distinguish them. Shortcut
changes are picked up by existing bindings without re-registration.

`window-commands` enumerates distinct currently registered/present commands in
registration order, including disabled commands. Applications can use this to
build palettes or other action surfaces without a toolkit-specific command list.
It does not provide an application command palette or enforce identifier
uniqueness.

## Ownership

`bind-command` returns a `command-binding` handle. `unbind-command` (or `dispose`
on that handle) disconnects its activation and shortcut connections, restores the
control's previous label/enabled state by default, and releases all endpoint,
context and provider references. It is idempotent. Pass `:restore-p nil` to leave
the control disabled instead.

Disposing a control removes its binding without affecting other controls.
Disposing a command removes all its bindings, disables its remaining controls
and releases action/predicate closures. Disposing a window removes its bindings;
a command shared with another window remains usable there. A retained unbound
handle no longer retains its context or controls. An externally retained command
is still application-owned and can be explicitly disposed when no longer needed.

Call command APIs on the GUI/controller thread, using `on-ui` for updates from
another thread. Commands do not create background jobs or own backend resources.

Try `(lut:start (lut-examples:command-actions))` after loading `lut/examples`.
The example shares an action between toolbar/menu buttons and F6, and a checkbox
changes their availability. Native system menus remain a separate platform
integration task; this foundation supplies the reusable command model.
