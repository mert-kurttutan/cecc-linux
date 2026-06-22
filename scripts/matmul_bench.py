# /// script
# dependencies = [
#   "numpy",
#   "rich",
# ]
# ///

import argparse
import time

import numpy as np
from rich.console import Console
from rich.table import Table


SIZES = [256, 1024, 2048, 4096, 8192]
DTYPE = np.float32
REPEATS = 3


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


def main() -> None:
    parser = argparse.ArgumentParser(description="Benchmark NumPy square matrix multiplication and report TFLOPS.")
    parser.add_argument(
        "--repeats",
        type=int,
        default=REPEATS,
        help="Number of timed repetitions per matrix size.",
    )
    args = parser.parse_args()

    if args.repeats < 1:
        raise SystemExit("--repeats must be at least 1")

    console = Console()
    table = Table(title="NumPy Matrix Multiplication Benchmark")
    table.add_column("N", justify="right")
    table.add_column("dtype")
    table.add_column("matrix GiB", justify="right")
    table.add_column("best s", justify="right")
    table.add_column("avg s", justify="right")
    table.add_column("best TFLOPS", justify="right")
    table.add_column("avg TFLOPS", justify="right")

    console.print(f"Benchmarking square GEMM with NumPy, dtype={DTYPE.__name__}, repeats={args.repeats}")

    for n in SIZES:
        result = benchmark_matmul(n, repeats=args.repeats)
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


if __name__ == "__main__":
    main()
