# Development Environment

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
