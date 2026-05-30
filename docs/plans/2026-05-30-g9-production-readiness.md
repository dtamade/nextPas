# G9 Production Readiness — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Bring nextpas.core.crypto + nextpas.core.tls to production quality — every public API tested, zero leaks, framework-consistent interfaces, performance-optimized with SIMD where applicable, benchmarked against Go/Rust/FPC RTL.

**Architecture:**
- Extract shared GF(2^255-19) field arithmetic into `nextpas.core.crypto.field25519` (used by both X25519 and Ed25519)
- Rewrite X25519 Montgomery ladder on 10-limb representation (5x speedup)
- Add comprehensive tests for all untested modules (ChaCha20-Poly1305, constant_time, PKCS8, TLS12Record, Argon2, AEAD)
- Benchmark suite with Go/Rust/FPC RTL comparisons

**Tech Stack:** FPC 3.3.1, x86_64 ASM (AES-NI/PCLMULQDQ/AVX2/BMI2), heaptrc, RFC test vectors

---

## Priority Order (by impact)

| # | Task | Impact | Risk | Est. |
|---|------|--------|------|------|
| 1 | ChaCha20-Poly1305 RFC 8439 tests | HIGH (TLS 1.3 2nd cipher) | LOW | 30min |
| 2 | Extract field25519 + rewrite X25519 | HIGH (5x perf) | MED | 2h |
| 3 | constant_time module tests | HIGH (security) | LOW | 20min |
| 4 | TLS 1.3 AEAD dispatch tests | HIGH (record layer) | LOW | 20min |
| 5 | PKCS8 key parsing tests | MED (cert loading) | LOW | 30min |
| 6 | TLS 1.2 Record crypto tests | MED (compat) | LOW | 30min |
| 7 | Argon2 tests | LOW (KDF) | LOW | 20min |
| 8 | API consistency review + Try* wrappers | MED (framework) | LOW | 1h |
| 9 | Comprehensive benchmark suite | MED (metrics) | LOW | 1h |

---

## Task 1: ChaCha20-Poly1305 RFC 8439 Vector Tests

**Files:**
- Test: `tests/nextpas.core.crypto/test_chacha20poly1305/test_chacha20poly1305.lpr`
- Source: `src/nextpas.core.tls.tls13.chacha20poly1305.pas` (existing, 474 lines)

**Vectors (RFC 8439):**
- Section 2.4.2: ChaCha20 encryption test vector
- Section 2.5.2: Poly1305 MAC test vector
- Section 2.8.2: AEAD encrypt test vector
- Section 2.8.2: AEAD decrypt test vector
- Tampered ciphertext rejection
- Tampered AAD rejection
- Combined encrypt/decrypt roundtrip

**Compile:** `fpc -O3 -Mobjfpc -Fusrc -Fu../core/src -I../core/src -gh -FE<dir> <test>.lpr`
**Gate:** All pass + heaptrc 0 unfreed

---

## Task 2: Extract field25519 + Rewrite X25519

**Files:**
- Create: `src/nextpas.core.crypto.field25519.pas` (shared field arithmetic)
- Modify: `src/nextpas.core.crypto.x25519.pas` (rewrite on 10-limb)
- Modify: `src/nextpas.core.crypto.ed25519.pas` (use shared field25519)
- Test: existing `tests/nextpas.core.crypto/test_x25519/` (must still pass)
- Test: existing `tests/nextpas.core.crypto/test_ed25519/` (must still pass)

**Design:**
```
nextpas.core.crypto.field25519:
  type TFe25519 = array[0..9] of Int64;
  procedure FeMul(out H: TFe25519; const F, G: TFe25519);
  procedure FeSq(out H: TFe25519; const F, G: TFe25519);
  procedure FeAdd(out H: TFe25519; const F, G: TFe25519);
  procedure FeSub(out H: TFe25519; const F, G: TFe25519);
  procedure FeInvert(out O: TFe25519; const Z: TFe25519);
  procedure FeFromBytes(out H: TFe25519; const S: TBytes; AOffset: Integer);
  procedure FeToBytes(out S: TBytes; const H: TFe25519);
  ...
```

X25519 Montgomery ladder rewritten using TFe25519 (10-limb).
Expected: 1500us → ~300us per ScalarMult.

**Gate:** X25519 6/6 tests pass + Ed25519 13/13 tests pass + heaptrc 0

---

## Task 3: constant_time Module Tests

**Files:**
- Test: `tests/nextpas.core.crypto/test_constant_time/test_constant_time.lpr`
- Source: `src/nextpas.core.crypto.constant_time.pas` (231 lines)

**Tests:**
- CompareBytes: equal → 1, different → 0
- CompareBytes: timing-independent (no early exit)
- Select: conditional swap
- Zero check

---

## Task 4: TLS 1.3 AEAD Dispatch Tests

**Files:**
- Test: `tests/nextpas.core.tls/test_tls13_aead/test_tls13_aead.lpr`
- Source: `src/nextpas.core.tls.tls13.aead.pas` (260 lines)

**Tests:**
- AES-128-GCM encrypt/decrypt via AEAD dispatch
- AES-256-GCM encrypt/decrypt via AEAD dispatch
- ChaCha20-Poly1305 encrypt/decrypt via AEAD dispatch
- Unsupported cipher suite rejection
- Tag length queries

---

## Task 5: PKCS8 Key Parsing Tests

**Files:**
- Test: `tests/nextpas.core.crypto/test_pkcs8/test_pkcs8.lpr`
- Source: `src/nextpas.core.crypto.pkcs8.pas` (509 lines)

**Tests:**
- Parse Ed25519 private key (DER)
- Parse ECDSA P-256 private key (DER)
- Parse RSA private key (DER)
- Invalid format rejection
- Key type detection

---

## Task 6: TLS 1.2 Record Crypto Tests

**Files:**
- Test: `tests/nextpas.core.crypto/test_tls12record/test_tls12record.lpr`
- Source: `src/nextpas.core.crypto.tls12record.pas` (324 lines)

**Tests:**
- MAC computation (HMAC-SHA256)
- Record encryption (AES-CBC + HMAC)
- Record decryption + MAC verify
- Padding validation
- Tampered record rejection

---

## Task 7: Argon2 Tests

**Files:**
- Test: `tests/nextpas.core.crypto/test_argon2/test_argon2.lpr`
- Source: `src/nextpas.core.crypto.argon2.pas` (141 lines)

**Tests:**
- Argon2id known-answer vector (RFC 9106)
- Output length validation
- Parameter validation (memory, iterations)

---

## Task 8: API Consistency Review

For modules that use bare functions (not Try* pattern), add Try* wrappers where appropriate:
- `nextpas.core.crypto.aesgcm` — already has Boolean returns, acceptable
- `nextpas.core.crypto.x25519` — uses exceptions, should add Try* variants
- `nextpas.core.crypto.ed25519` — mixed, needs review

**Principle:** Public API should use `Try*` for fallible operations. Internal helpers can use exceptions.

---

## Task 9: Comprehensive Benchmark Suite

**Files:**
- `benchmarks/nextpas.core.crypto/bench_all.lpr` — unified crypto benchmark
- `benchmarks/nextpas.core.crypto/compare_go/` — Go comparison
- `benchmarks/nextpas.core.crypto/compare_rust/` — Rust comparison

**Metrics:**
- SHA-256: MB/s (vs Go crypto/sha256, vs Rust sha2 crate)
- AES-128-GCM: MB/s (vs Go crypto/aes, vs Rust aes-gcm)
- X25519: us/op (vs Go crypto/ecdh, vs Rust x25519-dalek)
- Ed25519: us/op (vs Go crypto/ed25519, vs Rust ed25519-dalek)
- ChaCha20-Poly1305: MB/s (vs Go, vs Rust)
- HMAC-SHA256: MB/s
- HKDF: us/op

---

## Execution Order

1. Task 1 (ChaCha20) — immediate, no dependencies
2. Task 3 (constant_time) — immediate, no dependencies
3. Task 4 (AEAD dispatch) — depends on Task 1
4. Task 2 (field25519 + X25519) — biggest impact, careful
5. Task 5 (PKCS8) — independent
6. Task 6 (TLS12Record) — independent
7. Task 7 (Argon2) — independent
8. Task 8 (API review) — after all tests pass
9. Task 9 (benchmarks) — last, after all optimizations

## Quality Gate (per task)

- [ ] All RFC/NIST vector tests pass
- [ ] heaptrc reports 0 unfreed blocks
- [ ] git committed with descriptive message
- [ ] Goal tree updated if milestone reached
