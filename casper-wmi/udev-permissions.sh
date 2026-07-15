#!/usr/bin/env bash
set -euo pipefail

GROUP="${EXCALIBUR_GROUP:-excalibur}"
LED_ROOT="/sys/class/leds"
GPU_MODE_PATH="/sys/module/casper_wmi/parameters/gpu_mode"

apply_file() {
  local path="$1"

  [ -e "$path" ] || return 0
  chgrp "$GROUP" "$path" 2>/dev/null || true
  chmod g+rw "$path" 2>/dev/null || true
}

apply_led() {
  local led_name="$1"

  case "$led_name" in
    casper:rgb:*) ;;
    *) return 0 ;;
  esac

  apply_file "$LED_ROOT/$led_name/brightness"
  apply_file "$LED_ROOT/$led_name/multi_intensity"
}

apply_all_leds() {
  local led_path

  for led_path in "$LED_ROOT"/casper:rgb:*; do
    [ -e "$led_path" ] || continue
    apply_led "$(basename "$led_path")"
  done
}

apply_module() {
  apply_file "$GPU_MODE_PATH"
}

case "${1:-all}" in
  leds)
    apply_led "${2:-}"
    ;;
  module)
    apply_module
    ;;
  all)
    apply_all_leds
    apply_module
    ;;
  *)
    echo "usage: $0 [all|leds <name>|module]" >&2
    exit 2
    ;;
esac
