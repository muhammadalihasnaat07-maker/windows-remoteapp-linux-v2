#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BROKER="$REPO_DIR/oem/winapps-broker.ps1"

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

    if [[ -f "$BROKER" ]] && grep -Eiq -- "$pattern" "$BROKER"; then
        pass "$description"
    else
        fail "$description"
    fi
}

echo '============================================================'
echo ' Windows RemoteApp Linux v2 - Windows Broker Contract'
echo '============================================================'
echo

if [[ -f "$BROKER" ]]; then
    pass "Windows broker script exists"
else
    fail "Windows broker script exists"
fi

contains \
    'param[[:space:]]*\(' \
    "broker accepts parameters"

contains \
    'RequestDir' \
    "broker accepts request directory"

contains \
    'Get-ChildItem' \
    "broker enumerates request directory"

contains \
    '\*\.request' \
    "broker filters request files"

contains \
    'Get-Content' \
    "broker reads request content"

contains \
    '-Raw' \
    "broker reads complete request path"

contains \
    'Start-Process' \
    "broker launches requested application"

contains \
    'Remove-Item' \
    "broker consumes processed request"

contains \
    '(while|for)[[:space:]]*\(' \
    "broker remains alive for later requests"

contains \
    'Start-Sleep' \
    "broker avoids busy polling"

echo
echo '========== CREDENTIAL SCAN =========='

if [[ -f "$BROKER" ]] &&
   grep -niE \
       'RDP_PASS|WINDOWS_PASSWORD|/p:|abc' \
       "$BROKER"
then
    fail "broker contains no credential material"
else
    pass "broker contains no credential material"
fi

echo
echo '============================================================'
echo " FAILURES: $FAILURES"
echo '============================================================'

(( FAILURES == 0 ))
