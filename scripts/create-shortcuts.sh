#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

WINAPP_LAUNCHER="$SCRIPT_DIR/broker-launcher.sh"
START_WINDOWS="$SCRIPT_DIR/start-windows.sh"
WINDOWS_DESKTOP="$SCRIPT_DIR/windows-desktop.sh"

WINAPPS_CONFIG_DIR="${WINAPPS_CONFIG_DIR:-$HOME/.config/winapps}"
APPS_FILE="${WINAPPS_APPS_FILE:-$WINAPPS_CONFIG_DIR/apps.tsv}"

# Linux application-menu location.
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

# Tiny per-app wrappers keep Windows paths and quoting out of .desktop Exec lines.
WRAPPER_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/winapps/launchers"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

[[ -x "$WINAPP_LAUNCHER" ]] ||
    die "RemoteApp launcher missing: $WINAPP_LAUNCHER"

[[ -x "$START_WINDOWS" ]] ||
    die "Start Windows backend missing: $START_WINDOWS"

[[ -x "$WINDOWS_DESKTOP" ]] ||
    die "Windows Desktop launcher missing: $WINDOWS_DESKTOP"

[[ -f "$APPS_FILE" ]] ||
    die "Application manifest missing: $APPS_FILE. Run ./scripts/detect-apps.sh first."

mkdir -p "$APP_DIR" "$WRAPPER_DIR"

chmod 700 "$WRAPPER_DIR"

desktop_exec_quote() {
    local value="$1"

    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//\`/\\\`}"
    value="${value//\$/\\\$}"

    printf '"%s"' "$value"
}

create_wrapper() {
    local id="$1"
    local windows_path="$2"
    local wrapper="$WRAPPER_DIR/$id"

    {
        echo '#!/usr/bin/env bash'
        echo 'set -Eeuo pipefail'
        printf 'exec %q %q\n' \
            "$WINAPP_LAUNCHER" \
            "$windows_path"
    } > "$wrapper"

    chmod 755 "$wrapper"

    printf '%s' "$wrapper"
}

create_desktop_entry() {
    local id="$1"
    local name="$2"
    local comment="$3"
    local icon="$4"
    local categories="$5"
    local executable="$6"

    local desktop="$APP_DIR/$id.desktop"
    local exec_value

    exec_value="$(desktop_exec_quote "$executable")"

    cat > "$desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Version=1.0
Name=$name
Comment=$comment
Exec=$exec_value
Icon=$icon
Terminal=false
Categories=$categories
StartupNotify=true
DESKTOP

    chmod 644 "$desktop"

    if command -v desktop-file-validate >/dev/null 2>&1; then
        desktop-file-validate "$desktop"
    fi
}

app_metadata() {
    case "$1" in
        Word)
            printf '%s\t%s\t%s\t%s\n' \
                "Microsoft Word" \
                "Launch Microsoft Word through Windows RemoteApp" \
                "x-office-document" \
                "Office;WordProcessor;"
            ;;

        Excel)
            printf '%s\t%s\t%s\t%s\n' \
                "Microsoft Excel" \
                "Launch Microsoft Excel through Windows RemoteApp" \
                "x-office-spreadsheet" \
                "Office;Spreadsheet;"
            ;;

        PowerPoint)
            printf '%s\t%s\t%s\t%s\n' \
                "Microsoft PowerPoint" \
                "Launch Microsoft PowerPoint through Windows RemoteApp" \
                "x-office-presentation" \
                "Office;Presentation;"
            ;;

        PowerShell)
            printf '%s\t%s\t%s\t%s\n' \
                "Windows PowerShell" \
                "Launch Windows PowerShell through RemoteApp" \
                "utilities-terminal" \
                "System;"
            ;;

        *)
            return 1
            ;;
    esac
}

app_id() {
    case "$1" in
        Word)       printf 'winapps-word' ;;
        Excel)      printf 'winapps-excel' ;;
        PowerPoint) printf 'winapps-powerpoint' ;;
        PowerShell) printf 'winapps-powershell' ;;
        *)          return 1 ;;
    esac
}

echo '============================================================'
echo ' Windows RemoteApp Linux v2 - Create Shortcuts'
echo '============================================================'
echo
echo "Application manifest:"
echo "  $APPS_FILE"
echo
echo "Application menu:"
echo "  $APP_DIR"
echo

CREATED=0
SKIPPED=0

while IFS=$'\t' read -r APP_NAME WINDOWS_PATH; do
    [[ -n "$APP_NAME" ]] || continue

    # Ignore applications this v2 shortcut set does not currently expose.
    if ! ID="$(app_id "$APP_NAME")"; then
        continue
    fi

    if [[ -z "$WINDOWS_PATH" ]]; then
        printf 'SKIP     %-12s not installed/detected\n' "$APP_NAME"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    IFS=$'\t' read -r DISPLAY_NAME COMMENT ICON CATEGORIES \
        <<< "$(app_metadata "$APP_NAME")"

    WRAPPER="$(create_wrapper "$ID" "$WINDOWS_PATH")"

    create_desktop_entry \
        "$ID" \
        "$DISPLAY_NAME" \
        "$COMMENT" \
        "$ICON" \
        "$CATEGORIES" \
        "$WRAPPER"

    printf 'CREATED  %-12s %s.desktop\n' "$APP_NAME" "$ID"
    CREATED=$((CREATED + 1))

done < "$APPS_FILE"

# ------------------------------------------------------------
# Windows lifecycle shortcuts
# ------------------------------------------------------------

create_desktop_entry \
    "winapps-start-windows" \
    "Start Windows" \
    "Start the WinApps Windows VM and wait until it is ready" \
    "computer" \
    "System;" \
    "$START_WINDOWS"

echo "CREATED  Start Windows winapps-start-windows.desktop"
CREATED=$((CREATED + 1))


create_desktop_entry \
    "winapps-windows-desktop" \
    "Windows Desktop" \
    "Open the full Windows desktop through FreeRDP" \
    "computer" \
    "System;" \
    "$WINDOWS_DESKTOP"

echo "CREATED  Windows Desktop winapps-windows-desktop.desktop"
CREATED=$((CREATED + 1))


# Remove obsolete desktop entries created by older repository versions.
# The new v2 entries above replace Office launchers with manifest-driven
# shortcuts. Notepad remains available through test-notepad.sh.
rm -f     "$APP_DIR/ms-word.desktop"     "$APP_DIR/ms-excel.desktop"     "$APP_DIR/ms-powerpoint.desktop"     "$APP_DIR/windows-notepad.desktop"


if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$APP_DIR" >/dev/null 2>&1 || true
fi

echo
echo '============================================================'
echo " CREATED: $CREATED"
echo " SKIPPED: $SKIPPED"
echo '============================================================'
echo
echo "Shortcuts are installed in:"
echo "  $APP_DIR"
