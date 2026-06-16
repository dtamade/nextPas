# nextpas.core.collections

`nextpas.core.collections` is an L1 consumer of base memory and range
contracts. Collection views should keep the same defensive arithmetic shape as
`nextpas.core.base` spans: reject invalid ranges without relying on overflowing
addition.

## Span Contracts

`nextpas.core.collections.slice` exposes non-owning read-only span views:

- `TReadOnlySpan<T>.SubSpan(Index, Count)` raises `EOutOfRange` when `Index`
  is past the span or when `Count` would run beyond the remaining elements.
- `TReadOnlySpan2<T>.Count` saturates at `High(SizeUInt)` when the two segment
  counts cannot be represented exactly.
- `TReadOnlySpan2<T>.SubSpan(Index, Count)` uses the saturated total count and
  the same overflow-safe range check before splitting the view across segments.

The span records do not own memory. Tests for overflow use synthetic counts and
do not dereference those artificial ranges.

## Focused Gates

Run these gates after changing span range behavior:

```sh
make -C core/tests/nextpas.core.collections/test_slice_contract clean test
make -C core/tests/nextpas.core.collections/test_contracts clean test
make -C core/tests/nextpas.core.collections/test_error_paths clean test
```

Leak-sensitive runs must report heaptrc `0 unfreed memory blocks`.
