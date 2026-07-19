#!/usr/bin/env nu

const LED_ROOT = "/sys/class/leds"
const GPU_MODE_PATH = "/sys/module/casper_wmi/parameters/gpu_mode"
const GROUP = "excalibur"

def apply-file [path: string, group: string] {
  if not ($path | path exists) {
    return
  }

  do -i { ^chgrp $group $path }
  do -i { ^chmod g+rw $path }
}

def apply-led [led_name: string, group: string] {
  if not ($led_name | str starts-with "casper:rgb:") {
    return
  }

  apply-file ($LED_ROOT | path join $led_name "brightness") $group
  apply-file ($LED_ROOT | path join $led_name "multi_intensity") $group
}

def apply-all-leds [group: string] {
  if not ($LED_ROOT | path exists) {
    return
  }

  let leds = (
    ls $LED_ROOT
    | where {|entry| ($entry.name | path basename | str starts-with "casper:rgb:") }
  )

  for led in $leds {
    apply-led ($led.name | path basename) $group
  }
}

def apply-module [group: string] {
  apply-file $GPU_MODE_PATH $group
}

export def apply-excalibur-sysfs-permissions [
  mode: string = "all"
  led_name: string = ""
] {
  match $mode {
    "leds" => { apply-led $led_name $GROUP }
    "module" => { apply-module $GROUP }
    "all" => {
      apply-all-leds $GROUP
      apply-module $GROUP
    }
    _ => {
      error make {
        msg: "usage: apply-sysfs-permissions.nu [all|leds <name>|module]"
      }
    }
  }
}

def main [
  mode: string = "all"
  led_name: string = ""
] {
  apply-excalibur-sysfs-permissions $mode $led_name
}
