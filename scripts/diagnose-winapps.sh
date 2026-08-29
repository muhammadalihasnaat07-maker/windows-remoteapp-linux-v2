#!/usr/bin/env bash
set -u

CONTAINER="${WINAPPS_CONTAINER_NAME:-WinApps}"
RUNTIME_ROOT="${XDG_RUNTIME_DIR:-/tmp}"
BROKER_DIR="$RUNTIME_ROOT/winapps-$UID/broker"

echo '============================================================'
echo ' Windows RemoteApp Linux v2 - Diagnostics'
echo '============================================================'

echo
echo '========== SESSION =========='
echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-unknown}"
echo "DISPLAY=${DISPLAY:-unset}"

echo
echo '========== FREERDP =========='

if command -v xfreerdp3 >/dev/null 2>&1; then
    echo "Binary: $(command -v xfreerdp3)"
    xfreerdp3 /version 2>/dev/null || true
elif command -v xfreerdp >/dev/null 2>&1; then
    echo "Binary: $(command -v xfreerdp)"
    xfreerdp /version 2>/dev/null || true
else
    echo 'FreeRDP: NOT FOUND'
fi

echo
echo '========== DOCKER =========='

docker --version 2>/dev/null || echo 'Docker: NOT AVAILABLE'

echo
echo "Container: $CONTAINER"

docker ps -a \
    --filter "name=^/${CONTAINER}$" \
    --format 'Name={{.Names}} Status={{.Status}}' \
    2>/dev/null || echo 'Unable to query Docker as current user.'

echo
echo '========== BROKER PROCESSES =========='

pgrep -af \
    'broker-launcher|winapps-broker|xfreerdp3|xfreerdp' \
    2>/dev/null || echo 'None'

echo
echo '========== BROKER RUNTIME STATE =========='
echo "Runtime directory:"
echo "  $BROKER_DIR"

if [[ -d "$BROKER_DIR" ]]; then
    find "$BROKER_DIR" \
        -maxdepth 2 \
        -type f \
        -printf '%P\n' \
        2>/dev/null |
        sort
else
    echo 'Runtime directory does not currently exist.'
fi

echo
echo '========== BROKER PID STATE =========='

for pid_file in \
    supervisor.pid \
    freerdp.pid
do
    path="$BROKER_DIR/$pid_file"

    if [[ -f "$path" ]]; then
        pid="$(cat "$path" 2>/dev/null || true)"

        if [[ "$pid" =~ ^[0-9]+$ ]] &&
           kill -0 "$pid" 2>/dev/null
        then
            echo "$pid_file: $pid (running)"
        else
            echo "$pid_file: ${pid:-invalid} (stale/not running)"
        fi
    else
        echo "$pid_file: not present"
    fi
done

echo
echo '========== CONFIGURATION =========='

CONFIG_DIR="${WINAPPS_CONFIG_DIR:-$HOME/.config/winapps}"

for file in \
    credentials \
    apps.tsv
do
    path="$CONFIG_DIR/$file"

    if [[ -f "$path" ]]; then
        printf '%s: present (mode ' "$file"
        stat -c '%a)' "$path" 2>/dev/null || echo 'unknown)'
    else
        echo "$file: missing"
    fi
done

echo
echo '========== SHORTCUTS =========='

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
APPLICATION_DIR="$DATA_HOME/applications"

if [[ -d "$APPLICATION_DIR" ]]; then
    grep -RH \
        '^Exec=' \
        "$APPLICATION_DIR"/winapps-*.desktop \
        2>/dev/null || echo 'No WinApps desktop entries found.'
else
    echo 'Application directory not found.'
fi
