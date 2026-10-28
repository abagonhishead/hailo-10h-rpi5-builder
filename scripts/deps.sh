#!/usr/bin/env bash
# Install what the builds need from Raspberry Pi OS's own repositories (run as root).
. "$(dirname "$0")/lib.sh"
need_root
check_pi5
headers=linux-headers-$(uname -r)
apt-cache show "$headers" > /dev/null 2>&1 || headers=linux-headers-rpi-2712
step "Build dependencies ($headers)"
apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential cmake git curl psmisc ca-certificates pkg-config dkms "$headers" \
    python3-dev python3-venv python3-pip libssl-dev \
    meson ninja-build libglib2.0-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-tools libopencv-dev libtbb-dev libzmq3-dev python-gi-dev libgl-dev
