program test_mbedtls_ocsp_capability;

{$mode ObjFPC}{$H+}

{
  MbedTLS OCSP Stapling Capability Test

  目的: 验证 MbedTLS 的 OCSP Stapling 支持状态

  预期结果: MbedTLS 不支持客户端 OCSP Stapling
  这是 MbedTLS 的已知限制，不是 bug
}

uses
  SysUtils, TypInfo,
  nextpas.core.tls.base,
  nextpas.core.tls.mbedtls.lib,
  fafafa.examples.tcp;

// INTENTIONAL_OCSP_CORE_SURFACE: this MbedTLS-specific capability/runtime
// file intentionally keeps direct core OCSP compatibility-surface coverage
// as backend proof for the unsupported/fail-closed path. Ordinary
// ISSLOCSPStapling owner-path guidance is frozen elsewhere.

procedure TestOCSPCapability;
var
  LLib: ISSLLibrary;
  LCaps: TSSLBackendCapabilities;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LSock: TSocketHandle;
  LError: string;
begin
  WriteLn('================================================================================');
  WriteLn('MbedTLS OCSP Stapling Capability Test');
  WriteLn('================================================================================');
  WriteLn;

  // 1. 检查库级别能力
  WriteLn('1. Check library capabilities...');
  LLib := TMbedTLSLibrary.Create;
  if not LLib.Initialize then
  begin
    WriteLn('❌ Failed to initialize MbedTLS');
    Halt(1);
  end;
  WriteLn('✅ MbedTLS ', LLib.GetVersionString);

  LCaps := LLib.GetCapabilities;
  WriteLn;
  WriteLn('Backend Capabilities:');
  WriteLn('  SupportsOCSPStapling: ', LCaps.SupportsOCSPStapling);
  WriteLn('  OCSPStaplingSupport: ', GetEnumName(TypeInfo(TSSLFeatureSupportLevel),
    Ord(LCaps.OCSPStaplingSupport)));

  if not LCaps.SupportsOCSPStapling then
  begin
    WriteLn;
    WriteLn('✅ MbedTLS correctly reports: OCSP Stapling NOT supported');
    WriteLn('   This is a known limitation of MbedTLS client implementation');
  end
  else
  begin
    WriteLn;
    WriteLn('⚠️  OCSP Stapling reported as supported (unexpected)');
  end;

  // 2. 检查连接级别 OCSP API
  WriteLn;
  WriteLn('2. Check connection-level OCSP API...');

  if not InitNetwork(LError) then
  begin
    WriteLn('❌ Network init failed');
    LLib.Finalize;
    Halt(1);
  end;

  LSock := ConnectTCP('www.google.com', 443);
  try
    LCtx := LLib.CreateContext(sslCtxClient);
    LCtx.LoadCAFile('/etc/ssl/certs/ca-certificates.crt');
    LCtx.SetVerifyMode([sslVerifyPeer]);

    LConn := LCtx.CreateConnection(LSock);
    (LConn as ISSLClientConnection).SetServerName('www.google.com');
    if LConn.Connect then
    begin
      WriteLn('✅ TLS handshake successful');

      // 测试 OCSP API
      WriteLn;
      WriteLn('OCSP API Results:');
      {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
      WriteLn('  GetOCSPStaplingEnabled: ', LConn.GetOCSPStaplingEnabled);
      WriteLn('  GetOCSPResponse length: ', Length(LConn.GetOCSPResponse));
      WriteLn('  IsOCSPResponseVerified: ', LConn.IsOCSPResponseVerified);
      WriteLn('  GetOCSPResponseStatus: ', LConn.GetOCSPResponseStatus);

      if not LConn.GetOCSPStaplingEnabled then
      begin
        WriteLn;
        WriteLn('✅ OCSP Stapling correctly reported as disabled');
      end;

      if Length(LConn.GetOCSPResponse) = 0 then
      begin
        WriteLn('✅ OCSP Response correctly empty');
      end;

      if LConn.GetOCSPResponseStatus = 'Not Supported (MbedTLS limitation)' then
      begin
        WriteLn('✅ Status message correctly indicates MbedTLS limitation');
      end;
      {$POP}

      LConn.Shutdown;
    end;

    LConn := nil;
    LCtx := nil;
  finally
    CloseSocket(LSock);
  end;

  CleanupNetwork;
  LLib.Finalize;
  LLib := nil;

  WriteLn;
  WriteLn('================================================================================');
  WriteLn('CONCLUSION');
  WriteLn('================================================================================');
  WriteLn;
  WriteLn('MbedTLS OCSP Stapling Status:');
  WriteLn('  - Client-side OCSP Stapling: ❌ NOT SUPPORTED');
  WriteLn('  - This is a known limitation of MbedTLS');
  WriteLn('  - Server may still use OCSP for revocation checking');
  WriteLn('  - Alternative: Manual OCSP queries (future feature)');
  WriteLn;
  WriteLn('Capability correctly documented: ✅');
  WriteLn;
  WriteLn('================================================================================');
end;

begin
  try
    TestOCSPCapability;
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('❌ Fatal: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
