#!/usr/bin/env nu

use std/assert

const LED_ROOT = "/sys/class/leds"
const KEYBOARD_LEDS = [
  { zone: "left", device: "casper:rgb:kbd_zoned_backlight-left" }
  { zone: "middle", device: "casper:rgb:kbd_zoned_backlight-middle" }
  { zone: "right", device: "casper:rgb:kbd_zoned_backlight-right" }
]
const BRIGHTNESS_LEVELS = [0 1 2]
const TEST_COLORS = [
  { zone: "left", color: "255 0 0" }
  { zone: "middle", color: "0 255 0" }
  { zone: "right", color: "0 0 255" }
]

def led-file [device: string file: string] {
  $LED_ROOT | path join $device $file
}

def ensure-led-file [device: string file: string] {
  let path = (led-file $device $file)

  if not ($path | path exists) {
    error make { msg: $"LED sysfs file not found: ($path)" }
  }

  $path
}

def read-brightness [device: string] {
  open (ensure-led-file $device "brightness") | str trim | into int
}

def write-brightness [device: string brightness: int] {
  $brightness | save --force (ensure-led-file $device "brightness")
}

def read-color [device: string] {
  open (ensure-led-file $device "multi_intensity")
  | str trim
  | split row --regex '\s+'
  | str join " "
}

def write-color [device: string color: string] {
  let brightness = (read-brightness $device)

  $color | save --force (ensure-led-file $device "multi_intensity")
  $brightness | save --force (ensure-led-file $device "brightness")
}

def keyboard-state [] {
  $KEYBOARD_LEDS
  | each {|entry|
      {
        zone: $entry.zone
        device: $entry.device
        brightness: (read-brightness $entry.device)
        color: (read-color $entry.device)
      }
    }
}

def restore-keyboard-state [state: table] {
  for entry in $state {
    write-color $entry.device $entry.color
  }

  write-brightness ($state | first | get device) ($state | first | get brightness)
}

def assert-all-keyboard-brightness [expected: int] {
  let readings = (keyboard-state)

  for entry in $readings {
    assert equal $entry.brightness $expected $"($entry.zone) brightness should follow shared keyboard brightness"
  }
}

def assert-keyboard-colors [expected: table] {
  let readings = (keyboard-state)

  for entry in $readings {
    let expected_color = ($expected | where zone == $entry.zone | get 0.color)
    assert equal $entry.color $expected_color $"($entry.zone) color should match expected per-zone color"
  }
}

def "test keyboard brightness is shared" [--delay-ms: int = 300] {
  for target in $KEYBOARD_LEDS {
    for brightness in $BRIGHTNESS_LEVELS {
      print $"brightness: write ($brightness) through ($target.zone)"
      write-brightness $target.device $brightness
      sleep ($delay_ms * 1ms)
      assert-all-keyboard-brightness $brightness
    }
  }
}

def "test keyboard colors are per-zone" [--delay-ms: int = 300] {
  write-brightness ($KEYBOARD_LEDS | first | get device) 2
  sleep ($delay_ms * 1ms)

  mut expected = (keyboard-state)

  for target in $TEST_COLORS {
    let device = ($KEYBOARD_LEDS | where zone == $target.zone | get 0.device)

    print $"color: write ($target.color) through ($target.zone)"
    write-color $device $target.color
    sleep ($delay_ms * 1ms)

    $expected = (
      $expected
      | update color {|entry|
          if $entry.zone == $target.zone { $target.color } else { $entry.color }
        }
    )

    assert-keyboard-colors $expected
  }
}

def main [
  --delay-ms: int = 300
  --no-restore
] {
  let initial_state = (keyboard-state)

  print "Initial keyboard state:"
  $initial_state | table | print

  try {
    test keyboard brightness is shared --delay-ms $delay_ms
    test keyboard colors are per-zone --delay-ms $delay_ms

    if not $no_restore {
      restore-keyboard-state $initial_state
      sleep ($delay_ms * 1ms)
      print "Restored initial keyboard state."
    }

    print "LED behavior tests passed."
  } catch {|err|
    if not $no_restore {
      restore-keyboard-state $initial_state
    }

    error make { msg: $err.msg }
  }
}
