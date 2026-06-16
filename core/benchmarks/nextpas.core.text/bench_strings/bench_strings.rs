use std::hint::black_box;
use std::time::Instant;

const WARMUP_ITERS: usize = 1000;
const MEASURE_ITERS: usize = 100_000;
const TRIM_SAMPLE_COUNT: usize = 100;

struct BenchRow {
    name: &'static str,
    iterations: usize,
    total_ns: u128,
    ns_per_op: f64,
    throughput_mb_s: f64,
}

fn calc_throughput(total_bytes: usize, total_ns: u128) -> f64 {
    if total_bytes == 0 || total_ns == 0 {
        return 0.0;
    }
    let bytes_per_mb = 1024.0 * 1024.0;
    let seconds = total_ns as f64 / 1_000_000_000.0;
    (total_bytes as f64 / bytes_per_mb) / seconds
}

fn run_case<F>(name: &'static str, bytes_per_iteration: usize, mut f: F) -> BenchRow
where
    F: FnMut(),
{
    for _ in 0..WARMUP_ITERS {
        f();
    }

    let start = Instant::now();
    for _ in 0..MEASURE_ITERS {
        f();
    }
    let total_ns = start.elapsed().as_nanos();
    BenchRow {
        name,
        iterations: MEASURE_ITERS,
        total_ns,
        ns_per_op: total_ns as f64 / MEASURE_ITERS as f64,
        throughput_mb_s: calc_throughput(bytes_per_iteration * MEASURE_ITERS, total_ns),
    }
}

fn print_header() {
    println!("操作名 | 迭代次数 | 总耗时(ns) | 单次(ns/op) | 吞吐量(MB/s)");
    println!("--- | ---: | ---: | ---: | ---:");
}

fn print_row(row: &BenchRow) {
    println!(
        "{} | {} | {} | {:.2} | {:.2}",
        row.name, row.iterations, row.total_ns, row.ns_per_op, row.throughput_mb_s
    );
}

fn main() {
    let trim_samples: Vec<String> = (0..TRIM_SAMPLE_COUNT)
        .map(|i| format!("  sample_{:02} alpha beta gamma delta epsilon zeta eta theta iota  ", i))
        .collect();
    let split_sample = [
        "field_00=value_03",
        "field_01=value_10",
        "field_02=value_17",
        "field_03=value_24",
        "field_04=value_31",
        "field_05=value_38",
        "field_06=value_45",
        "field_07=value_52",
        "field_08=value_59",
        "field_09=value_66",
        "field_10=value_73",
        "field_11=value_80",
    ]
    .join(",");
    let split_parts: Vec<&str> = split_sample.split(',').collect();
    let join_parts = vec![
        "Alice", "Bob", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India", "Juliet",
    ];
    let join_separator = " | ";
    let joined = join_parts.join(join_separator);
    let replace_source = "Order status: pending, pending review, pending shipment, pending completion.";
    let replace_old = "pending";
    let replace_new = "ready";
    let contains_source =
        "The Unicode text module handles UTF-8 trimming, splitting, folding, and normalization safely.";
    let contains_needle = "splitting";
    let prefix_source = "nextpas.core.text.unicode.facade";
    let prefix_needle = "nextpas.core.text";
    let suffix_needle = "facade";
    let equal_left = "CAFÉ";
    let equal_right = "café";
    let upper_source = "Straße Ωμέγα café";
    let lower_source = "STRASSE ΩΜΕΓΑ CAFÉ";
    let trim_bytes: usize = trim_samples.iter().map(|s| s.len()).sum();

    print_header();

    let row = run_case("str::trim", trim_bytes, || {
        let mut len_acc = 0usize;
        for sample in &trim_samples {
            len_acc += black_box(sample.as_str()).trim().len();
        }
        black_box(len_acc);
    });
    print_row(&row);

    let row = run_case("str::split+collect", split_sample.len(), || {
        let parts: Vec<&str> = black_box(split_sample.as_str()).split(',').collect();
        black_box(parts.len());
    });
    print_row(&row);

    let row = run_case("slice::join", joined.len(), || {
        let result = black_box(&join_parts).join(black_box(join_separator));
        black_box(result.len());
    });
    print_row(&row);

    let row = run_case("str::replace", replace_source.len(), || {
        let result = black_box(replace_source).replace(black_box(replace_old), black_box(replace_new));
        black_box(result.len());
    });
    print_row(&row);

    let row = run_case("str::contains", contains_source.len(), || {
        black_box(black_box(contains_source).contains(black_box(contains_needle)));
    });
    print_row(&row);

    let row = run_case("str::starts_with", prefix_source.len(), || {
        black_box(black_box(prefix_source).starts_with(black_box(prefix_needle)));
    });
    print_row(&row);

    let row = run_case("str::ends_with", prefix_source.len(), || {
        black_box(black_box(prefix_source).ends_with(black_box(suffix_needle)));
    });
    print_row(&row);

    let row = run_case("unicode lowercase compare", equal_left.len() + equal_right.len(), || {
        let folded_left = black_box(equal_left).to_lowercase();
        let folded_right = black_box(equal_right).to_lowercase();
        black_box(folded_left == folded_right);
    });
    print_row(&row);

    let row = run_case("str::to_uppercase", upper_source.len(), || {
        let result = black_box(upper_source).to_uppercase();
        black_box(result.len());
    });
    print_row(&row);

    let row = run_case("str::to_lowercase", lower_source.len(), || {
        let result = black_box(lower_source).to_lowercase();
        black_box(result.len());
    });
    print_row(&row);

    black_box(split_parts.len());
}
