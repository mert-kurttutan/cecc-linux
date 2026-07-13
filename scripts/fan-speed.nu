#!/usr/bin/env nu

def read-file [path: string] {
  if ($path | path exists) {
    open --raw $path | str trim
  } else {
    null
  }
}

def fan-label [input_path: string] {
  let label_path = ($input_path | str replace "_input" "_label")
  let label = (read-file $label_path)

  if ($label == null) {
    $input_path | path basename | str replace "_input" ""
  } else {
    $label
  }
}

def main [] {
  let fan_inputs = (
    ls /sys/class/hwmon
    | where name =~ 'hwmon[0-9]+$'
    | each {|hwmon| glob ($hwmon.name | path join "fan*_input") }
    | flatten
  )

  if ($fan_inputs | is-empty) {
    print "No hwmon fan RPM inputs found under /sys/class/hwmon."
    print "This usually means the laptop/driver does not expose fan tachometer values."
    return
  }

  $fan_inputs
  | each {|input|
      let hwmon_dir = ($input | path dirname)
      let rpm = (read-file $input)

      {
        chip: (read-file ($hwmon_dir | path join "name")),
        fan: (fan-label $input),
        rpm: (if ($rpm == null or $rpm == "") { null } else { $rpm | into int }),
        path: $input,
      }
    }
  | sort-by chip fan
}
