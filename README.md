# cecc-linux

Linux port of Casper Excalibur Control Center software.

Scope:
- provide cli and gui based version of Control Center Software
- Aim is to have a version that is featuer complete.

Casper WMI driver work is based on and credits:
- <https://github.com/Mustafa-eksi/casper-wmi>

## Installation

Install the app, Casper WMI driver, and udev permission rules:

```sh
curl -fsSL https://raw.githubusercontent.com/mert-kurttutan/cecc-linux/main/scripts/driver-bash/install-release.sh | bash
```

Nushell version:

```sh
curl -fsSL https://raw.githubusercontent.com/mert-kurttutan/cecc-linux/main/scripts/driver-nu/install-release.nu | nu --stdin -c 'nu -c ($in + "\nmain")'
```

Install a specific release:

```sh
curl -fsSL https://raw.githubusercontent.com/mert-kurttutan/cecc-linux/main/scripts/driver-bash/install-release.sh | bash -s -- --version v0.0.2
```

Nushell version:

```sh
curl -fsSL https://raw.githubusercontent.com/mert-kurttutan/cecc-linux/main/scripts/driver-nu/install-release.nu | nu --stdin -c 'nu -c ($in + "\nmain --version v0.0.2")'
```

Install only the app binary, without driver or udev setup:

```sh
curl -fsSL https://raw.githubusercontent.com/mert-kurttutan/cecc-linux/main/scripts/driver-bash/install-release.sh | bash -s -- --skip-driver
```

Nushell version:

```sh
curl -fsSL https://raw.githubusercontent.com/mert-kurttutan/cecc-linux/main/scripts/driver-nu/install-release.nu | nu --stdin -c 'nu -c ($in + "\nmain --skip-driver")'
```

After installation, log out and back in if the installer adds your user to the
`excalibur` group.

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
