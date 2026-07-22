#!/usr/bin/env nu

let group = ($env.CASPER_LED_GROUP? | default "wheel")
let leds = [
  "/sys/class/leds/casper:rgb:kbd_zoned_backlight-left"
  "/sys/class/leds/casper:rgb:kbd_zoned_backlight-middle"
  "/sys/class/leds/casper:rgb:kbd_zoned_backlight-right"
  "/sys/class/leds/casper:rgb:biaslight"
]

print $"Granting ($group) write access to Casper LED sysfs nodes"

for led in $leds {
  sudo chgrp $group ($led | path join "brightness")
  sudo chmod g+w ($led | path join "brightness")

  sudo chgrp $group ($led | path join "effect")
  sudo chmod g+w ($led | path join "effect")

  sudo chgrp $group ($led | path join "multi_intensity")
  sudo chmod g+w ($led | path join "multi_intensity")
}

print "Done."
print "Verify with:"
print "ls -l /sys/class/leds/casper:rgb:*/*"
