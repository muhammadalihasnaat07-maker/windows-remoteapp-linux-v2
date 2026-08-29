# 12. Troubleshooting

Start with:

```bash
./scripts/diagnose-winapps.sh
```

and:

```bash
./scripts/preflight.sh
```

## RemoteApp opens but cannot receive keyboard or mouse input

Check:

```bash
echo "$XDG_SESSION_TYPE"
```

The current supported path requires:

```text
x11
```

Log into an X11/Xorg desktop session if necessary.

## `BadMatch` or `X_CopyArea`

Check the FreeRDP version:

```bash
xfreerdp3 /version
```

FreeRDP 3.26 or newer is required by this project.

## Windows is running but the first RemoteApp does not appear

Do not use TCP port `3389` alone as the readiness signal.

The v2 startup path waits for successful FreeRDP authentication readiness.

Run:

```bash
./scripts/diagnose-winapps.sh
```

Also inspect the Windows console at:

```text
http://127.0.0.1:8006
```

## One application closes or logs off when another application starts

Production shortcuts must use the persistent broker architecture.

Check current shortcut targets:

```bash
grep -RH '^Exec=' "${XDG_DATA_HOME:-$HOME/.local/share}/applications"/winapps-*.desktop
```

Then run:

```bash
./scripts/diagnose-winapps.sh
```

There should normally be one persistent broker FreeRDP session.

If shortcuts are stale, re-run:

```bash
./setup.sh finalize
```

## Container does not stop after the final RemoteApp closes

Inspect broker state with:

```bash
./scripts/diagnose-winapps.sh
```

The broker runtime directory is:

```text
${XDG_RUNTIME_DIR:-/tmp}/winapps-$UID/broker
```

Important PID files are:

```text
supervisor.pid
freerdp.pid
```

After the final managed Windows process closes, the Windows broker should exit. The Linux supervisor then stops the `WinApps` container.

## Container is missing but the Windows volume still exists

Check:

```bash
docker volume inspect winapps_data
```

If the persistent volume exists, start Windows with:

```bash
./scripts/start-windows.sh
```

The startup script can reconstruct the disposable container around the existing Windows volume.

## Windows data is unexpectedly missing

Check:

```bash
docker volume ls
```

Do not use Docker volume-pruning commands when the Windows installation must be preserved.

## `LOGON_MSG_BUMP_OPTIONS`

This usually indicates a competing Windows console or RDP session.

Close or log off the competing Windows session before starting the RemoteApp broker.

## Kerberos default realm warnings

For a local username/password RDP connection these warnings can be non-fatal.

Diagnose based on the final FreeRDP authentication result rather than the Kerberos warning alone.
