# Linux Driver for Casper Excalibur Laptops (Kernel 6.18+)

## Installation

This driver is installed out of tree. On most mutable distros, use DKMS. On
NixOS, prefer a Nix package/module or the dev reload script.

### Ubuntu / Linux Mint

```bash
sudo apt update
sudo apt install dkms build-essential linux-headers-$(uname -r)
sudo ./install.sh
```

### Debian

```bash
sudo apt update
sudo apt install dkms build-essential linux-headers-$(uname -r)
sudo ./install.sh
```

If `linux-headers-$(uname -r)` is not available, enable the matching Debian
repository for your running kernel first.

### Fedora

```bash
sudo dnf install dkms gcc make kernel-devel kernel-headers
sudo ./install.sh
```

After a kernel update, reboot into the new kernel before checking the rebuilt
module.

### Arch Linux / Manjaro

```bash
sudo pacman -S --needed dkms base-devel linux-headers
sudo ./install.sh
```

If you use another kernel, install its matching headers instead, for example
`linux-zen-headers` or `linux-lts-headers`.

### openSUSE

```bash
sudo zypper install dkms gcc make kernel-devel kernel-default-devel
sudo ./install.sh
```

### RHEL / Rocky / Alma / CentOS Stream

```bash
sudo dnf install dkms gcc make kernel-devel kernel-headers
sudo ./install.sh
```

You may need EPEL or the distro's DKMS repository enabled first.

### NixOS

Do not use `install.sh` as the normal install path on NixOS. From the repo
root, use the dev shell for local testing:

```bash
nix develop
nu ./scripts/reload.nu
```

For persistent installation, package the module with the NixOS kernel package
set and load it through `boot.extraModulePackages` / `boot.kernelModules`.
That keeps the module tied to the selected NixOS kernel.

## Usage

### Fan Control
Use your desktop's power settings or CLI:
```bash
# Silent
sudo sh -c 'echo low-power > /sys/firmware/acpi/platform_profile'

# Gaming
sudo sh -c 'echo performance > /sys/firmware/acpi/platform_profile'
```
