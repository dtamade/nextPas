# Linked List Benchmark

Three-language benchmark (Pascal, Go, Rust) for pointer-heavy linked list operations.

## Tracks

| Track | Description |
|-------|-------------|
| Build/100k | Build 100k-node linked list |
| Traverse/100k | Traverse 100k-node list, sum values |
| BuildTraverse/100k | Build + traverse combined |
| MergeSort/100k | Merge sort 100k-node linked list |

## Results (median)

| Track | Pascal | Go | Rust | vs Go | vs Rust |
|-------|--------|-----|------|-------|---------|
| Build/100k | 8.31ms | 9.68ms | 4.55ms | **1.17x** ✓ | 0.55x |
| Traverse/100k | 217µs | 150µs | 243µs | 0.69x | **1.12x** ✓ |
| BuildTraverse/100k | 6.50ms | 10.2ms | 5.96ms | **1.57x** ✓ | 0.92x |
| MergeSort/100k | 15.4ms | 18.3ms | N/A | **1.19x** ✓ | N/A |

**Wins: 3 vs Go (Build, BuildTraverse, MergeSort), 1 vs Rust (Traverse)**

## Analysis

- **Build**: Pascal wins vs Go — `New`/`Dispose` is faster than Go's GC-managed allocation.
  Rust fastest (4.55ms) — `Box::new` is a simple malloc with no GC overhead.
- **Traverse**: Go fastest (150µs) — better cache prefetching in Go's runtime.
  Pascal 1.12x faster than Rust (243µs) — both do simple pointer chasing.
- **BuildTraverse**: Pascal 1.57x faster than Go — combined allocation + traversal.
  Rust 1.09x faster than Pascal.
- **MergeSort**: Pascal 1.19x faster than Go — pointer-heavy recursive sort with
  manual memory management. Rust excluded (linked list merge sort is impractical
  with Rust's borrow checker).

## Conclusion

Linked list operations favor Pascal over Go: 3 wins out of 4. The pointer-heavy,
cache-unfriendly nature of linked lists amplifies Go's GC overhead. Rust wins on
Build/BuildTraverse with its zero-overhead `Box` allocation.
