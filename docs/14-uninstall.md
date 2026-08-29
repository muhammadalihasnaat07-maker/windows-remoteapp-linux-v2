# 14. Uninstall

Use the repository uninstaller rather than manually tearing down Docker resources.

## Safe default uninstall

Run:

```bash
./uninstall.sh
```

The default operation removes:

- the disposable `WinApps` Docker container;
- generated WinApps desktop entries;
- generated RemoteApp launcher wrappers;
- the generated application manifest;
- local WinApps credentials managed by the project;
- obsolete v1 shortcut/launcher artifacts when present.

It preserves:

- the persistent `winapps_data` Docker volume;
- the host WinApps working/shared directory.

This means the Windows installation remains recoverable.

## Permanently delete Windows data

To explicitly destroy the Windows installation stored in `winapps_data`:

```bash
./uninstall.sh --purge-data
```

The command requires confirmation.

For an explicitly approved non-interactive purge:

```bash
./uninstall.sh --purge-data --yes
```

`--purge-data` permanently removes the Windows disk and cannot be undone through this project.

The host WinApps working/shared directory is still preserved.

## Help

```bash
./uninstall.sh --help
```

Do not manually remove `winapps_data` unless permanent Windows-data destruction is intentional.
