#!/usr/bin/env nu

use std/assert

const LED_ROOT = "/sys/class/leds"
const ALL_LEDS = [
  "casper:rgb:kbd_zoned_backlight-left"
  "casper:rgb:kbd_zoned_backlight-middle"
  "casper:rgb:kbd_zoned_backlight-right"
  "casper:rgb:biaslight"
]
const MODES = [
  [value, name];
  [1, "static"]
  [2, "blink"]
  [3, "breathing"]
  [4, "heartbeat"]
  [5, "repeat"]
  [6, "cycle"]
  [7, "ambilight"]
]
const MODE_HELP = "static/1, blink/2, breathing/3, heartbeat/4, repeat/5, cycle/6, ambilight/7"

def led-file [device: string file: string] {
  $LED_ROOT | path join $device $file
}

def ensure-path [path: string] {
  if not ($path | path exists) {
    error make { msg: $"Required sysfs path not found: ($path)" }
  }

  $path
}

def read-file-trimmed [path: string] {
  open (ensure-path $path) | str trim
}

def write-file [path: string value: any] {
  ($value | into string) | ^sudo tee (ensure-path $path) | ignore
}

def resolve-mode [mode: string] {
  let selected = (
    $MODES
    | where (($it.value | into string) == $mode) or ($it.name == $mode)
  )

  if ($selected | is-empty) {
    error make { msg: $"Unsupported mode ($mode). Supported modes: ($MODE_HELP)" }
  }

  $selected.0
}

def read-leds [] {
  $ALL_LEDS
  | each { |led|
    {
      led: $led
      brightness: (read-file-trimmed (led-file $led "brightness") | into int)
      effect: (read-file-trimmed (led-file $led "effect") | into int)
    }
  }
}

def main [
  --mode: string = "breathing"
  --delay-ms: int = 300
  --no-restore
] {
  for led in $ALL_LEDS {
    ensure-path (led-file $led "effect") | ignore
    ensure-path (led-file $led "brightness") | ignore
  }

  let target_mode = (resolve-mode $mode)
  let initial = (read-leds)
  let expected_brightness = ($initial | select led brightness)

  print "Initial all-LED state:"
  $initial | table | print
  print $"Writing effect only to every LED, matching GUI Select all: ($target_mode.value) (($target_mode.name))"

  try {
    for led in $ALL_LEDS {
      write-file (led-file $led "effect") $target_mode.value
    }

    let immediate = (read-leds)
    print "After all-LED effect-only writes:"
    $immediate | table | print
    assert equal ($immediate | select led brightness) $expected_brightness "Brightness changed immediately after all-LED effect-only writes"

    sleep ($delay_ms * 1ms)

    let delayed = (read-leds)
    print $"After ($delay_ms)ms:"
    $delayed | table | print
    assert equal ($delayed | select led brightness) $expected_brightness $"Brightness changed within ($delay_ms)ms after all-LED effect-only writes"

    if not $no_restore {
      print "Restoring initial effects and brightness values."
      for row in $initial {
        write-file (led-file $row.led "effect") $row.effect
        write-file (led-file $row.led "brightness") $row.brightness
      }
    }

    print "Select-all effect-only brightness preservation test passed."
  } catch {|err|
    print "LED state after failure:"
    read-leds | table | print

    if not $no_restore {
      for row in $initial {
        write-file (led-file $row.led "effect") $row.effect
        write-file (led-file $row.led "brightness") $row.brightness
      }
    }

    error make { msg: $err.msg }
  }
}
