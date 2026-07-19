#!/usr/bin/env nu

const DRIVER_NAME = "casper-wmi"
const DRIVER_VERSION = "0.1"
const REQUIRED_FILES = [
  "casper-wmi.c"
  "casper-gpu-mode.c"
  "Makefile"
  "dkms.conf"
]

def is-root [] {
  ((^id -u | str trim) == "0")
}

def parse-os-release [] {
  if not ("/etc/os-release" | path exists) {
    return {}
  }

  open --raw /etc/os-release
  | lines
  | where {|line| ($line | str trim) != "" and not ($line | str starts-with "#") }
  | parse --regex '^(?P<key>[A-Za-z0-9_]+)=(?P<value>.*)$'
  | update value {|row|
      $row.value
      | str trim
      | str replace --regex '^"' ''
      | str replace --regex '"$' ''
    }
  | reduce --fold {} {|row, acc| $acc | insert $row.key $row.value }
}

def has-id [os: record, needle: string] {
  let id = ($os.ID? | default "")
  let id_like = ($os.ID_LIKE? | default "")

  ($id == $needle) or (($id_like | split row " ") | any {|entry| $entry == $needle })
}

def install-deps [] {
  let os = (parse-os-release)

  if ($os | is-empty) {
    print "Cannot detect distro: /etc/os-release is missing"
    print "Install dkms, build tools, kmod, and matching kernel headers manually."
    return
  }

  let pretty_name = ($os.PRETTY_NAME? | default "Linux")
  print $"Checking/installing build dependencies for ($pretty_name)..."

  if (has-id $os "nixos") {
    print "NixOS is not supported by this installer."
    print "Use the repo dev shell for testing or package the module through NixOS."
    exit 1
  } else if (has-id $os "debian") or (has-id $os "ubuntu") {
    let kernel = (^uname -r | str trim)
    ^apt-get update
    ^apt-get install -y dkms build-essential kmod $"linux-headers-($kernel)"
  } else if (has-id $os "fedora") {
    ^dnf install -y dkms gcc make kmod kernel-devel kernel-headers
  } else if (has-id $os "rhel") or (has-id $os "centos") {
    ^dnf install -y dkms gcc make kmod kernel-devel kernel-headers
  } else if (has-id $os "arch") {
    ^pacman -S --needed --noconfirm dkms base-devel kmod linux-headers
  } else if (has-id $os "opensuse") or (has-id $os "suse") {
    ^zypper --non-interactive install dkms gcc make kmod kernel-devel kernel-default-devel
  } else {
    print $"Unsupported distro: ($pretty_name)"
    print "Install dkms, build tools, kmod, and matching kernel headers manually."
    exit 1
  }
}

export def install-casper-driver [
  --driver-source-dir: string = ""
] {
  if not (is-root) {
    error make {
      msg: "Please run as root: 'sudo ./install.nu'"
    }
  }

  let script_dir = ($env.FILE_PWD? | default (pwd))
  let repo_root = ($script_dir | path join ".." ".." | path expand)
  let driver_source_dir = if $driver_source_dir != "" { $driver_source_dir } else { ($repo_root | path join "casper-wmi") }
  let src_dir = $"/usr/src/($DRIVER_NAME)-($DRIVER_VERSION)"

  print $"Installing ($DRIVER_NAME) driver version ($DRIVER_VERSION)..."
  install-deps

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
  install-casper-driver
}
