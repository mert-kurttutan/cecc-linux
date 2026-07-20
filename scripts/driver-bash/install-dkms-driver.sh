#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: 'sudo ./install-dkms-driver.sh'"
  exit 1
fi

DRIVER_NAME="casper-wmi"
DRIVER_VERSION="0.1"
SRC_DIR="/usr/src/$DRIVER_NAME-$DRIVER_VERSION"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
DRIVER_SOURCE_DIR="$REPO_ROOT/casper-wmi"
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
