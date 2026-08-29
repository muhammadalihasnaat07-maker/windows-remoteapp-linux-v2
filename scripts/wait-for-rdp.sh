#!/usr/bin/env bash
set -Eeuo pipefail

CREDENTIALS_FILE="${WINAPPS_CREDENTIALS_FILE:-$HOME/.config/winapps/credentials}"

RDP_HOST="${WINAPPS_RDP_HOST:-127.0.0.1}"
RDP_PORT="${WINAPPS_RDP_PORT:-3389}"

READY_TIMEOUT="${WINAPPS_READY_TIMEOUT:-600}"
AUTH_TIMEOUT="${WINAPPS_AUTH_TIMEOUT:-20}"
RETRY_INTERVAL="${WINAPPS_READY_INTERVAL:-5}"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

# ------------------------------------------------------------
# Validate numeric settings
# ------------------------------------------------------------

[[ "$READY_TIMEOUT" =~ ^[1-9][0-9]*$ ]] ||
    die "WINAPPS_READY_TIMEOUT must be a positive integer."

[[ "$AUTH_TIMEOUT" =~ ^[1-9][0-9]*$ ]] ||
    die "WINAPPS_AUTH_TIMEOUT must be a positive integer."

[[ "$RETRY_INTERVAL" =~ ^[1-9][0-9]*$ ]] ||
    die "WINAPPS_READY_INTERVAL must be a positive integer."

# ------------------------------------------------------------
# Locate FreeRDP
# ------------------------------------------------------------

if command -v xfreerdp3 >/dev/null 2>&1; then
    FREERDP_BIN="$(command -v xfreerdp3)"
elif command -v xfreerdp >/dev/null 2>&1; then
    FREERDP_BIN="$(command -v xfreerdp)"
else
    die "FreeRDP executable not found."
fi

command -v timeout >/dev/null 2>&1 ||
    die "timeout command not found."

# ------------------------------------------------------------
# Load credentials
# ------------------------------------------------------------

[[ -f "$CREDENTIALS_FILE" ]] ||
    die "Credentials file not found: $CREDENTIALS_FILE"

# shellcheck disable=SC1090
source "$CREDENTIALS_FILE"

[[ -n "${RDP_USER:-}" ]] ||
    die "RDP_USER is missing from $CREDENTIALS_FILE"

[[ -n "${RDP_PASS:-}" ]] ||
    die "RDP_PASS is missing from $CREDENTIALS_FILE"

# ------------------------------------------------------------
# Authentication probe
# ------------------------------------------------------------

probe_rdp() {
    printf '%s\n' \
        "/v:${RDP_HOST}:${RDP_PORT}" \
        "/u:${RDP_USER}" \
        "/p:${RDP_PASS}" \
        "/cert:ignore" \
        "/log-level:ERROR" \
        "+auth-only" |
        timeout "$AUTH_TIMEOUT" \
            "$FREERDP_BIN" \
            /args-from:stdin \
            >/dev/null 2>&1
}

echo '============================================================'
echo ' Windows RemoteApp Linux v2 - RDP Readiness'
echo '============================================================'
echo
echo "Target: ${RDP_HOST}:${RDP_PORT}"
echo "User:   $RDP_USER"
echo "Auth:   password hidden"
echo

START_TIME="$(date +%s)"
ATTEMPT=0

while true; do
    ATTEMPT=$((ATTEMPT + 1))

    if probe_rdp; then
        ELAPSED=$(( $(date +%s) - START_TIME ))

        echo
        echo "READY: Windows accepted FreeRDP authentication."
        echo "Attempts: $ATTEMPT"
        echo "Elapsed: ${ELAPSED}s"

        exit 0
    fi

    ELAPSED=$(( $(date +%s) - START_TIME ))

    if (( ELAPSED >= READY_TIMEOUT )); then
        echo
        echo "ERROR: Windows did not become RDP-authentication ready." >&2
        echo "Attempts: $ATTEMPT" >&2
        echo "Elapsed: ${ELAPSED}s" >&2

        exit 1
    fi

    printf '\rChecking Windows RDP readiness... attempt %d' "$ATTEMPT"

    sleep "$RETRY_INTERVAL"
done
