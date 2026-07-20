#!/usr/bin/env nu

const LED_ROOT = "/sys/class/leds"
const GPU_MODE_PATH = "/sys/module/casper_wmi/parameters/gpu_mode"
const GROUP = "excalibur"

def apply-file [path: string] {
  if not ($path | path exists) {
    return
  }

  do -i { ^chgrp $GROUP $path }
  do -i { ^chmod g+rw $path }
}

def apply-all-leds [] {
  if not ($LED_ROOT | path exists) {
    return
  }

  let leds = (
    ls $LED_ROOT
    | where {|entry| ($entry.name | path basename | str starts-with "casper:rgb:") }
  )

  for led in $leds {
    let led_name = ($led.name | path basename)
    apply-file ($LED_ROOT | path join $led_name "brightness")
    apply-file ($LED_ROOT | path join $led_name "multi_intensity")
  }
}

export def apply-excalibur-sysfs-permissions [
  mode: string = "all"
  led_name: string = ""
] {
  match $mode {
    "leds" => {
      if ($led_name | str starts-with "casper:rgb:") {
        apply-file ($LED_ROOT | path join $led_name "brightness")
        apply-file ($LED_ROOT | path join $led_name "multi_intensity")
      }
    }
    "module" => { apply-file $GPU_MODE_PATH }
    "all" => {
      apply-all-leds
      apply-file $GPU_MODE_PATH
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
