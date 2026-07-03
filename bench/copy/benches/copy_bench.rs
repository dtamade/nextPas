use criterion::{criterion_group, criterion_main, Criterion, black_box};

const N: usize = 10000;

fn bench_fill(c: &mut Criterion) {
    let mut dst = vec![0u8; 65536];

    c.bench_function("Fill/64B", |b| {
        b.iter(|| {
            for i in 0..N {
                dst[..64].fill(black_box((i & 255) as u8));
            }
            black_box(&dst);
        })
    });

    c.bench_function("Fill/1KB", |b| {
        b.iter(|| {
            for i in 0..N {
                dst[..1024].fill(black_box((i & 255) as u8));
            }
            black_box(&dst);
        })
    });

    c.bench_function("Fill/64KB", |b| {
        b.iter(|| {
            for i in 0..N {
                dst[..65536].fill(black_box((i & 255) as u8));
            }
            black_box(&dst);
        })
    });
}

fn bench_move(c: &mut Criterion) {
    let src: Vec<u8> = (0..65536).map(|i| (i & 255) as u8).collect();
    let mut dst = vec![0u8; 65536];

    c.bench_function("Move/64B", |b| {
        b.iter(|| {
            for _ in 0..N {
                dst[..64].copy_from_slice(&src[..64]);
            }
            black_box(&dst);
        })
    });

    c.bench_function("Move/1KB", |b| {
        b.iter(|| {
            for _ in 0..N {
                dst[..1024].copy_from_slice(&src[..1024]);
            }
            black_box(&dst);
        })
    });

    c.bench_function("Move/64KB", |b| {
        b.iter(|| {
            for _ in 0..N {
                dst[..65536].copy_from_slice(&src[..65536]);
            }
            black_box(&dst);
        })
    });
}

fn bench_compare(c: &mut Criterion) {
    let src: Vec<u8> = (0..65536).map(|i| (i & 255) as u8).collect();
    let mut dst: Vec<u8> = (0..65536).map(|i| (i & 255) as u8).collect();

    c.bench_function("Compare/Eq1K", |b| {
        b.iter(|| {
            for _ in 0..N {
                black_box(src[..1024] == dst[..1024]);
            }
        })
    });

    c.bench_function("Compare/Diff1K", |b| {
        b.iter(|| {
            for i in 0..N {
                dst[1023] = (i & 255) as u8;
                black_box(src[..1024] == dst[..1024]);
            }
        })
    });
}

fn bench_reverse(c: &mut Criterion) {
    let src: Vec<u8> = (0..65536).map(|i| (i & 255) as u8).collect();
    let mut dst = vec![0u8; 1024];

    c.bench_function("Reverse/1KB", |b| {
        b.iter(|| {
            for _ in 0..N {
                dst.copy_from_slice(&src[..1024]);
                dst[..1024].reverse();
            }
            black_box(&dst);
        })
    });
}

criterion_group!(benches, bench_fill, bench_move, bench_compare, bench_reverse);
criterion_main!(benches);
