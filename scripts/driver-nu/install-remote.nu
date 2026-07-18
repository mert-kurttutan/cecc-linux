#!/usr/bin/env nu

const INSTALLER_PATH = "scripts/driver-nu/install-full.nu"
const GUI_BIN_NAME = "excalibur-control-center-gui"
const CLI_BIN_NAME = "excalibur-control-center-cli"

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
  let explicit_ref = ($env.EXCALIBUR_REPO_REF? | default "")

  if $explicit_ref != "" {
    $explicit_ref
  } else if $release_tag == "latest" {
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

def local-installer-args [--skip-driver --skip-udev] {
  mut args = []

  if $skip_driver {
    $args = ($args | append "--skip-driver")
  }

  if $skip_udev {
    $args = ($args | append "--skip-udev")
  }

  $args
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
  args: list<string>
  --needs-root
] {
  if (is-root) or (not $needs_root) {
    ^nu $installer_path ...$args
  } else {
    need-command sudo
    ^sudo nu $installer_path ...$args
  }
}

export def install-excalibur-remote [
  --version: string = ""
  --tag: string = ""
  --no-cli
  --skip-driver
  --skip-udev
] {
  need-command git

  let github_repo = ($env.EXCALIBUR_GITHUB_REPO? | default "mert-kurttutan/cecc-linux")
  let prefix = ($env.PREFIX? | default "/usr/local")
  let bin_dir = ($env.BIN_DIR? | default ($prefix | path join "bin"))
  let env_release_tag = ($env.EXCALIBUR_RELEASE_TAG? | default "latest")
  let release_tag = if $version != "" {
    $version
  } else if $tag != "" {
    $tag
  } else {
    $env_release_tag
  }
  let gui_release_asset = ($env.EXCALIBUR_GUI_RELEASE_ASSET? | default $GUI_BIN_NAME)
  let cli_release_asset = ($env.EXCALIBUR_CLI_RELEASE_ASSET? | default $CLI_BIN_NAME)
  let install_cli = not ($no_cli or (($env.EXCALIBUR_INSTALL_CLI? | default "1") == "0"))
  let ref = (clone-ref $release_tag)
  let repo_url = $"https://github.com/($github_repo).git"
  let tmp_dir = (^mktemp -d | str trim)
  let download_dir = (^mktemp -d | str trim)

  try {
    let checkout_dir = ($tmp_dir | path join "cecc-linux")
    let installer_path = ($checkout_dir | path join $INSTALLER_PATH)

    print $"Cloning ($github_repo) for local installer files..."
    let clone_result = (^git clone --depth 1 --branch $ref $repo_url $checkout_dir | complete)

    if $clone_result.exit_code != 0 {
      if (($env.EXCALIBUR_REPO_REF? | default "") != "") or ($release_tag != "latest") {
        print $"Could not clone ref '($ref)'. Falling back to main."
        ^git clone --depth 1 --branch main $repo_url $checkout_dir
      } else {
        error make {
          msg: $"Could not clone ($github_repo)"
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

    let args = (local-installer-args --skip-driver=$skip_driver --skip-udev=$skip_udev)
    let needs_root = not ($skip_driver and $skip_udev)
    run-local-installer $installer_path $args --needs-root=$needs_root

    download-release-binaries $github_repo $release_tag $gui_release_asset $cli_release_asset $install_cli $download_dir
    install-app-binaries $download_dir $bin_dir $install_cli

    print "Installation complete."
    print $"Run: (($bin_dir | path join $GUI_BIN_NAME))"
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
  --skip-udev
] {
  install-excalibur-remote --version $version --tag $tag --no-cli=$no_cli --skip-driver=$skip_driver --skip-udev=$skip_udev
}
