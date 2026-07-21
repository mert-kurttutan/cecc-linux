# Rust Linux Driver Notes

This document summarizes the current state of writing Linux kernel drivers in
Rust and how it relates to a possible Rust version of `casper-wmi`.

## Current Status

Rust support is part of the upstream Linux kernel documentation. The official
entry point is the kernel's Rust documentation, which points developers to the
Rust quick-start guide and generated Rust API docs.

Rust in the kernel is not ordinary userspace Rust. Kernel Rust code:

- Uses `#![no_std]`.
- Links against `core` and the kernel-provided `kernel` crate, not `std`.
- Is built by the kernel build system, not by a normal standalone Cargo build.
- Uses kernel abstractions instead of direct userspace libraries.

The official docs state that the kernel Rust support can link only `core`, not
`std`, and kernel crates must opt into this with `#![no_std]`.

## Build Requirements

The kernel Rust quick-start guide lists the main pieces needed:

- `rustc`
- Rust standard library source, because the kernel build cross-compiles `core`
- `bindgen`
- `libclang`
- `rustfmt` and `clippy` for development

The documented check is:

```sh
make LLVM=1 rustavailable
```

This checks whether the current kernel tree has the Rust build requirements
needed to enable `CONFIG_RUST`.

The best-supported build path is currently a full LLVM toolchain:

```sh
make LLVM=1
```

GCC-based builds may work in some configurations, but the kernel docs describe
that path as more experimental.

## Kernel Rust API Model

Rust kernel modules use the kernel's `kernel` crate. The generated Rust docs
describe it as the crate that contains kernel APIs ported or wrapped for Rust
code. Kernel Rust code depends on `core` and this `kernel` crate.

A Rust module implements the `kernel::Module` trait. The trait's `init()`
method is the Rust equivalent of C's `module_init`.

The kernel crate also provides driver-related macros and abstractions, such as:

- `module_driver`
- `module_platform_driver`
- `module_pci_driver`
- `module_usb_driver`
- bus and subsystem modules like `acpi`, `platform`, `pci`, `usb`, `hwmon`,
  `device`, `sync`, and `uaccess`

The important design point is that Rust driver code should use safe kernel
abstractions where they exist. The official docs explicitly discourage leaf
drivers from bypassing abstractions and calling raw generated C bindings
directly.

## Abstractions And Bindings

The Rust-for-Linux model has two layers:

- **Bindings**: raw Rust declarations generated from C headers by `bindgen`.
- **Abstractions**: reviewed Rust wrappers around C kernel APIs.

The intended direction is that subsystem maintainers add safe abstractions, and
drivers consume those abstractions. If a C API is not wrapped yet, the preferred
upstream-style work is to add or improve the abstraction first.

This matters for `casper-wmi` because the current C driver uses several kernel
subsystems:

- WMI
- ACPI
- LED class
- multicolor LED class
- hwmon
- platform profile
- DMI quirks
- x86 CPU matching
- mutex/devres/device-managed allocation

A Rust rewrite is only straightforward if the needed abstractions exist. If WMI
or LED multicolor APIs are not available as safe Rust abstractions for the
target kernel version, the driver would need new abstraction work or carefully
contained unsafe interop.

## Architecture Support

The official Rust arch support page lists `x86` as maintained, with the
constraint that it is `x86_64` only. That is fine for the current Casper laptop
target.

## What A Rust `casper-wmi` Would Look Like

Conceptually, the Rust driver would keep the same Linux-facing behavior:

- Bind to the Casper WMI GUID.
- Register LED devices under `/sys/class/leds`.
- Register hwmon fan readings.
- Register platform profile support where supported.
- Expose GPU mode or another userspace interface.
- Send the same vendor WMI command buffers internally.

The user-facing sysfs contract should not change just because the implementation
language changes.

The main rewrite challenge is not Rust syntax. The main challenge is whether the
target kernel has enough Rust wrappers for the subsystems this driver uses.

## Practical Recommendation For This Project

For `casper-wmi`, a full Rust rewrite is probably not the most pragmatic next
step yet.

A better path is:

1. Keep the current C driver stable.
2. Reduce risky probe-time behavior.
3. Improve sysfs behavior and hardware state handling.
4. Track Rust-for-Linux support for WMI, LED multicolor, hwmon, and platform
   profile APIs.
5. Consider a Rust experiment only when the required abstractions exist in the
   kernel version you want to support.

If experimentation is still desired, start with a tiny Rust module against a
Rust-enabled kernel tree first. Do not start by porting the whole driver.

## Sources

- Linux kernel Rust documentation: <https://docs.kernel.org/rust/>
- Linux kernel Rust quick start: <https://docs.kernel.org/rust/quick-start.html>
- Linux kernel Rust general information: <https://docs.kernel.org/rust/general-information.html>
- Linux kernel Rust coding guidelines: <https://docs.kernel.org/rust/coding-guidelines.html>
- Linux kernel Rust architecture support: <https://docs.kernel.org/rust/arch-support.html>
- Generated Rust kernel API docs: <https://rust.docs.kernel.org/kernel/>
- `kernel::Module` API docs: <https://rust.docs.kernel.org/kernel/trait.Module.html>
