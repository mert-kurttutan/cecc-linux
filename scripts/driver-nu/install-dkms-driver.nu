#!/usr/bin/env nu

const DRIVER_NAME = "casper-wmi"
const DRIVER_VERSION = "0.1"
const REQUIRED_FILES = [
  "casper-wmi.c"
  "casper-gpu-mode.c"
  "Makefile"
  "dkms.conf"
]

export def install-casper-dkms-driver [] {
  let repo_root = ($env.FILE_PWD | path join ".." "..")
  let driver_source_dir = ($repo_root | path join "casper-wmi")
  let src_dir = $"/usr/src/($DRIVER_NAME)-($DRIVER_VERSION)"

  print $"Installing ($DRIVER_NAME) driver version ($DRIVER_VERSION)..."

  do -i { ^dkms remove $"($DRIVER_NAME)/($DRIVER_VERSION)" --all }
  ^rm -rf $src_dir

  mkdir $src_dir

  for file in $REQUIRED_FILES {
    ^cp ($driver_source_dir | path join $file) $src_dir
  }

  print "Adding to DKMS..."
  ^dkms add -m $DRIVER_NAME -v $DRIVER_VERSION

  print "Building module..."
  ^dkms build -m $DRIVER_NAME -v $DRIVER_VERSION

  print "Installing module..."
  ^dkms install -m $DRIVER_NAME -v $DRIVER_VERSION

  print "Loading module..."
  ^modprobe $DRIVER_NAME

  print "NOTICE: Check dmesg for any errors: 'dmesg | grep casper'"
}

def main [] {
  install-casper-dkms-driver
}
