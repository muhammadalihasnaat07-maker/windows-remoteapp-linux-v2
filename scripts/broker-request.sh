#!/usr/bin/env bash
set -Eeuo pipefail

if (( $# != 1 )); then
    echo "Usage: $(basename "$0") <windows-application-path>" >&2
    exit 2
fi

APP_PATH="$1"

if [[ -z "$APP_PATH" ]]; then
    echo "ERROR: Windows application path cannot be empty." >&2
    exit 2
fi

REQUEST_DIR="${WINAPPS_BROKER_REQUEST_DIR:-$HOME/WinApps/shared/broker/requests}"

umask 077
mkdir -p "$REQUEST_DIR"

REQUEST_ID="$(date +%s%N)-$$-$RANDOM"
TEMP_FILE="$REQUEST_DIR/.${REQUEST_ID}.tmp"
REQUEST_FILE="$REQUEST_DIR/${REQUEST_ID}.request"

cleanup() {
    rm -f "$TEMP_FILE"
}

trap cleanup EXIT

printf '%s' "$APP_PATH" > "$TEMP_FILE"
chmod 600 "$TEMP_FILE"

mv "$TEMP_FILE" "$REQUEST_FILE"

trap - EXIT

printf 'Broker request queued: %s\n' "$(basename "$REQUEST_FILE")"
