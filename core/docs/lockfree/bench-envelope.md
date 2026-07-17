# Lockfree / Atomic Benchmark Evidence Envelope (H2-4)

> **Status**: normative for any published or archived lockfree/atomic throughput number
> **Date**: 2026-07-17
> **Owner**: atomic-lockfree lane

## Rule

**禁止**无信封的绝对 Mops/ops/s 营销数字。
任何对比、README 摘录、roadmap 性能句、历史 `benchmark-comparison-*.md` 引用，都必须附带本信封字段，或明确标注 **not reproducible / historical only**。

相对排序（同机同构建下 A 快于 B）可以讨论；**绝对值**必须可复现。

---

## Required envelope fields

| Field | Example | Notes |
|-------|---------|-------|
| **date_utc** | `2026-07-17T09:00:00Z` | When the run finished |
| **host** | hostname | Optional but recommended |
| **os** | `Linux 6.x x86_64` | `uname -srm` |
| **cpu** | model name, cores, SMT | `/proc/cpuinfo` summary |
| **governor** | `performance` / `unknown` | If known |
| **compiler** | `fpc 3.3.1` + flags | Include `-O2` etc. |
| **build_id** | git SHA | `git rev-parse HEAD` |
| **binary** | path under `core/build/...` | Not source tree pollution |
| **threads** | producer/consumer counts | Exact scenario |
| **workload** | structure + capacity + op mix | e.g. MPMC cap=1024, 4P4C enqueue/dequeue |
| **warmup** | iterations or ms | Must be non-zero for timed runs |
| **measured** | iterations / duration | What the timer covers |
| **stats** | mean / median / min / max / samples | At least N≥3 samples for any claim |
| **units** | ops/s or ns/op | Never mix without conversion note |
| **command** | exact repro command | Copy-pasteable |

Optional: NUMA node, CPU affinity, background load note.

---

## Repro commands (module convention)

```bash
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
# lockfree microbench
make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree clean build run
# atomic microbench
make -C core/benchmarks/nextpas.core.atomic/bench_atomic clean build run
```

Artifacts must land under `core/build/` (or other ignored paths), never next to `.pas` sources.

Print envelope before numbers — helper script:

```bash
core/docs/lockfree/scripts/print-bench-envelope.sh
```

Or:

```bash
make -C core/benchmarks/nextpas.core.lockfree/bench_lockfree envelope
```

---

## Template (paste into results)

```text
=== nextpas bench envelope (H2-4) ===
date_utc:  ...
os:        ...
cpu:       ...
compiler:  ...
build_id:  ...
binary:    ...
threads:   ...
workload:  ...
warmup:    ...
measured:  ...
stats:     samples=N mean=... median=... min=... max=...
units:     ops/s
command:   ...
=== end envelope ===
<numbers only after this line>
```

---

## Historical comparisons

Files such as `benchmark-comparison-2026-06-16.md` / `benchmark-comparison-2026-07-06.md` are **evidence attachments**.
If they lack a full envelope, treat numbers as **non-authoritative** until re-run under this document.

---

## Non-goals

- CI gate that fails on absolute regression (optional later; not H2-4)
- Claiming superiority over Rust/Go/C++ without same-host envelope + matching workload
- R8 NUMA/TSX benches as default production claims
