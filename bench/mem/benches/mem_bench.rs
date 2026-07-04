use criterion::{criterion_group, criterion_main, Criterion};
use crossbeam_queue::ArrayQueue;
use std::alloc::{alloc_zeroed, dealloc, Layout};
use std::sync::Arc;

const ALLOC_N: usize = 10000;
const SMALL_SIZE: usize = 64;
const LARGE_SIZE: usize = 1024;
const POOL_N: usize = 100000;

// --- Alloc/Free 64B (alloc_zeroed + dealloc) ---

fn bench_alloc_64(c: &mut Criterion) {
    c.bench_function("Alloc/64B", |b| {
        b.iter(|| {
            let layout = Layout::from_size_align(SMALL_SIZE, 8).unwrap();
            for _ in 0..ALLOC_N {
                unsafe {
                    let ptr = alloc_zeroed(layout);
                    std::ptr::write_volatile(ptr, 0u8);
                    dealloc(ptr, layout);
                }
            }
        })
    });
}

// --- Alloc/Free 1KB ---

fn bench_alloc_1k(c: &mut Criterion) {
    c.bench_function("Alloc/1KB", |b| {
        b.iter(|| {
            let layout = Layout::from_size_align(LARGE_SIZE, 8).unwrap();
            for _ in 0..ALLOC_N {
                unsafe {
                    let ptr = alloc_zeroed(layout);
                    std::ptr::write_volatile(ptr, 0u8);
                    dealloc(ptr, layout);
                }
            }
        })
    });
}

// --- Batch Alloc 64B × 100 then free ---

fn bench_batch_64(c: &mut Criterion) {
    c.bench_function("Batch/64B", |b| {
        b.iter(|| {
            let layout = Layout::from_size_align(SMALL_SIZE, 8).unwrap();
            let mut ptrs: [*mut u8; 100] = [std::ptr::null_mut(); 100];
            let mut batch = 0usize;
            for _ in 0..ALLOC_N {
                unsafe {
                    ptrs[batch] = alloc_zeroed(layout);
                    std::ptr::write_volatile(ptrs[batch], 0u8);
                }
                batch += 1;
                if batch == 100 {
                    for j in 0..100 {
                        unsafe { dealloc(ptrs[j], layout); }
                    }
                    batch = 0;
                }
            }
            for j in 0..batch {
                unsafe { dealloc(ptrs[j], layout); }
            }
        })
    });
}

// --- Pool Get/Put 64B × 100000 (crossbeam ArrayQueue) ---

fn bench_pool_64(c: &mut Criterion) {
    let queue = Arc::new(ArrayQueue::new(1024));
    // Pre-fill
    for _ in 0..1024 {
        let layout = Layout::from_size_align(SMALL_SIZE, 8).unwrap();
        unsafe {
            let ptr = alloc_zeroed(layout);
            let _ = queue.push(ptr as usize);
        }
    }

    c.bench_function("Pool/64B", |b| {
        b.iter(|| {
            for _ in 0..POOL_N {
                if let Some(val) = queue.pop() {
                    let _ = queue.push(val);
                }
            }
        })
    });
}

criterion_group!(
    benches,
    bench_alloc_64,
    bench_alloc_1k,
    bench_batch_64,
    bench_pool_64,
);
criterion_main!(benches);
