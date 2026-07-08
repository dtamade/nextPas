use criterion::{criterion_group, criterion_main, Criterion};
use std::fmt::Write;
use std::hint::black_box;

const N: usize = 100_000;

fn make_parts() -> Vec<String> {
    (0..N).map(|i| format!("item_{}", i)).collect()
}

fn bench_builder_append(c: &mut Criterion) {
    let parts = make_parts();
    c.bench_function("Builder/Append/100k", |b| {
        b.iter(|| {
            let mut sb = String::with_capacity(N * 16);
            for p in &parts {
                sb.push_str(p);
                sb.push(',');
            }
            black_box(sb.len());
        })
    });
}

fn bench_builder_int_append(c: &mut Criterion) {
    c.bench_function("Builder/IntAppend/100k", |b| {
        b.iter(|| {
            let mut sb = String::with_capacity(N * 16);
            for i in 0..N {
                write!(sb, "{}", i).unwrap();
                sb.push(',');
            }
            black_box(sb.len());
        })
    });
}

fn bench_concat(c: &mut Criterion) {
    let parts = make_parts();
    c.bench_function("Concat/100k", |b| {
        b.iter(|| {
            let mut s = String::new();
            for p in &parts {
                s += p;
                s.push(',');
            }
            black_box(s.len());
        })
    });
}

fn bench_builder_large(c: &mut Criterion) {
    c.bench_function("Builder/Large/100k", |b| {
        b.iter(|| {
            let mut sb = String::with_capacity(N * 32);
            for i in 0..N {
                write!(sb, "line_{}: value={}\n", i, i as f64 * 3.14).unwrap();
            }
            black_box(sb.len());
        })
    });
}

criterion_group!(benches, bench_builder_append, bench_builder_int_append, bench_concat, bench_builder_large);
criterion_main!(benches);
