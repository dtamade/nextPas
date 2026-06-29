use criterion::{criterion_group, criterion_main, Criterion};
use std::alloc::{alloc_zeroed, dealloc, Layout};
use std::thread;

const OPS_PER_THREAD: usize = 100000;
const SMALL_SIZE: usize = 64;
const LARGE_SIZE: usize = 1024;

fn concurrent_alloc(c: &mut Criterion, name: &str, size: usize, threads: usize) {
    c.bench_function(name, |b| {
        b.iter(|| {
            let handles: Vec<_> = (0..threads)
                .map(|_| {
                    thread::spawn(move || {
                        let layout = Layout::from_size_align(size, 8).unwrap();
                        for _ in 0..OPS_PER_THREAD {
                            unsafe {
                                let ptr = alloc_zeroed(layout);
                                std::ptr::write_volatile(ptr, 0u8);
                                dealloc(ptr, layout);
                            }
                        }
                    })
                })
                .collect();
            for h in handles {
                h.join().unwrap();
            }
        })
    });
}

fn bench_conc_64_4(c: &mut Criterion)  { concurrent_alloc(c, "Conc/64B/4t",  SMALL_SIZE, 4); }
fn bench_conc_64_8(c: &mut Criterion)  { concurrent_alloc(c, "Conc/64B/8t",  SMALL_SIZE, 8); }
fn bench_conc_64_16(c: &mut Criterion) { concurrent_alloc(c, "Conc/64B/16t", SMALL_SIZE, 16); }
fn bench_conc_1k_4(c: &mut Criterion)  { concurrent_alloc(c, "Conc/1KB/4t",  LARGE_SIZE, 4); }
fn bench_conc_1k_8(c: &mut Criterion)  { concurrent_alloc(c, "Conc/1KB/8t",  LARGE_SIZE, 8); }
fn bench_conc_1k_16(c: &mut Criterion) { concurrent_alloc(c, "Conc/1KB/16t", LARGE_SIZE, 16); }

criterion_group!(
    benches,
    bench_conc_64_4,
    bench_conc_64_8,
    bench_conc_64_16,
    bench_conc_1k_4,
    bench_conc_1k_8,
    bench_conc_1k_16,
);
criterion_main!(benches);
