program test_openssl_https;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils, Classes, BaseUnix, Sockets,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.backed;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('  [PASS] ', AName);
    Inc(GPass);
  end
  else
  begin
    WriteLn('  [FAIL] ', AName);
    Inc(GFail);
  end;
end;

procedure TestOpenSSLVersionInfo;
var
  LLib: ISSLLibrary;
begin
  LLib := CreateOpenSSLLibrary;
  Check('library created', LLib <> nil);
  if LLib = nil then Exit;
  Check('initialize', LLib.Initialize);
  Check('version not empty', LLib.GetVersionString <> '');
  WriteLn('    Version: ', LLib.GetVersionString);
  LLib.Finalize;
end;

procedure TestOpenSSLContextLifecycle;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
begin
  LLib := CreateOpenSSLLibrary;
  LLib.Initialize;
  LCtx := LLib.CreateContext(sslCtxClient);
  Check('client context', LCtx <> nil);
  Check('context type', LCtx.GetContextType = sslCtxClient);
  LCtx := nil;
  LLib.Finalize;
  Check('lifecycle ok', True);
end;

procedure TestOpenSSLRealHTTPS;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: LongInt;
  LAddr: sockaddr_in;
  LRequest: string;
  LBuf: array[0..4095] of Byte;
  LRead: Integer;
  LResponse: string;
begin
  LLib := CreateOpenSSLLibrary;
  if not LLib.Initialize then begin Check('init', False); Exit; end;

  LCtx := LLib.CreateContext(sslCtxClient);
  if LCtx = nil then begin Check('context', False); Exit; end;

  // Disable cert verification for test (no CA bundle configured)
  LCtx.SetVerifyMode([]);
  LCtx.SetServerName('cloudflare.com');

  // TCP connect to httpbin.org:443
  LSock := fpSocket(AF_INET, SOCK_STREAM, 0);
  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.sin_family := AF_INET;
  LAddr.sin_port := htons(443);
  LAddr.sin_addr := StrToNetAddr('1.1.1.1'); // Cloudflare (reliable)

  WriteLn('  Connecting to 1.1.1.1:443...');
  if fpConnect(LSock, @LAddr, SizeOf(LAddr)) <> 0 then
  begin
    WriteLn('  SKIP: network unavailable');
    fpClose(LSock);
    LLib.Finalize;
    Exit;
  end;
  Check('TCP connect', True);

  // Create SSL connection from socket
  LConn := LCtx.CreateConnection(THandle(LSock));
  Check('SSL connection created', LConn <> nil);
  if LConn = nil then begin fpClose(LSock); LLib.Finalize; Exit; end;

  // Set SNI on context
  LCtx.SetServerName('cloudflare.com');

  // Perform TLS handshake
  if not LConn.Connect then
  begin
    WriteLn('    Handshake failed, error code: ', Ord(LConn.GetError(-1)));
    Check('TLS handshake', False);
    LConn.Close; fpClose(LSock); LLib.Finalize;
    Exit;
  end;
  Check('TLS handshake', True);

  if LConn.IsHandshakeComplete then
  begin
    Check('handshake complete', True);
    WriteLn('    Protocol: ', LConn.GetProtocolVersion);
    WriteLn('    Cipher: ', LConn.GetCipherName);

    // Send HTTP request
    LRequest := 'GET / HTTP/1.1'#13#10'Host: cloudflare.com'#13#10'Connection: close'#13#10#13#10;
    LConn.Write(LRequest[1], Length(LRequest));

    // Read response
    LRead := LConn.Read(LBuf[0], SizeOf(LBuf));
    Check('received HTTP response', LRead > 0);
    if LRead > 0 then
    begin
      SetString(LResponse, PAnsiChar(@LBuf[0]), LRead);
      Check('response starts with HTTP', Pos('HTTP/', LResponse) = 1);
      WriteLn('    Response: ', Copy(LResponse, 1, 40), '...');
    end;
  end
  else
    Check('handshake complete', False);

  LConn.Shutdown;
  LConn.Close;
  LConn := nil;
  LCtx := nil;
  LLib.Finalize;
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== OpenSSL Backend HTTPS Tests ===');
  WriteLn;

  TestOpenSSLVersionInfo;
  TestOpenSSLContextLifecycle;
  TestOpenSSLRealHTTPS;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then
    Halt(1);
end.
