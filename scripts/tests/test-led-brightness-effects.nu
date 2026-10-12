#!/usr/bin/env nu

use std/assert
use ./utils.nu *

const EFFECT_TO_TEST = 3
const SETTLE_MS = 300

def read-led-state [] {
  $ALL_LED_DEVICES
  | each {|device|
      {
        led: $device
        brightness: (read-file-trimmed (led-file $device "brightness") | into int)
        effect: (read-file-trimmed (led-file $device "effect") | into int)
      }
    }
}

def brightness-state [state: list] {
  $state | select led brightness
}

def keyboard-brightness-state [state: list] {
  $state
  | where led in $KEYBOARD_LED_DEVICES
  | select led brightness
}

def assert-keyboard-brightness [expected: int label: string] {
  let current = (read-led-state)
  let keyboard = ($current | where led in $KEYBOARD_LED_DEVICES)

  for row in $keyboard {
    assert equal $row.brightness $expected $"($row.led) brightness should be ($expected) during ($label)"
  }
}

def restore-state [state: list] {
  for row in $state {
    write-file (led-file $row.led "effect") $row.effect --sudo
  }

  for row in $state {
    write-file (led-file $row.led "brightness") $row.brightness --sudo
  }
}

def main [] {
  for device in $ALL_LED_DEVICES {
    ensure-path (led-file $device "brightness") | ignore
    ensure-path (led-file $device "effect") | ignore
  }

  let initial = (read-led-state)
  print "Initial LED state:"
  $initial | table | print

  try {
    print "Test shared keyboard brightness across all zones."
    for brightness in [0 1 2] {
      for device in $KEYBOARD_LED_DEVICES {
        print $"write brightness=($brightness) through ($device)"
        write-file (led-file $device "brightness") $brightness --sudo
        sleep ($SETTLE_MS * 1ms)
        assert-keyboard-brightness $brightness "shared brightness test"
      }
    }

    let keyboard_before_single_effect = (keyboard-brightness-state (read-led-state))
    let single_led = ($KEYBOARD_LED_DEVICES | first)
    print $"Test effect-only write on one LED: effect=($EFFECT_TO_TEST) -> ($single_led)"
    write-file (led-file $single_led "effect") $EFFECT_TO_TEST --sudo

    let after_single_effect = (read-led-state)
    assert equal (keyboard-brightness-state $after_single_effect) $keyboard_before_single_effect "Single-LED effect write changed keyboard brightness immediately"
    sleep ($SETTLE_MS * 1ms)
    let after_single_effect_delay = (read-led-state)
    assert equal (keyboard-brightness-state $after_single_effect_delay) $keyboard_before_single_effect "Single-LED effect write changed keyboard brightness after delay"

    let brightness_before_select_all = (brightness-state (read-led-state))
    print $"Test select-all effect-only writes: effect=($EFFECT_TO_TEST)"
    for device in $ALL_LED_DEVICES {
      write-file (led-file $device "effect") $EFFECT_TO_TEST --sudo
    }

    let after_select_all = (read-led-state)
    assert equal (brightness-state $after_select_all) $brightness_before_select_all "Select-all effect writes changed LED brightness immediately"
    sleep ($SETTLE_MS * 1ms)
    let after_select_all_delay = (read-led-state)
    assert equal (brightness-state $after_select_all_delay) $brightness_before_select_all "Select-all effect writes changed LED brightness after delay"

    print "Restoring initial LED effects and brightness."
    restore-state $initial
    print "LED brightness and effect tests passed."
  } catch {|err|
    print "LED state after failure:"
    read-led-state | table | print
    print "Restoring initial LED effects and brightness."
    restore-state $initial
    error make { msg: $err.msg }
  }
}
