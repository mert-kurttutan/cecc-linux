#!/usr/bin/env nu

const profile_path = "/sys/firmware/acpi/platform_profile"
const choices_path = "/sys/firmware/acpi/platform_profile_choices"

const modes = [
  [mode, windows_id, platform_profile];
  [office, 2, low-power],
  [gaming, 1, balanced],
  [high-performance, 0, performance],
]

def read-file [path: string] {
  if ($path | path exists) {
    open --raw $path | str trim
  } else {
    null
  }
}

def read-int-file [path: string] {
  let value = read-file $path
  if ($value == null) or ($value == "") {
    null
  } else {
    $value | into int
  }
}

def read-profile [] {
  read-file $profile_path
}

def read-choices [] {
  let value = read-file $choices_path
  if ($value == null) {
    []
  } else {
    $value | split row " " | where {|choice| $choice != "" }
  }
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
      {
        name: ($path | path basename)
        type: (read-file ($path | path join "type"))
        online: (read-file ($path | path join "online"))
        status: (read-file ($path | path join "status"))
        capacity: (read-file ($path | path join "capacity"))
        power_now: (read-file ($path | path join "power_now"))
        voltage_now: (read-file ($path | path join "voltage_now"))
        current_now: (read-file ($path | path join "current_now"))
      }
    }
}

def summarize-khz [values: list<int>] {
  if ($values | is-empty) {
    return { count: 0, min_ghz: null, avg_ghz: null, max_ghz: null }
  }

  {
    count: ($values | length)
    min_ghz: ((($values | math min) / 1000000) | math round --precision 3)
    avg_ghz: ((($values | math avg) / 1000000) | math round --precision 3)
    max_ghz: ((($values | math max) / 1000000) | math round --precision 3)
  }
}

def khz-to-ghz [value] {
  if $value == null {
    null
  } else {
    (($value / 1000000) | math round --precision 3)
  }
}

def read-cpufreq-summary [] {
  let policies = (
    glob "/sys/devices/system/cpu/cpufreq/policy*"
    | each {|policy|
        {
          policy: ($policy | path basename)
          governor: (read-file ($policy | path join "scaling_governor"))
          epp: (read-file ($policy | path join "energy_performance_preference"))
          scaling_cur_khz: (read-int-file ($policy | path join "scaling_cur_freq"))
          scaling_min_khz: (read-int-file ($policy | path join "scaling_min_freq"))
          scaling_max_khz: (read-int-file ($policy | path join "scaling_max_freq"))
          cpuinfo_min_khz: (read-int-file ($policy | path join "cpuinfo_min_freq"))
          cpuinfo_max_khz: (read-int-file ($policy | path join "cpuinfo_max_freq"))
          bios_limit_khz: (read-int-file ($policy | path join "bios_limit"))
          base_frequency_khz: (read-int-file ($policy | path join "base_frequency"))
        }
      }
  )

  {
    policies: $policies
    scaling_cur: (summarize-khz ($policies | get scaling_cur_khz | compact))
    scaling_max: (summarize-khz ($policies | get scaling_max_khz | compact))
    cpuinfo_max: (summarize-khz ($policies | get cpuinfo_max_khz | compact))
    governors: ($policies | get governor | uniq)
    epp_values: ($policies | get epp | uniq)
  }
}

def read-rapl [] {
  if not ("/sys/class/powercap" | path exists) {
    return []
  }

  ls /sys/class/powercap
  | where type == dir
  | get name
  | where {|zone| ($zone | path basename) | str starts-with "intel-rapl:" }
  | each {|zone|
      let constraints = (
        glob ($zone | path join "constraint_*_power_limit_uw")
        | each {|limit_path|
            let stem = ($limit_path | path basename | str replace "_power_limit_uw" "")
            {
              constraint: $stem
              name: (read-file ($zone | path join $"($stem)_name"))
              power_limit_w: (do {
                let uw = read-int-file $limit_path
                if $uw == null { null } else { ($uw / 1000000) }
              })
              time_window_s: (do {
                let us = read-int-file ($zone | path join $"($stem)_time_window_us")
                if $us == null { null } else { ($us / 1000000) }
              })
            }
          }
      )

      {
        zone: ($zone | path basename)
        name: (read-file ($zone | path join "name"))
        enabled: (read-file ($zone | path join "enabled"))
        constraints: $constraints
      }
    }
}

def sample [label: string] {
  let profile = read-profile
  let choices = read-choices
  let supplies = read-power-supplies
  let cpufreq = read-cpufreq-summary
  let rapl = read-rapl

  print $"== ($label) =="
  print ([{
    platform_profile: $profile
    platform_profile_choices: ($choices | str join " ")
  }] | table)

  print "Power supplies:"
  if ($supplies | is-empty) {
    print "none"
  } else {
    print ($supplies | table --expand)
  }

  print "CPU frequency summary:"
  print ([
    [metric, count, min_ghz, avg_ghz, max_ghz];
    [scaling_cur, $cpufreq.scaling_cur.count, $cpufreq.scaling_cur.min_ghz, $cpufreq.scaling_cur.avg_ghz, $cpufreq.scaling_cur.max_ghz],
    [scaling_max, $cpufreq.scaling_max.count, $cpufreq.scaling_max.min_ghz, $cpufreq.scaling_max.avg_ghz, $cpufreq.scaling_max.max_ghz],
    [cpuinfo_max, $cpufreq.cpuinfo_max.count, $cpufreq.cpuinfo_max.min_ghz, $cpufreq.cpuinfo_max.avg_ghz, $cpufreq.cpuinfo_max.max_ghz],
  ] | table)

  print "CPU policies:"
  if ($cpufreq.policies | is-empty) {
    print "none"
  } else {
    print (
      $cpufreq.policies
      | each {|policy|
          {
            policy: $policy.policy
            governor: $policy.governor
            epp: $policy.epp
            cur_ghz: (khz-to-ghz $policy.scaling_cur_khz)
            min_ghz: (khz-to-ghz $policy.scaling_min_khz)
            max_ghz: (khz-to-ghz $policy.scaling_max_khz)
            cpuinfo_max_ghz: (khz-to-ghz $policy.cpuinfo_max_khz)
            bios_limit_ghz: (khz-to-ghz $policy.bios_limit_khz)
            base_ghz: (khz-to-ghz $policy.base_frequency_khz)
          }
        }
      | table
    )
  }

  print "RAPL:"
  if ($rapl | is-empty) {
    print "none"
  } else {
    print ($rapl | table --expand)
  }
}

def main [
  --settle-ms: int = 2000
] {
  let initial_profile = read-profile

  sample "initial"

  try {
    for row in $modes {
      print ""
      print $"## mode=($row.mode) windows_id=($row.windows_id) platform_profile=($row.platform_profile)"
      write-profile $row.platform_profile
      sleep ($settle_ms * 1ms)
      sample $"after setting ($row.mode)"
    }
  } catch {|err|
    print $"Restoring initial platform_profile after failure: ($initial_profile)"
    write-profile $initial_profile
    error make { msg: $err.msg }
  }

  print ""
  print $"Restoring initial platform_profile: ($initial_profile)"
  write-profile $initial_profile
  sample "restored"
}
