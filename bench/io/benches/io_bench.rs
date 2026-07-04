use criterion::{criterion_group, criterion_main, Criterion};
use std::fs;
use std::io::Write;

const FILE_1MB: usize = 1024 * 1024;
const FILE_10MB: usize = 10 * 1024 * 1024;

const TEMP_PATH: &str = "/tmp/rust_io_bench.dat";
const TEMP_TEXT_PATH: &str = "/tmp/rust_io_bench.txt";

fn make_data(size: usize) -> Vec<u8> {
    (0..size).map(|i| (i & 0xFF) as u8).collect()
}

fn checksum(data: &[u8]) -> u8 {
    data.iter().fold(0u8, |acc, &b| acc ^ b)
}

fn make_lines() -> String {
    let line = "Hello, World! This is a benchmark line. \n";
    line.repeat(10000)
}

// --- Write 1MB ---

fn bench_write_1mb(c: &mut Criterion) {
    let data = make_data(FILE_1MB);
    c.bench_function("Write/1MB", |b| {
        b.iter(|| {
            fs::write(TEMP_PATH, &data).unwrap();
        })
    });
}

// --- Read 1MB ---

fn bench_read_1mb(c: &mut Criterion) {
    let data = make_data(FILE_1MB);
    fs::write(TEMP_PATH, &data).unwrap();
    c.bench_function("Read/1MB", |b| {
        b.iter(|| {
            let read = fs::read(TEMP_PATH).unwrap();
            checksum(&read)
        })
    });
}

// --- Write 10MB ---

fn bench_write_10mb(c: &mut Criterion) {
    let data = make_data(FILE_10MB);
    c.bench_function("Write/10MB", |b| {
        b.iter(|| {
            fs::write(TEMP_PATH, &data).unwrap();
        })
    });
}

// --- Read 10MB ---

fn bench_read_10mb(c: &mut Criterion) {
    let data = make_data(FILE_10MB);
    fs::write(TEMP_PATH, &data).unwrap();
    c.bench_function("Read/10MB", |b| {
        b.iter(|| {
            let read = fs::read(TEMP_PATH).unwrap();
            checksum(&read)
        })
    });
}

// --- Write Text ---

fn bench_write_text(c: &mut Criterion) {
    let lines = make_lines();
    c.bench_function("Write/Text", |b| {
        b.iter(|| {
            let mut f = fs::File::create(TEMP_TEXT_PATH).unwrap();
            f.write_all(lines.as_bytes()).unwrap();
        })
    });
}

// --- Read Text ---

fn bench_read_text(c: &mut Criterion) {
    let lines = make_lines();
    fs::write(TEMP_TEXT_PATH, lines.as_bytes()).unwrap();
    c.bench_function("Read/Text", |b| {
        b.iter(|| {
            let read = fs::read(TEMP_TEXT_PATH).unwrap();
            read.len()
        })
    });
}

criterion_group!(
    benches,
    bench_write_1mb,
    bench_read_1mb,
    bench_write_10mb,
    bench_read_10mb,
    bench_write_text,
    bench_read_text,
);
criterion_main!(benches);
