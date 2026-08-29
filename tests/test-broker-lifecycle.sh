#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BROKER="$REPO_DIR/oem/winapps-broker.ps1"

FAILURES=0

pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; FAILURES=$((FAILURES + 1)); }

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
echo ' Windows RemoteApp Linux v2 - Broker Lifecycle Contract'
echo '============================================================'
echo

contains \
    'managedProcesses|activeProcesses' \
    "broker tracks managed application processes"

contains \
    '-PassThru' \
    "Start-Process returns process object"

contains \
    'HasExited' \
    "broker detects closed managed applications"

contains \
    'hasLaunched|startedAny|launchedAny' \
    "broker distinguishes startup from post-app idle state"

contains \
    'Grace.*Seconds|Exit.*Grace|Idle.*Seconds' \
    "broker has last-app shutdown grace period"

contains \
    'break' \
    "broker can terminate its persistent loop"

echo
echo '========== EXISTING BROKER SAFETY =========='

if grep -niE \
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
