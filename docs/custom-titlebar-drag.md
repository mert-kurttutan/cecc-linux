# Custom Titlebar Drag

The GUI uses a frameless Slint window:

```slint
no-frame: true;
resize-border-width: 6px;
```

The custom titlebar lives in `gui/ui/main.slint`. Its drag area calls
`root.start_drag_window()` on `changed pressed`, and double-click toggles
maximize:

```slint
TouchArea {
    width: max(parent.width - 160px, 0px);
    height: parent.height;
    changed pressed => {
        if (self.pressed) {
            root.start_drag_window();
        }
    }
    double-clicked => {
        root.maximized = !root.maximized;
    }
}
```

Rust handles this through winit in `gui/src/main.rs`:

```rust
window.window().with_winit_window(|window| {
    let _ = window.drag_window();
});
```

This requires the GUI crate's `unstable-winit-030` Slint feature.

## Current State

- Window controls are separate SVG-icon buttons.
- The drag area is separated from the window control button area.
- Native `drag_window()` is preferred over manual `set_position()` because it
  works better with compositor behavior, especially on Wayland.

## Known Bug

After dragging the window, other UI regions can remain inactive until one extra
click happens inside the app. For example, hover effects on buttons may not
reactivate immediately after the drag ends.

The suspected cause is the handoff from Slint pointer handling to the native
window manager drag operation. The compositor takes over the pointer gesture,
and Slint may not receive the normal pointer release/enter/leave events needed
to refresh `has-hover` and click state immediately.

## Fallback

If drag/hover bugs become visible again, keep the explicit maximize button and
remove titlebar double-click maximize first. That is the smallest simplification
before considering a system titlebar or manual drag logic.
