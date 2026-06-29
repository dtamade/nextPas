use criterion::{criterion_group, criterion_main, Criterion};
use std::hint::black_box;

const N: usize = 100_000;
const STR_LEN: usize = 100;

fn make_strings() -> (Vec<String>, Vec<String>) {
    let mut a = Vec::with_capacity(N);
    let mut b = Vec::with_capacity(N);
    for i in 0..N {
        let sa: String = (0..STR_LEN).map(|j| (b'a' + ((i + j) % 26) as u8) as char).collect();
        let sb: String = (0..STR_LEN).map(|j| (b'A' + ((i + j) % 26) as u8) as char).collect();
        a.push(sa);
        b.push(sb);
    }
    (a, b)
}

fn bench_same_text(c: &mut Criterion) {
    let (a, b) = make_strings();
    c.bench_function("SameText/100k", |b_| {
        b_.iter(|| {
            let mut r = false;
            for i in 0..N {
                r = a[i].eq_ignore_ascii_case(&b[i]);
            }
            black_box(r);
        })
    });
}

fn bench_upper_case(c: &mut Criterion) {
    let (a, _) = make_strings();
    c.bench_function("UpperCase/100k", |b_| {
        b_.iter(|| {
            let mut s = String::new();
            for i in 0..N {
                s = a[i].to_uppercase();
            }
            black_box(&s);
        })
    });
}

fn bench_lower_case(c: &mut Criterion) {
    let (_, b) = make_strings();
    c.bench_function("LowerCase/100k", |b_| {
        b_.iter(|| {
            let mut s = String::new();
            for i in 0..N {
                s = b[i].to_lowercase();
            }
            black_box(&s);
        })
    });
}

fn bench_compare_str(c: &mut Criterion) {
    let (a, _) = make_strings();
    c.bench_function("CompareStr/100k", |b_| {
        b_.iter(|| {
            let mut r = 0i32;
            for i in 0..N {
                r = match a[i].cmp(&a[i]) {
                    std::cmp::Ordering::Less => -1,
                    std::cmp::Ordering::Equal => 0,
                    std::cmp::Ordering::Greater => 1,
                };
            }
            black_box(r);
        })
    });
}

criterion_group!(benches, bench_same_text, bench_upper_case, bench_lower_case, bench_compare_str);
criterion_main!(benches);
