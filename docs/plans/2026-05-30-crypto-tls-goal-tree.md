# nextpas.core.crypto + nextpas.core.tls — Goal Tree & Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the most capable pure-Pascal cryptography and TLS stack in the FreePascal ecosystem — correct, fast, auditable, zero external dependencies for the pure engine path.

**Architecture:**
- `nextpas.core.crypto` — standalone crypto primitives (hash, AEAD, ECC, RSA, KDF)
- `nextpas.core.tls` — TLS 1.2/1.3 protocol engine built on core.crypto
- Backend strategy: pure Pascal engine (default) + optional OpenSSL/WinSSL/wolfSSL/mbedTLS

**Tech Stack:** FPC 3.3.1, x86_64 ASM (AES-NI/PCLMULQDQ/AVX2/SHA-NI), AT&T + Intel syntax

---

## Goal Tree (G1–G9)

| ID | Goal | Status | Gate |
|----|------|--------|------|
| G1 | Crypto primitives 100% tested | **90%** | All NIST/RFC vectors pass, zero leaks |
| G2 | Crypto performance ≥ Go stdlib | **DONE** | SHA-256 ✓, AES-GCM ✓ |
| G3 | TLS 1.3 key schedule verified | **DONE** ✅ | 26 tests, early_secret matches RFC 8448 |
| G4 | TLS 1.3 record layer verified | **DONE** ✅ | 39 tests (23 unit + 16 E2E) |
| G5 | TLS 1.3 handshake state machine | **SIMULATED** ✅ | 19 tests, full crypto pipeline verified |
| G6 | TLS 1.3 pure Pascal engine E2E | **NEXT** | Connect to real server, no OpenSSL |
| G7 | OpenSSL backend integration | TODO | Dynamic load + basic handshake |
| G8 | Performance parity with Go net/tls | TODO | Handshake latency + bulk throughput |
| G9 | Production readiness | TODO | Fuzz, audit, docs, examples |

---

## G1 Breakdown — Crypto Primitives Test Coverage

| Module | API | Test Status | Vector Source |
|--------|-----|-------------|---------------|
| hash.sha256 | SHA256() | ✅ 58 tests | NIST CAVP |
| crypto.aesgcm | AES-128/256-GCM Encrypt/Decrypt | ✅ 14 tests | NIST SP 800-38D |
| crypto.x25519 | ScalarMult, KeyPair, SharedSecret | ✅ 6 tests | RFC 7748 |
| crypto.ed25519 | Sign, Verify, PubFromPriv | ✅ 13 tests | RFC 8032 |
| crypto.aescbc | AESCBCEncrypt/DecryptNoPadding | ✅ 10 tests | NIST SP 800-38A |
| crypto.hmac | HMAC-SHA256 | ✅ (in hash tests) | RFC 4231 |
| crypto.hkdf | HKDF-Expand/Extract | ✅ (in hash tests) | RFC 5869 |
| crypto.rsa | PKCS1v15 Encrypt | ✅ 14 tests | PKCS#1 format + roundtrip |
| crypto.ecdsa | P-256 Sign/Verify | ✅ 16 tests | NIST P-256 + RFC 6979 |
| crypto.bigint | ModPow, ModMul, Add, etc. | ✅ 19 tests | Known-answer vectors |
| crypto.tls12prf | PRF-SHA256/SHA384 | ✅ 11 tests | Python HMAC verification |
| crypto.p384 | P-384 ECDHE/Verify | ⏳ TODO | NIST vectors |
| crypto.tls12record | Record encrypt/decrypt | ⏳ TODO | Wireshark captures |

---

## Current Sprint: P0 Crypto Completion

### P0.4 — AES-CBC NIST Vector Tests
### P0.5 — ECDSA P-256 Basic Tests (RFC 6979 deterministic nonce)
### P0.6 — RSA PKCS#1 v1.5 Encrypt/Decrypt Tests
### P0.7 — TLS 1.2 PRF Tests (RFC 5246)
### P0.8 — BigInt Correctness Tests

---

## Architecture Principles

1. **Correctness first** — Every API has RFC/NIST vector tests before it's "done"
2. **Zero-copy where possible** — Pointer-based APIs for hot paths (record layer)
3. **Constant-time** — All secret-dependent operations use constant_time module
4. **Layered dispatch** — Hardware detect → ASM fast path → Pure Pascal fallback
5. **No global state** — All context is explicit (no thread-unsafe singletons)
6. **Minimal allocation** — Pre-allocated buffers for TLS record processing
7. **Fail-closed** — Crypto errors are fatal, never silently degraded

---

## Next Sprint: P1 TLS Integration

### P1.1 — TLS 1.3 Key Schedule (RFC 8448 vectors)
### P1.2 — TLS 1.3 Record Crypto (encrypt/decrypt application data)
### P1.3 — TLS 1.3 Handshake Messages (ClientHello/ServerHello/Finished)
### P1.4 — TLS 1.3 State Machine (full handshake flow)
### P1.5 — E2E: connect to openssl s_server

---
