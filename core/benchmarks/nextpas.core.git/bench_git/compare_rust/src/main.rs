use adler::Adler32;
use std::time::Instant;

// bench_git Rust counterpart — Adler32 64K zero-copy via adler crate, same DATA_64K as bench_git.lpr.
// Same-machine A/B: Pascal PByte+Len (checksum.adler32) vs Go hash/adler32 vs Rust adler crate.
// Single-source: crate adler (no hand-rolled MOD 65521), zero-copy &[u8] slice.

const DATA_64K: usize = 64 * 1024;

fn init_data() -> Vec<u8> {
    let mut v = vec![0u8; DATA_64K];
    for i in 0..DATA_64K {
        v[i] = ((i * 31 + 7) % 251) as u8;
    }
    v
}

fn bench_adler_pbyte(data: &[u8], iters: usize) -> (u128, f64) {
    let start = Instant::now();
    let mut sink: u32 = 0;
    for _ in 0..iters {
        let mut h = Adler32::new();
        h.write_slice(data);
        sink ^= h.checksum();
    }
    let elapsed = start.elapsed();
    std::hint::black_box(sink);
    let ns_per = elapsed.as_nanos() / iters as u128;
    // MB/s
    let mbs = (DATA_64K as f64 * iters as f64 / 1_048_576.0) / elapsed.as_secs_f64();
    (ns_per, mbs)
}

fn main() {
    let data = init_data();
    let iters = 20000;
    let (ns1, mbs1) = bench_adler_pbyte(&data, iters);
    let ops = 1_000_000_000.0 / ns1 as f64;
    // criterion-like line for xlang parser + human MB/s
    println!("bench_git_rs Adler32/PByte64K {} {} ns/op {:.2} MB/s ({:.0} ops/sec)", iters, ns1, mbs1, ops);
    println!("Adler32/PByte64K time:   [{} ns {} ns {} ns]", ns1, ns1, ns1);
}
