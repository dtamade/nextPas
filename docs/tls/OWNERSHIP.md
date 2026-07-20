# hash / crypto / tls — Ownership & Layering

**Status**: authoritative for this lane
**Last updated**: 2026-07-20

## Dependency direction

```
nextpas.core.hash          algorithms + IHasher + SIMD
        ↑
nextpas.core.crypto        AEAD, ECC, RSA, KDF, MAC, CT, ASN.1, random
        ↑
nextpas.core.tls           protocol, multi-backend, policy, cert chain verify
        ↑
nextpas.core.http          consumer
```

**Hard rules**

1. `crypto` production sources must not reference `nextpas.core.tls`.
2. `hash` production sources must not reference `nextpas.core.crypto`.
3. TLS protocol code must not re-implement hash/AEAD; it delegates to hash/crypto.

Enforced by: `core/tests/nextpas.core.crypto/test_crypto_layer_contract`.

## Module roles

| Module | Owner responsibilities | Non-goals |
|--------|------------------------|-----------|
| **hash** | SHA/MD5 digests, `IHasher`, SIMD, file hash, wyhash | keys, AEAD, TLS state |
| **crypto** | AEAD (AES-GCM, ChaCha20-Poly1305), ECC/RSA, KDF, HMAC/HKDF, constant-time, CSPRNG, ASN.1/DER, PKCS#8 | handshake, sockets, backend FFI |
| **tls** | TLS 1.2/1.3 protocol, OpenSSL/mbed/wolf/WinSSL/FreePascal backends, cert policy, session, dialer | reimplement primitives |

## Compatibility shims

| Unit | Role |
|------|------|
| `tls.tls13.chacha20poly1305` | thin forwarder → `crypto.chacha20poly1305` |
| `tls.asn1` | type/const re-export → `crypto.asn1` |
| `crypto.hash` | one-shot + `THashContext` adapter → `core.hash` IHasher |

Prefer the **owner unit** in new code. Shims exist for call-site stability.

## Decisions (2026-07-20)

- **D1** Unique hash implementation: `nextpas.core.hash`
- **D2** `crypto.hash` keeps public symbols; implementation is adapter-only
- **D3** ChaCha20-Poly1305 owner: `crypto.chacha20poly1305`
- **D4** ASN.1/DER owner: `crypto.asn1`
- **D5** X.509 chain verify owner: `tls.x509verify` (protocol-level)
- **D6** Crypto CSPRNG owner: `crypto.random` (via `platform.random`);
  `tls.random` is a thin compatibility shim
- **D7** (Batch B) ASN.1 trees own children (`TASN1Node` frees `FChildren`);
  X.509 parse paths must free temporary `TASN1Reader`/`TASN1Node`
- **D8** (Batch B) Prefer dynamic arrays / interface arrays over FPC `TList`
  for TLS registries and cert caches; no bare interface pointers in lists
- **D9** (Batch C) `TCertGenOptions.SubjectAltNames` and `TCertInfo.SubjectAltNames`
  are `TStringArray` value types — never `TStringList` (no Free required)
- **D10** (Batch D) OpenSSL certstore fingerprint/serial/subject/issuer indexes are
  value-type arrays (no `TStringList`); lookup is linear (stores are small)
- **D11** FPC RTL isolation (usability wave 2026-07-20):
  - Production `hash` / `crypto` / `tls` (except winssl) must not `uses` SysUtils,
    Classes, DateUtils, BaseUnix, Unix, or Windows directly.
  - Only `nextpas.core.system*` may route to broad FPC RTL.
  - `tls.winssl.*` may use `Windows` as **platform FFI** for Schannel (not SysUtils debt).
  - CSPRNG for TLS utils: `crypto.random` / `platform.random` only.
  - Socket I/O in nonblocking/freepascal.connection: `platform.socket` only.
  - Tests under hash/crypto/tls use `system.sysutils` / `system.classes` / `time`, not FPC RTL.
- **D12** Crypto errors: `nextpas.core.crypto.errors.ECryptoError` replaces bare
  `raise Exception` in crypto primitives; public APIs keep Try* shapes.
- **D13** `crypto.hash.THashAlgorithm` is a type alias of `hash.base.THashAlgorithm`
  (single enum definition).
- **D14** (2026-07-21 research/P0–P1): non-winssl production must not `uses` Base64 or
  Sockets; `tls.crypto.utils.THashAlgorithm` aliases `hash.base` with `HASH_* = ha*`
  consts for OpenSSL helper compatibility; tls production forbids bare
  `raise Exception` (use `ESSLInvalidArgument` / `ESSL*`); freepascal socket views use
  `TFdIStream` (IStream) instead of `THandleStream` (TMemoryStream/TConcatStream may
  remain via system.classes until M6).

## Related docs

- `core/docs/hash/CONTRACT.md`
- `core/docs/crypto/CONTRACT.md`
- `core/docs/tls/CONTRACT.md`
- `docs/tls/VERIFY.md`
