#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

LAUNCHER="$REPO_DIR/scripts/broker-launcher.sh"
SHORTCUTS="$REPO_DIR/scripts/create-shortcuts.sh"

FAILURES=0

pass() {
    printf 'PASS  %s\n' "$1"
}

fail() {
    printf 'FAIL  %s\n' "$1"
    FAILURES=$((FAILURES + 1))
}

contains() {
    local file="$1"
    local pattern="$2"
    local description="$3"

    if [[ -f "$file" ]] &&
       grep -Eiq -- "$pattern" "$file"
    then
        pass "$description"
    else
        fail "$description"
    fi
}

echo '============================================================'
echo ' Windows RemoteApp Linux v2 - Production Broker Launcher'
echo '============================================================'
echo

if [[ -x "$LAUNCHER" ]]; then
    pass "production broker launcher exists"
else
    fail "production broker launcher exists"
fi

contains \
    "$LAUNCHER" \
    'start-windows\.sh' \
    "broker launcher starts or reuses Windows"

contains \
    "$LAUNCHER" \
    'broker-request\.sh' \
    "broker launcher queues application requests"

contains \
    "$LAUNCHER" \
    'flock' \
    "broker startup is protected by a lock"

contains \
    "$LAUNCHER" \
    'winappsbroker' \
    "broker launcher configures the redirected RDP drive"

contains \
    "$LAUNCHER" \
    '/drive:' \
    "broker launcher uses RDP drive redirection"

contains \
    "$LAUNCHER" \
    '/args-from:stdin' \
    "FreeRDP arguments are supplied through stdin"

contains \
    "$LAUNCHER" \
    'xfreerdp3|xfreerdp' \
    "broker launcher starts FreeRDP"

contains \
    "$LAUNCHER" \
    'docker[[:space:]]+stop[[:space:]]+"\$CONTAINER"' \
    "broker supervisor stops Windows after broker exits"

contains \
    "$SHORTCUTS" \
    'broker-launcher\.sh' \
    "generated RemoteApp shortcuts use broker launcher"

echo
echo '========== OLD PER-APP LAUNCHER CHECK =========='

if grep -Eq \
    'WINAPP_LAUNCHER=.*winapp-launcher\.sh' \
    "$SHORTCUTS"
then
    fail "shortcut generator no longer targets old per-app launcher"
else
    pass "shortcut generator no longer targets old per-app launcher"
fi

echo
echo '========== CREDENTIAL SAFETY =========='

if [[ -f "$LAUNCHER" ]] &&
   grep -niE \
       'RDP_PASS=|WINDOWS_PASSWORD=|/p:[^"$]' \
       "$LAUNCHER"
then
    fail "broker launcher contains no embedded credential material"
else
    pass "broker launcher contains no embedded credential material"
fi

echo
echo '============================================================'
echo " FAILURES: $FAILURES"
echo '============================================================'

(( FAILURES == 0 ))
