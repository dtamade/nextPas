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
    // Accumulate a checksum over the full contents and print it: without
    // consuming the bytes the optimizer reduces the loop to a bare lookup
    // (~tens of ns) instead of a real payload read.
    let mut acc: u64 = 0;
    for _ in 0..WARMUP_ITERS {
        let f = ASSETS.get_file("file0000.bin").unwrap();
        for &b in f.contents() {
            acc = acc.wrapping_add(b as u64);
        }
    }
    let mut iters: u64 = 0;
    let start = Instant::now();
    while start.elapsed() < dur {
        let f = ASSETS.get_file("file0000.bin").unwrap();
        for &b in f.contents() {
            acc = acc.wrapping_add(b as u64);
        }
        iters += 1;
    }
    println!("  checksum: {:016x}", acc);
    print_result("rust-include_dir/4k", iters, start.elapsed());
}

fn main() {
    println!("=== Rust include_dir Benchmarks (same payload as nextpas bench_servevfs 4KiB) ===");
    println!();
    bench_include_dir_get_file(DUR);
    println!();
    bench_startup_pack_file();
    println!();
    bench_bulk_write_512();
    println!();
    println!("Note: same-host with nextpas benches; payloads: 4KiB testdata file,");
    println!("1MiB runtime-generated pack file, 512MiB runtime-generated bulk write.");
}

// Same deterministic pattern the Pascal benches use ((j*31+seed*7) mod 251).
fn gen_pattern(buf: &mut [u8], seed: usize) {
    for (j, b) in buf.iter_mut().enumerate() {
        *b = ((j * 31 + seed * 7) % 251) as u8;
    }
}

// Startup peer for Pascal readfile-pack-carrier: 1MiB generated file is
// written once outside timing, then fs::read+checksum is timed.
fn bench_startup_pack_file() {
    const SIZE: usize = 1048576;
    let path = std::env::temp_dir().join("rust-bench-startup.pack");
    let mut blob = vec![0u8; SIZE];
    gen_pattern(&mut blob, 1);
    std::fs::write(&path, &blob).unwrap();
    drop(blob);
    let mut acc: u64 = 0;
    for _ in 0..WARMUP_ITERS {
        let data = std::fs::read(&path).unwrap();
        for &b in &data {
            acc = acc.wrapping_add(b as u64);
        }
    }
    let mut iters: u64 = 0;
    let start = Instant::now();
    while start.elapsed() < DUR {
        let data = std::fs::read(&path).unwrap();
        for &b in &data {
            acc = acc.wrapping_add(b as u64);
        }
        iters += 1;
    }
    let elapsed = start.elapsed();
    std::fs::remove_file(&path).ok();
    println!("  checksum: {:016x}", acc);
    print_result("rust-startup/readfile-1mb", iters, elapsed);
}

// Bulk-write peer for Pascal writer_memory/writer_dedup: 512MiB assembled
// chunk by chunk with checksum (Pascal additionally sorts/validates/aligns,
// documented in RESULTS). Input chunks are retained like Pascal's caller-held
// buffers, so peak RSS covers the whole end-to-end job on all sides.
fn bench_bulk_write_512() {
    const TOTAL: usize = 536870912;
    const CHUNK: usize = 8 * 1024 * 1024;
    let mut buf: Vec<u8> = Vec::with_capacity(TOTAL);
    let mut tmp = vec![0u8; CHUNK];
    let mut retained: Vec<Vec<u8>> = Vec::with_capacity(TOTAL / CHUNK);
    let mut acc: u64 = 0;
    let start = Instant::now();
    let mut off = 0;
    while off < TOTAL {
        gen_pattern(&mut tmp, off / CHUNK);
        buf.extend_from_slice(&tmp);
        retained.push(tmp.clone());
        for &b in &tmp {
            acc = acc.wrapping_add(b as u64);
        }
        off += CHUNK;
    }
    let elapsed = start.elapsed();
    println!("  checksum: {:016x}", acc);
    println!("  {:30} {:8} bytes  {:8.2} ms", "rust-bulk/write-512mb", buf.len(), elapsed.as_millis() as f64);
    println!("  peak rss: {} MB", peak_rss_mb());
}

// Peak RSS via /proc (Linux-only, same measurand as Pascal ProcessPeakRssBytes
// and Go RUSAGE_SELF ru_maxrss: max resident set, MiB).
fn peak_rss_mb() -> u64 {
    let status = std::fs::read_to_string("/proc/self/status").unwrap_or_default();
    for line in status.lines() {
        if let Some(v) = line.strip_prefix("VmHWM:") {
            let kb: u64 = v.split_whitespace().next().unwrap_or("0").parse().unwrap_or(0);
            return kb / 1024;
        }
    }
    0
}
