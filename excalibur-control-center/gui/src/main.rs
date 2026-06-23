use std::cell::RefCell;
use std::rc::Rc;

use excalibur_control_center_backend::{
    Backend, KeyboardZone, KeyboardZoneName, RgbColor, SysfsBackend,
};
use excalibur_control_center_gui::ui::MainWindow;
use slint::ComponentHandle;

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
        let (h, s, v) = rgb_to_hsv(zone.color);
        window.set_color_hue(h);
        window.set_color_saturation(s);
        window.set_color_value(v);
        let base = hsv_to_rgb(h, 1.0, 1.0);
        window.set_picker_base_color(slint::Color::from_rgb_u8(base.red, base.green, base.blue));
        window.set_selected_color(slint::Color::from_rgb_u8(
            zone.color.red,
            zone.color.green,
            zone.color.blue,
        ));
    }
}

fn zone_for_index(index: i32) -> ZoneSelection {
    ZoneSelection::from_index(index)
}

fn clamp01(value: f32) -> f32 {
    value.clamp(0.0, 1.0)
}

fn hsv_to_rgb(h: f32, s: f32, v: f32) -> RgbColor {
    let h = h.rem_euclid(360.0);
    let c = v * s;
    let x = c * (1.0 - (((h / 60.0) % 2.0) - 1.0).abs());
    let m = v - c;
    let (r1, g1, b1) = match h as i32 {
        0..=59 => (c, x, 0.0),
        60..=119 => (x, c, 0.0),
        120..=179 => (0.0, c, x),
        180..=239 => (0.0, x, c),
        240..=299 => (x, 0.0, c),
        _ => (c, 0.0, x),
    };

    RgbColor::new(
        ((r1 + m) * 255.0).round().clamp(0.0, 255.0) as u8,
        ((g1 + m) * 255.0).round().clamp(0.0, 255.0) as u8,
        ((b1 + m) * 255.0).round().clamp(0.0, 255.0) as u8,
    )
}

fn rgb_to_hsv(color: RgbColor) -> (f32, f32, f32) {
    let r = color.red as f32 / 255.0;
    let g = color.green as f32 / 255.0;
    let b = color.blue as f32 / 255.0;
    let max = r.max(g.max(b));
    let min = r.min(g.min(b));
    let delta = max - min;

    let hue = if delta == 0.0 {
        0.0
    } else if max == r {
        60.0 * ((g - b) / delta).rem_euclid(6.0)
    } else if max == g {
        60.0 * (((b - r) / delta) + 2.0)
    } else {
        60.0 * (((r - g) / delta) + 4.0)
    };

    let saturation = if max == 0.0 { 0.0 } else { delta / max };
    (hue, saturation, max)
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
        let state = state.clone();
        let window_weak = window.as_weak();
        window.on_color_hue_changed(move |norm| {
            let mut state = state.borrow_mut();
            let hue = clamp01(norm) * 360.0;
            let sat = state
                .selected_zone_state()
                .map(|zone| rgb_to_hsv(zone.color).1)
                .unwrap_or(1.0);
            let val = state
                .selected_zone_state()
                .map(|zone| rgb_to_hsv(zone.color).2)
                .unwrap_or(1.0);
            let rgb = hsv_to_rgb(hue, sat, val);
            if let Some(window) = window_weak.upgrade() {
                window.set_color_hue(hue);
                window.set_color_saturation(sat);
                window.set_color_value(val);
                window.set_red(rgb.red as i32);
                window.set_green(rgb.green as i32);
                window.set_blue(rgb.blue as i32);
                window.set_picker_base_color(slint::Color::from_rgb_u8(
                    hsv_to_rgb(hue, 1.0, 1.0).red,
                    hsv_to_rgb(hue, 1.0, 1.0).green,
                    hsv_to_rgb(hue, 1.0, 1.0).blue,
                ));
                window.set_selected_color(slint::Color::from_rgb_u8(rgb.red, rgb.green, rgb.blue));
            }
            state.status = format!("color hue set to {:.0}°", hue);
        });
    }

    {
        let state = state.clone();
        let window_weak = window.as_weak();
        window.on_color_sv_changed(move |sat_norm, val_norm| {
            let mut state = state.borrow_mut();
            let hue = window_weak
                .upgrade()
                .map(|window| window.get_color_hue())
                .unwrap_or(0.0);
            let sat = clamp01(sat_norm);
            let val = 1.0 - clamp01(val_norm);
            let rgb = hsv_to_rgb(hue, sat, val);
            if let Some(window) = window_weak.upgrade() {
                window.set_color_saturation(sat);
                window.set_color_value(val);
                window.set_red(rgb.red as i32);
                window.set_green(rgb.green as i32);
                window.set_blue(rgb.blue as i32);
                window.set_selected_color(slint::Color::from_rgb_u8(rgb.red, rgb.green, rgb.blue));
            }
            state.status = format!("color updated to {},{},{}", rgb.red, rgb.green, rgb.blue);
        });
    }

    {
        let state = state.borrow();
        sync_window(&window, &state);
    }

    window.run()
}
