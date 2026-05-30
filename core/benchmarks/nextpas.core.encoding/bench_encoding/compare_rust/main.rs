use std::time::Instant;

const DATA_SIZE: usize = 10000;
const ITERS: usize = 1000;

const B64_TABLE: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

fn base64_encode(data: &[u8]) -> String {
    let mut result = String::with_capacity((data.len() + 2) / 3 * 4);
    for chunk in data.chunks(3) {
        let b0 = chunk[0] as u32;
        let b1 = if chunk.len() > 1 { chunk[1] as u32 } else { 0 };
        let b2 = if chunk.len() > 2 { chunk[2] as u32 } else { 0 };
        let triple = (b0 << 16) | (b1 << 8) | b2;
        result.push(B64_TABLE[((triple >> 18) & 0x3F) as usize] as char);
        result.push(B64_TABLE[((triple >> 12) & 0x3F) as usize] as char);
        if chunk.len() > 1 { result.push(B64_TABLE[((triple >> 6) & 0x3F) as usize] as char); } else { result.push('='); }
        if chunk.len() > 2 { result.push(B64_TABLE[(triple & 0x3F) as usize] as char); } else { result.push('='); }
    }
    result
}

fn hex_encode(data: &[u8]) -> String {
    let mut result = String::with_capacity(data.len() * 2);
    for &b in data {
        result.push(char::from_digit((b >> 4) as u32, 16).unwrap());
        result.push(char::from_digit((b & 0xF) as u32, 16).unwrap());
    }
    result
}

fn main() {
    let data: Vec<u8> = (0..DATA_SIZE).map(|i| (i % 256) as u8).collect();
    println!("=== Rust Encoding (naive, no crate) (data={} bytes) ===\n", DATA_SIZE);

    let start = Instant::now();
    let mut sink: usize = 0;
    for _ in 0..ITERS {
        let s = base64_encode(&data);
        sink += s.len();
    }
    println!("  Base64.Encode: {:>10.1} ns/op", start.elapsed().as_nanos() as f64 / ITERS as f64);

    let start = Instant::now();
    for _ in 0..ITERS {
        let s = hex_encode(&data);
        sink += s.len();
    }
    println!("  Hex.Encode:    {:>10.1} ns/op", start.elapsed().as_nanos() as f64 / ITERS as f64);
    std::hint::black_box(sink);
}
