#!/usr/bin/env nu

use ./utils.nu *

def benchmark-script [] {
  $env.FILE_PWD | path join ".." "matmul_bench.py" | path expand
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
        type: (read-optional-file $type_path)
        online: (read-optional-file $online_path)
        status: (read-optional-file $status_path)
        capacity: (read-optional-file $capacity_path)
      }
    }
}

def print-context [label: string] {
  print $"== ($label) =="
  print ({
    platform_profile: (read-platform-profile)
    platform_profile_choices: (read-platform-profile-choices)
    power_supplies: (read-power-supplies)
  })
}

def run-benchmark [script_path: string repeats: int] {
  ^uv run --script $script_path --repeats $repeats
}

def main [
  --repeats: int = 3 # Timed repetitions per matrix size.
  --settle-ms: int = 2000 # Delay after switching profile before benchmarking.
] {
  let bench_script = (benchmark-script)
  ensure-path $bench_script
  ensure-path $PLATFORM_PROFILE_PATH
  ensure-path $PLATFORM_PROFILE_CHOICES_PATH

  let initial_profile = read-platform-profile

  print-context "initial"

  try {
    for row in $SYSTEM_MODES {
      print ""
      print $"## mode=($row.mode) windows_id=($row.windows_id) platform_profile=($row.platform_profile)"

      write-platform-profile $row.platform_profile --sudo
      sleep ($settle_ms * 1ms)

      let readback = read-platform-profile
      if $readback != $row.platform_profile {
        error make {
          msg: $"platform_profile readback mismatch: expected ($row.platform_profile), got ($readback)"
        }
      }

      print-context $"before benchmark: ($row.mode)"
      run-benchmark $bench_script $repeats
      print-context $"after benchmark: ($row.mode)"
    }
  } catch {|err|
    print ""
    print $"Restoring initial platform_profile after failure: ($initial_profile)"
    write-platform-profile $initial_profile --sudo
    error make { msg: $err.msg }
  }

  print ""
  print $"Restoring initial platform_profile: ($initial_profile)"
  write-platform-profile $initial_profile --sudo
  print-context "restored"
}
