use std::collections::BinaryHeap;
use std::cmp::Reverse;
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

static mut RANDOM_DATA: [i32; N] = [0; N];

fn init_data() {
    let mut state: u64 = 42;
    unsafe {
        for x in RANDOM_DATA.iter_mut() {
            state = state.wrapping_mul(6364136223846793005).wrapping_add(1);
            *x = (state >> 33) as i32 % 1_000_000;
        }
    }
}

fn main() {
    init_data();
    println!("=== Rust BinaryHeap<i32> Benchmark (N={}) ===\n", N);

    bench("BinaryHeap::push/N=100000", || {
        let mut h = BinaryHeap::new();
        unsafe { for &x in RANDOM_DATA.iter() { h.push(Reverse(x)); } }
        black_box(&h);
    });

    bench("BinaryHeap::pop/N=100000", || {
        let mut h = BinaryHeap::new();
        unsafe { for &x in RANDOM_DATA.iter() { h.push(Reverse(x)); } }
        let mut sum: i64 = 0;
        while let Some(Reverse(v)) = h.pop() { sum += v as i64; }
        black_box(sum);
    });

    bench("BinaryHeap push+pop interleaved/N=100000", || {
        let mut h = BinaryHeap::new();
        let mut sink: i64 = 0;
        unsafe {
            for &x in RANDOM_DATA.iter() {
                h.push(Reverse(x));
                if h.len() > 100 { if let Some(Reverse(v)) = h.pop() { sink += v as i64; } }
            }
        }
        black_box(sink);
    });
}
