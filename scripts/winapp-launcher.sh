#!/usr/bin/env bash
set -Eeuo pipefail

APP="${1:-}"

COMPOSE_DIR="${WINAPPS_COMPOSE_DIR:-$HOME/WinApps}"
SHARE_DIR="${WINAPPS_SHARE_DIR:-$HOME}"
CREDENTIALS_FILE="${WINAPPS_CREDENTIALS_FILE:-$HOME/.config/winapps/credentials}"
CONTAINER_NAME="${WINAPPS_CONTAINER_NAME:-WinApps}"
RDP_HOST="${WINAPPS_RDP_HOST:-127.0.0.1}"
RDP_PORT="${WINAPPS_RDP_PORT:-3389}"
DOCKER_BIN="${DOCKER_BIN:-/usr/bin/docker}"
COLD_BOOT_DELAY="${WINAPPS_COLD_BOOT_DELAY:-45}"
STOP_GRACE_SECONDS="${WINAPPS_STOP_GRACE_SECONDS:-5}"

if [[ -z "$APP" ]]; then
  echo "Usage: $0 '<Windows executable or full Windows path>'" >&2
  exit 2
fi

if [[ "${XDG_SESSION_TYPE:-}" != "x11" ]]; then
  echo "Warning: RemoteApp input may not work correctly outside an X11/Xorg session." >&2
fi

[[ -d "$COMPOSE_DIR" ]] || { echo "Compose directory not found: $COMPOSE_DIR" >&2; exit 1; }
[[ -d "$SHARE_DIR" ]] || { echo "Share directory not found: $SHARE_DIR" >&2; exit 1; }
[[ -f "$CREDENTIALS_FILE" ]] || { echo "Credentials file not found: $CREDENTIALS_FILE" >&2; exit 1; }

# shellcheck source=/dev/null
source "$CREDENTIALS_FILE"
: "${RDP_USER:?RDP_USER is missing}"
: "${RDP_PASS:?RDP_PASS is missing}"

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}/winapps-container-manager"
LOCK_FILE="$RUNTIME_DIR/container.lock"
SESSION_FILE="$RUNTIME_DIR/session-$$"
mkdir -p "$RUNTIME_DIR"
chmod 700 "$RUNTIME_DIR"
touch "$SESSION_FILE"

compose() {
  (
    cd "$COMPOSE_DIR"
    sudo -n "$DOCKER_BIN" compose "$@"
  )
}

remove_stale_sessions() {
  local file pid
  shopt -s nullglob
  for file in "$RUNTIME_DIR"/session-*; do
    pid="${file##*-}"
    kill -0 "$pid" 2>/dev/null || rm -f "$file"
  done
}

cleanup() {
  local status=$?
  trap - EXIT INT TERM HUP
  rm -f "$SESSION_FILE"

  (
    flock -x 9
    remove_stale_sessions
    shopt -s nullglob
    local sessions=("$RUNTIME_DIR"/session-*)

    if (( ${#sessions[@]} == 0 )); then
      sleep "$STOP_GRACE_SECONDS"
      remove_stale_sessions
      sessions=("$RUNTIME_DIR"/session-*)

      if (( ${#sessions[@]} == 0 )); then
        sudo -n "$DOCKER_BIN" stop "$CONTAINER_NAME" \
          >>"$HOME/.winapps-cleanup.log" 2>&1 || true
      fi
    fi
  ) 9>"$LOCK_FILE"

  exit "$status"
}

trap cleanup EXIT INT TERM HUP

RDP_WAS_READY=false
if timeout 1 bash -c "</dev/tcp/$RDP_HOST/$RDP_PORT" 2>/dev/null; then
  RDP_WAS_READY=true
fi

compose up -d

if [[ "$RDP_WAS_READY" == false ]]; then
  echo "Waiting for Windows RDP port..."
  RDP_PORT_OPEN=false

  for ((attempt = 1; attempt <= 90; attempt++)); do
    if timeout 1 bash -c "</dev/tcp/$RDP_HOST/$RDP_PORT" 2>/dev/null; then
      RDP_PORT_OPEN=true
      break
    fi
    sleep 2
  done

  if [[ "$RDP_PORT_OPEN" != true ]]; then
    echo "Windows RDP port did not become available." >&2
    exit 1
  fi

  echo "RDP port is open. Waiting ${COLD_BOOT_DELAY}s for Windows login services..."
  sleep "$COLD_BOOT_DELAY"
fi

xfreerdp3 \
  "/v:${RDP_HOST}:${RDP_PORT}" \
  "/u:${RDP_USER}" \
  "/p:${RDP_PASS}" \
  "/app:program:${APP}" \
  "/drive:LinuxShared,${SHARE_DIR}" \
  +clipboard \
  /cert:ignore \
  -gfx
