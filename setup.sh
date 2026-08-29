#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WINAPPS_DIR="${WINAPPS_DIR:-$HOME/WinApps}"
WINAPPS_CONFIG_DIR="${WINAPPS_CONFIG_DIR:-$HOME/.config/winapps}"

ENV_FILE="$WINAPPS_DIR/.env"
CREDENTIALS_FILE="$WINAPPS_CONFIG_DIR/credentials"

usage() {
    cat <<USAGE
Usage:
  ./setup.sh configure
  ./setup.sh install-windows [--dry-run]
  ./setup.sh finalize

Commands:
  configure
      Create the WinApps configuration, credentials and OEM files.

  install-windows
      Pull the Dockur Windows image and start Windows installation.

  install-windows --dry-run
      Validate everything and show what would happen without changing Docker.

  finalize
      Detect installed Windows applications and create Linux shortcuts.
      Run this after Windows installation is complete and desired apps
      such as Microsoft Office have been installed.

Optional environment overrides:
  WINAPPS_DIR=/path/to/WinApps
  WINAPPS_CONFIG_DIR=/path/to/config
USAGE
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

validate_required_files() {
    local required=(
        "$REPO_DIR/compose.yml"
        "$REPO_DIR/config/winapps.env.example"
        "$REPO_DIR/oem/install.bat"
        "$REPO_DIR/oem/configure-winapps.ps1"
        "$REPO_DIR/oem/RDPApps.reg"
    )

    local file

    for file in "${required[@]}"; do
        [[ -f "$file" ]] || die "Required repository file missing: $file"
    done
}

prompt_default() {
    local prompt="$1"
    local default="$2"
    local value=""

    read -r -p "$prompt [$default]: " value

    if [[ -z "$value" ]]; then
        value="$default"
    fi

    printf '%s' "$value"
}

configure() {
    validate_required_files

    echo '============================================================'
    echo ' Windows RemoteApp Linux v2 - Configuration'
    echo '============================================================'
    echo
    echo "WinApps directory:"
    echo "  $WINAPPS_DIR"
    echo
    echo "Credentials directory:"
    echo "  $WINAPPS_CONFIG_DIR"
    echo

    if [[ -e "$WINAPPS_DIR" ]]; then
        die "$WINAPPS_DIR already exists. Refusing to overwrite it."
    fi

    if [[ -e "$CREDENTIALS_FILE" ]]; then
        die "$CREDENTIALS_FILE already exists. Refusing to overwrite it."
    fi

    WINDOWS_VERSION="$(
        prompt_default "Windows version (10 or 11)" "10"
    )"

    case "$WINDOWS_VERSION" in
        10|11)
            ;;
        *)
            die "Windows version must be 10 or 11."
            ;;
    esac

    WINDOWS_RAM="$(
        prompt_default "Windows RAM" "6G"
    )"

    [[ "$WINDOWS_RAM" =~ ^[1-9][0-9]*[Gg]$ ]] ||
        die "RAM must look like 4G, 6G, 8G, etc."

    WINDOWS_RAM="${WINDOWS_RAM^^}"
    RAM_NUMBER="${WINDOWS_RAM%G}"

    (( RAM_NUMBER >= 4 )) ||
        die "Windows RAM must be at least 4G."

    WINDOWS_CPUS="$(
        prompt_default "Windows CPU cores" "4"
    )"

    [[ "$WINDOWS_CPUS" =~ ^[1-9][0-9]*$ ]] ||
        die "CPU cores must be a positive integer."

    (( WINDOWS_CPUS >= 2 )) ||
        die "Windows must be allocated at least 2 CPU cores."

    WINDOWS_DISK="$(
        prompt_default "Windows disk size" "40G"
    )"

    [[ "$WINDOWS_DISK" =~ ^[0-9]+[Gg]$ ]] ||
        die "Disk size must look like 40G, 64G, etc."

    WINDOWS_DISK="${WINDOWS_DISK^^}"
    DISK_NUMBER="${WINDOWS_DISK%G}"

    (( DISK_NUMBER >= 40 )) ||
        die "Windows disk must be at least 40G."

    WINDOWS_USERNAME="$(
        prompt_default "Windows username" "WinApps"
    )"

    [[ "$WINDOWS_USERNAME" =~ ^[A-Za-z0-9._-]{1,20}$ ]] ||
        die "Username must be 1-20 characters using letters, numbers, dot, underscore or hyphen."

    echo
    echo "Choose the Windows password."
    echo "Requirements:"
    echo "  - at least 4 characters"
    echo "  - must not contain a single quote (')"
    echo

    while true; do
        read -r -s -p "Windows password: " WINDOWS_PASSWORD
        echo

        if (( ${#WINDOWS_PASSWORD} < 4 )); then
            echo "Password must contain at least 4 characters."
            continue
        fi

        if [[ "$WINDOWS_PASSWORD" == *"'"* ]]; then
            echo "Single quotes are not supported in the password."
            continue
        fi

        read -r -s -p "Confirm password: " WINDOWS_PASSWORD_CONFIRM
        echo

        if [[ "$WINDOWS_PASSWORD" != "$WINDOWS_PASSWORD_CONFIRM" ]]; then
            echo "Passwords do not match."
            continue
        fi

        break
    done

    echo
    echo '---------------- Configuration summary ----------------'
    echo "Windows version : $WINDOWS_VERSION"
    echo "RAM             : $WINDOWS_RAM"
    echo "CPU cores       : $WINDOWS_CPUS"
    echo "Disk            : $WINDOWS_DISK"
    echo "Username        : $WINDOWS_USERNAME"
    echo "Password        : [hidden]"
    echo "WinApps path    : $WINAPPS_DIR"
    echo

    read -r -p "Create this configuration? [y/N]: " CONFIRM

    case "$CONFIRM" in
        y|Y|yes|YES)
            ;;
        *)
            echo "Configuration cancelled."
            exit 0
            ;;
    esac

    echo
    echo 'Creating directories...'

    mkdir -p \
        "$WINAPPS_DIR/oem" \
        "$WINAPPS_DIR/shared" \
        "$WINAPPS_CONFIG_DIR"

    chmod 700 "$WINAPPS_DIR"
    chmod 700 "$WINAPPS_DIR/shared"
    chmod 700 "$WINAPPS_CONFIG_DIR"

    echo 'Installing Compose configuration...'

    install -m 644 \
        "$REPO_DIR/compose.yml" \
        "$WINAPPS_DIR/compose.yml"

    echo 'Installing OEM provisioning files...'

    install -m 644 \
        "$REPO_DIR/oem/install.bat" \
        "$WINAPPS_DIR/oem/install.bat"

    install -m 644 \
        "$REPO_DIR/oem/configure-winapps.ps1" \
        "$WINAPPS_DIR/oem/configure-winapps.ps1"

    install -m 644 \
        "$REPO_DIR/oem/RDPApps.reg" \
        "$WINAPPS_DIR/oem/RDPApps.reg"

    echo 'Creating .env...'

    cat > "$ENV_FILE" <<ENV
WINAPPS_IMAGE=ghcr.io/dockur/windows:latest

WINDOWS_VERSION=$WINDOWS_VERSION
WINDOWS_RAM=$WINDOWS_RAM
WINDOWS_CPUS=$WINDOWS_CPUS
WINDOWS_DISK=$WINDOWS_DISK

WINDOWS_USERNAME=$WINDOWS_USERNAME
WINDOWS_PASSWORD='$WINDOWS_PASSWORD'

WINAPPS_SHARED_DIR='$WINAPPS_DIR/shared'
ENV

    chmod 600 "$ENV_FILE"

    echo 'Creating FreeRDP credentials file...'

    cat > "$CREDENTIALS_FILE" <<CREDS
RDP_USER='$WINDOWS_USERNAME'
RDP_PASS='$WINDOWS_PASSWORD'
CREDS

    chmod 600 "$CREDENTIALS_FILE"

    echo
    echo 'Validating generated Compose configuration...'

    if docker compose \
        --env-file "$ENV_FILE" \
        -f "$WINAPPS_DIR/compose.yml" \
        config --quiet
    then
        echo "Compose validation: OK"
    else
        echo "Compose validation: FAILED"

        echo "Removing incomplete generated configuration..."

        rm -rf "$WINAPPS_DIR"
        rm -f "$CREDENTIALS_FILE"

        exit 1
    fi

    echo
    echo '============================================================'
    echo ' Configuration completed successfully.'
    echo '============================================================'
    echo
    echo "Created:"
    echo "  $WINAPPS_DIR/compose.yml"
    echo "  $WINAPPS_DIR/.env"
    echo "  $WINAPPS_DIR/oem/"
    echo "  $WINAPPS_DIR/shared/"
    echo "  $CREDENTIALS_FILE"
}


install_windows() {
    local mode="${1:-}"
    local dry_run=0

    case "$mode" in
        "")
            ;;
        --dry-run)
            dry_run=1
            ;;
        *)
            die "Usage: ./setup.sh install-windows [--dry-run]"
            ;;
    esac

    echo '============================================================'
    echo ' Windows RemoteApp Linux v2 - Windows Installation'
    echo '============================================================'
    echo

    # --------------------------------------------------------
    # Required generated configuration
    # --------------------------------------------------------

    [[ -d "$WINAPPS_DIR" ]] ||
        die "WinApps directory not found: $WINAPPS_DIR"

    [[ -f "$WINAPPS_DIR/compose.yml" ]] ||
        die "Missing: $WINAPPS_DIR/compose.yml"

    [[ -f "$ENV_FILE" ]] ||
        die "Missing: $ENV_FILE"

    [[ -f "$CREDENTIALS_FILE" ]] ||
        die "Missing: $CREDENTIALS_FILE"

    for file in \
        "$WINAPPS_DIR/oem/install.bat" \
        "$WINAPPS_DIR/oem/configure-winapps.ps1" \
        "$WINAPPS_DIR/oem/RDPApps.reg"
    do
        [[ -f "$file" ]] ||
            die "Missing OEM file: $file"
    done

    echo "Configuration files: OK"

    # --------------------------------------------------------
    # Permission checks
    # --------------------------------------------------------

    ENV_MODE="$(stat -c '%a' "$ENV_FILE")"
    CREDS_MODE="$(stat -c '%a' "$CREDENTIALS_FILE")"

    [[ "$ENV_MODE" == "600" ]] ||
        die "$ENV_FILE must have permissions 600 (currently $ENV_MODE)"

    [[ "$CREDS_MODE" == "600" ]] ||
        die "$CREDENTIALS_FILE must have permissions 600 (currently $CREDS_MODE)"

    echo "Credential permissions: OK"

    # --------------------------------------------------------
    # Placeholder/credential checks
    # --------------------------------------------------------

    if grep -q 'ChangeThisPassword' "$ENV_FILE"; then
        die "Default Windows password is still present in $ENV_FILE"
    fi

    if grep -q 'ChangeThisPassword' "$CREDENTIALS_FILE"; then
        die "Default RDP password is still present in $CREDENTIALS_FILE"
    fi

    echo "Credential placeholders: NONE"

    # --------------------------------------------------------
    # Host requirements needed specifically to boot Dockur
    # --------------------------------------------------------

    command -v docker >/dev/null 2>&1 ||
        die "Docker is not installed."

    docker info >/dev/null 2>&1 ||
        die "Docker daemon is unavailable or current user lacks access."

    docker compose version >/dev/null 2>&1 ||
        die "Docker Compose v2 is unavailable."

    [[ -r /dev/kvm && -w /dev/kvm ]] ||
        die "/dev/kvm is missing or inaccessible."

    [[ -r /dev/net/tun && -w /dev/net/tun ]] ||
        die "/dev/net/tun is missing or inaccessible."

    echo "Docker/KVM/TUN: OK"

    # --------------------------------------------------------
    # Compose validation
    # --------------------------------------------------------

    if docker compose \
        --env-file "$ENV_FILE" \
        -f "$WINAPPS_DIR/compose.yml" \
        config --quiet
    then
        echo "Compose validation: OK"
    else
        die "Generated Compose configuration is invalid."
    fi

    # --------------------------------------------------------
    # Display non-secret configuration
    # --------------------------------------------------------

    echo
    echo '---------------- VM configuration ----------------'

    grep -E \
        '^(WINAPPS_IMAGE|WINDOWS_VERSION|WINDOWS_RAM|WINDOWS_CPUS|WINDOWS_DISK|WINDOWS_USERNAME|WINAPPS_SHARED_DIR)=' \
        "$ENV_FILE"

    echo

    # --------------------------------------------------------
    # Dry-run path
    # --------------------------------------------------------

    if (( dry_run == 1 )); then
        echo '---------------- DRY RUN ----------------'
        echo
        echo "No Docker image will be pulled."
        echo "No container will be created or started."
        echo "No volume will be created."
        echo
        echo "Real installation would execute:"
        echo
        printf '  cd %q\n' "$WINAPPS_DIR"
        printf '  docker compose --env-file %q -f %q pull\n' \
            "$ENV_FILE" \
            "$WINAPPS_DIR/compose.yml"
        printf '  docker compose --env-file %q -f %q up -d\n' \
            "$ENV_FILE" \
            "$WINAPPS_DIR/compose.yml"
        echo

        if docker inspect WinApps >/dev/null 2>&1; then
            echo "NOTE: An existing WinApps container is currently present."
            echo "A real fresh-install run would refuse to overwrite it."
        else
            echo "Existing WinApps container: NONE"
        fi

        echo
        echo "Dry-run validation completed successfully."
        return 0
    fi

    # --------------------------------------------------------
    # Fresh-install safety
    # --------------------------------------------------------

    if docker inspect WinApps >/dev/null 2>&1; then
        die "A container named WinApps already exists. Refusing to overwrite an existing Windows installation."
    fi

    if docker volume inspect winapps_data >/dev/null 2>&1; then
        die "Docker volume winapps_data already exists. Refusing to overwrite possible Windows data."
    fi

    # --------------------------------------------------------
    # Pull and start
    # --------------------------------------------------------

    echo 'Pulling Windows container image...'

    (
        cd "$WINAPPS_DIR"

        docker compose \
            --env-file "$ENV_FILE" \
            -f "$WINAPPS_DIR/compose.yml" \
            pull
    )

    echo
    echo 'Starting Windows installation...'

    (
        cd "$WINAPPS_DIR"

        docker compose \
            --env-file "$ENV_FILE" \
            -f "$WINAPPS_DIR/compose.yml" \
            up -d
    )

    echo
    echo '============================================================'
    echo ' Windows installation started.'
    echo '============================================================'
    echo
    echo 'Web console:'
    echo '  http://127.0.0.1:8006'
    echo
    echo 'Container status:'
    echo '  docker ps --filter name=WinApps'
    echo
    echo 'Installation logs:'
    echo '  docker logs -f WinApps'
    echo
    echo 'Do not manually sign into the Windows console.'
    echo 'AUTOLOGIN is disabled so RemoteApp can own the interactive session.'
}

finalize() {
    echo '============================================================'
    echo ' Windows RemoteApp Linux v2 - Finalize Installation'
    echo '============================================================'
    echo

    [[ -x "$REPO_DIR/scripts/detect-apps.sh" ]] ||
        die "Application detector missing or not executable: $REPO_DIR/scripts/detect-apps.sh"

    [[ -x "$REPO_DIR/scripts/create-shortcuts.sh" ]] ||
        die "Shortcut generator missing or not executable: $REPO_DIR/scripts/create-shortcuts.sh"

    [[ -f "$CREDENTIALS_FILE" ]] ||
        die "Credentials file not found: $CREDENTIALS_FILE. Run ./setup.sh configure first."

    echo 'Step 1/2: Detecting installed Windows applications...'
    echo

    "$REPO_DIR/scripts/detect-apps.sh"

    echo
    echo 'Step 2/2: Creating Linux application shortcuts...'
    echo

    "$REPO_DIR/scripts/create-shortcuts.sh"

    echo
    echo '============================================================'
    echo ' Finalization completed successfully.'
    echo '============================================================'
    echo
    echo "Application manifest:"
    echo "  $WINAPPS_CONFIG_DIR/apps.tsv"
    echo
    echo "Linux application shortcuts are now installed."
}


case "${1:-}" in
    configure)
        configure
        ;;

    install-windows)
        install_windows "${2:-}"
        ;;

    finalize)
        finalize
        ;;

    -h|--help|"")
        usage
        ;;

    *)
        usage
        exit 2
        ;;
esac
