use regex::Regex;
use std::time::Instant;

const INPUT_SIZE: usize = 10000;
const ITERS: u64 = 100;

fn main() {
    let mut input = vec![0u8; INPUT_SIZE];
    for i in 0..INPUT_SIZE {
        input[i] = b'a' + (i % 26) as u8;
    }
    // Insert targets
    let target1 = b"hello world 2026-05-31 cat";
    input[5000..5000 + target1.len()].copy_from_slice(target1);
    let target2 = b"item 42 cost 199 qty 7";
    input[2000..2000 + target2.len()].copy_from_slice(target2);
    let target3 = b"id 12345 ref 9876";
    input[8000..8000 + target3.len()].copy_from_slice(target3);
    let s = String::from_utf8(input).unwrap();

    println!("=== Rust regex Benchmark (input={} bytes) ===\n", INPUT_SIZE);

    let mut sink: i64 = 0;

    // Literal IsMatch
    let re = Regex::new("hello").unwrap();
    let start = Instant::now();
    for _ in 0..ITERS {
        if re.is_match(&s) { sink += 1; }
    }
    let ns = start.elapsed().as_nanos() as f64 / ITERS as f64;
    println!("  Literal IsMatch:       {:10.1} ns/op", ns);

    // Digit Find
    let re = Regex::new(r"\d+").unwrap();
    let start = Instant::now();
    for _ in 0..ITERS {
        if let Some(m) = re.find(&s) { sink += m.len() as i64; }
    }
    let ns = start.elapsed().as_nanos() as f64 / ITERS as f64;
    println!("  Digit Find:            {:10.1} ns/op", ns);

    // Alternation
    let re = Regex::new("cat|dog|bird|fish").unwrap();
    let start = Instant::now();
    for _ in 0..ITERS {
        if re.is_match(&s) { sink += 1; }
    }
    let ns = start.elapsed().as_nanos() as f64 / ITERS as f64;
    println!("  Alternation (4 alts):  {:10.1} ns/op", ns);
    // Compile
    let start = Instant::now();
    for _ in 0..1000u64 {
        let _ = Regex::new(r"(\d{4})-(\d{2})-(\d{2})").unwrap();
    }
    let ns = start.elapsed().as_nanos() as f64 / 1000.0;
    println!("  Compile (date):        {:10.1} ns/op", ns);

    // IsFullMatch (^pattern$)
    let re = Regex::new(r"^[a-z]+$").unwrap();
    let start = Instant::now();
    for _ in 0..ITERS {
        if re.is_match(&s) { sink += 1; }
    }
    let ns = start.elapsed().as_nanos() as f64 / ITERS as f64;
    println!("  IsFullMatch (^[a-z]+$):{:10.1} ns/op", ns);

    // Case-insensitive
    let re = Regex::new(r"(?i)hello").unwrap();
    let start = Instant::now();
    for _ in 0..ITERS {
        if re.is_match(&s) { sink += 1; }
    }
    let ns = start.elapsed().as_nanos() as f64 / ITERS as f64;
    println!("  Case-Insensitive (?i): {:10.1} ns/op", ns);

    // Capture groups
    let re = Regex::new(r"(\d{4})-(\d{2})-(\d{2})").unwrap();
    let start = Instant::now();
    for _ in 0..ITERS {
        if let Some(caps) = re.captures(&s) { sink += caps.len() as i64; }
    }
    let ns = start.elapsed().as_nanos() as f64 / ITERS as f64;
    println!("  Capture Groups (date): {:10.1} ns/op", ns);

    // FindAll
    let re = Regex::new(r"\w+").unwrap();
    let start = Instant::now();
    for _ in 0..ITERS {
        let matches: Vec<_> = re.find_iter(&s).collect();
        sink += matches.len() as i64;
    }
    let ns = start.elapsed().as_nanos() as f64 / ITERS as f64;
    println!("  FindAll (\\w+):         {:10.1} ns/op", ns);

    // ReplaceAll
    let re = Regex::new(r"\d+").unwrap();
    let start = Instant::now();
    for _ in 0..ITERS {
        let result = re.replace_all(&s, "NUM");
        sink += result.len() as i64;
    }
    let ns = start.elapsed().as_nanos() as f64 / ITERS as f64;
    println!("  ReplaceAll (\\d+->NUM): {:10.1} ns/op", ns);

    if sink < 0 { print!(""); }
}
