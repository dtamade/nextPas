use std::collections::VecDeque;
use std::hint::black_box;
use std::sync::mpsc;
use std::sync::{Arc, Condvar, Mutex};
use std::thread;
use std::time::{Duration, Instant};

const N: usize = 1_000_000;
const CAPACITY: usize = 1024;

struct BoundedQueue {
    state: Mutex<VecDeque<u64>>,
    not_empty: Condvar,
    not_full: Condvar,
}

impl BoundedQueue {
    fn new() -> Self {
        Self {
            state: Mutex::new(VecDeque::with_capacity(CAPACITY)),
            not_empty: Condvar::new(),
            not_full: Condvar::new(),
        }
    }

    fn push(&self, value: u64) {
        let mut state = self.state.lock().unwrap();
        while state.len() >= CAPACITY {
            state = self.not_full.wait(state).unwrap();
        }
        state.push_back(value);
        self.not_empty.notify_one();
    }

    fn pop(&self) -> u64 {
        let mut state = self.state.lock().unwrap();
        loop {
            if let Some(value) = state.pop_front() {
                self.not_full.notify_one();
                return value;
            }
            state = self.not_empty.wait(state).unwrap();
        }
    }
}

fn print_result(name: &str, elapsed: Duration, operations: usize) {
    let elapsed_ns = elapsed.as_nanos().max(1) as f64;
    let ns_per_op = elapsed_ns / operations as f64;
    let mops = operations as f64 / (elapsed_ns / 1_000_000_000.0) / 1_000_000.0;
    println!(
        "  {:<34} {:>8.2} ms  {:>6.1} M ops/sec  {:>5.1} ns/op",
        name,
        elapsed_ns / 1_000_000.0,
        mops,
        ns_per_op
    );
}

fn bench_std_mpsc_spsc() -> u64 {
    let start = Instant::now();
    let (tx, rx) = mpsc::channel::<u64>();
    let producer = thread::spawn(move || {
        for value in 0..N as u64 {
            tx.send(value).unwrap();
        }
    });
    let consumer = thread::spawn(move || {
        let mut sum = 0u64;
        for _ in 0..N {
            sum = sum.wrapping_add(rx.recv().unwrap());
        }
        sum
    });
    producer.join().unwrap();
    let sum = consumer.join().unwrap();
    print_result("std::sync::mpsc 1P+1C", start.elapsed(), N);
    sum
}

fn bench_bounded_mutex_condvar_mpmc() -> u64 {
    let start = Instant::now();
    let queue = Arc::new(BoundedQueue::new());
    let mut producers = Vec::new();
    let mut consumers = Vec::new();

    for producer_index in 0..2 {
        let queue = queue.clone();
        producers.push(thread::spawn(move || {
            let start_value = producer_index * (N / 2);
            for offset in 0..(N / 2) {
                queue.push((start_value + offset) as u64);
            }
        }));
    }

    for _ in 0..2 {
        let queue = queue.clone();
        consumers.push(thread::spawn(move || {
            let mut sum = 0u64;
            for _ in 0..(N / 2) {
                sum = sum.wrapping_add(queue.pop());
            }
            sum
        }));
    }

    for producer in producers {
        producer.join().unwrap();
    }

    let sum = consumers
        .into_iter()
        .map(|consumer| consumer.join().unwrap())
        .fold(0u64, |acc, value| acc.wrapping_add(value));

    print_result("Mutex+Condvar VecDeque 2P+2C", start.elapsed(), N);
    sum
}

fn bench_mutex_vecdeque_single_thread() -> u64 {
    let queue = Mutex::new(VecDeque::<u64>::with_capacity(CAPACITY));
    let start = Instant::now();
    let mut sink = 0u64;

    for value in 0..N as u64 {
        {
            let mut queue = queue.lock().unwrap();
            queue.push_back(value);
            sink = sink.wrapping_add(queue.pop_front().unwrap());
        }
    }

    print_result("Mutex<VecDeque> 1T", start.elapsed(), N);
    sink
}

fn main() {
    println!("=== Rust std lockfree comparison (1M ops) ===");
    println!("Platform: {} {}", std::env::consts::OS, std::env::consts::ARCH);
    println!("Compiler flags: rustc -C opt-level=3 (recommended manual command)");
    println!("Input size: OPS=1000000; capacity=1024; scenarios=std::sync::mpsc 1P+1C, Mutex+Condvar VecDeque 2P+2C, Mutex<VecDeque> 1T");
    println!("Baselines: Rust std synchronization primitives only; manual comparison source, not auto-run by Pascal benchmark");
    println!();

    let sink = bench_std_mpsc_spsc()
        ^ bench_bounded_mutex_condvar_mpmc()
        ^ bench_mutex_vecdeque_single_thread();
    black_box(sink);

    println!();
    println!("Sink: {}", sink);
    println!("Done.");
}
