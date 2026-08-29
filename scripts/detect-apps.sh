#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

START_SCRIPT="$SCRIPT_DIR/start-windows.sh"
LAUNCHER="$SCRIPT_DIR/winapp-launcher.sh"

WINAPPS_CONFIG_DIR="${WINAPPS_CONFIG_DIR:-$HOME/.config/winapps}"
APPS_FILE="${WINAPPS_APPS_FILE:-$WINAPPS_CONFIG_DIR/apps.tsv}"

CONTAINER_NAME="${WINAPPS_CONTAINER_NAME:-WinApps}"

POWERSHELL_PATH='C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'

die() {
    echo "ERROR: $*" >&2
    exit 1
}

[[ -x "$START_SCRIPT" ]] ||
    die "Windows starter missing: $START_SCRIPT"

[[ -x "$LAUNCHER" ]] ||
    die "RemoteApp launcher missing: $LAUNCHER"

command -v docker >/dev/null 2>&1 ||
    die "Docker is unavailable."

command -v flock >/dev/null 2>&1 ||
    die "flock is unavailable."

mkdir -p "$WINAPPS_CONFIG_DIR"
chmod 700 "$WINAPPS_CONFIG_DIR"

# ------------------------------------------------------------
# Application detection is a setup/maintenance operation.
# Serialize it so two detectors cannot overwrite each other.
# ------------------------------------------------------------

RUNTIME_ROOT="${XDG_RUNTIME_DIR:-/tmp}"
LOCK_DIR="$RUNTIME_ROOT/winapps-$UID"

mkdir -p "$LOCK_DIR"
chmod 700 "$LOCK_DIR"

exec 9>"$LOCK_DIR/detect-apps.lock"
flock 9

echo '============================================================'
echo ' Windows RemoteApp Linux v2 - Application Detection'
echo '============================================================'
echo

# ------------------------------------------------------------
# Ensure Windows exists/runs and is genuinely RDP ready.
# ------------------------------------------------------------

"$START_SCRIPT"

# ------------------------------------------------------------
# Find the host directory mounted at /shared.
#
# Dockur maps this inside Windows as Z:
# ------------------------------------------------------------

SHARED_DIR="$(
    docker inspect "$CONTAINER_NAME" \
        --format '{{range .Mounts}}{{if eq .Destination "/shared"}}{{.Source}}{{end}}{{end}}'
)"

[[ -n "$SHARED_DIR" ]] ||
    die "Could not determine the host directory mounted at /shared."

[[ -d "$SHARED_DIR" ]] ||
    die "Shared host directory does not exist: $SHARED_DIR"

echo
echo "Shared host directory detected:"
echo "  $SHARED_DIR"

PS_NAME="winapps-detect-apps.ps1"
RESULT_NAME="winapps-detected-apps.tsv"

PS_HOST="$SHARED_DIR/$PS_NAME"
RESULT_HOST="$SHARED_DIR/$RESULT_NAME"

PS_WINDOWS="Z:\\$PS_NAME"

rm -f "$PS_HOST" "$RESULT_HOST"

cleanup_files() {
    rm -f "$PS_HOST" "$RESULT_HOST"
}

trap cleanup_files EXIT

# ------------------------------------------------------------
# Windows-side detector
# ------------------------------------------------------------

cat > "$PS_HOST" <<'POWERSHELL'
$ErrorActionPreference = 'Stop'

$ResultFile = 'Z:\winapps-detected-apps.tsv'

function Resolve-Application {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Executable,

        [Parameter(Mandatory = $true)]
        [string[]]$Candidates
    )

    $RegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\$Executable",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\$Executable"
    )

    foreach ($RegistryPath in $RegistryPaths) {
        if (Test-Path -LiteralPath $RegistryPath) {
            try {
                $RegistryKey = Get-Item -LiteralPath $RegistryPath
                $DetectedPath = $RegistryKey.GetValue('')

                if (
                    -not [string]::IsNullOrWhiteSpace($DetectedPath) -and
                    (Test-Path -LiteralPath $DetectedPath -PathType Leaf)
                ) {
                    return [string]$DetectedPath
                }
            }
            catch {
                # Continue to explicit filesystem candidates.
            }
        }
    }

    foreach ($Candidate in $Candidates) {
        if (
            -not [string]::IsNullOrWhiteSpace($Candidate) -and
            (Test-Path -LiteralPath $Candidate -PathType Leaf)
        ) {
            return [string]$Candidate
        }
    }

    return ''
}


$PowerShellPath =
    "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"


$WordCandidates = @(
    "$env:ProgramFiles\Microsoft Office\root\Office16\WINWORD.EXE",
    "$env:ProgramFiles\Microsoft Office\Office16\WINWORD.EXE"
)

if (${env:ProgramFiles(x86)}) {
    $WordCandidates += @(
        "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\WINWORD.EXE",
        "${env:ProgramFiles(x86)}\Microsoft Office\Office16\WINWORD.EXE"
    )
}


$ExcelCandidates = @(
    "$env:ProgramFiles\Microsoft Office\root\Office16\EXCEL.EXE",
    "$env:ProgramFiles\Microsoft Office\Office16\EXCEL.EXE"
)

if (${env:ProgramFiles(x86)}) {
    $ExcelCandidates += @(
        "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\EXCEL.EXE",
        "${env:ProgramFiles(x86)}\Microsoft Office\Office16\EXCEL.EXE"
    )
}


$PowerPointCandidates = @(
    "$env:ProgramFiles\Microsoft Office\root\Office16\POWERPNT.EXE",
    "$env:ProgramFiles\Microsoft Office\Office16\POWERPNT.EXE"
)

if (${env:ProgramFiles(x86)}) {
    $PowerPointCandidates += @(
        "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\POWERPNT.EXE",
        "${env:ProgramFiles(x86)}\Microsoft Office\Office16\POWERPNT.EXE"
    )
}


$Applications = [ordered]@{
    PowerShell = ''
    Word       = ''
    Excel      = ''
    PowerPoint = ''
}


if (Test-Path -LiteralPath $PowerShellPath -PathType Leaf) {
    $Applications.PowerShell = $PowerShellPath
}


$Applications.Word = Resolve-Application `
    -Executable 'WINWORD.EXE' `
    -Candidates $WordCandidates


$Applications.Excel = Resolve-Application `
    -Executable 'EXCEL.EXE' `
    -Candidates $ExcelCandidates


$Applications.PowerPoint = Resolve-Application `
    -Executable 'POWERPNT.EXE' `
    -Candidates $PowerPointCandidates


$Lines = foreach ($Entry in $Applications.GetEnumerator()) {
    "{0}`t{1}" -f $Entry.Key, $Entry.Value
}


$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

[System.IO.File]::WriteAllLines(
    $ResultFile,
    $Lines,
    $Utf8NoBom
)
POWERSHELL

chmod 600 "$PS_HOST"

echo
echo 'Running Windows application detector...'

APP_COMMAND="-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $PS_WINDOWS"

set +e

"$LAUNCHER" \
    "$POWERSHELL_PATH" \
    "$APP_COMMAND"

LAUNCH_STATUS=$?

set -e

if (( LAUNCH_STATUS != 0 )); then
    die "Windows detector RemoteApp failed with exit code $LAUNCH_STATUS."
fi

# ------------------------------------------------------------
# Validate detector output
# ------------------------------------------------------------

[[ -s "$RESULT_HOST" ]] ||
    die "Windows detector did not produce: $RESULT_HOST"

LINE_COUNT="$(wc -l < "$RESULT_HOST")"

(( LINE_COUNT == 4 )) ||
    die "Expected 4 application records, received $LINE_COUNT."

if ! grep -q $'^PowerShell\t' "$RESULT_HOST"; then
    die "PowerShell record is missing from detector output."
fi

if ! grep -q $'^Word\t' "$RESULT_HOST"; then
    die "Word record is missing from detector output."
fi

if ! grep -q $'^Excel\t' "$RESULT_HOST"; then
    die "Excel record is missing from detector output."
fi

if ! grep -q $'^PowerPoint\t' "$RESULT_HOST"; then
    die "PowerPoint record is missing from detector output."
fi

# ------------------------------------------------------------
# Save persistent Linux-side application manifest
# ------------------------------------------------------------

TMP_APPS_FILE="$(mktemp "$WINAPPS_CONFIG_DIR/.apps.tsv.XXXXXX")"

sed 's/\r$//' "$RESULT_HOST" > "$TMP_APPS_FILE"

chmod 600 "$TMP_APPS_FILE"
mv -f "$TMP_APPS_FILE" "$APPS_FILE"

echo
echo '---------------- Detection result ----------------'

FOUND=0
MISSING=0

while IFS=$'\t' read -r NAME WINDOWS_PATH; do
    if [[ -n "$WINDOWS_PATH" ]]; then
        printf 'FOUND    %-12s %s\n' "$NAME" "$WINDOWS_PATH"
        FOUND=$((FOUND + 1))
    else
        printf 'MISSING  %-12s not installed/detected\n' "$NAME"
        MISSING=$((MISSING + 1))
    fi
done < "$APPS_FILE"

echo
echo "Application manifest:"
echo "  $APPS_FILE"

echo
echo "FOUND:   $FOUND"
echo "MISSING: $MISSING"

echo
echo "Application detection completed successfully."
