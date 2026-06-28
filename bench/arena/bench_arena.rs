// bench_arena.rs — Rust 综合竞技场基准
//
// 四个赛道：HashMap / Sort / String / JSON
// 使用 criterion 运行: cargo bench
use criterion::{criterion_group, criterion_main, BenchmarkId, Criterion, Throughput};
use std::collections::HashMap;

const HASHMAP_N: usize = 100000;
const SORT_N: usize = 10000;
const STRING_N: usize = 10000;
const JSON_N: usize = 1000;

// === 赛道 1: HashMap ===

fn bench_hashmap_insert(c: &mut Criterion) {
    let mut group = c.benchmark_group("HashMap");
    group.throughput(Throughput::Elements(HASHMAP_N as u64));

    group.bench_function("Insert", |b| {
        b.iter(|| {
            let mut m = HashMap::with_capacity(HASHMAP_N);
            for i in 0..HASHMAP_N {
                m.insert((i as u64 * 2654435761) & 0x7FFFFFFF, i);
            }
            m
        })
    });

    group.finish();
}

fn bench_hashmap_lookup(c: &mut Criterion) {
    let mut m = HashMap::with_capacity(HASHMAP_N);
    for i in 0..HASHMAP_N {
        m.insert((i as u64 * 2654435761) & 0x7FFFFFFF, i);
    }
    let keys: Vec<u64> = (0..HASHMAP_N)
        .map(|i| (i as u64 * 2654435761) & 0x7FFFFFFF)
        .collect();

    let mut group = c.benchmark_group("HashMap");
    group.throughput(Throughput::Elements(HASHMAP_N as u64));

    group.bench_function("Lookup", |b| {
        b.iter(|| {
            let mut found = 0usize;
            for key in &keys {
                if m.contains_key(key) {
                    found += 1;
                }
            }
            found
        })
    });

    group.finish();
}

fn bench_hashmap_iterate(c: &mut Criterion) {
    let mut m = HashMap::with_capacity(HASHMAP_N);
    for i in 0..HASHMAP_N {
        m.insert((i as u64 * 2654435761) & 0x7FFFFFFF, i);
    }

    let mut group = c.benchmark_group("HashMap");
    group.throughput(Throughput::Elements(HASHMAP_N as u64));

    group.bench_function("Iterate", |b| {
        b.iter(|| {
            let mut count = 0usize;
            for _ in &m {
                count += 1;
            }
            count
        })
    });

    group.finish();
}

// === 赛道 2: Sort ===

fn bench_sort_int32(c: &mut Criterion) {
    let data: Vec<i32> = (0..SORT_N).map(|i| ((i as i64 * 48271) % 1000000) as i32).collect();

    let mut group = c.benchmark_group("Sort");
    group.throughput(Throughput::Bytes((SORT_N * 4) as u64));

    group.bench_function("Int32", |b| {
        b.iter(|| {
            let mut d = data.clone();
            d.sort_unstable();
            d
        })
    });

    group.finish();
}

// === 赛道 3: String ===

fn bench_string_builder(c: &mut Criterion) {
    let mut group = c.benchmark_group("String");
    group.throughput(Throughput::Bytes((STRING_N * 16) as u64));

    group.bench_function("Builder", |b| {
        b.iter(|| {
            let mut s = String::with_capacity(STRING_N * 16);
            for i in 0..STRING_N {
                s.push_str("item_");
                s.push_str(&i.to_string());
                s.push(',');
            }
            s
        })
    });

    group.finish();
}

fn bench_string_concat(c: &mut Criterion) {
    let mut group = c.benchmark_group("String");
    group.throughput(Throughput::Bytes((STRING_N * 16) as u64));

    group.bench_function("Concat", |b| {
        b.iter(|| {
            let mut result = String::new();
            for i in 0..STRING_N {
                result = result + "item_" + &i.to_string() + ",";
            }
            result
        })
    });

    group.finish();
}

// === 赛道 4: JSON ===

#[derive(serde::Serialize, serde::Deserialize)]
struct User {
    id: usize,
    name: String,
    email: String,
    age: usize,
}

#[derive(serde::Serialize, serde::Deserialize)]
struct Users {
    users: Vec<User>,
}

fn bench_json_parse(c: &mut Criterion) {
    let users = Users {
        users: (0..JSON_N)
            .map(|i| User {
                id: i,
                name: format!("user_{}", i),
                email: format!("user{}@example.com", i),
                age: 20 + (i % 50),
            })
            .collect(),
    };
    let json_str = serde_json::to_string(&users).unwrap();

    let mut group = c.benchmark_group("JSON");
    group.throughput(Throughput::Bytes(json_str.len() as u64));

    group.bench_function("Parse", |b| {
        b.iter(|| {
            let _: Users = serde_json::from_str(&json_str).unwrap();
        })
    });

    group.finish();
}

criterion_group!(
    benches,
    bench_hashmap_insert,
    bench_hashmap_lookup,
    bench_hashmap_iterate,
    bench_sort_int32,
    bench_string_builder,
    bench_string_concat,
    bench_json_parse,
);
criterion_main!(benches);
