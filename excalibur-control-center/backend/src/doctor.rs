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

pub fn format_doctor_report(report: &DoctorReport) -> String {
    let mut output = String::new();

    push_line(&mut output, "# Excalibur Control Center doctor report");
    push_line(&mut output, "");
    push_line(&mut output, "## App");
    push_line(&mut output, &format!("- version: {}", report.app_version));
    push_line(
        &mut output,
        &format!("- kernel: {}", probe_value(&report.kernel_release)),
    );
    push_line(&mut output, "");

    push_line(&mut output, "## DMI");
    push_line(
        &mut output,
        &format!("- sys_vendor: {}", probe_value(&report.dmi.sys_vendor)),
    );
    push_line(
        &mut output,
        &format!("- product_name: {}", probe_value(&report.dmi.product_name)),
    );
    push_line(
        &mut output,
        &format!(
            "- product_version: {}",
            probe_value(&report.dmi.product_version)
        ),
    );
    push_line(
        &mut output,
        &format!("- board_name: {}", probe_value(&report.dmi.board_name)),
    );
    push_line(
        &mut output,
        &format!("- bios_version: {}", probe_value(&report.dmi.bios_version)),
    );
    push_line(&mut output, "");

    push_line(&mut output, "## CPU");
    push_line(
        &mut output,
        &format!("- vendor_id: {}", probe_value(&report.cpu.vendor_id)),
    );
    push_line(
        &mut output,
        &format!("- model_name: {}", probe_value(&report.cpu.model_name)),
    );
    push_line(
        &mut output,
        &format!("- cpu_family: {}", probe_value(&report.cpu.cpu_family)),
    );
    push_line(
        &mut output,
        &format!("- model: {}", probe_value(&report.cpu.model)),
    );
    push_line(
        &mut output,
        &format!("- stepping: {}", probe_value(&report.cpu.stepping)),
    );
    push_line(&mut output, "");

    push_line(&mut output, "## WMI");
    push_line(
        &mut output,
        &format!(
            "- casper_guid_present: {}",
            yes_no(report.wmi.casper_guid_present)
        ),
    );
    push_line(&mut output, "- devices:");
    push_string_list(&mut output, &report.wmi.device_names);
    push_line(&mut output, "");

    push_line(&mut output, "## Driver");
    push_line(
        &mut output,
        &format!(
            "- casper_wmi_loaded: {}",
            yes_no(report.driver.module_loaded)
        ),
    );
    push_line(
        &mut output,
        &format!("- gpu_mode: {}", probe_value(&report.driver.gpu_mode)),
    );
    push_line(&mut output, "- parameters:");
    push_string_list(&mut output, &report.driver.parameter_names);
    push_line(&mut output, "");

    push_line(&mut output, "## LED sysfs");
    push_path_probes(&mut output, &report.sysfs.expected_leds);
    push_line(&mut output, "");

    push_line(&mut output, "## hwmon");
    if report.sysfs.hwmon_devices.is_empty() {
        push_line(&mut output, "- none found or not readable");
    } else {
        for hwmon in &report.sysfs.hwmon_devices {
            push_line(
                &mut output,
                &format!("- {} name={}", hwmon.path, probe_value(&hwmon.name)),
            );
            for fan in &hwmon.fans {
                push_line(
                    &mut output,
                    &format!(
                        "  - {} label={} value={}",
                        fan.input,
                        probe_value(&fan.label),
                        probe_value(&fan.value)
                    ),
                );
            }
        }
    }

    if let Some(dmesg) = &report.dmesg {
        push_line(&mut output, "");
        push_line(&mut output, "## dmesg");
        push_line(&mut output, &format!("- command: {}", dmesg.command));
        push_line(
            &mut output,
            &format!(
                "- status: {}",
                dmesg
                    .status
                    .map_or("unknown".to_string(), |status| status.to_string())
            ),
        );
        if let Some(error) = &dmesg.error {
            push_line(&mut output, &format!("- error: {error}"));
        }
        if !dmesg.stderr.is_empty() {
            push_line(&mut output, &format!("- stderr: {}", dmesg.stderr));
        }
        if dmesg.stdout.is_empty() {
            push_line(&mut output, "- filtered_output: none");
        } else {
            push_line(&mut output, "```text");
            push_line(&mut output, &dmesg.stdout);
            push_line(&mut output, "```");
        }
    }

    output
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

fn push_line(output: &mut String, line: &str) {
    output.push_str(line);
    output.push('\n');
}

fn push_path_probes(output: &mut String, probes: &[PathProbe]) {
    for probe in probes {
        push_line(
            output,
            &format!(
                "- {} exists={} readable={} value={}",
                probe.path,
                yes_no(probe.exists),
                yes_no(probe.readable),
                probe.value.as_deref().unwrap_or("--")
            ),
        );
        if let Some(error) = &probe.error {
            push_line(output, &format!("  error={error}"));
        }
    }
}

fn push_string_list(output: &mut String, values: &[String]) {
    if values.is_empty() {
        push_line(output, "  - none found or not readable");
        return;
    }

    for value in values {
        push_line(output, &format!("  - {value}"));
    }
}

fn probe_value(value: &ProbeValue) -> &str {
    value
        .value
        .as_deref()
        .or(value.error.as_deref())
        .unwrap_or("--")
}

fn yes_no(value: bool) -> &'static str {
    if value { "yes" } else { "no" }
}
