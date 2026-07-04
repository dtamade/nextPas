use criterion::{criterion_group, criterion_main, Criterion};
use std::collections::HashMap;
use std::hint::black_box;

const N: usize = 100_000;

fn make_keys() -> Vec<String> {
    (0..N).map(|i| format!("key_{}", i)).collect()
}

fn bench_insert(c: &mut Criterion) {
    let keys = make_keys();
    c.bench_function("Insert/100k", |b| {
        b.iter(|| {
            let mut m = HashMap::with_capacity(N);
            for (i, k) in keys.iter().enumerate() {
                m.insert(k.clone(), i);
            }
            black_box(&m);
        })
    });
}

fn bench_lookup(c: &mut Criterion) {
    let keys = make_keys();
    let mut m = HashMap::with_capacity(N);
    for (i, k) in keys.iter().enumerate() {
        m.insert(k.clone(), i);
    }
    c.bench_function("Lookup/100k", |b| {
        b.iter(|| {
            let mut sink = 0usize;
            for k in &keys {
                if let Some(&v) = m.get(k) {
                    sink = v;
                }
            }
            black_box(sink);
        })
    });
}

fn bench_insert_lookup(c: &mut Criterion) {
    let keys = make_keys();
    c.bench_function("InsertLookup/100k", |b| {
        b.iter(|| {
            let mut m = HashMap::with_capacity(N);
            for (i, k) in keys.iter().enumerate() {
                m.insert(k.clone(), i);
            }
            let mut sink = 0usize;
            for k in &keys {
                if let Some(&v) = m.get(k) {
                    sink = v;
                }
            }
            black_box(sink);
        })
    });
}

fn bench_lookup_miss(c: &mut Criterion) {
    let keys = make_keys();
    let mut m = HashMap::with_capacity(N);
    for (i, k) in keys.iter().enumerate() {
        m.insert(k.clone(), i);
    }
    let miss_keys: Vec<String> = (0..N).map(|i| format!("miss_{}", i)).collect();
    c.bench_function("LookupMiss/100k", |b| {
        b.iter(|| {
            let mut sink = 0usize;
            for k in &miss_keys {
                if let Some(&v) = m.get(k) {
                    sink = v;
                }
            }
            black_box(sink);
        })
    });
}

criterion_group!(benches, bench_insert, bench_lookup, bench_insert_lookup, bench_lookup_miss);
criterion_main!(benches);
