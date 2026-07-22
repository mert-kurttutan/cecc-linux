#!/usr/bin/env nu

const LED_ROOT = "/sys/class/leds"
const DEFAULT_LED = "casper:rgb:kbd_zoned_backlight-left"
const MODES = [
  [value, name, expected];
  [1, "static", "steady color"]
  [2, "blink", "unknown firmware blink-like mode"]
  [3, "breathing", "fade/breathing animation"]
  [4, "heartbeat", "unknown firmware heartbeat-like mode"]
  [5, "repeat", "unknown firmware repeat-like mode"]
  [6, "cycle", "color cycle or random animation"]
  [7, "ambilight", "ambilight-like mode if supported"]
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

def read-led-state [device: string] {
  {
    led: $device
    effect: (read-file-trimmed (led-file $device "effect"))
    brightness: (read-file-trimmed (led-file $device "brightness") | into int)
    color: (read-file-trimmed (led-file $device "multi_intensity"))
  }
}

def write-led-state [device: string brightness: int color: string] {
  write-file (led-file $device "multi_intensity") $color
  write-file (led-file $device "brightness") $brightness
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
      $MODES
    } else {
      let selected = (
        $MODES
        | where (($it.value | into string) == $mode) or ($it.name == $mode)
      )

      if ($selected | is-empty) {
        error make { msg: $"Unsupported mode ($mode). Supported modes: ($MODE_HELP)" }
      }

      $selected
    }

    for mode in $modes {
      print $"mode=($mode.value) (($mode.name)): expected ($mode.expected)"
      write-file (led-file $led "effect") $mode.value
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
      write-file (led-file $led "effect") $initial.effect
      write-led-state $led $initial.brightness $initial.color
    }

    print "LED mode observation test finished."
  } catch {|err|
    print "LED mode state after failure:"
    read-led-state $led | table | print

    if not $no_restore {
      write-file (led-file $led "effect") $initial.effect
      write-led-state $led $initial.brightness $initial.color
    }

    error make { msg: $err.msg }
  }
}
