// bench_arena.rs — Rust 综合竞技场基准
//
// 七个赛道：HashMap / Sort / String / JSON / TOML / Regex
// 使用 criterion 运行: cargo bench
use criterion::{criterion_group, criterion_main, BenchmarkId, Criterion, Throughput};
use std::collections::HashMap;
use std::fmt::Write;

const HASHMAP_N: usize = 100000;
const SORT_N: usize = 10000;
const STRING_N: usize = 10000;
const JSON_N: usize = 1000;
const TOML_N: usize = 500;
const REGEX_N: usize = 1000;

// === 赛道 1: HashMap ===

fn bench_hashmap_insert(c: &mut Criterion) {
    let mut group = c.benchmark_group("HashMap");
    group.throughput(Throughput::Elements(HASHMAP_N as u64));

    group.bench_function("Insert", |b| {
        b.iter(|| {
            let mut m = HashMap::with_capacity(HASHMAP_N);
            for i in 0..HASHMAP_N {
                m.insert((i as u64 * 2654435761) & 0x7FFFFFFF, i);
            }
            m
        })
    });

    group.finish();
}

fn bench_hashmap_lookup(c: &mut Criterion) {
    let mut m = HashMap::with_capacity(HASHMAP_N);
    for i in 0..HASHMAP_N {
        m.insert((i as u64 * 2654435761) & 0x7FFFFFFF, i);
    }
    let keys: Vec<u64> = (0..HASHMAP_N)
        .map(|i| (i as u64 * 2654435761) & 0x7FFFFFFF)
        .collect();

    let mut group = c.benchmark_group("HashMap");
    group.throughput(Throughput::Elements(HASHMAP_N as u64));

    group.bench_function("Lookup", |b| {
        b.iter(|| {
            let mut found = 0usize;
            for key in &keys {
                if m.contains_key(key) {
                    found += 1;
                }
            }
            found
        })
    });

    group.finish();
}

fn bench_hashmap_iterate(c: &mut Criterion) {
    let mut m = HashMap::with_capacity(HASHMAP_N);
    for i in 0..HASHMAP_N {
        m.insert((i as u64 * 2654435761) & 0x7FFFFFFF, i);
    }

    let mut group = c.benchmark_group("HashMap");
    group.throughput(Throughput::Elements(HASHMAP_N as u64));

    group.bench_function("Iterate", |b| {
        b.iter(|| {
            let mut count = 0usize;
            for _ in &m {
                count += 1;
            }
            count
        })
    });

    group.finish();
}

// === 赛道 2: Sort ===

fn bench_sort_int32(c: &mut Criterion) {
    let data: Vec<i32> = (0..SORT_N).map(|i| ((i as i64 * 48271) % 1000000) as i32).collect();

    let mut group = c.benchmark_group("Sort");
    group.throughput(Throughput::Bytes((SORT_N * 4) as u64));

    group.bench_function("Int32", |b| {
        b.iter(|| {
            let mut d = data.clone();
            d.sort_unstable();
            d
        })
    });

    group.finish();
}

// === 赛道 3: String ===

fn bench_string_builder(c: &mut Criterion) {
    let mut group = c.benchmark_group("String");
    group.throughput(Throughput::Bytes((STRING_N * 16) as u64));

    group.bench_function("Builder", |b| {
        b.iter(|| {
            let mut s = String::with_capacity(STRING_N * 16);
            for i in 0..STRING_N {
                s.push_str("item_");
                s.push_str(&i.to_string());
                s.push(',');
            }
            s
        })
    });

    group.finish();
}

fn bench_string_concat(c: &mut Criterion) {
    let mut group = c.benchmark_group("String");
    group.throughput(Throughput::Bytes((STRING_N * 16) as u64));

    group.bench_function("Concat", |b| {
        b.iter(|| {
            let mut result = String::new();
            for i in 0..STRING_N {
                result = result + "item_" + &i.to_string() + ",";
            }
            result
        })
    });

    group.finish();
}

// === 赛道 4: JSON ===

#[derive(serde::Serialize, serde::Deserialize)]
struct User {
    id: usize,
    name: String,
    email: String,
    age: usize,
}

#[derive(serde::Serialize, serde::Deserialize)]
struct Users {
    users: Vec<User>,
}

fn bench_json_parse(c: &mut Criterion) {
    let users = Users {
        users: (0..JSON_N)
            .map(|i| User {
                id: i,
                name: format!("user_{}", i),
                email: format!("user{}@example.com", i),
                age: 20 + (i % 50),
            })
            .collect(),
    };
    let json_str = serde_json::to_string(&users).unwrap();

    let mut group = c.benchmark_group("JSON");
    group.throughput(Throughput::Bytes(json_str.len() as u64));

    group.bench_function("Parse", |b| {
        b.iter(|| {
            let _: Users = serde_json::from_str(&json_str).unwrap();
        })
    });

    group.finish();
}

// === 赛道 5: TOML ===

fn generate_toml_data() -> String {
    let mut s = String::with_capacity(TOML_N * 200);
    s.push_str("[server]\n");
    s.push_str("host = \"0.0.0.0\"\n");
    s.push_str("port = 8080\n");
    s.push_str("workers = 16\n");
    s.push_str("max_connections = 10000\n\n");
    s.push_str("[database]\n");
    s.push_str("driver = \"postgresql\"\n");
    s.push_str("host = \"db.example.com\"\n");
    s.push_str("port = 5432\n");
    s.push_str("pool_size = 20\n\n");

    for i in 0..TOML_N {
        write!(s, "[[services]]\n").unwrap();
        write!(s, "name = \"service_{}\"\n", i).unwrap();
        if i % 2 == 0 {
            s.push_str("enabled = true\n");
        } else {
            s.push_str("enabled = false\n");
        }
        write!(s, "weight = {}\n", i % 100).unwrap();
        write!(s, "timeout = {}\n", 1000.0 + (i as f64) * 10.0 + 0.5).unwrap();
        write!(s, "endpoint = \"https://api.example.com/v1/service_{}\"\n", i).unwrap();
        write!(s, "tags = [\"production\", \"region_{}\", \"tier_backend\"]\n\n", i % 5).unwrap();
    }
    s
}

#[derive(serde::Deserialize)]
struct TomlServer {
    host: String,
    port: u16,
    workers: u32,
    max_connections: u32,
}

#[derive(serde::Deserialize)]
struct TomlDatabase {
    driver: String,
    host: String,
    port: u16,
    pool_size: u32,
}

#[derive(serde::Deserialize)]
struct TomlService {
    name: String,
    enabled: bool,
    weight: u32,
    timeout: f64,
    endpoint: String,
    tags: Vec<String>,
}

#[derive(serde::Deserialize)]
struct TomlConfig {
    server: TomlServer,
    database: TomlDatabase,
    services: Vec<TomlService>,
}

fn bench_toml_parse(c: &mut Criterion) {
    let data = generate_toml_data();

    let mut group = c.benchmark_group("TOML");
    group.throughput(Throughput::Bytes(data.len() as u64));

    group.bench_function("Parse", |b| {
        b.iter(|| {
            let _: TomlConfig = toml::from_str(&data).unwrap();
        })
    });

    group.finish();
}

// === 赛道 6: Regex ===

fn generate_regex_log_lines() -> Vec<String> {
    (0..REGEX_N)
        .map(|i| {
            format!(
                "2026-06-29 14:3{}:2{}.{:03} [info] Request #{} completed in {}ms",
                i % 10,
                i % 6,
                100 + (i * 37) % 900,
                i,
                i % 500
            )
        })
        .collect()
}

fn bench_regex_match(c: &mut Criterion) {
    let re = regex::Regex::new(r"(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}\.\d{3}) \[(\w+)\] (.+)")
        .unwrap();
    let lines = generate_regex_log_lines();

    let mut group = c.benchmark_group("Regex");
    group.throughput(Throughput::Elements(REGEX_N as u64));

    group.bench_function("Match", |b| {
        b.iter(|| {
            let mut matched = 0usize;
            for line in &lines {
                if re.is_match(line) {
                    matched += 1;
                }
            }
            matched
        })
    });

    group.finish();
}

fn bench_regex_simple_match(c: &mut Criterion) {
    let re = regex::Regex::new(r"\d+").unwrap();
    let lines = generate_regex_log_lines();

    let mut group = c.benchmark_group("Regex");
    group.throughput(Throughput::Elements(REGEX_N as u64));

    group.bench_function("SimpleMatch", |b| {
        b.iter(|| {
            let mut matched = 0usize;
            for line in &lines {
                if re.is_match(line) {
                    matched += 1;
                }
            }
            matched
        })
    });

    group.finish();
}

fn bench_regex_findall(c: &mut Criterion) {
    let re = regex::Regex::new(r"(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}\.\d{3}) \[(\w+)\] (.+)")
        .unwrap();
    let lines = generate_regex_log_lines();

    let mut group = c.benchmark_group("Regex");
    group.throughput(Throughput::Elements(REGEX_N as u64));

    group.bench_function("FindAll", |b| {
        b.iter(|| {
            let mut total = 0usize;
            for line in &lines {
                let matches: Vec<_> = re.find_iter(line).collect();
                total += matches.len();
            }
            total
        })
    });

    group.finish();
}

criterion_group!(
    benches,
    bench_hashmap_insert,
    bench_hashmap_lookup,
    bench_hashmap_iterate,
    bench_sort_int32,
    bench_string_builder,
    bench_string_concat,
    bench_json_parse,
    bench_toml_parse,
    bench_regex_match,
    bench_regex_simple_match,
    bench_regex_findall,
);
criterion_main!(benches);
