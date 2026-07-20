#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="/usr/local/bin"
GUI_BIN_NAME="excalibur-control-center-gui"
CLI_BIN_NAME="excalibur-control-center-cli"
GITHUB_REPO="mert-kurttutan/cecc-linux"
RELEASE_TAG="latest"
DEPENDENCY_HELP="Install curl, tar, dkms, build tools, kmod, and matching kernel headers manually."
DEPS_UBUNTU=(curl tar dkms build-essential kmod)
DEPS_DEBIAN=(curl tar dkms build-essential kmod)
DEPS_FEDORA=(curl tar dkms gcc make kmod kernel-devel kernel-headers)
DEPS_RHEL=(curl tar dkms gcc make kmod kernel-devel kernel-headers)
DEPS_CENTOS=(curl tar dkms gcc make kmod kernel-devel kernel-headers)
DEPS_ARCH=(curl tar dkms base-devel kmod linux-headers)
DEPS_OPENSUSE=(curl tar dkms gcc make kmod kernel-devel kernel-default-devel)
DEPS_SUSE=(curl tar dkms gcc make kmod kernel-devel kernel-default-devel)

SKIP_DRIVER=0
INSTALL_CLI=1

INSTALLER_PATH="scripts/driver-bash/install-driver-stack.sh"

download_dir=""
source_dir=""
source_parent_dir=""

usage() {
  cat <<EOF
Usage: $0 [--version <tag>] [--no-cli] [--skip-driver]

Installs Excalibur Control Center from GitHub Releases, then installs the
casper-wmi driver and udev permissions from a temporary repo checkout.

Options:
  --version <tag>     Install binaries from a specific GitHub release tag.
  --no-cli            Do not install the CLI binary.
  --skip-driver       Do not install the casper-wmi DKMS driver or udev rules.
  -h, --help          Show this help.

EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --version)
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

has_id() {
  local needle="$1"
  [ "${ID:-}" = "$needle" ] || [[ " ${ID_LIKE:-} " == *" $needle "* ]]
}

detect_distro() {
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
  else
    echo "Cannot detect distro: /etc/os-release is missing"
    echo "$DEPENDENCY_HELP"
    exit 1
  fi

  if has_id ubuntu; then
    printf 'ubuntu\n'
  elif has_id debian; then
    printf 'debian\n'
  elif has_id fedora; then
    printf 'fedora\n'
  elif has_id rhel; then
    printf 'rhel\n'
  elif has_id centos; then
    printf 'centos\n'
  elif has_id arch; then
    printf 'arch\n'
  elif has_id opensuse; then
    printf 'opensuse\n'
  elif has_id suse; then
    printf 'suse\n'
  elif has_id nixos; then
    printf 'nixos\n'
  else
    echo "Unsupported distro: ${PRETTY_NAME:-unknown}"
    echo "$DEPENDENCY_HELP"
    exit 1
  fi
}

install_deps() {
  local distro
  distro="$(detect_distro)"

  echo "Checking/installing dependencies..."

  case "$distro" in
    ubuntu|debian)
      apt-get update
      if [ "$distro" = "ubuntu" ]; then
        apt-get install -y "${DEPS_UBUNTU[@]}" "linux-headers-$(uname -r)"
      else
        apt-get install -y "${DEPS_DEBIAN[@]}" "linux-headers-$(uname -r)"
      fi
      ;;
    fedora)
      dnf install -y "${DEPS_FEDORA[@]}"
      ;;
    rhel)
      dnf install -y "${DEPS_RHEL[@]}"
      ;;
    centos)
      dnf install -y "${DEPS_CENTOS[@]}"
      ;;
    arch)
      pacman -S --needed --noconfirm "${DEPS_ARCH[@]}"
      ;;
    opensuse)
      zypper --non-interactive install "${DEPS_OPENSUSE[@]}"
      ;;
    suse)
      zypper --non-interactive install "${DEPS_SUSE[@]}"
      ;;
    nixos)
      echo "NixOS is not supported by this installer."
      echo "Use the repo dev shell for testing or package the module through NixOS."
      exit 1
      ;;
  esac
}

download_file() {
  local url="$1"
  local output="$2"

  curl -fL "$url" -o "$output"
}

release_asset_url() {
  local asset="$1"

  printf 'https://github.com/%s/releases/download/%s/%s\n' "$GITHUB_REPO" "$RELEASE_TAG" "$asset"
}

source_archive_url() {
  printf 'https://github.com/%s/archive/refs/tags/%s.tar.gz\n' "$GITHUB_REPO" "$RELEASE_TAG"
}

resolve_latest_tag() {
  local response tag

  response="$(curl -fsSL "https://api.github.com/repos/$GITHUB_REPO/releases/latest")" || {
    echo "Could not resolve latest GitHub release tag"
    exit 1
  }
  tag="$(printf '%s\n' "$response" | sed -n 's/^[[:space:]]*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"

  if [ -z "$tag" ]; then
    echo "Could not resolve latest GitHub release tag"
    exit 1
  fi

  printf '%s\n' "$tag"
}

resolve_release_tag() {
  if [ "$RELEASE_TAG" = "latest" ]; then
    echo "Resolving latest GitHub release tag..."
    RELEASE_TAG="$(resolve_latest_tag)"
  fi
}

extract_source_archive() {
  local output_dir="$1"
  local archive="$output_dir/source.tar.gz"
  local archive_url
  archive_url="$(source_archive_url)"

  echo "Downloading source archive for $RELEASE_TAG..."
  echo "$archive_url"
  download_file "$archive_url" "$archive"

  echo "Extracting source archive..."
  tar -xzf "$archive" -C "$output_dir"

  source_dir="$(find "$output_dir" -mindepth 1 -maxdepth 1 -type d -name 'cecc-linux-*' | head -n 1)"
  if [ -z "$source_dir" ]; then
    echo "Could not locate extracted release source directory"
    echo "Checked: $output_dir"
    exit 1
  fi

  if [ ! -x "$source_dir/$INSTALLER_PATH" ]; then
    echo "Could not locate Bash local installer in release source"
    echo "Checked: $source_dir/$INSTALLER_PATH"
    exit 1
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
  install -d -m 0755 "$BIN_DIR"
  install -m 0755 "$gui_source" "$BIN_DIR/$GUI_BIN_NAME"

  if [ "$INSTALL_CLI" = "1" ]; then
    if [ ! -x "$cli_source" ]; then
      echo "CLI binary not found or not executable: $cli_source"
      exit 1
    fi

    install -m 0755 "$cli_source" "$BIN_DIR/$CLI_BIN_NAME"
  fi
}

main() {
  trap 'rm -rf "$download_dir" "$source_parent_dir"' EXIT
  parse_args "$@"

  if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: 'sudo scripts/driver-bash/install-release.sh'"
    exit 1
  fi

  install_deps
  resolve_release_tag

  source_parent_dir="$(mktemp -d)"
  extract_source_archive "$source_parent_dir"

  if [ "$SKIP_DRIVER" = "1" ]; then
    echo "Skipping driver and udev rule installation."
  else
    "$source_dir/$INSTALLER_PATH"
  fi

  download_release_binaries
  install_app_binaries

  echo "Installation complete."
  echo "Run: $BIN_DIR/$GUI_BIN_NAME"
}

main "$@"
