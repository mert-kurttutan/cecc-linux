#!/usr/bin/env nu

use ./utils.nu *

const DEFAULT_LED = "casper:rgb:kbd_zoned_backlight-left"

def read-led-state [device: string] {
  {
    led: $device
    effect: (read-file-trimmed (led-file $device "effect"))
    brightness: (read-file-trimmed (led-file $device "brightness") | into int)
    color: (read-file-trimmed (led-file $device "multi_intensity"))
  }
}

def write-led-state [device: string brightness: int color: string] {
  write-file (led-file $device "multi_intensity") $color --sudo
  write-file (led-file $device "brightness") $brightness --sudo
}

def main [
  --led: string = $DEFAULT_LED
  --mode: string
  --brightness: int = 2
  --color: string = "255 0 0"
  --pause
  --delay-sec: int = 5
  --no-restore
] {
  ensure-path (led-file $led "effect") | ignore
  ensure-path (led-file $led "brightness") | ignore
  ensure-path (led-file $led "multi_intensity") | ignore

  let initial = (read-led-state $led)

  print "Initial LED mode test state:"
  $initial | table | print
  print $"Testing ($led) with brightness=($brightness), color='($color)'"

  try {
    let modes = if ($mode | is-empty) {
      $LED_EFFECT_MODES
    } else {
      let selected = (
        $LED_EFFECT_MODES
        | where (($it.value | into string) == $mode) or ($it.name == $mode)
      )

      if ($selected | is-empty) {
        error make { msg: $"Unsupported mode ($mode). Supported modes: ($LED_EFFECT_MODE_HELP)" }
      }

      $selected
    }

    for mode in $modes {
      print $"mode=($mode.value) (($mode.name)): expected ($mode.expected)"
      write-file (led-file $led "effect") $mode.value --sudo
      write-led-state $led $brightness $color
      read-led-state $led | table | print

      if $pause {
        input "Observe the physical lighting, then press Enter to continue."
      } else {
        sleep ($delay_sec * 1sec)
      }
    }

    if not $no_restore {
      print "Restoring initial effect, brightness, and color."
      write-file (led-file $led "effect") $initial.effect --sudo
      write-led-state $led $initial.brightness $initial.color
    }

    print "LED mode observation test finished."
  } catch {|err|
    print "LED mode state after failure:"
    read-led-state $led | table | print

    if not $no_restore {
      write-file (led-file $led "effect") $initial.effect --sudo
      write-led-state $led $initial.brightness $initial.color
    }

    error make { msg: $err.msg }
  }
}
