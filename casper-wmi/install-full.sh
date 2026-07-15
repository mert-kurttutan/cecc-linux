#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${CECC_REPO_URL:-https://github.com/mert-kurttutan/cecc-linux.git}"
REPO_REF="${CECC_REPO_REF:-main}"
DRIVER_DIR="casper-wmi"

need_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

run_installer() {
  if [ "$EUID" -eq 0 ]; then
    ./install.sh
  else
    need_command sudo
    sudo ./install.sh
  fi
}

need_command git

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

echo "Cloning cecc-linux from ${REPO_URL}..."
git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$tmp_dir/cecc-linux"

cd "$tmp_dir/cecc-linux/$DRIVER_DIR"

echo "Installing casper-wmi from temporary checkout..."
run_installer

echo "Done."
