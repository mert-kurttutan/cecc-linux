# LED Brightness Behavior

These observations describe the physical behavior of the Excalibur/Casper RGB
lighting hardware and the Windows control app.

## Keyboard Zones

- The left, middle, and right keyboard zones can have separate colors.
- Their brightness is shared.
- Setting the brightness of one keyboard zone also changes the brightness of
  the other keyboard zones on Windows.
- The Linux driver should therefore treat keyboard brightness as one shared
  keyboard-level value, not as three independent values.
- Setting the color of one keyboard zone should affect only that selected zone.
- The GUI must preserve this distinction: individual zone color writes should
  remain per-zone, while keyboard brightness writes should be shared.

## Bias Light

- The bias/trunk light is exposed separately from the three keyboard zones.
- Windows can change the bias/trunk brightness independently from the keyboard
  brightness.
- Current Linux WMI testing shows that target `0x07` changes physical
  brightness, but behaves like a shared/global brightness target.
- Tested targets `0x08` and `0x0c` did not physically control the bias/trunk
  light, even if sysfs state could be represented independently.

## Driver Implication

The known-good model is:

- one shared brightness value for all keyboard zones;
- a separate bias/trunk brightness value once the correct WMI command/target is
  identified;
- separate RGB colors for each keyboard zone and the bias/trunk light.

## GUI Sync Behavior

- The Linux driver can now read keyboard brightness changed by `Fn+Space`
  through the hardware-info WMI query.
- Applying brightness from the GUI after using `Fn+Space` works correctly.
- The remaining GUI issue is display-only: when brightness is changed with
  `Fn+Space` while the GUI is open, the brightness slider does not immediately
  move to the new hardware value.
- The GUI should therefore refresh or resync the selected LED brightness from
  sysfs without fighting user edits in progress.
