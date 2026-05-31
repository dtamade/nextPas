use sha2::{Sha256, Digest};
use std::time::{Duration, Instant};

fn bench_sha256(size: usize, duration: Duration) {
    let data: Vec<u8> = (0..size).map(|i| (i & 0xFF) as u8).collect();

    // warmup
    for _ in 0..50 {
        let mut hasher = Sha256::new();
        hasher.update(&data);
        let _ = hasher.finalize();
    }

    let mut bytes: u64 = 0;
    let mut iters: u64 = 0;
    let start = Instant::now();
    while start.elapsed() < duration {
        let mut hasher = Sha256::new();
        hasher.update(&data);
        let _ = hasher.finalize();
        bytes += size as u64;
        iters += 1;
    }
    let elapsed = start.elapsed();
    let mbps = bytes as f64 / 1_048_576.0 / elapsed.as_secs_f64();
    println!("  SHA-256 {:6} bytes: {:8.1} MB/s  ({} iters, {} ms)",
        size, mbps, iters, elapsed.as_millis());
}

fn main() {
    println!("=== SHA-256 Benchmark (Rust sha2 crate) ===");
    println!();

    bench_sha256(64, Duration::from_secs(2));
    bench_sha256(256, Duration::from_secs(2));
    bench_sha256(1024, Duration::from_secs(2));
    bench_sha256(4096, Duration::from_secs(2));
    bench_sha256(8192, Duration::from_secs(2));
    bench_sha256(16384, Duration::from_secs(2));
    bench_sha256(65536, Duration::from_secs(2));
    bench_sha256(1048576, Duration::from_secs(2));

    println!();
    println!("Done.");
}
