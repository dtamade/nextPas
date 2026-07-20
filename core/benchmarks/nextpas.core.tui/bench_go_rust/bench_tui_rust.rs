// Simplified TUI kernels matching nextpas scorecard / bench methodology.
// NOT a full ratatui/crossterm port.
use std::hint::black_box;
use std::time::Instant;

const W: usize = 200;
const H: usize = 50;
const DIFF_ITERS: usize = 2000;
const PARSE_ITERS: usize = 5_000_000;
const LAYOUT_ITERS: usize = 1_000_000;
const OVERLAY_ITERS: usize = 200_000;
const OV_W: usize = 40;
const OV_H: usize = 12;

#[derive(Clone, Copy)]
struct Cell {
    ch: u8,
}

fn new_grid(fill: u8) -> Vec<Cell> {
    vec![Cell { ch: fill }; W * H]
}

fn diff_count(a: &[Cell], b: &[Cell]) -> usize {
    let mut n = 0;
    for i in 0..a.len() {
        if a[i].ch != b[i].ch {
            n += 1;
        }
    }
    n
}

fn report(name: &str, elapsed: std::time::Duration, ops: usize) {
    let ns = elapsed.as_secs_f64() * 1e9 / ops as f64;
    let ops_s = if ns > 0.0 { 1e9 / ns } else { 0.0 };
    println!("  {:<40} {:>12.1} ns/op  {:>12.0} ops/s", name, ns, ops_s);
}

fn parse_ascii(buf: &[u8]) -> bool {
    !buf.is_empty() && buf[0] >= 32 && buf[0] < 127
}

fn parse_csi_up(buf: &[u8]) -> bool {
    buf.len() >= 3 && buf[0] == 27 && buf[1] == b'[' && buf[2] == b'A'
}

fn layout_vsplit3(total_h: i32) -> (i32, i32, i32) {
    let h0 = 3;
    let h2 = 3;
    let h1 = (total_h - h0 - h2).max(0);
    (h0, h1, h2)
}

fn overlay_merge(base: &[u8], dest: &mut [u8], marks: &[u8], mark_ch: u8) -> usize {
    let mut n = 0;
    for i in 0..base.len() {
        if marks[i] != 0 {
            dest[i] = mark_ch;
            n += 1;
        } else {
            dest[i] = base[i];
        }
    }
    n
}

fn main() {
    println!("=== nextpas.core.tui bench_go_rust (Rust) ===");

    let base = new_grid(b'b');
    let same = new_grid(b'b');
    let mut dirty = new_grid(b'b');
    for i in 0..10 {
        let row = i * 5;
        if row < H {
            for x in 0..5.min(W) {
                dirty[row * W + x].ch = b'D';
            }
        }
    }

    let t0 = Instant::now();
    let mut sink = 0usize;
    for _ in 0..DIFF_ITERS {
        sink = sink.wrapping_add(diff_count(black_box(&base), black_box(&same)));
    }
    black_box(sink);
    report("DiffIdentical 200x50", t0.elapsed(), DIFF_ITERS);

    let t0 = Instant::now();
    sink = 0;
    for _ in 0..DIFF_ITERS {
        sink = sink.wrapping_add(diff_count(black_box(&base), black_box(&dirty)));
    }
    black_box(sink);
    report("DiffDirty10 200x50", t0.elapsed(), DIFF_ITERS);

    let ascii = [b'a'];
    let csi = [27u8, b'[', b'A'];

    let t0 = Instant::now();
    let mut ok = true;
    for _ in 0..PARSE_ITERS {
        ok &= parse_ascii(black_box(&ascii));
    }
    assert!(ok);
    black_box(ok);
    report("ParseAscii", t0.elapsed(), PARSE_ITERS);

    let t0 = Instant::now();
    ok = true;
    for _ in 0..PARSE_ITERS {
        ok &= parse_csi_up(black_box(&csi));
    }
    assert!(ok);
    black_box(ok);
    report("ParseCsiUp", t0.elapsed(), PARSE_ITERS);

    let t0 = Instant::now();
    sink = 0;
    for _ in 0..LAYOUT_ITERS {
        let (a, b, c) = layout_vsplit3(black_box(60));
        sink = sink.wrapping_add((a + b + c) as usize);
    }
    black_box(sink);
    report("LayoutVSplit3", t0.elapsed(), LAYOUT_ITERS);

    let base_ov = vec![b'.'; OV_W * OV_H];
    let mut dest_ov = vec![0u8; OV_W * OV_H];
    let mut marks = vec![0u8; OV_W * OV_H];
    marks[2] = 1;
    marks[3] = 1;

    let t0 = Instant::now();
    sink = 0;
    for _ in 0..OVERLAY_ITERS {
        sink = sink.wrapping_add(overlay_merge(
            black_box(&base_ov),
            black_box(&mut dest_ov),
            black_box(&marks),
            b'O',
        ));
    }
    black_box(sink);
    report("OverlayMerge 40x12", t0.elapsed(), OVERLAY_ITERS);
}
