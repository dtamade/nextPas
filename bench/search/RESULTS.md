# Binary Search Benchmark

Three-language benchmark (Pascal, Go, Rust) for binary search on sorted Int64 arrays.

## Results (median)

| Track | Pascal | Go | Rust | vs Go | vs Rust |
|-------|--------|-----|------|-------|---------|
| BinarySearch/100k | 18.3ms | 14.9ms | 6.65ms | 0.81x | 0.36x |
| BinarySearchHit/100k | 8.92ms | 6.39ms | 2.92ms | 0.72x | 0.33x |

**Wins: 0 vs Go, 0 vs Rust**

## Analysis

Binary search is branch-prediction-unfriendly — the comparison result is essentially
random for random queries. Rust's `binary_search` uses branchless comparison (conditional
moves) which is 2-3x faster. Go's compiler also generates better branchless code than FPC.

Pascal's hand-written binary search uses standard `if/else` branches, which the CPU
branch predictor can't handle well for random access patterns.
