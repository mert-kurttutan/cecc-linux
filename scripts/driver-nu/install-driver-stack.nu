#!/usr/bin/env nu

use ./install-dkms-driver.nu install-casper-dkms-driver
use ./install-permission-rules.nu install-excalibur-permission-rules

def is-root [] {
  ((^id -u | str trim) == "0")
}

export def install-excalibur-driver-stack [
] {
  if not (is-root) {
    error make {
      msg: "Please run as root when installing the driver or udev rules."
      help: "Use sudo nu scripts/driver-nu/install-driver-stack.nu."
    }
  }

  print "Installing casper-wmi driver..."
  install-casper-dkms-driver

  print "Installing udev rules and permission helper..."
  install-excalibur-permission-rules
}

def main [
] {
  install-excalibur-driver-stack
}
