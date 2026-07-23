# cecc-linux

Linux port of Casper Excalibur Control Center software.

Scope:
- provide cli and gui based version of Control Center Software
- Aim is to have a version that is featuer complete.

Casper WMI driver work is based on and credits:
- <https://github.com/Mustafa-eksi/casper-wmi>

## Installation

### Debian Package

On Debian-based distributions such as Ubuntu, download the `.deb` from the
release page and install it with apt:

```sh
wget https://github.com/mert-kurttutan/cecc-linux/releases/download/v0.1.21/excalibur-control-center_0.1.21_amd64.deb
sudo apt install ./excalibur-control-center_0.1.21_amd64.deb
```

The `.deb` installs the GUI, CLI, udev permission rules, and the sysfs
permission helper. It does not install the `casper-wmi` driver yet.

After installation, add your user to the `excalibur` group and log out and back
in:

```sh
sudo usermod -aG excalibur "$USER"
```

Run the GUI:

```sh
excalibur-control-center-gui
```

### Full Installer Script

For the default installation method use the following in terminal:

```sh
curl -fsSL https://raw.githubusercontent.com/mert-kurttutan/cecc-linux/main/scripts/driver-bash/install-release.sh | sudo bash
```


Install a specific release:

```sh
curl -fsSL https://raw.githubusercontent.com/mert-kurttutan/cecc-linux/main/scripts/driver-bash/install-release.sh | sudo bash -s -- --version v0.0.2
```

Nushell versions:

```sh
curl -fsSL https://raw.githubusercontent.com/mert-kurttutan/cecc-linux/main/scripts/driver-nu/install-release.nu | sudo nu --stdin -c 'nu -c ($in + "\nmain")'

curl -fsSL https://raw.githubusercontent.com/mert-kurttutan/cecc-linux/main/scripts/driver-nu/install-release.nu | sudo nu --stdin -c 'nu -c ($in + "\nmain --version v0.0.2")'
```

The installer must run with `sudo` because it installs system packages, the
DKMS driver, udev permission rules, and application binaries under
`/usr/local/bin`.

## Development

Rust workspace commands are run from `excalibur-control-center/`:

```sh
cd excalibur-control-center
```

Install development dependencies on Ubuntu:

```sh
sudo apt update
sudo apt install build-essential pkg-config libfontconfig1-dev
```

Optional NVIDIA GPU frequency support requires NVML (`libnvidia-ml.so.1`).
On conventional Linux distributions such as Ubuntu, this is normally provided by
the proprietary NVIDIA driver packages. If the driver is installed correctly and
`nvidia-smi` works, the app can usually load NVML at runtime and display NVIDIA
GPU frequency. If NVML is not available, the GPU frequency field shows `--`.

On NixOS, the NVIDIA driver libraries live in Nix store paths and are not always
visible to dynamically-loaded libraries by default. The project flake handles
this for development by adding the host NVIDIA driver package to
`LD_LIBRARY_PATH` inside `nix develop`, so `nvml-wrapper` can find
`libnvidia-ml.so.1` when NVIDIA support is enabled on the host.

Run the CLI:

```sh
cargo run -p excalibur-control-center-cli
```

Run common CLI commands:

```sh
cargo run -p excalibur-control-center-cli -- status
cargo run -p excalibur-control-center-cli -- gpu get
cargo run -p excalibur-control-center-cli -- keyboard list
cargo run -p excalibur-control-center-cli -- keyboard get all
```

Run the GUI:

```sh
cargo run -p excalibur-control-center-gui
```

Build everything:

```sh
cargo build
```
