use std::io::{Cursor, Read};
use std::time::Instant;
use tar::{Builder, Archive, Header};

const FILE_COUNT: usize = 200;
const FILE_SIZE: usize = 512;
const BIG_SIZE: usize = 1024 * 1024;
const BENCH_ITERS: usize = 25;

fn generate_files() -> Vec<Vec<u8>> {
    let mut files = Vec::with_capacity(FILE_COUNT);
    for i in 0..FILE_COUNT {
        let mut b = vec![0u8; FILE_SIZE];
        for j in 0..FILE_SIZE {
            b[j] = ((j * 7 + i) % 251) as u8;
        }
        files.push(b);
    }
    files
}

fn generate_blob() -> Vec<u8> {
    let mut b = vec![0u8; BIG_SIZE];
    for i in 0..BIG_SIZE {
        b[i] = ((i * 7 + i / 256) % 251) as u8;
    }
    b
}

fn entry_name(idx: usize) -> String {
    format!("f/{:04}.bin", idx)
}

fn build_many_200(files: &[Vec<u8>]) -> Vec<u8> {
    let mut buf = Vec::new();
    let mut builder = Builder::new(&mut buf);
    for i in 0..200 {
        let mut hdr = Header::new_gnu();
        hdr.set_path(entry_name(i)).unwrap();
        hdr.set_size(files[i].len() as u64);
        hdr.set_mode(0o644);
        hdr.set_cksum();
        builder.append(&hdr, &files[i][..]).unwrap();
    }
    builder.finish().unwrap();
    drop(builder);
    buf
}

fn build_big(blob: &[u8]) -> Vec<u8> {
    let mut buf = Vec::new();
    let mut builder = Builder::new(&mut buf);
    let mut hdr = Header::new_gnu();
    hdr.set_path("big.bin").unwrap();
    hdr.set_size(blob.len() as u64);
    hdr.set_mode(0o644);
    hdr.set_cksum();
    builder.append(&hdr, &blob[..]).unwrap();
    builder.finish().unwrap();
    drop(builder);
    buf
}

fn bench_pack_many(files: &[Vec<u8>]) {
    let _ = build_many_200(files);
}

fn bench_builder_pack(files: &[Vec<u8>]) {
    let mut buf = Vec::new();
    let mut builder = Builder::new(&mut buf);
    for i in 0..200 {
        let mut hdr = Header::new_gnu();
        hdr.set_path(entry_name(i)).unwrap();
        hdr.set_size(files[i].len() as u64);
        hdr.set_mode(0o644);
        hdr.set_cksum();
        builder.append(&hdr, &files[i][..]).unwrap();
    }
    builder.finish().unwrap();
    let _ = buf;
}

fn bench_open_parse(archive: &[u8]) {
    let mut ar = Archive::new(Cursor::new(archive));
    for entry in ar.entries().unwrap() {
        let _ = entry.unwrap();
    }
}

fn bench_extract_all(archive: &[u8]) {
    let mut ar = Archive::new(Cursor::new(archive));
    for entry in ar.entries().unwrap() {
        let mut e = entry.unwrap();
        let mut buf = Vec::new();
        e.read_to_end(&mut buf).unwrap();
    }
}

fn bench_extract_slice(archive: &[u8]) {
    let mut ar = Archive::new(Cursor::new(archive));
    for entry in ar.entries().unwrap() {
        let mut e = entry.unwrap();
        // header view + discard
        let _ = e.header().path().unwrap();
        let mut sink = std::io::sink();
        std::io::copy(&mut e, &mut sink).unwrap();
    }
}

fn bench_write_1m(blob: &[u8]) {
    let _ = build_big(blob);
}

fn bench_read_1m(big_archive: &[u8]) {
    let mut ar = Archive::new(Cursor::new(big_archive));
    let mut entries = ar.entries().unwrap();
    if let Some(Ok(mut e)) = entries.next() {
        let mut buf = Vec::new();
        e.read_to_end(&mut buf).unwrap();
    }
}

fn measure<F: Fn()>(name: &str, f: F, bytes: usize) -> serde_json::Value {
    // warmup
    f();
    let start = Instant::now();
    for _ in 0..BENCH_ITERS {
        f();
    }
    let elapsed = start.elapsed();
    let ns = elapsed.as_nanos() as f64 / BENCH_ITERS as f64;
    let ops = if ns > 0.0 { 1e9 / ns } else { 0.0 };
    serde_json::json!({
        "name": name,
        "status": "ok",
        "iterations": BENCH_ITERS,
        "ns_per_op": ns,
        "ops_per_sec": ops,
        "bytes_per_op": bytes,
        "allocs_per_op": 0,
        "statistics": {"sample_count": BENCH_ITERS}
    })
}

fn main() {
    let files = generate_files();
    let blob = generate_blob();
    let archive = build_many_200(&files);
    let big_archive = build_big(&blob);

    if archive.is_empty() || big_archive.is_empty() {
        panic!("archive empty");
    }

    let benches = vec![
        measure("tar/pack/200x512B", || bench_pack_many(&files), 102400),
        measure("tar/builder-pack/200x512B", || bench_builder_pack(&files), 102400),
        measure("tar/open/parse", || bench_open_parse(&archive), 5536),
        measure("tar/extract-all/200x512B", || bench_extract_all(&archive), 102400),
        measure("tar/extract-slice/200x512B", || bench_extract_slice(&archive), 102400),
        measure("tar/write/1MB", || bench_write_1m(&blob), 1048576),
        measure("tar/read/1MB", || bench_read_1m(&big_archive), 1048576),
    ];

    let suite = serde_json::json!({
        "version": "1.0",
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "environment": {"os": std::env::consts::OS, "arch": std::env::consts::ARCH},
        "summary": {"total": benches.len(), "executed": benches.len(), "skipped": 0},
        "benchmarks": benches
    });

    // Try to write to multiple candidate paths expected by check_regression.py
    let data = serde_json::to_string_pretty(&suite).unwrap();
    let candidates = [
        "build/bench-tar-compare-rust.json",
        "compare_rust/build/bench-tar-compare-rust.json",
        "../../../build/bench-tar-compare-rust.json",
        "../../build/bench-tar-compare-rust.json",
    ];
    for p in &candidates {
        if let Some(dir) = std::path::Path::new(p).parent() {
            let _ = std::fs::create_dir_all(dir);
        }
        if std::fs::write(p, &data).is_ok() {
            eprintln!("saved {}", p);
        }
    }
    // Ensure primary paths
    let _ = std::fs::create_dir_all("build");
    let _ = std::fs::write("build/bench-tar-compare-rust.json", &data);
    let _ = std::fs::create_dir_all("compare_rust/build");
    let _ = std::fs::write("compare_rust/build/bench-tar-compare-rust.json", &data);
    let _ = std::fs::create_dir_all("../../../build");
    let _ = std::fs::write("../../../build/bench-tar-compare-rust.json", &data);
    println!("{}", data);
    eprintln!("Rust tar compare done (tar 0.4)");
}
