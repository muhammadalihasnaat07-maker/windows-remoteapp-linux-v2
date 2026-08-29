#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHER="$SCRIPT_DIR/broker-launcher.sh"

[[ -x "$LAUNCHER" ]] || {
    echo "ERROR: production broker launcher missing: $LAUNCHER" >&2
    exit 1
}

echo '============================================================'
echo ' Windows RemoteApp Linux v2 - Notepad Test'
echo '============================================================'
echo
echo 'A Windows Notepad RemoteApp should open through the'
echo 'persistent WinApps broker connection.'
echo
echo 'Before closing it, manually test:'
echo '  1. Type text'
echo '  2. Resize the window'
echo '  3. Minimize and restore it'
echo '  4. Maximize and restore it'
echo '  5. Copy Linux text and paste it into Notepad'
echo '  6. Copy Notepad text and paste it into Linux'
echo
echo 'Then close Notepad normally.'
echo 'If it is the final managed RemoteApp, Windows should'
echo 'stop automatically after the broker shutdown grace period.'
echo

"$LAUNCHER" 'C:\Windows\System32\notepad.exe'
