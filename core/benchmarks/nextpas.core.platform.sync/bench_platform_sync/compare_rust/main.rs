use std::sync::{Mutex, RwLock};
use std::time::Instant;

const N: usize = 1_000_000;

fn main() {
    println!("=== Rust Sync Primitives ({}M ops) ===\n", N / 1_000_000);

    // Mutex lock/unlock (uncontended)
    let m = Mutex::new(0u64);
    let start = Instant::now();
    for _ in 0..N {
        let mut g = m.lock().unwrap();
        *g += 1;
    }
    let ns = start.elapsed().as_nanos() as f64 / N as f64;
    println!("  Mutex lock/unlock:   {:>6.1} ns/op  {:>6.1} M ops/sec", ns, 1000.0 / ns);

    // RwLock read (uncontended)
    let rw = RwLock::new(0u64);
    let start = Instant::now();
    let mut sink: u64 = 0;
    for _ in 0..N {
        let g = rw.read().unwrap();
        sink += *g;
    }
    let ns = start.elapsed().as_nanos() as f64 / N as f64;
    println!("  RwLock read:         {:>6.1} ns/op  {:>6.1} M ops/sec", ns, 1000.0 / ns);

    // RwLock write (uncontended)
    let start = Instant::now();
    for _ in 0..N {
        let mut g = rw.write().unwrap();
        *g += 1;
    }
    let ns = start.elapsed().as_nanos() as f64 / N as f64;
    println!("  RwLock write:        {:>6.1} ns/op  {:>6.1} M ops/sec", ns, 1000.0 / ns);

    std::hint::black_box(sink);
}
