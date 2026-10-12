use std::error::Error;
use std::fs;
use std::thread;
use std::time::Duration;

use excalibur_control_center_backend::{GpuMode, SysfsBackend};

const GPU_MODE_SYSFS_PATH: &str = "/sys/module/casper_wmi/parameters/gpu_mode";
const MODE_SETTLE_DELAY: Duration = Duration::from_millis(500);

fn numeric_value(mode: GpuMode) -> &'static str {
    match mode {
        GpuMode::Hybrid => "1",
        GpuMode::Discrete => "2",
        GpuMode::Uma => "3",
    }
}

struct GpuModeRestore<'a> {
    backend: &'a SysfsBackend,
    initial_mode: GpuMode,
}

impl Drop for GpuModeRestore<'_> {
    fn drop(&mut self) {
        if let Err(error) = self.backend.write_gpu_mode(self.initial_mode) {
            eprintln!("Failed to restore GPU mode: {error}");
        }
        thread::sleep(MODE_SETTLE_DELAY);
    }
}

#[test]
fn display_mode_sysfs_accepts_active_mode_name_and_numeric_alias() -> Result<(), Box<dyn Error>> {
    let backend = SysfsBackend::default();
    let initial_mode = backend.read_gpu_mode()?;
    let _restore = GpuModeRestore {
        backend: &backend,
        initial_mode,
    };

    // This test only re-applies the firmware-reported mode. GPU mode changes
    // may require a reboot before the display routing changes, so avoid
    // switching modes here. Run it under each configured mode to cover the
    // corresponding name and numeric alias without changing the hardware mode.
    let numeric = numeric_value(initial_mode);
    println!("Verify active GPU mode {initial_mode} using its name and numeric alias.");

    backend.write_gpu_mode(initial_mode)?;
    thread::sleep(MODE_SETTLE_DELAY);
    assert_eq!(
        backend.read_gpu_mode()?,
        initial_mode,
        "active mode name was not retained"
    );

    println!("Write gpu_mode={numeric}; expect {initial_mode}.");
    fs::write(GPU_MODE_SYSFS_PATH, numeric)?;
    thread::sleep(MODE_SETTLE_DELAY);
    assert_eq!(
        backend.read_gpu_mode()?,
        initial_mode,
        "active mode numeric alias was not retained"
    );

    Ok(())
}
