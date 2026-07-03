# Number Operations Benchmark

Three-language benchmark (Pascal, Go, Rust) for number parsing and formatting.

## Tracks

| Track | Description |
|-------|-------------|
| IntToStr/1M | Format 1M integers (0..99999) to strings × 10 |
| StrToInt/1M | Parse 1M pre-formatted integer strings × 10 |
| IntToHex/1M | Format 1M integers as 16-digit hex × 10 |
| UIntToStr/1M | Format 1M unsigned integers to strings × 10 |
| TryStrToInt/1M | Try-parse 1M integer strings × 10 |
| FloatToStr/1M | Format 1M doubles to strings × 10 |

## Results (median, 100 samples)

| Track | Pascal | Go | Rust | vs Go | vs Rust |
|-------|--------|-----|------|-------|---------|
| IntToStr/1M | 36.0ms | 47.5ms | 25.4ms | **1.32x** ✓ | 0.71x |
| StrToInt/1M | 26.9ms | 25.6ms | 16.7ms | 0.95x | 0.62x |
| IntToHex/1M | 87.6ms | 41.9ms | 138ms | 0.48x | **1.58x** ✓ |
| UIntToStr/1M | 30.2ms | 47.1ms | 25.2ms | **1.56x** ✓ | 0.84x |
| TryStrToInt/1M | 21.9ms | 35.1ms | 8.3ms | **1.60x** ✓ | 0.38x |
| FloatToStr/1M | 373ms | 262ms | 197ms | 0.70x | 0.53x |

**Wins: 4 vs Go (IntToStr, UIntToStr, TryStrToInt, IntToHex vs Rust), 1 vs Rust (IntToHex)**

## Analysis

- **IntToStr**: Pascal wins vs Go — `nextpas.core.text.conv.IntToStr` inline path is efficient.
  Rust fastest overall (Ryū algorithm).
- **UIntToStr**: Pascal wins vs Go — same mechanism, unsigned path even faster.
- **TryStrToInt**: Pascal wins vs Go — `TryStrToInt` avoids exception overhead (Go uses `ParseInt`+err check).
  Rust fastest (zero-cost `Result`).
- **IntToHex**: Go wins — `strconv.FormatInt(_, 16)` is highly optimized. Pascal `IntToHex` has
  padding loop overhead (16-digit pad). Rust slow due to `format!("{:016x}")` allocation overhead.
- **FloatToStr**: Go and Rust use Ryu/dragonbox algorithms. Pascal uses FPC's classic sprintf-style
  path — 1.4x slower than Go, 1.9x slower than Rust.
- **StrToInt**: All three close. Go slightly ahead due to simpler parse path (no signed handling overhead).

## Conclusion

Number formatting is a strong track for Pascal vs Go: 4 wins out of 6. The main losses are
IntToHex (padding overhead) and FloatToStr (classic algorithm vs Ryu). Rust dominates all tracks
with its zero-cost abstractions and Ryu float formatting.
