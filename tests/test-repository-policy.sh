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

echo '============================================================'
echo ' Windows RemoteApp Linux v2 - Repository Policy'
echo '============================================================'

echo
echo '========== GIT ATTRIBUTES =========='

if [[ -f .gitattributes ]]; then
    pass ".gitattributes exists"
else
    fail ".gitattributes exists"
fi

if [[ -f .gitattributes ]] &&
   grep -Eq \
       '^oem/\*\.bat[[:space:]]+text[[:space:]]+eol=crlf$' \
       .gitattributes
then
    pass "OEM batch files are declared CRLF"
else
    fail "OEM batch files are declared CRLF"
fi

if [[ -f .gitattributes ]] &&
   grep -Eq \
       '^oem/\*\.reg[[:space:]]+text[[:space:]]+eol=crlf$' \
       .gitattributes
then
    pass "OEM registry files are declared CRLF"
else
    fail "OEM registry files are declared CRLF"
fi

if [[ -f .gitattributes ]] &&
   grep -Eq \
       '^oem/\*\.ps1[[:space:]]+text[[:space:]]+eol=crlf$' \
       .gitattributes
then
    pass "OEM PowerShell files are declared CRLF"
else
    fail "OEM PowerShell files are declared CRLF"
fi

echo
echo '========== UNINSTALL ENTRY POINT =========='

if [[ -x uninstall.sh ]]; then
    pass "uninstall.sh is executable"
else
    fail "uninstall.sh is executable"
fi

echo
echo '========== CURRENT PASSWORD-HANDLING DOCS =========='

STALE_DOCS="$(
    grep -RniE \
        --include='*.md' \
        '(/p:.*exposes.*password|/p:.*process list|adapt.*launcher.*from-stdin)' \
        README.md SECURITY.md docs \
        2>/dev/null || true
)"

if [[ -z "$STALE_DOCS" ]]; then
    pass "documentation contains no obsolete /p: process-list warning"
else
    fail "documentation contains no obsolete /p: process-list warning"
    printf '%s\n' "$STALE_DOCS"
fi

if grep -qi \
    'args-from:stdin' \
    README.md
then
    pass "README documents stdin-based FreeRDP argument handling"
else
    fail "README documents stdin-based FreeRDP argument handling"
fi

if grep -qi \
    'args-from:stdin' \
    SECURITY.md
then
    pass "SECURITY.md documents stdin-based FreeRDP argument handling"
else
    fail "SECURITY.md documents stdin-based FreeRDP argument handling"
fi

if grep -qi \
    'args-from:stdin' \
    docs/13-security.md
then
    pass "security guide documents stdin-based FreeRDP argument handling"
else
    fail "security guide documents stdin-based FreeRDP argument handling"
fi

echo
echo '========== GIT CRLF-AWARE DIFF CHECK =========='

if git -c core.whitespace=cr-at-eol diff --check; then
    pass "repository diff has no whitespace errors beyond intentional CRLF"
else
    fail "repository diff contains real whitespace errors"
fi

echo
echo '============================================================'
echo " FAILURES: $FAILURES"
echo '============================================================'

(( FAILURES == 0 ))
