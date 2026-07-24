#!/usr/bin/env nu

use std/assert

const LED_ROOT = "/sys/class/leds"
const DEFAULT_LED = "casper:rgb:kbd_zoned_backlight-left"
const KEYBOARD_LEDS = [
  "casper:rgb:kbd_zoned_backlight-left"
  "casper:rgb:kbd_zoned_backlight-middle"
  "casper:rgb:kbd_zoned_backlight-right"
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

def read-keyboard-brightness [] {
  $KEYBOARD_LEDS
  | each { |led|
    {
      led: $led
      brightness: (read-file-trimmed (led-file $led "brightness") | into int)
      effect: (read-file-trimmed (led-file $led "effect") | into int)
    }
  }
}

def main [
  --led: string = $DEFAULT_LED
  --mode: string = "breathing"
  --delay-ms: int = 300
  --no-restore
] {
  ensure-path (led-file $led "effect") | ignore

  let target_mode = (resolve-mode $mode)
  let initial_effect = (read-file-trimmed (led-file $led "effect") | into int)
  let initial_brightness = (read-keyboard-brightness)
  let expected_brightness = ($initial_brightness | select led brightness)

  print "Initial keyboard LED state:"
  $initial_brightness | table | print
  print $"Writing effect only: ($target_mode.value) (($target_mode.name)) -> ($led)"

  try {
    write-file (led-file $led "effect") $target_mode.value

    let immediate = (read-keyboard-brightness)
    print "After effect-only write:"
    $immediate | table | print
    assert equal ($immediate | select led brightness) $expected_brightness "Brightness changed immediately after effect-only write"

    sleep ($delay_ms * 1ms)

    let delayed = (read-keyboard-brightness)
    print $"After ($delay_ms)ms:"
    $delayed | table | print
    assert equal ($delayed | select led brightness) $expected_brightness $"Brightness changed within ($delay_ms)ms after effect-only write"

    if not $no_restore {
      print $"Restoring initial effect ($initial_effect) and brightness values."
      write-file (led-file $led "effect") $initial_effect
      for row in $initial_brightness {
        write-file (led-file $row.led "brightness") $row.brightness
      }
    }

    print "Effect-only brightness preservation test passed."
  } catch {|err|
    print "LED state after failure:"
    read-keyboard-brightness | table | print

    if not $no_restore {
      write-file (led-file $led "effect") $initial_effect
      for row in $initial_brightness {
        write-file (led-file $row.led "brightness") $row.brightness
      }
    }

    error make { msg: $err.msg }
  }
}
