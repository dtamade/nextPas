# nextpas.core.tls — TLS Module

Pure Pascal TLS 1.3/1.2 implementation with optional OpenSSL/WolfSSL/mbedTLS backends.

## Quick Start

```pascal
uses nextpas.core.tls;

var
  S: TSSLStream;
  Err: string;
  Buf: array[0..4095] of Byte;
  N: Integer;
begin
  // One line TLS connection (DNS + TCP + TLS handshake)
  if TryTLSDial('example.com', 443, S, Err) then
  try
    S.WriteBuffer('GET / HTTP/1.1'#13#10'Host: example.com'#13#10#13#10, 40);
    N := S.Read(Buf, SizeOf(Buf));
    // process response...
  finally
    S.Free;
  end;
end.
```

No setup required. `uses nextpas.core.tls` auto-registers the pure Pascal backend.

## API Layers

```
┌─────────────────────────────────────────────────────┐
│  uses nextpas.core.tls                              │
├─────────────────────────────────────────────────────┤
│  Convenience:                                       │
│    TryTLSDial('host', 443, Stream, Error)           │
│    TLSDial('host', 443) → TSSLStream (throws)      │
├─────────────────────────────────────────────────────┤
│  Primary (rustls-aligned):                          │
│    TSSLConnector.FromContext(cfg)                    │
│      .WithALPN('h2,http/1.1')                       │
│      .WithReadTimeout(30000)                        │
│      .ConnectSocket(sock, 'host') → TSSLStream      │
│    TSSLAcceptor.FromContext(cfg)                     │
│      .AcceptSocket(sock) → TSSLStream               │
├─────────────────────────────────────────────────────┤
│  Configuration:                                     │
│    TSSLContextBuilder.Create                        │
│      .WithTLS13.WithVerifyPeer.WithSystemRoots      │
│      .BuildClient → ISSLContext                     │
└─────────────────────────────────────────────────────┘
```

## Client Usage

### Simple (auto-config)

```pascal
uses nextpas.core.tls;
var S: TSSLStream; Err: string;
if TryTLSDial('api.example.com', 443, S, Err) then
begin
  S.SetReadTimeout(30000);
  S.WriteBuffer(Request[1], Length(Request));
  N := S.Read(Buf, SizeOf(Buf));
  S.Free;
end;
```

### With custom config

```pascal
uses nextpas.core.tls, nextpas.core.tls.context.builder;

var Ctx: ISSLContext;
Ctx := TSSLContextBuilder.Create
  .WithTLS13
  .WithVerifyPeer
  .WithSystemRoots
  .WithALPN('h2,http/1.1')
  .BuildClient;

var Connector: TSSLConnector;
Connector := TSSLConnector.FromContext(Ctx)
  .WithHandshakeTimeout(5000)
  .WithReadTimeout(30000)
  .WithWriteTimeout(10000);

var S: TSSLStream;
S := Connector.ConnectSocket(Socket, 'api.example.com');
```

### HTTP/2 ALPN detection

```pascal
S := Connector.WithALPN('h2,http/1.1').ConnectSocket(Socket, Host);
if S.GetSelectedALPN = 'h2' then
  // Use HTTP/2 framing
else
  // Use HTTP/1.1
```

### STARTTLS (upgrade existing connection)

```pascal
// After plaintext SMTP/IMAP negotiation:
S := TSSLConnector.FromContext(Ctx).ConnectSocket(ExistingSocket, 'mail.example.com');
```

## Server Usage

```pascal
uses nextpas.core.tls, nextpas.core.tls.context.builder;

var Ctx: ISSLContext;
Ctx := TSSLContextBuilder.Create
  .WithTLS13
  .WithCertificate('/path/to/cert.pem')
  .WithPrivateKey('/path/to/key.pem')
  .BuildServer;

var Acceptor: TSSLAcceptor;
Acceptor := TSSLAcceptor.FromContext(Ctx);

// Accept incoming connection
var S: TSSLStream;
S := Acceptor.AcceptSocket(ClientSocket);
```

## TSSLStream

`TSSLStream` extends `TStream` — use it anywhere a `TStream` is expected.

| Method | Description |
|--------|-------------|
| `Read(var Buffer; Count): Longint` | Read decrypted data |
| `Write(const Buffer; Count): Longint` | Write data (encrypted on wire) |
| `Close` | Send close_notify + close socket |
| `SetReadTimeout(ms)` | Set read timeout |
| `SetWriteTimeout(ms)` | Set write timeout |
| `GetSelectedALPN: string` | Get negotiated ALPN protocol |
| `Connection: ISSLConnection` | Access underlying connection |

## TSSLConnector

| Method | Description |
|--------|-------------|
| `FromContext(cfg)` | Create connector from config |
| `WithTimeout(ms)` | Set overall timeout |
| `WithHandshakeTimeout(ms)` | Set handshake-specific timeout |
| `WithReadTimeout(ms)` | Set read timeout |
| `WithWriteTimeout(ms)` | Set write timeout |
| `WithALPN(protocols)` | Set ALPN (comma-separated) |
| `WithBlocking(bool)` | Set blocking mode |
| `WithSession(session)` | Resume session |
| `ConnectSocket(sock, name)` | Connect (throws on error) |
| `TryConnectSocket(sock, name, out S)` | Connect (returns Result) |
| `ConnectStream(stream, name)` | Connect over TStream transport |

## TSSLDialer

Reusable dialer with DNS resolution (convenience layer):

```pascal
var Dialer: TSSLDialer;
Dialer := TSSLDialer.CreateDefault;
Dialer.TimeoutMs := 10000;

// Multiple connections with same config
S1 := Dialer.Dial('host1.com', 443).Stream;
S2 := Dialer.Dial('host2.com', 443).Stream;

Dialer.Free;
```

## Backends

| Backend | Status | Notes |
|---------|--------|-------|
| Pure Pascal (FreePascal) | ✅ Default | TLS 1.3 full stack, auto-registered |
| OpenSSL 3.x | ✅ Optional | Full feature set |
| WolfSSL | ✅ Optional | Embedded-friendly |
| mbedTLS | ✅ Optional | Embedded-friendly |

## Security

- All private-key operations are constant-time
- AES-GCM uses AES-NI when available, CT fallback otherwise
- ChaCha20-Poly1305 with AVX2 acceleration
- Ed25519/X25519 with ASM field arithmetic
- ECDSA P-256 with Jacobian CT scalar multiplication
- RSA with w=4 fixed-window Montgomery + CRT + verify-after-sign

## Performance (x86_64)

| Operation | Throughput |
|-----------|-----------|
| AES-128-GCM 8KB | 512 MB/s |
| ChaCha20-Poly1305 8KB | 328 MB/s |
| X25519 key exchange | 181 us |
| TLS 1.3 handshake | ~5 ms |
