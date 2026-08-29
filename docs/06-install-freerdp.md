# 6. Install FreeRDP

FreeRDP 3.26 or newer is required by this project.

Verify the installed version:

```bash
xfreerdp3 /version
```

On supported Debian-family systems, the repository dependency installer can install the required packages:

```bash
./scripts/install-dependencies.sh
```

Package names differ between distributions and releases.

If your distribution package is too old, use the supported newer package source for that distribution rather than copying a backports suite name blindly.

The v2 launchers use FreeRDP for:

- authentication readiness checks;
- the full Windows desktop;
- the persistent RemoteApp / RAIL broker connection.

Credentials are supplied through `/args-from:stdin` so the runtime password is not placed in the FreeRDP process argument list.
