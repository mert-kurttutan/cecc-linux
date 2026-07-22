#!/usr/bin/env nu

use std/assert

const LED_ROOT = "/sys/class/leds"
const KEYBOARD_LED = "casper:rgb:kbd_zoned_backlight-left"
const KEYBOARD_LEDS = [
  "casper:rgb:kbd_zoned_backlight-left"
  "casper:rgb:kbd_zoned_backlight-middle"
  "casper:rgb:kbd_zoned_backlight-right"
]
const BIAS_LED = "casper:rgb:biaslight"

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

def read-state [] {
  (
    $KEYBOARD_LEDS
    | each {|device| { led: $device, brightness: (read-brightness $device) } }
    | append { led: $BIAS_LED, brightness: (read-brightness $BIAS_LED) }
  )
}

def restore-state [keyboard_brightness: int bias_brightness: int] {
  write-brightness $KEYBOARD_LED $keyboard_brightness
  write-brightness $BIAS_LED $bias_brightness
}

def assert-keyboard-brightness [expected: int] {
  for device in $KEYBOARD_LEDS {
    assert equal (read-brightness $device) $expected $"($device) should have keyboard brightness ($expected)"
  }
}

def print-readback [label: string] {
  print $"== ($label) =="
  read-state | table | print
}

def main [
  --delay-ms: int = 500
  --no-restore
] {
  let initial_keyboard = (read-brightness $KEYBOARD_LED)
  let initial_bias = (read-brightness $BIAS_LED)

  print "Initial LED brightness state:"
  read-state | table | print

  try {
    print "Set keyboard brightness to 2 and biaslight brightness to 0"
    write-brightness $KEYBOARD_LED 2
    write-brightness $BIAS_LED 0
    sleep ($delay_ms * 1ms)
    print-readback "after keyboard=2 biaslight=0"
    assert-keyboard-brightness 2
    assert equal (read-brightness $BIAS_LED) 0 "biaslight should remain 0 after keyboard brightness is set to 2"

    print "Set keyboard brightness to 0; biaslight should remain 0"
    write-brightness $KEYBOARD_LED 0
    sleep ($delay_ms * 1ms)
    print-readback "after keyboard=0"
    assert-keyboard-brightness 0
    assert equal (read-brightness $BIAS_LED) 0 "biaslight should not change when keyboard brightness changes"

    print "Set biaslight brightness to 2; keyboard should remain 0"
    write-brightness $BIAS_LED 2
    sleep ($delay_ms * 1ms)
    print-readback "after biaslight=2"
    assert equal (read-brightness $BIAS_LED) 2 "biaslight should accept brightness 2"
    assert-keyboard-brightness 0

    print "Set biaslight brightness to 0; keyboard should remain 0"
    write-brightness $BIAS_LED 0
    sleep ($delay_ms * 1ms)
    print-readback "after biaslight=0"
    assert equal (read-brightness $BIAS_LED) 0 "biaslight should accept brightness 0"
    assert-keyboard-brightness 0

    if not $no_restore {
      restore-state $initial_keyboard $initial_bias
      sleep ($delay_ms * 1ms)
      print "Restored initial keyboard and biaslight brightness."
    }

    print "Biaslight brightness decoupling test passed."
  } catch {|err|
    print "LED brightness state after failure:"
    read-state | table | print

    if not $no_restore {
      restore-state $initial_keyboard $initial_bias
    }

    error make { msg: $err.msg }
  }
}
