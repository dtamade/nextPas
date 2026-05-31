# fafafa.ssl API Reference

## FreePascal Pure Pascal Backend — TLS 1.2/1.3

### Quick Start

```pascal
uses
  fafafa.ssl.tls12.client, SysUtils, Classes, ssockets;

var
  LSocket: TInetSocket;
  LState: TTLS12ClientState;
  LError: string;
  LProtos: array[0..0] of string;
begin
  LSocket := TInetSocket.Create('example.com', 443);
  LProtos[0] := 'http/1.1';

  if TryTLS12ClientHandshake(LSocket, 'example.com', LProtos, LState, LError) then
    WriteLn('Connected! Cipher: 0x', IntToHex(LState.CipherSuite, 4))
  else
    WriteLn('Failed: ', LError);

  LSocket.Free;
end.
```

### Supported Cipher Suites (8 total)

| ID | Name | Record Mode |
|----|------|-------------|
| 0xCCA8 | ECDHE-RSA-CHACHA20-POLY1305-SHA256 | ChaCha20-Poly1305 |
| 0xCCA9 | ECDHE-ECDSA-CHACHA20-POLY1305-SHA256 | ChaCha20-Poly1305 |
| 0xC02F | ECDHE-RSA-AES128-GCM-SHA256 | AES-GCM |
| 0xC030 | ECDHE-RSA-AES256-GCM-SHA384 | AES-GCM |
| 0xC02B | ECDHE-ECDSA-AES128-GCM-SHA256 | AES-GCM |
| 0xC02C | ECDHE-ECDSA-AES256-GCM-SHA384 | AES-GCM |
| 0xC027 | ECDHE-RSA-AES128-CBC-SHA256 | AES-CBC+HMAC |
| 0xC028 | ECDHE-RSA-AES256-CBC-SHA384 | AES-CBC+HMAC |

### Key Exchange Groups

- X25519 (preferred)
- secp256r1 (P-256)

### Client API

```pascal
// Full handshake
function TryTLS12ClientHandshake(
  AStream: TStream;
  const AServerName: string;
  const AALPNProtocols: array of string;
  out AState: TTLS12ClientState;
  out AError: string
): Boolean;

// Session resumption
function TryTLS12ClientHandshakeWithResume(
  AStream: TStream;
  const AServerName: string;
  const AALPNProtocols: array of string;
  const ACachedSession: TTLS12SessionCache;
  out AState: TTLS12ClientState;
  out AError: string
): Boolean;
```

### Server API

```pascal
function TryTLS12ServerHandshake(
  AStream: TStream;
  const AConfig: TTLS12ServerConfig;
  out AState: TTLS12ServerState;
  out AError: string
): Boolean;
```

**Server Config:**
```pascal
TTLS12ServerConfig = record
  Certificate: TX509Certificate;
  CertificateDER: TBytes;
  PrivateKeyDER: TBytes;
  ServerName: string;
  SupportEMS: Boolean;
  ALPNProtocols: array of string;
  RequestClientCert: Boolean;
end;
```

### Connection Layer (High-Level)

```pascal
uses fafafa.ssl, fafafa.ssl.factory;

var
  LCtx: ISSLContext;
  LConn: ISSLConnection;
begin
  LCtx := TSSLFactory.CreateContext(sslCtxClient, sslFreePascal);
  LCtx.SetPreferredVersion(sslProtocolTLS12);
  LConn := LCtx.CreateConnection;
  LConn.SetServerName('example.com');
  // ... connect via socket, then:
  LConn.Connect;
end.
```

### DANE/TLSA Verification

```pascal
uses fafafa.ssl.dane.pure;

var
  LRecords: array[0..0] of TTLSARecord;
  LError: string;
begin
  LRecords[0] := BuildTLSARecord(3, 1, 1, LSHA256Hash);
  if VerifyDANE(LRecords, LCertDER, LError) then
    WriteLn('DANE verification passed');
end.
```

### Connection Pooling

```pascal
uses fafafa.ssl.http2.alpn;

var
  LPool: TSSLConnectionPool;
begin
  LPool := TSSLConnectionPool.Create(8, 60);
  // Acquire reuses idle connections to same host:port
  LConn := LPool.Acquire('api.example.com', 443);
  // ... use connection ...
  LPool.Release(LConn);
  LPool.CleanupIdle;
  LPool.Free;
end.
```

### Security Features

- Extended Master Secret (RFC 7627) — enforced by default
- Session Ticket (RFC 5077) — client receives and stores tickets
- Certificate chain verification — X.509 trust store integration
- Constant-time CBC padding validation — anti-oracle
- Secure key material cleanup — FillChar after use
- Alert parsing — human-readable error descriptions

### Architecture

```
fafafa.ssl.tls12.wire          — Protocol constants
fafafa.ssl.tls12.io            — Record I/O + handshake framing
fafafa.ssl.tls12.clienthello   — ClientHello builder
fafafa.ssl.tls12.parser        — Message parsers
fafafa.ssl.tls12.recordcrypto  — GCM record encrypt/decrypt
fafafa.ssl.tls12.chacha20record — ChaCha20-Poly1305 record
fafafa.ssl.crypto.tls12record  — CBC record (constant-time)
fafafa.ssl.tls12.handshakecrypto — PRF, key derivation, Finished
fafafa.ssl.tls12.client        — Client handshake state machine
fafafa.ssl.tls12.server        — Server handshake state machine
fafafa.ssl.tls12.ciphersuite   — Cipher suite registry
fafafa.ssl.crypto.bigint       — Montgomery modular exponentiation (32-bit limbs)
fafafa.ssl.crypto.ecdsa        — P-256 ECDSA sign/verify
fafafa.ssl.crypto.x25519       — X25519 key exchange
fafafa.ssl.crypto.hash         — SHA-256/384/512, MD5, SHA-1
fafafa.ssl.crypto.aesgcm       — AES-GCM AEAD
fafafa.ssl.crypto.aescbc       — AES-CBC encrypt/decrypt
fafafa.ssl.crypto.x509verify   — X.509 chain verification
fafafa.ssl.dane.pure           — DANE/TLSA verification
fafafa.ssl.http2.alpn          — HTTP/2 ALPN + connection pooling
```
