#!/usr/bin/env bash
set -euo pipefail

GROUP="excalibur"
LED_ROOT="/sys/class/leds"
GPU_MODE_PATH="/sys/module/casper_wmi/parameters/gpu_mode"
PLATFORM_PROFILE_PATH="/sys/firmware/acpi/platform_profile"

apply_file() {
  local path="$1"

  [ -e "$path" ] || return 0
  chgrp "$GROUP" "$path" 2>/dev/null || true
  chmod g+rw "$path" 2>/dev/null || true
}

apply_all_leds() {
  local led_path led_name

  for led_path in "$LED_ROOT"/casper:rgb:*; do
    [ -e "$led_path" ] || continue
    led_name="$(basename "$led_path")"
    apply_file "$LED_ROOT/$led_name/brightness"
    apply_file "$LED_ROOT/$led_name/effect"
    apply_file "$LED_ROOT/$led_name/multi_intensity"
  done
}

case "${1:-all}" in
  leds)
    led_name="${2:-}"
    case "$led_name" in
      casper:rgb:*)
        apply_file "$LED_ROOT/$led_name/brightness"
        apply_file "$LED_ROOT/$led_name/effect"
        apply_file "$LED_ROOT/$led_name/multi_intensity"
        ;;
    esac
    ;;
  module)
    apply_file "$GPU_MODE_PATH"
    ;;
  platform)
    apply_file "$PLATFORM_PROFILE_PATH"
    ;;
  all)
    apply_all_leds
    apply_file "$GPU_MODE_PATH"
    apply_file "$PLATFORM_PROFILE_PATH"
    ;;
  *)
    echo "usage: $0 [all|leds <name>|module|platform]" >&2
    exit 2
    ;;
esac
