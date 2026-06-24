use criterion::{black_box, criterion_group, criterion_main, Criterion, BenchmarkId};
use rand::Rng;

/// Compute mean of a slice
fn mean(data: &[f64]) -> f64 {
    if data.is_empty() {
        return 0.0;
    }
    data.iter().sum::<f64>() / data.len() as f64
}

/// Compute standard deviation of a slice
fn stddev(data: &[f64]) -> f64 {
    if data.is_empty() {
        return 0.0;
    }
    let m = mean(data);
    let variance = data.iter().map(|x| (x - m).powi(2)).sum::<f64>() / data.len() as f64;
    variance.sqrt()
}

/// Sort data in-place
fn sort_data(data: &mut [f64]) {
    data.sort_by(|a, b| a.partial_cmp(b).unwrap());
}

/// Compute percentile from sorted data
fn percentile(sorted: &[f64], p: f64) -> f64 {
    if sorted.is_empty() {
        return 0.0;
    }
    let idx = p / 100.0 * (sorted.len() - 1) as f64;
    let lower = idx.floor() as usize;
    let upper = idx.ceil() as usize;
    if lower == upper {
        sorted[lower]
    } else {
        let frac = idx - lower as f64;
        sorted[lower] * (1.0 - frac) + sorted[upper] * frac
    }
}

/// Compute full statistics
fn compute_stats(data: &[f64]) -> (f64, f64, f64, f64, f64) {
    if data.is_empty() {
        return (0.0, 0.0, 0.0, 0.0, 0.0);
    }

    let mut sorted = data.to_vec();
    sort_data(&mut sorted);

    let m = mean(data);
    let sd = stddev(data);
    let med = percentile(&sorted, 50.0);
    let p25 = percentile(&sorted, 25.0);
    let p75 = percentile(&sorted, 75.0);

    (m, sd, med, p25, p75)
}

fn generate_data(size: usize) -> Vec<f64> {
    let mut rng = rand::thread_rng();
    (0..size).map(|_| 100.0 + rng.gen::<f64>() * 10.0).collect()
}

fn bench_mean(c: &mut Criterion) {
    let mut group = c.benchmark_group("Mean");

    for size in [100, 1000, 10000] {
        let data = generate_data(size);
        group.bench_with_input(BenchmarkId::from_parameter(size), &data, |b, data| {
            b.iter(|| {
                black_box(mean(black_box(data)));
            });
        });
    }
    group.finish();
}

fn bench_stddev(c: &mut Criterion) {
    let mut group = c.benchmark_group("StdDev");

    for size in [100, 1000, 10000] {
        let data = generate_data(size);
        group.bench_with_input(BenchmarkId::from_parameter(size), &data, |b, data| {
            b.iter(|| {
                black_box(stddev(black_box(data)));
            });
        });
    }
    group.finish();
}

fn bench_sort(c: &mut Criterion) {
    let mut group = c.benchmark_group("Sort");

    for size in [100, 1000, 10000] {
        let data = generate_data(size);
        group.bench_with_input(BenchmarkId::from_parameter(size), &data, |b, data| {
            b.iter_batched(
                || data.clone(),
                |mut d| {
                    sort_data(&mut d);
                    black_box(d);
                },
                criterion::BatchSize::SmallInput,
            );
        });
    }
    group.finish();
}

fn bench_compute_stats(c: &mut Criterion) {
    let mut group = c.benchmark_group("ComputeStats");

    for size in [100, 1000, 10000] {
        let data = generate_data(size);
        group.bench_with_input(BenchmarkId::from_parameter(size), &data, |b, data| {
            b.iter(|| {
                black_box(compute_stats(black_box(data)));
            });
        });
    }
    group.finish();
}

fn bench_percentile(c: &mut Criterion) {
    let mut group = c.benchmark_group("Percentile");

    for size in [100, 1000, 10000] {
        let mut data = generate_data(size);
        sort_data(&mut data);
        group.bench_with_input(BenchmarkId::from_parameter(size), &data, |b, data| {
            b.iter(|| {
                black_box(percentile(black_box(data), 25.0));
                black_box(percentile(black_box(data), 50.0));
                black_box(percentile(black_box(data), 75.0));
                black_box(percentile(black_box(data), 95.0));
            });
        });
    }
    group.finish();
}

criterion_group!(
    benches,
    bench_mean,
    bench_stddev,
    bench_sort,
    bench_compute_stats,
    bench_percentile
);
criterion_main!(benches);
