use std::hint::black_box;
use std::sync::atomic::{AtomicI32, AtomicU32, Ordering};
use std::time::Instant;

const ITERS: usize = 1_000_000;

fn print_result(name: &str, elapsed: std::time::Duration, operations: usize) {
    let elapsed_ns = elapsed.as_nanos().max(1) as f64;
    let ns_per_op = elapsed_ns / operations as f64;
    let mops = operations as f64 / (elapsed_ns / 1_000_000_000.0) / 1_000_000.0;
    println!(
        "  {:<34} {:>8.2} ms  {:>6.1} M ops/sec  {:>5.1} ns/op",
        name,
        elapsed_ns / 1_000_000.0,
        mops,
        ns_per_op
    );
}

fn bench_plain_baseline() -> i32 {
    let mut value = 0i32;
    let start = Instant::now();
    for i in 0..ITERS {
        value = black_box(value.wrapping_add(((i & 1) + 1) as i32));
    }
    print_result("Plain local increment 1M", start.elapsed(), ITERS);
    value
}

fn bench_atomic_load_store32() -> i32 {
    let value = AtomicI32::new(0);
    let mut sink = 0i32;
    let start = Instant::now();
    for i in 1..=ITERS {
        value.store(i as i32, Ordering::Relaxed);
        sink = value.load(Ordering::Relaxed);
    }
    print_result("AtomicLoad/Store32 2M", start.elapsed(), ITERS * 2);
    sink
}

fn bench_atomic_fetch_add32() -> i32 {
    let value = AtomicI32::new(0);
    let start = Instant::now();
    for _ in 0..ITERS {
        value.fetch_add(1, Ordering::Relaxed);
    }
    print_result("AtomicFetchAdd32 1M", start.elapsed(), ITERS);
    value.load(Ordering::Relaxed)
}

fn bench_atomic_compare_exchange32() -> i32 {
    let value = AtomicI32::new(0);
    let start = Instant::now();
    for i in 1..=ITERS {
        value
            .compare_exchange((i - 1) as i32, i as i32, Ordering::SeqCst, Ordering::SeqCst)
            .unwrap();
    }
    print_result("AtomicCompareExchange32 1M", start.elapsed(), ITERS);
    value.load(Ordering::SeqCst)
}

fn bench_typed_atomic_u32() -> u32 {
    let value = AtomicU32::new(0);
    let start = Instant::now();
    for _ in 0..ITERS {
        value.fetch_add(1, Ordering::Relaxed);
    }
    print_result("TAtomicUInt32 FetchAdd 1M", start.elapsed(), ITERS);
    value.load(Ordering::Relaxed)
}

fn main() {
    println!("=== Rust std atomic comparison (1M iterations) ===");
    println!(
        "Platform: {} {}",
        std::env::consts::OS,
        std::env::consts::ARCH
    );
    println!("Compiler flags: rustc -C opt-level=3 (recommended manual command)");
    println!("Input size: ITERS=1000000; scenarios=plain baseline, AtomicLoad/Store32, AtomicFetchAdd32, AtomicCompareExchange32, TAtomicUInt32");
    println!("Baselines: Rust std::sync::atomic single-thread operations; manual comparison source, not auto-run by Pascal benchmark");
    println!();

    let mut sink32 = bench_plain_baseline();
    black_box(sink32);
    sink32 = bench_atomic_load_store32();
    black_box(sink32);
    sink32 = bench_atomic_fetch_add32();
    black_box(sink32);
    sink32 = bench_atomic_compare_exchange32();
    let sink_u32 = bench_typed_atomic_u32();
    black_box((sink32, sink_u32));

    println!();
    println!("Sink: {}/{}", sink32, sink_u32);
    println!("Done.");
}
