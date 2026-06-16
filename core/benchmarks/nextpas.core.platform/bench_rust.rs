use std::fs;
use std::io::{Read, Write};
use std::sync::Mutex;
use std::sync::RwLock;
use std::time::Instant;

const WARMUP_ITERS: usize = 1000;
const BENCH_ITERS: usize = 100000;
const IO_ITERS: usize = 10000;
const BUF_SIZE: usize = 4096;

fn bench_timer_resolution() {
    let mut min_delta = std::time::Duration::from_secs(999);
    for _ in 0..BENCH_ITERS {
        let start = Instant::now();
        let end = Instant::now();
        let diff = end.duration_since(start);
        if diff < min_delta && !diff.is_zero() {
            min_delta = diff;
        }
    }
    println!("=== Timer Resolution ===");
    println!("  Instant::now() min delta: {:?}", min_delta);
    println!();
}

fn bench_mutex() {
    let mu = Mutex::new(0u64);

    for _ in 0..WARMUP_ITERS {
        let _g = mu.lock().unwrap();
    }

    let start = Instant::now();
    for _ in 0..BENCH_ITERS {
        let _g = mu.lock().unwrap();
    }
    let elapsed = start.elapsed();

    println!("=== Mutex Lock/Unlock ===");
    let ns_per_op = elapsed.as_nanos() as f64 / BENCH_ITERS as f64;
    let ops_per_sec = BENCH_ITERS as f64 / elapsed.as_secs_f64();
    println!("  {:<35} {:10.1} ns/op  {:12.0} ops/s",
        "std::sync::Mutex lock+unlock", ns_per_op, ops_per_sec);
    println!();
}

fn bench_rwlock_read() {
    let rw = RwLock::new(0u64);

    for _ in 0..WARMUP_ITERS {
        let _g = rw.read().unwrap();
    }

    let start = Instant::now();
    for _ in 0..BENCH_ITERS {
        let _g = rw.read().unwrap();
    }
    let elapsed = start.elapsed();

    println!("=== RwLock Read ===");
    let ns_per_op = elapsed.as_nanos() as f64 / BENCH_ITERS as f64;
    let ops_per_sec = BENCH_ITERS as f64 / elapsed.as_secs_f64();
    println!("  {:<35} {:10.1} ns/op  {:12.0} ops/s",
        "std::sync::RwLock read+drop", ns_per_op, ops_per_sec);
    println!();
}

fn bench_file_io() {
    let buf = vec![0xAAu8; BUF_SIZE];
    let path = format!("/tmp/nextpas_bench_rust_{}.tmp", std::process::id());

    // Write benchmark
    let mut f = match fs::File::create(&path) {
        Ok(f) => f,
        Err(e) => {
            println!("  SKIP: cannot create temp file: {}", e);
            return;
        }
    };

    let start = Instant::now();
    for _ in 0..IO_ITERS {
        f.write_all(&buf).unwrap();
    }
    let write_elapsed = start.elapsed();
    drop(f);

    println!("=== File I/O ===");
    let ns_per_op = write_elapsed.as_nanos() as f64 / IO_ITERS as f64;
    let ops_per_sec = IO_ITERS as f64 / write_elapsed.as_secs_f64();
    println!("  {:<35} {:10.1} ns/op  {:12.0} ops/s",
        "file_write 4KB", ns_per_op, ops_per_sec);

    // Read benchmark
    let mut f = match fs::File::open(&path) {
        Ok(f) => f,
        Err(_) => return,
    };
    let mut read_buf = vec![0u8; BUF_SIZE];

    let start = Instant::now();
    for _ in 0..IO_ITERS {
        f.read(&mut read_buf).unwrap();
    }
    let read_elapsed = start.elapsed();
    drop(f);

    let ns_per_op = read_elapsed.as_nanos() as f64 / IO_ITERS as f64;
    let ops_per_sec = IO_ITERS as f64 / read_elapsed.as_secs_f64();
    println!("  {:<35} {:10.1} ns/op  {:12.0} ops/s",
        "file_read 4KB", ns_per_op, ops_per_sec);
    println!();

    let _ = fs::remove_file(&path);
}

fn main() {
    println!("Rust std benchmarks");
    println!("===================");
    println!();

    bench_timer_resolution();
    bench_mutex();
    bench_rwlock_read();
    bench_file_io();

    println!("Done.");
}
