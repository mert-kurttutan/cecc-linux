#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: 'sudo ./install-udev-rules.sh'"
  exit 1
fi

GROUP="excalibur"
RULE_NAME="90-excalibur-control-center.rules"
HELPER_NAME="udev-permissions"
HELPER_DIR="/usr/local/libexec/excalibur-control-center"
RULE_DIR="/etc/udev/rules.d"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
RULE_SOURCE="$REPO_ROOT/casper-wmi/$RULE_NAME"

echo "Creating group: $GROUP"
groupadd -f "$GROUP"

echo "Installing udev permission helper..."
install -d -m 0755 "$HELPER_DIR"
install -m 0755 "$SCRIPT_DIR/udev-permissions.sh" "$HELPER_DIR/$HELPER_NAME"

echo "Installing udev rules..."
install -d -m 0755 "$RULE_DIR"
install -m 0644 "$RULE_SOURCE" "$RULE_DIR/$RULE_NAME"

echo "Reloading udev rules..."
udevadm control --reload-rules

echo "Triggering existing casper-wmi devices if present..."
udevadm trigger --subsystem-match=leds --action=change >/dev/null 2>&1 || true
udevadm trigger --subsystem-match=module --action=change >/dev/null 2>&1 || true
"$HELPER_DIR/$HELPER_NAME" all || true

echo "Installed udev rules."
echo "Add users with: sudo usermod -aG $GROUP <username>"
echo "Users must log out and back in for group membership to apply."
