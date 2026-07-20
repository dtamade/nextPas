# Usability assessment — hash / crypto / tls (2026-07-20)

## Scorecard (after remediation wave)

| Area | Before | After |
|------|--------|-------|
| Layering hash→crypto→tls | Strong | Strong (contracts green) |
| Heaptrc hot paths | Weak | Strong (ASN free, SAN value types, certstore arrays) |
| FPC RTL isolation (production) | Critical gap | **Cleared** for non-winssl; winssl = platform FFI |
| FPC RTL isolation (tests) | Critical gap (~785+ hits) | **Migrated** to system.sysutils/classes + time |
| Error model | Bare Exception | **ECryptoError** |
| Dual THashAlgorithm | Two enums | **One** (hash.base alias) |
| Dialer / pipe | Red (IMutex) | **INativeMutex** |
| Docs / Quick Start | Drifted | **IStream** aligned |

## Findings closed

| ID | Resolution |
|----|------------|
| F1 production RTL | Migrated SysUtils/Base64/DateUtils/BaseUnix/Unix/Windows(utils) to owners |
| F1 test RTL | Mechanical uses rewrite across hash/crypto/tls tests |
| F2 dual enum | `crypto.hash.THashAlgorithm` aliases `hash.base` |
| F4 bare Exception | `nextpas.core.crypto.errors` |
| F6 dialer | `io.pipe.FMutex: INativeMutex` |
| F8 heaptrc | Prior A–D gates retained |
| winssl Windows | Documented as platform FFI; not falsely “zeroed” |

## Known residual

- `test_system_source_contracts` may still fail on **unrelated** modules
  (`config.env`, `net.async.udp`) missing from allowlist — not owned by this lane.
- winssl still uses `Windows` unit (intentional Schannel FFI).
- `test_dialer` **compiles** after `io.pipe` `INativeMutex` fix; pool path may still
  AV / leave 2 heaptrc blocks under failed live handshake (network/env residual).
  Error-case assertions pass; not treated as compile gate failure.

## Verification evidence (2026-07-20)

| Gate | Result |
|------|--------|
| hash all focused Makefiles (13) | **green** |
| crypto all focused Makefiles (25) | **green** (incl. rsa_ct, x509verify heaptrc 0) |
| test_tls13_aead / stream_migration / openssl_https / asn1_free / rtl_dependency | **green** |
| test_dialer | compile OK; runtime pool residual |
| production RTL static (non-winssl) | **0 unit uses** |
| tests SysUtils/Classes/DateUtils uses | **0** |
| crypto `raise Exception.` | **0** |
| make hygiene | **pass** |

See `VERIFY.md` usability section.
