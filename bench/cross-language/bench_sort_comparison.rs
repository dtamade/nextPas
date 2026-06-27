// bench_sort_comparison.rs — Rust 跨语言排序基准
//
// 与 nextPas Pascal 基准同场景对比，输出 criterion 格式。
// 使用 criterion 运行: cargo bench

use criterion::{criterion_group, criterion_main, BenchmarkId, Criterion};

const N: usize = 1000;
const SEED: u64 = 42;

fn init_data() -> Vec<i32> {
    let mut rng = SimpleRng::new(SEED);
    (0..N).map(|_| (rng.next() % 1000000) as i32).collect()
}

struct SimpleRng {
    state: u64,
}

impl SimpleRng {
    fn new(seed: u64) -> Self {
        Self { state: seed }
    }
    fn next(&mut self) -> u64 {
        self.state = self.state.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        self.state
    }
}

fn insertion_sort(data: &[i32]) -> Vec<i32> {
    let mut d = data.to_vec();
    for i in 1..d.len() {
        let key = d[i];
        let mut j = i as isize - 1;
        while j >= 0 && d[j as usize] > key {
            d[(j + 1) as usize] = d[j as usize];
            j -= 1;
        }
        d[(j + 1) as usize] = key;
    }
    d
}

fn quick_sort(data: &[i32]) -> Vec<i32> {
    let mut d = data.to_vec();
    d.sort();
    d
}

fn merge_sort(data: &[i32]) -> Vec<i32> {
    fn merge_sort_inner(d: &[i32]) -> Vec<i32> {
        if d.len() <= 1 {
            return d.to_vec();
        }
        let mid = d.len() / 2;
        let left = merge_sort_inner(&d[..mid]);
        let right = merge_sort_inner(&d[mid..]);
        let mut result = Vec::with_capacity(d.len());
        let (mut i, mut j) = (0, 0);
        while i < left.len() && j < right.len() {
            if left[i] <= right[j] {
                result.push(left[i]);
                i += 1;
            } else {
                result.push(right[j]);
                j += 1;
            }
        }
        result.extend_from_slice(&left[i..]);
        result.extend_from_slice(&right[j..]);
        result
    }
    merge_sort_inner(data)
}

fn bench_sort(c: &mut Criterion) {
    let data = init_data();

    let mut group = c.benchmark_group("Sort/N=1000");
    group.throughput(criterion::Throughput::Bytes((N * 4) as u64));

    group.bench_function("InsertionSort", |b| {
        b.iter(|| insertion_sort(&data))
    });

    group.bench_function("QuickSort", |b| {
        b.iter(|| quick_sort(&data))
    });

    group.bench_function("MergeSort", |b| {
        b.iter(|| merge_sort(&data))
    });

    group.finish();
}

criterion_group!(benches, bench_sort);
criterion_main!(benches);
