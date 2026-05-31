# nextPas Crypto/Hash Benchmark Report

**Date:** 2026-06-01
**Platform:** Linux x86_64, AES-NI + PCLMUL available
**Compiler:** FPC (Object Pascal) vs Go 1.25

---

## Hash Performance

| Algorithm | Size | nextPas | Go | Ratio |
|-----------|------|---------|-----|-------|
| SHA-256 | 64 B | 39.6 MB/s | 98.5 MB/s | 0.40x |
| SHA-256 | 1 KB | 186.0 MB/s | 217.3 MB/s | 0.86x |
| SHA-256 | 8 KB | 233.8 MB/s | 247.8 MB/s | 0.94x |
| SHA-256 | 1 MB | 245.9 MB/s | 251.0 MB/s | 0.98x |
| SHA-512 | 1 KB | 136.2 MB/s | 299.5 MB/s | 0.46x |
| SHA-512 | 1 MB | 156.7 MB/s | 363.0 MB/s | 0.43x |
| SHA-1 | 1 KB | 97.5 MB/s | 491.1 MB/s | 0.20x |
| SHA-1 | 1 MB | 111.4 MB/s | 649.4 MB/s | 0.17x |
| MD5 | 1 KB | 133.6 MB/s | 455.7 MB/s | 0.29x |
| MD5 | 1 MB | 156.7 MB/s | 498.1 MB/s | 0.31x |
| HMAC-SHA256 | 64 B | 21.6 MB/s | 15.2 MB/s | **1.42x** |
| HMAC-SHA256 | 1 KB | 148.3 MB/s | 104.4 MB/s | **1.42x** |
| HMAC-SHA256 | 8 KB | 223.5 MB/s | 212.3 MB/s | **1.05x** |
| WyHash | 1 KB | 943.3 MB/s | — | — |
| WyHash | 1 MB | 2713.8 MB/s | — | — |

**Analysis:**
- SHA-256 large messages: near parity (0.98x) — our SHA-NI/AVX2 path is effective
- SHA-256 small messages: slower due to function call overhead (Go inlines aggressively)
- SHA-512/SHA-1/MD5: significantly slower — these lack SIMD acceleration in our implementation
- HMAC: **faster than Go** (1.42x) — our streaming IHasher avoids per-call allocation
- WyHash: 2.7 GB/s — excellent non-crypto hash performance

**Optimization opportunities:**
- SHA-512: needs AVX2 or SHA-NI acceleration (currently pure Pascal)
- SHA-1/MD5: needs x64 assembly (currently pure Pascal)

---

## Crypto Performance

| Operation | nextPas | Go | Ratio |
|-----------|---------|-----|-------|
| AES-128-GCM 1KB | 332.4 MB/s | 567.7 MB/s | 0.59x |
| AES-128-GCM 8KB | 469.8 MB/s | 704.7 MB/s | 0.67x |
| AES-256-GCM 1KB | 267.0 MB/s | 503.4 MB/s | 0.53x |
| AES-256-GCM 8KB | 400.9 MB/s | 660.4 MB/s | 0.61x |
| X25519 ECDH | 5,455 ops/s | 5,550 ops/s | **0.98x** |
| Ed25519 Sign | 2,085 ops/s | 23,638 ops/s | 0.09x |
| Ed25519 Verify | 2,063 ops/s | 9,667 ops/s | 0.21x |
| PBKDF2 i=1000 | 421 ops/s | 1,298 ops/s | 0.32x |
| PBKDF2 i=10000 | 42 ops/s | 135 ops/s | 0.31x |

**Analysis:**
- X25519: **near parity** (0.98x) — our field arithmetic is well-optimized
- AES-GCM: 60-67% of Go — Go uses CLMUL+AES-NI with 8-block parallel; we use 4-block
- Ed25519: significantly slower — Go uses precomputed tables + batch verification tricks
- PBKDF2: 3x slower — dominated by SHA-256 small-message overhead (HMAC inner loop)

**Optimization opportunities:**
- AES-GCM: upgrade to 8-block parallel (would reach ~90% of Go)
- Ed25519: precomputed base point table (would reach ~50% of Go)
- PBKDF2: inline HMAC inner loop to avoid per-iteration overhead

---

## Summary

| Category | Status |
|----------|--------|
| SHA-256 (large) | Near parity with Go (0.98x) |
| HMAC-SHA256 | **Faster than Go** (1.42x) |
| X25519 | Near parity (0.98x) |
| AES-GCM | Good (60-67% of Go) |
| WyHash | Excellent (2.7 GB/s) |
| SHA-512/SHA-1/MD5 | Needs SIMD acceleration |
| Ed25519 | Needs precomputed tables |
