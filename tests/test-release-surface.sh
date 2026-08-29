#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

FAILURES=0

pass() {
    printf 'PASS  %s\n' "$1"
}

fail() {
    printf 'FAIL  %s\n' "$1"
    FAILURES=$((FAILURES + 1))
}

contains() {
    local file="$1"
    local pattern="$2"
    local description="$3"

    if grep -Eiq -- "$pattern" "$file"; then
        pass "$description"
    else
        fail "$description"
    fi
}

absent() {
    local file="$1"
    local pattern="$2"
    local description="$3"

    if grep -Eiq -- "$pattern" "$file"; then
        fail "$description"
    else
        pass "$description"
    fi
}

echo '============================================================'
echo ' Windows RemoteApp Linux v2 - Release Surface Contract'
echo '============================================================'

echo
echo '========== README INSTALL FLOW =========='

contains \
    README.md \
    '\./setup\.sh[[:space:]]+configure' \
    "README documents setup configure"

contains \
    README.md \
    '\./setup\.sh[[:space:]]+install-windows' \
    "README documents setup install-windows"

contains \
    README.md \
    '\./setup\.sh[[:space:]]+finalize' \
    "README documents setup finalize"

absent \
    README.md \
    'scripts/install-launcher\.sh' \
    "README no longer exposes legacy launcher installer"

absent \
    README.md \
    '\.local/bin/winapp-launcher' \
    "README no longer exposes legacy per-app launcher"

absent \
    README.md \
    'passwordless sudo|sudoers\.d/winapps-container' \
    "README no longer requires passwordless sudo"

absent \
    README.md \
    'sudo[[:space:]]+docker' \
    "README no longer tells users to run Docker with sudo"

contains \
    README.md \
    'broker-launcher\.sh|persistent.*broker|single.*FreeRDP' \
    "README describes broker architecture"

contains \
    README.md \
    'authentication readiness|auth.*readiness|accepted FreeRDP authentication' \
    "README describes authentication-based Windows readiness"

echo
echo '========== VERSION / DEFAULTS =========='

contains \
    README.md \
    'Windows 10.*Windows 11|Windows 10 or 11|Windows 10/11' \
    "README supports Windows 10 and 11"

contains \
    README.md \
    'WINDOWS_VERSION[^[:cntrl:]]*10' \
    "README reflects Windows 10 default"

contains \
    README.md \
    'WINDOWS_RAM[^[:cntrl:]]*6G' \
    "README reflects 6G RAM default"

contains \
    README.md \
    'WINDOWS_DISK[^[:cntrl:]]*40G' \
    "README reflects 40G disk default"

echo
echo '========== UNINSTALL IMPLEMENTATION =========='

if [[ -s uninstall.sh ]]; then
    pass "uninstall.sh is non-empty"
else
    fail "uninstall.sh is non-empty"
fi

contains \
    uninstall.sh \
    '^#!/usr/bin/env bash' \
    "uninstall.sh has Bash shebang"

contains \
    uninstall.sh \
    '--purge-data' \
    "uninstall supports explicit destructive data purge"

contains \
    uninstall.sh \
    'winapps_data' \
    "uninstall knows the persistent Windows volume"

absent \
    uninstall.sh \
    'docker[[:space:]]+compose[[:space:]]+down[[:space:]]+-v' \
    "uninstall never uses implicit compose volume purge"

absent \
    uninstall.sh \
    'sudo[[:space:]]+docker' \
    "uninstall does not require sudo Docker"

contains \
    uninstall.sh \
    'winapps-word\.desktop' \
    "uninstall removes current Word shortcut"

contains \
    uninstall.sh \
    'winapps-excel\.desktop' \
    "uninstall removes current Excel shortcut"

contains \
    uninstall.sh \
    'winapps-powerpoint\.desktop' \
    "uninstall removes current PowerPoint shortcut"

contains \
    uninstall.sh \
    'winapps-powershell\.desktop' \
    "uninstall removes current PowerShell shortcut"

contains \
    uninstall.sh \
    'winapps-start-windows\.desktop' \
    "uninstall removes Start Windows shortcut"

contains \
    uninstall.sh \
    'winapps-windows-desktop\.desktop' \
    "uninstall removes Windows Desktop shortcut"

contains \
    uninstall.sh \
    'winapps/launchers' \
    "uninstall removes generated launcher wrappers"

echo
echo '========== UNINSTALL DOCUMENTATION =========='

contains \
    docs/14-uninstall.md \
    '\./uninstall\.sh' \
    "uninstall guide uses repository uninstaller"

contains \
    docs/14-uninstall.md \
    '--purge-data' \
    "uninstall guide documents explicit data purge"

absent \
    docs/14-uninstall.md \
    'docker[[:space:]]+compose[[:space:]]+down[[:space:]]+-v' \
    "uninstall guide does not recommend implicit volume deletion"

absent \
    docs/14-uninstall.md \
    'sudoers\.d/winapps-container' \
    "uninstall guide has no obsolete sudoers cleanup"

echo
echo '========== USER-FACING DOC MIGRATION =========='

for file in \
    docs/08-install-launcher.md \
    docs/09-sudoers.md \
    docs/10-create-shortcuts.md \
    docs/11-test.md \
    docs/12-troubleshooting.md \
    docs/13-security.md
do
    absent \
        "$file" \
        '\.local/bin/winapp-launcher|scripts/install-launcher\.sh|sudoers\.d/winapps-container' \
        "$file does not teach legacy launcher/sudoers workflow"
done

absent \
    docs/03-install-docker.md \
    'sudo[[:space:]]+docker' \
    "Docker guide verifies Docker as the current user"

absent \
    docs/04-create-windows-container.md \
    'sudo[[:space:]]+docker' \
    "Windows-container guide does not use sudo Docker"


absent \
    docs/12-troubleshooting.md \
    'cold-boot delay|WINAPPS_COLD_BOOT_DELAY|winapps-container-manager|\.winapps-cleanup\.log' \
    "troubleshooting guide no longer documents obsolete delay/marker lifecycle"

contains \
    docs/12-troubleshooting.md \
    'authentication readiness|successful FreeRDP authentication' \
    "troubleshooting guide documents authentication readiness"

contains \
    docs/12-troubleshooting.md \
    'supervisor\.pid|freerdp\.pid' \
    "troubleshooting guide documents broker PID state"

absent \
    docs/13-security.md \
    'sudoers|passwordless sudo|exact Docker commands required' \
    "security guide no longer requires obsolete sudoers permissions"

echo
echo '========== DIAGNOSTIC SCRIPT =========='

absent \
    scripts/diagnose-winapps.sh \
    'sudo[[:space:]]+-n[[:space:]]+docker|sudo[[:space:]]+docker' \
    "diagnostic helper uses Docker without sudo"

contains \
    scripts/diagnose-winapps.sh \
    'broker-launcher|broker' \
    "diagnostic helper knows broker processes"

contains \
    scripts/diagnose-winapps.sh \
    'supervisor\.pid|freerdp\.pid' \
    "diagnostic helper reports broker PID state"

absent \
    scripts/diagnose-winapps.sh \
    'winapps-container-manager' \
    "diagnostic helper no longer uses obsolete runtime-marker path"

echo
echo '========== NOTEPAD TEST =========='

contains \
    scripts/test-notepad.sh \
    'broker-launcher\.sh' \
    "Notepad test uses production broker launcher"

absent \
    scripts/test-notepad.sh \
    'winapp-launcher\.sh' \
    "Notepad test no longer exercises legacy per-app lifecycle"

echo
echo '========== LEGACY LAUNCHER SCOPE =========='

# The old launcher is temporarily retained because detect-apps.sh
# still uses it as an internal one-shot PowerShell transport.
contains \
    scripts/detect-apps.sh \
    'winapp-launcher\.sh' \
    "detector retains internal one-shot legacy launcher dependency"

# It must not remain a documented end-user installation path.
LEGACY_DOC_REFS="$(
    grep -RniE \
        --include='*.md' \
        'scripts/install-launcher\.sh|\.local/bin/winapp-launcher' \
        README.md docs \
        2>/dev/null || true
)"

if [[ -z "$LEGACY_DOC_REFS" ]]; then
    pass "legacy launcher has no user-facing documentation references"
else
    fail "legacy launcher has no user-facing documentation references"
    printf '%s\n' "$LEGACY_DOC_REFS"
fi

echo
echo '============================================================'
echo " FAILURES: $FAILURES"
echo '============================================================'

(( FAILURES == 0 ))
