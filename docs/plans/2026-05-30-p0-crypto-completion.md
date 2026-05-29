# P0 Crypto Completion — Detailed Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Achieve 100% test coverage on all crypto primitives with RFC/NIST vectors + zero memory leaks.

**Architecture:** Each module gets a standalone test program with vector tests + roundtrip tests + edge cases.

**Tech Stack:** FPC 3.3.1, `heaptrc` for leak detection, NIST/RFC test vectors.

---

## Task 1: AES-CBC NIST SP 800-38A Vector Tests

**Files:**
- Test: `tests/nextpas.core.crypto/test_aescbc/test_aescbc.lpr`
- Source: `src/nextpas.core.crypto.aescbc.pas` (existing)

**Step 1: Write the test program**

NIST SP 800-38A Appendix F.2 vectors (AES-128-CBC, AES-256-CBC):
- F.2.1: AES-128-CBC Encrypt
- F.2.2: AES-128-CBC Decrypt
- F.2.5: AES-256-CBC Encrypt
- F.2.6: AES-256-CBC Decrypt

Plus: roundtrip test, wrong-key rejection, block-alignment enforcement.

**Step 2: Run test, verify failures or passes**

```bash
cd ~/projects/nextPas/core-tls-import
mkdir -p tests/nextpas.core.crypto/test_aescbc
fpc -O3 -Mobjfpc -Fusrc -gh -FEtests/nextpas.core.crypto/test_aescbc tests/nextpas.core.crypto/test_aescbc/test_aescbc.lpr
./tests/nextpas.core.crypto/test_aescbc/test_aescbc
```

**Step 3: Fix any failures in aescbc.pas**

**Step 4: Verify zero leaks with heaptrc (-gh flag)**

**Step 5: Commit**

```bash
git add tests/nextpas.core.crypto/test_aescbc/
git commit -m "test(crypto): AES-CBC NIST SP 800-38A vector tests"
```

---

## Task 2: ECDSA P-256 Tests (NIST FIPS 186-4 + RFC 6979)

**Files:**
- Test: `tests/nextpas.core.crypto/test_ecdsa/test_ecdsa.lpr`
- Source: `src/nextpas.core.crypto.ecdsa.pas` (existing)

**Vectors:**
- NIST P-256 key pair generation (known scalar → known public point)
- RFC 6979 A.2.5: deterministic nonce for P-256/SHA-256
- Sign + verify roundtrip
- Invalid signature rejection
- Point validation (on-curve check)

**Step 1–5:** Same pattern as Task 1.

---

## Task 3: RSA PKCS#1 v1.5 Tests

**Files:**
- Test: `tests/nextpas.core.crypto/test_rsa/test_rsa.lpr`
- Source: `src/nextpas.core.crypto.rsa.pas` (existing)

**Vectors:**
- PKCS#1 v1.5 encoding format validation
- Known modulus/exponent encrypt + decrypt roundtrip
- Message too long rejection
- Padding format verification

---

## Task 4: TLS 1.2 PRF Tests (RFC 5246)

**Files:**
- Test: `tests/nextpas.core.crypto/test_tls12prf/test_tls12prf.lpr`
- Source: `src/nextpas.core.crypto.tls12prf.pas` (existing)

**Vectors:**
- RFC 5246 test vectors for PRF-SHA256
- Master secret derivation from pre-master secret
- Key expansion

---

## Task 5: BigInt Correctness Tests

**Files:**
- Test: `tests/nextpas.core.crypto/test_bigint/test_bigint.lpr`
- Source: `src/nextpas.core.crypto.bigint.pas` (existing)

**Vectors:**
- ModPow with known RSA-sized inputs
- ModInverse
- Addition/subtraction/multiplication overflow
- Comparison operators
- Zero/one edge cases

---

## Execution Order

1. Task 1 (AES-CBC) — simplest, pure block cipher
2. Task 5 (BigInt) — foundation for RSA/ECDSA
3. Task 3 (RSA) — depends on BigInt
4. Task 2 (ECDSA) — depends on BigInt
5. Task 4 (TLS12PRF) — depends on HMAC (already tested)

## Quality Gate

Each task is DONE when:
- [ ] All vector tests pass
- [ ] heaptrc reports 0 unfreed blocks
- [ ] git committed with descriptive message
- [ ] Goal tree updated

---
