# hash / crypto / tls — Verification matrix

## Layer contract (always)

```bash
make focused FOCUS=core/tests/nextpas.core.crypto/test_crypto_layer_contract
```

## Heaptrc zero gates (Batch B)

These must report `0 unfreed memory blocks`:

```bash
make focused FOCUS=core/tests/nextpas.core.crypto/test_pkcs8
make focused FOCUS=core/tests/nextpas.core.crypto/test_x509verify
```

## Static hygiene (Batch B)

```bash
# no TList on cleaned hot paths
rg -n '\bTList\b' core/src/nextpas.core.tls.openssl.context.pas \
  core/src/nextpas.core.tls.openssl.certstore.pas \
  core/src/nextpas.core.tls.winssl.certstore.pas

# CSPRNG owner
rg -n '/dev/urandom|CryptGenRandom' core/src/nextpas.core.tls.random.pas  # expect empty
```

## Batch C — cert options + ASN free

```bash
# value-type SAN (no TStringList ownership footgun)
rg -n 'SubjectAltNames\s*:=\s*TStringList\.Create' core/src/nextpas.core.tls*.pas  # empty

make focused FOCUS=core/tests/nextpas.core.tls/test_tls_asn1_free_contract
make focused FOCUS=core/tests/nextpas.core.crypto/test_ecdsa
make focused FOCUS=core/tests/nextpas.core.crypto/test_p384
```

Known residual: `test_dialer` may fail on `io.pipe` IMutex vs INativeMutex (sync/io lane).

Static checks:

- no `nextpas.core.tls` in `core/src/nextpas.core.crypto*.pas`
- no `nextpas.core.crypto` in `core/src/nextpas.core.hash*.pas`
- `crypto.hash` delegates to `core.hash` (no Transform tables)
- crypto facade re-exports `crypto.chacha20poly1305`

## Minimal set (after any layer change)

```bash
make hygiene

# hash
make focused FOCUS=core/tests/nextpas.core.hash/test_sha256
make focused FOCUS=core/tests/nextpas.core.hash/test_hmac
make focused FOCUS=core/tests/nextpas.core.hash/test_facade

# crypto
make focused FOCUS=core/tests/nextpas.core.crypto/test_facade
make focused FOCUS=core/tests/nextpas.core.crypto/test_chacha20poly1305
make focused FOCUS=core/tests/nextpas.core.crypto/test_aesgcm
make focused FOCUS=core/tests/nextpas.core.crypto/test_x25519
make focused FOCUS=core/tests/nextpas.core.crypto/test_ed25519
make focused FOCUS=core/tests/nextpas.core.crypto/test_pkcs8
make focused FOCUS=core/tests/nextpas.core.crypto/test_argon2

# tls pure + contracts
make focused FOCUS=core/tests/nextpas.core.tls/test_tls13_aead
make focused FOCUS=core/tests/nextpas.core.tls/test_tls13_keyschedule
make focused FOCUS=core/tests/nextpas.core.tls/test_tls13_recordcrypto
make focused FOCUS=core/tests/nextpas.core.tls/test_tls13_recordsealer
make focused FOCUS=core/tests/nextpas.core.tls/test_stream_migration
make focused FOCUS=core/tests/nextpas.core.tls/test_tls_rtl_dependency_contract
make focused FOCUS=core/tests/nextpas.core.tls/test_openssl_loader
make focused FOCUS=core/tests/nextpas.core.tls/test_dialer
```

## Extended set

All Makefiles under:

- `core/tests/nextpas.core.hash/*/`
- `core/tests/nextpas.core.crypto/*/`
- `core/tests/nextpas.core.tls/test_*/`

Optional network:

```bash
make focused FOCUS=core/tests/nextpas.core.tls/test_openssl_https
make focused FOCUS=core/tests/nextpas.core.tls/test_tls13_e2e_openssl
```

Missing `openssl s_server` may soft-skip; record in Ready report.

## Done criteria

- layer contract PASS
- minimal set green (or documented soft-skip)
- `make hygiene` PASS
- `git diff --check` PASS
