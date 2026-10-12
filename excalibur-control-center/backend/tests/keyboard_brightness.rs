use std::error::Error;
use std::sync::Mutex;
use std::thread;
use std::time::Duration;

use excalibur_control_center_backend::{
    KeyboardLedEffect, KeyboardZone, KeyboardZoneSelection, KeyboardZoneState, SysfsBackend,
};

const KEYBOARD_ZONES: [KeyboardZone; 3] = [
    KeyboardZone::Left,
    KeyboardZone::Middle,
    KeyboardZone::Right,
];
const BRIGHTNESS_LEVELS: [u8; 3] = [0, 1, 2];
const SETTLE_DELAY: Duration = Duration::from_millis(300);
const BIASLIGHT_SETTLE_DELAY: Duration = Duration::from_millis(500);
const BIASLIGHT_ZONE: KeyboardZone = KeyboardZone::Bias;
static HARDWARE_LOCK: Mutex<()> = Mutex::new(());

struct BrightnessRestore<'a> {
    backend: &'a SysfsBackend,
    initial_brightness: u8,
}

struct LedStateRestore<'a> {
    backend: &'a SysfsBackend,
    initial_zones: Vec<KeyboardZoneState>,
}

struct KeyboardAndBiaslightBrightnessRestore<'a> {
    backend: &'a SysfsBackend,
    keyboard_brightness: u8,
    biaslight_brightness: u8,
}

impl Drop for KeyboardAndBiaslightBrightnessRestore<'_> {
    fn drop(&mut self) {
        // Restore biaslight first because its WMI target also changes the
        // keyboard brightness; restore the keyboard last.
        if let Err(error) = self
            .backend
            .write_keyboard_brightness(BIASLIGHT_ZONE, self.biaslight_brightness)
        {
            eprintln!("Failed to restore biaslight brightness: {error}");
        }

        thread::sleep(BIASLIGHT_SETTLE_DELAY);
        let transition_brightness = if self.keyboard_brightness == 0 { 1 } else { 0 };
        if let Err(error) = self
            .backend
            .write_keyboard_brightness(KeyboardZone::Left, transition_brightness)
        {
            eprintln!("Failed to reset keyboard brightness before restoration: {error}");
        }

        thread::sleep(BIASLIGHT_SETTLE_DELAY);
        if let Err(error) = self
            .backend
            .write_keyboard_brightness(KeyboardZone::Left, self.keyboard_brightness)
        {
            eprintln!("Failed to restore keyboard brightness: {error}");
        }
        thread::sleep(BIASLIGHT_SETTLE_DELAY);
    }
}

impl Drop for LedStateRestore<'_> {
    fn drop(&mut self) {
        for zone in &self.initial_zones {
            if let Err(error) = self.backend.write_keyboard_effect(zone.name, zone.effect) {
                eprintln!("Failed to restore {} effect: {error}", zone.name);
            }
        }

        for zone in &self.initial_zones {
            if let Err(error) = self
                .backend
                .write_keyboard_brightness(zone.name, zone.brightness)
            {
                eprintln!("Failed to restore {} brightness: {error}", zone.name);
            }
        }
    }
}

impl Drop for BrightnessRestore<'_> {
    fn drop(&mut self) {
        if let Err(error) = self
            .backend
            .write_keyboard_brightness(KeyboardZone::Left, self.initial_brightness)
        {
            eprintln!("Failed to restore keyboard brightness: {error}");
        }
    }
}

fn verify_shared_brightness(backend: &SysfsBackend, expected: u8) -> Result<(), Box<dyn Error>> {
    for zone in KEYBOARD_ZONES {
        let state = backend.read_keyboard_zone(zone)?;
        println!("{} brightness={}", state.name, state.brightness);

        if state.brightness != expected {
            return Err(std::io::Error::other(format!(
                "{} brightness was {}, expected {expected}",
                state.name, state.brightness
            ))
            .into());
        }
    }

    Ok(())
}

fn keyboard_brightness(backend: &SysfsBackend) -> Result<Vec<(KeyboardZone, u8)>, Box<dyn Error>> {
    KEYBOARD_ZONES
        .into_iter()
        .map(|zone| Ok((zone, backend.read_keyboard_zone(zone)?.brightness)))
        .collect()
}

#[test]
fn keyboard_brightness_is_shared_across_zones() -> Result<(), Box<dyn Error>> {
    let _lock = HARDWARE_LOCK
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    let backend = SysfsBackend::default();
    let initial_zones = backend.read_keyboard_zones(KeyboardZoneSelection::All)?;
    let initial_brightness = backend.read_keyboard_zone(KeyboardZone::Left)?.brightness;
    let _restore = BrightnessRestore {
        backend: &backend,
        initial_brightness,
    };

    println!("Initial keyboard state:");
    for zone in &initial_zones {
        println!("{} brightness={}", zone.name, zone.brightness);
    }

    for target_zone in KEYBOARD_ZONES {
        for brightness in BRIGHTNESS_LEVELS {
            println!("Write brightness={brightness} through {target_zone}");
            backend.write_keyboard_brightness(target_zone, brightness)?;
            thread::sleep(SETTLE_DELAY);
            verify_shared_brightness(&backend, brightness)?;
        }
    }

    Ok(())
}

#[test]
fn changing_one_keyboard_effect_preserves_brightness() -> Result<(), Box<dyn Error>> {
    let _lock = HARDWARE_LOCK
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    let backend = SysfsBackend::default();
    let initial_zones = backend.read_keyboard_zones(KeyboardZoneSelection::All)?;
    let _restore = LedStateRestore {
        backend: &backend,
        initial_zones,
    };

    let brightness_before = keyboard_brightness(&backend)?;
    let target_zone = KeyboardZone::Left;
    println!("Change {target_zone} effect to breathing and check keyboard brightness.");
    backend.write_keyboard_effect(target_zone, KeyboardLedEffect::Breathing)?;

    let brightness_after_write = keyboard_brightness(&backend)?;
    assert_eq!(
        brightness_after_write, brightness_before,
        "changing one LED effect changed keyboard brightness immediately"
    );

    thread::sleep(SETTLE_DELAY);
    let brightness_after_delay = keyboard_brightness(&backend)?;
    assert_eq!(
        brightness_after_delay, brightness_before,
        "changing one LED effect changed keyboard brightness after delay"
    );

    Ok(())
}

#[test]
fn biaslight_brightness_also_changes_keyboard_brightness() -> Result<(), Box<dyn Error>> {
    let _lock = HARDWARE_LOCK
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    let backend = SysfsBackend::default();
    let initial_keyboard_brightness = backend.read_keyboard_zone(KeyboardZone::Left)?.brightness;
    let initial_biaslight_brightness = backend.read_keyboard_zone(BIASLIGHT_ZONE)?.brightness;
    let _restore = KeyboardAndBiaslightBrightnessRestore {
        backend: &backend,
        keyboard_brightness: initial_keyboard_brightness,
        biaslight_brightness: initial_biaslight_brightness,
    };

    println!("Set keyboard brightness to 2; biaslight should stay unchanged.");
    // Force a real keyboard brightness transition; the LED core may skip a
    // write when the requested value matches its cached brightness.
    backend.write_keyboard_brightness(KeyboardZone::Left, 0)?;
    thread::sleep(BIASLIGHT_SETTLE_DELAY);
    backend.write_keyboard_brightness(KeyboardZone::Left, 2)?;
    thread::sleep(BIASLIGHT_SETTLE_DELAY);
    verify_shared_brightness(&backend, 2)?;
    assert_eq!(
        backend.read_keyboard_zone(BIASLIGHT_ZONE)?.brightness,
        initial_biaslight_brightness,
        "keyboard brightness write changed biaslight brightness"
    );

    println!("Biaslight brightness 2 should also set keyboard brightness to 2.");
    backend.write_keyboard_brightness(BIASLIGHT_ZONE, 2)?;
    thread::sleep(BIASLIGHT_SETTLE_DELAY);
    assert_eq!(
        backend.read_keyboard_zone(BIASLIGHT_ZONE)?.brightness,
        2,
        "biaslight did not accept brightness 2"
    );
    verify_shared_brightness(&backend, 2)?;

    println!("Biaslight target 0 should also set keyboard brightness to 0.");
    backend.write_keyboard_brightness(BIASLIGHT_ZONE, 0)?;
    thread::sleep(BIASLIGHT_SETTLE_DELAY);
    assert_eq!(
        backend.read_keyboard_zone(BIASLIGHT_ZONE)?.brightness,
        0,
        "biaslight did not accept brightness 0"
    );
    verify_shared_brightness(&backend, 0)?;

    println!("Set keyboard brightness to 2; biaslight should remain 0.");
    backend.write_keyboard_brightness(KeyboardZone::Left, 0)?;
    thread::sleep(BIASLIGHT_SETTLE_DELAY);
    backend.write_keyboard_brightness(KeyboardZone::Left, 2)?;
    thread::sleep(BIASLIGHT_SETTLE_DELAY);
    assert_eq!(
        backend.read_keyboard_zone(BIASLIGHT_ZONE)?.brightness,
        0,
        "keyboard brightness write changed biaslight brightness"
    );
    verify_shared_brightness(&backend, 2)?;

    Ok(())
}
