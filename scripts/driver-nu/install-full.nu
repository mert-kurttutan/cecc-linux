#!/usr/bin/env nu

use ./install.nu install-casper-driver
use ./install-udev-rules.nu install-excalibur-udev-rules

def is-root [] {
  ((^id -u | str trim) == "0")
}

export def install-excalibur-full [
  --skip-driver
  --skip-udev
] {
  let script_dir = ($env.FILE_PWD? | default (pwd))
  let repo_root = ($script_dir | path join ".." ".." | path expand)
  let driver_source_dir = ($repo_root | path join "casper-wmi")
  let rule_source = ($driver_source_dir | path join "90-excalibur-control-center.rules")
  let helper_source = ($script_dir | path join "udev-permissions.nu")

  if (not (is-root)) and (not ($skip_driver and $skip_udev)) {
    error make {
      msg: "Please run as root when installing the driver or udev rules."
      help: "Use sudo nu scripts/driver-nu/install-full.nu, or pass --skip-driver --skip-udev."
    }
  }

  if $skip_driver {
    print "Skipping driver installation."
  } else {
    print "Installing casper-wmi driver..."
    install-casper-driver --driver-source-dir $driver_source_dir
  }

  if $skip_udev {
    print "Skipping udev rule installation."
  } else {
    print "Installing udev rules and permission helper..."
    install-excalibur-udev-rules --rule-source $rule_source --helper-source $helper_source
  }
}

def main [
  --skip-driver
  --skip-udev
] {
  install-excalibur-full --skip-driver=$skip_driver --skip-udev=$skip_udev
}
