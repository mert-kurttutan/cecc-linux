use eframe::egui;
use excalibur_control_center_backend::{
    Backend, KeyboardZone, KeyboardZoneName, RgbColor, SysfsBackend,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum ZoneSelection {
    All,
    Left,
    Middle,
    Right,
    Bias,
}

impl ZoneSelection {
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
struct KeyboardApp {
    backend: SysfsBackend,
    zones: Vec<KeyboardZone>,
    selected_zone: ZoneSelection,
    loaded_zone: Option<ZoneSelection>,
    brightness: u32,
    red: u8,
    green: u8,
    blue: u8,
    status: String,
}

impl KeyboardApp {
    fn new() -> Self {
        let backend = SysfsBackend::default();
        let mut app = Self {
            backend,
            zones: Vec::new(),
            selected_zone: ZoneSelection::All,
            loaded_zone: None,
            brightness: 0,
            red: 255,
            green: 255,
            blue: 255,
            status: String::new(),
        };
        app.refresh();
        app
    }

    fn refresh(&mut self) {
        match self.backend.read_keyboard_zones(None) {
            Ok(zones) => {
                self.zones = zones;
                self.sync_editor_from_selection();
                self.status = "refreshed keyboard state".to_string();
            }
            Err(err) => {
                self.status = format!("refresh failed: {err}");
            }
        }
    }

    fn sync_editor_from_selection(&mut self) {
        if self.loaded_zone == Some(self.selected_zone) {
            return;
        }

        if let Some(zone_name) = self.selected_zone.to_option() {
            if let Some(zone) = self
                .zones
                .iter()
                .find(|entry| entry.name == zone_name)
                .cloned()
            {
                self.brightness = zone.brightness;
                self.red = zone.color.red;
                self.green = zone.color.green;
                self.blue = zone.color.blue;
            } else if let Ok(zone) = self.backend.read_keyboard_zone(zone_name) {
                self.brightness = zone.brightness;
                self.red = zone.color.red;
                self.green = zone.color.green;
                self.blue = zone.color.blue;
            }
        }

        self.loaded_zone = Some(self.selected_zone);
    }

    fn apply_brightness(&mut self) {
        match self
            .backend
            .set_keyboard_brightness(self.selected_zone.to_option(), self.brightness)
        {
            Ok(zones) => {
                self.zones = zones;
                self.status = format!(
                    "brightness set to {} for {}",
                    self.brightness,
                    self.selected_zone.as_label()
                );
                self.refresh();
            }
            Err(err) => self.status = format!("brightness write failed: {err}"),
        }
    }

    fn apply_color(&mut self) {
        let color = RgbColor::new(self.red, self.green, self.blue);
        match self
            .backend
            .set_keyboard_color(self.selected_zone.to_option(), color)
        {
            Ok(zones) => {
                self.zones = zones;
                self.status = format!(
                    "color set to {},{},{} for {}",
                    self.red,
                    self.green,
                    self.blue,
                    self.selected_zone.as_label()
                );
                self.refresh();
            }
            Err(err) => self.status = format!("color write failed: {err}"),
        }
    }
}

impl eframe::App for KeyboardApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        egui::TopBottomPanel::top("top_bar").show(ctx, |ui| {
            ui.horizontal(|ui| {
                ui.heading("Excalibur Control Center");
                if ui.button("Refresh").clicked() {
                    self.refresh();
                }
                ui.label(&self.status);
            });
        });

        egui::SidePanel::left("controls").resizable(false).show(ctx, |ui| {
            ui.heading("Keyboard");
            ui.separator();

            egui::ComboBox::from_label("Zone")
                .selected_text(self.selected_zone.as_label())
                .show_ui(ui, |ui| {
                    for zone in [
                        ZoneSelection::All,
                        ZoneSelection::Left,
                        ZoneSelection::Middle,
                        ZoneSelection::Right,
                        ZoneSelection::Bias,
                    ] {
                        ui.selectable_value(&mut self.selected_zone, zone, zone.as_label());
                    }
                });

            if self.loaded_zone != Some(self.selected_zone) {
                self.sync_editor_from_selection();
            }

            if let Some(zone_name) = self.selected_zone.to_option() {
                if let Some(zone) = self.zones.iter().find(|entry| entry.name == zone_name) {
                    ui.label(format!("Current: {}", zone.sysfs_name));
                } else {
                    ui.label("Current: unknown");
                }
            } else {
                ui.label("Current: all zones");
            }

            ui.separator();
            ui.label("Brightness");
            ui.add(
                egui::Slider::new(&mut self.brightness, 0..=2)
                    .clamping(egui::SliderClamping::Always)
                    .show_value(true),
            );
            if ui.button("Apply brightness").clicked() {
                self.apply_brightness();
            }

            ui.separator();
            ui.label("Color");
            ui.horizontal(|ui| {
                ui.add(egui::DragValue::new(&mut self.red).range(0..=255).prefix("R "));
                ui.add(egui::DragValue::new(&mut self.green).range(0..=255).prefix("G "));
                ui.add(egui::DragValue::new(&mut self.blue).range(0..=255).prefix("B "));
            });
            let mut color = egui::Color32::from_rgb(self.red, self.green, self.blue);
            if ui.color_edit_button_srgba(&mut color).changed() {
                self.red = color.r();
                self.green = color.g();
                self.blue = color.b();
            }
            if ui.button("Apply color").clicked() {
                self.apply_color();
            }
        });

        egui::CentralPanel::default().show(ctx, |ui| {
            ui.heading("Zones");
            ui.separator();

            egui::Grid::new("zones_grid")
                .striped(true)
                .spacing([12.0, 8.0])
                .show(ui, |ui| {
                    ui.label("Zone");
                    ui.label("Brightness");
                    ui.label("Max");
                    ui.label("Color");
                    ui.label("Device");
                    ui.end_row();

                    for zone in &self.zones {
                        ui.label(zone.name.to_string());
                        ui.label(zone.brightness.to_string());
                        ui.label(zone.max_brightness.to_string());
                        ui.label(format!(
                            "{},{},{}",
                            zone.color.red, zone.color.green, zone.color.blue
                        ));
                        ui.label(&zone.sysfs_name);
                        ui.end_row();
                    }
                });
        });
    }
}

fn main() -> Result<(), eframe::Error> {
    let options = eframe::NativeOptions::default();
    eframe::run_native(
        "Excalibur Control Center",
        options,
        Box::new(|_cc| Ok(Box::new(KeyboardApp::new()))),
    )
}
