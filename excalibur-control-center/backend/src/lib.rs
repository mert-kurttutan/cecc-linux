pub mod model;
pub mod sysfs;

pub use model::{
    ControlCenterState, CpuFrequency, CpuLoad, FanSpeeds, GpuFrequency, GpuMode, KeyboardZone,
    KeyboardZoneSelection, KeyboardZoneState, MemoryStats, RgbColor, StorageStats,
};
pub use sysfs::{BackendError, SysfsBackend};
