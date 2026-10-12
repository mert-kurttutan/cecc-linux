#!/usr/bin/env bash
set -euo pipefail

if command -v udevadm >/dev/null 2>&1; then
  udevadm control --reload-rules || true
fi
