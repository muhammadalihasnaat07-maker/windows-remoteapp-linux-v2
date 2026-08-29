#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WINAPPS_DIR="${WINAPPS_DIR:-$HOME/WinApps}"
WINAPPS_CONFIG_DIR="${WINAPPS_CONFIG_DIR:-$HOME/.config/winapps}"

ENV_FILE="${WINAPPS_ENV_FILE:-$WINAPPS_DIR/.env}"
COMPOSE_FILE="${WINAPPS_COMPOSE_FILE:-$WINAPPS_DIR/compose.yml}"
CREDENTIALS_FILE="${WINAPPS_CREDENTIALS_FILE:-$WINAPPS_CONFIG_DIR/credentials}"

CONTAINER_NAME="${WINAPPS_CONTAINER_NAME:-WinApps}"
VOLUME_NAME="${WINAPPS_VOLUME_NAME:-winapps_data}"

WAIT_SCRIPT="$SCRIPT_DIR/wait-for-rdp.sh"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

command -v docker >/dev/null 2>&1 ||
    die "Docker is not installed."

docker info >/dev/null 2>&1 ||
    die "Docker daemon is unavailable or current user lacks access."

command -v flock >/dev/null 2>&1 ||
    die "flock is unavailable."

[[ -x "$WAIT_SCRIPT" ]] ||
    die "RDP readiness script is missing or not executable: $WAIT_SCRIPT"

[[ -f "$CREDENTIALS_FILE" ]] ||
    die "Credentials file not found: $CREDENTIALS_FILE"

# ------------------------------------------------------------
# Serialize simultaneous app launches.
#
# If Word, Excel, etc. are clicked at nearly the same time,
# only one launcher performs the Windows startup sequence.
# ------------------------------------------------------------

LOCK_ROOT="${XDG_RUNTIME_DIR:-/tmp}"
LOCK_DIR="$LOCK_ROOT/winapps-$UID"
LOCK_FILE="$LOCK_DIR/start.lock"

mkdir -p "$LOCK_DIR"
chmod 700 "$LOCK_DIR"

exec 9>"$LOCK_FILE"

echo "Waiting for Windows startup lock..."
flock 9

echo "Startup lock acquired."

# ------------------------------------------------------------
# Start or recover the container
# ------------------------------------------------------------

if docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then

    RUNNING="$(
        docker inspect \
            --format '{{.State.Running}}' \
            "$CONTAINER_NAME"
    )"

    if [[ "$RUNNING" == "true" ]]; then
        echo "Windows container is already running."
    else
        echo "Starting existing Windows container..."

        docker start "$CONTAINER_NAME" >/dev/null

        echo "Windows container started."
    fi

else
    echo "Windows container does not currently exist."

    # The Windows disk must already exist before we permit
    # automatic container reconstruction.
    if ! docker volume inspect "$VOLUME_NAME" >/dev/null 2>&1; then
        die "Windows installation volume $VOLUME_NAME does not exist. Run ./setup.sh install-windows first."
    fi

    [[ -f "$COMPOSE_FILE" ]] ||
        die "Compose file not found: $COMPOSE_FILE"

    [[ -f "$ENV_FILE" ]] ||
        die "Environment file not found: $ENV_FILE"

    docker compose \
        --env-file "$ENV_FILE" \
        -f "$COMPOSE_FILE" \
        config --quiet ||
        die "WinApps Compose configuration is invalid."

    echo "Existing Windows disk found."
    echo "Recreating disposable WinApps container..."

    (
        cd "$WINAPPS_DIR"

        docker compose \
            --env-file "$ENV_FILE" \
            -f "$COMPOSE_FILE" \
            up -d
    )

    docker inspect "$CONTAINER_NAME" >/dev/null 2>&1 ||
        die "Container reconstruction failed."

    echo "WinApps container recreated."
fi

# ------------------------------------------------------------
# Verify the container is actually running
# ------------------------------------------------------------

RUNNING="$(
    docker inspect \
        --format '{{.State.Running}}' \
        "$CONTAINER_NAME"
)"

[[ "$RUNNING" == "true" ]] ||
    die "Windows container failed to enter the running state."

# ------------------------------------------------------------
# Wait for genuine Windows authentication readiness.
#
# Port 3389 opening alone is NOT sufficient.
# ------------------------------------------------------------

echo
echo "Waiting for Windows RDP authentication readiness..."

WINAPPS_CREDENTIALS_FILE="$CREDENTIALS_FILE" \
    "$WAIT_SCRIPT"

echo
echo "Windows is ready."
