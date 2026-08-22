use clap::{Args, Parser, Subcommand, ValueEnum};
use excalibur_control_center_backend::{
    ControlCenterState, DoctorReport, GpuMode, KeyboardZone, KeyboardZoneSelection,
    KeyboardZoneState, PathProbe, ProbeValue, RgbColor, SysfsBackend, collect_doctor_report,
};

#[derive(Debug, Parser)]
#[command(
    name = "excalibur-control-center",
    about = "Casper Excalibur hardware control utility",
    version
)]
struct Cli {
    #[command(subcommand)]
    command: Option<Command>,
}

#[derive(Debug, Subcommand)]
enum Command {
    /// Show all known hardware state.
    Status,
    /// Print a read-only support report for bug reports.
    Doctor(DoctorCommand),
    /// Inspect or change GPU mode.
    Gpu(GpuCommand),
    /// Inspect or change keyboard lighting.
    Keyboard(KeyboardCommand),
}

#[derive(Debug, Args)]
struct DoctorCommand {
    /// Include filtered dmesg output if the current user can read it.
    #[arg(long)]
    include_dmesg: bool,
}

#[derive(Debug, Args)]
struct GpuCommand {
    #[command(subcommand)]
    command: GpuSubcommand,
}

#[derive(Debug, Subcommand)]
enum GpuSubcommand {
    /// Read the current GPU mode.
    Get,
    /// Write a new GPU mode.
    Set {
        #[arg(value_enum)]
        mode: GpuModeArg,
    },
}

#[derive(Debug, Args)]
struct KeyboardCommand {
    #[command(subcommand)]
    command: KeyboardSubcommand,
}

#[derive(Debug, Subcommand)]
enum KeyboardSubcommand {
    /// List all keyboard lighting zones.
    List,
    /// Read one keyboard lighting zone, or all zones if omitted.
    Get {
        #[arg(value_enum)]
        zone: Option<ZoneArg>,
    },
    /// Set brightness for one zone or all zones.
    Set {
        #[arg(value_enum)]
        zone: ZoneArg,
        level: u8,
    },
    /// Set RGB color for one zone or all zones.
    SetColor {
        #[arg(value_enum)]
        zone: ZoneArg,
        red: u8,
        green: u8,
        blue: u8,
    },
    /// Color commands.
    Color(ColorCommand),
}

#[derive(Debug, Args)]
struct ColorCommand {
    #[command(subcommand)]
    command: ColorSubcommand,
}

#[derive(Debug, Subcommand)]
enum ColorSubcommand {
    /// Read RGB color for one zone or all zones.
    Get {
        #[arg(value_enum)]
        zone: Option<ZoneArg>,
    },
    /// Set RGB color for one zone or all zones.
    Set {
        #[arg(value_enum)]
        zone: ZoneArg,
        red: u8,
        green: u8,
        blue: u8,
    },
}

#[derive(Debug, Clone, Copy, ValueEnum)]
enum GpuModeArg {
    Hybrid,
    Discrete,
    Uma,
}

impl From<GpuModeArg> for GpuMode {
    fn from(value: GpuModeArg) -> Self {
        match value {
            GpuModeArg::Hybrid => Self::Hybrid,
            GpuModeArg::Discrete => Self::Discrete,
            GpuModeArg::Uma => Self::Uma,
        }
    }
}

#[derive(Debug, Clone, Copy, ValueEnum)]
enum ZoneArg {
    Left,
    Middle,
    Right,
    Bias,
    All,
}

impl ZoneArg {
    fn to_selection(self) -> KeyboardZoneSelection {
        match self {
            Self::Left => KeyboardZoneSelection::One(KeyboardZone::Left),
            Self::Middle => KeyboardZoneSelection::One(KeyboardZone::Middle),
            Self::Right => KeyboardZoneSelection::One(KeyboardZone::Right),
            Self::Bias => KeyboardZoneSelection::One(KeyboardZone::Bias),
            Self::All => KeyboardZoneSelection::All,
        }
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();
    let backend = SysfsBackend::default();

    match cli.command.unwrap_or(Command::Status) {
        Command::Status => print_state(backend.read_state()?),
        Command::Doctor(command) => {
            let report = collect_doctor_report(env!("CARGO_PKG_VERSION"), command.include_dmesg);
            print_doctor_report(&report);
        }
        Command::Gpu(command) => match command.command {
            GpuSubcommand::Get => {
                let mode = backend.read_gpu_mode()?;
                println!("{}", mode.to_string());
            }
            GpuSubcommand::Set { mode } => {
                let mode: GpuMode = mode.into();
                backend.write_gpu_mode(mode)?;
                println!("{mode}");
            }
        },
        Command::Keyboard(command) => match command.command {
            KeyboardSubcommand::List => {
                for zone in backend.list_keyboard_zones()? {
                    print_zone(&zone);
                }
            }
            KeyboardSubcommand::Get { zone } => {
                let selection = zone.map_or(KeyboardZoneSelection::All, ZoneArg::to_selection);
                for zone in backend.read_keyboard_zones(selection)? {
                    print_zone(&zone);
                }
            }
            KeyboardSubcommand::Set { zone, level } => {
                for zone in backend.set_keyboard_brightness(zone.to_selection(), level)? {
                    print_zone(&zone);
                }
            }
            KeyboardSubcommand::SetColor {
                zone,
                red,
                green,
                blue,
            } => {
                for zone in backend
                    .set_keyboard_color(zone.to_selection(), RgbColor::new(red, green, blue))?
                {
                    print_zone(&zone);
                }
            }
            KeyboardSubcommand::Color(command) => match command.command {
                ColorSubcommand::Get { zone } => {
                    let selection = zone.map_or(KeyboardZoneSelection::All, ZoneArg::to_selection);
                    for zone in backend.read_keyboard_zones(selection)? {
                        println!(
                            "zone={} color={},{},{} device={}",
                            zone.name,
                            zone.color.red,
                            zone.color.green,
                            zone.color.blue,
                            zone.sysfs_name
                        );
                    }
                }
                ColorSubcommand::Set {
                    zone,
                    red,
                    green,
                    blue,
                } => {
                    for zone in backend
                        .set_keyboard_color(zone.to_selection(), RgbColor::new(red, green, blue))?
                    {
                        print_zone(&zone);
                    }
                }
            },
        },
    }

    Ok(())
}

fn print_state(state: ControlCenterState) {
    println!("gpu_mode={}", state.gpu_mode.to_string());
    for zone in state.keyboard_zones {
        print_zone(&zone);
    }
}

fn print_zone(zone: &KeyboardZoneState) {
    println!(
        "zone={} brightness={} max_brightness={} color={},{},{} device={}",
        zone.name,
        zone.brightness,
        zone.max_brightness,
        zone.color.red,
        zone.color.green,
        zone.color.blue,
        zone.sysfs_name
    );
}

fn print_doctor_report(report: &DoctorReport) {
    println!("# Excalibur Control Center doctor report");
    println!();
    println!("## App");
    println!("- version: {}", report.app_version);
    println!("- kernel: {}", probe_value(&report.kernel_release));
    println!();

    println!("## DMI");
    println!("- sys_vendor: {}", probe_value(&report.dmi.sys_vendor));
    println!("- product_name: {}", probe_value(&report.dmi.product_name));
    println!(
        "- product_version: {}",
        probe_value(&report.dmi.product_version)
    );
    println!("- board_name: {}", probe_value(&report.dmi.board_name));
    println!("- bios_version: {}", probe_value(&report.dmi.bios_version));
    println!();

    println!("## CPU");
    println!("- vendor_id: {}", probe_value(&report.cpu.vendor_id));
    println!("- model_name: {}", probe_value(&report.cpu.model_name));
    println!("- cpu_family: {}", probe_value(&report.cpu.cpu_family));
    println!("- model: {}", probe_value(&report.cpu.model));
    println!("- stepping: {}", probe_value(&report.cpu.stepping));
    println!();

    println!("## WMI");
    println!(
        "- casper_guid_present: {}",
        yes_no(report.wmi.casper_guid_present)
    );
    println!("- devices:");
    print_string_list(&report.wmi.device_names);
    println!();

    println!("## Driver");
    println!(
        "- casper_wmi_loaded: {}",
        yes_no(report.driver.module_loaded)
    );
    println!("- gpu_mode: {}", probe_value(&report.driver.gpu_mode));
    println!("- parameters:");
    print_string_list(&report.driver.parameter_names);
    println!();

    println!("## LED sysfs");
    print_path_probes(&report.sysfs.expected_leds);
    println!();

    println!("## hwmon");
    if report.sysfs.hwmon_devices.is_empty() {
        println!("- none found or not readable");
    } else {
        for hwmon in &report.sysfs.hwmon_devices {
            println!("- {} name={}", hwmon.path, probe_value(&hwmon.name));
            for fan in &hwmon.fans {
                println!(
                    "  - {} label={} value={}",
                    fan.input,
                    probe_value(&fan.label),
                    probe_value(&fan.value)
                );
            }
        }
    }

    if let Some(dmesg) = &report.dmesg {
        println!();
        println!("## dmesg");
        println!("- command: {}", dmesg.command);
        println!(
            "- status: {}",
            dmesg
                .status
                .map_or("unknown".to_string(), |s| s.to_string())
        );
        if let Some(error) = &dmesg.error {
            println!("- error: {error}");
        }
        if !dmesg.stderr.is_empty() {
            println!("- stderr: {}", dmesg.stderr);
        }
        if dmesg.stdout.is_empty() {
            println!("- filtered_output: none");
        } else {
            println!("```text");
            println!("{}", dmesg.stdout);
            println!("```");
        }
    }
}

fn print_path_probes(probes: &[PathProbe]) {
    for probe in probes {
        println!(
            "- {} exists={} readable={} value={}",
            probe.path,
            yes_no(probe.exists),
            yes_no(probe.readable),
            probe.value.as_deref().unwrap_or("--")
        );
        if let Some(error) = &probe.error {
            println!("  error={error}");
        }
    }
}

fn print_string_list(values: &[String]) {
    if values.is_empty() {
        println!("  - none found or not readable");
        return;
    }

    for value in values {
        println!("  - {value}");
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
