# Crypto Module Benchmark Results (2026-05-31)

## Environment
- CPU: x86_64 (with AES-NI, AVX2, PCLMULQDQ)
- FPC 3.3.1, -O2
- All CT security hardening applied

## Results

| Operation | Performance | vs Go stdlib | Notes |
|-----------|-------------|--------------|-------|
| X25519 ScalarMult | 182 us/op | = Go | ASM FeMul |
| Ed25519 Sign (CT) | 472 us/op | 2.4x slower | CT masked select (security tradeoff) |
| Ed25519 Verify | 450 us/op | = Go | Non-CT (public inputs) |
| AES-128-GCM 8KB | 518 MB/s | 1.5x faster | AES-NI + PCLMULQDQ |
| ChaCha20-Poly1305 8KB | 330 MB/s | 1.5x slower | AVX2 4-block + mulq Poly1305 |
| SHA-256 8KB | 235 MB/s | = Go | AVX2 dual-block |
| ECDSA P-256 Sign (CT) | 8.8 ms/op | 88x slower | Naive bit-by-bit, needs w=4 window |
| RSA-2048 CT ModExp | 82 ms/op | 41x slower | 32-bit limb, needs 64-bit + CRT |

## Optimization Roadmap (future)

### P-256 (currently 88x slower)
- Switch to w=4 fixed-window with precomputed base table (16 points)
- Use 64-bit limb field arithmetic (already implemented in p256.field.pas)
- Expected: 10-20x improvement → ~0.5-1ms

### RSA-2048 (currently 41x slower)
- Use CRT path (halves exponent size → ~4x faster)
- Switch to 64-bit limbs (2x fewer iterations)
- Expected with CRT: ~10-20ms (acceptable for TLS handshake)

### ChaCha20-Poly1305 (currently 1.5x slower)
- True instruction-level fusion (interleave ChaCha20 + Poly1305 in ASM)
- Expected: match or exceed Go

### Ed25519 Sign (currently 2.4x slower)
- Signed-radix-16 with precomputed table (Go's approach)
- Expected: match Go while maintaining CT
