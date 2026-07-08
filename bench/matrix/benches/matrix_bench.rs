// Matrix benchmark — Rust (criterion)
// Uses heap allocation to avoid stack overflow for large matrices
use criterion::{criterion_group, criterion_main, Criterion, black_box};

const N128: usize = 128;
const N256: usize = 256;
const N512: usize = 512;

type Mat128 = Box<[[i64; N128]; N128]>;
type Mat256 = Box<[[i64; N256]; N256]>;
type Mat512 = Box<[[i64; N512]; N512]>;

fn new_mat128(init: impl Fn(usize, usize) -> i64) -> Mat128 {
    let mut m = vec![[0i64; N128]; N128].into_boxed_slice();
    for i in 0..N128 {
        for j in 0..N128 {
            m[i][j] = init(i, j);
        }
    }
    m.try_into().unwrap()
}

fn new_mat256(init: impl Fn(usize, usize) -> i64) -> Mat256 {
    let mut m = vec![[0i64; N256]; N256].into_boxed_slice();
    for i in 0..N256 {
        for j in 0..N256 {
            m[i][j] = init(i, j);
        }
    }
    m.try_into().unwrap()
}

fn new_mat512(init: impl Fn(usize, usize) -> i64) -> Mat512 {
    let mut m = vec![[0i64; N512]; N512].into_boxed_slice();
    for i in 0..N512 {
        for j in 0..N512 {
            m[i][j] = init(i, j);
        }
    }
    m.try_into().unwrap()
}

fn bench_matmul_128(c: &mut Criterion) {
    let a = new_mat128(|i, j| (i * N128 + j + 1) as i64);
    let b = new_mat128(|i, j| ((i + 1) * (j + 1)) as i64);
    let mut result = new_mat128(|_, _| 0);

    c.bench_function("Matrix/MatMul/128", |bench| {
        bench.iter(|| {
            for i in 0..N128 {
                for j in 0..N128 {
                    let mut sum = 0i64;
                    for k in 0..N128 {
                        sum += a[i][k] * b[k][j];
                    }
                    result[i][j] = sum;
                }
            }
            black_box(&result);
        })
    });
}

fn bench_matadd_512(c: &mut Criterion) {
    let a = new_mat512(|i, j| (i * N512 + j + 1) as i64);
    let b = new_mat512(|i, j| ((i + 1) * (j + 1)) as i64);
    let mut result = new_mat512(|_, _| 0);

    c.bench_function("Matrix/MatAdd/512", |bench| {
        bench.iter(|| {
            for i in 0..N512 {
                for j in 0..N512 {
                    result[i][j] = a[i][j] + b[i][j];
                }
            }
            black_box(&result);
        })
    });
}

fn bench_transpose_512(c: &mut Criterion) {
    let a = new_mat512(|i, j| (i * N512 + j + 1) as i64);

    c.bench_function("Matrix/Transpose/512", |bench| {
        bench.iter(|| {
            let mut result = a.clone();
            for i in 0..N512 {
                for j in (i + 1)..N512 {
                    let tmp = result[i][j];
                    result[i][j] = result[j][i];
                    result[j][i] = tmp;
                }
            }
            black_box(&result);
        })
    });
}

fn bench_matmul_256(c: &mut Criterion) {
    let a = new_mat256(|i, j| (i * N256 + j + 1) as i64);
    let b = new_mat256(|i, j| ((i + 1) * (j + 1)) as i64);
    let mut result = new_mat256(|_, _| 0);

    c.bench_function("Matrix/MatMul/256", |bench| {
        bench.iter(|| {
            for i in 0..N256 {
                for j in 0..N256 {
                    let mut sum = 0i64;
                    for k in 0..N256 {
                        sum += a[i][k] * b[k][j];
                    }
                    result[i][j] = sum;
                }
            }
            black_box(&result);
        })
    });
}

criterion_group!(benches, bench_matmul_128, bench_matadd_512, bench_transpose_512, bench_matmul_256);
criterion_main!(benches);
