#!/bin/bash

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: 'sudo ./install.sh'"
  exit 1
fi

DRIVER_NAME="casper-wmi"
DRIVER_VERSION="0.1"
SRC_DIR="/usr/src/$DRIVER_NAME-$DRIVER_VERSION"

echo "Installing $DRIVER_NAME driver version $DRIVER_VERSION..."

# clean up previous
dkms remove "$DRIVER_NAME/$DRIVER_VERSION" --all >/dev/null 2>&1
rm -rf "$SRC_DIR"

mkdir -p "$SRC_DIR" # copies files to /usr/src/
cp casper-wmi.c Makefile dkms.conf "$SRC_DIR/"

echo "Adding to DKMS..."
dkms add -m "$DRIVER_NAME" -v "$DRIVER_VERSION"

echo "Building module..."
dkms build -m "$DRIVER_NAME" -v "$DRIVER_VERSION"

echo "Installing module..."
dkms install -m "$DRIVER_NAME" -v "$DRIVER_VERSION"

echo "Loading module..."
modprobe "$DRIVER_NAME"

echo "NOTICE: Check dmesg for any errors: 'dmesg | grep casper'"

