# Support Information

When reporting a problem with Excalibur Control Center or `casper-wmi`, run
this command in a terminal and paste its complete output into your report:

```sh
excalibur-control-center-cli doctor
```

The report includes the app version, kernel version, DMI identity, CPU details,
Casper WMI devices, driver status, and detected LED and fan interfaces.

If the driver is missing or failed to load, also collect the filtered kernel
messages:

```sh
sudo excalibur-control-center-cli doctor --include-dmesg
```

Review the output before sharing it. The optional kernel messages can contain
other system details. Redact anything you do not want to share, but leave the
DMI `sys_vendor` and `product_name` fields intact when possible; they are used
to match the laptop model in the driver.
