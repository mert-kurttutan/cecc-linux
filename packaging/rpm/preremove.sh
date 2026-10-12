#!/usr/bin/env bash
set -euo pipefail

# RPM passes the number of package instances that remain after the operation.
# Keep DKMS registered during upgrades; remove it only for a final erase.
if [ "${1:-0}" -ne 0 ]; then
  exit 0
fi

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
