# Shared by the scripts: paths, the version, logging.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
. "$ROOT/versions.env"
VERSION=$HAILO_VERSION
SRC=$ROOT/src
BUILD=$ROOT/build
STAGE=$BUILD/stage                 # everything built is installed here first (DESTDIR)
LOGS=$ROOT/logs
MULTIARCH=aarch64-linux-gnu
JOBS=${JOBS:-$(nproc)}
FIRMWARE_URL=https://hailo-hailort.s3.eu-west-2.amazonaws.com/Hailo10H/$VERSION/FW/hailo10h_fw.tar.gz
MODELS_URL=https://dev-public.hailo.ai/v$VERSION/blob

step() { echo "=== $* ($(date +%T))"; }

# run <log> <command...>: the command's output goes to logs/<log>.log; on failure, show its end
run() {
    local log=$LOGS/$1.log owner
    shift
    owner=$(stat -c %u:%g "$ROOT")       # logs belong to the checkout's owner, even under sudo
    [ -d "$LOGS" ] || { mkdir -p "$LOGS"; chown "$owner" "$LOGS" 2>/dev/null || true; }
    : > "$log"
    chown "$owner" "$log" 2>/dev/null || true
    if ! "$@" > "$log" 2>&1; then
        echo "Failed: $*" >&2
        tail -n 30 "$log" >&2
        echo "(the whole log: $log)" >&2
        exit 1
    fi
}

check_pi5() {
    [ "$(uname -m)" = aarch64 ] || { echo "This needs 64-bit Raspberry Pi OS (aarch64)." >&2; exit 1; }
    if ! tr -d '\0' < /proc/device-tree/model 2>/dev/null | grep -q "Raspberry Pi 5"; then
        [ "${FORCE:-}" = 1 ] || { echo "This is for a Raspberry Pi 5 (set FORCE=1 to try anyway)." >&2; exit 1; }
    fi
}

need_root() { [ "$(id -u)" = 0 ] || { echo "Run this as root (sudo $0)." >&2; exit 1; }; }

# The Hailo-10H's PCI address (vendor 1e60), e.g. 0001:01:00.0
hailo_pci() {
    local d
    for d in /sys/bus/pci/devices/*; do
        [ "$(cat "$d/vendor" 2>/dev/null)" = 0x1e60 ] && { basename "$d"; return 0; }
    done
    return 1
}

# The Hailo-10H firmware is Hailo's, under Hailo's licence. Nothing here accepts it for you: you
# read it, then set ACCEPT_HAILO_FIRMWARE_EULA=yes yourself. Without that, stop.
EULA_URL=https://github.com/hailo-ai/hailort/blob/v$VERSION/hailort/hailo_firmware_eula
require_eula() {
    [ "${ACCEPT_HAILO_FIRMWARE_EULA:-}" = yes ] && return 0
    cat >&2 <<MSG
Error: the Hailo-10H firmware is licensed by Hailo, and you must accept its licence before it's
downloaded or installed. Read it here:

    $EULA_URL

If you accept it, set this yourself and run the command again:

    export ACCEPT_HAILO_FIRMWARE_EULA=yes
MSG
    [ "$(id -u)" = 0 ] && echo "(sudo doesn't pass it through: run sudo ACCEPT_HAILO_FIRMWARE_EULA=yes $0)" >&2
    exit 1
}
