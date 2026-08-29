#!/usr/bin/env bash
set -Eeuo pipefail

WINAPPS_DIR="${WINAPPS_DIR:-$HOME/WinApps}"
WINAPPS_CONFIG_DIR="${WINAPPS_CONFIG_DIR:-$HOME/.config/winapps}"

CONTAINER_NAME="${WINAPPS_CONTAINER_NAME:-WinApps}"
VOLUME_NAME="${WINAPPS_VOLUME_NAME:-winapps_data}"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
APP_DIR="$DATA_HOME/applications"
WRAPPER_DIR="$DATA_HOME/winapps/launchers"

PURGE_DATA=0
ASSUME_YES=0

usage() {
    cat <<USAGE
Usage:
  ./uninstall.sh
  ./uninstall.sh --purge-data
  ./uninstall.sh --purge-data --yes

Default behavior:
  - Remove the disposable WinApps Docker container.
  - Remove generated Linux application shortcuts.
  - Remove generated RemoteApp launcher wrappers.
  - Remove ~/.config/winapps credentials and application manifest.
  - Preserve the persistent Windows disk: $VOLUME_NAME
  - Preserve the host WinApps directory: $WINAPPS_DIR

Options:
  --purge-data
      Also permanently delete the Docker volume $VOLUME_NAME.
      This destroys the Windows installation stored in that volume.

  --yes
      Confirm --purge-data non-interactively.

  -h, --help
      Show this help.

The host directory $WINAPPS_DIR is never deleted automatically.
USAGE
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

while (( $# > 0 )); do
    case "$1" in
        --purge-data)
            PURGE_DATA=1
            ;;

        --yes)
            ASSUME_YES=1
            ;;

        -h|--help)
            usage
            exit 0
            ;;

        *)
            usage >&2
            die "Unknown option: $1"
            ;;
    esac

    shift
done

if (( ASSUME_YES == 1 && PURGE_DATA == 0 )); then
    die "--yes is only valid together with --purge-data."
fi

echo '============================================================'
echo ' Windows RemoteApp Linux v2 - Uninstall'
echo '============================================================'
echo

if (( PURGE_DATA == 1 && ASSUME_YES == 0 )); then
    echo "WARNING:"
    echo "  --purge-data will permanently delete Docker volume:"
    echo "  $VOLUME_NAME"
    echo
    echo "This destroys the Windows installation stored in that volume."
    echo

    if [[ ! -t 0 ]]; then
        die "Interactive confirmation unavailable. Re-run with --purge-data --yes if destruction is intentional."
    fi

    read -r -p "Type DELETE to permanently remove Windows data: " CONFIRM

    [[ "$CONFIRM" == "DELETE" ]] ||
        die "Data purge cancelled."
fi

# ------------------------------------------------------------
# Docker cleanup
#
# The container is disposable. The persistent Windows volume
# is deliberately preserved unless --purge-data was requested.
# ------------------------------------------------------------

if command -v docker >/dev/null 2>&1; then
    if docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
        echo "Removing Docker container:"
        echo "  $CONTAINER_NAME"

        docker rm -f "$CONTAINER_NAME"
    else
        echo "Docker container not present:"
        echo "  $CONTAINER_NAME"
    fi

    if (( PURGE_DATA == 1 )); then
        if docker volume inspect "$VOLUME_NAME" >/dev/null 2>&1; then
            echo
            echo "Permanently removing Windows data volume:"
            echo "  $VOLUME_NAME"

            docker volume rm "$VOLUME_NAME"
        else
            echo
            echo "Docker volume not present:"
            echo "  $VOLUME_NAME"
        fi
    else
        echo
        echo "Preserving Windows data volume:"
        echo "  $VOLUME_NAME"
    fi
else
    echo "Docker command unavailable."
    echo "Skipping Docker container/volume cleanup."

    if (( PURGE_DATA == 1 )); then
        die "Cannot purge $VOLUME_NAME because Docker is unavailable."
    fi
fi

# ------------------------------------------------------------
# Remove current v2 desktop shortcuts.
# ------------------------------------------------------------

echo
echo "Removing WinApps application shortcuts..."

for file in \
    winapps-word.desktop \
    winapps-excel.desktop \
    winapps-powerpoint.desktop \
    winapps-powershell.desktop \
    winapps-start-windows.desktop \
    winapps-windows-desktop.desktop
do
    rm -f "$APP_DIR/$file"
done

# Remove old v1 shortcut names as migration cleanup.
for file in \
    ms-word.desktop \
    ms-excel.desktop \
    ms-powerpoint.desktop \
    windows-notepad.desktop
do
    rm -f "$APP_DIR/$file"
done

# ------------------------------------------------------------
# Remove generated v2 launcher wrappers.
# ------------------------------------------------------------

echo "Removing generated launcher wrappers..."

rm -rf "$WRAPPER_DIR"

# Remove now-empty parent directory when possible.
rmdir "$DATA_HOME/winapps" 2>/dev/null || true

# ------------------------------------------------------------
# Remove local generated configuration.
#
# Do not recursively delete arbitrary user files that might have
# been placed in the config directory. Remove only files owned by
# this project, then remove the directory only if it is empty.
# ------------------------------------------------------------

echo "Removing local WinApps configuration..."

rm -f \
    "$WINAPPS_CONFIG_DIR/credentials" \
    "$WINAPPS_CONFIG_DIR/apps.tsv"

rmdir "$WINAPPS_CONFIG_DIR" 2>/dev/null || true

# Remove the old v1 installed launcher if upgrading from v1.
rm -f "$HOME/.local/bin/winapp-launcher"

echo
echo "Preserving host WinApps directory:"
echo "  $WINAPPS_DIR"

echo
echo '============================================================'
echo ' Uninstall completed.'
echo '============================================================'

if (( PURGE_DATA == 0 )); then
    echo
    echo "Windows data was preserved in Docker volume:"
    echo "  $VOLUME_NAME"
    echo
    echo "To permanently delete it later:"
    echo "  ./uninstall.sh --purge-data"
fi
