use criterion::{criterion_group, criterion_main, black_box, Criterion, Throughput};

fn bench_array_fill_1m(c: &mut Criterion) {
    let mut group = c.benchmark_group("Array/Fill/1M");
    group.throughput(Throughput::Bytes((1_000_000 * 8) as u64));
    let mut arr = vec![0i64; 1_000_000];
    group.bench_function("Array/Fill/1M", |b| {
        b.iter(|| {
            for x in arr.iter_mut() {
                *x = 0;
            }
        });
    });
    group.finish();
}

fn bench_array_sum_1m(c: &mut Criterion) {
    let mut group = c.benchmark_group("Array/Sum/1M");
    group.throughput(Throughput::Bytes((1_000_000 * 8) as u64));
    let arr: Vec<i64> = (0..1_000_000).collect();
    group.bench_function("Array/Sum/1M", |b| {
        b.iter(|| {
            let mut sum: i64 = 0;
            for &x in &arr {
                sum += x;
            }
            sum
        });
    });
    group.finish();
}

fn bench_array_reverse_1m(c: &mut Criterion) {
    let mut group = c.benchmark_group("Array/Reverse/1M");
    group.throughput(Throughput::Bytes((1_000_000 * 8) as u64));
    let mut arr: Vec<i64> = (0..1_000_000).collect();
    group.bench_function("Array/Reverse/1M", |b| {
        b.iter(|| {
            arr.reverse();
        });
    });
    group.finish();
}

fn bench_array_scan_100k(c: &mut Criterion) {
    let mut group = c.benchmark_group("Array/Scan/100k");
    group.throughput(Throughput::Elements(1000));
    let arr: Vec<i64> = (0..100_000).map(|i| i * 3 + 7).collect();
    let targets: Vec<i64> = (0..1000)
        .map(|i| ((i * 7919) % 100_000) as i64 * 3 + 7)
        .collect();
    group.bench_function("Array/Scan/100k", |b| {
        b.iter(|| {
            let mut found = 0i64;
            for i in 0..targets.len() {
                let t = black_box(targets[i]);
                for j in 0..arr.len() {
                    if black_box(arr[j]) == t {
                        found += 1;
                        break;
                    }
                }
            }
            found
        });
    });
    group.finish();
}

criterion_group!(
    benches,
    bench_array_fill_1m,
    bench_array_sum_1m,
    bench_array_reverse_1m,
    bench_array_scan_100k
);
criterion_main!(benches);
