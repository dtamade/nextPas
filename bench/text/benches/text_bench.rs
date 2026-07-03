use criterion::{criterion_group, criterion_main, Criterion, Throughput};
use base64::Engine;
use base64::engine::general_purpose::STANDARD as BASE64;

fn bench_inttostr_100k(c: &mut Criterion) {
    let mut group = c.benchmark_group("IntToStr/100k");
    group.throughput(Throughput::Elements(100_000));
    group.bench_function("IntToStr/100k", |b| {
        let ints: Vec<i64> = (0..100_000).collect();
        b.iter(|| {
            let mut results = Vec::with_capacity(100_000);
            for &v in &ints {
                results.push(v.to_string());
            }
            results
        });
    });
    group.finish();
}

fn bench_base64_enc_4k(c: &mut Criterion) {
    let mut group = c.benchmark_group("Base64Enc/4KB");
    group.throughput(Throughput::Bytes(4096));
    let src: Vec<u8> = (0..4096u32).map(|i| (i % 256) as u8).collect();
    group.bench_function("Base64Enc/4KB", |b| {
        b.iter(|| {
            let _ = BASE64.encode(&src);
        });
    });
    group.finish();
}

fn bench_base64_dec_5k(c: &mut Criterion) {
    let mut group = c.benchmark_group("Base64Dec/5.3KB");
    group.throughput(Throughput::Bytes(5464));
    let src: Vec<u8> = (0..4096u32).map(|i| (i % 256) as u8).collect();
    let encoded = BASE64.encode(&src);
    group.bench_function("Base64Dec/5.3KB", |b| {
        b.iter(|| {
            let _ = BASE64.decode(&encoded).unwrap();
        });
    });
    group.finish();
}

fn bench_hex_enc_1k(c: &mut Criterion) {
    let mut group = c.benchmark_group("HexEnc/1KB");
    group.throughput(Throughput::Bytes(1024));
    let src: Vec<u8> = (0..1024u32).map(|i| (i % 256) as u8).collect();
    group.bench_function("HexEnc/1KB", |b| {
        b.iter(|| {
            hex::encode(&src)
        });
    });
    group.finish();
}

fn bench_strreplace_10k(c: &mut Criterion) {
    let mut group = c.benchmark_group("StrReplace/10KB");
    group.throughput(Throughput::Elements(10_000));
    let mut s = "x".repeat(100);
    for _ in 0..100 {
        s += "Hello World! This is a test string for replacement. ";
    }
    group.bench_function("StrReplace/10KB", |b| {
        b.iter(|| {
            let _ = s.replace("Hello", "World");
        });
    });
    group.finish();
}

fn bench_json_parse_404b(c: &mut Criterion) {
    let mut group = c.benchmark_group("JSON/Parse/404B");
    group.throughput(Throughput::Bytes(404));
    let s = r#"{"users":[{"id":1,"name":"Alice","email":"alice@example.com","score":95.5,"active":true},{"id":2,"name":"Bob","email":"bob@example.com","score":87.3,"active":false},{"id":3,"name":"Charlie","email":"charlie@example.com","score":92.1,"active":true},{"id":4,"name":"Diana","email":"diana@example.com","score":88.8,"active":true},{"id":5,"name":"Eve","email":"eve@example.com","score":91.0,"active":false}]}"#;
    group.bench_function("JSON/Parse/404B", |b| {
        b.iter(|| {
            let _: serde_json::Value = serde_json::from_str(s).unwrap();
        });
    });
    group.finish();
}

criterion_group!(
    benches,
    bench_inttostr_100k,
    bench_base64_enc_4k,
    bench_base64_dec_5k,
    bench_hex_enc_1k,
    bench_strreplace_10k,
    bench_json_parse_404b
);
criterion_main!(benches);
