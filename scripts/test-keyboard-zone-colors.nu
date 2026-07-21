#!/usr/bin/env nu

const LED_ROOT = "/sys/class/leds"
const KEYBOARD_LEDS = [
  { zone: "left", device: "casper:rgb:kbd_zoned_backlight-left", color: "255 0 0" }
  { zone: "middle", device: "casper:rgb:kbd_zoned_backlight-middle", color: "0 255 0" }
  { zone: "right", device: "casper:rgb:kbd_zoned_backlight-right", color: "0 0 255" }
]

def led-file [device: string file: string] {
  $LED_ROOT | path join $device $file
}

def read-color [device: string] {
  let path = (led-file $device "multi_intensity")

  if not ($path | path exists) {
    error make { msg: $"LED color path not found: ($path)" }
  }

  open $path | str trim | str replace --all "\n" " "
}

def read-brightness [device: string] {
  let path = (led-file $device "brightness")

  if not ($path | path exists) {
    error make { msg: $"LED brightness path not found: ($path)" }
  }

  open $path | str trim | into int
}

def write-brightness [device: string brightness: int] {
  let path = (led-file $device "brightness")

  if not ($path | path exists) {
    error make { msg: $"LED brightness path not found: ($path)" }
  }

  $brightness | save --force $path
}

def read-colors [] {
  $KEYBOARD_LEDS
  | each {|entry|
      {
        zone: $entry.zone
        device: $entry.device
        color: (read-color $entry.device)
      }
    }
}

def write-color [device: string color: string] {
  let path = (led-file $device "multi_intensity")

  if not ($path | path exists) {
    error make { msg: $"LED color path not found: ($path)" }
  }

  $color | save --force $path
}

def assert-zone-colors [target_device: string expected_color: string previous_colors: table] {
  let current = (read-colors)
  let failures = (
    $current
    | each {|entry|
        let expected = if $entry.device == $target_device {
          $expected_color
        } else {
          $previous_colors | where device == $entry.device | get 0.color
        }

        if $entry.color != $expected {
          {
            zone: $entry.zone
            device: $entry.device
            expected: $expected
            actual: $entry.color
          }
        }
      }
    | compact
  )

  if ($failures | is-not-empty) {
    print "Keyboard zone color mismatch:"
    $failures | table | print
    print "Current keyboard colors:"
    $current | table | print
    error make { msg: "Expected individual keyboard color write to affect only the selected zone" }
  }
}

def restore-colors [initial_colors: table] {
  for entry in $initial_colors {
    write-color $entry.device $entry.color
  }
}

def restore-keyboard-brightness [brightness: int] {
  write-brightness ($KEYBOARD_LEDS | first | get device) $brightness
}

def main [
  --delay-ms: int = 300
  --observe-ms: int = 2000
  --no-restore
] {
  let initial_colors = (read-colors)
  let initial_brightness = (read-brightness ($KEYBOARD_LEDS | first | get device))

  print "Initial keyboard colors:"
  $initial_colors | table | print
  print $"Initial keyboard brightness: ($initial_brightness)"

  try {
    mut expected_colors = $initial_colors

    for target in $KEYBOARD_LEDS {
      print "set keyboard brightness to 2 for observation"
      write-brightness $target.device 2
      sleep ($delay_ms * 1ms)
      print $"write keyboard color ($target.color) through ($target.zone)"
      write-color $target.device $target.color
      sleep ($delay_ms * 1ms)
      assert-zone-colors $target.device $target.color $expected_colors
      print $"observe ($target.zone) for ($observe_ms)ms"
      sleep ($observe_ms * 1ms)
      $expected_colors = (
        $expected_colors
        | update color {|entry|
            if $entry.device == $target.device { $target.color } else { $entry.color }
          }
      )
    }

    if not $no_restore {
      restore-colors $initial_colors
      restore-keyboard-brightness $initial_brightness
      sleep ($delay_ms * 1ms)
      print "Restored initial keyboard colors and brightness."
    }

    print "Keyboard per-zone color behavior passed."
  } catch {|err|
    if not $no_restore {
      restore-colors $initial_colors
      restore-keyboard-brightness $initial_brightness
    }

    error make { msg: $err.msg }
  }
}
