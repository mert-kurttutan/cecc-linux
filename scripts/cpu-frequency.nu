#!/usr/bin/env nu

def read-file [path: string] {
  if ($path | path exists) {
    open --raw $path | str trim
  } else {
    null
  }
}

def summarize-ghz [values: list<float>] {
  if ($values | is-empty) {
    return {
      count: 0,
      avg_ghz: null,
      min_ghz: null,
      max_ghz: null,
    }
  }

  {
    count: ($values | length),
    avg_ghz: (($values | math avg) | math round --precision 3),
    min_ghz: (($values | math min) | math round --precision 3),
    max_ghz: (($values | math max) | math round --precision 3),
  }
}

def read-cpuinfo-cur-freq [] {
  glob "/sys/devices/system/cpu/cpufreq/policy*/cpuinfo_cur_freq"
  | each {|path|
      let khz = (read-file $path)

      if ($khz == null or $khz == "") {
        null
      } else {
        {
          source: "cpufreq cpuinfo_cur_freq",
          cpu: ($path | path dirname | path basename | str replace "policy" ""),
          ghz: (($khz | into float) / 1000000),
          path: $path,
        }
      }
    }
  | compact
}

def read-scaling-cur-freq [] {
  glob "/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq"
  | each {|path|
      let khz = (read-file $path)

      if ($khz == null or $khz == "") {
        null
      } else {
        {
          source: "cpufreq scaling_cur_freq",
          cpu: (($path | path dirname | path dirname | path basename) | str replace "cpu" ""),
          ghz: (($khz | into float) / 1000000),
          path: $path,
        }
      }
    }
  | compact
}

def read-proc-cpuinfo [] {
  if not ("/proc/cpuinfo" | path exists) {
    return []
  }

  open --raw /proc/cpuinfo
  | lines
  | where {|line| $line =~ '^cpu MHz\s*:' }
  | enumerate
  | each {|entry|
      let mhz = ($entry.item | split row ":" | get 1 | str trim | into float)

      {
        source: "/proc/cpuinfo",
        cpu: $entry.index,
        ghz: ($mhz / 1000),
        path: "/proc/cpuinfo",
      }
    }
}

def main [
  --details (-d)
] {
  let cpuinfo_cur = (read-cpuinfo-cur-freq)
  let scaling_cur = (read-scaling-cur-freq)
  let cpuinfo = (read-proc-cpuinfo)

  let summary = [
    ({ source: "cpufreq cpuinfo_cur_freq" } | merge (summarize-ghz ($cpuinfo_cur | get ghz))),
    ({ source: "cpufreq scaling_cur_freq" } | merge (summarize-ghz ($scaling_cur | get ghz))),
    ({ source: "/proc/cpuinfo" } | merge (summarize-ghz ($cpuinfo | get ghz))),
  ]

  print $summary

  if $details {
    print ""
    print "cpufreq cpuinfo_cur_freq details"
    print $cpuinfo_cur
    print ""
    print "cpufreq scaling_cur_freq details"
    print $scaling_cur
    print ""
    print "/proc/cpuinfo details"
    print $cpuinfo
  }
}
