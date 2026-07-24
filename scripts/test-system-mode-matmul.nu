#!/usr/bin/env nu

const profile_path = "/sys/firmware/acpi/platform_profile"
const choices_path = "/sys/firmware/acpi/platform_profile_choices"
const bench_script = "scripts/matmul_bench.py"

const modes = [
  [mode, windows_id, platform_profile];
  [office, 2, low-power],
  [gaming, 1, balanced],
  [high-performance, 0, performance],
]

def ensure-path [path: string] {
  if not ($path | path exists) {
    error make { msg: $"Required path not found: ($path)" }
  }
}

def read-file [path: string] {
  open --raw $path | str trim
}

def read-choices [] {
  ensure-path $profile_path
  ensure-path $choices_path
  read-file $choices_path | split row " " | where {|choice| $choice != "" }
}

def read-profile [] {
  ensure-path $profile_path
  read-file $profile_path
}

def write-profile [profile: string] {
  let choices = read-choices
  if ($choices | any {|choice| $choice == $profile }) == false {
    error make {
      msg: $"Unsupported platform profile: ($profile)"
      help: $"Available choices: ($choices | str join ', ')"
    }
  }

  $profile | ^sudo tee $profile_path | ignore
}

def read-power-supplies [] {
  glob "/sys/class/power_supply/*"
  | each {|path|
      let name = ($path | path basename)
      let type_path = ($path | path join "type")
      let online_path = ($path | path join "online")
      let status_path = ($path | path join "status")
      let capacity_path = ($path | path join "capacity")

      {
        name: $name
        type: (if ($type_path | path exists) { read-file $type_path } else { null })
        online: (if ($online_path | path exists) { read-file $online_path } else { null })
        status: (if ($status_path | path exists) { read-file $status_path } else { null })
        capacity: (if ($capacity_path | path exists) { read-file $capacity_path } else { null })
      }
    }
}

def print-context [label: string] {
  print $"== ($label) =="
  print ({
    platform_profile: (read-profile)
    platform_profile_choices: (read-choices)
    power_supplies: (read-power-supplies)
  })
}

def run-benchmark [repeats: int] {
  ^uv run --script $bench_script --repeats $repeats
}

def main [
  --repeats: int = 3 # Timed repetitions per matrix size.
  --settle-ms: int = 2000 # Delay after switching profile before benchmarking.
] {
  ensure-path $bench_script
  ensure-path $profile_path
  ensure-path $choices_path

  let initial_profile = read-profile

  print-context "initial"

  try {
    for row in $modes {
      print ""
      print $"## mode=($row.mode) windows_id=($row.windows_id) platform_profile=($row.platform_profile)"

      write-profile $row.platform_profile
      sleep ($settle_ms * 1ms)

      let readback = read-profile
      if $readback != $row.platform_profile {
        error make {
          msg: $"platform_profile readback mismatch: expected ($row.platform_profile), got ($readback)"
        }
      }

      print-context $"before benchmark: ($row.mode)"
      run-benchmark $repeats
      print-context $"after benchmark: ($row.mode)"
    }
  } catch {|err|
    print ""
    print $"Restoring initial platform_profile after failure: ($initial_profile)"
    write-profile $initial_profile
    error make { msg: $err.msg }
  }

  print ""
  print $"Restoring initial platform_profile: ($initial_profile)"
  write-profile $initial_profile
  print-context "restored"
}
