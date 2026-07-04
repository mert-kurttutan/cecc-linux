#!/usr/bin/env nu

def is-nixos [] {
  ("/etc/NIXOS" | path exists) or ("/run/current-system/sw/bin/nixos-version" | path exists)
}

def nixos-kernel-build-dir [kernel_version: string] {
  let kdir = ($env.KDIR? | default "")

  if ($kdir != "") and (($kdir | path expand) | path exists) {
    return ($kdir | path expand)
  }

  error make {
    msg: $"Could not locate the NixOS kernel build tree for ($kernel_version)"
    help: "Enter the project dev shell with `nix develop`; flake.nix exports KDIR from the host NixOS kernel."
  }
}

def kernel-build-dir [] {
  let kernel_version = (^uname -r | str trim)

  if (is-nixos) {
    return (nixos-kernel-build-dir $kernel_version)
  }

  let kdir = $"/lib/modules/($kernel_version)/build"

  if ($kdir | path exists) {
    return $kdir
  }

  error make {
    msg: $"Could not locate the kernel build tree for ($kernel_version)"
    help: $"Expected ($kdir). Install the matching kernel headers for this kernel."
  }
}

def main [
  --driver-dir (-d): string = "./casper-wmi"
  --module-file (-f): string = "casper-wmi.ko"
  --module-name (-m): string = "casper_wmi"
] {
  let repo_dir = (pwd)
  let driver_dir = ($driver_dir | path expand)
  let kdir = (kernel-build-dir)
  let output_dir = ($repo_dir | path join ".reload" "casper-wmi")
  let module_path = ($output_dir | path join $module_file)

  if not ($driver_dir | path exists) {
    error make {
      msg: $"Driver directory not found: ($driver_dir)"
    }
  }

  print $"Building module in ($driver_dir)"
  print $"Using kernel build dir: ($kdir)"
  print $"Using local output dir: ($output_dir)"

  mkdir $output_dir

  cd $driver_dir
  ^make clean $"KDIR=($kdir)" $"OUT_DIR=($output_dir)"
  ^make $"KDIR=($kdir)" $"OUT_DIR=($output_dir)"

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

  print "Applying temporary dev permissions"
  do -i { ^sudo chmod a+rw /sys/class/leds/casper:rgb:kbd_zoned_backlight-*/brightness }
  do -i { ^sudo chmod a+rw /sys/class/leds/casper:rgb:kbd_zoned_backlight-*/multi_intensity }
  do -i { ^sudo chmod a+rw /sys/class/leds/casper:rgb:biaslight/brightness }
  do -i { ^sudo chmod a+rw /sys/class/leds/casper:rgb:biaslight/multi_intensity }

  print "Recent dmesg"
  let dmesg_output = (^sudo dmesg --color=never --ctime)
  $dmesg_output | lines | last 60 | str join (char nl) | print
}
