use std::time::{Duration, Instant};

const N: usize = 10000;
const TARGET_NS: u64 = 200_000_000;
const SAMPLES: usize = 5;

fn bench_sort(name: &str, gen_data: impl Fn() -> Vec<i32>) {
    // warmup
    for _ in 0..10 {
        let mut d = gen_data();
        d.sort_unstable();
    }

    // calibrate
    let mut iters: u64 = 100;
    loop {
        let start = Instant::now();
        for _ in 0..iters {
            let mut d = gen_data();
            d.sort_unstable();
        }
        let elapsed = start.elapsed().as_nanos() as u64;
        if elapsed >= TARGET_NS {
            break;
        }
        if elapsed < 1_000_000 {
            iters *= 100;
        } else {
            iters = (iters as f64 * TARGET_NS as f64 / elapsed as f64) as u64;
        }
        if iters < 100 {
            iters = 100;
        }
    }

    // measure
    let mut samples = [Duration::ZERO; SAMPLES];
    for s in 0..SAMPLES {
        let start = Instant::now();
        for _ in 0..iters {
            let mut d = gen_data();
            d.sort_unstable();
        }
        samples[s] = start.elapsed();
    }
    samples.sort();
    let median = samples[SAMPLES / 2];
    let ns_per_op = median.as_nanos() as f64 / iters as f64;
    let ops_per_sec = 1e9 / ns_per_op;

    println!(
        "  {:<40} {:>12} iters {:>10.1} ns/op {:>14.0} ops/s",
        name, iters, ns_per_op, ops_per_sec
    );
}

fn main() {
    use std::cell::RefCell;

    let mut rng_state: u64 = 42;
    let mut random_data = vec![0i32; N];
    for x in random_data.iter_mut() {
        rng_state = rng_state.wrapping_mul(6364136223846793005).wrapping_add(1);
        *x = (rng_state >> 33) as i32 % 1_000_000;
    }
    let random_data = random_data;

    println!("=== Rust sort_unstable Benchmark (N={}) ===\n", N);

    let rd = random_data.clone();
    bench_sort("sort_unstable/random", move || rd.clone());

    bench_sort("sort_unstable/sorted", || (0..N as i32).collect());

    bench_sort("sort_unstable/reversed", || {
        (0..N as i32).rev().collect()
    });

    bench_sort("sort_unstable/all-same", || vec![7i32; N]);
}
