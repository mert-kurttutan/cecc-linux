# /// script
# dependencies = [
#   "numpy",
#   "rich",
# ]
# ///

import argparse
import subprocess
import time
from pathlib import Path

import numpy as np
from rich.console import Console
from rich.table import Table


SIZES = [256, 1024, 2048, 4096, 8192]
DTYPE = np.float32
REPEATS = 3
PLATFORM_PROFILE_PATH = Path("/sys/firmware/acpi/platform_profile")
PLATFORM_PROFILE_CHOICES_PATH = Path("/sys/firmware/acpi/platform_profile_choices")
SYSTEM_MODES = [
    ("office", 2, "low-power"),
    ("gaming", 1, "balanced"),
    ("high-performance", 0, "performance"),
]


def benchmark_matmul(n: int, repeats: int = REPEATS) -> dict:
    a = np.random.rand(n, n).astype(DTYPE, copy=False)
    b = np.random.rand(n, n).astype(DTYPE, copy=False)

    # Warm up BLAS dispatch and allocations.
    _ = a @ b

    times = []
    for _ in range(repeats):
        start = time.perf_counter()
        c = a @ b
        end = time.perf_counter()
        times.append(end - start)
        # Prevent overly aggressive optimization assumptions.
        _ = float(c[0, 0])

    best = min(times)
    avg = sum(times) / len(times)
    flops = 2.0 * n * n * n

    return {
        "size": n,
        "dtype": str(DTYPE.__name__),
        "best_s": best,
        "avg_s": avg,
        "best_tflops": flops / best / 1e12,
        "avg_tflops": flops / avg / 1e12,
        "matrix_gib_each": (a.nbytes / (1024**3)),
    }


def read_platform_profile() -> str:
    return PLATFORM_PROFILE_PATH.read_text().strip()


def read_platform_profile_choices() -> list[str]:
    return PLATFORM_PROFILE_CHOICES_PATH.read_text().split()


def write_platform_profile(profile: str) -> None:
    choices = read_platform_profile_choices()
    if profile not in choices:
        raise RuntimeError(
            f"Unsupported platform profile {profile!r}; available choices: {', '.join(choices)}"
        )

    subprocess.run(
        ["sudo", "tee", str(PLATFORM_PROFILE_PATH)],
        input=f"{profile}\n",
        text=True,
        stdout=subprocess.DEVNULL,
        check=True,
    )


def read_power_supplies() -> list[dict[str, str | None]]:
    supplies = []
    for path in sorted(Path("/sys/class/power_supply").glob("*")):
        supply = {"name": path.name}
        for attribute in ("type", "online", "status", "capacity"):
            attribute_path = path / attribute
            supply[attribute] = (
                attribute_path.read_text().strip() if attribute_path.exists() else None
            )
        supplies.append(supply)
    return supplies


def print_context(console: Console, label: str) -> None:
    console.print(f"== {label} ==")
    console.print(f"platform_profile: {read_platform_profile()}")
    console.print(
        "platform_profile_choices: " + " ".join(read_platform_profile_choices())
    )

    supplies = read_power_supplies()
    if supplies:
        table = Table(title="Power supplies")
        columns = ("name", "type", "online", "status", "capacity")
        for column in columns:
            table.add_column(column)
        for supply in supplies:
            table.add_row(*(str(supply[column] or "") for column in columns))
        console.print(table)
    else:
        console.print("Power supplies: none")


def run_benchmark(console: Console, repeats: int) -> None:
    table = Table(title="NumPy Matrix Multiplication Benchmark")
    table.add_column("N", justify="right")
    table.add_column("dtype")
    table.add_column("matrix GiB", justify="right")
    table.add_column("best s", justify="right")
    table.add_column("avg s", justify="right")
    table.add_column("best TFLOPS", justify="right")
    table.add_column("avg TFLOPS", justify="right")

    console.print(
        f"Benchmarking square GEMM with NumPy, dtype={DTYPE.__name__}, repeats={repeats}"
    )

    for n in SIZES:
        result = benchmark_matmul(n, repeats=repeats)
        table.add_row(
            str(result["size"]),
            result["dtype"],
            f'{result["matrix_gib_each"]:.3f}',
            f'{result["best_s"]:.6f}',
            f'{result["avg_s"]:.6f}',
            f'{result["best_tflops"]:.3f}',
            f'{result["avg_tflops"]:.3f}',
        )

    console.print(table)
    console.print("TFLOPS formula: 2 * N^3 / seconds / 1e12")


def main() -> None:
    parser = argparse.ArgumentParser(description="Benchmark NumPy square matrix multiplication and report TFLOPS.")
    parser.add_argument(
        "--repeats",
        type=int,
        default=REPEATS,
        help="Number of timed repetitions per matrix size.",
    )
    parser.add_argument(
        "--settle-ms",
        type=int,
        default=2000,
        help="Delay after changing the platform profile before benchmarking.",
    )
    args = parser.parse_args()

    if args.repeats < 1:
        raise SystemExit("--repeats must be at least 1")
    if args.settle_ms < 0:
        raise SystemExit("--settle-ms must not be negative")

    console = Console()
    if not PLATFORM_PROFILE_PATH.exists():
        raise SystemExit(f"Platform profile is unavailable: {PLATFORM_PROFILE_PATH}")
    if not PLATFORM_PROFILE_CHOICES_PATH.exists():
        raise SystemExit(
            f"Platform profile choices are unavailable: {PLATFORM_PROFILE_CHOICES_PATH}"
        )

    initial_profile = read_platform_profile()
    print_context(console, "initial")

    try:
        for mode, windows_id, profile in SYSTEM_MODES:
            console.print()
            console.print(
                f"## mode={mode} windows_id={windows_id} platform_profile={profile}"
            )
            write_platform_profile(profile)
            time.sleep(args.settle_ms / 1000)
            actual_profile = read_platform_profile()
            if actual_profile != profile:
                raise RuntimeError(
                    f"platform_profile readback mismatch: expected {profile}, got {actual_profile}"
                )

            print_context(console, f"before benchmark: {mode}")
            run_benchmark(console, args.repeats)
            print_context(console, f"after benchmark: {mode}")
    finally:
        console.print()
        console.print(f"Restoring initial platform_profile: {initial_profile}")
        write_platform_profile(initial_profile)
        print_context(console, "restored")


if __name__ == "__main__":
    main()
