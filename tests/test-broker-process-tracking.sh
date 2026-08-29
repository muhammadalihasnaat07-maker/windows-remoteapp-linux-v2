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

    if grep -Eiq -- "$pattern" "$BROKER"; then
        pass "$description"
    else
        fail "$description"
    fi
}

echo '============================================================'
echo ' Windows RemoteApp Linux v2 - Broker Process Tracking'
echo '============================================================'
echo

contains \
    '\$aliveProcesses[[:space:]]*=[[:space:]]*@\(\)' \
    "broker builds an explicit alive-process list"

contains \
    'foreach[[:space:]]*\(\$process[[:space:]]+in[[:space:]]+\$managedProcesses\)' \
    "broker checks tracked processes explicitly"

contains \
    '\$process\.HasExited' \
    "broker checks HasExited on the named process object"

contains \
    '\$aliveProcesses[[:space:]]*\+=' \
    "running processes are explicitly preserved"

contains \
    '\$managedProcesses[[:space:]]*=[[:space:]]*@\(\$aliveProcesses\)' \
    "managed process list is replaced with verified live processes"

echo
echo '========== UNSAFE PIPELINE FILTER CHECK =========='

if grep -Eq \
    'Where-Object' \
    "$BROKER"
then
    fail "broker does not use Where-Object for managed-process lifecycle tracking"
else
    pass "broker does not use Where-Object for managed-process lifecycle tracking"
fi

echo
echo '========== CREDENTIAL SAFETY =========='

if grep -niE \
    'RDP_PASS=|WINDOWS_PASSWORD=|/p:' \
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
