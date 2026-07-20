#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="/usr/local/bin"
GUI_BIN_NAME="excalibur-control-center-gui"
CLI_BIN_NAME="excalibur-control-center-cli"
GITHUB_REPO="mert-kurttutan/cecc-linux"
RELEASE_TAG="latest"

SKIP_DRIVER=0
INSTALL_CLI=1

INSTALLER_PATH="scripts/driver-bash/install-driver-stack.sh"

download_dir=""
repo_checkout_dir=""

usage() {
  cat <<EOF
Usage: $0 [--version <tag>] [--tag <tag>] [--no-cli] [--skip-driver]

Installs Excalibur Control Center from GitHub Releases, then installs the
casper-wmi driver and udev permissions from a temporary repo checkout.

Options:
  --version <tag>     Install binaries from a specific GitHub release tag.
  --tag <tag>         Alias for --version.
  --no-cli            Do not install the CLI binary.
  --skip-driver       Do not install the casper-wmi DKMS driver or udev rules.
  -h, --help          Show this help.

EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --version|--tag)
        if [ "$#" -lt 2 ]; then
          echo "Missing value for $1"
          exit 1
        fi
        RELEASE_TAG="$2"
        shift 2
        ;;
      --no-cli)
        INSTALL_CLI=0
        shift
        ;;
      --skip-driver)
        SKIP_DRIVER=1
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

download_file() {
  local url="$1"
  local output="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fL "$url" -o "$output"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$output" "$url"
  else
    echo "Missing downloader: install curl or wget"
    exit 1
  fi
}

release_asset_url() {
  local asset="$1"

  if [ "$RELEASE_TAG" = "latest" ]; then
    printf 'https://github.com/%s/releases/latest/download/%s\n' "$GITHUB_REPO" "$asset"
  else
    printf 'https://github.com/%s/releases/download/%s/%s\n' "$GITHUB_REPO" "$RELEASE_TAG" "$asset"
  fi
}

clone_ref() {
  if [ "$RELEASE_TAG" = "latest" ]; then
    printf 'main\n'
  else
    printf '%s\n' "$RELEASE_TAG"
  fi
}

prepare_repo_checkout() {
  need_command git

  local ref
  ref="$(clone_ref)"

  repo_checkout_dir="$(mktemp -d)"

  echo "Cloning $GITHUB_REPO for local installer files..."
  if ! git clone --depth 1 --branch "$ref" "https://github.com/$GITHUB_REPO.git" "$repo_checkout_dir/cecc-linux"; then
    if [ "$RELEASE_TAG" != "latest" ]; then
      echo "Could not clone ref '$ref'. Falling back to main."
      git clone --depth 1 --branch main "https://github.com/$GITHUB_REPO.git" "$repo_checkout_dir/cecc-linux"
    else
      exit 1
    fi
  fi

  if [ ! -x "$repo_checkout_dir/cecc-linux/$INSTALLER_PATH" ]; then
    echo "Could not locate Bash local installer in cloned release source"
    echo "Checked: $repo_checkout_dir/cecc-linux/$INSTALLER_PATH"
    exit 1
  fi
}

run_local_installer() {
  local installer="$repo_checkout_dir/cecc-linux/$INSTALLER_PATH"

  if [ "$SKIP_DRIVER" = "1" ]; then
    echo "Skipping driver and udev rule installation."
  else
    sudo_cmd "$installer"
  fi
}

download_release_binaries() {
  download_dir="$(mktemp -d)"

  local gui_url
  gui_url="$(release_asset_url "$GUI_BIN_NAME")"

  echo "Downloading GUI binary from GitHub Releases..."
  echo "$gui_url"
  download_file "$gui_url" "$download_dir/$GUI_BIN_NAME"
  chmod 0755 "$download_dir/$GUI_BIN_NAME"

  if [ "$INSTALL_CLI" = "1" ]; then
    local cli_url
    cli_url="$(release_asset_url "$CLI_BIN_NAME")"

    echo "Downloading CLI binary from GitHub Releases..."
    echo "$cli_url"
    download_file "$cli_url" "$download_dir/$CLI_BIN_NAME"
    chmod 0755 "$download_dir/$CLI_BIN_NAME"
  fi
}

install_app_binaries() {
  local gui_source="$download_dir/$GUI_BIN_NAME"
  local cli_source="$download_dir/$CLI_BIN_NAME"

  if [ ! -x "$gui_source" ]; then
    echo "GUI binary not found or not executable: $gui_source"
    exit 1
  fi

  echo "Installing application binaries into $BIN_DIR..."
  sudo_cmd install -d -m 0755 "$BIN_DIR"
  sudo_cmd install -m 0755 "$gui_source" "$BIN_DIR/$GUI_BIN_NAME"

  if [ "$INSTALL_CLI" = "1" ]; then
    if [ ! -x "$cli_source" ]; then
      echo "CLI binary not found or not executable: $cli_source"
      exit 1
    fi

    sudo_cmd install -m 0755 "$cli_source" "$BIN_DIR/$CLI_BIN_NAME"
  fi
}

main() {
  trap 'rm -rf "$download_dir" "$repo_checkout_dir"' EXIT
  parse_args "$@"
  prepare_repo_checkout
  run_local_installer
  download_release_binaries
  install_app_binaries

  echo "Installation complete."
  echo "Run: $BIN_DIR/$GUI_BIN_NAME"
}

main "$@"
