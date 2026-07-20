#!/usr/bin/env nu

const INSTALLER_PATH = "scripts/driver-nu/install-driver-stack.nu"
const GUI_BIN_NAME = "excalibur-control-center-gui"
const CLI_BIN_NAME = "excalibur-control-center-cli"
const GITHUB_REPO = "mert-kurttutan/cecc-linux"
const BIN_DIR = "/usr/local/bin"

def need-command [name: string] {
  if ((which $name) | is-empty) {
    error make {
      msg: $"Missing required command: ($name)"
    }
  }
}

def is-root [] {
  ((^id -u | str trim) == "0")
}

def clone-ref [release_tag: string] {
  if $release_tag == "latest" {
    "main"
  } else {
    $release_tag
  }
}

def release-asset-url [github_repo: string, release_tag: string, asset: string] {
  if $release_tag == "latest" {
    $"https://github.com/($github_repo)/releases/latest/download/($asset)"
  } else {
    $"https://github.com/($github_repo)/releases/download/($release_tag)/($asset)"
  }
}

def download-file [url: string, output: string] {
  if not ((which curl) | is-empty) {
    ^curl -fL $url -o $output
  } else if not ((which wget) | is-empty) {
    ^wget -O $output $url
  } else {
    error make {
      msg: "Missing downloader: install curl or wget"
    }
  }
}

def install-dir [bin_dir: string] {
  if (is-root) {
    ^install -d -m 0755 $bin_dir
  } else {
    need-command sudo
    ^sudo install -d -m 0755 $bin_dir
  }
}

def install-file [source: string, target: string] {
  if (is-root) {
    ^install -m 0755 $source $target
  } else {
    need-command sudo
    ^sudo install -m 0755 $source $target
  }
}

def download-release-binaries [
  github_repo: string
  release_tag: string
  gui_release_asset: string
  cli_release_asset: string
  install_cli: bool
  download_dir: string
] {
  let gui_url = (release-asset-url $github_repo $release_tag $gui_release_asset)
  let gui_output = ($download_dir | path join $GUI_BIN_NAME)

  print "Downloading GUI binary from GitHub Releases..."
  print $gui_url
  download-file $gui_url $gui_output
  ^chmod 0755 $gui_output

  if $install_cli {
    let cli_url = (release-asset-url $github_repo $release_tag $cli_release_asset)
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
    need-command sudo
    ^sudo nu $installer_path
  }
}

export def install-excalibur-release [
  --version: string = ""
  --tag: string = ""
  --no-cli
  --skip-driver
] {
  need-command git

  let release_tag = if $version != "" {
    $version
  } else if $tag != "" {
    $tag
  } else {
    "latest"
  }
  let install_cli = not $no_cli
  let ref = (clone-ref $release_tag)
  let repo_url = $"https://github.com/($GITHUB_REPO).git"
  let tmp_dir = (^mktemp -d | str trim)
  let download_dir = (^mktemp -d | str trim)

  try {
    let checkout_dir = ($tmp_dir | path join "cecc-linux")
    let installer_path = ($checkout_dir | path join $INSTALLER_PATH)

    print $"Cloning ($GITHUB_REPO) for local installer files..."
    let clone_result = (^git clone --depth 1 --branch $ref $repo_url $checkout_dir | complete)

    if $clone_result.exit_code != 0 {
      if $release_tag != "latest" {
        print $"Could not clone ref '($ref)'. Falling back to main."
        ^git clone --depth 1 --branch main $repo_url $checkout_dir
      } else {
        error make {
          msg: $"Could not clone ($GITHUB_REPO)"
          help: ($clone_result.stderr | str trim)
        }
      }
    }

    if not ($installer_path | path exists) {
      error make {
        msg: "Could not locate Nushell local installer in cloned release source"
        help: $"Checked ($installer_path)"
      }
    }

    if $skip_driver {
      print "Skipping driver and udev rule installation."
    } else {
      run-local-installer $installer_path --needs-root
    }

    download-release-binaries $GITHUB_REPO $release_tag $GUI_BIN_NAME $CLI_BIN_NAME $install_cli $download_dir
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
  --tag: string = ""
  --no-cli
  --skip-driver
] {
  install-excalibur-release --version $version --tag $tag --no-cli=$no_cli --skip-driver=$skip_driver
}
