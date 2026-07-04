use criterion::{criterion_group, criterion_main, Criterion};
use std::hint::black_box;

const N: usize = 100_000;

type ByteSet = [u8; 32];

fn set_add(s: &mut ByteSet, v: u8) {
    s[(v / 8) as usize] |= 1 << (v % 8);
}

fn set_has(s: &ByteSet, v: u8) -> bool {
    s[(v / 8) as usize] & (1 << (v % 8)) != 0
}

fn set_union(a: &ByteSet, b: &ByteSet) -> ByteSet {
    let mut r = [0u8; 32];
    for i in 0..32 {
        r[i] = a[i] | b[i];
    }
    r
}

fn set_intersect(a: &ByteSet, b: &ByteSet) -> ByteSet {
    let mut r = [0u8; 32];
    for i in 0..32 {
        r[i] = a[i] & b[i];
    }
    r
}

fn set_difference(a: &ByteSet, b: &ByteSet) -> ByteSet {
    let mut r = [0u8; 32];
    for i in 0..32 {
        r[i] = a[i] & !b[i];
    }
    r
}

fn make_data() -> (ByteSet, ByteSet, Vec<u8>) {
    let mut set_a = [0u8; 32];
    let mut set_b = [0u8; 32];
    let mut values = Vec::with_capacity(N);
    let mut seed: u32 = 12345;
    for i in 0..N {
        seed = seed.wrapping_mul(1103515245).wrapping_add(12345);
        let v = (seed & 0xFF) as u8;
        values.push(v);
        if i % 2 == 0 {
            set_add(&mut set_a, v);
        } else {
            set_add(&mut set_b, v);
        }
    }
    (set_a, set_b, values)
}

fn bench_union(c: &mut Criterion) {
    let (set_a, set_b, _) = make_data();
    c.bench_function("Union/100k", |b| {
        b.iter(|| {
            let mut acc = [0u8; 32];
            for i in 0..N {
                let r = set_union(black_box(&set_a), black_box(&set_b));
                acc[i % 32] ^= r[i % 32];
            }
            black_box(acc);
        })
    });
}

fn bench_intersection(c: &mut Criterion) {
    let (set_a, set_b, _) = make_data();
    c.bench_function("Intersection/100k", |b| {
        b.iter(|| {
            let mut acc = [0u8; 32];
            for i in 0..N {
                let r = set_intersect(black_box(&set_a), black_box(&set_b));
                acc[i % 32] ^= r[i % 32];
            }
            black_box(acc);
        })
    });
}

fn bench_difference(c: &mut Criterion) {
    let (set_a, set_b, _) = make_data();
    c.bench_function("Difference/100k", |b| {
        b.iter(|| {
            let mut acc = [0u8; 32];
            for i in 0..N {
                let r = set_difference(black_box(&set_a), black_box(&set_b));
                acc[i % 32] ^= r[i % 32];
            }
            black_box(acc);
        })
    });
}

fn bench_membership(c: &mut Criterion) {
    let (set_a, _, values) = make_data();
    c.bench_function("Membership/100k", |b| {
        b.iter(|| {
            let mut count = 0i32;
            for &v in &values {
                if set_has(&set_a, v) {
                    count += 1;
                }
            }
            black_box(count);
        })
    });
}

fn bench_build(c: &mut Criterion) {
    let (_, _, values) = make_data();
    c.bench_function("Build/100k", |b| {
        b.iter(|| {
            let mut s = [0u8; 32];
            for &v in &values {
                set_add(&mut s, v);
            }
            black_box(s[0]);
        })
    });
}

criterion_group!(benches, bench_union, bench_intersection, bench_difference, bench_membership, bench_build);
criterion_main!(benches);
