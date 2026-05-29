use std::collections::BTreeMap;
use std::time::{Duration, Instant};

const SAMPLES: usize = 3;
const TARGET_NS: u64 = 50_000_000;

fn bench(name: &str, f: impl Fn()) {
    for _ in 0..3 { f(); }
    let mut iters: u64 = 10;
    loop {
        let start = Instant::now();
        for _ in 0..iters { f(); }
        let elapsed = start.elapsed().as_nanos() as u64;
        if elapsed >= TARGET_NS { break; }
        iters = ((iters as f64) * (TARGET_NS as f64) / (elapsed as f64)).max(10.0) as u64;
        if iters > 1000 { iters = 1000; break; }
    }
    let mut samples = [Duration::ZERO; SAMPLES];
    for s in 0..SAMPLES {
        let start = Instant::now();
        for _ in 0..iters { f(); }
        samples[s] = start.elapsed();
    }
    samples.sort();
    let ns = samples[SAMPLES/2].as_nanos() as f64 / iters as f64;
    let ops = 1_000_000_000.0 / ns;
    println!("  {:40} {:>6} iters {:>12.1} ns/op {:>12.0} ops/s", name, iters, ns, ops);
}

fn main() {
    println!("=== Rust BTreeMap<i32,i32> (N=10000 + N=100000) ===\n");

    bench("BTreeMap::insert/N=10000", || {
        let mut m = BTreeMap::new();
        for i in 0..10000i64 { m.insert(i, i); }
        std::hint::black_box(&m);
    });

    let m10k: BTreeMap<i64,i64> = (0..10000).map(|i| (i,i)).collect();
    bench("BTreeMap::get/N=10000", || {
        let mut s: i64 = 0;
        for i in 0..10000i64 { if let Some(v) = m10k.get(&i) { s += v; } }
        std::hint::black_box(s);
    });

    bench("BTreeMap::remove/N=10000", || {
        let mut m: BTreeMap<i64,i64> = (0..10000).map(|i| (i,i)).collect();
        for i in 0..10000i64 { m.remove(&i); }
        std::hint::black_box(&m);
    });

    bench("BTreeMap::insert/N=100000", || {
        let mut m = BTreeMap::new();
        for i in 0..100000i64 { m.insert(i, i); }
        std::hint::black_box(&m);
    });

    let m100k: BTreeMap<i64,i64> = (0..100000).map(|i| (i,i)).collect();
    bench("BTreeMap::get/N=100000", || {
        let mut s: i64 = 0;
        for i in 0..100000i64 { if let Some(v) = m100k.get(&i) { s += v; } }
        std::hint::black_box(s);
    });
}
