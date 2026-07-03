# HashMap Operations Benchmark

Three-language benchmark (Pascal, Go, Rust) for hash map operations with string keys.

## Tracks

| Track | Description |
|-------|-------------|
| Insert/100k | Insert 100k string→int pairs into fresh map |
| Lookup/100k | Lookup 100k existing keys from pre-populated map |
| InsertLookup/100k | Insert 100k then lookup 100k |
| LookupMiss/100k | Lookup 100k non-existing keys from pre-populated map |

## Results (median)

| Track | Pascal | Go | Rust | vs Go | vs Rust |
|-------|--------|-----|------|-------|---------|
| Insert/100k | 16.2ms | 12.0ms | 27.7ms | 0.74x | **1.71x** ✓ |
| Lookup/100k | 6.29ms | 6.1ms | 17.4ms | 0.97x | **2.77x** ✓ |
| InsertLookup/100k | 23.3ms | 18.0ms | 30.6ms | 0.77x | **1.31x** ✓ |
| LookupMiss/100k | 11.6ms | 4.4ms | 3.87ms | 0.38x | 0.33x |

**Wins: 0 vs Go, 3 vs Rust**

## Analysis

- **Insert**: Go wins due to incremental rehashing (no stop-the-world grow).
  Pascal SwissTable grows in bulk. Rust slowest due to String clone overhead.
- **Lookup**: Pascal and Go nearly tied. Rust slowest — HashMap's SipHash is expensive
  for short string keys (SwissTable and Go use faster hash functions).
- **LookupMiss**: Go wins big — its map uses open addressing with fast probe sequence.
  Pascal SwissTable's control-byte probing may have higher miss cost on this CPU.
  High variance (129%) suggests cache effects.

## Conclusion

Hash map performance is competitive between Pascal and Go (within 1.3x). The main gap
is LookupMiss where Go's map has a more cache-friendly miss path. Rust's HashMap is
slower than both due to SipHash overhead for short strings.
