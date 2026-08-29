#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATOR="$REPO_DIR/scripts/create-shortcuts.sh"

TEST_DATA="/tmp/winapps-migration-test-$USER"
APP_DIR="$TEST_DATA/applications"

FAILURES=0

pass() {
    printf 'PASS  %s\n' "$1"
}

fail() {
    printf 'FAIL  %s\n' "$1"
    FAILURES=$((FAILURES + 1))
}

rm -rf "$TEST_DATA"
mkdir -p "$APP_DIR"

# Seed files produced by older repository versions.
for legacy in \
    ms-word.desktop \
    ms-excel.desktop \
    ms-powerpoint.desktop \
    windows-notepad.desktop
do
    printf '[Desktop Entry]\nType=Application\nName=Legacy\n' \
        > "$APP_DIR/$legacy"
done

echo '============================================================'
echo ' Windows RemoteApp Linux v2 - Shortcut Migration Tests'
echo '============================================================'
echo

set +e

GENERATOR_OUTPUT="$(
    XDG_DATA_HOME="$TEST_DATA" \
        "$GENERATOR" 2>&1
)"

GENERATOR_STATUS=$?

set -e

printf '%s\n' "$GENERATOR_OUTPUT"

echo

if (( GENERATOR_STATUS == 0 )); then
    pass "shortcut generator completed"
else
    fail "shortcut generator completed"
fi

for legacy in \
    ms-word.desktop \
    ms-excel.desktop \
    ms-powerpoint.desktop \
    windows-notepad.desktop
do
    if [[ ! -e "$APP_DIR/$legacy" ]]; then
        pass "obsolete $legacy removed"
    else
        fail "obsolete $legacy removed"
    fi
done

POWERSHELL_DESKTOP="$APP_DIR/winapps-powershell.desktop"

if grep -qx 'Categories=System;' "$POWERSHELL_DESKTOP" 2>/dev/null; then
    pass "PowerShell uses one main menu category"
else
    fail "PowerShell uses one main menu category"
fi

if grep -qi 'contains more than one main category' <<< "$GENERATOR_OUTPUT"; then
    fail "desktop generation has no category validation warning"
else
    pass "desktop generation has no category validation warning"
fi

echo
echo '============================================================'
echo " FAILURES: $FAILURES"
echo '============================================================'

(( FAILURES == 0 ))
