#!/usr/bin/env nu

const INSTALLER_PATH = "scripts/driver-nu/install.nu"

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

def run-installer [installer_path: string] {
  if (is-root) {
    ^nu $installer_path
  } else {
    need-command sudo
    ^sudo nu $installer_path
  }
}

def main [] {
  let repo_url = ($env.CECC_REPO_URL? | default "https://github.com/mert-kurttutan/cecc-linux.git")
  let repo_ref = ($env.CECC_REPO_REF? | default "main")

  need-command git

  let tmp_dir = (^mktemp -d | str trim)

  try {
    let checkout_dir = ($tmp_dir | path join "cecc-linux")

    print $"Cloning cecc-linux from ($repo_url)..."
    ^git clone --depth 1 --branch $repo_ref $repo_url $checkout_dir

    print "Installing casper-wmi from temporary checkout..."
    run-installer ($checkout_dir | path join $INSTALLER_PATH)

    print "Done."
  } catch {|err|
    ^rm -rf $tmp_dir
    error make {
      msg: $err.msg
      help: ($err.help? | default "")
    }
  }

  ^rm -rf $tmp_dir
}
