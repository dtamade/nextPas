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
    for _ in 0..WARMUP_ITERS {
        let _ = ASSETS.get_file("file0000.bin");
    }
    let mut iters: u64 = 0;
    let start = Instant::now();
    while start.elapsed() < dur {
        let f = ASSETS.get_file("file0000.bin").unwrap();
        let _ = f.contents();
        iters += 1;
    }
    print_result("rust-include_dir/4k", iters, start.elapsed());
}

fn main() {
    println!("=== Rust include_dir Benchmarks (same payload as nextpas bench_servevfs 4KiB) ===");
    println!();
    bench_include_dir_get_file(DUR);
    println!();
    println!("Note: numbers are same-host with nextpas bench_servevfs ~7µs; expect ~7.1µs ±30%");
}
