use std::time::Instant;

const BENCH_ITERATIONS: usize = 1000;
const SMALL_SIZE: usize = 64;
const BATCH_COUNT: usize = 10000;
const REUSE_CYCLES: usize = 100;

struct BenchResult {
    name: String,
    total_ns: u128,
    ns_per_op: f64,
    ops_per_sec: f64,
}

fn print_result(r: &BenchResult) {
    println!(
        "  {:<45} {:>12.0} ns/op  {:>12.0} ops/s",
        r.name, r.ns_per_op, r.ops_per_sec
    );
}

// Bump arena (mimics our TVirtualArena)
struct BumpArena {
    buf: Vec<u8>,
    offset: usize,
}

impl BumpArena {
    fn new(capacity: usize) -> Self {
        let mut buf = Vec::with_capacity(capacity);
        unsafe { buf.set_len(capacity); }
        BumpArena { buf, offset: 0 }
    }

    fn alloc(&mut self, size: usize) -> Option<*mut u8> {
        if self.offset + size > self.buf.capacity() {
            return None;
        }
        let ptr = unsafe { self.buf.as_mut_ptr().add(self.offset) };
        self.offset += size;
        Some(ptr)
    }

    fn reset(&mut self) {
        self.offset = 0;
    }
}

fn bench_rust_vec_alloc() -> BenchResult {
    let name = "Rust Vec<u8> 64B x10000".to_string();
    let t0 = Instant::now();
    for _ in 0..BENCH_ITERATIONS {
        for _ in 0..BATCH_COUNT {
            let _v: Vec<u8> = Vec::with_capacity(SMALL_SIZE);
        }
    }
    let total_ns = t0.elapsed().as_nanos();
    let ops = (BENCH_ITERATIONS * BATCH_COUNT) as f64;
    BenchResult {
        name,
        total_ns,
        ns_per_op: total_ns as f64 / ops,
        ops_per_sec: 1e9 / (total_ns as f64 / ops),
    }
}

fn bench_rust_vec_batch() -> BenchResult {
    let name = "Rust Vec batch 64B x10000".to_string();
    let t0 = Instant::now();
    for _ in 0..BENCH_ITERATIONS {
        let mut ptrs: Vec<Vec<u8>> = Vec::with_capacity(BATCH_COUNT);
        for _ in 0..BATCH_COUNT {
            ptrs.push(Vec::with_capacity(SMALL_SIZE));
        }
        std::hint::black_box(&ptrs);
    }
    let total_ns = t0.elapsed().as_nanos();
    let ops = (BENCH_ITERATIONS * BATCH_COUNT) as f64;
    BenchResult {
        name,
        total_ns,
        ns_per_op: total_ns as f64 / ops,
        ops_per_sec: 1e9 / (total_ns as f64 / ops),
    }
}

fn bench_bumpalo_alloc() -> BenchResult {
    let name = "Rust BumpArena Alloc 64B x10000".to_string();
    let mut arena = BumpArena::new(BATCH_COUNT * SMALL_SIZE * 2);
    let t0 = Instant::now();
    for _ in 0..BENCH_ITERATIONS {
        arena.reset();
        for _ in 0..BATCH_COUNT {
            arena.alloc(SMALL_SIZE);
        }
    }
    let total_ns = t0.elapsed().as_nanos();
    let ops = (BENCH_ITERATIONS * BATCH_COUNT) as f64;
    BenchResult {
        name,
        total_ns,
        ns_per_op: total_ns as f64 / ops,
        ops_per_sec: 1e9 / (total_ns as f64 / ops),
    }
}

fn bench_bumpalo_reset_reuse() -> BenchResult {
    let name = "Rust BumpArena reset+reuse x1000".to_string();
    let mut arena = BumpArena::new(BATCH_COUNT * SMALL_SIZE * 2);
    let t0 = Instant::now();
    for _ in 0..REUSE_CYCLES {
        for _ in 0..BATCH_COUNT {
            arena.alloc(SMALL_SIZE);
        }
        arena.reset();
    }
    let total_ns = t0.elapsed().as_nanos();
    let ops = (REUSE_CYCLES * BATCH_COUNT) as f64;
    BenchResult {
        name,
        total_ns,
        ns_per_op: total_ns as f64 / ops,
        ops_per_sec: 1e9 / (total_ns as f64 / ops),
    }
}

fn bench_rust_unsafe_bump() -> BenchResult {
    let name = "Rust unsafe bump 64B x10000".to_string();
    let mut buf = vec![0u8; BATCH_COUNT * SMALL_SIZE * 2];
    let t0 = Instant::now();
    for _ in 0..BENCH_ITERATIONS {
        let mut offset = 0usize;
        for _ in 0..BATCH_COUNT {
            let _ptr = unsafe { buf.as_mut_ptr().add(offset) };
            offset += SMALL_SIZE;
        }
    }
    let total_ns = t0.elapsed().as_nanos();
    let ops = (BENCH_ITERATIONS * BATCH_COUNT) as f64;
    BenchResult {
        name,
        total_ns,
        ns_per_op: total_ns as f64 / ops,
        ops_per_sec: 1e9 / (total_ns as f64 / ops),
    }
}

fn main() {
    println!("=== Rust Arena Benchmark ===");
    println!(
        "  Iterations: {}, Batch: {}, Size: {}B",
        BENCH_ITERATIONS, BATCH_COUNT, SMALL_SIZE
    );
    println!();

    let results = vec![
        bench_rust_vec_alloc(),
        bench_rust_vec_batch(),
        bench_bumpalo_alloc(),
        bench_bumpalo_reset_reuse(),
        bench_rust_unsafe_bump(),
    ];

    println!("--- Results ---");
    for r in &results {
        print_result(r);
    }
    println!();
    println!("Done.");
}
