use std::collections::BTreeMap;
use std::time::Instant;

const N: usize = 10000;
const ITERS: usize = 100;

fn main() {
    println!("=== Rust BTreeMap (N={}) ===", N);

    // Put
    let start = Instant::now();
    for _ in 0..ITERS {
        let mut m = BTreeMap::new();
        for i in 0..N as i64 {
            m.insert(i, i);
        }
        std::hint::black_box(&m);
    }
    let elapsed = start.elapsed();
    println!("  Put:    {:>8.1} ns/op  ({} iters)", elapsed.as_nanos() as f64 / ITERS as f64, ITERS);

    // Get
    let mut m = BTreeMap::new();
    for i in 0..N as i64 {
        m.insert(i, i);
    }
    let start = Instant::now();
    let mut sink: i64 = 0;
    for _ in 0..ITERS {
        for i in 0..N as i64 {
            if let Some(v) = m.get(&i) {
                sink += v;
            }
        }
    }
    let elapsed = start.elapsed();
    println!("  Get:    {:>8.1} ns/op  ({} iters)", elapsed.as_nanos() as f64 / ITERS as f64, ITERS);
    std::hint::black_box(sink);

    // Remove
    let start = Instant::now();
    for _ in 0..ITERS {
        let mut m = BTreeMap::new();
        for i in 0..N as i64 {
            m.insert(i, i);
        }
        for i in 0..N as i64 {
            m.remove(&i);
        }
        std::hint::black_box(&m);
    }
    let elapsed = start.elapsed();
    println!("  Remove: {:>8.1} ns/op  ({} iters)", elapsed.as_nanos() as f64 / ITERS as f64, ITERS);
}
