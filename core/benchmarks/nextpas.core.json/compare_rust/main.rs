use std::time::Instant;

const SMALL: &str = r#"{"name":"Alice","age":30,"active":true,"score":3.14}"#;
const MEDIUM: &str = r#"{"users":[{"id":1,"name":"Alice","email":"alice@example.com","age":30},{"id":2,"name":"Bob","email":"bob@example.com","age":25},{"id":3,"name":"Charlie","email":"charlie@example.com","age":35}],"total":3,"page":1,"hasMore":false}"#;

fn bench(name: &str, ops: u64, elapsed_ns: u64) {
    let ns_per_op = elapsed_ns as f64 / ops as f64;
    println!("  {:<45} {:>8.0} ns/op", name, ns_per_op);
}

fn main() {
    println!("=== Rust JSON benchmarks (serde_json + simd-json) ===\n");

    // serde_json parse
    let n = 50000u64;
    let start = Instant::now();
    for _ in 0..n {
        let _: serde_json::Value = serde_json::from_str(SMALL).unwrap();
    }
    bench("serde_json parse (small, 52B)", n, start.elapsed().as_nanos() as u64);

    let start = Instant::now();
    for _ in 0..n {
        let _: serde_json::Value = serde_json::from_str(MEDIUM).unwrap();
    }
    bench("serde_json parse (medium, 250B)", n, start.elapsed().as_nanos() as u64);

    // serde_json stringify
    let val: serde_json::Value = serde_json::from_str(MEDIUM).unwrap();
    let start = Instant::now();
    for _ in 0..n {
        let _ = serde_json::to_string(&val).unwrap();
    }
    bench("serde_json stringify (medium)", n, start.elapsed().as_nanos() as u64);

    // simd-json parse
    let n2 = 50000u64;
    let start = Instant::now();
    for _ in 0..n2 {
        let mut data = SMALL.as_bytes().to_vec();
        let _ = simd_json::to_borrowed_value(&mut data).unwrap();
    }
    bench("simd-json parse (small, 52B)", n2, start.elapsed().as_nanos() as u64);

    let start = Instant::now();
    for _ in 0..n2 {
        let mut data = MEDIUM.as_bytes().to_vec();
        let _ = simd_json::to_borrowed_value(&mut data).unwrap();
    }
    bench("simd-json parse (medium, 250B)", n2, start.elapsed().as_nanos() as u64);

    println!("\nDone.");
}
