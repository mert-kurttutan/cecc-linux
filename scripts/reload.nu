#!/usr/bin/env nu

def resolve-kdir [kernel_dir: string] {
  let kernel_version = (^uname -r | str trim)
  let direct_candidates = [
    $kernel_dir
    ($env.KDIR? | default "")
    $"/lib/modules/($kernel_version)/build"
    $"/run/current-system/kernel-modules/lib/modules/($kernel_version)/build"
  ]

  let direct_hit = (
    $direct_candidates
    | where {|candidate| ($candidate != "") and (($candidate | path expand) | path exists) }
    | each {|candidate| $candidate | path expand }
    | get 0?
  )

  if $direct_hit != null {
    return $direct_hit
  }

  let store_hits = (glob $"/nix/store/*-linux-($kernel_version)-dev/lib/modules/($kernel_version)/build")
  if ($store_hits | length) > 0 {
    return ($store_hits | get 0)
  }

  error make {
    msg: $"Could not locate the kernel build tree for ($kernel_version)"
    help: "Pass --kernel-dir /path/to/build or export KDIR before running reload.nu"
  }
}

def main [
  --kernel-dir (-k): string = ""
  --driver-dir (-d): string = "./casper-wmi"
  --module-file (-f): string = "casper-wmi.ko"
  --module-name (-m): string = "casper_wmi"
  --log-lines (-n): int = 60
] {
  let driver_dir = ($driver_dir | path expand)
  let kdir = (resolve-kdir $kernel_dir)
  let module_path = ($driver_dir | path join $module_file)

  if not ($driver_dir | path exists) {
    error make {
      msg: $"Driver directory not found: ($driver_dir)"
    }
  }

  print $"Building module in ($driver_dir)"
  print $"Using kernel build dir: ($kdir)"

  cd $driver_dir
  ^make clean $"KDIR=($kdir)"
  ^make $"KDIR=($kdir)"

  if not ($module_path | path exists) {
    error make {
      msg: $"Built module not found: ($module_path)"
    }
  }

  print "Authenticating sudo once"
  ^sudo -v

  print "Unloading previous module if present"
  do -i { ^sudo modprobe -r casper-wmi }
  do -i { ^sudo rmmod $module_name }

  print "Loading dependencies"
  ^sudo modprobe wmi
  ^sudo modprobe platform_profile
  ^sudo modprobe led_class_multicolor

  print $"Loading ($module_path)"
  ^sudo insmod $module_path

  print "Recent dmesg"
  let dmesg_output = (^sudo dmesg --color=never --ctime)
  $dmesg_output | lines | last $log_lines | str join (char nl) | print
}
