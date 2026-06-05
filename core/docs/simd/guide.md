# SIMD Usage Guide

## Performance Guidelines

### Batch Helper Minimum Useful Size

The `ArrayAddF32`, `ArrayMulF32`, etc. batch helpers incur a fixed overhead
per call (~15-20ns for dispatch table lookup + function pointer call).

Rule of thumb:
- < 64 bytes (16 floats): scalar loop is usually faster
- 64-256 bytes: break-even zone, depends on operation complexity
- > 256 bytes: batch helpers are clearly faster (SIMD throughput dominates)

For very small arrays (< 16 elements), write a direct loop instead.

### vec16 vs Dispatch — When to Use Which

| Scenario | Use | Why |
|----------|-----|-----|
| Process entire buffer (> 64 bytes) | `MemFindByte`, `ToLowerAscii` | One dispatch call, amortized |
| Inner loop, 16 bytes per iteration | `Vec16CmpEq`, `Vec16Ctz` | Zero dispatch overhead |
| Single vector operation | `VecF32x4Add` | Inline, no dispatch |

### StrFindChar vs MemFindByte

- `MemFindByte(p, len, value)`: Explicit length, walks dispatch table, SIMD-accelerated.
  Use for arbitrary byte buffers with known length.
- `StrFindChar` (in simd.utils): Inline helper, assumes null-terminated string.
  Use only for C-style strings. Prefer `MemFindByte` for new code.

## Safety Contracts

### vec16/32/64 Layer — No Nil Checks

All `Vec16*`, `Vec32*`, `Vec64*` functions assume:
- `AData` pointer is non-nil
- At least 16/32/64 bytes are accessible at `AData`
- No alignment requirement (uses unaligned loads)

Passing nil will cause SIGSEGV. This is by design for hot-path performance.
Callers are responsible for pointer validity.

### LoadAligned Functions

`VecF32x4LoadAligned(p)` requires 16-byte alignment. Violation triggers
an Assert in debug builds. In release builds, behavior is undefined
(may crash on some CPUs, silently work on others).

## Semantic Notes

### AndNot(a, b) = (NOT a) AND b

All `AndNot` functions follow Intel's PANDN/VPANDN semantics:
the **first** parameter is inverted, then AND'd with the second.

```pascal
Result := VecI32x4AndNot(a, b);
// Equivalent to: Result[i] := (NOT a[i]) AND b[i]
```

This is counterintuitive — "AndNot" sounds like "a AND (NOT b)" but it's
actually "(NOT a) AND b". The naming matches x86 instruction mnemonics.

### Select vs Blend

- `Select(mask: TMaskN, a, b)`: Scalar bit-mask. Bit=1 selects `a[i]`, bit=0 selects `b[i]`.
  Uniform interface across all widths. May have small overhead on 128/256-bit
  (mask expansion to vector).

- `Blend(mask: TVecXxN, a, b)`: Vector mask. Each lane's MSB selects.
  Zero overhead (maps directly to hardware blend instructions).
  Use when you already have a vector comparison result.
