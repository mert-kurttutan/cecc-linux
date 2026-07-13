pub mod model;
pub mod sysfs;

pub use model::{
    ControlCenterState, CpuFrequency, FanSpeeds, GpuFrequency, GpuMode, KeyboardZone,
    KeyboardZoneSelection, KeyboardZoneState, MemoryStats, RgbColor,
};
pub use sysfs::{BackendError, SysfsBackend};
