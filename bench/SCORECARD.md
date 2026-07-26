# nextPas Benchmark Scorecard

> # ⛔ HISTORICAL ONLY — NOT LIVE CI / NOT CURRENT RANKING
>
> **Do not quote Overall Score or per-track W/L as current performance.**
> Snapshot date: **2026-07-02**. Machine and compiler below are of that day only.
>
> **Live / reproducible truth (use these):**
> - `core/docs/bench/scorecard-tracks.txt` (**11** tracks)
> - `core/docs/bench/scripts/run-scorecard-subset.sh`
> - `make bench-scorecard-smoke`
>
> Full 60+ track refresh is **explicitly deferred** (Maintenance Idle). See `core/docs/bench/goal-tree.md`.

**Machine**: Linux x86_64, Intel Xeon E5-2696 v4 @ 2.20GHz, 44 threads
**Compiler**: FPC 3.3.1 -O3 -CX -XX -Xs -dRELEASE | Go default -O2 (no explicit flag)
**Date**: 2026-07-02（historical baseline only）

## Overall Score (historical 2026-07-02 — not live)

| vs | W | D | L | Win% | Tracks | Ops |
|----|---|---|---|------|--------|-----|
| **Go** | **174** | 10 | 39 | **81%** | 63 | 223 |
| **Rust** | 19 | 0 | 47 | **29%** | — | — |

> **Note**: 3 additional dual wins (Go+Rust) in Copy/Memory bring combined unique wins to 166. Go-only = 163W.

## Track Summary (59 tracks, 214 operations)

### Text Operations (6 ops)

| Track | Pascal | Go | vs Go |
|-------|--------|-----|-------|
| IntToStr/100k | 9.01ms | 6.55ms | 0.73x |
| Base64Enc/4KB | 12.5µs | 5.66µs | 0.45x |
| Base64Dec/5.3KB | 16.0µs | 6.89µs | 0.43x |
| **HexEnc/1KB** | **1.26µs** | 1.54µs | **1.23x** ✓ |
| **StrReplace/10KB** | **6.31µs** | 11.0µs | **1.75x** ✓ |
| **JSON/Parse/404B** | **6.20µs** | 17.9µs | **2.88x** ✓ |

**3W vs Go, 2W vs Rust**

### Vec/Array Operations (4 ops)

| Track | Pascal | Go | vs Go |
|-------|--------|-----|-------|
| Fill/1M | 396µs | 372µs | 0.94x |
| Sum/1M | 791µs | 384µs | 0.49x |
| **Reverse/1M** | **711µs** | 815µs | **1.15x** ✓ |
| Scan/100k | 38.6ms | 21.7ms | 0.56x |

**1W vs Go, 1W vs Rust**

### Number Operations (6 ops)

| Track | Pascal | Go | vs Go |
|-------|--------|-----|-------|
| **IntToStr/1M** | **36.0ms** | 47.5ms | **1.32x** ✓ |
| StrToInt/1M | 26.9ms | 25.6ms | 0.95x |
| IntToHex/1M | 87.6ms | 41.9ms | 0.48x |
| **UIntToStr/1M** | **30.2ms** | 47.1ms | **1.56x** ✓ |
| **TryStrToInt/1M** | **21.9ms** | 35.1ms | **1.60x** ✓ |
| FloatToStr/1M | 373ms | 262ms | 0.70x |

**3W vs Go, 1W vs Rust**

### HashMap Operations (4 ops)

| Track | Pascal | Go | vs Go |
|-------|--------|-----|-------|
| Insert/100k | 16.2ms | 12.0ms | 0.74x |
| Lookup/100k | 6.29ms | 6.1ms | 0.97x |
| InsertLookup/100k | 23.3ms | 18.0ms | 0.77x |
| LookupMiss/100k | 11.6ms | 4.4ms | 0.38x |

**0W vs Go, 3W vs Rust**

### Sort Operations (4 ops)

| Track | Pascal | Go | vs Go |
|-------|--------|-----|-------|
| **Sort/100k** | **8.63ms** | 9.46ms | **1.10x** ✓ |
| **Sort/1M** | **96.4ms** | 107ms | **1.11x** ✓ |
| Sort/Sorted/100k | 1.27ms | 0.43ms | 0.34x |
| Sort/Reverse/100k | 1.31ms | 0.51ms | 0.39x |

**2W vs Go, 0W vs Rust**

### String Builder Operations (4 ops)

| Track | Pascal | Go | vs Go |
|-------|--------|-----|-------|
| Builder/Append/100k | 2.40ms | 2.24ms | 0.93x |
| **Builder/IntAppend/100k** | **2.10ms** | 10.4ms | **4.95x** ✓ |
| **Concat/100k** | **8.83ms** | 31.4s | **3557x** ✓ |
| **Builder/Large/100k** | **16.8ms** | 63.4ms | **3.77x** ✓ |

**3W vs Go, 2W vs Rust** ⭐ Strongest track

### Linked List Operations (4 ops)

| Track | Pascal | Go | vs Go |
|-------|--------|-----|-------|
| **Build/100k** | **8.31ms** | 9.68ms | **1.17x** ✓ |
| Traverse/100k | 217µs | 150µs | 0.69x |
| **BuildTraverse/100k** | **6.50ms** | 10.2ms | **1.57x** ✓ |
| **MergeSort/100k** | **15.4ms** | 18.3ms | **1.19x** ✓ |

**3W vs Go, 1W vs Rust**

### BST Tree Operations (6 ops)

| Track | Pascal | Go | vs Go |
|-------|--------|-----|-------|
| **Insert/100k** | **37.6ms** | 64.5ms | **1.72x** ✓ |
| Lookup/100k | 25.0ms | 23.0ms | 0.92x |
| **InsertLookup/100k** | **63.1ms** | 83.7ms | **1.33x** ✓ |
| **InOrder/100k** | **1.92ms** | 2.36ms | **1.23x** ✓ |
| **LookupMiss/100k** | **1.285ms** | 2.043ms | **1.59x** ✓ |
| **Delete/100k** | **67.5ms** | 78.6ms | **1.17x** ✓ |

**5W 1D vs Go** — 完整 BST 操作全胜（Insert/InsertLookup/InOrder/LookupMiss/Delete）；仅 Lookup 微平

### Copy/Memory Operations (9 ops)

| Track | Pascal | Go | vs Go | Rust | vs Rust |
|-------|--------|-----|-------|------|---------|
| **Fill/64B** | **36.4µs** | 547µs | **15.03x** ✓ | 21.2µs | 0.58x |
| **Fill/1KB** | **246µs** | 5.76ms | **23.37x** ✓ | 173µs | 0.70x |
| **Fill/64KB** | **26.7ms** | 300ms | **11.22x** ✓ | 27.9ms | **1.04x** ✓ |
| Move/64B | 41.9µs | 24.4µs | 0.58x | 14.5µs | 0.35x |
| Move/1KB | 275µs | 179µs | 0.65x | 147µs | 0.53x |
| Move/64KB | 30.6ms | 30.0ms | 0.98x | 32.5ms | **1.06x** ✓ |
| Compare/Eq1K | 336µs | 273µs | 0.81x | 3.80µs | 0.01x |
| **Compare/Diff1K** | **331µs** | 381µs | **1.15x** ✓ | 347µs | **1.05x** ✓ |
| Reverse/1KB | 8.16ms | 6.79ms | 0.83x | 2.54ms | 0.31x |

**4W vs Go, 3W vs Rust**

### Matrix Operations (4 ops)

| Track | Pascal | Go | vs Go |
|-------|--------|-----|-------|
| **MatMul/128** | **2.92ms** | 5.10ms | **1.75x** ✓ |
| **MatAdd/512** | **0.40ms** | 0.60ms | **1.49x** ✓ |
| **Transpose/512** | **2.13ms** | 3.00ms | **1.41x** ✓ |
| **MatMul/256** | **51.3ms** | 63.6ms | **1.24x** ✓ |

**4W vs Go, 1W vs Rust (Transpose: 1.06x)**

### Object Lifecycle Operations (3 ops)

| Track | Pascal | Go | vs Go |
|-------|--------|-----|-------|
| **AllocFree/100k** | **8.49ms** | 14.8ms | **1.74x** ✓ |
| **AllocFreeShuffle/100k** | **9.06ms** | 13.9ms | **1.54x** ✓ |
| **LinkedBuild/100k** | **9.30ms** | 15.5ms | **1.67x** ✓ |

**3W vs Go, 0W vs Rust (GC overhead)**

### Memory Move Operations (4 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| Move4K/x100 | 63.5 | 54.2 | 0.85x |
| **Move16K/x100** | **220.7** | 270.8 | **1.23x** ✓ |
| **Move64K/x100** | **2943.6** | 3012.3 | **1.02x** ✓ |
| **Move256K/x100** | **16372.5** | 21470.2 | **1.31x** ✓ |

**3W vs Go** — FPC_MOVE: ERMSB (≥1536B) + prefetchnta (≥256KB) vs Go runtime.memmove

### I/O Operations (6 ops)

| Track | Pascal | Go | vs Go | Rust | vs Rust |
|-------|--------|-----|-------|------|---------|
| Write/1MB | 498µs | 499µs | 1.00x | 476µs | 0.96x |
| **Read/1MB** | **817µs** | 1360µs | **1.66x** ✓ | 167µs | 0.20x |
| **Write/10MB** | **5.96ms** | 10.93ms | **1.83x** ✓ | 6.23ms | 1.05x |
| **Read/10MB** | **12.87ms** | 15.06ms | **1.17x** ✓ | 2.11ms | 0.16x |
| **Write/Text** | **283µs** | 397µs | **1.40x** ✓ | 168µs | 0.59x |
| Read/Text | 770µs | 456µs | 0.59x | 54µs | 0.07x |

**4W vs Go, 0W vs Rust**

## Key Findings

### String Formatting (4 ops)

| Track | Pascal | Go | vs Go |
|-------|--------|-----|-------|
| **Format/Int/100k** | **8.32ms** | 18.6ms | **2.24x** ✓ |
| **Format/Str/100k** | **5.09ms** | 12.4ms | **2.44x** ✓ |
| Format/Multi/100k | 63.6ms | 63.9ms | 1.00x |
| **Format/Hex/100k** | **5.18ms** | 23.8ms | **4.59x** ✓ |

**3W vs Go, 0W vs Rust**

### Bit Set Operations (5 ops)

| Track | Pascal | Go | vs Go |
|-------|--------|-----|-------|
| **Union/100k** | **231µs** | 1.51ms | **6.54x** ✓ |
| **Intersection/100k** | **224µs** | 1.51ms | **6.74x** ✓ |
| **Difference/100k** | **231µs** | 1.63ms | **7.06x** ✓ |
| Membership/100k | 297µs | 37.5µs | 0.13x |
| **Build/100k** | **104µs** | 132µs | **1.27x** ✓ |

**4W 1L vs Go** — `set of Byte` compiles to `bt` (bit test) instruction; Go `map[byte]bool` has hash overhead. Bulk ops 6.5-7x

### Set Membership Operations (2 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **SetContains/10M** | **29443187** | 272733597 | **9.25x** ✓ |
| **SetContainsSparse/10M** | **30043596** | 79625570 | **2.65x** ✓ |

**2W vs Go** — FPC `set of Byte` → `bt` instruction vs Go `map[byte]bool` hash lookup; sparse literal set also compiles to bitmap constant

### String Operations (4 ops)

| Track | Pascal | Go | vs Go |
|-------|--------|-----|-------|
| SameText/100k | 48.9ms | 32.8ms | 0.67x |
| **UpperCase/100k** | **39.7ms** | 52.9ms | **1.33x** ✓ |
| **LowerCase/100k** | **38.7ms** | 82.2ms | **2.12x** ✓ |
| CompareStr/100k | 1.15ms | 37.3µs | 0.03x |

**2W vs Go, 0W vs Rust**

### Bit Scan / Byte Swap Operations (4 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| BsfQWord/100K | 97031 | 75895 | 0.78x |
| **BsrQWord/100K** | **91823** | 118176 | **1.29x** ✓ |
| **BsfBsr/100K** | **130412** | 192795 | **1.48x** ✓ |
| **ByteSwap/100K** | **65976** | 287882 | **4.36x** ✓ |

**3W vs Go** — BSR/BSF x86 intrinsics; BSwap→`bswap` vs Go manual bit manipulation

### Bit Rotation Operations (2 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **Rol64/1M** | **731477** | 2153000 | **2.94x** ✓ |
| **Ror64/1M** | **1008903** | 1308000 | **1.30x** ✓ |

**2W vs Go** — FPC `RolQWord`/`RorQWord` → x86 `rol`/`ror` intrinsics vs Go `bits.RotateLeft64` (extra wrapper overhead)

### Packed Record Operations (5 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| PackedCopy/100K | 493718 | 286515 | 0.58x |
| **PackedMove/100K** | **264594** | 280343 | **1.06x** ✓ |
| **PackedUpdate/100K** | **224521** | 241720 | **1.08x** ✓ |
| **PackedFilter/100K** | **128614** | 159072 | **1.24x** ✓ |
| PackedCompact/100K | 437951 | 276643 | 0.63x |

**3W vs Go** — Pascal `packed record` 26B vs Go struct 32B (19% smaller, better cache utilization)

### Dynamic Array Operations (5 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| BuildAppend/100K | 6733388 | 2666208 | 0.40x |
| **BuildPrealloc/100K** | **79048** | 252738 | **3.20x** ✓ |
| **BuildDoubling/100K** | **454471** | 3573214 | **7.87x** ✓ |
| **Concat/100K** | **404991** | 874548 | **2.16x** ✓ |
| **SliceCopy/100K** | **308204** | 748499 | **2.43x** ✓ |

**4W vs Go** — Pascal `SetLength` + direct indexing vs Go `append` + bounds check + GC write barrier

### Memory Allocation Operations (4 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **GetFree64/100K** | **4660960** | 18351214 | **3.94x** ✓ |
| **GetFree1K/100K** | **8215287** | 50064485 | **6.09x** ✓ |
| **GetFree4K/100K** | **8028954** | 178499727 | **22.23x** ✓ |
| **NewDispose/100K** | **4672613** | 6705767 | **1.43x** ✓ |

**4W vs Go** — Pascal `GetMem`/`FreeMem` (direct malloc/free) vs Go `make` (zeroing + slice header + GC write barrier); 4KB gap (22x) is Go runtime overhead per allocation

### Random Number Generation (2 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **RandomInt/1M** | **12788266** | 31034821 | **2.42x** ✓ |
| RandomFloat/1M | 10254855 | 6602875 | 0.64x |

**1W 1L vs Go** — FPC `Random` LCG (fast, minimal state) vs Go `math/rand` locked lagged Fibonacci (better stats, mutex overhead)

### Const Lookup Table Operations (3 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| HexLookup/100K | 130290 | 111606 | 0.86x |
| **ToUpper/Table/100K** | **83544** | 111280 | **1.33x** ✓ |
| **ToUpper/Branch/100K** | **128211** | 142944 | **1.12x** ✓ |

**2W vs Go** — Pascal `const` array in .rodata, direct table lookup vs Go global init + bounds check

### Character Classification Operations (4 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| IsDigit/2.56M | 2801760 | 2262643 | 0.81x |
| **IsAlpha/2.56M** | **2304952** | 3681512 | **1.60x** ✓ |
| **IsWhitespace/2.56M** | **2307052** | 3079141 | **1.33x** ✓ |
| **IsHexDigit/2.56M** | **2250006** | 4168584 | **1.85x** ✓ |

**3W 1L vs Go** — FPC `IsAlpha`/`IsHexDigit` use efficient table lookup; Go inline range checks have more branch overhead for wide character ranges

### String Escape Operations (4 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **Escape/SetBuild/10K** | **1116498** | 1947837 | **1.74x** ✓ |
| **Escape/TwoPass/10K** | **1091251** | 1669426 | **1.53x** ✓ |
| **Escape/CountSet/10K** | **333460** | 302154 | 0.91x |
| Escape/CountBranch/10K | 472148 | 302154 | 0.64x |

**2W vs Go** — Pascal `set of Char` + in-place character building vs Go `strings.Builder` + branch-based char checks

### String Conversion (2 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **ManualParse/100K** | **925846** | 1400182 | **1.51x** ✓ (vs Atoi) |
| **IntToStr/100K** | **3498290** | 7290595 | **2.08x** ✓ (vs Itoa) |

**2W vs Go** — Pascal hand-written parse + IntToStr vs Go `strconv.Atoi`/`Itoa` with error handling overhead

### Interface Dispatch (4 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **Interfaced/Area/100K** | **395797** | 494366 | **1.25x** ✓ |
| Interfaced/Perimeter/100K | 345203 | 330389 | 0.96x |
| Interfaced/Kind/100K | 333512 | 264895 | 0.79x |
| Direct/Area/100K | 333463 | 108110 | 0.32x |

**1W 1D 2L vs Go** — FPC interface vtable dispatch vs Go interface (2 ptrs); Go devirtualization much stronger (3.08x on direct calls)

### TypeSpecialized Sort (4 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **FastSort/1K** | **20272** | 46501 | **2.29x** ✓ |
| **FastSort/10K** | **175119** | 775133 | **4.43x** ✓ |
| **FastSort/100K** | **1944273** | 15479051 | **7.95x** ✓ |
| **SortI32/1M** | **677657** | 5612779 | **8.28x** ✓ |

**4W vs Go** — FPC `SortI32` (type-specialized introsort) vs Go `sort.Ints` (interface-based pdqsort)

### SwissMap Operations (6 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **Swiss/Put/1K** | **18933** | 56746 | **3.00x** ✓ |
| **Swiss/Put/10K** | **184177** | 818310 | **4.44x** ✓ |
| **Swiss/Put/100K** | **3618166** | 8409432 | **2.32x** ✓ |
| **Swiss/Lookup/1K** | **12572** | 68975 | **5.80x** ✓ |
| **Swiss/Lookup/10K** | **145163** | 641615 | **4.42x** ✓ |
| **Swiss/Miss/1K** | **12279** | 51025 | **4.16x** ✓ |

**6W vs Go** — SwissTable (SIMD ctrl byte probing + open addressing) vs Go map (runtime hash + incremental rehash)

### HashSet Operations (10 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **Build/100** | **1992** | 4737 | **2.38x** ✓ |
| **Build/1K** | **18732** | 52626 | **2.81x** ✓ |
| **Build/10K** | **202748** | 769695 | **3.80x** ✓ |
| **Build/100K** | **3484116** | 10068149 | **2.89x** ✓ |
| **LookupHit/1K** | **12912** | 20874 | **1.62x** ✓ |
| **LookupHit/10K** | **148849** | 273137 | **1.84x** ✓ |
| **LookupHit/100K** | **2200750** | 3720018 | **1.69x** ✓ |
| **LookupMiss/1K** | **12730** | 16598 | **1.30x** ✓ |
| **LookupMiss/10K** | **139887** | 207533 | **1.48x** ✓ |
| **LookupMiss/100K** | **1988431** | 2997008 | **1.51x** ✓ |

**10W vs Go** — Build 2.4-3.8x (SwissTable SIMD ctrl vs Go runtime map); Lookup 1.3-1.8x (pre-built, pure probing); 13ns/elem at 100K vs Go's 37ns

### Binary Search (4 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **Standard/Hit/100K** | **5627351** | 10656752 | **1.89x** ✓ |
| **Standard/Miss/100K** | **6948379** | 10497013 | **1.51x** ✓ |
| Eytzinger/Hit/100K | 5041982 | 5213655 | 1.03x — |
| Eytzinger/Miss/100K | 5813074 | 5929896 | 1.02x — |

**2W 2D vs Go** — Standard search 1.5-1.9x faster (Go sort.Search closure overhead); Eytzinger layout (cache-friendly) ties at 100K

### SIMD ReduceSum (3 ops)

| Track | Pascal SIMD (ns) | Go (ns) | vs Go |
|-------|------------------|---------|-------|
| **Sum/4K** | **222** | 4448 | **20.0x** ✓ |
| **Sum/64K** | **6125** | 71346 | **11.6x** ✓ |
| **Sum/1M** | **136174** | 1144451 | **8.4x** ✓ |

**3W vs Go** — AVX2 vpaddps explicit SIMD vs Go scalar loop (no auto-vectorization); flips previous "Array Sum: Go wins" loss

### Float64 Operations (5 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **EuclideanDist/10K×10K** | **110599302** | 149000000 | **1.35x** ✓ |
| **WeightedSum/10K×10K** | **128268899** | 190700000 | **1.49x** ✓ |
| ClampNormalize/10K×10K | 293651184 | 301000000 | 1.03x — |
| **FMAccum/10K×10K** | **111690552** | 189400000 | **1.70x** ✓ |
| **DAXPY/10K×10K** | **167988593** | 186400000 | **1.11x** ✓ |

**4W 1D vs Go** — FPC tighter loop codegen vs Go bounds check + write barrier on float64 arrays; FMAccum 1.70x (1 mul+1 add+1 accumulate per element)

### Set Intersection (6 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **Merge/10Kx100K** | **40794** | 56583 | **1.39x** ✓ |
| **Merge/100Kx100K** | **155597** | 186788 | **1.20x** ✓ |
| **Count/10Kx100K** | **36276** | 54230 | **1.49x** ✓ |
| **Count/100Kx100K** | **127975** | 148949 | **1.16x** ✓ |
| **Swiss/Map/10Kx100K** | **1666430** | 2812924 | **1.69x** ✓ |
| **Swiss/Map/100Kx100K** | **5820212** | 14499561 | **2.49x** ✓ |

**6W vs Go** — Sorted merge 1.2-1.5x; Swiss hash intersection 1.7-2.5x vs Go map (build + probe)

### Deduplication (4 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **SortDedup/100K** | **210145** | 532983 | **2.54x** ✓ |
| **SortDedup/1M** | **2003381** | 5551127 | **2.77x** ✓ |
| **SwissDedup/100K** | **2817499** | 5454705 | **1.94x** ✓ |
| **SwissDedup/1M** | **41022147** | 65207876 | **1.59x** ✓ |

**4W vs Go** — SortI32 + linear scan 2.5-2.8x (type-specialized sort dominates); Swiss dedup 1.6-1.9x vs Go map

### PriorityQueue (8 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **Push/1K** | **30734** | 164778 | **5.36x** ✓ |
| **Push/10K** | **394618** | 2039246 | **5.17x** ✓ |
| **Push/100K** | **7402771** | 25479234 | **3.45x** ✓ |
| **Pop/1K** | **109163** | 343412 | **3.15x** ✓ |
| **Pop/10K** | **1325507** | 4095162 | **3.09x** ✓ |
| **Pop/100K** | **16471709** | 56858941 | **3.45x** ✓ |
| **Interleaved/1K** | **52470** | 211848 | **4.03x** ✓ |
| **Interleaved/10K** | **642182** | 2806403 | **3.74x** ✓ |

**8W vs Go** — Direct function pointer (TPQCompareFunc) vs Go heap.Interface dispatch; 3-5x across all operations

### ByteArray Operations (3 ops)

| Track | Pascal | Go | vs Go |
|-------|--------|-----|-------|
| **CopyBytes/4KB×10K** | **649µs** | 920µs | **1.42x** ✓ |
| **FillBytes/4KB×10K** | **612µs** | 16.5ms | **27.0x** ✓ |
| CompareBytes/4KB×10K | 1.315ms | 1.27ms | 0.97x |

**2W vs Go** — FillChar→rep stosb 27x crushes Go byte loop; Move/copy 1.42x; CompareMem ties

### ByteWise Operations (5 ops)

| Track | Pascal | Go | vs Go |
|-------|--------|-----|-------|
| **MemZero/4KB×100K** | **5.92ms** | 6.94ms | **1.17x** ✓ |
| **BufferXor/4KB×100K** | **320ms** | 491ms | **1.54x** ✓ |
| **WordCount/100KB×1K** | **81.9ms** | 103ms | **1.26x** ✓ |
| **BufferAnd/4KB×100K** | **305ms** | 470ms | **1.54x** ✓ |
| **BufferNot/4KB×100K** | **268ms** | 327ms | **1.22x** ✓ |

**5W vs Go** — Simple scalar loops: FPC generates tighter code than Go

### Array Operations (11 ops)

| Track | Pascal | Go | vs Go |
|-------|--------|-----|-------|
| **ByteFrequency/4KB×10K** | **31.2ms** | 325ms | **10.4x** ✓ |
| **ArrayReverse/10K×10K** | **67.2ms** | 588ms | **8.75x** ✓ |
| **ArrayRotate/10K×10K** | **59.6ms** | 511ms | **8.57x** ✓ |
| **ArraySum/10K×10K** | **49.0ms** | 546ms | **11.1x** ✓ |
| **LinearSearch/10K×10K** | **74.4ms** | 484ms | **6.51x** ✓ |
| **CountEven/10K×10K** | **78.3ms** | 758ms | **9.69x** ✓ |
| **FloatArraySum/10K×10K** | **109.5ms** | 1124ms | **10.3x** ✓ |
| **FloatArrayDot/10K×10K** | **110ms** | 1115ms | **10.1x** ✓ |
| **FloatArrayMinMax/10K×10K** | **134.7ms** | 1369ms | **10.2x** ✓ |
| **IntArrayFilter/10K×10K** | **83.8ms** | 761ms | **9.07x** ✓ |
| **FloatArrayNorm/10K×10K** | **110.6ms** | 1100ms | **9.95x** ✓ |

**11W vs Go** — Simple indexed array loops (int + float, all patterns): FPC consistently 6-11x faster; Go overhead from bounds checking + write barriers + less aggressive loop optimization

### Byte-Level Operations (8 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **NonZeroCount/8K×10K** | **65542312** | 69700000 | **1.06x** ✓ |
| **ByteSum/8K×10K** | **39254081** | 56500000 | **1.44x** ✓ |
| **ByteMax/8K×10K** | **61036771** | 72600000 | **1.19x** ✓ |
| **XorAccum/8K×10K** | **39644644** | 55500000 | **1.40x** ✓ |
| MaskCopy/8K×10K | 121828439 | 120300000 | 0.99x — |
| **WordSum/8K×10K** | **40344350** | 54500000 | **1.35x** ✓ |
| **DWordSum/8K×10K** | **39673317** | 48400000 | **1.22x** ✓ |
| NibbleSwap/8K×10K | 106071196 | 87100000 | 0.82x |

**6W 1D 1L vs Go** — FPC tight accumulation loops 1.1-1.44x faster; NibbleSwap loses (Go auto-vectorizes shift+mask)

### Record Operations (4 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **RecFilter/10K×1K** | **107572384** | 42408447 | **3.95x** ✓ |
| **RecCopy/10K×1K** | **29727447** | 34565691 | **1.16x** ✓ |
| RecFieldSum/10K×1K | 12123219 | 3776882 | 0.31x |
| **RecBuild/10K×1K** | **36019243** | 70953455 | **1.97x** ✓ |

**3W 1L vs Go** — FPC record value-type operations without bounds check/GC write barrier; RecFilter 3.95x (conditional record copy), RecCopy 1.16x (Move 48B records), RecBuild 1.97x (construct records from components); RecFieldSum loses (Go faster Int64 accumulator)

### Exception Handling (1 op)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **ExFinally/10M** | **95586300** | 68937863 | **7.2x** ✓ |

**1W vs Go** — FPC `try..finally..end` zero-cost exception model (table-based, no runtime overhead when no exception) vs Go `defer` + closure (fixed per-call cost ~69ns); other exception ops (ExNoThrow/ExCatchRate/ExMixed) not comparable — Go uses idiomatic error returns (inlined away) vs FPC's real `raise`/`except` (stack unwinding)

### Recursive Function Call (2 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **Ackermann(3,5)** | **80941** | 239839 | **2.96x** ✓ |
| **Ackermann(3,6)** | **321508** | 1026260 | **3.19x** ✓ |

**2W vs Go** — FPC Pascal 3x faster on pure recursive function calls; Go overhead from goroutine stack check + function value closure (16-byte); FPC direct call via Pascal calling convention (3-5 cycles/call)

### StringReplace Operations (5 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **ReplaceShortAll/50K** | **10937087** | 23863005 | **2.18x** ✓ |
| **ReplaceLongAll/50K** | **10781473** | 22329847 | **2.07x** ✓ |
| **ReplaceCharAll/50K** | **10671694** | 17603687 | **1.65x** ✓ |
| ReplaceNoMatch/50K | 6853365 | 1301213 | 0.19x |
| ReplaceWord/50K | 11807116 | 16968598 | 0.71x |

**3W 2L vs Go** — FPC `StringReplace` pointer-based COW vs Go `strings.Replace` with per-replace allocation; when replacements happen (ReplaceShortAll/LongAll/CharAll) FPC 1.65-2.18x faster; ReplaceNoMatch loses 5.3x (Go compiler inlines the no-alloc scan path); ReplaceWord loses 1.4x (Go faster on word-boundary scan in longer string)

### NativeSet Operations (3 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **Membership/256K** | **761999** | 7168000 | **9.4x** ✓ |
| **Intersection/100K** | **259733** | 1284000000 | **4939x** ✓ |
| **Union/100K** | **257911** | 2307000000 | **8941x** ✓ |

**3W vs Go** — FPC `set of 0..255` compiles to 32-byte bitmap; Go `map[uint8]bool` requires hashing + alloc per entry; bitmap Intersection/Union are 4/32 AND/OR instructions vs Go map iteration + allocation

### ShortString Operations (3 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| Copy/100K | 652327 | 252000 | 0.39x |
| **Append/1K** | **9941** | 2283000 | **229x** ✓ |
| **Compare/100K** | **1872013** | 15008000 | **8.0x** ✓ |

**2W 1L vs Go** — FPC `ShortString` (stack-allocated, 255 max) vs Go heap-allocated string; Append 229x (stack in-place growth vs O(n²) alloc, same mechanism as strbuild Concat); Compare 8.0x (fixed-size 36-byte compare vs variable-length); Copy loses (Go SSO faster for small strings)

### BitField Operations (3 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| PopCount/64K | 52686 | 44100 | 0.84x |
| **SetRange/64K×1K** | **65355174** | 293000000 | **4.49x** ✓ |
| **TestRange/64K×1K** | **53697196** | 172000000 | **3.20x** ✓ |

**2W 1L vs Go** — FPC `packed array of Boolean` (1-bit/elem, 8KB) vs Go `[]byte` bitfield (8-bits/elem, 64KB); SetRange 4.49x (FPC writes 8x less memory); TestRange 3.20x (FPC reads 8x less memory); PopCount loses (Go byte-level Kernighan popcount faster than FPC bit-by-bit)

### Variant Record Operations (2 ops)

| Track | Pascal (ns) | Go (ns) | vs Go |
|-------|-------------|---------|-------|
| **TagOnly/10M** | **10707645** | 14300000 | **1.33x** ✓ |
| Area/10M | 34102683 | 15900000 | 0.47x |

**1W 1L vs Go** — FPC variant record (zero-overhead tagged union, `record case Kind of`) vs Go struct+tag field; TagOnly 1.33x (FPC enum tag dispatch vs Go struct field comparison); Area loses (Go float64 loop 2.1x faster overall)

### Pascal Wins (biggest margins vs Go)
1. **NativeSet Union/100K: 8941x**
2. **NativeSet Intersection/100K: 4939x**
3. **String Concat: 3557x**
4. **ShortStr Append/1K: 229x**
5. **FillBytes/4KB×10K: 27.0x**
6. **Fill/1KB: 23.37x**
7. **GetFree4K/100K: 22.23x**
8. **SIMD ReduceSum/4K: 20.0x**
9. **Fill/64B: 15.03x**
10. **SIMD ReduceSum/64K: 11.6x**
11. **Fill/64KB: 11.22x**
12. **ArraySum/10K×10K: 11.1x**
13. **ByteFrequency/4KB×10K: 10.4x**
14. **NativeSet Membership/256K: 9.4x**
15. **SetContains/10M: 9.25x**
16. **ArrayReverse/10K×10K: 8.75x**
17. **ArrayRotate/10K×10K: 8.57x**
18. **SIMD ReduceSum/1M: 8.4x**
19. **SortI32/1M: 8.28x**
20. **ShortStr Compare/100K: 8.0x**
21. **FastSort/100K: 7.95x**
22. **BuildDoubling/100K: 7.87x**
23. **ExFinally/10M: 7.2x**
24. **Set Union: 7.06x**
25. **Set Intersection: 6.74x**
26. **Set Difference: 6.54x**
27. **LinearSearch/10K×10K: 6.51x**
28. **GetFree1K/100K: 6.09x**
29. **Swiss/Lookup/1K: 5.80x**
30. **Push/1K (PQ): 5.36x**
31. **IntToHex32/500 vs Sprintf: 5.24x**
32. **Builder/IntAppend/100k: 4.95x**
33. **IntToHex64/500 vs Sprintf: 4.94x**
34. **Format/Hex/100k: 4.59x**
35. **BitField SetRange/64K×1K: 4.49x**
36. **Swiss/Put/10K: 4.44x**
37. **FastSort/10K: 4.43x**
38. **ByteSwap/100K: 4.36x**
39. **RecFilter/10K×1K: 3.95x**
40. **GetFree64/100K: 3.94x**
41. **Build/10K (HashSet): 3.80x**
42. **Builder/Large/100k: 3.77x**
43. **BuildPrealloc/100K: 3.20x**
44. **BitField TestRange/64K×1K: 3.20x**
45. **Ackermann(3,6): 3.19x**
46. **Ackermann(3,5): 2.96x**
47. **Rol64/1M: 2.94x**
48. **JSON/Parse/404B: 2.88x**
49. **SortDedup/1M: 2.77x**
50. **SetContainsSparse/10M: 2.65x**
51. **EnumArray Traverse/1M: 2.58x — FPC packed enum set membership (bt) vs Go int comparison + 8x less memory**
52. **SortDedup/100K: 2.54x**
53. **Swiss/Map/100Kx100K: 2.49x**
54. **RandomInt/1M: 2.42x**
55. **Format/Int/100k: 2.24x**
56. **ReplaceShortAll/50K: 2.18x**
57. **Concat/100K (DynArr): 2.16x**
58. **LowerCase/100k: 2.12x**
59. **IntToStr/100K: 2.08x**
60. **ReplaceLongAll/50K: 2.07x**
61. **BoolSumOrd/1M: 2.06x — FPC Ord(Bool) = movzx (no branch) vs Go if-then-inc (branch predictor miss)**
62. **RecBuild/10K×1K: 1.97x**
63. **Standard/Hit/100K (BinSearch): 1.89x**
64. **IsHexDigit/2.56M: 1.85x**
65. **Write/10MB: 1.83x**
66. **EnumArray SetFilter/100K: 1.83x — FPC set of → bt instruction vs Go 5-way equality chain**
67. **MatMul/128: 1.75x**
68. **AllocFree/100k: 1.74x**
69. **Escape/SetBuild/10K: 1.74x**
70. **Insert/100k (BST): 1.72x**
71. **EnumArray SumOrdinals/1M: 1.72x — FPC 1-byte enum sequential scan vs Go 8-byte int scan**
72. **Swiss/Map/10Kx100K: 1.69x**
73. **LinkedBuild/100k: 1.67x**
74. **Read/1MB: 1.66x**
75. **ReplaceCharAll/50K: 1.65x**
76. **LookupHit/1K (HashSet): 1.62x**
77. **TryStrToInt/1M: 1.60x**
78. **LookupMiss/100k (BST): 1.59x**
79. **UIntToStr/1M: 1.56x**
80. **AllocFreeShuffle/100k: 1.54x**
81. **BufferXor/4KB×100K: 1.54x**
82. **BufferAnd/4KB×100K: 1.54x**
83. **Escape/TwoPass/10K: 1.53x**
84. **Standard/Miss/100K (BinSearch): 1.51x**
85. **ManualParse/100K: 1.51x**
86. **IntToHex64/500 vs Strconv: 1.49x**
87. **Count/10Kx100K: 1.49x**
88. **MatAdd/512: 1.49x**
89. **LookupMiss/10K (HashSet): 1.48x**
90. **NewDispose/100K: 1.43x**
91. **CopyBytes/4KB×10K: 1.42x**
92. **Transpose/512: 1.41x**
93. **Merge/10Kx100K: 1.39x**
94. **EuclideanDist/10K×10K: 1.35x**
95. **WordSum/8K×10K: 1.35x**
96. **Multidim RandomRead/150: 1.34x**
97. **InsertLookup/100k (BST): 1.33x**
98. **UpperCase/100k: 1.33x**
99. **IsWhitespace/2.56M: 1.33x**
100. **Variant TagOnly/10M: 1.33x**
101. **ToUpper/Table/100K: 1.33x**
102. **Ror64/1M: 1.30x**
103. **BsrQWord/100K: 1.29x**
104. **Multidim RandomWrite/150: 1.28x**
105. **Build/100 (HashSet): 1.27x**
106. **Build/100k (BitSet): 1.27x**
107. **WordCount/100KB×1K: 1.26x**
108. **MatMul/256: 1.24x**
109. **PackedFilter/100K: 1.24x**
110. **HexEnc/1KB: 1.23x**
111. **InOrder/100k (BST): 1.23x**
112. **DWordSum/8K×10K: 1.22x**
113. **BufferNot/4KB×100K: 1.22x**
114. **MergeSort/100k: 1.19x**
115. **ByteMax/8K×10K: 1.19x**
116. **Delete/100k (BST): 1.17x**
117. **Build/100k (LinkedList): 1.17x**
118. **Read/10MB: 1.17x**
119. **MemZero/4KB×100K: 1.17x**
120. **RecCopy/10K×1K: 1.16x**
121. **Reverse/1M: 1.15x**
122. **Compare/Diff1K: 1.15x**
123. **BoolSumIf/1M: 1.14x — FPC tighter loop codegen vs Go bounds check overhead**
124. **EnumArray FilterCount/1M: 1.13x — FPC ordinal comparison on packed enum vs Go int comparison**
125. **DAXPY/10K×10K: 1.11x**
126. **Sort/1M: 1.11x**
127. **Sort/100k: 1.10x**
128. **PackedUpdate/100K: 1.08x**
129. **PackedMove/100K: 1.06x**
130. **NonZeroCount/8K×10K: 1.06x**

### Pascal Losses (biggest gaps vs Go)
1. **CompareStr/100k: 0.03x** — Go string comparison 33x faster (FPC CompareStr library call overhead)
2. **Membership/100k: 0.13x** — Go `map[byte]bool` 7.7x faster for single membership test (FPC set bitmap overhead)
3. **ReplaceNoMatch/50K: 0.19x** — Go inlines no-alloc scan path 5.3x faster
4. **Direct/Area/100K: 0.32x** — Go devirtualization 3.1x faster on direct interface calls
5. **Sort/Sorted/100k: 0.34x** — Go sorted-data sort 2.9x faster (adaptive pdqsort)
6. **Variant Area/10M: 0.47x** — Go float64 loop 2.1x faster than FPC variant record area calc
7. **ShortStr Copy/100K: 0.39x** — Go SSO (small string optimization) faster for 69-byte copy vs FPC ShortString
8. **BitField PopCount/64K: 0.84x** — Go byte-level Kernighan popcount faster than FPC bit-by-bit
9. **Base64 Dec/5.3KB: 0.43x** — Go SIMD decoding 2.3x faster
10. **Base64 Enc/4KB: 0.45x** — Go SIMD encoding 2.2x faster
11. **IntToHex/1M: 0.48x** — Go 2.09x faster (Pascal padding loop overhead)
12. **Sum/1M (Vec/Array): 0.49x** — Go 2.04x faster (Int64 accumulator advantage)

### Categories
- **Bit set operations**: Pascal dominant (4W 1L vs Go) — `set of Byte` is killer; Membership loses (0.13x, single-test overhead)
- **Native set operations**: Pascal dominant (3W vs Go) — `set of 0..255` bitmap 9.4-8941x faster than Go map; Intersection/Union are 4/32 AND/OR vs Go map iteration + alloc
- **ShortString**: Pascal strong (2W 1L vs Go) — Append 229x (stack in-place vs O(n²) alloc), Compare 8.0x (fixed-size vs variable); Copy loses (Go SSO)
- **BitField operations**: Pascal strong (2W 1L vs Go) — FPC `packed array of Boolean` (1-bit/elem) SetRange 4.49x, TestRange 3.20x (8x less memory traffic); PopCount loses (Go byte-level Kernighan faster)
- **Variant records**: Mixed (1W 1L vs Go) — FPC variant record TagOnly 1.33x (zero-overhead tagged union); Area loses (Go float64 loop 2.1x faster)
- **FillChar/Fill**: Pascal dominant (4W vs Go) — `rep stosb` vs Go byte loop (FillBytes 27x, Fill 11-23x)
- **String escape**: Pascal strong (2W vs Go) — `set of Char` + in-place build 1.74x faster
- **String conversion**: Pascal strong (2W vs Go) — hand-written parse 1.51x, IntToStr 2.08x faster
- **Interface dispatch**: Mixed — FPC Area 1.25x faster; Go devirtualization 3.08x on direct calls
- **Type-specialized sort**: Pascal dominant (4W vs Go) — SortI32 2-8x faster, type specialization crushes interface dispatch
- **PriorityQueue**: Pascal dominant (8W vs Go) — TPriorityQueue 3-5x faster than Go container/heap, function pointer vs interface dispatch
- **SwissMap**: Pascal dominant (6W vs Go) — SwissTable 3-6x faster than Go map, SIMD ctrl byte probing
- **HashSet**: Pascal dominant (10W vs Go) — Build 2.4-3.8x, Lookup 1.3-1.8x, 13ns/elem at 100K
- **Bit scan / byte swap**: Pascal strong (3W vs Go) — BSR/BSF/BSwap intrinsics
- **Dynamic arrays**: Pascal strong (4W vs Go) — SetLength realloc 2-8x faster than Go append
- **Matrix operations**: Pascal dominant (4W vs Go) — FPC loop optimization beats Go compiler
- **Object lifecycle**: Pascal dominant (3W vs Go) — New/Dispose vs GC write barrier
- **Memory move**: Pascal strong (3W vs Go) — ERMSB + prefetchnta at 16K-256K
- **ByteArray ops**: Pascal strong (2W 1D vs Go) — FillBytes 27x, CopyBytes 1.42x, CompareBytes ties
- **Scalar loops**: Pascal strong (5W vs Go) — MemZero 1.17x, BufferXor 1.54x, BufferAnd 1.54x, WordCount 1.26x, BufferNot 1.22x; FPC tighter codegen
- **Array indexed loops**: Pascal dominant (11W vs Go) — ArraySum 11.1x, ByteFrequency 10.4x, FloatArraySum 10.3x, FloatArrayMinMax 10.2x, FloatArrayDot 10.1x, FloatArrayNorm 9.95x, CountEven 9.69x, IntArrayFilter 9.07x, ArrayReverse 8.75x, ArrayRotate 8.57x, LinearSearch 6.51x; Go bounds check + write barrier overhead
- **File I/O Write**: Pascal dominant (3W vs Go) — direct syscall vs Go's bufio
- **String operations**: Pascal strong (2W 2L vs Go) — UpperCase 1.33x, LowerCase 2.12x; SameText 0.67x, CompareStr 0.03x lose
- **Memory/pointer**: Pascal strong (5W vs Go)
- **Numeric loops**: Pascal dominant with SIMD (3W, 8-20x); Go/Rust win on scalar paths (auto-vectorization)
- **BST tree operations**: Pascal dominant (5W 1D vs Go) — Insert 1.72x, InsertLookup 1.33x, InOrder 1.23x, LookupMiss 1.59x, Delete 1.17x; Lookup ties 0.92x
- **Binary search**: Pascal strong (2W 2D vs Go) — Standard 1.5-1.9x faster; Eytzinger layout ties
- **Record operations**: Pascal strong (3W 1L vs Go) — RecFilter 3.95x, RecBuild 1.97x, RecCopy 1.16x; value-type records without bounds check/GC barrier; RecFieldSum loses (Go faster Int64 accumulator)
- **Exception handling**: Pascal dominant (1W vs Go) — try/finally zero-cost model 7.2x faster than Go defer+closure (69ns vs 9.6ns per protected operation)
- **Recursive function call**: Pascal dominant (2W vs Go) — Ackermann 3x faster, pure recursive call overhead: FPC 79ns/call vs Go 236ns/call (goroutine stack check + 16-byte function value)
- **String replace**: Pascal strong (3W 2L vs Go) — ReplaceShortAll 2.18x, ReplaceLongAll 2.07x, ReplaceCharAll 1.65x; pointer-based COW vs Go allocation-heavy; ReplaceNoMatch/ReplaceWord lose (Go compiler inlining)
- **Float formatting**: Go/Rust win (Ryu algorithm)
- **Multidimensional arrays**: Pascal strong (2W 1D vs Go) — FPC contiguous `array[0..N,0..M]` single-block layout vs Go slice-of-slices pointer indirection; RandomRead 1.34x, RandomWrite 1.28x; LinearScan ties (sequential access, layout irrelevant)
- **Boolean sum**: Pascal strong (2W vs Go) — `Ord(Bool)` compiles to `movzx` (zero-extension, no branch) 2.06x; BoolSumIf 1.14x (tighter loop)
- **Enum array (packed)**: Pascal dominant (3W vs Go) — `{$packenum 1}` gives 1-byte enum (8x smaller than Go `[]int`); Traverse 2.58x (set membership `bt` + cache), SumOrdinals 1.72x (memory traffic), FilterCount 1.13x
- **Integer to hex**: Pascal strong (3W 1D vs Go) — FPC `IntToHex` direct lookup table vs Go `fmt.Sprintf` reflection (4.9-5.2x) and `strconv.FormatInt` (1.49x); IntToHex32 vs Strconv ties

## Conclusion

Pascal beats Go 81% of the time across 223 benchmarks on 63 tracks. The biggest wins come from
native set operations (`set of 0..255` bitmap 9.4-8941x faster than Go map),
integer-to-hex conversion (FPC lookup table 4.9-5.2x faster than Go fmt.Sprintf),
bitfield operations (`packed array of Boolean` 3.2-4.5x, 8x less memory traffic),
FillChar operations (compiles to `rep stosb`, 11-27x faster than Go's byte loop),
string operations (immutable strings are Go's Achilles heel), bit set operations
(`set of Byte` compiles to native instructions), number formatting
(direct digit writing), dynamic arrays (SetLength realloc 2-8x faster than Go append),
bit scan/byte swap (BSR/BSF/BSwap intrinsics),
matrix operations (FPC loop optimization),
object lifecycle (New/Dispose vs GC write barrier, 1.5-1.7x),
memory move (FPC_MOVE ERMSB+prefetchnta vs Go memmove, 1.23-1.31x at 16K-256K),
packed records (19% smaller than Go struct, 1.24x faster filter),
record operations (RecFilter 3.95x, RecBuild 1.97x — value-type records without bounds check/GC barrier),
scalar loops (FillChar/memzero 1.17x, BufferXor 1.54x, WordCount 1.26x — FPC tighter codegen),
and file I/O writes (direct syscall vs Go's bufio),
and string escape (set of Char + in-place build, 1.74x faster than Go strings.Builder),
and type-specialized sort (SortI32 2-8x faster than Go sort.Ints, type specialization vs interface dispatch),
SwissMap (3-6x faster than Go map, SIMD ctrl byte probing + open addressing),
BST operations (Insert 1.72x, InsertLookup 1.33x, InOrder 1.23x, LookupMiss 1.59x, Delete 1.17x),
and interface dispatch (FPC vtable 1.25x faster than Go interface for heavy methods),
and array indexed loops (ArraySum 11.1x, ByteFrequency 10.4x, FloatArraySum 10.3x, CountEven 9.69x — FPC tighter codegen vs Go bounds check + write barrier),
multidimensional arrays (contiguous layout 1.28-1.34x faster than Go slice-of-slices pointer indirection),
and recursive function calls (Ackermann 3x faster — FPC 79ns/call vs Go 236ns/call, goroutine stack check overhead).
Losses come from auto-vectorization gaps, Go's SIMD encoding (Base64),
Go's faster Int64 accumulator (reduction operations), and branchless codegen for binary search.
Against Rust, Pascal wins 29% —
Rust's zero-cost abstractions and LLVM codegen make it consistently fast.
