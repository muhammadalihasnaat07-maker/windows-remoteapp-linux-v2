#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

START_WINDOWS="$SCRIPT_DIR/start-windows.sh"
BROKER_REQUEST="$SCRIPT_DIR/broker-request.sh"
BROKER_PS="$SCRIPT_DIR/../oem/winapps-broker.ps1"

CONTAINER="WinApps"

APP_PATH="${1:-}"

if [[ -z "$APP_PATH" ]]; then
    echo "Usage: $(basename "$0") <windows-application-path>" >&2
    exit 2
fi

[[ -x "$START_WINDOWS" ]] || {
    echo "ERROR: Missing start-windows.sh" >&2
    exit 1
}

[[ -x "$BROKER_REQUEST" ]] || {
    echo "ERROR: Missing broker-request.sh" >&2
    exit 1
}

[[ -f "$BROKER_PS" ]] || {
    echo "ERROR: Missing Windows broker script." >&2
    exit 1
}

if [[ "${XDG_SESSION_TYPE:-x11}" != "x11" ]]; then
    echo "ERROR: WinApps RemoteApp currently requires an X11 session." >&2
    exit 1
fi

if command -v xfreerdp3 >/dev/null 2>&1; then
    FREERDP="$(command -v xfreerdp3)"
elif command -v xfreerdp >/dev/null 2>&1; then
    FREERDP="$(command -v xfreerdp)"
else
    echo "ERROR: FreeRDP was not found." >&2
    exit 1
fi

CREDENTIALS="$HOME/.config/winapps/credentials"

[[ -f "$CREDENTIALS" ]] || {
    echo "ERROR: Credentials file not found: $CREDENTIALS" >&2
    exit 1
}

# shellcheck disable=SC1090
source "$CREDENTIALS"

[[ -n "${RDP_USER:-}" && -n "${RDP_PASS:-}" ]] || {
    echo "ERROR: RDP_USER or RDP_PASS is missing." >&2
    exit 1
}

RUNTIME_BASE="${XDG_RUNTIME_DIR:-/tmp}/winapps-$UID/broker"
BROKER_ROOT="$RUNTIME_BASE/drive"
REQUEST_DIR="$BROKER_ROOT/requests"

SUPERVISOR_PID_FILE="$RUNTIME_BASE/supervisor.pid"
FREERDP_PID_FILE="$RUNTIME_BASE/freerdp.pid"

START_LOCK="$RUNTIME_BASE/start.lock"
CLEANUP_LOCK="$RUNTIME_BASE/cleanup.lock"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/winapps"
BROKER_LOG="$STATE_DIR/broker.log"
CLEANUP_LOG="$STATE_DIR/cleanup.log"

mkdir -p \
    "$RUNTIME_BASE" \
    "$REQUEST_DIR" \
    "$STATE_DIR"

chmod 700 "$RUNTIME_BASE" "$BROKER_ROOT" "$REQUEST_DIR" 2>/dev/null || true

broker_is_alive() {
    local supervisor_pid=""
    local freerdp_pid=""

    [[ -f "$SUPERVISOR_PID_FILE" ]] || return 1
    [[ -f "$FREERDP_PID_FILE" ]] || return 1

    supervisor_pid="$(cat "$SUPERVISOR_PID_FILE" 2>/dev/null || true)"
    freerdp_pid="$(cat "$FREERDP_PID_FILE" 2>/dev/null || true)"

    [[ "$supervisor_pid" =~ ^[0-9]+$ ]] || return 1
    [[ "$freerdp_pid" =~ ^[0-9]+$ ]] || return 1

    kill -0 "$supervisor_pid" 2>/dev/null || return 1
    kill -0 "$freerdp_pid" 2>/dev/null || return 1

    return 0
}

queue_request() {
    WINAPPS_BROKER_REQUEST_DIR="$REQUEST_DIR" \
        "$BROKER_REQUEST" "$APP_PATH"
}

cleanup_supervisor() {
    local original_status=$?

    exec 8>"$CLEANUP_LOCK"
    flock 8

    if [[ -f "$SUPERVISOR_PID_FILE" ]] &&
       [[ "$(cat "$SUPERVISOR_PID_FILE" 2>/dev/null || true)" == "$$" ]]
    then
        rm -f \
            "$SUPERVISOR_PID_FILE" \
            "$FREERDP_PID_FILE"

        {
            printf '%s broker session ended; stopping %s\n' \
                "$(date '+%Y-%m-%d %H:%M:%S')" \
                "$CONTAINER"

            docker stop "$CONTAINER" || true
        } >>"$CLEANUP_LOG" 2>&1
    fi

    flock -u 8

    return "$original_status"
}

exec 9>"$START_LOCK"
flock 9

#
# Fast path: a broker session already exists.
# No new FreeRDP connection is created.
#
if broker_is_alive; then
    queue_request

    flock -u 9
    exit 0
fi

#
# Remove stale state from an interrupted broker session.
#
rm -f \
    "$SUPERVISOR_PID_FILE" \
    "$FREERDP_PID_FILE"

find "$REQUEST_DIR" \
    -maxdepth 1 \
    -type f \
    \( -name '*.request' -o -name '.*.tmp' \) \
    -delete 2>/dev/null || true

echo "Preparing Windows..."

"$START_WINDOWS"

#
# Determine the real host directory currently mounted at /shared.
# The existing detector has already established that /shared appears
# inside Windows as Z:\.
#
SHARED_DIR="$(
    docker inspect "$CONTAINER" \
        --format '{{range .Mounts}}{{if eq .Destination "/shared"}}{{.Source}}{{end}}{{end}}'
)"

[[ -n "$SHARED_DIR" ]] || {
    echo "ERROR: Could not determine the host /shared directory." >&2
    flock -u 9
    exit 1
}

[[ -d "$SHARED_DIR" ]] || {
    echo "ERROR: Shared directory does not exist: $SHARED_DIR" >&2
    flock -u 9
    exit 1
}

mkdir -p "$SHARED_DIR/broker"

cp -f \
    "$BROKER_PS" \
    "$SHARED_DIR/broker/winapps-broker.ps1"

POWERSHELL_PATH="$(
    awk -F '\t' \
        '$1 == "PowerShell" {print $2; exit}' \
        "$HOME/.config/winapps/apps.tsv"
)"

[[ -n "$POWERSHELL_PATH" ]] || {
    echo "ERROR: PowerShell was not found in apps.tsv." >&2
    flock -u 9
    exit 1
}

BROKER_COMMAND='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File Z:\broker\winapps-broker.ps1 -RequestDir \\tsclient\winappsbroker\requests -LastAppGraceSeconds 5'

printf '%s\n' "$$" >"$SUPERVISOR_PID_FILE"
chmod 600 "$SUPERVISOR_PID_FILE"

trap cleanup_supervisor EXIT INT TERM

echo "Starting shared RemoteApp broker..."

{
    printf '%s\n' \
        "/v:127.0.0.1:3389" \
        "/u:${RDP_USER}" \
        "/p:${RDP_PASS}" \
        "/cert:ignore" \
        "+clipboard" \
        "/dynamic-resolution" \
        "/drive:winappsbroker,${BROKER_ROOT}" \
        "/app:program:${POWERSHELL_PATH},cmd:${BROKER_COMMAND}"
} |
    "$FREERDP" /args-from:stdin \
        >>"$BROKER_LOG" 2>&1 &

FREERDP_PID=$!

printf '%s\n' "$FREERDP_PID" >"$FREERDP_PID_FILE"
chmod 600 "$FREERDP_PID_FILE"

#
# The request can be queued immediately. It remains in the redirected
# directory until the Windows broker is ready to consume it.
#
queue_request

#
# Allow other application shortcuts to enter the fast path while this
# process remains the long-lived broker supervisor.
#
flock -u 9

set +e
wait "$FREERDP_PID"
FREERDP_STATUS=$?
set -e

case "$FREERDP_STATUS" in
    0|11|12)
        exit 0
        ;;
    *)
        echo "ERROR: FreeRDP broker exited with code $FREERDP_STATUS." >&2
        exit "$FREERDP_STATUS"
        ;;
esac
