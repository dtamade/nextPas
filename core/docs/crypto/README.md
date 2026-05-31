# nextpas.core.crypto

Pure Pascal cryptographic primitives. Zero external dependencies, constant-time where it matters, SIMD-accelerated where available.

## Quick Start

```pascal
uses
  nextpas.core.crypto.aesgcm,
  nextpas.core.crypto.x25519,
  nextpas.core.crypto.ed25519,
  nextpas.core.crypto.pbkdf2;

// AES-256-GCM authenticated encryption
var CT, Tag: TBytes;
PurePascalAESGCMEncrypt(Key, Nonce, Plaintext, AAD, CT, Tag);

// X25519 key exchange
var Priv, Pub, Shared: TBytes;
GenerateX25519KeyPair(Priv, Pub);
Shared := X25519ComputeSharedSecret(Priv, PeerPub);

// Ed25519 digital signature
var Sig: TBytes;
Ed25519Sign(PrivateKey, Message, Sig);
if Ed25519Verify(PublicKey, Message, Sig) then ...

// Password hashing
var DerivedKey: TBytes;
DerivedKey := PBKDF2_SHA256(Password, Salt, 100000, 32);
```

## Module Map

```
nextpas.core.crypto
├── AEAD (authenticated encryption)
│   ├── aesgcm          — AES-128/256-GCM (PCLMUL + AES-NI accelerated)
│   └── chacha20poly1305 — ChaCha20-Poly1305 (RFC 8439)
├── Symmetric
│   ├── aesni           — AES-NI hardware acceleration
│   ├── aes.ct64        — AES constant-time software (bitsliced)
│   └── aescbc          — AES-CBC (no padding)
├── Asymmetric
│   ├── x25519          — X25519 ECDH (RFC 7748)
│   ├── ed25519         — Ed25519 signatures (RFC 8032)
│   ├── ecdsa           — ECDSA P-256 sign/verify
│   ├── p256.field/point — P-256 elliptic curve arithmetic
│   ├── p384            — P-384 ECDHE + ECDSA verify
│   └── rsa / rsa.ct    — RSA PKCS#1 v1.5 + constant-time CRT
├── KDF (key derivation)
│   ├── hkdf            — HKDF Extract/Expand (RFC 5869)
│   ├── pbkdf2          — PBKDF2-HMAC-SHA256/SHA1 (RFC 6070)
│   └── argon2          — Argon2id password hashing
├── MAC
│   └── hmac            — HMAC-SHA256/384/512/1 (RFC 2104)
├── Utilities
│   ├── constant_time   — Constant-time compare/select
│   ├── ct.bigint       — CT equal/less-than/swap
│   ├── bigint          — Montgomery modular exponentiation
│   └── pkcs8           — PKCS#8 encrypted key parsing
└── X.509
    └── x509verify      — Certificate chain + hostname verification
```

## Security Properties

| Module | Constant-Time | Notes |
|--------|:---:|-------|
| aesgcm (PCLMUL path) | Yes | Hardware carry-less multiply |
| aesgcm (scalar fallback) | Yes | Branchless GHASH (mask-based) |
| aes.ct64 | Yes | Bitsliced, no table lookups |
| aesni | Yes | Hardware AES rounds |
| chacha20poly1305 | Yes | ARX construction, no branches |
| x25519 | Yes | Montgomery ladder, clamped scalar |
| ed25519 | Partial | Verify is variable-time (public data) |
| ecdsa | Partial | Sign uses RFC 6979 deterministic k |
| rsa.ct | Yes | Fixed-window modexp + CRT with verify |
| p256.field | Yes | No secret-dependent branches |
| hmac | Yes | Inherits from underlying hash |
| constant_time | Yes | Purpose-built CT primitives |
| bigint (ModExp) | No | Standard Montgomery, use rsa.ct for secrets |

## API Reference

### AEAD

```pascal
// AES-GCM
function PurePascalAESGCMEncrypt(
  const AKey, AIV, APlaintext, AAAD: TBytes;
  out ACiphertext, ATag: TBytes): Boolean;

function PurePascalAESGCMDecrypt(
  const AKey, AIV, ACiphertext, AAAD, ATag: TBytes;
  out APlaintext: TBytes): Boolean;

// ChaCha20-Poly1305
function TryChaCha20Poly1305Encrypt(
  const AKey, ANonce, AAAD, APlaintext: TBytes;
  out ACiphertext, ATag: TBytes): Boolean;

function TryChaCha20Poly1305Decrypt(
  const AKey, ANonce, AAAD, ACiphertext, ATag: TBytes;
  out APlaintext: TBytes): Boolean;
```

### Key Exchange

```pascal
// X25519
procedure GenerateX25519KeyPair(out APrivateKey, APublicKey: TBytes);
function X25519ComputeSharedSecret(
  const APrivateKey, APeerPublicKey: TBytes): TBytes;

// P-384 ECDHE
function TryP384ECDHEKeyPair(
  out APrivateKey, APublicKey: TBytes; out AError: string): Boolean;
function TryP384ECDHE(
  const APrivateKey, APeerPublicKey: TBytes;
  out ASharedSecret: TBytes; out AError: string): Boolean;
```

### Digital Signatures

```pascal
// Ed25519
function Ed25519Sign(const APrivateKey, AMessage: TBytes;
  out ASignature: TBytes): Boolean;
function Ed25519Verify(const APublicKey, AMessage, ASignature: TBytes): Boolean;

// ECDSA P-256
function TryECDSASignP256SHA256(const APrivateKey, AMessage: TBytes;
  out ASignature: TBytes; out AError: string): Boolean;
function TryECDSAVerifyP256SHA256(const APublicPoint, AMessage, ASignature: TBytes;
  out AError: string): Boolean;
```

### Key Derivation

```pascal
// HKDF (RFC 5869)
function HKDF_Extract_SHA256(const ASalt, AIKM: TBytes): TBytes;
function HKDF_Expand_SHA256(const APRK, AInfo: TBytes; ALength: Integer): TBytes;

// PBKDF2 (RFC 6070)
function PBKDF2_SHA256(const APassword, ASalt: TBytes;
  AIterations, AKeyLen: Integer): TBytes;

// Argon2id
function Argon2Hash(const APassword, ASalt: TBytes;
  ATimeCost, AMemoryCost, AParallelism, AOutputLen: Integer): TBytes;
```

### MAC

```pascal
// HMAC (streaming via IHasher)
function NewHMAC(AAlgo: THashAlgorithm; const AKey; AKeyLen: SizeUInt): IHasher;

// One-shot convenience
function HMAC_SHA256(const AKey, AData: TBytes): TBytes;
function HMAC_SHA384(const AKey, AData: TBytes): TBytes;
```

## Usage Notes

1. **Nonce reuse is fatal for AES-GCM.** Never encrypt two messages with the same (key, nonce) pair. Use a counter or random 96-bit nonce.

2. **PBKDF2 iterations:** Use at least 100,000 for password storage (2026 recommendation). Prefer Argon2id for new applications.

3. **Key sizes:** AES-GCM accepts 16 or 32 byte keys. ChaCha20-Poly1305 requires exactly 32 bytes. X25519/Ed25519 keys are 32 bytes.

4. **Error handling:** `Try*` functions return Boolean + error string. Non-Try functions may raise exceptions on invalid input.

5. **Memory:** Sensitive intermediates are cleared with `SecureZeroMemory` (not optimizable away by the compiler).
