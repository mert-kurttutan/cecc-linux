use std::fmt;

#[derive(Debug, Clone, Copy)]
pub enum GpuMode {
    Hybrid,
    Discrete,
    Uma,
}

impl GpuMode {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Hybrid => "hybrid",
            Self::Discrete => "discrete",
            Self::Uma => "uma",
        }
    }
}

impl fmt::Display for GpuMode {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum KeyboardZone {
    Left,
    Middle,
    Right,
    Bias,
}

impl KeyboardZone {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Left => "left",
            Self::Middle => "middle",
            Self::Right => "right",
            Self::Bias => "bias",
        }
    }
}

impl fmt::Display for KeyboardZone {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum KeyboardZoneSelection {
    All,
    One(KeyboardZone),
}

impl KeyboardZoneSelection {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::All => "all",
            Self::One(zone) => zone.as_str(),
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub struct RgbColor {
    pub red: u8,
    pub green: u8,
    pub blue: u8,
}

impl RgbColor {
    pub const fn new(red: u8, green: u8, blue: u8) -> Self {
        Self { red, green, blue }
    }
}

#[derive(Debug, Clone)]
pub struct KeyboardZoneState {
    pub name: KeyboardZone,
    pub sysfs_name: String,
    pub brightness: u8,
    pub max_brightness: u8,
    pub color: RgbColor,
}

#[derive(Debug, Clone, Copy, Default)]
pub struct FanSpeeds {
    pub cpu_rpm: Option<u32>,
    pub gpu_rpm: Option<u32>,
}

#[derive(Debug, Clone, Copy, Default)]
pub struct CpuFrequency {
    pub average_ghz: Option<f32>,
}

#[derive(Debug, Clone, Copy, Default)]
pub struct CpuLoad {
    pub used_percent: Option<f32>,
}

#[derive(Debug, Clone, Copy, Default)]
pub struct GpuFrequency {
    pub graphics_ghz: Option<f32>,
}

#[derive(Debug, Clone, Copy, Default)]
pub struct GpuLoad {
    pub used_percent: Option<f32>,
}

#[derive(Debug, Clone, Copy, Default)]
pub struct MemoryStats {
    pub used_bytes: Option<u64>,
    pub total_bytes: Option<u64>,
    pub used_percent: Option<f32>,
}

#[derive(Debug, Clone, Copy, Default)]
pub struct StorageStats {
    pub used_bytes: Option<u64>,
    pub total_bytes: Option<u64>,
    pub used_percent: Option<f32>,
}

#[derive(Debug, Clone)]
pub struct ControlCenterState {
    pub gpu_mode: GpuMode,
    pub keyboard_zones: Vec<KeyboardZoneState>,
    pub fan_speeds: FanSpeeds,
    pub cpu_frequency: CpuFrequency,
    pub cpu_load: CpuLoad,
    pub gpu_frequency: GpuFrequency,
    pub gpu_load: GpuLoad,
    pub memory_stats: MemoryStats,
    pub storage_stats: StorageStats,
}
