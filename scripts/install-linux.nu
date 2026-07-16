#!/usr/bin/env nu

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

def release-asset-url [github_repo: string, release_tag: string, asset: string] {
  if $release_tag == "latest" {
    $"https://github.com/($github_repo)/releases/latest/download/($asset)"
  } else {
    $"https://github.com/($github_repo)/releases/download/($release_tag)/($asset)"
  }
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

def prepare-repo-checkout [github_repo: string, release_tag: string, repo_checkout_dir: string] {
  need-command git

  let ref = (clone-ref $release_tag)
  let checkout_path = ($repo_checkout_dir | path join "cecc-linux")
  let repo_url = $"https://github.com/($github_repo).git"

  print $"Cloning ($github_repo) for driver and udev installer files..."
  let clone_result = (^git clone --depth 1 --branch $ref $repo_url $checkout_path | complete)

  if $clone_result.exit_code != 0 {
    if (($env.EXCALIBUR_REPO_REF? | default "") != "") or ($release_tag != "latest") {
      print $"Could not clone ref '($ref)'. Falling back to main."
      ^git clone --depth 1 --branch main $repo_url $checkout_path
    } else {
      error make {
        msg: $"Could not clone ($github_repo)"
        help: ($clone_result.stderr | str trim)
      }
    }
  }

  $checkout_path | path join "casper-wmi"
}

def run-root-script [script_path: string] {
  if (is-root) {
    ^bash $script_path
  } else {
    need-command sudo
    ^sudo bash $script_path
  }
}

def install-driver [driver_dir: string, skip_driver: bool] {
  if $skip_driver {
    print "Skipping driver installation."
    return
  }

  print "Installing casper-wmi driver..."
  run-root-script ($driver_dir | path join "install-full.sh")
}

def install-udev-rules [driver_dir: string, skip_udev: bool] {
  if $skip_udev {
    print "Skipping udev rule installation."
    return
  }

  print "Installing udev rules and permission helper..."
  run-root-script ($driver_dir | path join "install-udev-rules.sh")
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

def sudo-install-dir [bin_dir: string] {
  if (is-root) {
    ^install -d -m 0755 $bin_dir
  } else {
    need-command sudo
    ^sudo install -d -m 0755 $bin_dir
  }
}

def sudo-install-file [source: string, target: string] {
  if (is-root) {
    ^install -m 0755 $source $target
  } else {
    need-command sudo
    ^sudo install -m 0755 $source $target
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
  sudo-install-dir $bin_dir
  sudo-install-file $gui_source ($bin_dir | path join $GUI_BIN_NAME)

  if $install_cli {
    if not ($cli_source | path exists) {
      error make {
        msg: $"CLI binary not found: ($cli_source)"
      }
    }

    sudo-install-file $cli_source ($bin_dir | path join $CLI_BIN_NAME)
  }
}

def main [
  --version: string = ""
  --tag: string = ""
  --no-cli
  --skip-driver
  --skip-udev
] {
  let prefix = ($env.PREFIX? | default "/usr/local")
  let bin_dir = ($env.BIN_DIR? | default ($prefix | path join "bin"))
  let github_repo = ($env.EXCALIBUR_GITHUB_REPO? | default "mert-kurttutan/cecc-linux")
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
  let skip_driver = $skip_driver or (($env.EXCALIBUR_SKIP_DRIVER? | default "0") == "1")
  let skip_udev = $skip_udev or (($env.EXCALIBUR_SKIP_UDEV? | default "0") == "1")

  let repo_checkout_dir = (^mktemp -d | str trim)
  let download_dir = (^mktemp -d | str trim)

  try {
    let driver_dir = (prepare-repo-checkout $github_repo $release_tag $repo_checkout_dir)
    install-driver $driver_dir $skip_driver
    install-udev-rules $driver_dir $skip_udev
    download-release-binaries $github_repo $release_tag $gui_release_asset $cli_release_asset $install_cli $download_dir
    install-app-binaries $download_dir $bin_dir $install_cli

    print "Installation complete."
    print $"Run: (($bin_dir | path join $GUI_BIN_NAME))"
  } catch {|err|
    ^rm -rf $repo_checkout_dir $download_dir
    error make {
      msg: $err.msg
      help: ($err.help? | default "")
    }
  }

  ^rm -rf $repo_checkout_dir $download_dir
}
