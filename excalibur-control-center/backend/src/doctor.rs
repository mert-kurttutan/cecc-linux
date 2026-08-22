use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

const CASPER_WMI_GUID: &str = "644C5791-B7B0-4123-A90B-E93876E0DAAD";
const DMI_ROOT: &str = "/sys/class/dmi/id";
const WMI_DEVICES_ROOT: &str = "/sys/bus/wmi/devices";
const CASPER_MODULE_ROOT: &str = "/sys/module/casper_wmi";
const CASPER_MODULE_PARAMETERS_ROOT: &str = "/sys/module/casper_wmi/parameters";
const LED_ROOT: &str = "/sys/class/leds";
const HWMON_ROOT: &str = "/sys/class/hwmon";
const PROC_CPUINFO_PATH: &str = "/proc/cpuinfo";

const EXPECTED_LED_NAMES: &[&str] = &[
    "casper:rgb:kbd_zoned_backlight-left",
    "casper:rgb:kbd_zoned_backlight-middle",
    "casper:rgb:kbd_zoned_backlight-right",
    "casper:rgb:biaslight",
];

#[derive(Debug, Clone)]
pub struct DoctorReport {
    pub app_version: String,
    pub kernel_release: ProbeValue,
    pub dmi: DmiReport,
    pub cpu: CpuReport,
    pub wmi: WmiReport,
    pub driver: DriverReport,
    pub sysfs: SysfsReport,
    pub dmesg: Option<CommandProbe>,
}

#[derive(Debug, Clone, Default)]
pub struct DmiReport {
    pub sys_vendor: ProbeValue,
    pub product_name: ProbeValue,
    pub product_version: ProbeValue,
    pub board_name: ProbeValue,
    pub bios_version: ProbeValue,
}

#[derive(Debug, Clone, Default)]
pub struct CpuReport {
    pub model_name: ProbeValue,
    pub vendor_id: ProbeValue,
    pub cpu_family: ProbeValue,
    pub model: ProbeValue,
    pub stepping: ProbeValue,
}

#[derive(Debug, Clone, Default)]
pub struct WmiReport {
    pub casper_guid_present: bool,
    pub device_names: Vec<String>,
}

#[derive(Debug, Clone, Default)]
pub struct DriverReport {
    pub module_loaded: bool,
    pub parameter_names: Vec<String>,
    pub gpu_mode: ProbeValue,
}

#[derive(Debug, Clone, Default)]
pub struct SysfsReport {
    pub expected_leds: Vec<PathProbe>,
    pub hwmon_devices: Vec<HwmonProbe>,
}

#[derive(Debug, Clone)]
pub struct PathProbe {
    pub path: String,
    pub exists: bool,
    pub readable: bool,
    pub value: Option<String>,
    pub error: Option<String>,
}

#[derive(Debug, Clone)]
pub struct HwmonProbe {
    pub path: String,
    pub name: ProbeValue,
    pub fans: Vec<FanProbe>,
}

#[derive(Debug, Clone)]
pub struct FanProbe {
    pub input: String,
    pub label: ProbeValue,
    pub value: ProbeValue,
}

#[derive(Debug, Clone)]
pub struct CommandProbe {
    pub command: String,
    pub status: Option<i32>,
    pub stdout: String,
    pub stderr: String,
    pub error: Option<String>,
}

#[derive(Debug, Clone, Default)]
pub struct ProbeValue {
    pub value: Option<String>,
    pub error: Option<String>,
}

impl ProbeValue {
    fn from_path(path: impl AsRef<Path>) -> Self {
        match fs::read_to_string(path.as_ref()) {
            Ok(value) => Self {
                value: Some(value.trim().to_string()),
                error: None,
            },
            Err(error) => Self {
                value: None,
                error: Some(error.to_string()),
            },
        }
    }

    fn from_option(value: Option<String>) -> Self {
        Self { value, error: None }
    }
}

pub fn collect_doctor_report(app_version: impl Into<String>, include_dmesg: bool) -> DoctorReport {
    let dmi = collect_dmi_report();

    DoctorReport {
        app_version: app_version.into(),
        kernel_release: command_stdout("uname", &["-r"]),
        cpu: collect_cpu_report(),
        wmi: collect_wmi_report(),
        driver: collect_driver_report(),
        sysfs: collect_sysfs_report(),
        dmesg: include_dmesg.then(collect_dmesg),
        dmi,
    }
}

fn collect_dmi_report() -> DmiReport {
    DmiReport {
        sys_vendor: ProbeValue::from_path(Path::new(DMI_ROOT).join("sys_vendor")),
        product_name: ProbeValue::from_path(Path::new(DMI_ROOT).join("product_name")),
        product_version: ProbeValue::from_path(Path::new(DMI_ROOT).join("product_version")),
        board_name: ProbeValue::from_path(Path::new(DMI_ROOT).join("board_name")),
        bios_version: ProbeValue::from_path(Path::new(DMI_ROOT).join("bios_version")),
    }
}

fn collect_cpu_report() -> CpuReport {
    let cpuinfo = fs::read_to_string(PROC_CPUINFO_PATH).unwrap_or_default();

    CpuReport {
        model_name: ProbeValue::from_option(cpuinfo_field(&cpuinfo, "model name")),
        vendor_id: ProbeValue::from_option(cpuinfo_field(&cpuinfo, "vendor_id")),
        cpu_family: ProbeValue::from_option(cpuinfo_field(&cpuinfo, "cpu family")),
        model: ProbeValue::from_option(cpuinfo_field(&cpuinfo, "model")),
        stepping: ProbeValue::from_option(cpuinfo_field(&cpuinfo, "stepping")),
    }
}

fn collect_wmi_report() -> WmiReport {
    let device_names = read_dir_names(WMI_DEVICES_ROOT);
    let casper_guid_present = device_names.iter().any(|name| {
        name.eq_ignore_ascii_case(CASPER_WMI_GUID) || name.starts_with(CASPER_WMI_GUID)
    });

    WmiReport {
        casper_guid_present,
        device_names,
    }
}

fn collect_driver_report() -> DriverReport {
    DriverReport {
        module_loaded: Path::new(CASPER_MODULE_ROOT).exists(),
        parameter_names: read_dir_names(CASPER_MODULE_PARAMETERS_ROOT),
        gpu_mode: ProbeValue::from_path(Path::new(CASPER_MODULE_PARAMETERS_ROOT).join("gpu_mode")),
    }
}

fn collect_sysfs_report() -> SysfsReport {
    let expected_leds = EXPECTED_LED_NAMES
        .iter()
        .flat_map(|name| {
            [
                Path::new(LED_ROOT).join(name).join("brightness"),
                Path::new(LED_ROOT).join(name).join("max_brightness"),
                Path::new(LED_ROOT).join(name).join("multi_intensity"),
                Path::new(LED_ROOT).join(name).join("effect"),
            ]
        })
        .map(path_probe)
        .collect();

    SysfsReport {
        expected_leds,
        hwmon_devices: collect_hwmon_report(),
    }
}

fn collect_hwmon_report() -> Vec<HwmonProbe> {
    read_dir_paths(HWMON_ROOT)
        .into_iter()
        .filter(|path| path.is_dir())
        .map(|path| {
            let fans = read_dir_paths(&path)
                .into_iter()
                .filter_map(|fan_path| {
                    let file_name = fan_path.file_name()?.to_str()?;
                    if !file_name.starts_with("fan") || !file_name.ends_with("_input") {
                        return None;
                    }

                    let fan_base = file_name.trim_end_matches("_input");
                    Some(FanProbe {
                        input: fan_path.display().to_string(),
                        label: ProbeValue::from_path(path.join(format!("{fan_base}_label"))),
                        value: ProbeValue::from_path(&fan_path),
                    })
                })
                .collect();

            HwmonProbe {
                name: ProbeValue::from_path(path.join("name")),
                path: path.display().to_string(),
                fans,
            }
        })
        .collect()
}

fn collect_dmesg() -> CommandProbe {
    let probe = command_probe("dmesg", &[]);
    let filtered_stdout = probe
        .stdout
        .lines()
        .filter(|line| {
            let lower = line.to_ascii_lowercase();
            lower.contains("casper")
                || lower.contains("wmi")
                || lower.contains("excalibur")
                || lower.contains("module")
                || lower.contains("enodev")
        })
        .collect::<Vec<_>>()
        .join("\n");

    CommandProbe {
        stdout: filtered_stdout,
        ..probe
    }
}

fn path_probe(path: PathBuf) -> PathProbe {
    let exists = path.exists();
    match fs::read_to_string(&path) {
        Ok(value) => PathProbe {
            path: path.display().to_string(),
            exists,
            readable: true,
            value: Some(value.trim().to_string()),
            error: None,
        },
        Err(error) => PathProbe {
            path: path.display().to_string(),
            exists,
            readable: false,
            value: None,
            error: Some(error.to_string()),
        },
    }
}

fn cpuinfo_field(cpuinfo: &str, wanted_key: &str) -> Option<String> {
    cpuinfo.lines().find_map(|line| {
        let (key, value) = line.split_once(':')?;
        (key.trim() == wanted_key).then(|| value.trim().to_string())
    })
}

fn read_dir_names(path: impl AsRef<Path>) -> Vec<String> {
    read_dir_paths(path)
        .into_iter()
        .filter_map(|path| path.file_name()?.to_str().map(ToOwned::to_owned))
        .collect()
}

fn read_dir_paths(path: impl AsRef<Path>) -> Vec<PathBuf> {
    let Ok(entries) = fs::read_dir(path) else {
        return Vec::new();
    };

    let mut paths = entries
        .flatten()
        .map(|entry| entry.path())
        .collect::<Vec<_>>();
    paths.sort();
    paths
}

fn command_stdout(program: &str, args: &[&str]) -> ProbeValue {
    let probe = command_probe(program, args);
    if probe.error.is_none() && probe.status == Some(0) {
        ProbeValue {
            value: Some(probe.stdout.trim().to_string()),
            error: None,
        }
    } else {
        ProbeValue {
            value: None,
            error: Some(command_error_summary(&probe)),
        }
    }
}

fn command_probe(program: &str, args: &[&str]) -> CommandProbe {
    match Command::new(program).args(args).output() {
        Ok(output) => CommandProbe {
            command: std::iter::once(program)
                .chain(args.iter().copied())
                .collect::<Vec<_>>()
                .join(" "),
            status: output.status.code(),
            stdout: String::from_utf8_lossy(&output.stdout).trim().to_string(),
            stderr: String::from_utf8_lossy(&output.stderr).trim().to_string(),
            error: None,
        },
        Err(error) => CommandProbe {
            command: std::iter::once(program)
                .chain(args.iter().copied())
                .collect::<Vec<_>>()
                .join(" "),
            status: None,
            stdout: String::new(),
            stderr: String::new(),
            error: Some(error.to_string()),
        },
    }
}

fn command_error_summary(probe: &CommandProbe) -> String {
    if let Some(error) = &probe.error {
        return error.clone();
    }

    if !probe.stderr.is_empty() {
        return probe.stderr.clone();
    }

    format!("command exited with status {:?}", probe.status)
}
