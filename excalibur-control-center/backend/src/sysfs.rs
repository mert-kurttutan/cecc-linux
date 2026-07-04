use std::fs;
use std::path::{Path, PathBuf};

use crate::model::{ControlCenterState, GpuMode, KeyboardZone, KeyboardZoneName, RgbColor};

const DEFAULT_SYSFS_ROOT: &str = "/sys";
const GPU_MODE_PATH: &str = "module/casper_wmi/parameters/gpu_mode";
const LED_ROOT: &str = "class/leds";

#[derive(Debug, thiserror::Error)]
pub enum BackendError {
    #[error("{0}")]
    Io(#[from] std::io::Error),
    #[error("invalid data in {path}: {value}")]
    Parse { path: String, value: String },
    #[error("unknown keyboard zone: {0}")]
    UnknownZone(String),
    #[error("value out of range: {0}")]
    OutOfRange(String),
}

#[derive(Debug, Clone)]
pub struct SysfsBackend {
    root: PathBuf,
}

impl Default for SysfsBackend {
    fn default() -> Self {
        Self::new(DEFAULT_SYSFS_ROOT)
    }
}

impl SysfsBackend {
    pub fn new(root: impl Into<PathBuf>) -> Self {
        Self { root: root.into() }
    }

    fn path(&self, rel: impl AsRef<Path>) -> PathBuf {
        self.root.join(rel)
    }

    fn read_string(&self, rel: impl AsRef<Path>) -> Result<String, BackendError> {
        Ok(fs::read_to_string(self.path(rel))?)
    }

    fn write_string(&self, rel: impl AsRef<Path>, value: &str) -> Result<(), BackendError> {
        fs::write(self.path(rel), value.as_bytes())?;
        Ok(())
    }

    fn zone_sysfs_name(zone: KeyboardZoneName) -> &'static str {
        match zone {
            KeyboardZoneName::Left => "casper:rgb:kbd_zoned_backlight-left",
            KeyboardZoneName::Middle => "casper:rgb:kbd_zoned_backlight-middle",
            KeyboardZoneName::Right => "casper:rgb:kbd_zoned_backlight-right",
            KeyboardZoneName::Bias => "casper:rgb:biaslight",
        }
    }

    fn zone_brightness_path(&self, zone: KeyboardZoneName) -> PathBuf {
        self.path([LED_ROOT, Self::zone_sysfs_name(zone), "brightness"].join("/"))
    }

    fn zone_max_brightness_path(&self, zone: KeyboardZoneName) -> PathBuf {
        self.path([LED_ROOT, Self::zone_sysfs_name(zone), "max_brightness"].join("/"))
    }

    fn parse_u32(path: &Path, value: &str) -> Result<u32, BackendError> {
        value
            .trim()
            .parse::<u32>()
            .map_err(|_| BackendError::Parse {
                path: path.display().to_string(),
                value: value.trim().to_string(),
            })
    }

    fn parse_rgb(value: &str) -> Result<RgbColor, BackendError> {
        let parts: Vec<_> = value.split_whitespace().collect();
        if parts.len() != 3 {
            return Err(BackendError::Parse {
                path: "multi_intensity".to_string(),
                value: value.trim().to_string(),
            });
        }

        let red = parts[0].parse::<u8>().map_err(|_| BackendError::Parse {
            path: "multi_intensity".into(),
            value: value.trim().into(),
        })?;
        let green = parts[1].parse::<u8>().map_err(|_| BackendError::Parse {
            path: "multi_intensity".into(),
            value: value.trim().into(),
        })?;
        let blue = parts[2].parse::<u8>().map_err(|_| BackendError::Parse {
            path: "multi_intensity".into(),
            value: value.trim().into(),
        })?;

        Ok(RgbColor { red, green, blue })
    }

    fn parse_gpu_mode(value: &str) -> Result<Option<GpuMode>, BackendError> {
        match value.trim() {
            "hybrid" => Ok(Some(GpuMode::Hybrid)),
            "discrete" => Ok(Some(GpuMode::Discrete)),
            "uma" => Ok(Some(GpuMode::Uma)),
            "" => Ok(None),
            other => Err(BackendError::Parse {
                path: GPU_MODE_PATH.to_string(),
                value: other.to_string(),
            }),
        }
    }

    fn zone_rel(zone: KeyboardZoneName, file: &str) -> String {
        [LED_ROOT, Self::zone_sysfs_name(zone), file].join("/")
    }
    pub fn read_state(&self) -> Result<ControlCenterState, BackendError> {
        Ok(ControlCenterState {
            gpu_mode: self.read_gpu_mode()?,
            keyboard_zones: self.list_keyboard_zones()?,
        })
    }

    pub fn read_gpu_mode(&self) -> Result<Option<GpuMode>, BackendError> {
        let path = self.path(GPU_MODE_PATH);
        let value = self.read_string(GPU_MODE_PATH)?;
        Self::parse_gpu_mode(&value).map_err(|err| match err {
            BackendError::Parse { .. } => BackendError::Parse {
                path: path.display().to_string(),
                value: value.trim().to_string(),
            },
            other => other,
        })
    }

    pub fn write_gpu_mode(&self, mode: GpuMode) -> Result<(), BackendError> {
        self.write_string(GPU_MODE_PATH, &format!("{mode}"))
    }

    pub fn list_keyboard_zones(&self) -> Result<Vec<KeyboardZone>, BackendError> {
        [
            KeyboardZoneName::Left,
            KeyboardZoneName::Middle,
            KeyboardZoneName::Right,
            KeyboardZoneName::Bias,
        ]
        .into_iter()
        .map(|zone| self.read_keyboard_zone(zone))
        .collect()
    }

    pub fn read_keyboard_zone(&self, zone: KeyboardZoneName) -> Result<KeyboardZone, BackendError> {
        let sysfs_name = Self::zone_sysfs_name(zone).to_string();
        let brightness_path = self.zone_brightness_path(zone);
        let max_brightness_path = self.zone_max_brightness_path(zone);

        if !brightness_path.exists() {
            return Err(BackendError::UnknownZone(sysfs_name));
        }

        let brightness = Self::parse_u32(
            &brightness_path,
            &self.read_string(Self::zone_rel(zone, "brightness"))?,
        )?;
        let max_brightness = Self::parse_u32(
            &max_brightness_path,
            &self.read_string(Self::zone_rel(zone, "max_brightness"))?,
        )?;
        let color = Self::parse_rgb(&self.read_string(Self::zone_rel(zone, "multi_intensity"))?)?;

        Ok(KeyboardZone {
            name: zone,
            sysfs_name,
            brightness,
            max_brightness,
            color,
        })
    }

    pub fn write_keyboard_brightness(
        &self,
        zone: KeyboardZoneName,
        brightness: u32,
    ) -> Result<(), BackendError> {
        let max_brightness = Self::parse_u32(
            &self.zone_max_brightness_path(zone),
            &self.read_string(Self::zone_rel(zone, "max_brightness"))?,
        )?;

        if brightness > max_brightness {
            return Err(BackendError::OutOfRange(format!(
                "{brightness} > {max_brightness} for {}",
                Self::zone_sysfs_name(zone)
            )));
        }

        self.write_string(Self::zone_rel(zone, "brightness"), &brightness.to_string())
    }

    pub fn write_keyboard_color(
        &self,
        zone: KeyboardZoneName,
        color: RgbColor,
    ) -> Result<(), BackendError> {
        let brightness = Self::parse_u32(
            &self.zone_brightness_path(zone),
            &self.read_string(Self::zone_rel(zone, "brightness"))?,
        )?;

        self.write_string(
            Self::zone_rel(zone, "multi_intensity"),
            &format!("{} {} {}", color.red, color.green, color.blue),
        )?;

        self.write_string(Self::zone_rel(zone, "brightness"), &brightness.to_string())
    }

    pub fn keyboard_zones_for_target(
        &self,
        zone: Option<KeyboardZoneName>,
    ) -> Vec<KeyboardZoneName> {
        match zone {
            Some(zone) => vec![zone],
            None => vec![
                KeyboardZoneName::Left,
                KeyboardZoneName::Middle,
                KeyboardZoneName::Right,
                KeyboardZoneName::Bias,
            ],
        }
    }

    pub fn read_keyboard_zones(
        &self,
        zone: Option<KeyboardZoneName>,
    ) -> Result<Vec<KeyboardZone>, BackendError> {
        match zone {
            Some(zone) => Ok(vec![self.read_keyboard_zone(zone)?]),
            None => self.list_keyboard_zones(),
        }
    }

    pub fn set_keyboard_brightness(
        &self,
        zone: Option<KeyboardZoneName>,
        brightness: u32,
    ) -> Result<Vec<KeyboardZone>, BackendError> {
        for target in self.keyboard_zones_for_target(zone) {
            self.write_keyboard_brightness(target, brightness)?;
        }

        self.read_keyboard_zones(zone)
    }

    pub fn set_keyboard_color(
        &self,
        zone: Option<KeyboardZoneName>,
        color: RgbColor,
    ) -> Result<Vec<KeyboardZone>, BackendError> {
        for target in self.keyboard_zones_for_target(zone) {
            self.write_keyboard_color(target, color)?;
        }

        self.read_keyboard_zones(zone)
    }
}
