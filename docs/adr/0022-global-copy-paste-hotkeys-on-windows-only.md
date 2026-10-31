# ADR-0022 — Global copy/paste hot keys on Windows only

- Status: Accepted (implemented; Linux build checked, Windows objects unchanged)
- Date: 2026-10-31
- Deciders: Harald Lapp (project owner)

## Context

`TQueryBrowserForm.FormCreate` registers Ctrl+Alt+Shift+C and Ctrl+Alt+Shift+V system-wide
(`RegisterHotKey`). `WMHotKey` then looks at the foreground window of another program, sends it Ctrl+C
(`keybd_event`) or a message, reads the clipboard, strips the SQL out of PHP or Java string literals
(`CaptureSQLFromClipboard`) and puts the cleaned statement into the query area, or the reverse for paste
(`AttachThreadInput`, `GetForegroundWindow`). The mode (keystrokes or window message) is chosen from the
foreign window's class; there is no option for it.

This needs three things from the window system: a shortcut that works while another program has the focus,
the identity of that program's window, and typing into it. X11 offers all three (`XGrabKey`, `XTest`);
Wayland offers none of the last two by design (the XDG GlobalShortcuts portal can deliver a shortcut, but
no portal lets a program send keystrokes to another one or read its window). The target platform is a
Wayland desktop as much as an X11 one.

## Decision

- The feature stays Windows-only. Outside Windows no hot keys are registered and `WMHotKey` is not
  compiled (`{$IFDEF MSWINDOWS}` with a `// Port:` comment, already in place).
- No replacement is built for X11 alone: a feature that works on half of the Linux desktops and silently
  not on the other half would be harder to explain than its absence.
- Menu items and shortcuts inside the application (the "Copy as PHP/Java code" menu items)
  are not affected; they use the application's own clipboard access.

## Consequences

Positive:
- No platform-specific input injection to maintain or secure; the Windows behaviour is unchanged.

Negative:
- Linux users cannot capture a statement out of an editor with a key press; they copy it and use the
  menu entry. This is the only workflow of the original that has no Linux counterpart so far.
- The shortcuts Ctrl+Alt+Shift+C/V are documented nowhere in the UI, so there is nothing to hide.

Deferred: a Wayland-capable variant (GlobalShortcuts portal to trigger, the clipboard to transfer, no
typing into the other program) as a different feature with its own ADR, if it is wanted.

## Alternatives considered

- **X11 implementation (`XGrabKey` + `XTest`):** works under X11 and XWayland-only applications at best;
  silently useless on a Wayland session. Rejected for now.
- **GlobalShortcuts portal now:** delivers the key press, but the copy half of the feature (Ctrl+C into
  the other program) is impossible, so only half of the feature would exist.
- **Hide the whole feature on Windows too:** would change the Windows behaviour (ADR-0001).

## Related

- ADR-0001 — no UX changes on Windows.
- `docs/linux-port.md`, section 4.3.
