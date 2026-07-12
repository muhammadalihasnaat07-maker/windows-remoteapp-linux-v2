#!/usr/bin/env bash
set -Eeuo pipefail

LAUNCHER="${WINAPPS_LAUNCHER:-$HOME/.local/bin/winapp-launcher}"
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$APP_DIR"

create_shortcut() {
  local id="$1" name="$2" icon="$3" app="$4"
  cat > "$APP_DIR/$id.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$LAUNCHER "$app"
Icon=$icon
Terminal=false
Categories=Office;
StartupNotify=true
DESKTOP
  chmod +x "$APP_DIR/$id.desktop"
}

create_shortcut "ms-word" "Microsoft Word" "x-office-document" 'C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE'
create_shortcut "ms-excel" "Microsoft Excel" "x-office-spreadsheet" 'C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE'
create_shortcut "ms-powerpoint" "Microsoft PowerPoint" "x-office-presentation" 'C:\Program Files\Microsoft Office\root\Office16\POWERPNT.EXE'
create_shortcut "windows-notepad" "Windows Notepad" "accessories-text-editor" 'notepad.exe'

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APP_DIR" || true

echo "Shortcuts created in $APP_DIR"
