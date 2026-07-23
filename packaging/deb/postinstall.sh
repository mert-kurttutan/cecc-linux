#!/usr/bin/env bash
set -euo pipefail

GROUP="excalibur"
HELPER="/usr/local/libexec/excalibur-control-center/apply-sysfs-permissions"

groupadd -f "$GROUP"

if command -v udevadm >/dev/null 2>&1; then
  udevadm control --reload-rules || true
  udevadm trigger --subsystem-match=leds --action=change >/dev/null 2>&1 || true
  udevadm trigger --subsystem-match=module --action=change >/dev/null 2>&1 || true
fi

if [ -x "$HELPER" ]; then
  "$HELPER" all || true
fi

echo "Installed Excalibur Control Center."
echo "Add users to the excalibur group to use hardware controls without sudo:"
echo "  sudo usermod -aG excalibur <username>"
echo "Users must log out and back in for group membership to apply."
