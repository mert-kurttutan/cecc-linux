#!/usr/bin/env nu

const profile_path = "/sys/firmware/acpi/platform_profile"
const choices_path = "/sys/firmware/acpi/platform_profile_choices"

const modes = [
  [mode, windows_id, platform_profile];
  [office, 2, low-power],
  [gaming, 1, balanced],
  [high-performance, 0, performance],
]

def ensure-profile-support [] {
  if not ($profile_path | path exists) {
    error make {
      msg: "platform_profile is not available"
      help: "The kernel or platform driver did not expose /sys/firmware/acpi/platform_profile"
    }
  }

  if not ($choices_path | path exists) {
    error make {
      msg: "platform_profile_choices is not available"
      help: "The kernel did not expose available platform profile choices"
    }
  }
}

def read-file [path: string] {
  open --raw $path | str trim
}

def read-choices [] {
  ensure-profile-support
  read-file $choices_path | split row " " | where {|choice| $choice != "" }
}

def read-current-profile [] {
  ensure-profile-support
  read-file $profile_path
}

def mode-row [mode: string] {
  let normalized = ($mode | str trim | str lowercase | str replace "_" "-")
  let matches = ($modes | where mode == $normalized)

  if ($matches | is-empty) {
    error make {
      msg: $"Unknown system mode: ($mode)"
      help: $"Available modes: ($modes | get mode | str join ', ')"
    }
  }

  $matches | first
}

def ensure-supported-profile [profile: string] {
  let choices = read-choices

  if ($choices | any {|choice| $choice == $profile }) == false {
    error make {
      msg: $"Unsupported platform profile for this machine: ($profile)"
      help: $"Available choices: ($choices | str join ', ')"
    }
  }
}

def write-profile [profile: string] {
  ensure-supported-profile $profile
  $profile | ^sudo tee $profile_path | ignore
}

def show-state [] {
  let current = read-current-profile
  let choices = read-choices
  let mapped_mode = (
    $modes
    | where platform_profile == $current
    | get mode?
    | default []
  )

  {
    current_platform_profile: $current
    current_mapped_mode: (if ($mapped_mode | is-empty) { null } else { $mapped_mode | first })
    choices: $choices
    mapping: $modes
  }
}

def apply-mode [mode: string] {
  let row = mode-row $mode

  print $"Applying system mode: ($row.mode)"
  print $"Windows/decompiled mode id: ($row.windows_id)"
  print $"Linux platform_profile target: ($row.platform_profile)"

  write-profile $row.platform_profile

  let readback = read-current-profile
  if $readback != $row.platform_profile {
    error make {
      msg: $"platform_profile readback mismatch: expected ($row.platform_profile), got ($readback)"
    }
  }

  show-state
}

def main [
  command?: string # get, list, set, test
  mode?: string # office, gaming, high-performance
] {
  match ($command | default "get") {
    "get" => { show-state }
    "list" => { $modes }
    "set" => {
      if $mode == null {
        error make {
          msg: "Usage: ./scripts/system-mode.nu set <mode>"
          help: "Example: ./scripts/system-mode.nu set gaming"
        }
      }

      apply-mode $mode
    }
    "test" => {
      let initial = read-current-profile
      print $"Initial platform_profile: ($initial)"

      try {
        for row in $modes {
          print ""
          apply-mode $row.mode
        }
      } catch {|err|
        write-profile $initial
        error make { msg: $err.msg }
      }

      print ""
      print $"Restoring initial platform_profile: ($initial)"
      write-profile $initial
      show-state
    }
    "help" => {
      print "system-mode.nu"
      print "  ./scripts/system-mode.nu get"
      print "  ./scripts/system-mode.nu list"
      print "  ./scripts/system-mode.nu set <office|gaming|high-performance>"
      print "  ./scripts/system-mode.nu test"
    }
    _ => {
      error make {
        msg: $"Unknown command: ($command)"
        help: "Use: get, list, set, test, help"
      }
    }
  }
}
