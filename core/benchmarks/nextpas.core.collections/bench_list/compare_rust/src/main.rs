use std::collections::LinkedList;
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
    println!("=== Rust LinkedList<i32> Benchmark (N={}) ===\n", N);

    bench("LinkedList::push_back/N=100000", || {
        let mut l = LinkedList::new();
        for i in 0..N as i32 { l.push_back(i); }
        black_box(&l);
    });

    bench("LinkedList::push_front/N=100000", || {
        let mut l = LinkedList::new();
        for i in 0..N as i32 { l.push_front(i); }
        black_box(&l);
    });

    bench("LinkedList::pop_front/N=100000", || {
        let mut l: LinkedList<i32> = (0..N as i32).collect();
        let mut sum: i64 = 0;
        while let Some(v) = l.pop_front() { sum += v as i64; }
        black_box(sum);
    });
}
