# 10. Create desktop shortcuts

```bash
WINAPPS_LAUNCHER="$HOME/.local/bin/winapp-launcher" ./scripts/create-shortcuts.sh
```

Generated shortcuts are stored in:

```text
~/.local/share/applications
```

Example:

```ini
[Desktop Entry]
Type=Application
Name=Microsoft Word
Exec=/home/USER/.local/bin/winapp-launcher "C:\\Program Files\\Microsoft Office\\root\\Office16\\WINWORD.EXE"
Terminal=false
Categories=Office;
```
