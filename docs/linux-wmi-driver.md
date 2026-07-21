# Linux Driver And WMI Notes

This document summarizes the moving parts behind the `casper-wmi` kernel
driver and how it talks to Casper Excalibur firmware from Linux.

## Linux Driver Basics

A Linux driver is kernel code that binds to a hardware or firmware interface and
exposes a normal Linux interface to userspace. Userspace should not need to know
the vendor-specific firmware protocol. It should interact through standard
interfaces such as:

- `/sys/class/leds/...` for LED brightness and RGB color.
- `/sys/class/hwmon/...` for fan speed and sensor data.
- `/sys/firmware/acpi/platform_profile` or platform-profile APIs for power
  profile control.
- `/sys/module/.../parameters/...` for module parameters.

For an out-of-tree module like `casper-wmi`, the source is compiled against the
currently running kernel's build tree. The produced `.ko` module is then loaded
with `insmod` or `modprobe`. Once loaded, its probe function registers the Linux
interfaces that userspace can use.

## What WMI Means On Linux

WMI originally comes from Windows, but many laptop vendors expose firmware
controls through ACPI WMI objects. Linux has a WMI bus layer that lets kernel
drivers bind to those vendor-specific WMI GUIDs.

The rough flow is:

1. Firmware exposes an ACPI WMI device with a vendor GUID.
2. Linux detects that WMI device.
3. A WMI driver declares the GUID it supports.
4. The kernel calls the driver's probe function when the GUID is present.
5. The driver sends vendor-specific command buffers through WMI.
6. The driver translates those results into normal Linux sysfs interfaces.

In this driver, the GUID is:

```c
#define CASPER_WMI_GUID "644C5791-B7B0-4123-A90B-E93876E0DAAD"
```

The driver registers that GUID in its WMI ID table, so the kernel can match the
driver to the firmware device.

## Casper WMI Protocol Shape

The Casper firmware protocol is represented by this command structure:

```c
struct casper_wmi_args {
    u16 a0, a1;
    u32 a2, a3, a4, a5, a6, a7, a8;
};
```

The driver uses two broad operation types:

```c
#define CASPER_READ  0xfa00
#define CASPER_WRITE 0xfb00
```

For writes, `casper_set()` fills the structure and sends it with
`wmidev_block_set()`:

```c
a0 = CASPER_WRITE
a1 = command type
a2 = target id
a3 = payload
```

For reads, `casper_query()` sends a read request and then calls
`wmidev_block_query()` to fetch the returned buffer.

The important point is that userspace never calls WMI directly. Userspace writes
to sysfs; the kernel driver converts that into WMI commands.

## LED Control

The driver exposes the keyboard zones as multicolor LED class devices:

```text
/sys/class/leds/casper:rgb:kbd_zoned_backlight-left
/sys/class/leds/casper:rgb:kbd_zoned_backlight-middle
/sys/class/leds/casper:rgb:kbd_zoned_backlight-right
/sys/class/leds/casper:rgb:biaslight
```

Each LED has standard files such as:

```text
brightness
max_brightness
multi_intensity
```

The app writes these files. The LED class calls the driver's
`set_casper_brightness()` callback. That callback builds the vendor WMI payload:

```c
alpha/mode byte + red + green + blue
```

The RGB bits come from the multicolor LED intensities. The upper byte contains
the brightness and LED mode, for example `LED_NORMAL`.

## Fan Speed

The driver also registers a Linux `hwmon` device named `casper_wmi`.

That creates files such as:

```text
/sys/class/hwmon/hwmonX/name
/sys/class/hwmon/hwmonX/fan1_input
/sys/class/hwmon/hwmonX/fan1_label
/sys/class/hwmon/hwmonX/fan2_input
/sys/class/hwmon/hwmonX/fan2_label
```

On this machine the labels are expected to be:

```text
cpu_fan_speed
gpu_fan_speed
```

The app should use the labels, not assume `fan1` is always CPU and `fan2` is
always GPU.

## Platform Profile

For supported models, the driver registers Linux platform profile support. This
maps vendor-specific Casper power modes onto Linux profile names such as:

```text
low-power
balanced
balanced-performance
performance
```

The firmware command values differ between older and newer machines, so the
driver has CPU generation and DMI quirks to select the correct mapping.

## Sysfs Permissions

Sysfs files are normally owned by root. The production install path uses udev to
run a helper when the driver or LED devices appear. That helper changes group
ownership and group write permissions for the relevant sysfs files.

The development `scripts/reload.nu` path does not install persistent udev rules.
It reloads the module and applies temporary permissions after `insmod`.

## Fn+Space Regression

The keyboard Fn+Space hotkey is firmware behavior. It should continue working
after the Linux driver loads.

The regression was caused by the driver changing LED hardware state during
probe. The old probe path registered the LED devices and then immediately sent
default color WMI commands:

```c
casper_set(... CASPER_ALL_KEYBOARD_LEDS, CASPER_DEFAULT_COLOR);
casper_set(... CASPER_CORNER_LEDS, CASPER_DEFAULT_COLOR);
```

That default payload only contained RGB bits. It did not include the same
brightness/mode byte used by normal userspace LED writes. As a result, loading
or reloading the module could leave the firmware LED controller in a partial
state where Fn+Space stopped working until the app or CLI wrote brightness once.

The fix is to avoid changing LED hardware state during probe. The driver should
register Linux interfaces, but it should not reset keyboard lighting simply
because the module loaded. Hardware state changes should happen only after
userspace writes brightness or color.

## Design Rule

For this driver, probe should be conservative:

- Detect the device.
- Register Linux interfaces.
- Read state when needed.
- Avoid user-visible hardware changes during module load.

This keeps firmware hotkeys and boot-time hardware state intact while still
allowing the app and CLI to control the device through standard Linux sysfs
interfaces.
