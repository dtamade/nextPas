# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.6.x   | Yes       |
| 1.5.x   | Security fixes only |
| < 1.5   | No        |

## Reporting a Vulnerability

If you discover a security vulnerability in fafafa.ssl, please report it responsibly:

1. **Do NOT** open a public GitHub issue for security vulnerabilities.
2. Email the maintainer directly or use GitHub's private vulnerability reporting feature.
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Affected versions
   - Potential impact

## Response Timeline

- Acknowledgment: within 48 hours
- Initial assessment: within 7 days
- Fix release: within 30 days for Critical/High severity

## Security Design Principles

fafafa.ssl follows these security principles:

- **Secure defaults**: TLS 1.2+ only, peer verification enabled by default
- **Constant-time operations**: Cryptographic comparisons use `TConstantTime.CompareBytes`
- **Secure memory**: Key material is zeroed with `SecureZeroMemory` before deallocation
- **Fail-closed**: Unknown states reject rather than accept
- **Input validation**: All external inputs (PEM, certificates, config) are size-limited and validated
- **No custom crypto**: All cryptographic operations delegate to proven backends (OpenSSL, MbedTLS, WolfSSL, Schannel)

## Audit History

- 2026-05-25: Internal security review
  - 2 rounds, 30 findings total
  - All Critical (5/5), High (8/8), Medium (10/10), Low (7/7) resolved
