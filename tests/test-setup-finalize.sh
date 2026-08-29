#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETUP="$REPO_DIR/setup.sh"

FAILURES=0

pass() {
    printf 'PASS  %s\n' "$1"
}

fail() {
    printf 'FAIL  %s\n' "$1"
    FAILURES=$((FAILURES + 1))
}

contains() {
    local pattern="$1"
    local description="$2"

    if grep -Eiq -- "$pattern" "$SETUP"; then
        pass "$description"
    else
        fail "$description"
    fi
}

echo '============================================================'
echo ' Windows RemoteApp Linux v2 - Setup Finalize Contract'
echo '============================================================'
echo

contains \
    '\./setup\.sh finalize' \
    "usage documents finalize command"

contains \
    'finalize\(\)' \
    "setup defines finalize function"

contains \
    'detect-apps\.sh' \
    "finalize references application detector"

contains \
    'create-shortcuts\.sh' \
    "finalize references shortcut generator"

contains \
    '\[\[.*-x.*detect-apps\.sh' \
    "finalize validates detector is executable"

contains \
    '\[\[.*-x.*create-shortcuts\.sh' \
    "finalize validates shortcut generator is executable"

echo
echo '========== ORDER CHECK =========='

DETECT_LINE="$(
    grep -n \
        '"$REPO_DIR/scripts/detect-apps.sh"' \
        "$SETUP" |
        tail -n 1 |
        cut -d: -f1 \
        || true
)"

SHORTCUT_LINE="$(
    grep -n \
        '"$REPO_DIR/scripts/create-shortcuts.sh"' \
        "$SETUP" |
        tail -n 1 |
        cut -d: -f1 \
        || true
)"

if [[ "$DETECT_LINE" =~ ^[0-9]+$ ]] &&
   [[ "$SHORTCUT_LINE" =~ ^[0-9]+$ ]] &&
   (( DETECT_LINE < SHORTCUT_LINE ))
then
    pass "application detection runs before shortcut generation"
else
    fail "application detection runs before shortcut generation"
fi

echo
echo '========== COMMAND ROUTING =========='

if grep -Eq \
    '^[[:space:]]*finalize\)' \
    "$SETUP"
then
    pass "setup command dispatcher routes finalize"
else
    fail "setup command dispatcher routes finalize"
fi

echo
echo '========== INSTALL-WINDOWS SEPARATION =========='

INSTALL_SECTION="$(
    sed -n \
        '/^install_windows()/,/^}/p' \
        "$SETUP"
)"

if printf '%s\n' "$INSTALL_SECTION" |
   grep -Eq 'detect-apps\.sh|create-shortcuts\.sh'
then
    fail "install-windows does not prematurely finalize shortcuts"
else
    pass "install-windows remains separate from post-install finalization"
fi

echo
echo '============================================================'
echo " FAILURES: $FAILURES"
echo '============================================================'

(( FAILURES == 0 ))
