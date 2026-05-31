use std::time::{Duration, Instant};

const SAMPLES: usize = 3;
const TARGET_NS: u64 = 50_000_000;

fn bench(name: &str, f: impl Fn()) {
    for _ in 0..3 { f(); }
    let mut iters: u64 = 10;
    loop {
        let start = Instant::now();
        for _ in 0..iters { f(); }
        let elapsed = start.elapsed().as_nanos() as u64;
        if elapsed >= TARGET_NS { break; }
        iters = ((iters as f64) * (TARGET_NS as f64) / (elapsed as f64)).max(10.0) as u64;
        if iters > 1000 { iters = 1000; break; }
    }
    let mut samples = [Duration::ZERO; SAMPLES];
    for s in 0..SAMPLES {
        let start = Instant::now();
        for _ in 0..iters { f(); }
        samples[s] = start.elapsed();
    }
    samples.sort();
    let ns = samples[SAMPLES/2].as_nanos() as f64 / iters as f64;
    let ops = 1_000_000_000.0 / ns;
    println!("  {:40} {:>6} iters {:>12.1} ns/op {:>12.0} ops/s", name, iters, ns, ops);
}

fn parse_empty() {
    // Simulate: create parser, parse empty args
    let _args: Vec<String> = Vec::new();
}

fn parse_flags() {
    // clap-style: parse 5 boolean flags
    let args = vec!["-v", "-d", "-f", "-q", "-r"];
    let mut verbose = false;
    let mut debug = false;
    let mut force = false;
    let mut quiet = false;
    let mut recursive = false;
    for a in &args {
        match *a {
            "-v" => verbose = true,
            "-d" => debug = true,
            "-f" => force = true,
            "-q" => quiet = true,
            "-r" => recursive = true,
            _ => {}
        }
    }
    std::hint::black_box((verbose, debug, force, quiet, recursive));
}

fn parse_mixed() {
    // Simulate compiler-like parse
    let args = vec!["-v", "--output", "main", "-O", "3", "--target=aarch64", "input.pas"];
    let mut verbose = false;
    let mut output = String::from("a.out");
    let mut opt_level: i64 = 2;
    let mut target = String::from("x86_64");
    let mut positionals: Vec<&str> = Vec::new();
    let mut i = 0;
    while i < args.len() {
        match args[i] {
            "-v" => verbose = true,
            "--output" => { i += 1; output = args[i].to_string(); }
            "-O" => { i += 1; opt_level = args[i].parse().unwrap(); }
            s if s.starts_with("--target=") => { target = s[9..].to_string(); }
            s => { positionals.push(s); }
        }
        i += 1;
    }
    std::hint::black_box((verbose, output, opt_level, target, positionals));
}

fn parse_stringlist() {
    let args = vec!["-I", "/a", "-I", "/b", "-I", "/c", "-I", "/d", "-I", "/e",
                    "-I", "/f", "-I", "/g", "-I", "/h", "-I", "/i", "-I", "/j"];
    let mut includes: Vec<&str> = Vec::new();
    let mut i = 0;
    while i < args.len() {
        if args[i] == "-I" {
            i += 1;
            includes.push(args[i]);
        }
        i += 1;
    }
    std::hint::black_box(includes);
}

fn main() {
    println!("=== Rust manual-parse benchmark (baseline, no clap overhead) ===");
    println!();
    bench("ParseEmpty", parse_empty);
    bench("ParseFlags(5)", parse_flags);
    bench("ParseMixed(compiler-like)", parse_mixed);
    bench("ParseStringList(10x-I)", parse_stringlist);
    println!();
    println!("Note: This is raw manual parsing, not clap. clap adds ~2-5x overhead.");
    println!("      nextpas.core.args includes full validation, help gen, and error handling.");
}
