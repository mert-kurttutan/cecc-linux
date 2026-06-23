use std::cell::RefCell;
use std::rc::Rc;

use excalibur_control_center_backend::{
    Backend, KeyboardZone, KeyboardZoneName, RgbColor, SysfsBackend,
};

slint::slint! {
import { Button, HorizontalBox, Slider, SpinBox, VerticalBox } from "std-widgets.slint";

export component MainWindow inherits Window {
    in property <string> status: "";
    in property <string> active_zone: "all";
    in property <string> zones_summary: "";
    in-out property <int> brightness: 0;
    in-out property <float> brightness_slider: 0;
    in-out property <int> red: 255;
    in-out property <int> green: 255;
    in-out property <int> blue: 255;

    callback refresh();
    callback select_zone(int);
    callback brightness_edited(int);
    callback brightness_slider_changed(float);
    callback apply_brightness();
    callback apply_color();

    width: 980px;
    height: 640px;
    title: "Excalibur Control Center";

    VerticalBox {
        spacing: 12px;

        Text { text: "Excalibur Control Center"; }
        Text { text: root.status; }

        HorizontalBox {
            spacing: 8px;
            Button { text: "All"; clicked => { root.select_zone(0); } }
            Button { text: "Left"; clicked => { root.select_zone(1); } }
            Button { text: "Middle"; clicked => { root.select_zone(2); } }
            Button { text: "Right"; clicked => { root.select_zone(3); } }
            Button { text: "Bias"; clicked => { root.select_zone(4); } }
            Button { text: "Refresh"; clicked => { root.refresh(); } }
        }

        Text { text: "Selected: " + root.active_zone; }

        HorizontalBox {
            spacing: 8px;
            Text { text: "Brightness"; }
            Slider {
                minimum: 0;
                maximum: 2;
                value <=> root.brightness_slider;
                changed(value) => { root.brightness_slider_changed(value); }
            }
            SpinBox {
                minimum: 0;
                maximum: 2;
                value <=> root.brightness;
                edited(value) => { root.brightness_edited(value); }
            }
            Button { text: "Apply brightness"; clicked => { root.apply_brightness(); } }
        }

        HorizontalBox {
            spacing: 8px;
            Text { text: "R"; }
            SpinBox { minimum: 0; maximum: 255; value <=> root.red; }
            Text { text: "G"; }
            SpinBox { minimum: 0; maximum: 255; value <=> root.green; }
            Text { text: "B"; }
            SpinBox { minimum: 0; maximum: 255; value <=> root.blue; }
            Button { text: "Apply color"; clicked => { root.apply_color(); } }
        }

        Text { text: "Zones"; }
        Text { text: root.zones_summary; }
    }
}
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum ZoneSelection {
    All,
    Left,
    Middle,
    Right,
    Bias,
}

impl ZoneSelection {
    fn from_index(index: i32) -> Self {
        match index {
            1 => Self::Left,
            2 => Self::Middle,
            3 => Self::Right,
            4 => Self::Bias,
            _ => Self::All,
        }
    }

    fn as_label(self) -> &'static str {
        match self {
            Self::All => "all",
            Self::Left => "left",
            Self::Middle => "middle",
            Self::Right => "right",
            Self::Bias => "bias",
        }
    }

    fn to_option(self) -> Option<KeyboardZoneName> {
        match self {
            Self::All => None,
            Self::Left => Some(KeyboardZoneName::Left),
            Self::Middle => Some(KeyboardZoneName::Middle),
            Self::Right => Some(KeyboardZoneName::Right),
            Self::Bias => Some(KeyboardZoneName::Bias),
        }
    }
}

#[derive(Debug)]
struct AppState {
    backend: SysfsBackend,
    zones: Vec<KeyboardZone>,
    selected_zone: ZoneSelection,
    status: String,
}

impl AppState {
    fn new() -> Self {
        let mut state = Self {
            backend: SysfsBackend::default(),
            zones: Vec::new(),
            selected_zone: ZoneSelection::All,
            status: String::new(),
        };
        state.refresh();
        state
    }

    fn refresh(&mut self) {
        match self.backend.read_keyboard_zones(None) {
            Ok(zones) => {
                self.zones = zones;
                self.status = "refreshed keyboard state".into();
            }
            Err(err) => {
                self.status = format!("refresh failed: {err}");
            }
        }
    }

    fn set_selected_zone(&mut self, zone: ZoneSelection) {
        self.selected_zone = zone;
        self.status = format!("selected {}", zone.as_label());
    }

    fn selected_zone_state(&self) -> Option<KeyboardZone> {
        self.selected_zone
            .to_option()
            .and_then(|zone| self.zones.iter().find(|entry| entry.name == zone))
            .cloned()
    }

    fn zone_summary(&self) -> String {
        self.zones
            .iter()
            .map(|zone| {
                format!(
                    "{}: brightness={} max={} color={},{},{}",
                    zone.name,
                    zone.brightness,
                    zone.max_brightness,
                    zone.color.red,
                    zone.color.green,
                    zone.color.blue
                )
            })
            .collect::<Vec<_>>()
            .join("\n")
    }
}

fn sync_window(window: &MainWindow, state: &AppState) {
    window.set_status(state.status.clone().into());
    window.set_active_zone(state.selected_zone.as_label().into());
    window.set_zones_summary(state.zone_summary().into());

    if let Some(zone) = state.selected_zone_state() {
        window.set_brightness(zone.brightness as i32);
        window.set_brightness_slider(zone.brightness as f32);
        window.set_red(zone.color.red as i32);
        window.set_green(zone.color.green as i32);
        window.set_blue(zone.color.blue as i32);
    }
}

fn zone_for_index(index: i32) -> ZoneSelection {
    ZoneSelection::from_index(index)
}

fn main() -> Result<(), slint::PlatformError> {
    let window = MainWindow::new()?;
    let state = Rc::new(RefCell::new(AppState::new()));

    {
        let state = state.clone();
        let window_weak = window.as_weak();
        window.on_refresh(move || {
            let mut state = state.borrow_mut();
            state.refresh();
            if let Some(window) = window_weak.upgrade() {
                sync_window(&window, &state);
            }
        });
    }

    {
        let state = state.clone();
        let window_weak = window.as_weak();
        window.on_select_zone(move |index| {
            let mut state = state.borrow_mut();
            state.set_selected_zone(zone_for_index(index));
            if let Some(window) = window_weak.upgrade() {
                sync_window(&window, &state);
            }
        });
    }

    {
        let state = state.clone();
        let window_weak = window.as_weak();
        window.on_brightness_edited(move |value| {
            let mut state = state.borrow_mut();
            if let Some(window) = window_weak.upgrade() {
                window.set_brightness(value);
                window.set_brightness_slider(value as f32);
            }
            state.status = format!("brightness adjusted to {}", value);
        });
    }

    {
        let state = state.clone();
        let window_weak = window.as_weak();
        window.on_brightness_slider_changed(move |value| {
            let mut state = state.borrow_mut();
            let brightness = value.round() as i32;
            if let Some(window) = window_weak.upgrade() {
                window.set_brightness(brightness);
                window.set_brightness_slider(value);
            }
            state.status = format!("brightness adjusted to {}", brightness);
        });
    }

    {
        let state = state.clone();
        let window_weak = window.as_weak();
        window.on_apply_brightness(move || {
            let mut state = state.borrow_mut();
            let brightness = window_weak
                .upgrade()
                .map(|window| window.get_brightness_slider().round() as u32)
                .unwrap_or(0);

            let result = state
                .backend
                .set_keyboard_brightness(state.selected_zone.to_option(), brightness);

            match result {
                Ok(zones) => {
                    state.zones = zones;
                    state.status = format!(
                        "brightness set to {} for {}",
                        brightness,
                        state.selected_zone.as_label()
                    );
                }
                Err(err) => state.status = format!("brightness write failed: {err}"),
            }

            if let Some(window) = window_weak.upgrade() {
                sync_window(&window, &state);
            }
        });
    }

    {
        let state = state.clone();
        let window_weak = window.as_weak();
        window.on_apply_color(move || {
            let mut state = state.borrow_mut();
            let Some(window) = window_weak.upgrade() else {
                return;
            };

            let color = RgbColor::new(
                window.get_red() as u8,
                window.get_green() as u8,
                window.get_blue() as u8,
            );

            let result = state
                .backend
                .set_keyboard_color(state.selected_zone.to_option(), color);

            match result {
                Ok(zones) => {
                    state.zones = zones;
                    state.status = format!(
                        "color set to {},{},{} for {}",
                        color.red,
                        color.green,
                        color.blue,
                        state.selected_zone.as_label()
                    );
                }
                Err(err) => state.status = format!("color write failed: {err}"),
            }

            sync_window(&window, &state);
        });
    }

    {
        let state = state.borrow();
        sync_window(&window, &state);
    }

    window.run()
}
