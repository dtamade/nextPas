# P2 Fixtures

This directory stores offline fixture files for P2 modules:

- `pkcs7/`
- `cms/`
- `pkcs12/`
- `ocsp/`
- `ct/`
- `ts/`
- `store/`

## Naming convention

Use `<module>_<scenario>_<version>.<ext>`.

Examples:

- `pkcs12_valid_nopass_v1.p12`
- `ocsp_response_revoked_v1.der`
- `ts_request_v1.tsq`

## Current Fixtures

### PKCS12

| File | Description | Password |
|------|-------------|----------|
| `pkcs12_valid_nopass_v1.p12` | Valid PKCS12 without password | (none) |
| `pkcs12_valid_password_v1.p12` | Valid PKCS12 with password | `test123` |
| `pkcs12_malformed_v1.der` | Malformed data for error handling | N/A |

### PKCS7

| File | Description |
|------|-------------|
| `pkcs7_signed_attached_v1.der` | Signed data with content attached |
| `pkcs7_signed_detached_v1.der` | Detached signature |
| `pkcs7_malformed_v1.der` | Malformed data for error handling |

### CMS

| File | Description |
|------|-------------|
| `cms_signed_v1.der` | CMS signed data |
| `cms_encrypted_v1.der` | CMS encrypted (AES-256-CBC) |
| `cms_malformed_v1.der` | Malformed data for error handling |

### OCSP

| File | Description |
|------|-------------|
| `ocsp_response_successful_basic_v1.der` | Valid basic OCSP response |
| `ocsp_response_malformed_v1.der` | Malformed data for error handling |

### CT

| File | Description |
|------|-------------|
| `ct_log_list_valid_v1.json` | Valid CT log list JSON |
| `ct_log_list_invalid_v1.txt` | Invalid format for error handling |

### TS

| File | Description |
|------|-------------|
| `ts_request_v1.tsq` | Valid timestamp request (SHA-256) |
| `ts_response_malformed_v1.der` | Malformed data for error handling |

### Store

| File | Description |
|------|-------------|
| `store_valid_cert_v1.pem` | Valid PEM certificate |
| `store_chain_v1.pem` | Certificate chain |
| `store_invalid_cert_payload_v1.txt` | Invalid data for error handling |

## Regenerating Fixtures

```bash
# Generate test certificate and key
openssl genrsa -out /tmp/test_key.pem 2048
openssl req -new -x509 -key /tmp/test_key.pem -out /tmp/test_cert.pem -days 365 \
  -subj "/CN=Test Certificate/O=fafafa.ssl/C=CN"

# PKCS12 (no password)
openssl pkcs12 -export -out pkcs12_valid_nopass_v1.p12 \
  -inkey /tmp/test_key.pem -in /tmp/test_cert.pem -passout pass:

# PKCS12 (with password)
openssl pkcs12 -export -out pkcs12_valid_password_v1.p12 \
  -inkey /tmp/test_key.pem -in /tmp/test_cert.pem -passout pass:test123

# PKCS7 signed
echo "test" > /tmp/data.txt
openssl smime -sign -in /tmp/data.txt -signer /tmp/test_cert.pem \
  -inkey /tmp/test_key.pem -outform DER -nodetach -out pkcs7_signed_attached_v1.der

# CMS signed
openssl cms -sign -in /tmp/data.txt -signer /tmp/test_cert.pem \
  -inkey /tmp/test_key.pem -outform DER -nodetach -out cms_signed_v1.der

# CMS encrypted
openssl cms -encrypt -aes-256-cbc -in /tmp/data.txt \
  -out cms_encrypted_v1.der -outform DER /tmp/test_cert.pem

# TS request
openssl ts -query -data /tmp/data.txt -sha256 -cert -out ts_request_v1.tsq
```

## Rules

- Keep fixtures deterministic and offline.
- Add one success and one failure sample per scenario.
- Update this README when adding new fixtures.
- Passwords for test fixtures should be documented here.
