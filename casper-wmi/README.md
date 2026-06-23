# Linux Driver for Casper Excalibur Laptops (Kernel 6.18+)

This repository contains an out-of-tree WMI driver for Casper Excalibur laptops (such as G911) on modern Linux kernels (6.18 and newer).

**Original Driver:** [https://github.com/Mustafa-eksi/casper-wmi](https://github.com/Mustafa-eksi/casper-wmi) <br>
**Original Author**: [Mustafa Ekşi](https://github.com/Mustafa-eksi/)
<br>
<br>
**Maintenance:** 
*   Updated for Linux 6.18+ API changes
*   Raptor Lake HX support

## Features
*   **Platform Profiles**: Switch between `low-power`, `balanced`, and `performance` modes to control fan curves.
*   **Fan Monitoring**: Reports CPU/GPU fan speeds via HWMON.
*   **RGB Keyboard Control**: Control 3-zone + corner lighting (Color & Brightness).
*   **CPU Support**: Added support for 13th Gen Intel Core (Raptor Lake, e.g., i7-13700HX).

## Requirements
*   Linux kernel headers for your running kernel
*   Build tools (`build-essential`, `dkms`, `libssl-dev`, etc.)

## Installation

**Install with DKMS (recommended)**
1. **Download and CD into the repository**
2. **Run install script as sudo:**
    ```bash
    sudo ./install.sh
    ```

## Usage

### Fan Control
Use your desktop's power settings or CLI:
```bash
# Silent
sudo sh -c 'echo low-power > /sys/firmware/acpi/platform_profile'

# Gaming
sudo sh -c 'echo performance > /sys/firmware/acpi/platform_profile'
```

### Keyboard Colors
(Optional) Use the included `keyboard_control.sh` script:
```bash
sudo ./keyboard_control.sh all 255 0 0  # Red, All Zones
sudo ./keyboard_control.sh left 0 255 0 # Green Left Zone
sudo ./keyboard_control.sh right 0 0 255 # Green Left Zone
```
> This script assigns max brightness to the keyboard LEDs. Modify the script if you wish to change that.
