# Debugging Model Support

Use these commands when a user reports that an Excalibur model is not
supported. They collect the installed app version, DMI identity, WMI devices,
driver logs, and sysfs interfaces exposed by `casper-wmi`.

## Version

```console
excalibur-control-center-cli --version
excalibur-control-center 0.1.29
```

## Hardware And Driver Diagnostics

```sh
cat /sys/class/dmi/id/sys_vendor
cat /sys/class/dmi/id/product_name
cat /sys/class/dmi/id/product_version
sudo dmidecode -s system-manufacturer
sudo dmidecode -s system-product-name
sudo dmidecode -s system-version
ls /sys/bus/wmi/devices
sudo dmesg | grep -iE 'casper|wmi|excalibur'
ls /sys/class/leds | grep -i casper
ls /sys/module/casper_wmi/parameters 2>/dev/null
```

Ask the reporter to include the installation method and package/release version
they used. If the DMI strings differ from the driver's match table, add or
adjust the DMI match. If the Casper WMI GUID is missing, support likely needs
model-specific firmware investigation.
