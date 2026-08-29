#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

START_SCRIPT="$SCRIPT_DIR/start-windows.sh"

WINAPPS_CONFIG_DIR="${WINAPPS_CONFIG_DIR:-$HOME/.config/winapps}"
CREDENTIALS_FILE="${WINAPPS_CREDENTIALS_FILE:-$WINAPPS_CONFIG_DIR/credentials}"

CONTAINER_NAME="${WINAPPS_CONTAINER_NAME:-WinApps}"

RDP_HOST="${WINAPPS_RDP_HOST:-127.0.0.1}"
RDP_PORT="${WINAPPS_RDP_PORT:-3389}"

STOP_GRACE="${WINAPPS_STOP_GRACE:-5}"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

usage() {
    cat <<USAGE
Usage:
  $0 <windows-program-path> [windows-command-line]

Examples:
  $0 'C:\Windows\System32\notepad.exe'

  $0 \
    'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' \
    '-NoProfile -File "Z:\script.ps1"'
USAGE
}

if (( $# < 1 || $# > 2 )); then
    usage
    exit 2
fi

APP_PATH="$1"
APP_CMD="${2:-}"

[[ -n "$APP_PATH" ]] ||
    die "Windows application path cannot be empty."

if [[ "$APP_PATH" == *$'\n'* || "$APP_CMD" == *$'\n'* ]]; then
    die "Application path/command must not contain newline characters."
fi

[[ "$STOP_GRACE" =~ ^[0-9]+$ ]] ||
    die "WINAPPS_STOP_GRACE must be a non-negative integer."

[[ -x "$START_SCRIPT" ]] ||
    die "Windows startup script missing: $START_SCRIPT"

[[ -f "$CREDENTIALS_FILE" ]] ||
    die "Credentials file missing: $CREDENTIALS_FILE"

# ------------------------------------------------------------
# X11 requirement
# ------------------------------------------------------------

if [[ "${XDG_SESSION_TYPE:-}" != "x11" ]]; then
    die "RemoteApp launcher currently requires an X11 session."
fi

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

# ------------------------------------------------------------
# Load credentials
# ------------------------------------------------------------

# shellcheck disable=SC1090
source "$CREDENTIALS_FILE"

[[ -n "${RDP_USER:-}" ]] ||
    die "RDP_USER missing from $CREDENTIALS_FILE"

[[ -n "${RDP_PASS:-}" ]] ||
    die "RDP_PASS missing from $CREDENTIALS_FILE"

# ------------------------------------------------------------
# Runtime/session state
# ------------------------------------------------------------

RUNTIME_ROOT="${XDG_RUNTIME_DIR:-/tmp}"
RUNTIME_DIR="$RUNTIME_ROOT/winapps-$UID"

STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$STATE_ROOT/winapps"

CLEANUP_LOCK="$RUNTIME_DIR/cleanup.lock"
SESSION_MARKER="$RUNTIME_DIR/session-$$"
CLEANUP_LOG="$STATE_DIR/cleanup.log"

mkdir -p "$RUNTIME_DIR" "$STATE_DIR"

chmod 700 "$RUNTIME_DIR"
chmod 700 "$STATE_DIR"

touch "$CLEANUP_LOG"
chmod 600 "$CLEANUP_LOG"

log_cleanup() {
    printf '%s %s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$*" \
        >> "$CLEANUP_LOG"
}

cleanup_stale_markers() {
    local marker pid

    shopt -s nullglob

    for marker in "$RUNTIME_DIR"/session-*; do
        [[ -f "$marker" ]] || continue

        pid="$(cat "$marker" 2>/dev/null || true)"

        if [[ ! "$pid" =~ ^[0-9]+$ ]] ||
           ! kill -0 "$pid" 2>/dev/null; then

            rm -f "$marker"
            log_cleanup "removed stale marker $(basename "$marker")"
        fi
    done

    shopt -u nullglob
}

cleanup() {
    local original_status=$?
    local markers=()

    trap - EXIT INT TERM HUP

    rm -f "$SESSION_MARKER"

    if (( STOP_GRACE > 0 )); then
        sleep "$STOP_GRACE"
    fi

    exec 8>"$CLEANUP_LOCK"
    flock 8

    cleanup_stale_markers

    shopt -s nullglob
    markers=("$RUNTIME_DIR"/session-*)
    shopt -u nullglob

    if (( ${#markers[@]} == 0 )); then
        if docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then

            running="$(
                docker inspect \
                    --format '{{.State.Running}}' \
                    "$CONTAINER_NAME" \
                    2>/dev/null ||
                true
            )"

            if [[ "$running" == "true" ]]; then
                log_cleanup "last managed RemoteApp closed; stopping $CONTAINER_NAME"

                docker stop "$CONTAINER_NAME" \
                    >>"$CLEANUP_LOG" 2>&1 ||
                    log_cleanup "WARNING: docker stop $CONTAINER_NAME failed"
            fi
        fi
    else
        log_cleanup \
            "managed RemoteApp still active; keeping $CONTAINER_NAME running"
    fi

    exit "$original_status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

# ------------------------------------------------------------
# Remove markers left by abnormal previous launcher exits
# ------------------------------------------------------------

exec 7>"$CLEANUP_LOCK"
flock 7

cleanup_stale_markers

flock -u 7
exec 7>&-

# ------------------------------------------------------------
# Start Windows and wait until authentication really works
# ------------------------------------------------------------

echo "Preparing Windows..."

WINAPPS_CREDENTIALS_FILE="$CREDENTIALS_FILE" \
    "$START_SCRIPT"

# ------------------------------------------------------------
# Register this managed RemoteApp session
# ------------------------------------------------------------

printf '%s\n' "$$" > "$SESSION_MARKER"
chmod 600 "$SESSION_MARKER"

echo
echo "Launching RemoteApp:"
echo "  $APP_PATH"
echo

# ------------------------------------------------------------
# Launch FreeRDP.
#
# IMPORTANT:
# Do NOT use "exec" here.
#
# The shell must remain alive so the EXIT trap can remove this
# session marker and decide whether Windows should be stopped.
#
# Password is supplied through /args-from:stdin rather than
# appearing in xfreerdp's process argument list.
# ------------------------------------------------------------

RDP_APP_SPEC="/app:program:${APP_PATH}"

if [[ -n "$APP_CMD" ]]; then
    RDP_APP_SPEC+=",cmd:${APP_CMD}"
fi

set +e

printf '%s\n' \
    "/v:${RDP_HOST}:${RDP_PORT}" \
    "/u:${RDP_USER}" \
    "/p:${RDP_PASS}" \
    "$RDP_APP_SPEC" \
    "/cert:ignore" \
    "/log-level:WARN" \
    "+clipboard" \
    "+auto-reconnect" |
    "$FREERDP_BIN" /args-from:stdin

RDP_STATUS="${PIPESTATUS[1]}"

set -e

# ------------------------------------------------------------
# Normalize expected user-initiated RemoteApp termination.
#
# FreeRDP may return:
#   0  = success
#   11 = disconnect initiated by user
#   12 = logoff by user (ERRINFO_LOGOFF_BY_USER / 0x0000000C)
#
# Closing the final RemoteApp can legitimately produce 11 or 12.
# These are not application-launch failures.
# ------------------------------------------------------------

case "$RDP_STATUS" in
    0)
        NORMALIZED_STATUS=0
        echo
        echo "RemoteApp connection ended normally."
        ;;

    11)
        NORMALIZED_STATUS=0
        echo
        echo "RemoteApp disconnected by user."
        ;;

    12)
        NORMALIZED_STATUS=0
        echo
        echo "RemoteApp session logged off normally."
        ;;

    *)
        NORMALIZED_STATUS="$RDP_STATUS"
        echo
        echo "RemoteApp connection failed/ended with FreeRDP exit code: $RDP_STATUS"
        ;;
esac

exit "$NORMALIZED_STATUS"
