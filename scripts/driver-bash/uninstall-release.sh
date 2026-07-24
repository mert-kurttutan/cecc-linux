#!/usr/bin/env bash
set -euo pipefail

GUI_BIN_NAME="excalibur-control-center-gui"
CLI_BIN_NAME="excalibur-control-center-cli"
BIN_DIR="/usr/local/bin"
DRIVER_NAME="casper-wmi"
DRIVER_VERSION="0.1"
RULE_NAME="90-excalibur-control-center.rules"
HELPER_NAME="apply-sysfs-permissions"
HELPER_DIR="/usr/local/libexec/excalibur-control-center"
RULE_DIR="/etc/udev/rules.d"
GROUP="excalibur"

KEEP_APP=0
KEEP_DRIVER=0
REMOVE_GROUP=0

usage() {
  cat <<EOF
Usage: $0 [--keep-app] [--keep-driver] [--remove-group]

Uninstalls Excalibur Control Center files installed by install-release.sh.

Options:
  --keep-app         Keep application binaries under $BIN_DIR.
  --keep-driver      Keep the DKMS driver, udev rules, and permission helper.
  --remove-group     Also remove the $GROUP group.
  -h, --help         Show this help.

EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --keep-app)
        KEEP_APP=1
        shift
        ;;
      --keep-driver)
        KEEP_DRIVER=1
        shift
        ;;
      --remove-group)
        REMOVE_GROUP=1
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

remove_file_if_present() {
  local path="$1"

  if [ -e "$path" ]; then
    echo "Removing $path"
    rm -f "$path"
  fi
}

uninstall_casper_dkms_driver() {
  local src_dir="/usr/src/$DRIVER_NAME-$DRIVER_VERSION"

  echo "Unloading $DRIVER_NAME module if loaded..."
  modprobe -r "$DRIVER_NAME" >/dev/null 2>&1 || true

  echo "Removing $DRIVER_NAME DKMS module version $DRIVER_VERSION..."
  dkms remove "$DRIVER_NAME/$DRIVER_VERSION" --all >/dev/null 2>&1 || true

  if [ -e "$src_dir" ]; then
    echo "Removing DKMS source tree: $src_dir"
    rm -rf "$src_dir"
  fi

  echo "Driver uninstall step complete."
}

uninstall_excalibur_permission_rules() {
  local helper_target="$HELPER_DIR/$HELPER_NAME"
  local rule_target="$RULE_DIR/$RULE_NAME"

  remove_file_if_present "$rule_target"
  remove_file_if_present "$helper_target"

  if [ -d "$HELPER_DIR" ]; then
    rmdir "$HELPER_DIR" >/dev/null 2>&1 || true
  fi

  echo "Reloading udev rules..."
  udevadm control --reload-rules >/dev/null 2>&1 || true

  if [ "$REMOVE_GROUP" = "1" ]; then
    echo "Removing group if present: $GROUP"
    groupdel "$GROUP" >/dev/null 2>&1 || true
  else
    echo "Keeping group: $GROUP"
  fi

  echo "Permission-rule uninstall step complete."
}

uninstall_excalibur_driver_stack() {
  echo "Uninstalling casper-wmi driver..."
  uninstall_casper_dkms_driver

  echo "Uninstalling udev rules and permission helper..."
  uninstall_excalibur_permission_rules
}

uninstall_excalibur_release() {
  if [ "$KEEP_DRIVER" = "1" ]; then
    echo "Keeping driver, udev rules, and permission helper."
  else
    uninstall_excalibur_driver_stack
  fi

  if [ "$KEEP_APP" = "1" ]; then
    echo "Keeping application binaries."
  else
    echo "Removing application binaries from $BIN_DIR..."
    remove_file_if_present "$BIN_DIR/$GUI_BIN_NAME"
    remove_file_if_present "$BIN_DIR/$CLI_BIN_NAME"
  fi

  echo "Uninstallation complete."
}

main() {
  parse_args "$@"

  if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: 'sudo scripts/driver-bash/uninstall-release.sh'"
    exit 1
  fi

  uninstall_excalibur_release
}

main "$@"
