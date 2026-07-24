#!/usr/bin/env nu

use std/assert

const LED_ROOT = "/sys/class/leds"
const KEYBOARD_LEDS = [
  "casper:rgb:kbd_zoned_backlight-left"
  "casper:rgb:kbd_zoned_backlight-middle"
  "casper:rgb:kbd_zoned_backlight-right"
]
const BIAS_LED = "casper:rgb:biaslight"
const ALL_LEDS = [
  "casper:rgb:kbd_zoned_backlight-left"
  "casper:rgb:kbd_zoned_backlight-middle"
  "casper:rgb:kbd_zoned_backlight-right"
  "casper:rgb:biaslight"
]

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

def read-led-state [] {
  $ALL_LEDS
  | each { |led|
    {
      led: $led
      brightness: (read-file-trimmed (led-file $led "brightness") | into int)
      effect: (read-file-trimmed (led-file $led "effect") | into int)
      color: (read-file-trimmed (led-file $led "multi_intensity"))
    }
  }
}

def print-state [label: string] {
  print $label
  read-led-state | table | print
}

def write-keyboard-brightness [brightness: int] {
  write-file (led-file ($KEYBOARD_LEDS | first) "brightness") $brightness
}

def write-gui-all-brightness [brightness: int] {
  # Matches SysfsBackend::set_keyboard_brightness(All).
  for led in $ALL_LEDS {
    write-file (led-file $led "brightness") $brightness
  }
}

def write-gui-all-color [color: string] {
  # Matches SysfsBackend::set_keyboard_color(All): each zone rewrites color, then brightness.
  for led in $ALL_LEDS {
    let brightness = (read-file-trimmed (led-file $led "brightness") | into int)

    write-file (led-file $led "multi_intensity") $color
    write-file (led-file $led "brightness") $brightness
  }
}

def write-gui-all-effect [effect: int] {
  # Matches SysfsBackend::set_keyboard_effect(All): left, middle, right, then biaslight.
  for led in $ALL_LEDS {
    write-file (led-file $led "effect") $effect
  }
}

def restore-state [initial: list] {
  for row in $initial {
    write-file (led-file $row.led "effect") $row.effect
    write-file (led-file $row.led "multi_intensity") $row.color
    write-file (led-file $row.led "brightness") $row.brightness
  }
}

def assert-all-brightness [state: list expected: int label: string] {
  let failures = ($state | where brightness != $expected)

  if ($failures | is-not-empty) {
    print $"Brightness changed during ($label):"
    $state | table | print
    error make { msg: $"Expected all LED brightness values to stay at ($expected)" }
  }
}

def main [
  --delay-ms: int = 300
  --color: string
  --no-restore
  --no-assert
] {
  for led in $ALL_LEDS {
    ensure-path (led-file $led "brightness") | ignore
    ensure-path (led-file $led "effect") | ignore
    ensure-path (led-file $led "multi_intensity") | ignore
  }

  let initial = (read-led-state)

  print "Initial LED state:"
  $initial | table | print

  try {
    let apply_color = if ($color | is-empty) {
      $initial.0.color
    } else {
      $color
    }

    print $"Apply GUI-style all color '($apply_color)', then all brightness 2."
    write-gui-all-color $apply_color
    write-gui-all-brightness 2
    sleep ($delay_ms * 1ms)
    let after_brightness = (read-led-state)
    print "After GUI-style color and brightness apply:"
    $after_brightness | table | print

    if not $no_assert {
      assert-all-brightness $after_brightness 2 "initial brightness setup"
    }

    print "Set GUI-style all effect to 3 (breathing)."
    write-gui-all-effect 3
    sleep ($delay_ms * 1ms)
    let after_breathing = (read-led-state)
    print "After switching to breathing:"
    $after_breathing | table | print

    if not $no_assert {
      assert-all-brightness $after_breathing 2 "breathing effect write"
    }

    print "Set GUI-style all effect to 1 (static)."
    write-gui-all-effect 1
    sleep ($delay_ms * 1ms)
    let after_static = (read-led-state)
    print "After switching back to static:"
    $after_static | table | print

    if not $no_assert {
      assert-all-brightness $after_static 2 "static effect write"
    }

    if not $no_restore {
      print "Restoring initial LED state."
      restore-state $initial
    }

    print "Breathing brightness repro finished."
  } catch {|err|
    print "LED state after failure:"
    read-led-state | table | print

    if not $no_restore {
      print "Restoring initial LED state."
      restore-state $initial
    }

    error make { msg: $err.msg }
  }
}
