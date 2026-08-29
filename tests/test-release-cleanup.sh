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

absent_file() {
    local file="$1"
    local description="$2"

    if [[ ! -e "$file" ]]; then
        pass "$description"
    else
        fail "$description"
    fi
}

echo '============================================================'
echo ' Windows RemoteApp Linux v2 - Release Cleanup Contract'
echo '============================================================'

echo
echo '========== CANONICAL CONFIGURATION =========='

if [[ -f compose.yml ]]; then
    pass "canonical compose.yml exists"
else
    fail "canonical compose.yml exists"
fi

if [[ -f config/winapps.env.example ]]; then
    pass "canonical config template exists"
else
    fail "canonical config template exists"
fi

contains \
    config/winapps.env.example \
    '^WINDOWS_VERSION=10$' \
    "canonical Windows default is 10"

contains \
    config/winapps.env.example \
    '^WINDOWS_RAM=6G$' \
    "canonical RAM default is 6G"

contains \
    config/winapps.env.example \
    '^WINDOWS_DISK=40G$' \
    "canonical disk default is 40G"

echo
echo '========== RETIRED V1/DUPLICATE FILES =========='

absent_file \
    docker-compose.yaml \
    "obsolete docker-compose.yaml is retired"

absent_file \
    examples/compose.yml \
    "obsolete example Compose file is retired"

absent_file \
    examples/.env.example \
    "obsolete example environment file is retired"

absent_file \
    examples/credentials.example \
    "obsolete example credentials file is retired"

absent_file \
    scripts/install-launcher.sh \
    "obsolete launcher installer is retired"

echo
echo '========== INTERNAL ONE-SHOT LAUNCHER =========='

if [[ -f scripts/winapp-launcher.sh ]]; then
    pass "internal one-shot launcher remains available"
else
    fail "internal one-shot launcher remains available"
fi

contains \
    scripts/detect-apps.sh \
    'winapp-launcher\.sh' \
    "application detector retains one-shot launcher dependency"

echo
echo '========== ARCHITECTURE DOCUMENTATION =========='

contains \
    docs/01-overview.md \
    'Windows 10.*11|Windows 10/11|Windows 10 and 11' \
    "architecture guide describes Windows 10/11"

contains \
    docs/01-overview.md \
    'single.*FreeRDP|persistent.*broker|one persistent' \
    "architecture guide describes persistent broker design"

contains \
    docs/01-overview.md \
    'final.*application.*close|final managed application' \
    "architecture guide describes final-app shutdown"

echo
echo '========== REQUIREMENTS DOCUMENTATION =========='

contains \
    docs/02-requirements.md \
    '/dev/net/tun' \
    "requirements include TUN device"

contains \
    docs/02-requirements.md \
    'Docker.*current user|current.*user.*Docker|docker ps' \
    "requirements document current-user Docker access"

contains \
    docs/02-requirements.md \
    '40 (GiB|GB)' \
    "requirements reflect 40 GiB disk floor/default"

contains \
    docs/02-requirements.md \
    '4 (GiB|GB)' \
    "requirements document 4 GiB Windows RAM minimum"

echo
echo '========== WINDOWS PROVISIONING DOCUMENTATION =========='

contains \
    docs/05-configure-windows.md \
    'configure-winapps\.ps1' \
    "Windows guide documents provisioning script"

contains \
    docs/05-configure-windows.md \
    'AUTOLOGIN|automatic console logon' \
    "Windows guide documents autologin conflict prevention"

contains \
    docs/05-configure-windows.md \
    'winapps-broker\.ps1|RemoteApp broker' \
    "Windows guide documents broker provisioning"

echo
echo '========== FREERDP DOCUMENTATION =========='

contains \
    docs/06-install-freerdp.md \
    '3\.26.*required|required.*3\.26' \
    "FreeRDP guide states 3.26+ is required"

contains \
    docs/06-install-freerdp.md \
    'xfreerdp3 /version' \
    "FreeRDP guide documents version verification"

echo
echo '========== CHANGELOG =========='

contains \
    CHANGELOG.md \
    '2\.0\.0' \
    "changelog contains v2 entry"

contains \
    CHANGELOG.md \
    'broker' \
    "changelog records broker architecture"

contains \
    CHANGELOG.md \
    'authentication' \
    "changelog records authentication readiness"

contains \
    CHANGELOG.md \
    'uninstall|purge-data' \
    "changelog records safe uninstall behavior"

echo
echo '========== CONTRIBUTING =========='

contains \
    CONTRIBUTING.md \
    'tests/test-\*\.sh|tests/' \
    "contributing guide requires regression tests"

contains \
    CONTRIBUTING.md \
    'git diff --check' \
    "contributing guide requires diff whitespace validation"

contains \
    CONTRIBUTING.md \
    'CRLF' \
    "contributing guide documents Windows OEM CRLF policy"

echo
echo '========== REPOSITORY REFERENCES =========='

OBSOLETE_REFS="$(
    grep -RniE \
        --exclude-dir=.git \
        --exclude-dir=tests \
        --exclude='uninstall.sh' \
        'docker-compose\.yaml|examples/compose\.yml|examples/\.env\.example|examples/credentials\.example|scripts/install-launcher\.sh|\.local/bin/winapp-launcher' \
        . \
        2>/dev/null || true
)"

if [[ -z "$OBSOLETE_REFS" ]]; then
    pass "no production/docs references to retired v1 files"
else
    fail "no production/docs references to retired v1 files"
    printf '%s\n' "$OBSOLETE_REFS"
fi

echo
echo '============================================================'
echo " FAILURES: $FAILURES"
echo '============================================================'

(( FAILURES == 0 ))
