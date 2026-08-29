# 10. Desktop shortcuts

Desktop shortcuts are normally created automatically during:

```bash
./setup.sh finalize
```

The application detector writes:

```text
~/.config/winapps/apps.tsv
```

The shortcut generator then creates application entries under:

```text
~/.local/share/applications/
```

Current shortcut names include:

```text
winapps-word.desktop
winapps-excel.desktop
winapps-powerpoint.desktop
winapps-powershell.desktop
winapps-start-windows.desktop
winapps-windows-desktop.desktop
```

Only applications detected inside Windows receive application-specific shortcuts.

Generated RemoteApp wrappers are stored under:

```text
~/.local/share/winapps/launchers/
```

RemoteApp shortcuts use the production `broker-launcher.sh` path.

They reuse one persistent broker FreeRDP connection instead of creating an independent RDP session for each application.

To refresh shortcuts after installing or removing Windows applications, run:

```bash
./setup.sh finalize
```
