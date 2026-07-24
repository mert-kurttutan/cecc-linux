#!/usr/bin/env nu

const LED_ROOT = "/sys/class/leds"
const LEDS = [
  "casper:rgb:kbd_zoned_backlight-left"
  "casper:rgb:kbd_zoned_backlight-middle"
  "casper:rgb:kbd_zoned_backlight-right"
  "casper:rgb:biaslight"
]

def led-path [name: string file: string] {
  $LED_ROOT | path join $name $file
}

def read-brightness [] {
  $LEDS
  | each {|name|
      let path = (led-path $name "brightness")
      {
        led: $name
        brightness: (if ($path | path exists) { open $path | str trim } else { "missing" })
      }
    }
}

def print-readback [label: string] {
  print $"== ($label) =="
  read-brightness | table | print
}

def write-brightness [name: string brightness: int] {
  let path = (led-path $name "brightness")

  if not ($path | path exists) {
    error make { msg: $"LED brightness path not found: ($path)" }
  }

  print $"write ($brightness) -> ($name)"
  $brightness | save --force $path
}

def main [
  --delay-ms: int = 300
] {
  print-readback "initial"

  for brightness in [0 1 2] {
    for led in $LEDS {
      print ""
      write-brightness $led $brightness
      print-readback "immediate readback"
      sleep ($delay_ms * 1ms)
      print-readback $"after ($delay_ms)ms"
    }
  }
}
