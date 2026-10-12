#!/usr/bin/env bash
set -euo pipefail

DRIVER_NAME="casper-wmi"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
DRIVER_SOURCE_DIR="$REPO_ROOT/casper-wmi"
mapfile -t DRIVER_VERSIONS < <(sed -n 's/^PACKAGE_VERSION="\([^"]\+\)"$/\1/p' "$DRIVER_SOURCE_DIR/dkms.conf")
if [ "${#DRIVER_VERSIONS[@]}" -ne 1 ]; then
  echo "Expected one PACKAGE_VERSION in $DRIVER_SOURCE_DIR/dkms.conf" >&2
  exit 1
fi
DRIVER_VERSION="${DRIVER_VERSIONS[0]}"
SRC_DIR="/usr/src/$DRIVER_NAME-$DRIVER_VERSION"
REQUIRED_FILES=(
  "casper-wmi.c"
  "casper-gpu-mode.c"
  "Makefile"
  "dkms.conf"
)

echo "Installing $DRIVER_NAME driver version $DRIVER_VERSION..."

# clean up previous
dkms remove "$DRIVER_NAME/$DRIVER_VERSION" --all >/dev/null 2>&1 || true
rm -rf "$SRC_DIR"

mkdir -p "$SRC_DIR" # copies files to /usr/src/
for file in "${REQUIRED_FILES[@]}"; do
  cp "$DRIVER_SOURCE_DIR/$file" "$SRC_DIR/"
done

echo "Adding to DKMS..."
dkms add -m "$DRIVER_NAME" -v "$DRIVER_VERSION"

echo "Building module..."
dkms build -m "$DRIVER_NAME" -v "$DRIVER_VERSION"

echo "Installing module..."
dkms install -m "$DRIVER_NAME" -v "$DRIVER_VERSION"

echo "Loading module..."
modprobe "$DRIVER_NAME"

echo "NOTICE: Check dmesg for any errors: 'dmesg | grep casper'"
