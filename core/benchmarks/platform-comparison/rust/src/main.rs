use std::path::Path;
use std::time::Instant;
use std::fs;
use std::hint::black_box;

const PATH_ITERS: u64 = 500_000;
const FS_ITERS: u64 = 200_000;
const MMAP_ITERS: u64 = 10_000;
const RAND_ITERS: u64 = 200_000;
const WARMUP: u64 = 1_000;

fn emit(op: &str, imp: &str, iters: u64, ns_per_op: u64) {
    println!("{}\t{}\t{}\t{}", op, imp, iters, ns_per_op);
}

fn bench_path_join() {
    for _ in 0..WARMUP {
        black_box(Path::new("/home/user/projects").join("nextpas/core/src/file.pas"));
    }
    let t0 = Instant::now();
    for _ in 0..PATH_ITERS {
        black_box(Path::new("/home/user/projects").join("nextpas/core/src/file.pas"));
    }
    let elapsed = t0.elapsed().as_nanos() as u64;
    emit("path_join", "rust", PATH_ITERS, elapsed / PATH_ITERS);
}

fn bench_path_basename() {
    for _ in 0..WARMUP {
        black_box(Path::new("/home/user/projects/nextpas/core/src/file.pas").file_name());
    }
    let t0 = Instant::now();
    for _ in 0..PATH_ITERS {
        black_box(Path::new("/home/user/projects/nextpas/core/src/file.pas").file_name());
    }
    let elapsed = t0.elapsed().as_nanos() as u64;
    emit("path_basename", "rust", PATH_ITERS, elapsed / PATH_ITERS);
}

fn bench_file_exists() {
    let path = "/tmp/bench_exists_test.txt";
    for _ in 0..WARMUP {
        black_box(Path::new(path).exists());
    }
    let t0 = Instant::now();
    for _ in 0..FS_ITERS {
        black_box(Path::new(path).exists());
    }
    let elapsed = t0.elapsed().as_nanos() as u64;
    emit("file_exists", "rust", FS_ITERS, elapsed / FS_ITERS);
}

fn bench_mmap() {
    let path = "/tmp/bench_mmap_1mb.dat";
    for _ in 0..WARMUP {
        let file = fs::File::open(path).unwrap();
        let mmap = unsafe { memmap2::MmapOptions::new().map(&file).unwrap() };
        black_box(&mmap[0]);
        drop(mmap);
        drop(file);
    }
    let t0 = Instant::now();
    for _ in 0..MMAP_ITERS {
        let file = fs::File::open(path).unwrap();
        let mmap = unsafe { memmap2::MmapOptions::new().map(&file).unwrap() };
        black_box(&mmap[0]);
        drop(mmap);
        drop(file);
    }
    let elapsed = t0.elapsed().as_nanos() as u64;
    emit("mmap_open_close", "rust", MMAP_ITERS, elapsed / MMAP_ITERS);
}

fn bench_random_32() {
    let mut buf = [0u8; 32];
    for _ in 0..WARMUP {
        getrandom::getrandom(&mut buf).unwrap();
    }
    let t0 = Instant::now();
    for _ in 0..RAND_ITERS {
        getrandom::getrandom(&mut buf).unwrap();
    }
    let elapsed = t0.elapsed().as_nanos() as u64;
    emit("random_32B", "rust", RAND_ITERS, elapsed / RAND_ITERS);
}

fn main() {
    println!("operation\timpl\titerations\tns_per_op");
    bench_path_join();
    bench_path_basename();
    bench_file_exists();
    bench_mmap();
    bench_random_32();
}
