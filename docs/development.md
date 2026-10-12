# Development Environment

## Release package smoke tests

After publishing a release, the [Release workflow](https://github.com/mert-kurttutan/cecc-linux/actions/runs/38302422453)
installs the Debian package on Ubuntu and the RPM in a Fedora container. It
checks that the GUI and CLI binaries are installed, runs the CLI help command,
checks that the `casper-wmi` DKMS source is installed and registered, then
removes each package and verifies that the DKMS registration is cleaned up.

These checks verify package installation and removal. They do not build the
module for a running kernel or load it on laptop hardware. The backend hardware
tests below require the supported Excalibur laptop and exercise real devices.

## Running backend hardware tests

The backend integration tests exercise the laptop's real hardware through
sysfs. They can change device state while running and require the supported
Excalibur laptop with its controls available. Run them on that machine with:

```sh
cargo test -p excalibur-control-center-backend
```

Do not run the backend integration tests on a machine without the supported
hardware. The tests restore the state they change when they finish.

## Entering the development shell on NixOS

The project flake reads the NixOS configuration at `/etc/nixos` to select the
running host's kernel build tree and related packages. Because `/etc/nixos` is
a local flake input, Nix records its content hash in `flake.lock`. Editing the
host configuration changes that hash and can make a plain `nix develop` fail
with a NAR hash mismatch.

After changing the host configuration, refresh the flake lock file and enter the
development shell:

```sh
nix flake update
nix develop
```

`nix flake update` refreshes the locked inputs, including the `/etc/nixos`
content hash, so Nix can evaluate the host configuration again. Review the
`flake.lock` diff because this command can update other flake inputs as well.

## Reloading the development driver

From the repository root, inside the development shell, run:

```sh
nu scripts/reload.nu
```

The script builds the Casper WMI module against the selected host kernel,
replaces the currently loaded module, applies temporary development
permissions to its sysfs controls, and prints recent kernel messages. Reloading
replaces the active driver, so run it when you intend to test driver changes.
