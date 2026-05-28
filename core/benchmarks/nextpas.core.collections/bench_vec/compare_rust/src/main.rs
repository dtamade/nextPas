use std::time::{Duration, Instant};
use std::hint::black_box;

const N: usize = 100000;
const TARGET_NS: u64 = 50_000_000;
const SAMPLES: usize = 3;
const MAX_ITERS: u64 = 1000;

fn bench(name: &str, f: impl Fn()) {
    for _ in 0..5 { f(); }
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
    let ops_per_sec = 1e9 / ns_per_op;
    println!("  {:<40} {:>8} iters {:>10.1} ns/op {:>14.0} ops/s",
        name, iters, ns_per_op, ops_per_sec);
}

fn main() {
    println!("=== Rust Vec<i32> Benchmark (N={}) ===\n", N);

    bench("Vec::push/N=100000", || {
        let mut v = Vec::with_capacity(8);
        for i in 0..N as i32 { v.push(i); }
        black_box(&v);
    });

    bench("Vec::push+reserve/N=100000", || {
        let mut v = Vec::with_capacity(N);
        for i in 0..N as i32 { v.push(i); }
        black_box(&v);
    });

    bench("Vec::pop/N=100000", || {
        let mut v: Vec<i32> = (0..N as i32).collect();
        for _ in 0..N { black_box(v.pop()); }
    });

    let data: Vec<i32> = (0..N as i32).collect();

    bench("Vec[i] get/N=100000", || {
        let mut sum: i64 = 0;
        for i in 0..N { sum += data[i] as i64; }
        black_box(sum);
    });

    bench("Vec::insert(mid)/N=1000", || {
        let mut v = Vec::with_capacity(2000);
        for i in 0..1000i32 {
            let mid = v.len() / 2;
            v.insert(mid, i);
        }
        black_box(&v);
    });

    bench("Vec::remove(mid)/N=1000", || {
        let mut v: Vec<i32> = (0..1000).collect();
        for _ in 0..1000 {
            let mid = v.len() / 2;
            v.remove(mid);
        }
        black_box(&v);
    });

    bench("Vec iterate/N=100000", || {
        let sum: i64 = data.iter().map(|&x| x as i64).sum();
        black_box(sum);
    });
}
