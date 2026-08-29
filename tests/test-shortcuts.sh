#!/usr/bin/env bash
set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

FAILURES=0

pass() {
    printf 'PASS  %s\n' "$1"
}

fail() {
    printf 'FAIL  %s\n' "$1"
    FAILURES=$((FAILURES + 1))
}

require_file() {
    local file="$1"
    local description="$2"

    if [[ -f "$file" ]]; then
        pass "$description"
    else
        fail "$description -- missing: $file"
    fi
}

require_executable() {
    local file="$1"
    local description="$2"

    if [[ -x "$file" ]]; then
        pass "$description"
    else
        fail "$description -- not executable/missing: $file"
    fi
}

echo '============================================================'
echo ' Windows RemoteApp Linux v2 - Shortcut Tests'
echo '============================================================'
echo

# ------------------------------------------------------------
# Production scripts expected by the design
# ------------------------------------------------------------

require_executable \
    "$REPO_DIR/scripts/create-shortcuts.sh" \
    "shortcut generator exists"

require_executable \
    "$REPO_DIR/scripts/windows-desktop.sh" \
    "Windows Desktop launcher exists"

require_executable \
    "$REPO_DIR/scripts/start-windows.sh" \
    "Start Windows backend exists"

require_executable \
    "$REPO_DIR/scripts/winapp-launcher.sh" \
    "RemoteApp backend exists"

echo

# ------------------------------------------------------------
# Static design requirements
# ------------------------------------------------------------

if [[ -f "$REPO_DIR/scripts/create-shortcuts.sh" ]]; then

    if grep -q 'apps.tsv' \
        "$REPO_DIR/scripts/create-shortcuts.sh"
    then
        pass "shortcut generator reads application manifest"
    else
        fail "shortcut generator reads application manifest"
    fi

    if grep -q 'XDG_DATA_HOME' \
        "$REPO_DIR/scripts/create-shortcuts.sh" &&
       grep -q '/applications' \
        "$REPO_DIR/scripts/create-shortcuts.sh"
    then
        pass "shortcuts target Linux application menu"
    else
        fail "shortcuts target Linux application menu"
    fi

    if grep -q 'broker-launcher.sh' \
        "$REPO_DIR/scripts/create-shortcuts.sh"
    then
        pass "RemoteApp shortcuts use broker launcher"
    else
        fail "RemoteApp shortcuts use broker launcher"
    fi

    if grep -q 'start-windows.sh' \
        "$REPO_DIR/scripts/create-shortcuts.sh"
    then
        pass "Start Windows shortcut uses starter"
    else
        fail "Start Windows shortcut uses starter"
    fi

    if grep -q 'windows-desktop.sh' \
        "$REPO_DIR/scripts/create-shortcuts.sh"
    then
        pass "Windows Desktop shortcut uses desktop launcher"
    else
        fail "Windows Desktop shortcut uses desktop launcher"
    fi

    if grep -Eq \
        'RDP_PASS=|WINDOWS_PASSWORD=|/p:' \
        "$REPO_DIR/scripts/create-shortcuts.sh"
    then
        fail "shortcut generator contains no credential material"
    else
        pass "shortcut generator contains no credential material"
    fi

fi

echo

if [[ -f "$REPO_DIR/scripts/windows-desktop.sh" ]]; then

    if grep -q 'start-windows.sh' \
        "$REPO_DIR/scripts/windows-desktop.sh"
    then
        pass "desktop launcher uses Windows starter"
    else
        fail "desktop launcher uses Windows starter"
    fi

    if grep -q '/args-from:stdin' \
        "$REPO_DIR/scripts/windows-desktop.sh"
    then
        pass "desktop launcher supplies FreeRDP arguments via stdin"
    else
        fail "desktop launcher supplies FreeRDP arguments via stdin"
    fi

    if grep -Eq \
        'xfreerdp(3)? .*\/p:' \
        "$REPO_DIR/scripts/windows-desktop.sh"
    then
        fail "desktop launcher exposes password in process arguments"
    else
        pass "desktop launcher avoids password process argument"
    fi

    if grep -q 'docker stop' \
        "$REPO_DIR/scripts/windows-desktop.sh"
    then
        fail "desktop launcher must not automatically stop Windows"
    else
        pass "desktop launcher leaves Windows running after disconnect"
    fi

fi

echo
echo '============================================================'
echo " FAILURES: $FAILURES"
echo '============================================================'

if (( FAILURES > 0 )); then
    exit 1
fi

exit 0
