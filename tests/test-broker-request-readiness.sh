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
echo ' Windows RemoteApp Linux v2 - Request Readiness Contract'
echo '============================================================'
echo

contains \
    'rawContent|requestContent' \
    "broker stores raw request content before trimming"

contains \
    'IsNullOrWhiteSpace.*rawContent|IsNullOrWhiteSpace.*requestContent' \
    "broker detects temporarily empty request content"

contains \
    'continue' \
    "broker retries an unreadable request on a later poll"

echo
echo '========== UNSAFE DIRECT TRIM CHECK =========='

if grep -Eq \
    '\(.*Get-Content|Get-Content.*-Raw.*\)\.Trim' \
    "$BROKER"
then
    fail "broker does not Trim directly on nullable Get-Content result"
else
    pass "broker does not Trim directly on nullable Get-Content result"
fi

echo
echo '========== REQUEST DELETION SAFETY =========='

if grep -Eiq \
    'Remove-Item' \
    "$BROKER"
then
    pass "processed requests are still removable"
else
    fail "processed requests are still removable"
fi

echo
echo '============================================================'
echo " FAILURES: $FAILURES"
echo '============================================================'

(( FAILURES == 0 ))
