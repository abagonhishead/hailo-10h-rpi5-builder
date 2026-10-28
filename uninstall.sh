#!/usr/bin/env bash
# Remove what install.sh installed (run as root). Afterwards, Raspberry Pi's packages can go back
# on with: sudo apt install hailo-h10-all
. "$(dirname "$0")/scripts/lib.sh"
need_root
MANIFEST=/var/lib/hailo-h10-rpi5-builder/installed-files.txt
[ -f "$MANIFEST" ] || { echo "Nothing to remove: $MANIFEST isn't there." >&2; exit 1; }
systemctl disable --now hailo-ollama 2>/dev/null || true
modprobe -r hailo1x_pci 2>/dev/null || true
step "Driver"
rm -rf /var/lib/dkms/hailo1x_pci /lib/modules/*/updates/dkms/hailo1x_pci* /usr/src/hailo1x_pci-*
depmod -a
step "Files"
while IFS= read -r f; do rm -f "$f"; done < "$MANIFEST"
rmdir --ignore-fail-on-non-empty /lib/firmware/hailo/hailo10h /lib/firmware/hailo 2>/dev/null || true
python3 -m pip uninstall -y --root-user-action=ignore --break-system-packages hailort > /dev/null 2>&1 || true
ldconfig
systemctl daemon-reload
udevadm control --reload
rm -f "$MANIFEST"
echo "Removed. The hailo-ollama user, the device group, its models in /usr/share/hailo-ollama and the backups in /var/backups/hailo-h10-rpi5-builder are left in place."
