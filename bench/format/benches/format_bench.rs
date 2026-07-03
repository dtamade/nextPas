use criterion::{criterion_group, criterion_main, Criterion};
use std::fmt::Write;
use std::hint::black_box;

const N: usize = 100_000;

fn make_data() -> (Vec<String>, Vec<i32>, Vec<f64>) {
    let names: Vec<String> = (0..N).map(|i| format!("item_{}", i)).collect();
    let values: Vec<i32> = (0..N as i32).collect();
    let floats: Vec<f64> = (0..N).map(|i| i as f64 * 3.14159).collect();
    (names, values, floats)
}

fn bench_format_int(c: &mut Criterion) {
    let (_, values, _) = make_data();
    c.bench_function("Format/Int/100k", |b| {
        b.iter(|| {
            let mut s = String::new();
            for &v in &values {
                s.clear();
                write!(s, "Value: {}", v).unwrap();
            }
            black_box(&s);
        })
    });
}

fn bench_format_str(c: &mut Criterion) {
    let (names, _, _) = make_data();
    c.bench_function("Format/Str/100k", |b| {
        b.iter(|| {
            let mut s = String::new();
            for n in &names {
                s.clear();
                write!(s, "Name: {}", n).unwrap();
            }
            black_box(&s);
        })
    });
}

fn bench_format_multi(c: &mut Criterion) {
    let (names, values, floats) = make_data();
    c.bench_function("Format/Multi/100k", |b| {
        b.iter(|| {
            let mut s = String::new();
            for i in 0..N {
                s.clear();
                write!(s, "{}={} ({})", names[i], values[i], floats[i]).unwrap();
            }
            black_box(&s);
        })
    });
}

fn bench_format_hex(c: &mut Criterion) {
    let (_, values, _) = make_data();
    c.bench_function("Format/Hex/100k", |b| {
        b.iter(|| {
            let mut s = String::new();
            for &v in &values {
                s.clear();
                write!(s, "{:08X}", v).unwrap();
            }
            black_box(&s);
        })
    });
}

criterion_group!(benches, bench_format_int, bench_format_str, bench_format_multi, bench_format_hex);
criterion_main!(benches);
