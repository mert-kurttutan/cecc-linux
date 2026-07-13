use std::fs;
use std::path::{Path, PathBuf};

use crate::model::{
    ControlCenterState, CpuFrequency, FanSpeeds, GpuMode, KeyboardZone, KeyboardZoneSelection,
    KeyboardZoneState, RgbColor,
};

const DEFAULT_SYSFS_ROOT: &str = "/sys";
const GPU_MODE_PATH: &str = "module/casper_wmi/parameters/gpu_mode";
const LED_ROOT: &str = "class/leds";
const HWMON_ROOT: &str = "class/hwmon";
const CPUFREQ_POLICY_ROOT: &str = "devices/system/cpu/cpufreq";
const PROC_CPUINFO_PATH: &str = "/proc/cpuinfo";

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
    cpu_freq_detection: CpuFreqDetection,
}

#[derive(Debug, Clone, Copy)]
enum CpuFreqDetection {
    ScalingCurFreq,
    ProcCpuinfo,
}

impl Default for SysfsBackend {
    fn default() -> Self {
        Self::new(DEFAULT_SYSFS_ROOT)
    }
}

impl SysfsBackend {
    pub fn new(root: impl Into<PathBuf>) -> Self {
        let root = root.into();
        let cpu_freq_detection = Self::detect_cpu_freq_method(&root);

        Self {
            root,
            cpu_freq_detection,
        }
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

    fn zone_sysfs_name(zone: KeyboardZone) -> &'static str {
        match zone {
            KeyboardZone::Left => "casper:rgb:kbd_zoned_backlight-left",
            KeyboardZone::Middle => "casper:rgb:kbd_zoned_backlight-middle",
            KeyboardZone::Right => "casper:rgb:kbd_zoned_backlight-right",
            KeyboardZone::Bias => "casper:rgb:biaslight",
        }
    }

    fn zone_brightness_path(&self, zone: KeyboardZone) -> PathBuf {
        self.path([LED_ROOT, Self::zone_sysfs_name(zone), "brightness"].join("/"))
    }

    fn zone_max_brightness_path(&self, zone: KeyboardZone) -> PathBuf {
        self.path([LED_ROOT, Self::zone_sysfs_name(zone), "max_brightness"].join("/"))
    }

    fn parse_u8(path: &Path, value: &str) -> Result<u8, BackendError> {
        value.trim().parse::<u8>().map_err(|_| BackendError::Parse {
            path: path.display().to_string(),
            value: value.trim().to_string(),
        })
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

    fn parse_f32(path: &Path, value: &str) -> Result<f32, BackendError> {
        value
            .trim()
            .parse::<f32>()
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

    fn parse_gpu_mode(value: &str) -> Result<GpuMode, BackendError> {
        match value.trim() {
            "hybrid" => Ok(GpuMode::Hybrid),
            "discrete" => Ok(GpuMode::Discrete),
            "uma" => Ok(GpuMode::Uma),
            other => Err(BackendError::Parse {
                path: GPU_MODE_PATH.to_string(),
                value: other.to_string(),
            }),
        }
    }

    fn zone_rel(zone: KeyboardZone, file: &str) -> String {
        [LED_ROOT, Self::zone_sysfs_name(zone), file].join("/")
    }
    pub fn read_state(&self) -> Result<ControlCenterState, BackendError> {
        Ok(ControlCenterState {
            gpu_mode: self.read_gpu_mode()?,
            keyboard_zones: self.list_keyboard_zones()?,
            fan_speeds: self.read_fan_speeds().unwrap_or_default(),
            cpu_frequency: self.read_cpu_frequency().unwrap_or_default(),
        })
    }

    pub fn read_gpu_mode(&self) -> Result<GpuMode, BackendError> {
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

    pub fn read_fan_speeds(&self) -> Result<FanSpeeds, BackendError> {
        let mut speeds = FanSpeeds::default();
        let mut fallback_cpu = None;
        let mut fallback_gpu = None;
        let hwmon_root = self.path(HWMON_ROOT);

        if !hwmon_root.exists() {
            return Ok(speeds);
        }

        for entry in fs::read_dir(hwmon_root)? {
            let hwmon_dir = entry?.path();
            if !hwmon_dir.is_dir() {
                continue;
            }

            let chip_name = fs::read_to_string(hwmon_dir.join("name"))
                .unwrap_or_default()
                .trim()
                .to_ascii_lowercase();

            for fan_entry in fs::read_dir(&hwmon_dir)? {
                let fan_path = fan_entry?.path();
                let Some(file_name) = fan_path.file_name().and_then(|name| name.to_str()) else {
                    continue;
                };

                if !file_name.starts_with("fan") || !file_name.ends_with("_input") {
                    continue;
                }

                let rpm = Self::parse_u32(&fan_path, &fs::read_to_string(&fan_path)?)?;
                let fan_base = file_name.trim_end_matches("_input");
                let label = fs::read_to_string(hwmon_dir.join(format!("{fan_base}_label")))
                    .unwrap_or_default()
                    .trim()
                    .to_ascii_lowercase();
                let identity = format!("{chip_name} {label}");

                if identity.contains("cpu") {
                    speeds.cpu_rpm = Some(rpm);
                } else if identity.contains("gpu") {
                    speeds.gpu_rpm = Some(rpm);
                } else if fan_base == "fan1" {
                    fallback_cpu = Some(rpm);
                } else if fan_base == "fan2" {
                    fallback_gpu = Some(rpm);
                }
            }
        }

        if speeds.cpu_rpm.is_none() {
            speeds.cpu_rpm = fallback_cpu;
        }
        if speeds.gpu_rpm.is_none() {
            speeds.gpu_rpm = fallback_gpu;
        }

        Ok(speeds)
    }

    pub fn read_cpu_frequency(&self) -> Result<CpuFrequency, BackendError> {
        match self.cpu_freq_detection {
            CpuFreqDetection::ScalingCurFreq => self.read_scaling_cur_freq(),
            CpuFreqDetection::ProcCpuinfo => self.read_proc_cpuinfo_frequency(),
        }
    }

    fn detect_cpu_freq_method(root: &Path) -> CpuFreqDetection {
        let policy_root = root.join(CPUFREQ_POLICY_ROOT);
        if Self::has_cpufreq_policy_values(&policy_root, "scaling_cur_freq") {
            return CpuFreqDetection::ScalingCurFreq;
        }

        CpuFreqDetection::ProcCpuinfo
    }

    fn has_cpufreq_policy_values(policy_root: &Path, file_name: &str) -> bool {
        let Ok(entries) = fs::read_dir(policy_root) else {
            return false;
        };

        for entry in entries.flatten() {
            let policy_dir = entry.path();
            if policy_dir.is_dir() && policy_dir.join(file_name).exists() {
                return true;
            }
        }

        false
    }

    fn read_scaling_cur_freq(&self) -> Result<CpuFrequency, BackendError> {
        let policy_root = self.path(CPUFREQ_POLICY_ROOT);
        let khz_values = self.read_cpufreq_values(&policy_root, "scaling_cur_freq")?;

        Ok(CpuFrequency {
            average_ghz: Self::average_khz_as_ghz(&khz_values),
        })
    }

    fn read_cpufreq_values(
        &self,
        policy_root: &Path,
        file_name: &str,
    ) -> Result<Vec<u32>, BackendError> {
        if !policy_root.exists() {
            return Ok(Vec::new());
        }

        let mut values = Vec::new();
        for entry in fs::read_dir(policy_root)? {
            let policy_dir = entry?.path();
            if !policy_dir.is_dir() {
                continue;
            }

            let path = policy_dir.join(file_name);
            if path.exists() {
                values.push(Self::parse_u32(&path, &fs::read_to_string(&path)?)?);
            }
        }

        Ok(values)
    }

    fn read_proc_cpuinfo_frequency(&self) -> Result<CpuFrequency, BackendError> {
        let path = Path::new(PROC_CPUINFO_PATH);
        let value = fs::read_to_string(path)?;
        let mut mhz_values = Vec::new();

        for line in value.lines() {
            let Some((key, value)) = line.split_once(':') else {
                continue;
            };

            if key.trim() == "cpu MHz" {
                mhz_values.push(Self::parse_f32(path, value)?);
            }
        }

        Ok(CpuFrequency {
            average_ghz: Self::average_mhz_as_ghz(&mhz_values),
        })
    }

    fn average_khz_as_ghz(values: &[u32]) -> Option<f32> {
        if values.is_empty() {
            return None;
        }

        Some(
            values.iter().map(|value| *value as f32).sum::<f32>()
                / values.len() as f32
                / 1_000_000.0,
        )
    }

    fn average_mhz_as_ghz(values: &[f32]) -> Option<f32> {
        if values.is_empty() {
            return None;
        }

        Some(values.iter().sum::<f32>() / values.len() as f32 / 1000.0)
    }

    pub fn list_keyboard_zones(&self) -> Result<Vec<KeyboardZoneState>, BackendError> {
        [
            KeyboardZone::Left,
            KeyboardZone::Middle,
            KeyboardZone::Right,
            KeyboardZone::Bias,
        ]
        .into_iter()
        .map(|zone| self.read_keyboard_zone(zone))
        .collect()
    }

    pub fn read_keyboard_zone(
        &self,
        zone: KeyboardZone,
    ) -> Result<KeyboardZoneState, BackendError> {
        let sysfs_name = Self::zone_sysfs_name(zone).to_string();
        let brightness_path = self.zone_brightness_path(zone);
        let max_brightness_path = self.zone_max_brightness_path(zone);

        let brightness = Self::parse_u8(
            &brightness_path,
            &self.read_string(Self::zone_rel(zone, "brightness"))?,
        )?;
        let max_brightness = Self::parse_u8(
            &max_brightness_path,
            &self.read_string(Self::zone_rel(zone, "max_brightness"))?,
        )?;
        let color = Self::parse_rgb(&self.read_string(Self::zone_rel(zone, "multi_intensity"))?)?;

        Ok(KeyboardZoneState {
            name: zone,
            sysfs_name,
            brightness,
            max_brightness,
            color,
        })
    }

    pub fn write_keyboard_brightness(
        &self,
        zone: KeyboardZone,
        brightness: u8,
    ) -> Result<(), BackendError> {
        let max_brightness = Self::parse_u8(
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
        zone: KeyboardZone,
        color: RgbColor,
    ) -> Result<(), BackendError> {
        let brightness = Self::parse_u8(
            &self.zone_brightness_path(zone),
            &self.read_string(Self::zone_rel(zone, "brightness"))?,
        )?;

        self.write_string(
            Self::zone_rel(zone, "multi_intensity"),
            &format!("{} {} {}", color.red, color.green, color.blue),
        )?;

        self.write_string(Self::zone_rel(zone, "brightness"), &brightness.to_string())
    }

    fn keyboard_zones_for_target(&self, selection: KeyboardZoneSelection) -> Vec<KeyboardZone> {
        match selection {
            KeyboardZoneSelection::One(zone) => vec![zone],
            KeyboardZoneSelection::All => vec![
                KeyboardZone::Left,
                KeyboardZone::Middle,
                KeyboardZone::Right,
                KeyboardZone::Bias,
            ],
        }
    }

    pub fn read_keyboard_zones(
        &self,
        selection: KeyboardZoneSelection,
    ) -> Result<Vec<KeyboardZoneState>, BackendError> {
        match selection {
            KeyboardZoneSelection::One(zone) => Ok(vec![self.read_keyboard_zone(zone)?]),
            KeyboardZoneSelection::All => self.list_keyboard_zones(),
        }
    }

    pub fn set_keyboard_brightness(
        &self,
        selection: KeyboardZoneSelection,
        brightness: u8,
    ) -> Result<Vec<KeyboardZoneState>, BackendError> {
        for target in self.keyboard_zones_for_target(selection) {
            self.write_keyboard_brightness(target, brightness)?;
        }

        self.read_keyboard_zones(selection)
    }

    pub fn set_keyboard_color(
        &self,
        selection: KeyboardZoneSelection,
        color: RgbColor,
    ) -> Result<Vec<KeyboardZoneState>, BackendError> {
        for target in self.keyboard_zones_for_target(selection) {
            self.write_keyboard_color(target, color)?;
        }

        self.read_keyboard_zones(selection)
    }
}
