#!/usr/bin/env nu

const RULE_NAME = "90-excalibur-control-center.rules"
const HELPER_NAME = "apply-sysfs-permissions"
const HELPER_DIR = "/usr/local/libexec/excalibur-control-center"
const RULE_DIR = "/etc/udev/rules.d"
const GROUP = "excalibur"

def is-root [] {
  ((^id -u | str trim) == "0")
}

export def install-excalibur-permission-rules [] {
  if not (is-root) {
    error make {
      msg: "Please run as root: 'sudo ./install-permission-rules.nu'"
    }
  }

  let repo_root = ($env.FILE_PWD | path join ".." "..")
  let rule_source = ($repo_root | path join "casper-wmi" $RULE_NAME)
  let helper_source = ($env.FILE_PWD | path join "apply-sysfs-permissions.nu")
  let helper_target = ($HELPER_DIR | path join $HELPER_NAME)
  let rule_target = ($RULE_DIR | path join $RULE_NAME)

  print $"Creating group: ($GROUP)"
  ^groupadd -f $GROUP

  print "Installing udev permission helper..."
  ^install -d -m 0755 $HELPER_DIR
  ^install -m 0755 $helper_source $helper_target

  print "Installing udev rules..."
  ^install -d -m 0755 $RULE_DIR
  ^install -m 0644 $rule_source $rule_target

  print "Reloading udev rules..."
  ^udevadm control --reload-rules

  print "Triggering existing casper-wmi devices if present..."
  do -i { ^udevadm trigger --subsystem-match=leds --action=change }
  do -i { ^udevadm trigger --subsystem-match=module --action=change }
  do -i { ^$helper_target all }

  print "Installed udev rules."
  print "Users must log out and back in for group membership to apply."
}

def main [] {
  install-excalibur-permission-rules
}
