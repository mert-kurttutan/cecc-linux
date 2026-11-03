# Display Mode Behavior

Display/GPU mode is exposed by the driver through:

```text
/sys/module/casper_wmi/parameters/gpu_mode
```

The driver maps the modes as:

- `hybrid` = `1`
- `discrete` = `2`
- `uma` = `3`

## Expected Sysfs Behavior

- Reading `gpu_mode` returns the normalized text value:
  - `hybrid`
  - `discrete`
  - `uma`
- Writing either the text value or numeric alias should be accepted.
- After writing a mode, readback should return the normalized text value.
- Invalid values should be rejected by the kernel parameter parser.

Some firmware, including the reported G770 firmware, does not return a valid
mode when queried. In that case, reads return the last successfully requested
mode, initially `hybrid`. This is a cached request, not a confirmation of the
firmware's active mode.

## Runtime Caveat

Changing GPU/display mode may require reboot or matching OS graphics
configuration before the physical graphics stack fully reflects the selected
mode. The sysfs test only verifies driver command dispatch and readback.
