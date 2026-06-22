#!/usr/bin/env nu

const base_path = "/sys/class/leds"

def zones-map [] {
  {
    left: "casper:rgb:kbd_zoned_backlight-left"
    middle: "casper:rgb:kbd_zoned_backlight-middle"
    right: "casper:rgb:kbd_zoned_backlight-right"
    bias: "casper:rgb:biaslight"
  }
}

def zone-names [] {
  zones-map | columns
}

def resolve-zone-devices [zone: string] {
  let zones = (zones-map)

  if $zone == "all" {
    return [
      $zones.left
      $zones.middle
      $zones.right
      $zones.bias
    ]
  }

  let device = ($zones | get --optional $zone)
  if $device == null {
    error make {
      msg: $"Unknown zone: ($zone)"
      help: $"Use one of: (($zones | columns | append all | str join ', '))"
    }
  }

  [ $device ]
}

def device-path [device: string] {
  $base_path | path join $device
}

def ensure-device [device: string] {
  let path = (device-path $device)
  if not ($path | path exists) {
    error make {
      msg: $"LED device not found: ($device)"
      help: $"Expected path: ($path)"
    }
  }
}

def read-zone [zone: string] {
  let zones = (zones-map)
  let device = ($zones | get $zone)
  ensure-device $device

  let path = (device-path $device)

  {
    zone: $zone
    device: $device
    brightness: (open ($path | path join "brightness") | str trim | into int)
    max_brightness: (open ($path | path join "max_brightness") | str trim | into int)
    multi_intensity: (open ($path | path join "multi_intensity") | str trim)
  }
}

def write-brightness [device: string, level: int] {
  ensure-device $device
  let path = (device-path $device)
  let max = (open ($path | path join "max_brightness") | str trim | into int)

  if $level < 0 or $level > $max {
    error make {
      msg: $"Brightness ($level) out of range for ($device)"
      help: $"Allowed range: 0..($max)"
    }
  }

  let brightness_path = ($path | path join "brightness")
  ($level | into string) | ^sudo tee $brightness_path | ignore
}

def write-color [device: string, red: int, green: int, blue: int] {
  ensure-device $device

  for value in [$red $green $blue] {
    if $value < 0 or $value > 255 {
      error make {
        msg: $"RGB value ($value) out of range for ($device)"
        help: "Allowed range: 0..255"
      }
    }
  }

  let path = (device-path $device)
  let color_path = ($path | path join "multi_intensity")
  let payload = $"($red) ($green) ($blue)"
  $payload | ^sudo tee $color_path | ignore
}

def api-list [] {
  [
    (read-zone left)
    (read-zone middle)
    (read-zone right)
    (read-zone bias)
  ]
}

def api-get [zone: string] {
  if $zone == "all" {
    return (api-list)
  }

  read-zone $zone
}

def api-set-brightness [zone: string, level: int] {
  let devices = (resolve-zone-devices $zone)
  $devices | each {|device| write-brightness $device $level }
  api-get $zone
}

def api-set-color [zone: string, red: int, green: int, blue: int] {
  let devices = (resolve-zone-devices $zone)
  $devices | each {|device| write-color $device $red $green $blue }
  api-get $zone
}

def main [
  command?: string
  zone?: string
  arg1?: int
  arg2?: int
  arg3?: int
] {
  match ($command | default "list") {
    "list" => { api-list }
    "get" => { api-get ($zone | default "all") }
    "set" => {
      if $zone == null or $arg1 == null {
        error make {
          msg: "Usage: ./scripts/kbdctl.nu set <zone> <level>"
          help: "Example: ./scripts/kbdctl.nu set left 2"
        }
      }

      api-set-brightness $zone $arg1
    }
    "set-color" => {
      if $zone == null or $arg1 == null or $arg2 == null or $arg3 == null {
        error make {
          msg: "Usage: ./scripts/kbdctl.nu set-color <zone> <r> <g> <b>"
          help: "Example: ./scripts/kbdctl.nu set-color left 255 0 0"
        }
      }

      api-set-color $zone $arg1 $arg2 $arg3
    }
    "help" => {
      print "kbdctl.nu"
      print "  ./scripts/kbdctl.nu list"
      print "  ./scripts/kbdctl.nu get [zone|all]"
      print "  ./scripts/kbdctl.nu set <zone|all> <level>"
      print "  ./scripts/kbdctl.nu set-color <zone|all> <r> <g> <b>"
      print "zones: left, middle, right, bias, all"
      print "writes use sudo"
    }
    _ => {
      error make {
        msg: $"Unknown command: ($command)"
        help: "Use: list, get, set, help"
      }
    }
  }
}
