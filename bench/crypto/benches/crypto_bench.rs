use criterion::{criterion_group, criterion_main, Criterion, black_box};
use md5::Md5;
use sha2::{Sha256, Sha512};
use digest::{Digest, FixedOutputReset};

const HASH_SMALL_N: usize = 10000;
const HASH_SMALL_SIZE: usize = 1;
const HASH_LARGE_N: usize = 1000;
const HASH_LARGE_SIZE: usize = 1024;

fn make_payload(size: usize) -> Vec<u8> {
    (0..size).map(|i| (i & 0xFF) as u8).collect()
}

fn checksum(data: &[u8]) -> u8 {
    data.iter().fold(0u8, |acc, &b| acc ^ b)
}

// --- MD5 ---

fn bench_md5_small(c: &mut Criterion) {
    let data = vec![0x42u8; HASH_SMALL_SIZE];
    c.bench_function("MD5/small", |b| {
        b.iter(|| {
            let mut dummy = 0u8;
            for _ in 0..HASH_SMALL_N {
                let hash = Md5::digest(black_box(&data));
                dummy ^= checksum(&hash);
            }
            dummy
        })
    });
}

fn bench_md5_large(c: &mut Criterion) {
    let data = make_payload(HASH_LARGE_SIZE);
    c.bench_function("MD5/large", |b| {
        b.iter(|| {
            let mut dummy = 0u8;
            for _ in 0..HASH_LARGE_N {
                let hash = Md5::digest(black_box(&data));
                dummy ^= checksum(&hash);
            }
            dummy
        })
    });
}

// --- SHA-256 ---

fn bench_sha256_small(c: &mut Criterion) {
    let data = vec![0x42u8; HASH_SMALL_SIZE];
    c.bench_function("SHA256/small", |b| {
        b.iter(|| {
            let mut dummy = 0u8;
            for _ in 0..HASH_SMALL_N {
                let hash = Sha256::digest(black_box(&data));
                dummy ^= checksum(&hash);
            }
            dummy
        })
    });
}

fn bench_sha256_large(c: &mut Criterion) {
    let data = make_payload(HASH_LARGE_SIZE);
    c.bench_function("SHA256/large", |b| {
        b.iter(|| {
            let mut dummy = 0u8;
            for _ in 0..HASH_LARGE_N {
                let hash = Sha256::digest(black_box(&data));
                dummy ^= checksum(&hash);
            }
            dummy
        })
    });
}

// --- SHA-512 ---

fn bench_sha512_small(c: &mut Criterion) {
    let data = vec![0x42u8; HASH_SMALL_SIZE];
    c.bench_function("SHA512/small", |b| {
        b.iter(|| {
            let mut dummy = 0u8;
            for _ in 0..HASH_SMALL_N {
                let hash = Sha512::digest(black_box(&data));
                dummy ^= checksum(&hash);
            }
            dummy
        })
    });
}

fn bench_sha512_large(c: &mut Criterion) {
    let data = make_payload(HASH_LARGE_SIZE);
    c.bench_function("SHA512/large", |b| {
        b.iter(|| {
            let mut dummy = 0u8;
            for _ in 0..HASH_LARGE_N {
                let hash = Sha512::digest(black_box(&data));
                dummy ^= checksum(&hash);
            }
            dummy
        })
    });
}

criterion_group!(
    benches,
    bench_md5_small,
    bench_md5_large,
    bench_sha256_small,
    bench_sha256_large,
    bench_sha512_small,
    bench_sha512_large,
);
criterion_main!(benches);
