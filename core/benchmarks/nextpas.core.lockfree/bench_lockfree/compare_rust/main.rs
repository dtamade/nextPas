use std::time::Instant;
use std::io::Write;
use std::fs::File;
use std::sync::mpsc;
use std::sync::{Arc, Condvar, Mutex};
use crossbeam::queue::{ArrayQueue, SegQueue};

const OPS: u64 = 1_000_000;
const CAP: usize = 1024;

fn main() {
    let mut out = File::create("/tmp/rust_bench_results.txt").unwrap();
    writeln!(out, "Rust crossbeam queue benchmarks (ops={OPS}, capacity={CAP})").unwrap();
    writeln!(out, "===========================================================").unwrap();

    // --- SPSC Try* single-threaded ---
    {
        let q = ArrayQueue::<u64>::new(CAP);
        let start = Instant::now();
        for i in 0..OPS {
            while q.push(i).is_err() {}
            let _ = q.pop().unwrap();
        }
        let elapsed = start.elapsed().as_secs_f64();
        let ops_sec = OPS as f64 / elapsed / 1_000_000.0;
        writeln!(out, "SPSC ArrayQueue Try* 1T: {ops_sec:.1} M ops/sec  ({:.0} ns/op)", elapsed * 1e9 / OPS as f64).unwrap();
    }

    // --- SPSC 1P+1C threaded ---
    {
        let q = std::sync::Arc::new(ArrayQueue::<u64>::new(CAP));
        let q_send = q.clone();
        let q_recv = q.clone();
        let start = Instant::now();
        let sender = std::thread::spawn(move || {
            for i in 0..OPS {
                while q_send.push(i).is_err() {}
            }
        });
        let receiver = std::thread::spawn(move || {
            let mut sum: u64 = 0;
            for _ in 0..OPS {
                loop {
                    if let Some(v) = q_recv.pop() {
                        sum = sum.wrapping_add(v);
                        break;
                    }
                }
            }
            sum
        });
        sender.join().unwrap();
        let _sum = receiver.join().unwrap();
        let elapsed = start.elapsed().as_secs_f64();
        let ops_sec = OPS as f64 / elapsed / 1_000_000.0;
        writeln!(out, "SPSC ArrayQueue 1P+1C:   {ops_sec:.1} M ops/sec  ({:.0} ns/op)", elapsed * 1e9 / OPS as f64).unwrap();
    }

    // --- MPMC 2P+2C threaded ---
    {
        let q = std::sync::Arc::new(ArrayQueue::<u64>::new(CAP));
        let q_send1 = q.clone();
        let q_send2 = q.clone();
        let q_recv1 = q.clone();
        let q_recv2 = q.clone();
        let start = Instant::now();
        let s1 = std::thread::spawn(move || {
            for i in 0..OPS/2 {
                while q_send1.push(i).is_err() {}
            }
        });
        let s2 = std::thread::spawn(move || {
            for i in 0..OPS/2 {
                while q_send2.push(i + OPS).is_err() {}
            }
        });
        let r1 = std::thread::spawn(move || {
            let mut sum: u64 = 0;
            for _ in 0..OPS/2 {
                loop {
                    if let Some(v) = q_recv1.pop() {
                        sum = sum.wrapping_add(v);
                        break;
                    }
                }
            }
            sum
        });
        let r2 = std::thread::spawn(move || {
            let mut sum: u64 = 0;
            for _ in 0..OPS/2 {
                loop {
                    if let Some(v) = q_recv2.pop() {
                        sum = sum.wrapping_add(v);
                        break;
                    }
                }
            }
            sum
        });
        s1.join().unwrap();
        s2.join().unwrap();
        r1.join().unwrap();
        r2.join().unwrap();
        let elapsed = start.elapsed().as_secs_f64();
        let ops_sec = OPS as f64 / elapsed / 1_000_000.0;
        writeln!(out, "MPMC ArrayQueue 2P+2C:   {ops_sec:.1} M ops/sec  ({:.0} ns/op)", elapsed * 1e9 / OPS as f64).unwrap();
    }

    // --- SegQueue (unbounded MPSC) ---
    {
        let q = std::sync::Arc::new(SegQueue::<u64>::new());
        let q_send = q.clone();
        let q_recv = q.clone();
        let start = Instant::now();
        let sender = std::thread::spawn(move || {
            for i in 0..OPS {
                q_send.push(i);
            }
        });
        let receiver = std::thread::spawn(move || {
            let mut sum: u64 = 0;
            for _ in 0..OPS {
                loop {
                    if let Some(v) = q_recv.pop() {
                        sum = sum.wrapping_add(v);
                        break;
                    }
                }
            }
            sum
        });
        sender.join().unwrap();
        let _sum = receiver.join().unwrap();
        let elapsed = start.elapsed().as_secs_f64();
        let ops_sec = OPS as f64 / elapsed / 1_000_000.0;
        writeln!(out, "SegQueue unbounded 1P+1C: {ops_sec:.1} M ops/sec  ({:.0} ns/op)", elapsed * 1e9 / OPS as f64).unwrap();
    }

    writeln!(out, "===========================================================").unwrap();
    writeln!(out, "Done.").unwrap();
}
