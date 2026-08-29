#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNINSTALL="$REPO_DIR/uninstall.sh"

TEST_ROOT="$(mktemp -d)"
FAKE_BIN="$TEST_ROOT/bin"
FAKE_HOME="$TEST_ROOT/home"
FAKE_DATA="$TEST_ROOT/data"
FAKE_CONFIG="$TEST_ROOT/config"
FAKE_WINAPPS="$TEST_ROOT/WinApps"
DOCKER_LOG="$TEST_ROOT/docker.log"

FAILURES=0

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

pass() {
    printf 'PASS  %s\n' "$1"
}

fail() {
    printf 'FAIL  %s\n' "$1"
    FAILURES=$((FAILURES + 1))
}

mkdir -p \
    "$FAKE_BIN" \
    "$FAKE_HOME" \
    "$FAKE_DATA/applications" \
    "$FAKE_DATA/winapps/launchers" \
    "$FAKE_CONFIG" \
    "$FAKE_WINAPPS/shared"

# ------------------------------------------------------------
# Fake Docker
#
# - Records every invocation.
# - Pretends the container and volume exist.
# - Does not touch the real Docker daemon.
# ------------------------------------------------------------

cat > "$FAKE_BIN/docker" <<'DOCKER'
#!/usr/bin/env bash
set -u

printf '%s\n' "$*" >> "$FAKE_DOCKER_LOG"

case "${1:-} ${2:-}" in
    "inspect WinApps")
        exit 0
        ;;

    "volume inspect")
        exit 0
        ;;

    *)
        exit 0
        ;;
esac
DOCKER

chmod 755 "$FAKE_BIN/docker"

create_local_artifacts() {
    rm -rf \
        "$FAKE_DATA/applications" \
        "$FAKE_DATA/winapps/launchers" \
        "$FAKE_CONFIG"

    mkdir -p \
        "$FAKE_DATA/applications" \
        "$FAKE_DATA/winapps/launchers" \
        "$FAKE_CONFIG"

    for file in \
        winapps-word.desktop \
        winapps-excel.desktop \
        winapps-powerpoint.desktop \
        winapps-powershell.desktop \
        winapps-start-windows.desktop \
        winapps-windows-desktop.desktop
    do
        printf 'test\n' > "$FAKE_DATA/applications/$file"
    done

    for file in \
        winapps-word \
        winapps-excel \
        winapps-powerpoint \
        winapps-powershell
    do
        printf 'test\n' > "$FAKE_DATA/winapps/launchers/$file"
    done

    printf 'RDP_USER=test\n' > "$FAKE_CONFIG/credentials"
    printf 'Word\tC:\\Test\\Word.exe\n' > "$FAKE_CONFIG/apps.tsv"
}

run_uninstall() {
    env \
        HOME="$FAKE_HOME" \
        PATH="$FAKE_BIN:$PATH" \
        XDG_DATA_HOME="$FAKE_DATA" \
        WINAPPS_DIR="$FAKE_WINAPPS" \
        WINAPPS_CONFIG_DIR="$FAKE_CONFIG" \
        WINAPPS_CONTAINER_NAME="WinApps" \
        WINAPPS_VOLUME_NAME="winapps_data" \
        FAKE_DOCKER_LOG="$DOCKER_LOG" \
        "$UNINSTALL" "$@"
}

echo '============================================================'
echo ' Windows RemoteApp Linux v2 - Uninstall Behavior'
echo '============================================================'

echo
echo '========== DEFAULT UNINSTALL =========='

create_local_artifacts
: > "$DOCKER_LOG"

set +e
run_uninstall >"$TEST_ROOT/default.out" 2>&1
DEFAULT_STATUS=$?
set -e

cat "$TEST_ROOT/default.out"

if [[ "$DEFAULT_STATUS" -eq 0 ]]; then
    pass "default uninstall exits successfully"
else
    fail "default uninstall exits successfully"
fi

if grep -Eq '^rm -f WinApps$' "$DOCKER_LOG"; then
    pass "default uninstall removes disposable container"
else
    fail "default uninstall removes disposable container"
fi

if grep -Eq '^volume rm( -f)? winapps_data$' "$DOCKER_LOG"; then
    fail "default uninstall preserves winapps_data"
else
    pass "default uninstall preserves winapps_data"
fi

if [[ -d "$FAKE_WINAPPS" ]]; then
    pass "default uninstall preserves WinApps working directory"
else
    fail "default uninstall preserves WinApps working directory"
fi

if [[ ! -e "$FAKE_CONFIG/credentials" ]] &&
   [[ ! -e "$FAKE_CONFIG/apps.tsv" ]]
then
    pass "default uninstall removes local WinApps config/credentials"
else
    fail "default uninstall removes local WinApps config/credentials"
fi

SHORTCUTS_LEFT="$(
    find "$FAKE_DATA/applications" \
        -maxdepth 1 \
        -type f \
        -name 'winapps-*.desktop' \
        -print \
        2>/dev/null || true
)"

if [[ -z "$SHORTCUTS_LEFT" ]]; then
    pass "default uninstall removes generated desktop entries"
else
    fail "default uninstall removes generated desktop entries"
    printf '%s\n' "$SHORTCUTS_LEFT"
fi

if [[ ! -d "$FAKE_DATA/winapps/launchers" ]]; then
    pass "default uninstall removes generated launcher wrappers"
else
    fail "default uninstall removes generated launcher wrappers"
fi

echo
echo '========== PURGE-DATA UNINSTALL =========='

create_local_artifacts
: > "$DOCKER_LOG"

set +e
run_uninstall --purge-data --yes >"$TEST_ROOT/purge.out" 2>&1
PURGE_STATUS=$?
set -e

cat "$TEST_ROOT/purge.out"

if [[ "$PURGE_STATUS" -eq 0 ]]; then
    pass "purge-data uninstall exits successfully"
else
    fail "purge-data uninstall exits successfully"
fi

if grep -Eq '^rm -f WinApps$' "$DOCKER_LOG"; then
    pass "purge-data removes disposable container first"
else
    fail "purge-data removes disposable container first"
fi

if grep -Eq '^volume rm( -f)? winapps_data$' "$DOCKER_LOG"; then
    pass "purge-data explicitly removes winapps_data"
else
    fail "purge-data explicitly removes winapps_data"
fi

if [[ -d "$FAKE_WINAPPS" ]]; then
    pass "purge-data still preserves host WinApps/shared directory"
else
    fail "purge-data still preserves host WinApps/shared directory"
fi

echo
echo '========== HELP CONTRACT =========='

set +e
HELP_OUTPUT="$("$UNINSTALL" --help 2>&1)"
HELP_STATUS=$?
set -e

if [[ "$HELP_STATUS" -eq 0 ]]; then
    pass "--help exits successfully"
else
    fail "--help exits successfully"
fi

if printf '%s\n' "$HELP_OUTPUT" | grep -q -- '--purge-data'; then
    pass "--help documents --purge-data"
else
    fail "--help documents --purge-data"
fi

if printf '%s\n' "$HELP_OUTPUT" | grep -q -- '--yes'; then
    pass "--help documents non-interactive purge confirmation"
else
    fail "--help documents non-interactive purge confirmation"
fi

echo
echo '============================================================'
echo " FAILURES: $FAILURES"
echo '============================================================'

(( FAILURES == 0 ))
