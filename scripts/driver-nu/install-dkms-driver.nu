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

def detect-distro [os: record] {
  if ($os | is-empty) {
    error make {
      msg: "Cannot detect distro: /etc/os-release is missing"
      help: "Install dkms, build tools, kmod, and matching kernel headers manually."
    }
  }

  let id = ($os.ID? | default "")
  let id_like = ($os.ID_LIKE? | default "")
  let candidates = [ubuntu debian fedora arch rhel centos opensuse suse nixos]

  for distro in $candidates {
    if $id == $distro {
      return $distro
    }
  }

  for distro in $candidates {
    if (($id_like | split row " ") | any {|entry| $entry == $distro }) {
      return $distro
    }
  }

  error make {
    msg: $"Unsupported distro: (($os.PRETTY_NAME? | default "unknown"))"
    help: "Install dkms, build tools, kmod, and matching kernel headers manually."
  }
}

def install-deps [] {
  let os = (parse-os-release)
  let distro = (detect-distro $os)
  let pretty_name = ($os.PRETTY_NAME? | default "Linux")

  print $"Checking/installing build dependencies for ($pretty_name)..."

  match $distro {
    "ubuntu" | "debian" => {
      let kernel = (^uname -r | str trim)
      ^apt-get update
      ^apt-get install -y dkms build-essential kmod $"linux-headers-($kernel)"
    }
    "fedora" | "rhel" | "centos" => {
      ^dnf install -y dkms gcc make kmod kernel-devel kernel-headers
    }
    "arch" => {
      ^pacman -S --needed --noconfirm dkms base-devel kmod linux-headers
    }
    "opensuse" | "suse" => {
      ^zypper --non-interactive install dkms gcc make kmod kernel-devel kernel-default-devel
    }
    "nixos" => {
      error make {
        msg: "NixOS is not supported by this installer."
        help: "Use the repo dev shell for testing or package the module through NixOS."
      }
    }
  }
}

export def install-casper-dkms-driver [] {
  if not (is-root) {
    error make {
      msg: "Please run as root: 'sudo ./install-dkms-driver.nu'"
    }
  }

  let repo_root = ($env.FILE_PWD | path join ".." "..")
  let driver_source_dir = ($repo_root | path join "casper-wmi")
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
  install-casper-dkms-driver
}
