use clap::{Args, Parser, Subcommand, ValueEnum};
use excalibur_control_center_backend::{
    ControlCenterState, GpuMode, KeyboardZone, KeyboardZoneSelection, KeyboardZoneState, RgbColor,
    SysfsBackend,
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
