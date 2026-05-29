# Known Limits & Non-Goals

**Last updated**: 2026-05-29

This document defines the intentional boundaries of the FreePascal TLS backend.
These are design decisions, not bugs.

## Intentional Limitations

### 1. No PKCS#11 / PKCS#12

Hardware security module (HSM) integration and PFX/P12 container support are not
implemented in the pure Pascal backend. Use the OpenSSL backend for these features.

**Rationale**: PKCS#11 requires platform-specific dynamic library loading; PKCS#12
requires ASN.1 encryption formats beyond TLS scope.

### 2. No Online OCSP

The FreePascal backend verifies OCSP stapled responses (server-pushed) but does not
perform online OCSP queries to CA responders.

**Rationale**: Online OCSP requires an HTTP client, which is outside the TLS layer's
responsibility. Applications should inject their own HTTP transport if needed.

**Workaround**: Use OCSP stapling (server-side) or CRL-based revocation checking.

### 3. TLS 1.2 Renegotiation Not Completed

The FreePascal backend validates that the peer supports secure renegotiation (RFC 5746)
but does not complete the full re-handshake sequence.

**Rationale**: TLS 1.3 KeyUpdate is the recommended path for key rotation. TLS 1.2
renegotiation is deprecated in modern deployments and a source of complexity attacks.

### 4. No SetPasswordCallback / SetInfoCallback

Runtime callbacks for password prompting and handshake state notification are not
supported. Password-protected keys are handled at load time via PKCS#8 decryption.

**Rationale**: The callback pattern couples TLS internals to application UI flow.
The FreePascal backend prefers explicit configuration over runtime callbacks.

### 5. Platform Scope

- **System certificate store**: Linux/Unix paths only (`/etc/ssl/certs`, etc.)
- **Hardware acceleration**: x86_64 only (AES-NI, PCLMULQDQ)
- **No Windows CryptoAPI integration** in the pure Pascal backend

## Non-Goals

- **General-purpose cryptography toolkit**: Only TLS-required primitives are implemented
- **HTTP/2 or QUIC**: Transport protocols above TLS are out of scope
- **Certificate Authority operations**: No CA signing, only verification
- **DTLS**: Datagram TLS is not planned for the FreePascal backend

## Verified Interoperability

| Peer | TLS 1.2 | TLS 1.3 | PSK Resume | Status |
|------|---------|---------|------------|--------|
| OpenSSL 3.x | 9/9 cipher suites | 5/5 | Pass | Automated gate |
| Go crypto/tls | — | Pass | Pass | Automated gate |
| FreePascal (self) | Pass | Pass | Pass | Loopback tests |
