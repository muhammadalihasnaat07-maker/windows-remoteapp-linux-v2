# 4. Create or start Windows

The v2 Windows installation is managed through `setup.sh`.

Configure first:

```bash
./setup.sh configure
```

Optionally validate the install action:

```bash
./setup.sh install-windows --dry-run
```

Then start Windows installation:

```bash
./setup.sh install-windows
```

The default container is named `WinApps`.

The persistent Windows disk is stored in the Docker volume:

```text
winapps_data
```

The Windows installer/web console is available at:

```text
http://127.0.0.1:8006
```

Complete Windows installation there and install any desired Windows applications before finalizing.

The container is disposable. The `winapps_data` volume is the persistent Windows asset and should not be deleted during routine troubleshooting.
