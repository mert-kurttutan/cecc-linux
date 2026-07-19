#!/usr/bin/env nu

use ./install-dkms-driver.nu install-casper-dkms-driver
use ./install-permission-rules.nu install-excalibur-permission-rules

def is-root [] {
  ((^id -u | str trim) == "0")
}

export def install-excalibur-driver-stack [
  --skip-driver
] {
  if (not (is-root)) and (not $skip_driver) {
    error make {
      msg: "Please run as root when installing the driver or udev rules."
      help: "Use sudo nu scripts/driver-nu/install-driver-stack.nu, or pass --skip-driver."
    }
  }

  if $skip_driver {
    print "Skipping driver and udev rule installation."
  } else {
    print "Installing casper-wmi driver..."
    install-casper-dkms-driver

    print "Installing udev rules and permission helper..."
    install-excalibur-permission-rules
  }
}

def main [
  --skip-driver
] {
  install-excalibur-driver-stack --skip-driver=$skip_driver
}
