// Same-host microbench peers for nextpas test_async_bench.
// Not API-equivalent; order-of-magnitude reference only.
use std::collections::VecDeque;
use std::sync::Mutex;
use std::time::Instant;

fn bench_post_like() -> f64 {
    const N: i32 = 100_000;
    let mut q: VecDeque<fn()> = VecDeque::with_capacity(N as usize);
    let start = Instant::now();
    for _ in 0..N {
        q.push_back(|| {});
    }
    for _ in 0..N {
        if let Some(f) = q.pop_front() {
            f();
        }
    }
    let sec = start.elapsed().as_secs_f64();
    if sec <= 0.0 {
        0.0
    } else {
        (N as f64) / sec
    }
}

fn bench_timer_schedule_like() -> f64 {
    const N: i32 = 10_000;
    let start = Instant::now();
    let mut v = Vec::with_capacity(N as usize);
    for i in 0..N {
        v.push(std::time::Duration::from_millis(1000 + i as u64));
    }
    let sec = start.elapsed().as_secs_f64();
    std::mem::drop(v);
    if sec <= 0.0 {
        0.0
    } else {
        (N as f64) / sec
    }
}

fn bench_mutex() -> f64 {
    const N: i32 = 100_000;
    let m = Mutex::new(());
    let start = Instant::now();
    for _ in 0..N {
        let _g = m.lock().unwrap();
    }
    let sec = start.elapsed().as_secs_f64();
    if sec <= 0.0 {
        0.0
    } else {
        (N as f64) / sec
    }
}

fn bench_channel() -> f64 {
    const N: i32 = 100_000;
    let (tx, rx) = std::sync::mpsc::sync_channel::<u32>(1);
    let start = Instant::now();
    for i in 0..N {
        tx.send(i as u32).unwrap();
        let _ = rx.recv().unwrap();
    }
    let sec = start.elapsed().as_secs_f64();
    if sec <= 0.0 {
        0.0
    } else {
        (N as f64) / sec
    }
}

fn main() {
    println!(
        "metric=post_ops_per_s lang=rust value={:.1} note=vecdeque_post_drain",
        bench_post_like()
    );
    println!(
        "metric=timer_schedule_ops_per_s lang=rust value={:.1} note=duration_vec_alloc",
        bench_timer_schedule_like()
    );
    println!(
        "metric=mutex_ops_per_s lang=rust value={:.1} note=std_mutex",
        bench_mutex()
    );
    println!(
        "metric=channel_ops_per_s lang=rust value={:.1} note=mpsc_sync1",
        bench_channel()
    );
}
