#!/usr/bin/env bash
set -euo pipefail

SKIP_DRIVER="${EXCALIBUR_SKIP_DRIVER:-0}"
SKIP_UDEV="${EXCALIBUR_SKIP_UDEV:-0}"

usage() {
  cat <<EOF
Usage: $0 [--skip-driver] [--skip-udev]

Installs the local casper-wmi DKMS driver and udev permission rules.

Options:
  --skip-driver       Do not install the casper-wmi DKMS driver.
  --skip-udev         Do not install udev rules and permission helper.
  -h, --help          Show this help.
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --skip-driver)
        SKIP_DRIVER=1
        shift
        ;;
      --skip-udev)
        SKIP_UDEV=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
  done
}

need_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

sudo_cmd() {
  if [ "$EUID" -eq 0 ]; then
    "$@"
  else
    need_command sudo
    sudo "$@"
  fi
}

main() {
  parse_args "$@"

  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

  if [ "$SKIP_DRIVER" = "1" ]; then
    echo "Skipping driver installation."
  else
    echo "Installing casper-wmi driver..."
    sudo_cmd "$script_dir/install.sh"
  fi

  if [ "$SKIP_UDEV" = "1" ]; then
    echo "Skipping udev rule installation."
  else
    echo "Installing udev rules and permission helper..."
    sudo_cmd "$script_dir/install-udev-rules.sh"
  fi
}

main "$@"
