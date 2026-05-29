# CA Certificate Auto-Loading

## Current Status

This page is now a current-state note, not a feature-completion record.

Do not assume that `Lib.CreateContext(sslCtxClient)` by itself automatically loads
system CA certificates across backends. The supported, documented path is to ask
for system trust explicitly through the context builder, or through
`TSSLConfig.UseSystemRoots` on factory/direct-library config surfaces.

## Recommended Client Pattern

```pascal
uses
  fafafa.ssl,
  fafafa.ssl.context.builder,
  fafafa.ssl.tls;

var
  Ctx: ISSLContext;
  TLS: TSSLConnector;
  Stream: TSSLStream;
begin
  Ctx := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyPeer
    .WithSystemRoots
    .BuildClient;

  TLS := TSSLConnector.FromContext(Ctx);
  Stream := TLS.ConnectSocket(SocketHandle, 'www.example.com');
  try
    WriteLn('TLS OK: ', Stream.Connection.GetCipherName);
  finally
    Stream.Free;
  end;
end.
```

Explicit system-roots opt-in is the portable contract:

- builder path: `.WithSystemRoots`
- config/direct-library path: `TSSLConfig.UseSystemRoots := True`
- both ask the selected backend to load its platform-appropriate trust source
- both keep the trust-store setup explicit in user code
- both can layer explicit trust anchors through `.WithCAFile` or `SetCertificateStore(...)`
- do not treat `.WithCAPath` as a portable cross-backend rule
- WinSSL rejects non-empty `CAPath` because Schannel uses the Windows certificate store.

## What To Avoid Documenting

- Do not document `Lib.CreateContext(sslCtxClient)` alone as "automatic CA loading".
- Do not treat one backend's internal helper path as the cross-backend contract.
- Do not describe hostname verification as a context-level option; use
  `TSSLConnector.Connect*(..., host)` or `ISSLClientConnection.SetServerName(...)`
  on the connection.

## Backend Notes

- OpenSSL, WinSSL, MbedTLS, and WolfSSL do not share the same native trust-store
  implementation details.
- WinSSL ultimately validates against Windows certificate-store semantics.
- OpenSSL-family backends may rely on file/path-based trust loading.
- `CAPath` remains backend-specific; do not assume a Linux/OpenSSL-style CA directory
  is valid on WinSSL.
- The common API surface is explicit opt-in plus the store abstraction, not an
  implicit "auto-loaded client context" guarantee.

## Custom or Private Trust Anchors

If you need non-system trust anchors, layer them explicitly:

```pascal
Ctx := TSSLContextBuilder.Create
  .WithVerifyPeer
  .WithSystemRoots
  .WithCAFile('/path/to/internal-ca.pem')
  .BuildClient;
```

The same layered trust model is available on config/direct-library paths:

```pascal
var
  LConfig: TSSLConfig;
begin
  LConfig := CreateDefaultConfig(sslCtxClient);
  LConfig.LibraryType := sslOpenSSL;
  LConfig.ContextType := sslCtxClient;
  LConfig.VerifyMode := [sslVerifyPeer];
  LConfig.UseSystemRoots := True;
  LConfig.CAFile := '/path/to/internal-ca.pem';

  Ctx := TSSLFactory.CreateContext(LConfig);
end;
```

Or inject a backend-specific `ISSLCertificateStore` through `SetCertificateStore(...)`
when you need finer control.

## Verification Pointers

- Builder system-roots runtime contract:
  `tests/config/test_context_builder_system_roots_contract.pas`
- Current doc/runtime guidance contract:
  `tests/scripts/test_active_tls_guidance_contract.sh`
