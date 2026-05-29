# Migration Guide: From Synapse/Indy to fafafa.ssl

## From Synapse (THTTPSend + ssl_openssl)

### Before (Synapse)

```pascal
uses
  httpsend, ssl_openssl;

var
  HTTP: THTTPSend;
begin
  HTTP := THTTPSend.Create;
  try
    HTTP.Sock.SSL.SSLType := LT_TLSv1_2;
    HTTP.Sock.SSL.CertificateFile := 'client.pem';
    HTTP.HTTPMethod('GET', 'https://api.example.com/data');
    // Response in HTTP.Document
  finally
    HTTP.Free;
  end;
end;
```

### After (fafafa.ssl — zero C dependency)

```pascal
uses
  SysUtils, Classes, Sockets, ssockets,
  fafafa.ssl.base, fafafa.ssl.freepascal.lib;

var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  Conn: ISSLConnection;
  Socket: TInetSocket;
  Buf: array[0..4095] of Byte;
  Request: string;
  N: Integer;
begin
  Lib := TFreePascalSSLLibrary.Create;
  Lib.Initialize;

  Ctx := Lib.CreateContext(sslCtxClient);
  Ctx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
  Ctx.SetVerifyMode([sslVerifyPeer]);

  Socket := TInetSocket.Create('api.example.com', 443);
  try
    Conn := Ctx.CreateConnection(THandle(Socket.Handle));
    if Conn.Connect then
    begin
      Request := 'GET /data HTTP/1.0'#13#10 +
                 'Host: api.example.com'#13#10#13#10;
      Conn.Write(PByte(PChar(Request))^, Length(Request));
      N := Conn.Read(Buf[0], SizeOf(Buf));
      // Response in Buf[0..N-1]
      Conn.Shutdown;
    end;
  finally
    Socket.Free;
  end;

  Lib.Finalize;
end;
```

### Key Differences

| Aspect | Synapse | fafafa.ssl |
|--------|---------|-----------|
| External dependency | Requires OpenSSL DLL/so | Zero (pure Pascal backend) |
| TLS version | Configured via SSLType enum | Protocol version set |
| Certificate | File path on SSL object | Context-level LoadCertificate |
| Session resume | Not exposed | Full PSK/ticket support |
| Error handling | Exception-based | Boolean return + error query |

---

## From Indy (TIdSSLIOHandlerSocketOpenSSL)

### Before (Indy)

```pascal
uses
  IdHTTP, IdSSLOpenSSL;

var
  HTTP: TIdHTTP;
  SSL: TIdSSLIOHandlerSocketOpenSSL;
begin
  HTTP := TIdHTTP.Create(nil);
  SSL := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
  try
    SSL.SSLOptions.SSLVersions := [sslvTLSv1_2];
    SSL.SSLOptions.Mode := sslmClient;
    SSL.SSLOptions.VerifyMode := [sslvrfPeer];
    HTTP.IOHandler := SSL;
    HTTP.Get('https://api.example.com/data');
  finally
    SSL.Free;
    HTTP.Free;
  end;
end;
```

### After (fafafa.ssl)

```pascal
uses
  SysUtils, Sockets, ssockets,
  fafafa.ssl.base, fafafa.ssl.freepascal.lib;

var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  Conn: ISSLConnection;
  Socket: TInetSocket;
  Buf: array[0..4095] of Byte;
  N: Integer;
begin
  Lib := TFreePascalSSLLibrary.Create;
  Lib.Initialize;

  Ctx := Lib.CreateContext(sslCtxClient);
  Ctx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
  Ctx.SetVerifyMode([sslVerifyPeer]);

  Socket := TInetSocket.Create('api.example.com', 443);
  try
    Conn := Ctx.CreateConnection(THandle(Socket.Handle));
    if Conn.Connect then
    begin
      // Write/Read directly on Conn
      N := Conn.Read(Buf[0], SizeOf(Buf));
      Conn.Shutdown;
    end;
  finally
    Socket.Free;
  end;

  Lib.Finalize;
end;
```

### Key Differences

| Aspect | Indy | fafafa.ssl |
|--------|------|-----------|
| Architecture | IOHandler plugin on HTTP component | Standalone TLS layer |
| External dependency | Requires OpenSSL DLL | Zero (pure Pascal) |
| Ownership | Component-based (Create/Free) | Interface-based (ref-counted) |
| Session resume | Not exposed | Full PSK/ticket support |
| 0-RTT Early Data | Not available | Supported |
| OCSP/CT | Not available | Built-in verification |

---

## Migration Checklist

1. Replace `uses ssl_openssl` / `IdSSLOpenSSL` with `fafafa.ssl.freepascal.lib`
2. Create `ISSLLibrary` + `Initialize` at app startup
3. Create `ISSLContext` with desired protocol versions and verify mode
4. For each connection: `CreateConnection(socket_handle)` → `Connect` → `Read/Write` → `Shutdown`
5. Remove OpenSSL DLL from deployment package
6. Test with `run_unit_tests.sh` to verify TLS behavior
