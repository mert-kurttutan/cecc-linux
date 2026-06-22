#!/bin/bash

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "This script must be ran as root. Use 'sudo ./keyboard_color.sh <args>'"
  exit 1
fi

BASE_PATH="/sys/class/leds"

# Function to set color
set_color() {
    ZONE=$1
    COLOR=$2 # R G B
    
    case $ZONE in
        "left")   DEV="casper:rgb:kbd_zoned_backlight-left" ;;
        "middle") DEV="casper:rgb:kbd_zoned_backlight-middle" ;;
        "right")  DEV="casper:rgb:kbd_zoned_backlight-right" ;;
        "bias")   DEV="casper:rgb:biaslight" ;;
        "all")    DEV="all" ;;
        *) echo "Unknown zone: $ZONE"; return ;;
    esac

    if [ "$DEV" == "all" ]; then
        echo "$COLOR" > "$BASE_PATH/casper:rgb:kbd_zoned_backlight-left/multi_intensity" 2>/dev/null
        echo "2" > "$BASE_PATH/casper:rgb:kbd_zoned_backlight-left/brightness" 2>/dev/null
        
        echo "$COLOR" > "$BASE_PATH/casper:rgb:kbd_zoned_backlight-middle/multi_intensity" 2>/dev/null
        echo "2" > "$BASE_PATH/casper:rgb:kbd_zoned_backlight-middle/brightness" 2>/dev/null
        
        echo "$COLOR" > "$BASE_PATH/casper:rgb:kbd_zoned_backlight-right/multi_intensity" 2>/dev/null
        echo "2" > "$BASE_PATH/casper:rgb:kbd_zoned_backlight-right/brightness" 2>/dev/null
        
        echo "$COLOR" > "$BASE_PATH/casper:rgb:biaslight/multi_intensity" 2>/dev/null
        echo "2" > "$BASE_PATH/casper:rgb:biaslight/brightness" 2>/dev/null
        
        echo "Set all zones to $COLOR (Brightness: Max)"
    else
        echo "$COLOR" > "$BASE_PATH/$DEV/multi_intensity"
        echo "2" > "$BASE_PATH/$DEV/brightness"
        echo "Set $ZONE to $COLOR (Brightness: Max)"
    fi
}

echo "Usage: sudo ./keyboard_color.sh [zone] [r] [g] [b]"
echo "Zones: left, middle, right, bias, all"
echo "Example (Red): sudo ./keyboard_color.sh all 255 0 0"
echo ""

if [ -z "$1" ]; then
    exit 1
fi

ZONE=$1
R=${2:-255}
G=${3:-255}
B=${4:-255}

set_color "$ZONE" "$R $G $B"
