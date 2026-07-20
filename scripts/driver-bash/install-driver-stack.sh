#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0

Installs the local casper-wmi DKMS driver and udev permission rules.

Options:
  -h, --help          Show this help.
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
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

main() {
  parse_args "$@"

  if [ "$EUID" -ne 0 ]; then
    echo "Please run as root when installing the driver or udev rules."
    echo "Use sudo scripts/driver-bash/install-driver-stack.sh."
    exit 1
  fi

  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

  echo "Installing casper-wmi driver..."
  "$script_dir/install-dkms-driver.sh"

  echo "Installing udev rules and permission helper..."
  "$script_dir/install-permission-rules.sh"
}

main "$@"
