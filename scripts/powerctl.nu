#!/usr/bin/env nu

const profile_path = "/sys/firmware/acpi/platform_profile"
const choices_path = "/sys/firmware/acpi/platform_profile_choices"

def ensure-profile-support [] {
  if not ($profile_path | path exists) {
    error make {
      msg: "platform_profile is not available"
      help: "The casper-wmi driver or kernel platform_profile support may not be loaded"
    }
  }

  if not ($choices_path | path exists) {
    error make {
      msg: "platform_profile_choices is not available"
      help: "The kernel did not expose available profile choices"
    }
  }
}

def read-choices [] {
  ensure-profile-support
  open $choices_path | str trim | split row " " | where {|it| $it != "" }
}

def read-current-profile [] {
  ensure-profile-support
  open $profile_path | str trim
}

def api-list [] {
  {
    current: (read-current-profile)
    choices: (read-choices)
  }
}

def api-get [] {
  api-list
}

def api-set [profile: string] {
  let choices = (read-choices)

  if ($choices | any {|choice| $choice == $profile }) == false {
    error make {
      msg: $"Unsupported profile: ($profile)"
      help: $"Available choices: ($choices | str join ', ')"
    }
  }

  $profile | ^sudo tee $profile_path | ignore
  api-list
}

def main [
  command?: string
  profile?: string
] {
  match ($command | default "get") {
    "list" => { api-list }
    "get" => { api-get }
    "set" => {
      if $profile == null {
        error make {
          msg: "Usage: ./scripts/powerctl.nu set <profile>"
          help: "Example: ./scripts/powerctl.nu set performance"
        }
      }

      api-set $profile
    }
    "help" => {
      print "powerctl.nu"
      print "  ./scripts/powerctl.nu list"
      print "  ./scripts/powerctl.nu get"
      print "  ./scripts/powerctl.nu set <profile>"
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
