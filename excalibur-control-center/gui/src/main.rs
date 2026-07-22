use std::cell::RefCell;
use std::rc::Rc;

use excalibur_control_center_backend::{
    CpuFrequency, CpuLoad, FanSpeeds, GpuFrequency, GpuLoad, GpuMode, KeyboardZone,
    KeyboardZoneSelection, KeyboardZoneState, MemoryStats, RgbColor, StorageStats, SysfsBackend,
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
    gpu_load: GpuLoad,
    memory_stats: MemoryStats,
    storage_stats: StorageStats,
    active_tab: AppTab,
    selected_zone: KeyboardZoneSelection,
    display_mode_warning: String,
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
            gpu_load: GpuLoad::default(),
            memory_stats: MemoryStats::default(),
            storage_stats: StorageStats::default(),
            active_tab: AppTab::SystemMode,
            selected_zone: KeyboardZoneSelection::All,
            display_mode_warning: String::new(),
            status: String::new(),
        };
        state.refresh_initial();
        state
    }

    fn refresh_initial(&mut self) {
        match self.backend.read_state() {
            Ok(state) => {
                self.zones = state.keyboard_zones;
                self.gpu_mode = state.gpu_mode;
                self.fan_speeds = state.fan_speeds;
                self.cpu_frequency = state.cpu_frequency;
                self.cpu_load = state.cpu_load;
                self.gpu_frequency = state.gpu_frequency;
                self.gpu_load = state.gpu_load;
                self.memory_stats = state.memory_stats;
                self.storage_stats = state.storage_stats;
                self.status = "refreshed hardware state".into();
            }
            Err(err) => {
                self.status = format!("refresh failed: {err}");
            }
        }
    }

    fn refresh_active_tab(&mut self) {
        match self.active_tab {
            AppTab::SystemMode => self.refresh_system_mode(),
            AppTab::DisplayMode => self.refresh_display_mode(),
            AppTab::LedControl => self.refresh_led_control(),
            AppTab::About => {}
        }
    }

    fn refresh_system_mode(&mut self) {
        self.fan_speeds = self.backend.read_fan_speeds().unwrap_or_default();
        self.cpu_frequency = self.backend.read_cpu_frequency().unwrap_or_default();
        self.cpu_load = self.backend.read_cpu_load().unwrap_or_default();
        self.gpu_frequency = self.backend.read_gpu_frequency();
        self.gpu_load = self.backend.read_gpu_load();
        self.memory_stats = self.backend.read_memory_stats().unwrap_or_default();
        self.storage_stats = self.backend.read_storage_stats("/").unwrap_or_default();
    }

    fn refresh_display_mode(&mut self) {
        match self.backend.read_gpu_mode() {
            Ok(mode) => {
                self.gpu_mode = mode;
            }
            Err(err) => {
                self.status = format!("gpu mode read failed: {err}");
            }
        }

        self.fan_speeds = self.backend.read_fan_speeds().unwrap_or_default();
    }

    fn refresh_led_control(&mut self) {
        match self.backend.list_keyboard_zones() {
            Ok(zones) => self.update_zones(zones),
            Err(err) => {
                self.status = format!("LED sync failed: {err}");
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
        let current_mode = match self.backend.read_gpu_mode() {
            Ok(mode) => {
                self.gpu_mode = mode;
                mode
            }
            Err(err) => {
                self.status = format!("gpu mode read failed: {err}");
                return;
            }
        };

        self.display_mode_warning = gpu_mode_transition_warning(current_mode, mode).to_string();

        if current_mode == mode {
            self.status = format!("gpu mode is already {mode}");
            return;
        }

        match self.backend.write_gpu_mode(mode) {
            Ok(()) => match self.backend.read_gpu_mode() {
                Ok(active_mode) => {
                    self.gpu_mode = active_mode;
                    if active_mode == mode {
                        self.status = format!("gpu mode set to {mode}");
                    } else {
                        self.status =
                            format!("requested {mode}; firmware still reports {active_mode}");
                    }
                }
                Err(err) => {
                    self.status = format!("gpu mode readback failed after write: {err}");
                }
            },
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

    fn led_editor_state(&self) -> Option<KeyboardZoneState> {
        match self.selected_zone {
            KeyboardZoneSelection::One(zone) => {
                self.zones.iter().find(|entry| entry.name == zone).cloned()
            }
            KeyboardZoneSelection::All => self
                .zones
                .iter()
                .find(|entry| entry.name == KeyboardZone::Left)
                .cloned(),
        }
    }

    fn zone_state(&self, zone: KeyboardZone) -> Option<&KeyboardZoneState> {
        self.zones.iter().find(|entry| entry.name == zone)
    }

    fn update_zones(&mut self, zones: Vec<KeyboardZoneState>) {
        for zone in zones {
            if let Some(existing) = self
                .zones
                .iter_mut()
                .find(|existing| existing.name == zone.name)
            {
                *existing = zone;
            } else {
                self.zones.push(zone);
            }
        }
    }
}

fn sync_window(window: &MainWindow, state: &AppState) {
    sync_window_common(window, state);
    sync_active_tab(window, state);
}

fn sync_window_common(window: &MainWindow, state: &AppState) {
    window.set_status(state.status.clone().into());
    window.set_active_tab(state.active_tab);
}

fn sync_active_tab(window: &MainWindow, state: &AppState) {
    match state.active_tab {
        AppTab::SystemMode => sync_tab_system_mode(window, state),
        AppTab::DisplayMode => sync_tab_display_mode(window, state),
        AppTab::LedControl => sync_tab_led_control(window, state),
        AppTab::About => {}
    }
}

fn sync_tab_system_mode(window: &MainWindow, state: &AppState) {
    sync_fan_speed_fields(window, state);
    sync_performance_fields(window, state);
}

fn sync_tab_display_mode(window: &MainWindow, state: &AppState) {
    window.set_gpu_mode(state.gpu_mode.as_str().into());
    window.set_display_mode_warning(state.display_mode_warning.clone().into());
    sync_fan_speed_fields(window, state);
}

fn sync_tab_led_control(window: &MainWindow, state: &AppState) {
    window.set_active_zone(state.selected_zone.as_str().into());
    sync_led_preview_fields(window, state);
    sync_led_brightness_editor_fields(window, state);
}

fn sync_fan_speed_fields(window: &MainWindow, state: &AppState) {
    window.set_cpu_fan_rpm(format_fan_rpm(state.fan_speeds.cpu_rpm).into());
    window.set_gpu_fan_rpm(format_fan_rpm(state.fan_speeds.gpu_rpm).into());
}

fn sync_performance_fields(window: &MainWindow, state: &AppState) {
    window.set_cpu_frequency(format_cpu_frequency(state.cpu_frequency.average_ghz).into());
    window.set_cpu_load_percent(format_metric_percent(state.cpu_load.used_percent).into());
    window.set_cpu_load_fill(format_metric_fill(state.cpu_load.used_percent));
    window.set_gpu_frequency(format_gpu_frequency(state.gpu_frequency.graphics_ghz).into());
    window.set_gpu_load_percent(format_metric_percent(state.gpu_load.used_percent).into());
    window.set_gpu_load_fill(format_metric_fill(state.gpu_load.used_percent));
    window.set_memory_usage(format_memory_usage(&state.memory_stats).into());
    window.set_memory_percent(format_memory_percent(state.memory_stats.used_percent).into());
    window.set_memory_fill(format_memory_fill(state.memory_stats.used_percent));
    window.set_storage_usage(format_storage_usage(&state.storage_stats).into());
    window.set_storage_percent(format_storage_percent(state.storage_stats.used_percent).into());
    window.set_storage_fill(format_storage_fill(state.storage_stats.used_percent));
}

fn sync_led_preview_fields(window: &MainWindow, state: &AppState) {
    window.set_applied_left_color(zone_color(state, KeyboardZone::Left));
    window.set_applied_middle_color(zone_color(state, KeyboardZone::Middle));
    window.set_applied_right_color(zone_color(state, KeyboardZone::Right));
    window.set_applied_bias_color(zone_color(state, KeyboardZone::Bias));
}

fn sync_led_editor_fields(window: &MainWindow, state: &AppState) {
    window.set_suppress_led_edit_events(true);

    if let Some(zone) = state.led_editor_state() {
        sync_led_brightness_editor_values(window, &zone);
        window.set_red(zone.color.red as i32);
        window.set_green(zone.color.green as i32);
        window.set_blue(zone.color.blue as i32);
        let (h, s, _) = rgb_to_hsv(zone.color);
        window.set_color_hue(h);
        window.set_color_saturation(s);
    }

    window.set_suppress_led_edit_events(false);
}

fn sync_led_brightness_editor_fields(window: &MainWindow, state: &AppState) {
    window.set_suppress_led_edit_events(true);

    if let Some(zone) = state.led_editor_state() {
        sync_led_brightness_editor_values(window, &zone);
    }

    window.set_suppress_led_edit_events(false);
}

fn sync_led_brightness_editor_values(window: &MainWindow, zone: &KeyboardZoneState) {
    window.set_brightness(zone.brightness as i32);
    window.set_brightness_slider(zone.brightness as f32);
}

fn gpu_mode_transition_warning(current: GpuMode, target: GpuMode) -> &'static str {
    match (current, target) {
        (GpuMode::Discrete, GpuMode::Hybrid) | (GpuMode::Discrete, GpuMode::Uma) => {
            "Switching away from Discrete mode may require a reboot. Hybrid mode routes the display through the integrated GPU and uses NVIDIA through PRIME/On-Demand offload. UMA / Integrated mode uses only the integrated GPU path. Reboot into a matching integrated or hybrid graphics profile."
        }
        (GpuMode::Hybrid, GpuMode::Discrete) | (GpuMode::Uma, GpuMode::Discrete) => {
            "Switching to Discrete mode may require a reboot. Discrete mode routes the display through the NVIDIA GPU. Reboot into an NVIDIA-only / Performance graphics profile."
        }
        _ => "",
    }
}

fn zone_color(state: &AppState, zone: KeyboardZone) -> slint::Color {
    state
        .zone_state(zone)
        .map(|zone| slint::Color::from_rgb_u8(zone.color.red, zone.color.green, zone.color.blue))
        .unwrap_or_else(|| slint::Color::from_rgb_u8(0, 0, 0))
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

fn color_wheel_to_hsv(x_norm: f32, y_norm: f32) -> Option<(f32, f32, f32)> {
    let dx = clamp01(x_norm) - 0.5;
    let dy = clamp01(y_norm) - 0.5;
    let radius = (dx * dx + dy * dy).sqrt();
    if radius > 0.5 {
        return None;
    }
    let saturation = (radius * 2.0).clamp(0.0, 1.0);
    let mut hue = dy.atan2(dx).to_degrees();
    if hue < 0.0 {
        hue += 360.0;
    }
    Some((hue, saturation, 1.0))
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
            state.refresh_active_tab();
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
            state.refresh_active_tab();
            if let Some(window) = window_weak.upgrade() {
                sync_window(&window, &state);
                if state.active_tab == AppTab::LedControl {
                    sync_led_editor_fields(&window, &state);
                }
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
                sync_led_editor_fields(&window, &state);
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
        window.on_apply_led_settings(move || {
            let mut state = state.borrow_mut();
            let Some(window) = window_weak.upgrade() else {
                return;
            };

            let brightness = window.get_brightness_slider().round() as u8;
            let color = RgbColor::new(
                window.get_red() as u8,
                window.get_green() as u8,
                window.get_blue() as u8,
            );
            let selected_zone = state.selected_zone;
            let selected_state = state.selected_zone_state();
            let color_changed = selected_state
                .as_ref()
                .map(|zone| zone.color != color)
                .unwrap_or(true);

            if color_changed {
                match state.backend.set_keyboard_color(selected_zone, color) {
                    Ok(zones) => state.update_zones(zones),
                    Err(err) => {
                        state.status = format!("color write failed: {err}");
                        sync_window(&window, &state);
                        return;
                    }
                }
            }

            match state
                .backend
                .set_keyboard_brightness(selected_zone, brightness)
            {
                Ok(zones) => {
                    state.update_zones(zones);
                }
                Err(err) => {
                    state.status = format!("brightness write failed: {err}");
                    sync_window(&window, &state);
                    return;
                }
            }

            state.status = if color_changed {
                format!(
                    "color set to {},{},{} for {}",
                    color.red,
                    color.green,
                    color.blue,
                    selected_zone.as_str(),
                )
            } else {
                format!(
                    "brightness set to {} for {}",
                    brightness,
                    selected_zone.as_str(),
                )
            };

            sync_window(&window, &state);
            sync_led_editor_fields(&window, &state);
        });
    }

    {
        let state = state.clone();
        let window_weak = window.as_weak();
        window.on_color_wheel_changed(move |x_norm, y_norm| {
            let mut state = state.borrow_mut();
            let Some((hue, sat, val)) = color_wheel_to_hsv(x_norm, y_norm) else {
                state.status = "color wheel click ignored outside circle".to_string();
                return;
            };
            let rgb = hsv_to_rgb(hue, sat, val);
            if let Some(window) = window_weak.upgrade() {
                window.set_color_hue(hue);
                window.set_color_saturation(sat);
                window.set_red(rgb.red as i32);
                window.set_green(rgb.green as i32);
                window.set_blue(rgb.blue as i32);
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
