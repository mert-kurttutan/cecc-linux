#!/usr/bin/env nu

use ./install.nu install-casper-driver
use ./install-udev-rules.nu install-excalibur-udev-rules

def is-root [] {
  ((^id -u | str trim) == "0")
}

export def install-excalibur-full [
  --skip-driver
] {
  if (not (is-root)) and (not $skip_driver) {
    error make {
      msg: "Please run as root when installing the driver or udev rules."
      help: "Use sudo nu scripts/driver-nu/install-full.nu, or pass --skip-driver."
    }
  }

  if $skip_driver {
    print "Skipping driver and udev rule installation."
  } else {
    print "Installing casper-wmi driver..."
    install-casper-driver

    print "Installing udev rules and permission helper..."
    install-excalibur-udev-rules
  }
}

def main [
  --skip-driver
] {
  install-excalibur-full --skip-driver=$skip_driver
}
