# 12. Troubleshooting

## Window opens but cannot receive input

Cause: Wayland/XWayland input handling.

Fix: log into an X11/Xorg session.

## `BadMatch` or `X_CopyArea`

Cause: older FreeRDP X11/RAIL rendering defect.

Fix: upgrade FreeRDP and retain `-gfx`.

## `LOGON_MSG_BUMP_OPTIONS`

Cause: another Windows console or RDP session is active.

Fix: log off the competing session using `query session` and `logoff`.

## First cold launch resets the connection

Cause: port 3389 opens before Windows logon services are fully initialized.

Fix: the launcher waits for the port and then applies an additional cold-boot delay.

## Container starts but does not stop

Check:

```bash
pgrep -af 'winapp-launcher|xfreerdp3'
find "${XDG_RUNTIME_DIR:-/tmp}/winapps-container-manager" -maxdepth 1 -type f -printf '%f\n'
cat "$HOME/.winapps-cleanup.log"
```

Make sure the launcher calls `xfreerdp3` directly. Do not prefix it with `exec`.

## Kerberos default realm warning

This is commonly non-fatal for a local username/password connection. Focus on the final FreeRDP connection error instead.
