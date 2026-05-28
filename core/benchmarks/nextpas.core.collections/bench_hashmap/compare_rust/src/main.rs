use std::collections::HashMap;
use std::hint::black_box;
use std::time::{Duration, Instant};

const N: usize = 100000;
const TARGET_NS: u64 = 50_000_000;
const SAMPLES: usize = 3;
const MAX_ITERS: u64 = 1000;

fn bench(name: &str, f: impl Fn()) {
    for _ in 0..3 { f(); }
    let mut iters: u64 = 10;
    loop {
        let start = Instant::now();
        for _ in 0..iters { f(); }
        let elapsed = start.elapsed().as_nanos() as u64;
        if elapsed >= TARGET_NS { break; }
        if elapsed < 1_000_000 { iters *= 10; }
        else { iters = (iters as f64 * TARGET_NS as f64 / elapsed as f64) as u64; }
        if iters < 10 { iters = 10; }
        if iters > MAX_ITERS { iters = MAX_ITERS; break; }
    }
    let mut samples = [Duration::ZERO; SAMPLES];
    for s in 0..SAMPLES {
        let start = Instant::now();
        for _ in 0..iters { f(); }
        samples[s] = start.elapsed();
    }
    samples.sort();
    let median = samples[SAMPLES / 2];
    let ns_per_op = median.as_nanos() as f64 / iters as f64;
    println!("  {:<40} {:>8} iters {:>10.1} ns/op {:>14.0} ops/s", name, iters, ns_per_op, 1e9 / ns_per_op);
}

fn main() {
    println!("=== Rust HashMap<i32,i32> Benchmark (N={}) ===\n", N);

    bench("HashMap::insert/N=100000", || {
        let mut m = HashMap::new();
        for i in 0..N as i32 { m.insert(i, i); }
        black_box(&m);
    });

    bench("HashMap::insert+reserve/N=100000", || {
        let mut m = HashMap::with_capacity(N);
        for i in 0..N as i32 { m.insert(i, i); }
        black_box(&m);
    });

    let gmap: HashMap<i32, i32> = (0..N as i32).map(|i| (i, i)).collect();

    bench("HashMap::get(hit)/N=100000", || {
        let mut sum: i64 = 0;
        for i in 0..N as i32 { if let Some(&v) = gmap.get(&i) { sum += v as i64; } }
        black_box(sum);
    });

    bench("HashMap::get(miss)/N=100000", || {
        let mut sum: i64 = 0;
        for i in N as i32..2*N as i32 { if let Some(&v) = gmap.get(&i) { sum += v as i64; } }
        black_box(sum);
    });

    bench("HashMap::remove/N=100000", || {
        let mut m: HashMap<i32, i32> = (0..N as i32).map(|i| (i, i)).collect();
        for i in 0..N as i32 { m.remove(&i); }
        black_box(&m);
    });
}
