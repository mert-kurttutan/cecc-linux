use excalibur_control_center::{Backend, GpuMode, KeyboardZoneName, RgbColor, SysfsBackend};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let backend = SysfsBackend::default();
    let mut args = std::env::args().skip(1);

    match args.next().as_deref() {
        Some("status") | None => {
            let state = backend.read_state()?;
            println!("gpu_mode={}", state.gpu_mode.map(|m| m.to_string()).unwrap_or_else(|| "unknown".to_string()));
            for zone in state.keyboard_zones {
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
        }
        Some("gpu") => match args.next().as_deref() {
            Some("get") => {
                let mode = backend.read_gpu_mode()?;
                println!("{}", mode.map(|m| m.to_string()).unwrap_or_else(|| "unknown".to_string()));
            }
            Some("set") => {
                let mode = parse_gpu_mode(args.next().as_deref())?;
                backend.write_gpu_mode(mode)?;
                println!("{mode}");
            }
            _ => print_usage(),
        },
        Some("keyboard") => match args.next().as_deref() {
            Some("list") => {
                for zone in backend.list_keyboard_zones()? {
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
            }
            Some("get") => {
                let zone = parse_zone(args.next().as_deref())?;
                let zone = backend.read_keyboard_zone(zone)?;
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
            Some("set") => {
                let zone = parse_zone(args.next().as_deref())?;
                let brightness = parse_u32_arg(args.next().as_deref(), "brightness")?;
                backend.write_keyboard_brightness(zone, brightness)?;
                let zone = backend.read_keyboard_zone(zone)?;
                println!("zone={} brightness={}", zone.name, zone.brightness);
            }
            Some("set-color") => {
                let zone = parse_zone(args.next().as_deref())?;
                let red = parse_u8_arg(args.next().as_deref(), "red")?;
                let green = parse_u8_arg(args.next().as_deref(), "green")?;
                let blue = parse_u8_arg(args.next().as_deref(), "blue")?;
                backend.write_keyboard_color(zone, RgbColor::new(red, green, blue))?;
                let zone = backend.read_keyboard_zone(zone)?;
                println!(
                    "zone={} color={},{},{}",
                    zone.name, zone.color.red, zone.color.green, zone.color.blue
                );
            }
            _ => print_usage(),
        },
        Some("help") => print_usage(),
        Some(other) => {
            eprintln!("Unknown command: {other}");
            print_usage();
        }
    }

    Ok(())
}

fn parse_gpu_mode(value: Option<&str>) -> Result<GpuMode, Box<dyn std::error::Error>> {
    match value {
        Some("hybrid") => Ok(GpuMode::Hybrid),
        Some("discrete") => Ok(GpuMode::Discrete),
        Some("uma") => Ok(GpuMode::Uma),
        Some(other) => Err(format!("Unknown gpu mode: {other}").into()),
        None => Err("Missing gpu mode".into()),
    }
}

fn parse_zone(value: Option<&str>) -> Result<KeyboardZoneName, Box<dyn std::error::Error>> {
    match value {
        Some("left") => Ok(KeyboardZoneName::Left),
        Some("middle") => Ok(KeyboardZoneName::Middle),
        Some("right") => Ok(KeyboardZoneName::Right),
        Some("bias") => Ok(KeyboardZoneName::Bias),
        Some(other) => Err(format!("Unknown zone: {other}").into()),
        None => Err("Missing zone".into()),
    }
}

fn parse_u32_arg(value: Option<&str>, name: &str) -> Result<u32, Box<dyn std::error::Error>> {
    let raw = value.ok_or_else(|| format!("Missing {name}"))?;
    Ok(raw.parse::<u32>()?)
}

fn parse_u8_arg(value: Option<&str>, name: &str) -> Result<u8, Box<dyn std::error::Error>> {
    let raw = value.ok_or_else(|| format!("Missing {name}"))?;
    Ok(raw.parse::<u8>()?)
}

fn print_usage() {
    println!("excalibur-control-center");
    println!("  status");
    println!("  gpu get");
    println!("  gpu set <hybrid|discrete|uma>");
    println!("  keyboard list");
    println!("  keyboard get <left|middle|right|bias>");
    println!("  keyboard set <left|middle|right|bias> <brightness>");
    println!("  keyboard set-color <left|middle|right|bias> <r> <g> <b>");
}
