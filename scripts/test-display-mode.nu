#!/usr/bin/env nu

use std/assert

const GPU_MODE_PATH = "/sys/module/casper_wmi/parameters/gpu_mode"
const MODE_CASES = [
  { input: "hybrid", expected: "hybrid" }
  { input: "discrete", expected: "discrete" }
  { input: "uma", expected: "uma" }
  { input: "1", expected: "hybrid" }
  { input: "2", expected: "discrete" }
  { input: "3", expected: "uma" }
]

def ensure-gpu-mode-path [] {
  if not ($GPU_MODE_PATH | path exists) {
    error make {
      msg: $"GPU mode sysfs parameter not found: ($GPU_MODE_PATH)"
      help: "Load the casper_wmi module and apply sysfs permissions first."
    }
  }
}

def read-gpu-mode [] {
  ensure-gpu-mode-path
  open $GPU_MODE_PATH | str trim
}

def write-gpu-mode [mode: string] {
  ensure-gpu-mode-path
  $mode | save --force $GPU_MODE_PATH
}

def assert-gpu-mode [expected: string] {
  let actual = (read-gpu-mode)
  assert equal $actual $expected $"gpu_mode readback should be ($expected)"
}

def print-readback [label: string] {
  print $"== ($label) =="
  print $"gpu_mode=(read-gpu-mode)"
}

def main [
  --delay-ms: int = 500
  --no-restore
  --names-only
  --numeric-only
] {
  if $names_only and $numeric_only {
    error make { msg: "Use only one of --names-only or --numeric-only" }
  }

  let initial_mode = (read-gpu-mode)
  let cases = if $names_only {
    $MODE_CASES | where input in ["hybrid" "discrete" "uma"]
  } else if $numeric_only {
    $MODE_CASES | where input in ["1" "2" "3"]
  } else {
    $MODE_CASES
  }

  print-readback "initial"

  try {
    for case in $cases {
      print $"write gpu_mode=($case.input), expect readback=($case.expected)"
      write-gpu-mode $case.input
      sleep ($delay_ms * 1ms)
      print-readback $"after write ($case.input)"
      assert-gpu-mode $case.expected
    }

    if not $no_restore {
      print $"restore gpu_mode=($initial_mode)"
      write-gpu-mode $initial_mode
      sleep ($delay_ms * 1ms)
      print-readback "after restore"
      assert-gpu-mode $initial_mode
    }

    print "Display mode sysfs behavior passed."
  } catch {|err|
    print "Display mode state after failure:"
    print-readback "failure"

    if not $no_restore {
      write-gpu-mode $initial_mode
    }

    error make { msg: $err.msg }
  }
}
