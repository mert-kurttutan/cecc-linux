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

DRIVER_NAME="casper-wmi"
shopt -s nullglob
DKMS_CONFIGS=(/usr/src/"$DRIVER_NAME"-*/dkms.conf)

if [ "${#DKMS_CONFIGS[@]}" -ne 1 ]; then
  echo "Expected one installed $DRIVER_NAME DKMS configuration." >&2
  exit 1
fi

DKMS_CONF="${DKMS_CONFIGS[0]}"
# dkms.conf is the source of truth for the module name and version.
# shellcheck disable=SC1090
source "$DKMS_CONF"

if ! dkms status -m "$PACKAGE_NAME" -v "$PACKAGE_VERSION" 2>/dev/null | grep -q .; then
  dkms add -m "$PACKAGE_NAME" -v "$PACKAGE_VERSION"
fi

mapfile -t REGISTERED_VERSIONS < <(
  dkms status -m "$PACKAGE_NAME" 2>/dev/null \
    | awk -F/ -v name="$PACKAGE_NAME" '$1 == name { split($2, v, /[, :]/); print v[1] }' \
    | sort -u
)
for registered_version in "${REGISTERED_VERSIONS[@]}"; do
  if [ "$registered_version" != "$PACKAGE_VERSION" ]; then
    dkms remove "$PACKAGE_NAME/$registered_version" --all >/dev/null 2>&1 || true
  fi
done

kernel_version="$(uname -r)"
if [ -d "/lib/modules/$kernel_version/build" ]; then
  current_status="$(dkms status -m "$PACKAGE_NAME" -v "$PACKAGE_VERSION" -k "$kernel_version" 2>/dev/null || true)"
  if [[ "$current_status" != *": installed"* ]]; then
    if [[ "$current_status" == *": built"* ]]; then
      dkms install -m "$PACKAGE_NAME" -v "$PACKAGE_VERSION" -k "$kernel_version"
    else
      dkms build -m "$PACKAGE_NAME" -v "$PACKAGE_VERSION" -k "$kernel_version"
      dkms install -m "$PACKAGE_NAME" -v "$PACKAGE_VERSION" -k "$kernel_version"
    fi
  fi
  modprobe "$PACKAGE_NAME" || echo "Could not load $PACKAGE_NAME; check dmesg for details." >&2
else
  echo "Registered $PACKAGE_NAME with DKMS, but headers for $kernel_version are missing."
  echo "Install matching kernel headers, then run: sudo dkms autoinstall"
fi
