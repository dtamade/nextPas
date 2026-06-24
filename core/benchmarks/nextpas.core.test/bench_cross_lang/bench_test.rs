// bench_test.rs — Rust benchmarks with black_box to prevent optimization
#![feature(test)]
extern crate test;

use test::Bencher;

#[bench]
fn bench_check_true(b: &mut Bencher) {
    let mut v = true;
    b.iter(|| {
        for i in 0..1000 {
            assert!(test::black_box(v && i >= 0));
        }
    });
}

#[bench]
fn bench_check_equal_i64(b: &mut Bencher) {
    let v: i64 = 42;
    b.iter(|| {
        for _ in 0..1000 {
            assert_eq!(test::black_box(v), 42i64);
        }
    });
}

#[bench]
fn bench_check_equal_string(b: &mut Bencher) {
    let v = "hello";
    b.iter(|| {
        for _ in 0..1000 {
            assert_eq!(test::black_box(v), "hello");
        }
    });
}

#[bench]
fn bench_check_near(b: &mut Bencher) {
    let v: f64 = 3.14;
    b.iter(|| {
        for _ in 0..1000 {
            let e = test::black_box(3.1400000001f64);
            assert!((test::black_box(v) - e).abs() <= 1e-6);
        }
    });
}
