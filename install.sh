#!/usr/bin/env bash
# Install what build.sh built (run as root): the PCIe driver (DKMS), the firmware, HailoRT,
# hailortcli, the GStreamer plugin, hailo_platform for python3, hailo-ollama and TAPPAS.
# Raspberry Pi's own Hailo packages, if installed, are removed first and held back.
#   sudo ACCEPT_HAILO_FIRMWARE_EULA=yes ./install.sh          asks before removing anything
#   sudo ACCEPT_HAILO_FIRMWARE_EULA=yes ./install.sh --yes    doesn't ask
# HAILO_GROUP (default hailo): the group that may use the Hailo-10H.
. "$(dirname "$0")/scripts/lib.sh"
need_root
check_pi5
require_eula      # it installs Hailo's firmware
yes=0
[ "${1:-}" = --yes ] && yes=1
GROUP=${HAILO_GROUP:-hailo}
STATE=/var/lib/hailo-h10-rpi5-builder
MANIFEST=$STATE/installed-files.txt
FW=$BUILD/firmware-$VERSION
[ -x "$STAGE/usr/bin/hailortcli" ] && [ -f "$FW/fitImage" ] || { echo "Nothing built yet: run ./build.sh first." >&2; exit 1; }
mkdir -p "$STATE"

# Raspberry Pi's packages: the 5.1.1 runtime, driver, models, TAPPAS, and the Hailo-8 runtime that
# apt reaches for when they go (hailo-ai/hailo-rpi5-examples#195)
RPI_PKGS="hailo-all hailo-h10-all h10-hailort python3-h10-hailort h10-hailort-pcie-driver hailo-gen-ai-model-zoo
          hailo-tappas-core python3-hailo-tappas rpicam-apps-hailo-postprocess hailort hailort-pcie-driver python3-hailort"
installed=$(dpkg-query -W -f '${db:Status-Abbrev} ${Package}\n' $RPI_PKGS 2>/dev/null | awk '$1 ~ /^.i/ {print $2}' | xargs || true)
if [ -n "$installed" ]; then
    echo "These Raspberry Pi packages will be removed (and kept from coming back): $installed"
    if [ $yes = 0 ]; then read -r -p "Go ahead? [y/N] " a; [ "$a" = y ] || exit 1; fi
fi
echo "Anything using the Hailo-10H loses it for a few seconds while the driver reloads."

step "Back up the current state"
bk=/var/backups/hailo-h10-rpi5-builder/$(date +%Y%m%d-%H%M%S)
mkdir -p "$bk"
dpkg -l | awk '/hailo|h10/ {print $2, $3}' > "$bk/packages.txt"
[ -d /lib/firmware/hailo ] && cp -a /lib/firmware/hailo "$bk/firmware"
echo "Backed up to $bk"

ollama_was_on=0
systemctl is-enabled -q hailo-ollama 2>/dev/null && ollama_was_on=1
systemctl stop hailo-ollama 2>/dev/null || true
# The driver can't be reloaded while anything has the device open
holders=$(fuser /dev/h1x-* /dev/hailo* 2>/dev/null | xargs || true)
if [ -n "$holders" ]; then
    echo "These processes have the Hailo-10H open; stop them, then run this again:" >&2
    ps -o pid=,user=,args= -p "${holders// /,}" >&2
    [ $ollama_was_on = 1 ] && systemctl start hailo-ollama
    exit 1
fi

if [ -n "$installed" ]; then
    step "Remove Raspberry Pi's Hailo packages"
    run apt-remove env DEBIAN_FRONTEND=noninteractive apt-get remove -y --allow-change-held-packages $installed
fi
cat > /etc/apt/preferences.d/hailo-h10-rpi5-builder <<PIN
# HailoRT $VERSION is built from source (hailo-h10-rpi5-builder): keep apt from installing Raspberry Pi's
# Hailo packages over it. Remove this file to go back to them.
Package: $(echo $RPI_PKGS)
Pin: origin archive.raspberrypi.com
Pin-Priority: -1
PIN

step "PCIe driver (DKMS)"
if lsmod | grep -q '^hailo1x_pci '; then modprobe -r hailo1x_pci; fi
run driver make -C "$SRC/hailort-drivers/linux/pcie" install_dkms

step "Firmware"
rm -rf /lib/firmware/hailo/hailo10h
install -d -m 755 /lib/firmware/hailo/hailo10h
install -m 644 "$FW"/* /lib/firmware/hailo/hailo10h/

step "HailoRT, hailo-ollama, TAPPAS"
# Never cp -a the stage over /usr: it would copy the builder's ownership and modes onto system
# directories. Make directories as root 755, then copy the files in, owned by root.
(cd "$STAGE" && find usr -type d -print0 | while IFS= read -r -d '' d; do install -d -m 755 "/$d"; done
 find usr ! -type d -print0 | while IFS= read -r -d '' f; do
     cp -P --preserve=timestamps "$f" "/$f"; chown -h root:root "/$f"
     [ -L "/$f" ] || chmod go-w "/$f"
 done)
ldconfig

step "Device access (group $GROUP)"
getent group "$GROUP" > /dev/null || groupadd --system "$GROUP"
# 5.4.0's driver makes /dev/h1x-N in subsystem hailo1x (5.1.1 made /dev/hailoN)
printf '# Hailo-10H (HailoRT %s driver, /dev/h1x-N): for the %s group\nSUBSYSTEM=="hailo1x", MODE="0660", GROUP="%s"\n' \
    "$VERSION" "$GROUP" "$GROUP" > /etc/udev/rules.d/60-hailo1x.rules
udevadm control --reload

if [ -x /usr/bin/hailo-ollama ]; then
    step "hailo-ollama service"
    getent passwd hailo-ollama > /dev/null || useradd --system --no-create-home --home-dir /usr/share/hailo-ollama \
        --shell /usr/sbin/nologin hailo-ollama
    usermod -aG "$GROUP" hailo-ollama
    install -d -m 755 -o hailo-ollama -g hailo-ollama /var/log/hailo-ollama
    install -d -m 2775 -o hailo-ollama -g hailo-ollama /usr/share/hailo-ollama/models
    install -m 644 "$ROOT/files/hailo-ollama.service" /etc/systemd/system/hailo-ollama.service
    systemctl daemon-reload
fi

step "hailo_platform for python3"
run pip python3 -m pip install --root-user-action=ignore --break-system-packages --no-deps --force-reinstall \
    "$BUILD"/wheels/hailort-"$VERSION"-*.whl

step "Record what was installed ($MANIFEST)"
{ (cd "$STAGE" && find usr ! -type d | sed 's#^#/#')
  find /lib/firmware/hailo/hailo10h -type f
  echo /etc/udev/rules.d/60-hailo1x.rules
  echo /etc/apt/preferences.d/hailo-h10-rpi5-builder
  [ -x /usr/bin/hailo-ollama ] && echo /etc/systemd/system/hailo-ollama.service
} | sort -u > "$MANIFEST"

step "Load the driver and boot the new firmware"
# The Hailo-10H keeps running the firmware it booted with until it's reset, and a new driver
# refuses old firmware ("Mismatch Driver version"). A PCIe function reset makes it boot the new
# files, without rebooting the Pi.
if lsmod | grep -q '^hailo1x_pci '; then modprobe -r hailo1x_pci; fi
if pci=$(hailo_pci); then
    echo 1 > "/sys/bus/pci/devices/$pci/reset"
else
    echo "No Hailo-10H on PCIe: is the AI HAT+ 2 fitted, and PCIe enabled? (see the README)" >&2
fi
modprobe hailo1x_pci
for _ in $(seq 20); do ls /dev/h1x-* > /dev/null 2>&1 && break; sleep 1; done
udevadm trigger --subsystem-match=hailo1x
sleep 1
hailortcli fw-control identify || { echo "The device didn't answer: see dmesg | grep -i hailo" >&2; exit 1; }
[ $ollama_was_on = 1 ] && systemctl enable --now hailo-ollama

echo
echo "Installed HailoRT $VERSION. Add yourself to the $GROUP group to use the Hailo-10H:"
echo "    sudo usermod -aG $GROUP \$USER     (then log in again)"
[ -x /usr/bin/hailo-ollama ] && [ $ollama_was_on = 0 ] && echo "Start hailo-ollama with: sudo systemctl enable --now hailo-ollama"
exit 0
