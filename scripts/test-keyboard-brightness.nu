#!/usr/bin/env nu

const LED_ROOT = "/sys/class/leds"
const KEYBOARD_LEDS = [
  "casper:rgb:kbd_zoned_backlight-left"
  "casper:rgb:kbd_zoned_backlight-middle"
  "casper:rgb:kbd_zoned_backlight-right"
]
const BRIGHTNESS_LEVELS = [0 1 2]

def led-path [name: string] {
  $LED_ROOT | path join $name "brightness"
}

def read-led-brightness [name: string] {
  let path = (led-path $name)

  if not ($path | path exists) {
    error make { msg: $"LED brightness path not found: ($path)" }
  }

  open $path | str trim | into int
}

def read-keyboard-brightness [] {
  $KEYBOARD_LEDS
  | each {|name|
      {
        led: $name
        brightness: (read-led-brightness $name)
      }
    }
}

def write-led-brightness [name: string brightness: int] {
  let path = (led-path $name)

  if not ($path | path exists) {
    error make { msg: $"LED brightness path not found: ($path)" }
  }

  $brightness | save --force $path
}

def assert-keyboard-brightness [expected: int] {
  let readings = (read-keyboard-brightness)
  let failures = ($readings | where brightness != $expected)

  if ($failures | is-not-empty) {
    print "Keyboard brightness mismatch:"
    $readings | table | print
    error make { msg: $"Expected every keyboard zone brightness to be ($expected)" }
  }
}

def restore-keyboard-brightness [brightness: int] {
  write-led-brightness ($KEYBOARD_LEDS | first) $brightness
}

def main [
  --delay-ms: int = 300
  --no-restore
] {
  let initial_keyboard = (read-led-brightness ($KEYBOARD_LEDS | first))

  print "Initial keyboard brightness:"
  read-keyboard-brightness | table | print

  try {
    for target in $KEYBOARD_LEDS {
      for brightness in $BRIGHTNESS_LEVELS {
        print $"write keyboard brightness ($brightness) through ($target)"
        write-led-brightness $target $brightness
        sleep ($delay_ms * 1ms)
        assert-keyboard-brightness $brightness
      }
    }

    if not $no_restore {
      restore-keyboard-brightness $initial_keyboard
      sleep ($delay_ms * 1ms)
      print $"Restored keyboard brightness to ($initial_keyboard)"
    }

    print "Keyboard shared-brightness behavior passed."
  } catch {|err|
    if not $no_restore {
      restore-keyboard-brightness $initial_keyboard
    }

    error make { msg: $err.msg }
  }
}
