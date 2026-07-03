#!/usr/bin/env bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root: 'sudo ./install.sh'"
  exit 1
fi

DRIVER_NAME="casper-wmi"
DRIVER_VERSION="0.1"
SRC_DIR="/usr/src/$DRIVER_NAME-$DRIVER_VERSION"
REQUIRED_FILES=(
  "casper-wmi.c"
  "casper-gpu-mode.c"
  "Makefile"
  "dkms.conf"
)

has_id() {
  local needle="$1"
  [ "${ID:-}" = "$needle" ] || [[ " ${ID_LIKE:-} " == *" $needle "* ]]
}

install_deps() {
  if [ "${CASPER_WMI_SKIP_DEPS:-0}" = "1" ]; then
    echo "Skipping dependency installation because CASPER_WMI_SKIP_DEPS=1"
    return
  fi

  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
  else
    echo "Cannot detect distro: /etc/os-release is missing"
    echo "Install dkms, build tools, kmod, and matching kernel headers manually."
    return
  fi

  echo "Checking/installing build dependencies for ${PRETTY_NAME:-Linux}..."

  if has_id nixos; then
    echo "NixOS is not supported by this installer."
    echo "Use the repo dev shell for testing or package the module through NixOS."
    exit 1
  elif has_id debian || has_id ubuntu; then
    apt-get update
    apt-get install -y dkms build-essential kmod "linux-headers-$(uname -r)"
  elif has_id fedora; then
    dnf install -y dkms gcc make kmod kernel-devel kernel-headers
  elif has_id rhel || has_id centos; then
    dnf install -y dkms gcc make kmod kernel-devel kernel-headers
  elif has_id arch; then
    pacman -S --needed --noconfirm dkms base-devel kmod linux-headers
  elif has_id opensuse || has_id suse; then
    zypper --non-interactive install dkms gcc make kmod kernel-devel kernel-default-devel
  else
    echo "Unsupported distro: ${PRETTY_NAME:-unknown}"
    echo "Install dkms, build tools, kmod, and matching kernel headers manually,"
    echo "then rerun with CASPER_WMI_SKIP_DEPS=1."
    exit 1
  fi
}

echo "Installing $DRIVER_NAME driver version $DRIVER_VERSION..."
install_deps

# clean up previous
dkms remove "$DRIVER_NAME/$DRIVER_VERSION" --all >/dev/null 2>&1 || true
rm -rf "$SRC_DIR"

mkdir -p "$SRC_DIR" # copies files to /usr/src/
cp "${REQUIRED_FILES[@]}" "$SRC_DIR/"

echo "Adding to DKMS..."
dkms add -m "$DRIVER_NAME" -v "$DRIVER_VERSION"

echo "Building module..."
dkms build -m "$DRIVER_NAME" -v "$DRIVER_VERSION"

echo "Installing module..."
dkms install -m "$DRIVER_NAME" -v "$DRIVER_VERSION"

echo "Loading module..."
modprobe "$DRIVER_NAME"

echo "NOTICE: Check dmesg for any errors: 'dmesg | grep casper'"
