RESULTS: packed track
====================

Pascal packed record (26 bytes) vs Go struct (32 bytes, 19% larger)

Pascal:
  PackedCopy/100K:    493717 ns/op
  PackedMove/100K:    264594 ns/op
  PackedUpdate/100K:  224521 ns/op
  PackedFilter/100K:  128614 ns/op
  PackedCompact/100K: 437951 ns/op

Go:
  PackedCopy/100K:    286515 ns/op
  PackedMove/100K:    280343 ns/op
  PackedUpdate/100K:  241720 ns/op
  PackedFilter/100K:  159072 ns/op
  PackedCompact/100K: 276643 ns/op

Result: 3W 2L vs Go
  PackedMove:    1.06x Pascal (ERMSB rep movsb for 2.6MB bulk copy)
  PackedUpdate:  1.08x Pascal (packed record cache efficiency)
  PackedFilter:  1.24x Pascal (26B packed vs 32B struct, better cache line utilization)
  PackedCopy:    0.58x Go wins (FPC 26-byte copy slower than Go 32-byte copy)
  PackedCompact: 0.63x Go wins (copy overhead dominates)

Key insight: Pascal's `packed record` saves 19% memory (26 vs 32 bytes per element),
improving cache utilization for scan/filter workloads. Go has no packed equivalent.
