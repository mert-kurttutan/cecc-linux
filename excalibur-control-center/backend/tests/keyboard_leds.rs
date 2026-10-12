use std::error::Error;
use std::sync::Mutex;
use std::thread;
use std::time::Duration;

use excalibur_control_center_backend::{
    KeyboardLedEffect, KeyboardZone, KeyboardZoneSelection, KeyboardZoneState, RgbColor,
    SysfsBackend,
};

const KEYBOARD_ZONES: [KeyboardZone; 3] = [
    KeyboardZone::Left,
    KeyboardZone::Middle,
    KeyboardZone::Right,
];
const BRIGHTNESS_LEVELS: [u8; 3] = [0, 1, 2];
const SETTLE_DELAY: Duration = Duration::from_millis(300);
const BIASLIGHT_SETTLE_DELAY: Duration = Duration::from_millis(500);
const COLOR_OBSERVATION_DELAY: Duration = Duration::from_secs(2);
const BIASLIGHT_ZONE: KeyboardZone = KeyboardZone::Bias;
const MODE_OBSERVATION_DELAY: Duration = Duration::from_secs(5);
const MODE_TEST_COLOR: RgbColor = RgbColor {
    red: 255,
    green: 0,
    blue: 0,
};
const KEYBOARD_ZONE_TEST_COLORS: [RgbColor; 3] = [
    RgbColor::new(255, 0, 0),
    RgbColor::new(0, 255, 0),
    RgbColor::new(0, 0, 255),
];
const KEYBOARD_LED_EFFECTS: [KeyboardLedEffect; 7] = [
    KeyboardLedEffect::Static,
    KeyboardLedEffect::Blink,
    KeyboardLedEffect::Breathing,
    KeyboardLedEffect::Heartbeat,
    KeyboardLedEffect::Repeat,
    KeyboardLedEffect::Cycle,
    KeyboardLedEffect::Ambilight,
];
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
            if let Err(error) = self.backend.write_keyboard_color(zone.name, zone.color) {
                eprintln!("Failed to restore {} color: {error}", zone.name);
            }
        }

        let biaslight_brightness = self
            .initial_zones
            .iter()
            .find(|zone| zone.name == BIASLIGHT_ZONE)
            .map(|zone| zone.brightness);
        if let Some(brightness) = biaslight_brightness {
            if let Err(error) = self
                .backend
                .write_keyboard_brightness(BIASLIGHT_ZONE, brightness)
            {
                eprintln!("Failed to restore biaslight brightness: {error}");
            }
        }

        thread::sleep(BIASLIGHT_SETTLE_DELAY);
        if let Some(keyboard_brightness) = self
            .initial_zones
            .iter()
            .find(|zone| zone.name == KeyboardZone::Left)
            .map(|zone| zone.brightness)
        {
            let transition_brightness = if keyboard_brightness == 0 { 1 } else { 0 };
            if let Err(error) = self
                .backend
                .write_keyboard_brightness(KeyboardZone::Left, transition_brightness)
            {
                eprintln!("Failed to reset keyboard brightness before restoration: {error}");
            }

            thread::sleep(BIASLIGHT_SETTLE_DELAY);
            if let Err(error) = self
                .backend
                .write_keyboard_brightness(KeyboardZone::Left, keyboard_brightness)
            {
                eprintln!("Failed to restore keyboard brightness: {error}");
            }
            thread::sleep(BIASLIGHT_SETTLE_DELAY);
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
fn keyboard_zone_colors_are_independent() -> Result<(), Box<dyn Error>> {
    let _lock = HARDWARE_LOCK
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    let backend = SysfsBackend::default();
    let initial_zones = backend.read_keyboard_zones(KeyboardZoneSelection::All)?;
    let mut expected_colors = initial_zones
        .iter()
        .map(|zone| (zone.name, zone.color))
        .collect::<Vec<_>>();
    let _restore = LedStateRestore {
        backend: &backend,
        initial_zones,
    };

    for (target_zone, target_color) in KEYBOARD_ZONES.into_iter().zip(KEYBOARD_ZONE_TEST_COLORS) {
        println!("Set keyboard brightness to 2 for color observation.");
        backend.write_keyboard_brightness(target_zone, 2)?;
        thread::sleep(SETTLE_DELAY);

        println!("Set {target_zone} to color {target_color:?}.");
        backend.write_keyboard_color(target_zone, target_color)?;
        thread::sleep(SETTLE_DELAY);

        for zone in KEYBOARD_ZONES {
            let state = backend.read_keyboard_zone(zone)?;
            let expected = if zone == target_zone {
                target_color
            } else {
                expected_colors
                    .iter()
                    .find(|(expected_zone, _)| *expected_zone == zone)
                    .map(|(_, color)| *color)
                    .expect("keyboard zone has an expected color")
            };

            assert_eq!(
                state.color, expected,
                "writing {target_zone} color changed {zone} color"
            );
        }

        expected_colors
            .iter_mut()
            .find(|(zone, _)| *zone == target_zone)
            .expect("keyboard zone has an expected color")
            .1 = target_color;
        println!("Observe {target_zone} for two seconds.");
        thread::sleep(COLOR_OBSERVATION_DELAY);
    }

    Ok(())
}

#[test]
fn keyboard_led_modes_accept_supported_effects() -> Result<(), Box<dyn Error>> {
    let _lock = HARDWARE_LOCK
        .lock()
        .unwrap_or_else(std::sync::PoisonError::into_inner);
    let backend = SysfsBackend::default();
    let initial_zones = backend.read_keyboard_zones(KeyboardZoneSelection::All)?;
    let _restore = LedStateRestore {
        backend: &backend,
        initial_zones,
    };

    println!("Cycling LED effects on the left keyboard zone.");
    println!("Each mode stays active for five seconds for visual inspection.");

    for effect in KEYBOARD_LED_EFFECTS {
        println!("Set effect={effect} (mode {})", effect.mode_id());
        backend.write_keyboard_effect(KeyboardZone::Left, effect)?;
        backend.write_keyboard_color(KeyboardZone::Left, MODE_TEST_COLOR)?;
        backend.write_keyboard_brightness(KeyboardZone::Left, 2)?;
        thread::sleep(MODE_OBSERVATION_DELAY);

        let state = backend.read_keyboard_zone(KeyboardZone::Left)?;
        assert_eq!(
            state.effect, effect,
            "driver did not retain effect {effect}"
        );
        assert_eq!(
            state.color, MODE_TEST_COLOR,
            "driver did not retain test color"
        );
        assert_eq!(state.brightness, 2, "driver did not retain test brightness");
    }

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
