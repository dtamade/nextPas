use criterion::{criterion_group, criterion_main, Criterion};
use std::hint::black_box;

const N: usize = 100_000;
const QUERIES: usize = 100_000;

fn make_data() -> (Vec<i64>, Vec<i64>) {
    let sorted: Vec<i64> = (0..N as i64).map(|i| i * 3).collect();
    let mut queries = Vec::with_capacity(QUERIES);
    let mut seed: u32 = 12345;
    for _ in 0..QUERIES {
        seed = seed.wrapping_mul(1103515245).wrapping_add(12345);
        queries.push((seed % (N as u32 * 3)) as i64);
    }
    (sorted, queries)
}

fn binary_search(a: &[i64], key: i64) -> usize {
    match a.binary_search(&key) {
        Ok(i) => i,
        Err(_) => usize::MAX,
    }
}

fn bench_binary_search(c: &mut Criterion) {
    let (sorted, queries) = make_data();
    c.bench_function("BinarySearch/100k", |b| {
        b.iter(|| {
            let mut found = 0usize;
            for &q in &queries {
                found = binary_search(&sorted, q);
            }
            black_box(found);
        })
    });
}

fn bench_binary_search_hit(c: &mut Criterion) {
    let (sorted, _) = make_data();
    c.bench_function("BinarySearchHit/100k", |b| {
        b.iter(|| {
            let mut found = 0usize;
            for i in 0..QUERIES {
                found = binary_search(&sorted, sorted[i % N]);
            }
            black_box(found);
        })
    });
}

criterion_group!(benches, bench_binary_search, bench_binary_search_hit);
criterion_main!(benches);
