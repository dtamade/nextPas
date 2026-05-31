# nextpas.core.crypto — Cryptography Module

Pure Pascal cryptographic primitives. Zero external dependencies.
All secret-key operations are constant-time.

## Quick Start

```pascal
uses nextpas.core.crypto;

// X25519 key exchange
var Priv, Pub, Shared: TBytes;
GenerateX25519KeyPair(Priv, Pub);
Shared := X25519ComputeSharedSecret(Priv, PeerPub);

// Ed25519 signing
var Sig: TBytes; Err: string;
TryEd25519Sign(PrivKey, Message, Sig, Err);
if Ed25519Verify(PubKey, Message, Sig) then ...;

// AES-GCM encryption
var CT, Tag: TBytes;
PurePascalAESGCMEncrypt(Key, IV, Plaintext, AAD, CT, Tag);

// ChaCha20-Poly1305
TryChaCha20Poly1305Encrypt(Key, Nonce, AAD, Plain, CT, Tag);

// ECDSA P-256
TryECDSASignP256SHA256(Hash, PrivScalar, SigDER, Err);
TryECDSAVerifyP256SHA256(Hash, PubPoint, SigDER, Err);
```

## API Reference

### Facade: `uses nextpas.core.crypto`

One import gives access to all sub-modules below.

### Hash (`nextpas.core.crypto.hash`)

| Function | Description |
|----------|-------------|
| `SHA256(Data: TBytes): TBytes` | SHA-256 hash |
| `SHA384(Data: TBytes): TBytes` | SHA-384 hash |
| `SHA512(Data: TBytes): TBytes` | SHA-512 hash |
| `MD5(Data: TBytes): TBytes` | MD5 hash |
| `SHA1(Data: TBytes): TBytes` | SHA-1 hash |
| `HashToHex(Hash: TBytes): string` | Hex encode |

### HMAC (`nextpas.core.crypto.hmac`)

| Function | Description |
|----------|-------------|
| `HMAC_SHA256(Key, Data: TBytes): TBytes` | HMAC-SHA-256 |
| `HMAC_SHA384(Key, Data: TBytes): TBytes` | HMAC-SHA-384 |
| `HMAC_SHA1(Key, Data: TBytes): TBytes` | HMAC-SHA-1 |
| `NewHMAC(Algo, Key, KeyLen): IHasher` | Streaming HMAC |

### HKDF (`nextpas.core.crypto.hkdf`)

| Function | Description |
|----------|-------------|
| `HKDF_Extract_SHA256(Salt, IKM): TBytes` | Extract PRK |
| `HKDF_Expand_SHA256(PRK, Info, Len): TBytes` | Expand to OKM |
| `HKDF_Extract_SHA384(Salt, IKM): TBytes` | SHA-384 variant |
| `HKDF_Expand_SHA384(PRK, Info, Len): TBytes` | SHA-384 variant |

### X25519 (`nextpas.core.crypto.x25519`)

| Function | Description |
|----------|-------------|
| `GenerateX25519KeyPair(out Priv, Pub)` | Generate key pair |
| `X25519ScalarMult(Scalar, U): TBytes` | Raw scalar mult |
| `X25519ComputeSharedSecret(Priv, Peer): TBytes` | ECDHE |
| `TryX25519ScalarMult(...): Boolean` | Safe variant |
| `TryX25519ComputeSharedSecret(...): Boolean` | Safe variant |

### Ed25519 (`nextpas.core.crypto.ed25519`)

| Function | Description |
|----------|-------------|
| `Ed25519Sign(Priv, Msg, out Sig): Boolean` | Sign message |
| `Ed25519Verify(Pub, Msg, Sig): Boolean` | Verify signature |
| `Ed25519PublicKeyFromPrivate(Priv): TBytes` | Derive public key |
| `TryEd25519Sign(..., out Err): Boolean` | Safe variant |
| `TryEd25519PublicKeyFromPrivate(..., out Err): Boolean` | Safe variant |

### ECDSA P-256 (`nextpas.core.crypto.ecdsa`)

| Function | Description |
|----------|-------------|
| `TryECDSASignP256SHA256(Hash, Priv, out Sig, out Err): Boolean` | Sign (RFC 6979) |
| `TryECDSAVerifyP256SHA256(Hash, Pub, Sig, out Err): Boolean` | Verify |
| `TryP256ScalarMultBase(Scalar, out Point, out Err): Boolean` | k*G |

### AES-GCM (`nextpas.core.crypto.aesgcm`)

| Function | Description |
|----------|-------------|
| `PurePascalAESGCMEncrypt(Key, IV, PT, AAD, out CT, out Tag): Boolean` | Encrypt |
| `PurePascalAESGCMDecrypt(Key, IV, CT, Tag, AAD, out PT): Boolean` | Decrypt + verify |

### AES-CBC (`nextpas.core.crypto.aescbc`)

| Function | Description |
|----------|-------------|
| `TryAESCBCEncryptNoPadding(Key, IV, PT, out CT, out Err): Boolean` | Encrypt |
| `TryAESCBCDecryptNoPadding(Key, IV, CT, out PT, out Err): Boolean` | Decrypt |

### ChaCha20-Poly1305 (`nextpas.core.tls.tls13.chacha20poly1305`)

| Function | Description |
|----------|-------------|
| `TryChaCha20Poly1305Encrypt(Key, Nonce, AAD, PT, out CT, out Tag): Boolean` | Encrypt |
| `TryChaCha20Poly1305Decrypt(Key, Nonce, AAD, CT, Tag, out PT): Boolean` | Decrypt + verify |

### RSA (`nextpas.core.crypto.rsa`, `nextpas.core.crypto.rsa.ct`)

| Function | Description |
|----------|-------------|
| `TryRSAES_PKCS1v15_Encrypt(Msg, N, E, out CT, out Err): Boolean` | Public-key encrypt |
| `TryRSACTModExpSign(Msg, N, D, out Sig, out Err): Boolean` | CT private-key sign |
| `TryRSACTSignWithCRT(Msg, N, E, P, Q, DP, DQ, QInv, out Sig, out Err): Boolean` | CT CRT sign |

### Constant-Time (`nextpas.core.crypto.constant_time`)

| Function | Description |
|----------|-------------|
| `TConstantTime.CompareBytes(A, B: TBytes): Integer` | CT compare (1=equal) |
| `TConstantTime.CompareBuffer(A, B: Pointer; Len): Integer` | CT buffer compare |
| `TConstantTime.Select(Cond, IfTrue, IfFalse): TBytes` | CT select |

## Security Properties

- All private-key operations use constant-time algorithms
- RSA: w=4 fixed-window Montgomery + CRT + verify-after-sign
- ECDSA: Jacobian coordinates + CT table lookup + RFC 6979 nonce
- Ed25519: CT masked select in basepoint multiplication
- AES: CT S-box (256-entry scan) on non-AES-NI platforms
- X25519: Montgomery ladder with CT conditional swap

## Performance (x86_64)

| Operation | Performance | vs Go |
|-----------|-------------|-------|
| AES-128-GCM 8KB | 512 MB/s | 1.5x faster |
| X25519 | 181 us | = Go |
| SHA-256 8KB | 254 MB/s | = Go |
| ChaCha20-Poly1305 8KB | 328 MB/s | 0.66x |
| Ed25519 Sign (CT) | 478 us | 0.42x |
| ECDSA P-256 Sign (CT) | 2.6 ms | 0.04x |
| RSA-2048 CRT (CT) | 24 ms | 0.08x |

## Platform Support

All algorithms work on all platforms. SIMD acceleration on x86_64:
- AES-NI + PCLMULQDQ for AES-GCM
- AVX2 for ChaCha20 (4-block parallel)
- mulq for field arithmetic (X25519, P-256)
