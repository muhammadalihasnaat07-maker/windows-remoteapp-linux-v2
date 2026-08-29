#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLIENT="$REPO_DIR/scripts/broker-request.sh"

TEST_ROOT="/tmp/winapps-broker-request-test-$USER"
REQUEST_DIR="$TEST_ROOT/requests"

FAILURES=0

pass() {
    printf 'PASS  %s\n' "$1"
}

fail() {
    printf 'FAIL  %s\n' "$1"
    FAILURES=$((FAILURES + 1))
}

rm -rf "$TEST_ROOT"
mkdir -p "$REQUEST_DIR"

APP_PATH='C:\Program Files\Microsoft Office\Root\Office16\WINWORD.EXE'

echo '============================================================'
echo ' Windows RemoteApp Linux v2 - Broker Request Test'
echo '============================================================'
echo

if [[ -x "$CLIENT" ]]; then
    pass "broker request client exists"
else
    fail "broker request client exists"
fi

echo
echo '========== ENQUEUE REQUEST =========='

set +e

WINAPPS_BROKER_REQUEST_DIR="$REQUEST_DIR" \
    "$CLIENT" "$APP_PATH" \
    >"$TEST_ROOT/stdout.log" \
    2>"$TEST_ROOT/stderr.log"

CLIENT_STATUS=$?

set -e

echo "client exit code: $CLIENT_STATUS"

if [[ -s "$TEST_ROOT/stdout.log" ]]; then
    echo
    echo '--- stdout ---'
    cat "$TEST_ROOT/stdout.log"
fi

if [[ -s "$TEST_ROOT/stderr.log" ]]; then
    echo
    echo '--- stderr ---'
    cat "$TEST_ROOT/stderr.log"
fi

echo
echo '========== REQUEST FILES =========='

find "$REQUEST_DIR" \
    -maxdepth 1 \
    -type f \
    -printf '%f\n' \
    2>/dev/null \
    | sort

REQUEST_COUNT="$(
    find "$REQUEST_DIR" \
        -maxdepth 1 \
        -type f \
        -name '*.request' \
        2>/dev/null \
        | wc -l
)"

if (( CLIENT_STATUS == 0 )); then
    pass "broker request client exits successfully"
else
    fail "broker request client exits successfully"
fi

if (( REQUEST_COUNT == 1 )); then
    pass "exactly one request file created"
else
    fail "exactly one request file created"
fi

REQUEST_FILE="$(
    find "$REQUEST_DIR" \
        -maxdepth 1 \
        -type f \
        -name '*.request' \
        2>/dev/null \
        | head -n 1
)"

if [[ -n "$REQUEST_FILE" ]]; then

    echo
    echo '========== REQUEST CONTENT =========='
    cat "$REQUEST_FILE"

    REQUEST_CONTENT="$(cat "$REQUEST_FILE")"

    if [[ "$REQUEST_CONTENT" == "$APP_PATH" ]]; then
        pass "request preserves Windows application path"
    else
        fail "request preserves Windows application path"
    fi

    REQUEST_MODE="$(stat -c '%a' "$REQUEST_FILE")"

    if [[ "$REQUEST_MODE" == "600" ]]; then
        pass "request file mode is 600"
    else
        echo "actual mode: $REQUEST_MODE"
        fail "request file mode is 600"
    fi

else
    fail "request preserves Windows application path"
    fail "request file mode is 600"
fi

echo
echo '========== NO CREDENTIAL MATERIAL =========='

if grep -RniE \
    'RDP_PASS=|WINDOWS_PASSWORD=|/p:' \
    "$TEST_ROOT" \
    2>/dev/null
then
    fail "request contains no credential material"
else
    pass "request contains no credential material"
fi

echo
echo '============================================================'
echo " FAILURES: $FAILURES"
echo '============================================================'

(( FAILURES == 0 ))
