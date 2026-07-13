use std::cell::RefCell;
use std::rc::Rc;

use excalibur_control_center_backend::{
    CpuFrequency, CpuLoad, FanSpeeds, GpuFrequency, GpuMode, KeyboardZone, KeyboardZoneSelection,
    KeyboardZoneState, MemoryStats, RgbColor, StorageStats, SysfsBackend,
};
use excalibur_control_center_gui::ui::{
    AppTab, GpuMode as UiGpuMode, KeyboardZoneSelection as UiKeyboardZoneSelection, MainWindow,
};
use slint::ComponentHandle;
use slint::winit_030::WinitWindowAccessor;

fn zone_selection_from_ui(zone: UiKeyboardZoneSelection) -> KeyboardZoneSelection {
    match zone {
        UiKeyboardZoneSelection::All => KeyboardZoneSelection::All,
        UiKeyboardZoneSelection::Left => KeyboardZoneSelection::One(KeyboardZone::Left),
        UiKeyboardZoneSelection::Middle => KeyboardZoneSelection::One(KeyboardZone::Middle),
        UiKeyboardZoneSelection::Right => KeyboardZoneSelection::One(KeyboardZone::Right),
        UiKeyboardZoneSelection::Bias => KeyboardZoneSelection::One(KeyboardZone::Bias),
    }
}

#[derive(Debug)]
struct AppState {
    backend: SysfsBackend,
    zones: Vec<KeyboardZoneState>,
    gpu_mode: GpuMode,
    fan_speeds: FanSpeeds,
    cpu_frequency: CpuFrequency,
    cpu_load: CpuLoad,
    gpu_frequency: GpuFrequency,
    memory_stats: MemoryStats,
    storage_stats: StorageStats,
    active_tab: AppTab,
    selected_zone: KeyboardZoneSelection,
    status: String,
}

impl AppState {
    fn new() -> Self {
        let mut state = Self {
            backend: SysfsBackend::default(),
            zones: Vec::new(),
            gpu_mode: GpuMode::Hybrid,
            fan_speeds: FanSpeeds::default(),
            cpu_frequency: CpuFrequency::default(),
            cpu_load: CpuLoad::default(),
            gpu_frequency: GpuFrequency::default(),
            memory_stats: MemoryStats::default(),
            storage_stats: StorageStats::default(),
            active_tab: AppTab::SystemMode,
            selected_zone: KeyboardZoneSelection::All,
            status: String::new(),
        };
        state.refresh();
        state
    }

    fn refresh(&mut self) {
        match self.backend.read_state() {
            Ok(state) => {
                self.zones = state.keyboard_zones;
                self.gpu_mode = state.gpu_mode;
                self.fan_speeds = state.fan_speeds;
                self.cpu_frequency = state.cpu_frequency;
                self.cpu_load = state.cpu_load;
                self.gpu_frequency = state.gpu_frequency;
                self.memory_stats = state.memory_stats;
                self.storage_stats = state.storage_stats;
                self.status = "refreshed hardware state".into();
            }
            Err(err) => {
                self.status = format!("refresh failed: {err}");
            }
        }
    }

    fn set_active_tab(&mut self, tab: AppTab) {
        self.active_tab = tab;
    }

    fn set_selected_zone(&mut self, zone: KeyboardZoneSelection) {
        self.selected_zone = zone;
        self.status = format!("selected {}", zone.as_str());
    }

    fn set_gpu_mode(&mut self, mode: GpuMode) {
        match self.backend.write_gpu_mode(mode) {
            Ok(()) => {
                self.gpu_mode = mode;
                self.status = format!("gpu mode set to {mode}");
            }
            Err(err) => {
                self.status = format!("gpu mode write failed: {err}");
            }
        }
    }

    fn selected_zone_state(&self) -> Option<KeyboardZoneState> {
        match self.selected_zone {
            KeyboardZoneSelection::One(zone) => {
                self.zones.iter().find(|entry| entry.name == zone).cloned()
            }
            KeyboardZoneSelection::All => None,
        }
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
    window.set_active_zone(state.selected_zone.as_str().into());
    window.set_zones_summary(state.zone_summary().into());
    window.set_active_tab(state.active_tab);
    window.set_gpu_mode(state.gpu_mode.as_str().into());
    window.set_cpu_fan_rpm(format_fan_rpm(state.fan_speeds.cpu_rpm).into());
    window.set_gpu_fan_rpm(format_fan_rpm(state.fan_speeds.gpu_rpm).into());
    window.set_cpu_frequency(format_cpu_frequency(state.cpu_frequency.average_ghz).into());
    window.set_cpu_load_percent(format_metric_percent(state.cpu_load.used_percent).into());
    window.set_cpu_load_fill(format_metric_fill(state.cpu_load.used_percent));
    window.set_gpu_frequency(format_gpu_frequency(state.gpu_frequency.graphics_ghz).into());
    window.set_memory_usage(format_memory_usage(&state.memory_stats).into());
    window.set_memory_percent(format_memory_percent(state.memory_stats.used_percent).into());
    window.set_memory_fill(format_memory_fill(state.memory_stats.used_percent));
    window.set_storage_usage(format_storage_usage(&state.storage_stats).into());
    window.set_storage_percent(format_storage_percent(state.storage_stats.used_percent).into());
    window.set_storage_fill(format_storage_fill(state.storage_stats.used_percent));

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

fn format_fan_rpm(rpm: Option<u32>) -> String {
    rpm.map(|value| format!("{value} RPM"))
        .unwrap_or_else(|| "--".to_string())
}

fn format_cpu_frequency(average_ghz: Option<f32>) -> String {
    average_ghz
        .map(|value| format!("{value:.2} GHz"))
        .unwrap_or_else(|| "--".to_string())
}

fn format_gpu_frequency(graphics_ghz: Option<f32>) -> String {
    graphics_ghz
        .map(|value| format!("{value:.2} GHz"))
        .unwrap_or_else(|| "--".to_string())
}

fn format_memory_usage(stats: &MemoryStats) -> String {
    match (stats.used_bytes, stats.total_bytes) {
        (Some(used), Some(total)) => {
            format!("{:.1}/{:.1} GiB", bytes_to_gib(used), bytes_to_gib(total))
        }
        _ => "--".to_string(),
    }
}

fn format_memory_percent(used_percent: Option<f32>) -> String {
    format_metric_percent(used_percent)
}

fn format_memory_fill(used_percent: Option<f32>) -> f32 {
    format_metric_fill(used_percent)
}

fn format_storage_usage(stats: &StorageStats) -> String {
    match (stats.used_bytes, stats.total_bytes) {
        (Some(used), Some(total)) => {
            format!("{:.1}/{:.1} GiB", bytes_to_gib(used), bytes_to_gib(total))
        }
        _ => "--".to_string(),
    }
}

fn format_storage_percent(used_percent: Option<f32>) -> String {
    format_metric_percent(used_percent)
}

fn format_storage_fill(used_percent: Option<f32>) -> f32 {
    format_metric_fill(used_percent)
}

fn format_metric_percent(percent: Option<f32>) -> String {
    percent
        .map(|value| format!("{value:.1}%"))
        .unwrap_or_else(|| "--".to_string())
}

fn format_metric_fill(percent: Option<f32>) -> f32 {
    percent
        .map(|value| (value / 100.0).clamp(0.0, 1.0))
        .unwrap_or(0.0)
}

fn bytes_to_gib(bytes: u64) -> f32 {
    bytes as f32 / 1024.0 / 1024.0 / 1024.0
}

fn gpu_mode_from_ui(mode: UiGpuMode) -> GpuMode {
    match mode {
        UiGpuMode::Hybrid => GpuMode::Hybrid,
        UiGpuMode::Discrete => GpuMode::Discrete,
        UiGpuMode::Uma => GpuMode::Uma,
    }
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
    window.set_app_version(env!("CARGO_PKG_VERSION").into());
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
        window.on_select_tab(move |index| {
            let mut state = state.borrow_mut();
            state.set_active_tab(index);
            if let Some(window) = window_weak.upgrade() {
                sync_window(&window, &state);
            }
        });
    }

    {
        let window_weak = window.as_weak();
        window.on_start_drag_window(move || {
            if let Some(window) = window_weak.upgrade() {
                window.window().with_winit_window(|window| {
                    let _ = window.drag_window();
                });
            }
        });
    }

    {
        let state = state.clone();
        let window_weak = window.as_weak();
        window.on_select_zone(move |zone| {
            let mut state = state.borrow_mut();
            state.set_selected_zone(zone_selection_from_ui(zone));
            if let Some(window) = window_weak.upgrade() {
                sync_window(&window, &state);
            }
        });
    }

    {
        let state = state.clone();
        let window_weak = window.as_weak();
        window.on_set_gpu_mode(move |mode| {
            let mut state = state.borrow_mut();
            state.set_gpu_mode(gpu_mode_from_ui(mode));
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
                window.set_brightness_slider(brightness as f32);
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
                .map(|window| window.get_brightness_slider().round() as u8)
                .unwrap_or(0);

            let result = state
                .backend
                .set_keyboard_brightness(state.selected_zone, brightness);

            match result {
                Ok(zones) => {
                    state.zones = zones;
                    state.status = format!(
                        "brightness set to {} for {}",
                        brightness,
                        state.selected_zone.as_str()
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

            let result = state.backend.set_keyboard_color(state.selected_zone, color);

            match result {
                Ok(zones) => {
                    state.zones = zones;
                    state.status = format!(
                        "color set to {},{},{} for {}",
                        color.red,
                        color.green,
                        color.blue,
                        state.selected_zone.as_str()
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
