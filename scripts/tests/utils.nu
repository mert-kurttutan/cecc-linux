export const LED_ROOT = "/sys/class/leds"
export const KEYBOARD_LED_DEVICES = [
  "casper:rgb:kbd_zoned_backlight-left"
  "casper:rgb:kbd_zoned_backlight-middle"
  "casper:rgb:kbd_zoned_backlight-right"
]
export const BIASLIGHT_DEVICE = "casper:rgb:biaslight"
export const ALL_LED_DEVICES = [
  "casper:rgb:kbd_zoned_backlight-left"
  "casper:rgb:kbd_zoned_backlight-middle"
  "casper:rgb:kbd_zoned_backlight-right"
  "casper:rgb:biaslight"
]
export const LED_EFFECT_MODES = [
  [value, name, expected];
  [1, "static", "steady color"]
  [2, "blink", "unknown firmware blink-like mode"]
  [3, "breathing", "fade/breathing animation"]
  [4, "heartbeat", "unknown firmware heartbeat-like mode"]
  [5, "repeat", "unknown firmware repeat-like mode"]
  [6, "cycle", "color cycle or random animation"]
  [7, "ambilight", "ambilight-like mode if supported"]
]
export const LED_EFFECT_MODE_HELP = "static/1, blink/2, breathing/3, heartbeat/4, repeat/5, cycle/6, ambilight/7"

export const SYSTEM_MODES = [
  [mode, windows_id, platform_profile];
  [office, 2, low-power],
  [gaming, 1, balanced],
  [high-performance, 0, performance],
]

export const PLATFORM_PROFILE_PATH = "/sys/firmware/acpi/platform_profile"
export const PLATFORM_PROFILE_CHOICES_PATH = "/sys/firmware/acpi/platform_profile_choices"

export def led-file [device: string file: string] {
  $LED_ROOT | path join $device $file
}

export def ensure-path [path: string] {
  if not ($path | path exists) {
    error make { msg: $"Required path not found: ($path)" }
  }

  $path
}

export def read-file-trimmed [path: string] {
  open (ensure-path $path) | str trim
}

export def read-optional-file [path: string] {
  if ($path | path exists) {
    open --raw $path | str trim
  } else {
    null
  }
}

export def write-file [path: string value: any --sudo] {
  let target = (ensure-path $path)
  let content = ($value | into string)

  if $sudo {
    $content | ^sudo tee $target | ignore
  } else {
    $content | save --force $target
  }
}

export def resolve-effect-mode [mode: string] {
  let selected = (
    $LED_EFFECT_MODES
    | where (($it.value | into string) == $mode) or ($it.name == $mode)
  )

  if ($selected | is-empty) {
    error make { msg: $"Unsupported mode ($mode). Supported modes: ($LED_EFFECT_MODE_HELP)" }
  }

  $selected.0
}

export def read-platform-profile [] {
  read-file-trimmed $PLATFORM_PROFILE_PATH
}

export def read-platform-profile-choices [] {
  read-file-trimmed $PLATFORM_PROFILE_CHOICES_PATH
  | split row --regex '\s+'
  | where {|choice| $choice != "" }
}

export def write-platform-profile [profile: string --sudo] {
  let choices = (read-platform-profile-choices)

  if ($choices | any {|choice| $choice == $profile }) == false {
    error make {
      msg: $"Unsupported platform profile: ($profile)"
      help: $"Available choices: ($choices | str join ', ')"
    }
  }

  if $sudo {
    write-file $PLATFORM_PROFILE_PATH $profile --sudo
  } else {
    write-file $PLATFORM_PROFILE_PATH $profile
  }
  read-platform-profile
}
