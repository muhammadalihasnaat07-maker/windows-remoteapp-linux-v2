#!/usr/bin/env bash
set -u

echo "=== Session ==="
echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-unknown}"

echo
echo "=== FreeRDP ==="
command -v xfreerdp3 || true
xfreerdp3 /version 2>/dev/null || true

echo
echo "=== Docker ==="
docker --version 2>/dev/null || true
sudo -n docker ps -a --filter name=WinApps 2>/dev/null || true

echo
echo "=== Processes ==="
pgrep -af 'winapp-launcher|office-launcher|xfreerdp3' || echo "None"

echo
echo "=== Runtime markers ==="
find "${XDG_RUNTIME_DIR:-/tmp}/winapps-container-manager" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null || true

echo
echo "=== Shortcuts ==="
grep -RHi '^Exec=' "$HOME/.local/share/applications" "$HOME/Desktop" 2>/dev/null | grep -Ei 'winapp|xfreerdp|WINWORD|EXCEL|POWERPNT|notepad' || true
