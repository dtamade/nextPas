# Format Benchmark

Three-language benchmark (Pascal, Go, Rust) for string formatting operations.

## Results (median)

| Track | Pascal | Go | Rust | vs Go | vs Rust |
|-------|--------|-----|------|-------|---------|
| **Format/Int/100k** | **8.32ms** | 18.6ms | 3.42ms | **2.24x** ✓ | 0.41x |
| **Format/Str/100k** | **5.09ms** | 12.4ms | 2.19ms | **2.44x** ✓ | 0.43x |
| Format/Multi/100k | 63.6ms | 63.9ms | 23.8ms | 1.00x | 0.37x |
| **Format/Hex/100k** | **5.18ms** | 23.8ms | 4.42ms | **4.59x** ✓ | 0.85x |

**Wins: 3 vs Go (Int, Str, Hex), 0 vs Rust**

## Analysis

- **Format/Int**: Pascal 2.24x faster — `IntToStr` + string concat avoids Go's `fmt.Sprintf`
  reflect overhead. Direct digit writing is very efficient.
- **Format/Str**: Pascal 2.44x faster — simple string concat (`'Name: ' + S`) vs Go's
  `fmt.Sprintf("%s", ...)` which has format parsing overhead.
- **Format/Multi**: Tied (63.6ms vs 63.9ms). Both do 3 string conversions + 2 concats.
  Pascal's FloatToStr matches Go's strconv.FormatFloat.
- **Format/Hex**: Pascal 4.59x faster — `IntToHex` + string concat vs Go's `fmt.Sprintf("%.8X", ...)`
  which parses the format string each time. Using `strconv.FormatInt(_, 16)` would be closer.

## Conclusion

Pascal's direct string concatenation (`+` operator) with `IntToStr`/`IntToHex` is 2-5x faster
than Go's `fmt.Sprintf` for simple formatting. Go's format string parsing overhead is the
main bottleneck. For complex multi-argument formatting, the gap narrows to parity.
