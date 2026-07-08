use criterion::{black_box, criterion_group, criterion_main, Criterion};
use std::hint::black_box as std_black_box;

const N: usize = 1_000_000;

fn bench_int_to_str(c: &mut Criterion) {
    let ints: Vec<i64> = (0..N as i64).collect();
    c.bench_function("IntToStr/1M", |b| {
        b.iter(|| {
            let mut sink = String::new();
            for &v in &ints {
                sink = v.to_string();
            }
            std_black_box(&sink);
        })
    });
}

fn bench_str_to_int(c: &mut Criterion) {
    let strs: Vec<String> = (0..N).map(|i| i.to_string()).collect();
    c.bench_function("StrToInt/1M", |b| {
        b.iter(|| {
            let mut sink: i64 = 0;
            for s in &strs {
                sink = s.parse::<i64>().unwrap_or(0);
            }
            std_black_box(sink);
        })
    });
}

fn bench_int_to_hex(c: &mut Criterion) {
    let ints: Vec<i64> = (0..N as i64).collect();
    c.bench_function("IntToHex/1M", |b| {
        b.iter(|| {
            let mut sink = String::new();
            for &v in &ints {
                sink = format!("{:016x}", v);
            }
            std_black_box(&sink);
        })
    });
}

fn bench_uint_to_str(c: &mut Criterion) {
    let ints: Vec<u64> = (0..N as u64).collect();
    c.bench_function("UIntToStr/1M", |b| {
        b.iter(|| {
            let mut sink = String::new();
            for &v in &ints {
                sink = v.to_string();
            }
            std_black_box(&sink);
        })
    });
}

fn bench_try_str_to_int(c: &mut Criterion) {
    let strs: Vec<String> = (0..N).map(|i| i.to_string()).collect();
    c.bench_function("TryStrToInt/1M", |b| {
        b.iter(|| {
            let mut sink: i64 = 0;
            for s in &strs {
                if let Ok(v) = s.parse::<i64>() {
                    sink = v;
                }
            }
            std_black_box(sink);
        })
    });
}

fn bench_float_to_str(c: &mut Criterion) {
    let floats: Vec<f64> = (0..N).map(|i| i as f64 * 3.14159).collect();
    c.bench_function("FloatToStr/1M", |b| {
        b.iter(|| {
            let mut sink = String::new();
            for &v in &floats {
                sink = format!("{}", v);
            }
            std_black_box(&sink);
        })
    });
}

criterion_group!(
    benches,
    bench_int_to_str,
    bench_str_to_int,
    bench_int_to_hex,
    bench_uint_to_str,
    bench_try_str_to_int,
    bench_float_to_str,
);
criterion_main!(benches);
