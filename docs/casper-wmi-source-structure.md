# `casper-wmi.c` Source Structure

This document explains the structure of `casper-wmi/casper-wmi.c` and how it
follows the usual Linux driver and WMI driver model.

## High-Level Shape

The driver is an out-of-tree Linux WMI driver. Its job is to bind to the Casper
firmware WMI GUID and expose vendor-specific laptop controls through standard
Linux subsystems:

- LED class and multicolor LED class for keyboard RGB zones.
- hwmon for fan speed readings.
- platform profile for system performance modes.
- sysfs/module support for GPU mode through `casper-gpu-mode.c`.

The file follows the common kernel driver pattern:

1. Include subsystem headers.
2. Define vendor protocol constants.
3. Define private driver state.
4. Implement low-level hardware access helpers.
5. Implement Linux subsystem callbacks.
6. Register devices/subsystems in `probe`.
7. Clean up in `remove`.
8. Register the WMI driver with `module_wmi_driver`.

## Includes

The includes show which kernel subsystems the driver uses:

```c
#include <linux/wmi.h>
#include <linux/acpi.h>
#include <linux/leds.h>
#include <linux/led-class-multicolor.h>
#include <linux/hwmon.h>
#include <linux/platform_profile.h>
#include <linux/dmi.h>
```

This is a normal Linux driver rule: include the subsystem headers for the
interfaces the driver registers with. Userspace should see standard Linux
interfaces; vendor-specific WMI details should stay inside the driver.

## Vendor Protocol Constants

The driver starts by defining the Casper WMI GUID:

```c
#define CASPER_WMI_GUID "644C5791-B7B0-4123-A90B-E93876E0DAAD"
```

This is the firmware interface ID. The WMI core uses it to match this driver to
the ACPI WMI device exposed by firmware.

Then the file defines vendor command IDs:

```c
#define CASPER_READ 0xfa00
#define CASPER_WRITE 0xfb00
#define CASPER_GET_HARDWAREINFO 0x0200
#define CASPER_SET_LED 0x0100
#define CASPER_POWERPLAN 0x0300
```

These are not Linux concepts. They are Casper firmware protocol values. Keeping
them as named constants makes the rest of the driver readable and avoids magic
numbers inside callbacks.

The LED target IDs work the same way:

```c
#define CASPER_KEYBOARD_LED_1 0x03
#define CASPER_KEYBOARD_LED_2 0x04
#define CASPER_KEYBOARD_LED_3 0x05
#define CASPER_ALL_KEYBOARD_LEDS 0x06
#define CASPER_CORNER_LEDS 0x07
```

## LED Names

The driver exposes four LED devices:

```c
static const char * const zone_names[CASPER_LED_COUNT] = {
    "casper:rgb:kbd_zoned_backlight-right",
    "casper:rgb:kbd_zoned_backlight-middle",
    "casper:rgb:kbd_zoned_backlight-left",
    "casper:rgb:biaslight",
};
```

These names become sysfs entries under:

```text
/sys/class/leds/
```

This applies the Linux driver rule of exposing hardware features through a
standard subsystem instead of inventing a custom userspace API.

## Driver State

The central private state is:

```c
struct casper_drv {
    struct mutex mutex;
    struct casper_fourzone_led *leds;
    struct wmi_device *wdev;
    struct casper_quirk_entry *quirk_applied;
};
```

This is normal Linux driver structure:

- `mutex` serializes WMI firmware access.
- `leds` stores the LED class devices and their RGB subled state.
- `wdev` is the matched WMI device.
- `quirk_applied` stores model/generation-specific behavior.

The driver stores this private state with:

```c
dev_set_drvdata(&wdev->dev, drv);
```

Later callbacks recover it with `dev_get_drvdata()`.

## WMI Command Buffer

The firmware command payload is represented by:

```c
struct casper_wmi_args {
    u16 a0, a1;
    u32 a2, a3, a4, a5, a6, a7, a8;
};
```

The driver uses this same layout for reads and writes. This is the boundary
between Linux code and the vendor firmware protocol.

## Low-Level WMI Helpers

There are two low-level helpers:

```c
static int casper_set(...)
static int casper_query(...)
```

`casper_set()` sends a write command using `wmidev_block_set()`.

`casper_query()` sends a read command and then fetches the returned ACPI buffer
with `wmidev_block_query()`.

Both helpers hold the driver mutex:

```c
guard(mutex)(&drv->mutex);
```

That follows a core driver rule: serialize access to firmware interfaces unless
the protocol is explicitly known to be safe for concurrent access.

The helpers also translate ACPI/WMI failures into normal Linux error codes such
as `-EIO` and `-EINVAL`.

## GPU Mode Include

The file includes:

```c
#include "casper-gpu-mode.c"
```

That means GPU mode support is compiled into the same kernel module but kept in
a separate source file. Conceptually, this is still part of the same driver. It
is just split out to keep the main file smaller.

## LED Implementation

The LED path has three main pieces:

```c
get_zone_color()
get_casper_brightness()
set_casper_brightness()
```

`get_zone_color()` converts the multicolor LED state into the vendor RGB bit
layout:

```c
red   -> bits 23..16
green -> bits 15..8
blue  -> bits 7..0
```

`set_casper_brightness()` is the LED class callback. When userspace writes:

```text
/sys/class/leds/.../brightness
```

the kernel LED subsystem calls this function. The driver then builds a WMI
payload containing:

```text
brightness/mode byte + RGB bytes
```

and sends it with:

```c
casper_set(drv, CASPER_SET_LED, zone_to_change, led_data);
```

This is the main driver translation layer:

```text
userspace sysfs write -> Linux LED callback -> Casper WMI command
```

## Platform Profile

The platform profile section implements:

```c
casper_platform_profile_probe()
casper_platform_profile_get()
casper_platform_profile_set()
```

These callbacks map Casper firmware power-plan values to Linux platform profile
values:

```text
low-power
balanced
balanced-performance
performance
```

The driver has two firmware mappings:

- older scheme
- newer scheme

That is why it has separate enums:

```c
enum casper_power_profile_old
enum casper_power_profile_new
```

The general driver rule here is to normalize vendor-specific modes into the
standard Linux interface. Userspace should not need to know whether a specific
model uses the old or new firmware numbering.

## hwmon Fan Speed

The hwmon section implements:

```c
casper_wmi_hwmon_is_visible()
casper_wmi_hwmon_read()
casper_wmi_hwmon_read_string()
```

`casper_wmi_hwmon_read()` queries firmware with:

```c
CASPER_GET_HARDWAREINFO
```

and returns fan RPM values through standard hwmon files:

```text
fan1_input
fan2_input
```

`casper_wmi_hwmon_read_string()` gives those fans labels:

```text
cpu_fan_speed
gpu_fan_speed
```

This follows the standard hwmon rule: expose sensor values through hwmon
channels and labels, not through private custom files.

## Quirks

The driver has two kinds of quirks:

```c
static const struct x86_cpu_id casper_gen[]
static const struct dmi_system_id casper_quirks[]
```

CPU generation quirks select things like:

- fan byte order
- old/new power scheme

DMI quirks select model-specific behavior such as whether platform profiles are
available.

This is normal laptop driver design. Firmware behavior often differs by model
and generation, so the driver should detect the machine and select behavior
explicitly instead of relying on one universal path.

## Subsystem Registration Helpers

`casper_platform_profile_register()` registers platform profile support:

```c
devm_platform_profile_register(...)
```

`casper_multicolor_register()` allocates and registers the LED devices:

```c
devm_kcalloc(...)
devm_led_classdev_multicolor_register(...)
```

The use of `devm_*` APIs is important. Device-managed resources are
automatically released when the device is removed. That reduces manual cleanup
and is the preferred style for many modern Linux drivers.

The LED registration function now only registers LED devices. It does not write
default color or brightness to hardware during probe. This is intentional:
module load should not alter visible hardware state unless necessary.

## Probe Function

The main entry point is:

```c
static int casper_wmi_probe(struct wmi_device *wdev, const void *context)
```

The WMI core calls this when it finds the Casper WMI GUID.

The probe flow is:

1. Allocate private driver state with `devm_kzalloc`.
2. Store the `wmi_device`.
3. Attach private state with `dev_set_drvdata`.
4. Match CPU generation.
5. Match DMI model.
6. Initialize the mutex.
7. Register GPU mode support.
8. Register multicolor LED devices.
9. Register hwmon fan sensors.
10. Register platform profile support if the model supports it.

This is the standard Linux driver rule: `probe` should set up kernel-facing
interfaces and fail cleanly if the hardware/model is unsupported.

For this driver, probe should stay conservative. It should register interfaces,
but avoid changing keyboard lighting state on load. That preserves firmware
hotkey behavior such as Fn+Space.

## Remove Function

The remove function currently unregisters the GPU mode backend:

```c
static void casper_wmi_remove(struct wmi_device *wdev)
{
    struct casper_drv *drv = dev_get_drvdata(&wdev->dev);

    casper_gpu_mode_backend_unregister(drv);
}
```

Most other resources are device-managed through `devm_*`, so they do not need
manual cleanup here.

## WMI Driver Registration

The WMI match table is:

```c
static const struct wmi_device_id casper_wmi_id_table[] = {
    { CASPER_WMI_GUID, NULL },
    { }
};
MODULE_DEVICE_TABLE(wmi, casper_wmi_id_table);
```

The WMI driver object is:

```c
static struct wmi_driver casper_drv = {
    .driver = {
        .name = "casper-wmi",
    },
    .id_table = casper_wmi_id_table,
    .probe = casper_wmi_probe,
    .remove = casper_wmi_remove,
    .no_singleton = true,
};
```

And the module registration macro is:

```c
module_wmi_driver(casper_drv);
```

This is the standard WMI driver pattern:

```text
WMI GUID table -> wmi_driver -> probe/remove callbacks -> module_wmi_driver
```

## General Rules Applied

The driver follows several important Linux driver rules:

- Bind through the kernel bus layer, here WMI.
- Keep vendor protocol details inside the driver.
- Expose standard Linux interfaces to userspace.
- Store per-device state with `dev_set_drvdata`.
- Serialize firmware access with a mutex.
- Use `devm_*` managed resources where practical.
- Use DMI and CPU quirks for model-specific behavior.
- Return normal Linux error codes.
- Avoid changing visible hardware state during probe unless required.

## Current Design Principle

For `casper-wmi`, the most important rule is:

```text
Probe should register controls, not take control.
```

The driver should make keyboard lighting, fan sensors, platform profiles, and
GPU mode available to Linux. It should not reset LED state simply because the
module loaded. Actual hardware changes should happen in response to userspace
actions or explicit kernel subsystem callbacks.
