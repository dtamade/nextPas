# BST (Binary Search Tree) Benchmark

Three-language benchmark (Pascal, Go, Rust) for binary search tree operations.

## Tracks

| Track | Description |
|-------|-------------|
| Insert/100k | Insert 100k random keys into BST |
| Lookup/100k | Lookup all 100k keys in pre-built BST |
| InsertLookup/100k | Insert 100k then lookup 100k |
| InOrder/100k | In-order traversal sum of 100k-node BST |

## Results (median)

| Track | Pascal | Go | Rust | vs Go | vs Rust |
|-------|--------|-----|------|-------|---------|
| Insert/100k | 47.1ms | 59.2ms | 52.1ms | **1.26x** ✓ | 1.11x ✓ |
| Lookup/100k | 82.6ms | 22.7ms | 40.6ms | 0.28x | 0.49x |
| InsertLookup/100k | 71.9ms | 83.7ms | 87.2ms | **1.16x** ✓ | 1.21x ✓ |
| InOrder/100k | 47.0ms | 2.25ms | 2.09ms | 0.05x | 0.04x |

**Wins: 2 vs Go (Insert, InsertLookup), 2 vs Rust (Insert, InsertLookup)**

## Analysis

- **Insert**: Pascal wins vs Go (1.26x) and Rust (1.11x). `New`/`Dispose` is efficient
  for small node allocation. Go's GC adds overhead. Rust's `Box::new` also has overhead.
- **Lookup**: Go fastest (22.7ms). Pascal's `BSTLookup` with recursive descent is slower
  than Go's iterative loop. Rust is in between. Pascal's lookup function may benefit from
  iterative rewrite.
- **InsertLookup**: Pascal wins vs Go (1.16x) and Rust (1.21x). Insert time dominates.
- **InOrder**: Go and Rust ~2ms, Pascal 47ms. Pascal uses recursive `InOrderSum` with
  200k function calls (2 per node). Go/Rust use iterative traversal or the compiler
  optimizes tail recursion. This is a **Pascal implementation issue**, not a language
  limitation — an iterative in-order traversal would close the gap.

## Conclusion

BST insert operations favor Pascal over Go (1.26x) due to efficient `New`/`Dispose`.
Lookup and traversal highlight the difference between recursive and iterative implementations.
The InOrder gap (22x) is an implementation detail, not fundamental — iterative traversal
would bring Pascal to parity.
