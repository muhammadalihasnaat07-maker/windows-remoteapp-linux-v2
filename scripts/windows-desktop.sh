#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

START_SCRIPT="$SCRIPT_DIR/start-windows.sh"

WINAPPS_CONFIG_DIR="${WINAPPS_CONFIG_DIR:-$HOME/.config/winapps}"
CREDENTIALS_FILE="${WINAPPS_CREDENTIALS_FILE:-$WINAPPS_CONFIG_DIR/credentials}"

RDP_HOST="${WINAPPS_RDP_HOST:-127.0.0.1}"
RDP_PORT="${WINAPPS_RDP_PORT:-3389}"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

[[ -x "$START_SCRIPT" ]] ||
    die "Windows startup script missing: $START_SCRIPT"

[[ -f "$CREDENTIALS_FILE" ]] ||
    die "Credentials file missing: $CREDENTIALS_FILE"

if [[ "${XDG_SESSION_TYPE:-}" != "x11" ]]; then
    die "Windows Desktop currently requires an X11 session."
fi

if command -v xfreerdp3 >/dev/null 2>&1; then
    FREERDP_BIN="$(command -v xfreerdp3)"
elif command -v xfreerdp >/dev/null 2>&1; then
    FREERDP_BIN="$(command -v xfreerdp)"
else
    die "FreeRDP executable not found."
fi

# shellcheck disable=SC1090
source "$CREDENTIALS_FILE"

[[ -n "${RDP_USER:-}" ]] ||
    die "RDP_USER missing from $CREDENTIALS_FILE"

[[ -n "${RDP_PASS:-}" ]] ||
    die "RDP_PASS missing from $CREDENTIALS_FILE"

echo "Preparing Windows..."

WINAPPS_CREDENTIALS_FILE="$CREDENTIALS_FILE" \
    "$START_SCRIPT"

echo
echo "Opening Windows Desktop..."
echo

set +e

printf '%s\n' \
    "/v:${RDP_HOST}:${RDP_PORT}" \
    "/u:${RDP_USER}" \
    "/p:${RDP_PASS}" \
    "/cert:ignore" \
    "/log-level:WARN" \
    "/dynamic-resolution" \
    "+clipboard" \
    "+auto-reconnect" |
    "$FREERDP_BIN" /args-from:stdin

RDP_STATUS="${PIPESTATUS[1]}"

set -e

case "$RDP_STATUS" in
    0)
        echo
        echo "Windows Desktop connection ended normally."
        exit 0
        ;;

    11)
        echo
        echo "Windows Desktop disconnected by user."
        exit 0
        ;;

    12)
        echo
        echo "Windows Desktop session logged off normally."
        exit 0
        ;;

    *)
        echo
        echo "Windows Desktop ended with FreeRDP exit code: $RDP_STATUS" >&2
        exit "$RDP_STATUS"
        ;;
esac
