use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Instant;

const N: usize = 1_000_000;

struct TestObj {
    value: i32,
}

/// 简单线程安全对象池 (对标 Go sync.Pool 的 Rust 等价物)
struct SyncPool<T, F> {
    pool: Arc<Mutex<Vec<T>>>,
    factory: F,
}

impl<T, F: Fn() -> T> SyncPool<T, F> {
    fn new(factory: F) -> Self {
        Self {
            pool: Arc::new(Mutex::new(Vec::new())),
            factory,
        }
    }

    fn get(&self) -> T {
        let mut guard = self.pool.lock().unwrap();
        guard.pop().unwrap_or_else(|| {
            drop(guard);
            (self.factory)()
        })
    }

    fn put(&self, item: T) {
        let mut guard = self.pool.lock().unwrap();
        guard.push(item);
    }
}

impl<T, F> Clone for SyncPool<T, F>
where
    F: Fn() -> T + Clone,
{
    fn clone(&self) -> Self {
        Self {
            pool: Arc::clone(&self.pool),
            factory: self.factory.clone(),
        }
    }
}

fn main() {
    println!("=== Rust SyncPool Benchmark ===");
    println!("Rust (rustc)");
    println!();

    // --- 1. 直接 alloc ---
    let start = Instant::now();
    for i in 0..N {
        let obj = Box::new(TestObj { value: i as i32 });
        drop(obj);
    }
    let direct_ms = start.elapsed().as_secs_f64() * 1000.0;
    println!(
        "Direct alloc x{}: {:.1} ms ({:.0} ops/ms)",
        N,
        direct_ms,
        N as f64 / direct_ms
    );

    // --- 2. Pool get/put (single thread) ---
    let pool = SyncPool::new(|| TestObj { value: 0 });
    // warmup
    for i in 0..1000 {
        let mut obj = pool.get();
        obj.value = i;
        pool.put(obj);
    }

    let start = Instant::now();
    for i in 0..N {
        let mut obj = pool.get();
        obj.value = i as i32;
        pool.put(obj);
    }
    let pool_ms = start.elapsed().as_secs_f64() * 1000.0;
    println!(
        "Pool get/put x{}: {:.1} ms ({:.0} ops/ms)",
        N,
        pool_ms,
        N as f64 / pool_ms
    );
    println!("Pool vs direct: {:.1}x", direct_ms / pool_ms);
    println!();

    // --- 3. Concurrent pool ---
    for threads in [1, 2, 4, 8, 16, 32] {
        let per_thread = N / threads;
        let pool = SyncPool::new(|| TestObj { value: 0 });
        // warmup
        for i in 0..1000 {
            let mut obj = pool.get();
            obj.value = i;
            pool.put(obj);
        }

        let start = Instant::now();
        let handles: Vec<_> = (0..threads)
            .map(|_| {
                let pool = pool.clone();
                thread::spawn(move || {
                    for i in 0..per_thread {
                        let mut obj = pool.get();
                        obj.value = i as i32;
                        pool.put(obj);
                    }
                })
            })
            .collect();
        for h in handles {
            h.join().unwrap();
        }
        let total_ms = start.elapsed().as_secs_f64() * 1000.0;
        let total_ops = per_thread * threads;
        println!(
            "Pool {:2}T x {:7} ops: {:7.1} ms ({:10.0} ops/sec)",
            threads,
            total_ops,
            total_ms,
            total_ops as f64 / total_ms * 1000.0
        );
    }
}
