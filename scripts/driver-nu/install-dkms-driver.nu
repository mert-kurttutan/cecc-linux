#!/usr/bin/env nu

const DRIVER_NAME = "casper-wmi"
const REQUIRED_FILES = [
  "casper-wmi.c"
  "casper-gpu-mode.c"
  "Makefile"
  "dkms.conf"
]

export def install-casper-dkms-driver [] {
  let repo_root = ($env.FILE_PWD | path join ".." "..")
  let driver_source_dir = ($repo_root | path join "casper-wmi")
  let dkms_conf = ($driver_source_dir | path join "dkms.conf")
  let version_line = (open --raw $dkms_conf | lines | where ($it | str starts-with 'PACKAGE_VERSION='))
  if ($version_line | length) != 1 {
    error make { msg: $"Expected one PACKAGE_VERSION in ($dkms_conf)" }
  }
  let driver_version = ($version_line | first | parse 'PACKAGE_VERSION="{version}"' | get version | first)
  if ($driver_version | is-empty) {
    error make { msg: $"PACKAGE_VERSION is empty in ($dkms_conf)" }
  }
  let src_dir = $"/usr/src/($DRIVER_NAME)-($driver_version)"

  print $"Installing ($DRIVER_NAME) driver version ($driver_version)..."

  do -i { ^dkms remove $"($DRIVER_NAME)/($driver_version)" --all }
  ^rm -rf $src_dir

  mkdir $src_dir

  for file in $REQUIRED_FILES {
    ^cp ($driver_source_dir | path join $file) $src_dir
  }

  print "Adding to DKMS..."
  ^dkms add -m $DRIVER_NAME -v $driver_version

  print "Building module..."
  ^dkms build -m $DRIVER_NAME -v $driver_version

  print "Installing module..."
  ^dkms install -m $DRIVER_NAME -v $driver_version

  print "Loading module..."
  ^modprobe $DRIVER_NAME

  print "NOTICE: Check dmesg for any errors: 'dmesg | grep casper'"
}

def main [] {
  install-casper-dkms-driver
}
