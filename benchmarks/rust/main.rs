use std::collections::HashMap;
use std::time::Instant;

#[derive(Debug)]
struct BenchmarkResult {
    name: String,
    n: usize,
    total_ns: u64,
    mean_ns: f64,
    min_ns: u64,
    max_ns: u64,
    median_ns: f64,
    stddev_ns: f64,
    ops_per_sec: f64,
}

fn run_benchmark<F: FnMut()>(name: &str, n: usize, mut f: F) -> BenchmarkResult {
    let mut times = Vec::with_capacity(n);

    for _ in 0..n {
        let start = Instant::now();
        f();
        let elapsed = start.elapsed().as_nanos() as u64;
        times.push(elapsed);
    }

    times.sort_unstable();

    let total: u64 = times.iter().sum();
    let mean = total as f64 / n as f64;

    let variance = times
        .iter()
        .map(|&t| {
            let diff = t as f64 - mean;
            diff * diff
        })
        .sum::<f64>()
        / n as f64;
    let stddev = variance.sqrt();

    let median = if n % 2 == 0 {
        (times[n / 2 - 1] + times[n / 2]) as f64 / 2.0
    } else {
        times[n / 2] as f64
    };

    let ops_per_sec = if mean > 0.0 { 1e9 / mean } else { 0.0 };

    BenchmarkResult {
        name: name.to_string(),
        n,
        total_ns: total,
        mean_ns: mean,
        min_ns: times[0],
        max_ns: times[n - 1],
        median_ns: median,
        stddev_ns: stddev,
        ops_per_sec,
    }
}

fn benchmark_fibonacci(n: usize) -> BenchmarkResult {
    fn fib(x: u32) -> u32 {
        if x <= 1 {
            return x;
        }
        fib(x - 1) + fib(x - 2)
    }

    run_benchmark("Fibonacci(20)", n, || {
        let _ = fib(20);
    })
}

fn benchmark_sorting(n: usize) -> BenchmarkResult {
    run_benchmark("Sorting(1000)", n, || {
        let mut data: Vec<i32> = (0..1000).map(|_| rand::random::<i32>() % 10000).collect();
        data.sort_unstable();
    })
}

fn benchmark_string_concat(n: usize) -> BenchmarkResult {
    run_benchmark("StringConcat(100)", n, || {
        let mut s = String::new();
        for _ in 0..100 {
            s.push('a');
        }
    })
}

fn benchmark_map_operations(n: usize) -> BenchmarkResult {
    run_benchmark("MapOps(1000)", n, || {
        let mut m = HashMap::new();
        for i in 0..1000 {
            m.insert(format!("key{}", i), i);
        }
        for i in 0..1000 {
            let _ = m.get(&format!("key{}", i));
        }
    })
}

fn benchmark_memory_alloc(n: usize) -> BenchmarkResult {
    run_benchmark("MemoryAlloc(100)", n, || {
        let data: Vec<u8> = (0..100).map(|i| (i % 256) as u8).collect();
        drop(data);
    })
}

fn main() {
    let n = 1000;

    println!("=== Rust Benchmark Results ===");
    println!();

    let results = vec![
        benchmark_fibonacci(n),
        benchmark_sorting(n),
        benchmark_string_concat(n),
        benchmark_map_operations(n),
        benchmark_memory_alloc(n),
    ];

    for r in &results {
        println!(
            "{:<20}: N={}, Mean={:.0} ns, Min={} ns, Max={} ns, Median={:.0} ns, StdDev={:.0} ns, Ops/sec={:.0}",
            r.name, r.n, r.mean_ns, r.min_ns, r.max_ns, r.median_ns, r.stddev_ns, r.ops_per_sec
        );
    }

    println!();
    println!("=== End of Rust Benchmarks ===");
}
