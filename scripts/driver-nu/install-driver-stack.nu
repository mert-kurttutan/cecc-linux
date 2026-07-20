#!/usr/bin/env nu

use ./install-dkms-driver.nu install-casper-dkms-driver
use ./install-permission-rules.nu install-excalibur-permission-rules

export def install-excalibur-driver-stack [] {
  print "Installing casper-wmi driver..."
  install-casper-dkms-driver

  print "Installing udev rules and permission helper..."
  install-excalibur-permission-rules
}

def main [] {
  install-excalibur-driver-stack
}
