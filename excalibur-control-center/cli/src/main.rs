use clap::{Args, Parser, Subcommand, ValueEnum};
use excalibur_control_center_backend::{
    Backend, ControlCenterState, GpuMode, KeyboardZoneName, RgbColor, SysfsBackend,
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
    /// Inspect or change GPU mode.
    Gpu(GpuCommand),
    /// Inspect or change keyboard lighting.
    Keyboard(KeyboardCommand),
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
        level: u32,
    },
    /// Set RGB color for one zone or all zones.
    SetColor {
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
    fn to_option(self) -> Option<KeyboardZoneName> {
        match self {
            Self::Left => Some(KeyboardZoneName::Left),
            Self::Middle => Some(KeyboardZoneName::Middle),
            Self::Right => Some(KeyboardZoneName::Right),
            Self::Bias => Some(KeyboardZoneName::Bias),
            Self::All => None,
        }
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();
    let backend = SysfsBackend::default();

    match cli.command.unwrap_or(Command::Status) {
        Command::Status => print_state(backend.read_state()?),
        Command::Gpu(command) => match command.command {
            GpuSubcommand::Get => {
                let mode = backend.read_gpu_mode()?;
                println!("{}", mode.map(|m| m.to_string()).unwrap_or_else(|| "unknown".to_string()));
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
                if let Some(zone) = zone.and_then(ZoneArg::to_option) {
                    print_zone(&backend.read_keyboard_zone(zone)?);
                } else {
                    for zone in backend.list_keyboard_zones()? {
                        print_zone(&zone);
                    }
                }
            }
            KeyboardSubcommand::Set { zone, level } => {
                if let Some(zone) = zone.to_option() {
                    backend.write_keyboard_brightness(zone, level)?;
                    print_zone(&backend.read_keyboard_zone(zone)?);
                } else {
                    for zone in [
                        KeyboardZoneName::Left,
                        KeyboardZoneName::Middle,
                        KeyboardZoneName::Right,
                        KeyboardZoneName::Bias,
                    ] {
                        backend.write_keyboard_brightness(zone, level)?;
                    }
                    for zone in backend.list_keyboard_zones()? {
                        print_zone(&zone);
                    }
                }
            }
            KeyboardSubcommand::SetColor {
                zone,
                red,
                green,
                blue,
            } => {
                if let Some(zone) = zone.to_option() {
                    backend.write_keyboard_color(zone, RgbColor::new(red, green, blue))?;
                    print_zone(&backend.read_keyboard_zone(zone)?);
                } else {
                    for zone in [
                        KeyboardZoneName::Left,
                        KeyboardZoneName::Middle,
                        KeyboardZoneName::Right,
                        KeyboardZoneName::Bias,
                    ] {
                        backend.write_keyboard_color(zone, RgbColor::new(red, green, blue))?;
                    }
                    for zone in backend.list_keyboard_zones()? {
                        print_zone(&zone);
                    }
                }
            }
        },
    }

    Ok(())
}

fn print_state(state: ControlCenterState) {
    println!(
        "gpu_mode={}",
        state
            .gpu_mode
            .map(|m| m.to_string())
            .unwrap_or_else(|| "unknown".to_string())
    );
    for zone in state.keyboard_zones {
        print_zone(&zone);
    }
}

fn print_zone(zone: &excalibur_control_center_backend::KeyboardZone) {
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
