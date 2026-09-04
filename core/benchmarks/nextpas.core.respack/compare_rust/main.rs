use include_dir::{include_dir, Dir};
use std::time::{Duration, Instant};

static ASSETS: Dir<'_> = include_dir!("$CARGO_MANIFEST_DIR/testdata");

const WARMUP_ITERS: usize = 50;
const DUR: Duration = Duration::from_millis(2000);

fn print_result(name: &str, iters: u64, elapsed: Duration) {
    let ns_per_op = elapsed.as_nanos() as f64 / iters as f64;
    println!("  {:30} {:8} iters  {:8.2} ms  {:10.1} ns/op", name, iters, elapsed.as_millis() as f64, ns_per_op);
}

fn bench_include_dir_get_file(dur: Duration) {
    // Accumulate a checksum over the full contents and print it: without
    // consuming the bytes the optimizer reduces the loop to a bare lookup
    // (~tens of ns) instead of a real payload read.
    let mut acc: u64 = 0;
    for _ in 0..WARMUP_ITERS {
        let f = ASSETS.get_file("file0000.bin").unwrap();
        for &b in f.contents() {
            acc = acc.wrapping_add(b as u64);
        }
    }
    let mut iters: u64 = 0;
    let start = Instant::now();
    while start.elapsed() < dur {
        let f = ASSETS.get_file("file0000.bin").unwrap();
        for &b in f.contents() {
            acc = acc.wrapping_add(b as u64);
        }
        iters += 1;
    }
    println!("  checksum: {:016x}", acc);
    print_result("rust-include_dir/4k", iters, start.elapsed());
}

fn main() {
    println!("=== Rust include_dir Benchmarks (same payload as nextpas bench_servevfs 4KiB) ===");
    println!();
    bench_include_dir_get_file(DUR);
    println!();
    println!("Note: numbers are same-host with nextpas bench_servevfs ~7µs; expect ~7.1µs ±30%");
}
