# String Builder Benchmark

Three-language benchmark (Pascal, Go, Rust) for string building operations.

## Tracks

| Track | Description |
|-------|-------------|
| Builder/Append/100k | Append 100k pre-allocated strings + comma via builder |
| Builder/IntAppend/100k | Append 100k integers + comma via builder |
| Concat/100k | Concatenate 100k strings with `+` operator |
| Builder/Large/100k | Build 100k lines with mixed string/int/float |

## Results (median)

| Track | Pascal | Go | Rust | vs Go | vs Rust |
|-------|--------|-----|------|-------|---------|
| Builder/Append/100k | 2.40ms | 2.24ms | 0.44ms | 0.93x | 0.18x |
| Builder/IntAppend/100k | 2.10ms | 10.4ms | 2.70ms | **4.95x** ✓ | **1.29x** ✓ |
| Concat/100k | 8.83ms | 31.4s | 0.53ms | **3557x** ✓ | 0.06x |
| Builder/Large/100k | 16.8ms | 63.4ms | 22.0ms | **3.77x** ✓ | 1.31x ✓ |

**Wins: 3 vs Go (IntAppend, Concat, Large), 2 vs Rust (IntAppend, Large)**

## Analysis

- **Builder/Append**: Pascal and Go tied (~2.3ms). Rust fastest (0.44ms) — `push_str` is memcpy.
  Pascal slightly slower due to `AppendStr` + `AppendChar` two-call overhead.
- **Builder/IntAppend**: Pascal 4.95x faster than Go! `AppendInt` uses direct digit writing.
  Go's `strconv.Itoa` + `WriteString` has allocation overhead per integer.
  Pascal 1.29x faster than Rust (Rust's `write!` macro has formatting overhead).
- **Concat/100k**: Pascal 3557x faster than Go! Go strings are immutable — `+=` creates
  a full copy every time, resulting in O(n²) behavior (31 seconds!).
  Pascal's `S := S + ...` uses reference counting and copy-on-write, much more efficient.
  Rust fastest (0.53ms) — `String` is mutable, `+=` is `push_str` internally.
- **Builder/Large**: Pascal 3.77x faster than Go. Mixed int+float formatting is Go's weakness.
  Pascal `AppendInt`/`AppendFloat` are direct, Go's `strconv.FormatFloat` is slower.

## Conclusion

String building is Pascal's **strongest track vs Go**: 3 wins including the 3557x Concat blowout.
Pascal's `TBufStringBuilder` with direct `AppendInt`/`AppendFloat` avoids Go's allocation overhead.
Rust remains fastest overall due to zero-cost `push_str` and mutable strings.
