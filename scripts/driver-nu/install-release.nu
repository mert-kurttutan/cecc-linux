#!/usr/bin/env nu

const INSTALLER_PATH = "scripts/driver-nu/install-driver-stack.nu"
const GUI_BIN_NAME = "excalibur-control-center-gui"
const CLI_BIN_NAME = "excalibur-control-center-cli"
const GITHUB_REPO = "mert-kurttutan/cecc-linux"
const BIN_DIR = "/usr/local/bin"
const DEPENDENCIES = {
  ubuntu: [curl tar dkms build-essential kmod]
  debian: [curl tar dkms build-essential kmod]
  fedora: [curl tar dkms gcc make kmod kernel-devel kernel-headers]
  rhel: [curl tar dkms gcc make kmod kernel-devel kernel-headers]
  centos: [curl tar dkms gcc make kmod kernel-devel kernel-headers]
  arch: [curl tar dkms base-devel kmod linux-headers]
  opensuse: [curl tar dkms gcc make kmod kernel-devel kernel-default-devel]
  suse: [curl tar dkms gcc make kmod kernel-devel kernel-default-devel]
}

def is-root [] {
  ((^id -u | str trim) == "0")
}

def run-root [command: list<string>] {
  if (is-root) {
    ^($command.0) ...($command | skip 1)
  } else {
    ^sudo ...$command
  }
}

export def parse-os-release [] {
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

export def detect-distro [
  os: record
  manual_help: string = "Install curl and tar manually."
] {
  if ($os | is-empty) {
    error make {
      msg: "Cannot detect distro: /etc/os-release is missing"
      help: $manual_help
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
    help: $manual_help
  }
}

def install-deps [] {
  let os = (parse-os-release)
  let distro = (detect-distro $os)
  let pretty_name = ($os.PRETTY_NAME? | default "Linux")

  print $"Checking/installing dependencies for ($pretty_name)..."

  match $distro {
    "ubuntu" | "debian" => {
      run-root [apt-get update]
      let packages = (($DEPENDENCIES | get $distro) | append $"linux-headers-(^uname -r | str trim)")
      run-root ([apt-get install -y] | append $packages)
    }
    "fedora" | "rhel" | "centos" => {
      run-root ([dnf install -y] | append ($DEPENDENCIES | get $distro))
    }
    "arch" => {
      run-root ([pacman -S --needed --noconfirm] | append ($DEPENDENCIES | get $distro))
    }
    "opensuse" | "suse" => {
      run-root ([zypper --non-interactive install] | append ($DEPENDENCIES | get $distro))
    }
    "nixos" => {
      error make {
        msg: "NixOS is not supported by this installer."
        help: "Use the repo dev shell for testing or package the module through NixOS."
      }
    }
  }
}

def release-asset-url [release_tag: string, asset: string] {
  $"https://github.com/($GITHUB_REPO)/releases/download/($release_tag)/($asset)"
}

def source-archive-url [release_tag: string] {
  $"https://github.com/($GITHUB_REPO)/archive/refs/tags/($release_tag).tar.gz"
}

def download-file [url: string, output: string] {
  ^curl -fL $url -o $output
}

def resolve-latest-tag [] {
  let url = $"https://api.github.com/repos/($GITHUB_REPO)/releases/latest"
  let response = (^curl -fsSL $url | complete)

  if $response.exit_code != 0 {
    error make {
      msg: "Could not resolve latest GitHub release tag"
      help: ($response.stderr | str trim)
    }
  }

  let release = ($response.stdout | from json)
  let tag = ($release.tag_name? | default "")

  if $tag == "" {
    error make {
      msg: "Could not resolve latest GitHub release tag"
    }
  }

  $tag
}

def resolve-release-tag [version: string] {
  if $version != "" {
    return $version
  }

  print "Resolving latest GitHub release tag..."
  resolve-latest-tag
}

def extract-source-archive [
  release_tag: string
  output_dir: string
] {
  let archive = ($output_dir | path join "source.tar.gz")
  let archive_url = (source-archive-url $release_tag)

  print $"Downloading source archive for ($release_tag)..."
  print $archive_url
  download-file $archive_url $archive

  print "Extracting source archive..."
  ^tar -xzf $archive -C $output_dir

  let extracted = (
    ls $output_dir
    | where {|entry| $entry.type == dir and ($entry.name | path basename | str starts-with "cecc-linux-") }
    | get name
  )

  if ($extracted | is-empty) {
    error make {
      msg: "Could not locate extracted release source directory"
      help: $"Checked ($output_dir)"
    }
  }

  $extracted.0
}

def install-dir [bin_dir: string] {
  if (is-root) {
    ^install -d -m 0755 $bin_dir
  } else {
    ^sudo install -d -m 0755 $bin_dir
  }
}

def install-file [source: string, target: string] {
  if (is-root) {
    ^install -m 0755 $source $target
  } else {
    ^sudo install -m 0755 $source $target
  }
}

def download-release-binaries [
  release_tag: string
  install_cli: bool
  download_dir: string
] {
  let gui_url = (release-asset-url $release_tag $GUI_BIN_NAME)
  let gui_output = ($download_dir | path join $GUI_BIN_NAME)

  print "Downloading GUI binary from GitHub Releases..."
  print $gui_url
  download-file $gui_url $gui_output
  ^chmod 0755 $gui_output

  if $install_cli {
    let cli_url = (release-asset-url $release_tag $CLI_BIN_NAME)
    let cli_output = ($download_dir | path join $CLI_BIN_NAME)

    print "Downloading CLI binary from GitHub Releases..."
    print $cli_url
    download-file $cli_url $cli_output
    ^chmod 0755 $cli_output
  }
}

def install-app-binaries [download_dir: string, bin_dir: string, install_cli: bool] {
  let gui_source = ($download_dir | path join $GUI_BIN_NAME)
  let cli_source = ($download_dir | path join $CLI_BIN_NAME)

  if not ($gui_source | path exists) {
    error make {
      msg: $"GUI binary not found: ($gui_source)"
    }
  }

  print $"Installing application binaries into ($bin_dir)..."
  install-dir $bin_dir
  install-file $gui_source ($bin_dir | path join $GUI_BIN_NAME)

  if $install_cli {
    if not ($cli_source | path exists) {
      error make {
        msg: $"CLI binary not found: ($cli_source)"
      }
    }

    install-file $cli_source ($bin_dir | path join $CLI_BIN_NAME)
  }
}

def run-local-installer [
  installer_path: string
  --needs-root
] {
  if (is-root) or (not $needs_root) {
    ^nu $installer_path
  } else {
    ^sudo nu $installer_path
  }
}

export def install-excalibur-release [
  --version: string = ""
  --no-cli
  --skip-driver
] {
  let release_tag = (resolve-release-tag $version)
  let install_cli = not $no_cli
  let tmp_dir = (^mktemp -d | str trim)
  let download_dir = (^mktemp -d | str trim)

  try {
    let checkout_dir = (extract-source-archive $release_tag $tmp_dir)
    let installer_path = ($checkout_dir | path join $INSTALLER_PATH)

    if not ($installer_path | path exists) {
      error make {
        msg: "Could not locate Nushell local installer in release source"
        help: $"Checked ($installer_path)"
      }
    }

    if $skip_driver {
      print "Skipping driver and udev rule installation."
    } else {
      run-local-installer $installer_path --needs-root
    }

    download-release-binaries $release_tag $install_cli $download_dir
    install-app-binaries $download_dir $BIN_DIR $install_cli

    print "Installation complete."
    print $"Run: (($BIN_DIR | path join $GUI_BIN_NAME))"
  } catch {|err|
    ^rm -rf $tmp_dir $download_dir
    error make {
      msg: $err.msg
      help: ($err.help? | default "")
    }
  }

  ^rm -rf $tmp_dir $download_dir
}

def main [
  --version: string = ""
  --no-cli
  --skip-driver
] {
  install-deps
  install-excalibur-release --version $version --no-cli=$no_cli --skip-driver=$skip_driver
}
