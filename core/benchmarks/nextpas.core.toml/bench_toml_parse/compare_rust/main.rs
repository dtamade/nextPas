use std::time::Instant;
use std::fmt::Write;

const SMALL_TOML: &str = r#"name = "my-app"
version = "1.0.0"
description = "A sample application"
license = "MIT"
authors = ["Alice", "Bob"]
debug = false
port = 8080
timeout = 30.5
created = 2024-01-15T10:30:00Z
tags = ["web", "api", "fast"]
"#;

fn build_medium_toml() -> String {
    let mut s = String::from(r#"[package]
name = "nextpas"
version = "0.1.0"
edition = "2024"

[dependencies]
http = "2.0.0"
json = "1.5.0"
toml = "0.8.0"
crypto = "0.4.0"

[server]
host = "0.0.0.0"
port = 443
workers = 4
max_connections = 10000
timeout_ms = 30000
tls = true

[database]
url = "postgres://localhost:5432/mydb"
pool_size = 20
idle_timeout = 300
ssl_mode = "require"

[logging]
level = "info"
format = "json"
output = "stdout"

"#);
    for i in 1..=20 {
        write!(s, "[[features]]\nname = \"feature-{}\"\nenabled = true\npriority = {}\n\n", i, i).unwrap();
    }
    s
}

fn build_large_toml() -> String {
    let mut s = String::new();
    for i in 1..=100 {
        write!(s, "[section_{}]\nkey_a = \"value_{}_a\"\nkey_b = {}\nkey_c = {}.5\nkey_d = true\nkey_e = [1, 2, 3, 4, 5]\nkey_f = {{x = {}, y = {}}}\n\n",
            i, i, i*100, i, i, i*2).unwrap();
    }
    s
}

fn bench(name: &str, input: &str, iters: u64) {
    let start = Instant::now();
    for _ in 0..iters {
        let _: toml::Value = input.parse().unwrap();
    }
    let elapsed = start.elapsed();
    let ns_per_op = elapsed.as_nanos() as f64 / iters as f64;
    let mb_per_sec = input.len() as f64 / ns_per_op * 1000.0;
    println!("  {:<40} {:>8} iters {:>10.1} ns/op {:>8.1} MB/s", name, iters, ns_per_op, mb_per_sec);
}

fn main() {
    let medium = build_medium_toml();
    let large = build_large_toml();

    println!("=== Rust toml crate benchmark ===");
    println!("Small TOML:  {:>5} bytes", SMALL_TOML.len());
    println!("Medium TOML: {:>5} bytes", medium.len());
    println!("Large TOML:  {:>5} bytes\n", large.len());

    bench("parse/small (10 keys)", SMALL_TOML, 100000);
    bench("parse/medium (~50 keys)", &medium, 20000);
    bench("parse/large (~700 keys)", &large, 2000);
}
