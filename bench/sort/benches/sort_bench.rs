use criterion::{criterion_group, criterion_main, Criterion};
use std::hint::black_box;

const N: usize = 100_000;
const N2: usize = 1_000_000;

fn make_arr(seed: u64, n: usize) -> Vec<i64> {
    let mut rng = seed;
    (0..n).map(|_| {
        rng = rng.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        rng as i64
    }).collect()
}

fn bench_sort_100k(c: &mut Criterion) {
    let arr = make_arr(12345, N);
    c.bench_function("Sort/100k", |b| {
        b.iter(|| {
            let mut tmp = arr.clone();
            tmp.sort_unstable();
            black_box(&tmp);
        })
    });
}

fn bench_sort_1m(c: &mut Criterion) {
    let arr = make_arr(12345, N2);
    c.bench_function("Sort/1M", |b| {
        b.iter(|| {
            let mut tmp = arr.clone();
            tmp.sort_unstable();
            black_box(&tmp);
        })
    });
}

fn bench_sort_sorted(c: &mut Criterion) {
    let arr: Vec<i64> = (0..N as i64).collect();
    c.bench_function("Sort/Sorted/100k", |b| {
        b.iter(|| {
            let mut tmp = arr.clone();
            tmp.sort_unstable();
            black_box(&tmp);
        })
    });
}

fn bench_sort_reverse(c: &mut Criterion) {
    let arr: Vec<i64> = (0..N as i64).rev().collect();
    c.bench_function("Sort/Reverse/100k", |b| {
        b.iter(|| {
            let mut tmp = arr.clone();
            tmp.sort_unstable();
            black_box(&tmp);
        })
    });
}

criterion_group!(benches, bench_sort_100k, bench_sort_1m, bench_sort_sorted, bench_sort_reverse);
criterion_main!(benches);
