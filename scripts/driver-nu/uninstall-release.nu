#!/usr/bin/env nu

const GUI_BIN_NAME = "excalibur-control-center-gui"
const CLI_BIN_NAME = "excalibur-control-center-cli"
const BIN_DIR = "/usr/local/bin"
const DRIVER_NAME = "casper-wmi"
const RULE_NAME = "90-excalibur-control-center.rules"
const HELPER_NAME = "apply-sysfs-permissions"
const HELPER_DIR = "/usr/local/libexec/excalibur-control-center"
const RULE_DIR = "/etc/udev/rules.d"
const GROUP = "excalibur"

def is-root [] {
  ((^id -u | str trim) == "0")
}

def remove-file-if-present [path: string] {
  if ($path | path exists) {
    print $"Removing ($path)"
    ^rm -f $path
  }
}

def uninstall-casper-dkms-driver [] {
  print $"Unloading ($DRIVER_NAME) module if loaded..."
  do -i { ^modprobe -r $DRIVER_NAME }

  let dkms_configs = (glob $"/usr/src/($DRIVER_NAME)-*/dkms.conf")
  if ($dkms_configs | is-empty) {
    print $"No ($DRIVER_NAME) DKMS source installation found."
  }
  for dkms_conf in $dkms_configs {
    let version_line = (open --raw $dkms_conf | lines | where ($it | str starts-with 'PACKAGE_VERSION='))
    if ($version_line | length) != 1 {
      error make { msg: $"Expected one PACKAGE_VERSION in ($dkms_conf)" }
    }
    let driver_version = ($version_line | first | parse 'PACKAGE_VERSION="{version}"' | get version | first)
    if ($driver_version | is-empty) {
      error make { msg: $"PACKAGE_VERSION is empty in ($dkms_conf)" }
    }
    let src_dir = ($dkms_conf | path dirname)
    print $"Removing ($DRIVER_NAME) DKMS module version ($driver_version)..."
    do -i { ^dkms remove $"($DRIVER_NAME)/($driver_version)" --all }
    print $"Removing DKMS source tree: ($src_dir)"
    ^rm -rf $src_dir
  }

  print "Driver uninstall step complete."
}

def uninstall-excalibur-permission-rules [
  --remove-group
] {
  let helper_target = ($HELPER_DIR | path join $HELPER_NAME)
  let rule_target = ($RULE_DIR | path join $RULE_NAME)

  remove-file-if-present $rule_target
  remove-file-if-present $helper_target

  if ($HELPER_DIR | path exists) {
    do -i { ^rmdir $HELPER_DIR }
  }

  print "Reloading udev rules..."
  do -i { ^udevadm control --reload-rules }

  if $remove_group {
    print $"Removing group if present: ($GROUP)"
    do -i { ^groupdel $GROUP }
  } else {
    print $"Keeping group: ($GROUP)"
  }

  print "Permission-rule uninstall step complete."
}

def uninstall-excalibur-driver-stack [
  --remove-group
] {
  print "Uninstalling casper-wmi driver..."
  uninstall-casper-dkms-driver

  print "Uninstalling udev rules and permission helper..."
  uninstall-excalibur-permission-rules --remove-group=$remove_group
}

export def uninstall-excalibur-release [
  --keep-app
  --keep-driver
  --remove-group
] {
  if not $keep_driver {
    uninstall-excalibur-driver-stack --remove-group=$remove_group
  } else {
    print "Keeping driver, udev rules, and permission helper."
  }

  if not $keep_app {
    print $"Removing application binaries from ($BIN_DIR)..."
    remove-file-if-present ($BIN_DIR | path join $GUI_BIN_NAME)
    remove-file-if-present ($BIN_DIR | path join $CLI_BIN_NAME)
  } else {
    print "Keeping application binaries."
  }

  print "Uninstallation complete."
}

def main [
  --keep-app
  --keep-driver
  --remove-group
] {
  if not (is-root) {
    error make {
      msg: "Please run as root: 'sudo nu scripts/driver-nu/uninstall-release.nu'"
    }
  }

  uninstall-excalibur-release --keep-app=$keep_app --keep-driver=$keep_driver --remove-group=$remove_group
}
