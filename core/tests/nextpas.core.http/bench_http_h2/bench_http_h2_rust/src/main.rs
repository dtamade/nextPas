use hpack::{Encoder, Decoder};
use std::time::Instant;

fn main() {
    println!("=== Rust H2 Benchmarks ===");
    println!();

    bench_hpack_encode();
    bench_hpack_decode();
    bench_frame_ops();
    bench_flow_control();
    println!();
    println!("All benchmarks completed.");
}

fn bench_hpack_encode() {
    const ITERATIONS: usize = 50000;
    let headers: Vec<(&[u8], &[u8])> = vec![
        (b":method", b"POST"),
        (b":path", b"/api/v1/users"),
        (b":authority", b"example.com"),
        (b"content-type", b"application/json"),
        (b"content-length", b"42"),
    ];

    let start = Instant::now();
    for _ in 0..ITERATIONS {
        let mut enc = Encoder::new();
        let _buf = enc.encode(headers.iter().copied());
    }
    let elapsed = start.elapsed();
    let avg_ns = elapsed.as_nanos() as u64 / ITERATIONS as u64;
    println!("--- HPACK Encode ---");
    println!("Iterations: {}", ITERATIONS);
    if avg_ns > 0 {
        println!("Total time: {} us", elapsed.as_micros());
        println!("Avg: {} ns/op", avg_ns);
        println!("Ops/sec: {}", (ITERATIONS as u64 * 1_000_000_000) / elapsed.as_nanos() as u64);
    }
}

fn bench_hpack_decode() {
    const ITERATIONS: usize = 50000;
    let headers: Vec<(&[u8], &[u8])> = vec![
        (b":method", b"POST"),
        (b":path", b"/api/v1/users"),
        (b":authority", b"example.com"),
        (b"content-type", b"application/json"),
        (b"content-length", b"42"),
    ];

    // Encode once
    let mut enc = Encoder::new();
    let block = enc.encode(headers.iter().copied());

    let start = Instant::now();
    for _ in 0..ITERATIONS {
        let mut dec = Decoder::new();
        let decoded = dec.decode(&block).unwrap();
        std::hint::black_box(decoded);
    }
    let elapsed = start.elapsed();
    let avg_ns = elapsed.as_nanos() as u64 / ITERATIONS as u64;
    println!("--- HPACK Decode ---");
    println!("Iterations: {}", ITERATIONS);
    println!("Total time: {} us", elapsed.as_micros());
    if avg_ns > 0 {
        println!("Avg: {} ns/op", avg_ns);
        println!("Ops/sec: {}", (ITERATIONS as u64 * 1_000_000_000) / elapsed.as_nanos() as u64);
    }
}

fn bench_frame_ops() {
    const ITERATIONS: usize = 100000;
    let mut payload = vec![0u8; 128];
    for i in 0..payload.len() {
        payload[i] = i as u8;
    }
    let mut frame = vec![0u8; 9 + 128];

    let start = Instant::now();
    for _ in 0..ITERATIONS {
        let len = payload.len() as u32;
        frame[0] = (len >> 16) as u8;
        frame[1] = (len >> 8) as u8;
        frame[2] = len as u8;
        frame[3] = 0;
        frame[4] = 0;
        frame[5] = 0;
        frame[6] = 0;
        frame[7] = 0;
        frame[8] = 1;
        frame[9..9 + 128].copy_from_slice(&payload);
    }
    let elapsed = start.elapsed();
    let avg_ns = elapsed.as_nanos() as u64 / ITERATIONS as u64;
    println!("--- Frame Encode ---");
    println!("Iterations: {}", ITERATIONS);
    println!("Frame size: 128+9 bytes");
    if avg_ns > 0 {
        println!("Avg: {} ns/op", avg_ns);
        println!("Ops/sec: {}", (ITERATIONS as u64 * 1_000_000_000) / elapsed.as_nanos() as u64);
    }

    let start = Instant::now();
    for _ in 0..ITERATIONS {
        let _len: u32 = ((frame[0] as u32) << 16) | ((frame[1] as u32) << 8) | (frame[2] as u32);
        let _frame_type = frame[3];
        let _flags = frame[4];
        let _stream_id = ((frame[5] as u32 & 0x7f) << 24) | ((frame[6] as u32) << 16) | ((frame[7] as u32) << 8) | (frame[8] as u32);
        let _payload = &frame[9..9 + 128];
    }
    let elapsed = start.elapsed();
    let avg_ns = elapsed.as_nanos() as u64 / ITERATIONS as u64;
    println!("--- Frame Decode ---");
    println!("Iterations: {}", ITERATIONS);
    println!("Frame size: 128+9 bytes");
    if avg_ns > 0 {
        println!("Avg: {} ns/op", avg_ns);
        println!("Ops/sec: {}", (ITERATIONS as u64 * 1_000_000_000) / elapsed.as_nanos() as u64);
    }
}

fn bench_flow_control() {
    const ITERATIONS: usize = 100000;
    let mut window: i64 = 65535;
    let mut _reserved: u32 = 0;
    let mut _in_flight: u32 = 0;

    let start = Instant::now();
    for _ in 0..ITERATIONS {
        if window >= 256 { window -= 256; _reserved += 256; }
        if _reserved >= 256 { _reserved -= 256; _in_flight += 256; }
        window += 256;
        if window >= 256 { window -= 256; _in_flight += 256; }
        if _in_flight >= 256 { _in_flight -= 256; window += 256; }
    }
    let elapsed = start.elapsed();
    let total_ops = ITERATIONS * 5;
    let avg_ns = elapsed.as_nanos() as u64 / total_ops as u64;
    println!("--- Flow Control (5 ops/iteration) ---");
    println!("Iterations: {}", ITERATIONS);
    println!("Total flow ops: {}", total_ops);
    if avg_ns > 0 {
        println!("Avg per single op: {} ns", avg_ns);
        println!("Flow ops/sec: {}", (total_ops as u64 * 1_000_000_000) / elapsed.as_nanos() as u64);
    }
}
