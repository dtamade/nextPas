# Platform Benchmark Report

> Generated: 2026-06-16
> Machine: Linux x86_64, FPC 3.3.1, Go 1.23.5, Rust 1.96.0
> All benchmarks: -O2 optimization, 100k iterations (10k for I/O)

## Summary

| Metric | nextPas | Go | Rust | Winner |
|--------|---------|-----|------|--------|
| Timer min delta | 25 ns | 48 ns | 23 ns | Rust (nextPas 2nd) |
| Mutex lock+unlock | **14.6 ns** | 17.0 ns | 16.3 ns | **nextPas** |
| RwLock read | 29.2 ns | 16.0 ns | 21.3 ns | Go |
| File write 4KB | **3590 ns** | 4174 ns | 3920 ns | **nextPas** |
| File read 4KB | **1595 ns** | 2213 ns | 2020 ns | **nextPas** |
| Futex wake | 576 ns | — | — | (single impl) |

**nextPas wins 3/5 benchmarks**, competitive in all 5.

## Analysis

### Mutex (nextPas wins)
nextPas delegates to `pthread_mutex` which uses a futex-backed CAS fast path
in glibc. Go's `sync.Mutex` has additional runtime overhead (goroutine parking,
sema-based contention handling). Rust's `std::sync::Mutex` wraps pthread on
Linux, so the 1.7ns difference is within measurement noise.

### RwLock (Go wins)
Go's `sync.RWMutex` uses an atomic counter for readers (no syscall in
uncontended read case), making it significantly faster. nextPas and Rust both
delegate to `pthread_rwlock` which has higher overhead. This is a known design
trade-off: Go optimizes for the read-heavy case at the cost of writer fairness.

### File I/O (nextPas wins)
nextPas uses raw POSIX `read`/`write` syscalls directly. Go and Rust add
buffering layers (`bufio`, `BufWriter`) which add overhead in micro-benchmarks
but improve throughput in real workloads. For raw syscall performance, nextPas
has the advantage of zero runtime overhead.

### Timer Resolution (Rust wins, nextPas close second)
All three use `clock_gettime(CLOCK_MONOTONIC)` on Linux. The 2ns difference
between nextPas (25ns) and Rust (23ns) is within noise. Go's 48ns reflects the
additional `time.Now()` overhead (vDSO call + struct conversion).

## Caveats

- All benchmarks are single-threaded uncontended. Contended performance may
  differ significantly due to runtime scheduling differences.
- File I/O benchmarks use raw syscalls. Real applications benefit from
  buffering, which Go and Rust provide out of the box.
- Go's goroutine scheduler provides fairness guarantees that pthread does not.
  Raw ns/op comparisons don't capture the full picture.
- These are micro-benchmarks. Application-level performance depends on the
  full system, not individual primitives.
