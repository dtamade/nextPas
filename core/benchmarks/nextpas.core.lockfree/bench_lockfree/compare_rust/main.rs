use std::sync::mpsc;
use std::sync::Arc;
use std::thread;
use std::time::Instant;
use std::collections::VecDeque;
use std::sync::Mutex;

const N: usize = 1_000_000;

fn main() {
    println!("=== Rust Channel Benchmarks (1M ops) ===\n");

    // SPSC: std::sync::mpsc (unbounded)
    let start = Instant::now();
    let (tx, rx) = mpsc::channel::<u64>();
    let producer = thread::spawn(move || {
        for i in 0..N as u64 { tx.send(i).unwrap(); }
    });
    let consumer = thread::spawn(move || {
        let mut sum: u64 = 0;
        for _ in 0..N { sum += rx.recv().unwrap(); }
        sum
    });
    producer.join().unwrap();
    let _sum = consumer.join().unwrap();
    let elapsed = start.elapsed();
    let ns_per_op = elapsed.as_nanos() as f64 / N as f64;
    println!("  mpsc channel 1P+1C:  {:>8.1} ns/op  {:>6.1} M ops/sec",
             ns_per_op, 1000.0 / ns_per_op);

    // MPMC: Mutex<VecDeque> (naive, for comparison)
    let start = Instant::now();
    let queue = Arc::new(Mutex::new(VecDeque::<u64>::with_capacity(1024)));
    let q_prod = queue.clone();
    let q_cons = queue.clone();
    let p = thread::spawn(move || {
        for i in 0..N as u64 {
            q_prod.lock().unwrap().push_back(i);
        }
    });
    let c = thread::spawn(move || {
        let mut count = 0usize;
        while count < N {
            let val = q_cons.lock().unwrap().pop_front();
            if val.is_some() { count += 1; }
        }
    });
    p.join().unwrap();
    c.join().unwrap();
    let elapsed = start.elapsed();
    let ns_per_op = elapsed.as_nanos() as f64 / N as f64;
    println!("  Mutex<VecDeque> 1P+1C: {:>6.1} ns/op  {:>6.1} M ops/sec",
             ns_per_op, 1000.0 / ns_per_op);

    // Single-thread throughput: mpsc try_send/try_recv
    let (tx, rx) = mpsc::channel::<u64>();
    let start = Instant::now();
    for i in 0..N as u64 { tx.send(i).unwrap(); }
    let mut sink: u64 = 0;
    for _ in 0..N { sink += rx.try_recv().unwrap(); }
    let elapsed = start.elapsed();
    let ns_per_op = elapsed.as_nanos() as f64 / N as f64;
    println!("  mpsc single-thread:  {:>8.1} ns/op  {:>6.1} M ops/sec",
             ns_per_op, 1000.0 / ns_per_op);
    std::hint::black_box(sink);
}
