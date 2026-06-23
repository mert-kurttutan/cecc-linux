mod sysfs;

pub use sysfs::SysfsBackend;

use crate::model::{ControlCenterState, GpuMode, KeyboardZone, KeyboardZoneName, RgbColor};

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

pub trait Backend {
    fn read_state(&self) -> Result<ControlCenterState, BackendError>;
    fn read_gpu_mode(&self) -> Result<Option<GpuMode>, BackendError>;
    fn write_gpu_mode(&self, mode: GpuMode) -> Result<(), BackendError>;

    fn list_keyboard_zones(&self) -> Result<Vec<KeyboardZone>, BackendError>;
    fn read_keyboard_zone(&self, zone: KeyboardZoneName) -> Result<KeyboardZone, BackendError>;
    fn write_keyboard_brightness(
        &self,
        zone: KeyboardZoneName,
        brightness: u32,
    ) -> Result<(), BackendError>;
    fn write_keyboard_color(
        &self,
        zone: KeyboardZoneName,
        color: RgbColor,
    ) -> Result<(), BackendError>;

    fn keyboard_zones_for_target(
        &self,
        zone: Option<KeyboardZoneName>,
    ) -> Result<Vec<KeyboardZoneName>, BackendError> {
        match zone {
            Some(zone) => Ok(vec![zone]),
            None => Ok(vec![
                KeyboardZoneName::Left,
                KeyboardZoneName::Middle,
                KeyboardZoneName::Right,
                KeyboardZoneName::Bias,
            ]),
        }
    }

    fn read_keyboard_zones(
        &self,
        zone: Option<KeyboardZoneName>,
    ) -> Result<Vec<KeyboardZone>, BackendError> {
        match zone {
            Some(zone) => Ok(vec![self.read_keyboard_zone(zone)?]),
            None => self.list_keyboard_zones(),
        }
    }

    fn set_keyboard_brightness(
        &self,
        zone: Option<KeyboardZoneName>,
        brightness: u32,
    ) -> Result<Vec<KeyboardZone>, BackendError> {
        for target in self.keyboard_zones_for_target(zone)? {
            self.write_keyboard_brightness(target, brightness)?;
        }

        self.read_keyboard_zones(zone)
    }

    fn set_keyboard_color(
        &self,
        zone: Option<KeyboardZoneName>,
        color: RgbColor,
    ) -> Result<Vec<KeyboardZone>, BackendError> {
        for target in self.keyboard_zones_for_target(zone)? {
            self.write_keyboard_color(target, color)?;
        }

        self.read_keyboard_zones(zone)
    }
}
