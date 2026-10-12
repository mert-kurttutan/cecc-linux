#!/usr/bin/env bash
set -euo pipefail

# Keep the DKMS module during package upgrades. The updated package's postinst
# will register or reuse its configured version after unpacking.
case "${1:-}" in
  upgrade|failed-upgrade|abort-upgrade)
    exit 0
    ;;
esac

DRIVER_NAME="casper-wmi"
modprobe -r "$DRIVER_NAME" >/dev/null 2>&1 || true

mapfile -t DRIVER_VERSIONS < <(
  dkms status -m "$DRIVER_NAME" 2>/dev/null \
    | awk -F/ -v name="$DRIVER_NAME" '$1 == name { split($2, v, /[, :]/); print v[1] }' \
    | sort -u
)
for driver_version in "${DRIVER_VERSIONS[@]}"; do
  [ -n "$driver_version" ] || continue
  dkms remove "$DRIVER_NAME/$driver_version" --all >/dev/null 2>&1 || true
done
