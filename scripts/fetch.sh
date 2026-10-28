#!/usr/bin/env bash
# Download Hailo's sources (git tags v$HAILO_VERSION) and the Hailo-10H firmware into src/ and
# build/. Nothing of Hailo's is kept in this repository: it's all fetched from Hailo here.
# The firmware is under Hailo's licence: this stops unless you've set
# ACCEPT_HAILO_FIRMWARE_EULA=yes yourself, having read it.
. "$(dirname "$0")/lib.sh"
require_eula
mkdir -p "$SRC" "$BUILD"

clone() {   # clone <name>: github.com/hailo-ai/<name> at the release tag
    local dir=$SRC/$1 tag=v$VERSION
    if [ -d "$dir/.git" ] && [ "$(git -C "$dir" describe --tags --exact-match 2>/dev/null)" = "$tag" ]; then
        echo "$1 $tag: already here"
        return
    fi
    rm -rf "$dir"
    step "Clone $1 $tag"
    git -c advice.detachedHead=false clone -q --depth 1 --branch "$tag" "https://github.com/hailo-ai/$1.git" "$dir"
}
clone hailort                  # libhailort, hailortcli, the GStreamer plugin, Python bindings
clone hailort-drivers          # the PCIe driver (hailo1x_pci)
clone hailo_model_zoo_genai    # hailo-ollama
clone tappas                   # TAPPAS core: GStreamer elements, post-processing, Python

# TAPPAS's header-only dependencies (xtensor, pybind11, ...), as its own installer gets them
if [ ! -d "$SRC/tappas/core/open_source/xtensor_stack" ]; then
    step "TAPPAS's header-only dependencies"
    run tappas-externals env TAPPAS_WORKSPACE="$SRC/tappas" bash "$SRC/tappas/scripts/build_scripts/clone_external_packages.sh"
fi

# FIRMWARE_FROM=<dir>: use a copy you already have (e.g. /lib/firmware/hailo/hailo10h from an
# earlier install of the same version) instead of downloading it. It's still Hailo's licence.
fw=$BUILD/firmware-$VERSION
if [ -n "${FIRMWARE_FROM:-}" ] && [ ! -f "$fw/fitImage" ]; then
    [ -f "$FIRMWARE_FROM/fitImage" ] || { echo "No firmware in $FIRMWARE_FROM (no fitImage)." >&2; exit 1; }
    step "Firmware from $FIRMWARE_FROM"
    rm -rf "$fw" && mkdir -p "$fw" && cp "$FIRMWARE_FROM"/* "$fw"/
fi
if [ ! -f "$fw/fitImage" ]; then
    step "Firmware $VERSION"
    mkdir -p "$fw.tmp"
    curl -fsSL "$FIRMWARE_URL" | tar xz -C "$fw.tmp"
    # flatten: the files the driver loads from /lib/firmware/hailo/hailo10h
    find "$fw.tmp" -type f -exec mv -t "$fw.tmp" {} + 2>/dev/null || true
    find "$fw.tmp" -mindepth 1 -type d -empty -delete
    rm -rf "$fw" && mv "$fw.tmp" "$fw"
fi
[ -f "$fw/fitImage" ] || { echo "The firmware has no fitImage: has the download changed?" >&2; exit 1; }
echo "Sources in $SRC, firmware in $fw"
