#!/usr/bin/env nu

use std/assert
use ./utils.nu *

def read-brightness [device: string] {
  read-file-trimmed (led-file $device "brightness") | into int
}

def write-brightness [device: string brightness: int] {
  write-file (led-file $device "brightness") $brightness
}

def read-state [] {
  (
    $KEYBOARD_LED_DEVICES
    | each {|device| { led: $device, brightness: (read-brightness $device) } }
    | append { led: $BIASLIGHT_DEVICE, brightness: (read-brightness $BIASLIGHT_DEVICE) }
  )
}

def restore-state [keyboard_brightness: int bias_brightness: int] {
  write-brightness ($KEYBOARD_LED_DEVICES | first) $keyboard_brightness
  write-brightness $BIASLIGHT_DEVICE $bias_brightness
}

def assert-keyboard-brightness [expected: int] {
  for device in $KEYBOARD_LED_DEVICES {
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
  let initial_keyboard = (read-brightness ($KEYBOARD_LED_DEVICES | first))
  let initial_bias = (read-brightness $BIASLIGHT_DEVICE)

  print "Initial LED brightness state:"
  read-state | table | print

  try {
    print "Set keyboard brightness to 2 and biaslight brightness to 0"
    write-brightness ($KEYBOARD_LED_DEVICES | first) 2
    write-brightness $BIASLIGHT_DEVICE 0
    sleep ($delay_ms * 1ms)
    print-readback "after keyboard=2 biaslight=0"
    assert-keyboard-brightness 2
    assert equal (read-brightness $BIASLIGHT_DEVICE) 0 "biaslight should remain 0 after keyboard brightness is set to 2"

    print "Set keyboard brightness to 0; biaslight should remain 0"
    write-brightness ($KEYBOARD_LED_DEVICES | first) 0
    sleep ($delay_ms * 1ms)
    print-readback "after keyboard=0"
    assert-keyboard-brightness 0
    assert equal (read-brightness $BIASLIGHT_DEVICE) 0 "biaslight should not change when keyboard brightness changes"

    print "Set biaslight brightness to 2; keyboard should remain 0"
    write-brightness $BIASLIGHT_DEVICE 2
    sleep ($delay_ms * 1ms)
    print-readback "after biaslight=2"
    assert equal (read-brightness $BIASLIGHT_DEVICE) 2 "biaslight should accept brightness 2"
    assert-keyboard-brightness 0

    print "Set biaslight brightness to 0; keyboard should remain 0"
    write-brightness $BIASLIGHT_DEVICE 0
    sleep ($delay_ms * 1ms)
    print-readback "after biaslight=0"
    assert equal (read-brightness $BIASLIGHT_DEVICE) 0 "biaslight should accept brightness 0"
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
