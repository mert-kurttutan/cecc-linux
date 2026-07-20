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

main() {
  parse_args "$@"

  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

  echo "Installing casper-wmi driver..."
  "$script_dir/install-dkms-driver.sh"

  echo "Installing udev rules and permission helper..."
  "$script_dir/install-permission-rules.sh"
}

main "$@"
