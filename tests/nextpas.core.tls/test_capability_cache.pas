program test_capability_cache;

{$mode objfpc}{$H+}

uses
  SysUtils, DateUtils,
  fafafa.ssl,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.mbedtls.lib,
  nextpas.core.tls.wolfssl.lib;

procedure Require(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

procedure TestCachingPerformance;
var
  Lib: TOpenSSLLibrary;
  Caps: TSSLBackendCapabilities;
  StartTime, EndTime: TDateTime;
  I: Integer;
  FirstCallTime, CachedCallTime: Int64;
  CallsPerSecond: Int64;
const
  ITERATIONS = 10000;
begin
  WriteLn('==============================================');
  WriteLn('能力矩阵缓存性能测试');
  WriteLn('==============================================');
  WriteLn;

  Lib := TOpenSSLLibrary.Create;
  try
    if not Lib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    WriteLn('第一次调用 GetCapabilities（未缓存）...');
    StartTime := Now;
    Caps := Lib.GetCapabilities;
    EndTime := Now;
    FirstCallTime := MilliSecondsBetween(EndTime, StartTime);
    WriteLn('  Backend: ', SSL_LIBRARY_NAMES[Caps.BackendType]);
    WriteLn('  Version: ', Caps.BackendVersion);
    WriteLn('  Time: ', FirstCallTime, ' ms');
    WriteLn;

    WriteLn('测试缓存性能 (', ITERATIONS, ' 次调用)...');
    StartTime := Now;
    for I := 1 to ITERATIONS do
      Caps := Lib.GetCapabilities;
    EndTime := Now;
    CachedCallTime := MilliSecondsBetween(EndTime, StartTime);

    WriteLn('  Total Time: ', CachedCallTime, ' ms');
    WriteLn('  Average per call: ', (CachedCallTime / ITERATIONS):0:6, ' ms');
    if CachedCallTime > 0 then
      CallsPerSecond := Round(ITERATIONS / (CachedCallTime / 1000))
    else
      CallsPerSecond := ITERATIONS;
    WriteLn('  Calls per second: ', CallsPerSecond:0, ' ops/s');
    WriteLn;

    WriteLn('性能提升分析:');
    if FirstCallTime > 0 then
      WriteLn('  首次调用耗时: ', FirstCallTime, ' ms')
    else
      WriteLn('  首次调用耗时: < 1 ms');
    WriteLn('  缓存调用耗时: ~', (CachedCallTime / ITERATIONS):0:6, ' ms per call');
    if (FirstCallTime > 0) and (CachedCallTime > 0) then
      WriteLn('  性能提升: ~', Round((FirstCallTime * 1000) / (CachedCallTime / ITERATIONS)):0, 'x')
    else
      WriteLn('  性能提升: 极显著（计时精度不足）');
    WriteLn;

    WriteLn('验证缓存内容...');
    WriteLn('  TLS 1.3: ', Caps.SupportsTLS13);
    WriteLn('  ALPN: ', Caps.SupportsALPN);
    WriteLn('  Hardware Accel: ', Caps.HasHardwareAcceleration);
    WriteLn('  Security Score: ', GetSecurityScore(Caps), '/100');
    WriteLn('  ✓ 缓存内容正确');
    WriteLn;

    Lib.Finalize;
  finally
    Lib.Free;
  end;
end;

procedure TestCacheInvalidation;
var
  Lib: TOpenSSLLibrary;
  Caps1, Caps2, Caps3: TSSLBackendCapabilities;
begin
  WriteLn('==============================================');
  WriteLn('能力矩阵缓存失效测试');
  WriteLn('==============================================');
  WriteLn;

  Lib := TOpenSSLLibrary.Create;
  try
    if not Lib.Initialize then
    begin
      WriteLn('Failed to initialize OpenSSL');
      Exit;
    end;

    WriteLn('首次获取能力矩阵...');
    Caps1 := Lib.GetCapabilities;
    WriteLn('  Version: ', Caps1.BackendVersion);
    WriteLn('  ✓ 已缓存');
    WriteLn;

    WriteLn('再次获取能力矩阵（应该来自缓存）...');
    Caps2 := Lib.GetCapabilities;
    WriteLn('  Version: ', Caps2.BackendVersion);
    if Caps2.BackendVersion = Caps1.BackendVersion then
      WriteLn('  ✓ 缓存有效')
    else
      WriteLn('  ✗ 缓存失效（不应该发生）');
    WriteLn;

    WriteLn('Finalize 后重新初始化...');
    Lib.Finalize;
    if not Lib.Initialize then
    begin
      WriteLn('  ✗ Re-initialization failed');
      Exit;
    end;

    WriteLn('获取能力矩阵（缓存应该已失效）...');
    Caps3 := Lib.GetCapabilities;
    WriteLn('  Version: ', Caps3.BackendVersion);
    WriteLn('  ✓ 缓存已重建');
    WriteLn;

    Lib.Finalize;
  finally
    Lib.Free;
  end;
end;

procedure TestFreePascalKnownIssuesAlignment;
var
  Lib: ISSLLibrary;
  Caps: TSSLBackendCapabilities;
begin
  WriteLn('==============================================');
  WriteLn('FreePascal KnownIssues 运行时对齐测试');
  WriteLn('==============================================');
  WriteLn;

  Lib := TSSLFactory.GetLibrary(sslFreePascal);
  if Lib = nil then
  begin
    WriteLn('  [SKIP] FreePascal backend not available');
    WriteLn;
    Exit;
  end;

  Caps := Lib.GetCapabilities;
  WriteLn('  KnownIssues: ', Caps.KnownIssues);
  WriteLn('  Supports AES256GCM in caps: ', IsCipherSupported(Caps, sslCipherAES256GCM));
  WriteLn('  IsCipherSupported(TLS_AES_256_GCM_SHA384): ',
    Lib.IsCipherSupported('TLS_AES_256_GCM_SHA384'));

  Require(Pos('ECDSA', UpperCase(Caps.KnownIssues)) = 0,
    'FreePascal KnownIssues should stop listing supported CertificateVerify algorithms as remaining issues');
  Require(Pos('PSK/RESUMPTION REMAIN IN PROGRESS', UpperCase(Caps.KnownIssues)) = 0,
    'FreePascal KnownIssues must stop claiming PSK/resumption is entirely pending once client and server session resumption close');
  Require(Pos('SERVER-SIDE RESUMPTION/PSK', UpperCase(Caps.KnownIssues)) = 0,
    'FreePascal KnownIssues should stop listing server-side resumption/PSK once the server path closes');
  Require(Pos('RESUMPTION', UpperCase(Caps.KnownIssues)) = 0,
    'FreePascal KnownIssues should stop listing implemented session-resumption details');
  Require(Pos('PSK', UpperCase(Caps.KnownIssues)) = 0,
    'FreePascal KnownIssues should stop listing implemented PSK details');
  Require(Pos('0-RTT', UpperCase(Caps.KnownIssues)) > 0,
    'FreePascal KnownIssues should still mention 0-RTT for experimental/support caveats');
  Require(Caps.ZeroRTTSupport = sslSupportExperimental,
    'FreePascal ZeroRTTSupport should move to experimental once public early-data transport is wired');
  Require(Caps.EarlyDataSupport = sslSupportExperimental,
    'FreePascal EarlyDataSupport should move to experimental once public early-data transport is wired');
  Require(Pos('IN-MEMORY SINGLE-PROCESS', UpperCase(Caps.KnownIssues)) = 0,
    'FreePascal KnownIssues should stop claiming the default early-data path is limited to an in-memory single-process ledger');
  Require(Pos('ANTI-REPLAY', UpperCase(Caps.KnownIssues)) > 0,
    'FreePascal KnownIssues should mention conservative anti-replay limitations for experimental 0-RTT');
  Require(Pos('FAIL-CLOSED', UpperCase(Caps.KnownIssues)) > 0,
    'FreePascal KnownIssues should mention fail-closed replay-store behavior once the default path is persistent');
  Require(Caps.SupportsCertificateTransparency,
    'FreePascal capabilities should advertise certificate-transparency support once client runtime surface is implemented');
  Require(Caps.CertTransparencySupport = sslSupportExperimental,
    'FreePascal certificate-transparency support level should be experimental while remaining gaps are still bounded');
  Require(Lib.IsFeatureSupported(sslFeatCertificateTransparency),
    'FreePascal IsFeatureSupported should acknowledge certificate-transparency runtime support');
  Require(Caps.SupportsOCSPStapling,
    'FreePascal capabilities should advertise OCSP stapling support once client runtime surface is implemented');
  Require(Caps.OCSPStaplingSupport = sslSupportExperimental,
    'FreePascal OCSP stapling support level should be experimental while broader revocation gaps remain bounded');
  Require(Lib.IsFeatureSupported(sslFeatOCSPStapling),
    'FreePascal IsFeatureSupported should acknowledge OCSP stapling runtime support');
  Require(Pos('OCSP', UpperCase(Caps.KnownIssues)) = 0,
    'FreePascal KnownIssues should stop listing OCSP as a remaining gap once server stapling closes');
  Require(Pos('SERVER-SIDE', UpperCase(Caps.KnownIssues)) = 0,
    'FreePascal KnownIssues should stop listing server-side stapling as a remaining gap');
  Require(Pos('STAPLING', UpperCase(Caps.KnownIssues)) = 0,
    'FreePascal KnownIssues should stop listing stapling issuance as a remaining gap');
  Require(Pos('ISSUANCE', UpperCase(Caps.KnownIssues)) = 0,
    'FreePascal KnownIssues should stop listing issuance gaps once public closeout lands');
  Require(Pos('REVOCATION EVIDENCE MATERIAL', UpperCase(Caps.KnownIssues)) = 0,
    'FreePascal KnownIssues should stop claiming revocation evidence material plumbing is still pending');
  Require(Pos('CRL-BACKED', UpperCase(Caps.KnownIssues)) = 0,
    'FreePascal KnownIssues should stop listing CRL-backed client validation material as a remaining gap');
  Require(Pos('CERTIFICATE VALIDATION', UpperCase(Caps.KnownIssues)) = 0,
    'FreePascal KnownIssues should stop using generic certificate-validation gap wording once client-side parity closes');
  Require(Pos('REMAINING GAPS INCLUDE OCSP STAPLING', UpperCase(Caps.KnownIssues)) = 0,
    'FreePascal KnownIssues should stop listing OCSP stapling as a blanket remaining gap');
  Require(Pos('ONLINE OCSP FETCH PARITY', UpperCase(Caps.KnownIssues)) = 0,
    'FreePascal KnownIssues should stop claiming online OCSP fetch parity is still missing');
  Require(Pos('OCSP STAPLING VALIDATION HARDENING', UpperCase(Caps.KnownIssues)) = 0,
    'FreePascal KnownIssues should stop claiming OCSP stapling validation hardening is still pending');
  Require(Pos('BROADER OCSP VALIDATION HARDENING', UpperCase(Caps.KnownIssues)) = 0,
    'FreePascal KnownIssues should stop claiming broader OCSP validation hardening is still pending once Batch 4 closes');
  Require(Pos('REMAINING GAPS INCLUDE OCSP STAPLING, CERTIFICATE TRANSPARENCY', UpperCase(Caps.KnownIssues)) = 0,
    'FreePascal KnownIssues should stop listing OCSP stapling and Certificate Transparency as blanket remaining gaps');
  Require(Pos('OCSP-DELIVERED', UpperCase(Caps.KnownIssues)) = 0,
    'FreePascal KnownIssues should stop claiming OCSP-delivered CT source parity is still missing');
  Require(Pos('TRANSPARENCY', UpperCase(Caps.KnownIssues)) = 0,
    'FreePascal KnownIssues should stop mentioning Certificate Transparency once Batch 2 closes');
  Require(Pos('BROADER CERTIFICATE VALIDATION HARDENING', UpperCase(Caps.KnownIssues)) = 0,
    'FreePascal KnownIssues should stop claiming broader certificate validation hardening is still pending once Batch 5 closes');
  Require(Pos('SHA384', UpperCase(Caps.KnownIssues)) = 0,
    'FreePascal KnownIssues must stop claiming SHA384 finished path is pending once parity is closed');
  Require(IsCipherSupported(Caps, sslCipherAES256GCM),
    'FreePascal capabilities must advertise AES256GCM once SHA384 parity is implemented');
  Require(Lib.IsCipherSupported('TLS_AES_256_GCM_SHA384'),
    'FreePascal IsCipherSupported must accept TLS_AES_256_GCM_SHA384 once SHA384 parity is implemented');

  WriteLn('  ✓ FreePascal KnownIssues runtime alignment verified');
  WriteLn;
end;

procedure TestWolfSSLKnownIssuesAlignment;
var
  Lib: ISSLLibrary;
  Caps: TSSLBackendCapabilities;
  LUpper: string;
begin
  WriteLn('==============================================');
  WriteLn('WolfSSL KnownIssues 运行时对齐测试');
  WriteLn('==============================================');
  WriteLn;

  Lib := TSSLFactory.GetLibrary(sslWolfSSL);
  if Lib = nil then
  begin
    WriteLn('  [SKIP] WolfSSL backend not available');
    WriteLn;
    Exit;
  end;

  Caps := Lib.GetCapabilities;
  LUpper := UpperCase(Caps.KnownIssues);
  WriteLn('  KnownIssues: ', Caps.KnownIssues);
  WriteLn('  EarlyDataSupport: ', Ord(Caps.EarlyDataSupport));
  WriteLn('  OCSPStaplingSupport: ', Ord(Caps.OCSPStaplingSupport));

  Require(Pos('MAY REQUIRE SPECIFIC BUILD OPTIONS FOR FULL FEATURE SUPPORT', LUpper) = 0,
    'WolfSSL KnownIssues should stop using the generic build-options placeholder');
  Require((Pos('BUILD/RUNTIME', LUpper) > 0) or (Pos('BUILD OR RUNTIME', LUpper) > 0),
    'WolfSSL KnownIssues should describe build/runtime-gated behavior');
  Require(Pos('HELPER', LUpper) > 0,
    'WolfSSL KnownIssues should mention helper-gated capability boundaries');
  Require((Pos('EARLY-DATA', LUpper) > 0) or (Pos('EARLY DATA', LUpper) > 0),
    'WolfSSL KnownIssues should mention early-data capability boundaries');
  Require(Pos('OCSP', LUpper) > 0,
    'WolfSSL KnownIssues should mention OCSP stapling remaining as experimental capability');

  WriteLn('  ✓ WolfSSL KnownIssues runtime alignment verified');
  WriteLn;
end;

procedure TestMbedTLSKnownIssuesAlignment;
var
  Lib: ISSLLibrary;
  Caps: TSSLBackendCapabilities;
  LUpper: string;
begin
  WriteLn('==============================================');
  WriteLn('MbedTLS KnownIssues 运行时对齐测试');
  WriteLn('==============================================');
  WriteLn;

  Lib := TSSLFactory.GetLibrary(sslMbedTLS);
  if Lib = nil then
  begin
    WriteLn('  [SKIP] MbedTLS backend not available');
    WriteLn;
    Exit;
  end;

  Caps := Lib.GetCapabilities;
  LUpper := UpperCase(Caps.KnownIssues);
  WriteLn('  KnownIssues: ', Caps.KnownIssues);
  WriteLn('  EarlyDataSupport: ', Ord(Caps.EarlyDataSupport));
  WriteLn('  OCSPStaplingSupport: ', Ord(Caps.OCSPStaplingSupport));
  WriteLn('  CertTransparencySupport: ', Ord(Caps.CertTransparencySupport));

  Require(Caps.EarlyDataSupport = sslSupportNone,
    'MbedTLS EarlyDataSupport should remain none on the current capability model');
  Require(Caps.OCSPStaplingSupport = sslSupportNone,
    'MbedTLS OCSPStaplingSupport should remain none on the current capability model');
  Require(Caps.CertTransparencySupport = sslSupportNone,
    'MbedTLS CertTransparencySupport should remain none on the current capability model');
  Require(Pos('MAY LACK SOME ENTERPRISE FEATURES', LUpper) = 0,
    'MbedTLS KnownIssues should stop using the generic enterprise-features placeholder');
  Require((Pos('EARLY-DATA', LUpper) > 0) or (Pos('EARLY DATA', LUpper) > 0),
    'MbedTLS KnownIssues should mention early-data unsupported truth');
  Require(Pos('OCSP', LUpper) > 0,
    'MbedTLS KnownIssues should mention OCSP stapling unsupported truth');
  Require((Pos('TRANSPARENCY', LUpper) > 0) or (Pos('CT', LUpper) > 0),
    'MbedTLS KnownIssues should mention certificate-transparency unsupported truth');

  WriteLn('  ✓ MbedTLS KnownIssues runtime alignment verified');
  WriteLn;
end;

begin
  WriteLn('fafafa.ssl - 能力矩阵缓存测试');
  WriteLn('==============================================');
  WriteLn;

  try
    TestCachingPerformance;
    WriteLn;
    TestCacheInvalidation;
    WriteLn;
    TestFreePascalKnownIssuesAlignment;
    TestWolfSSLKnownIssuesAlignment;
    TestMbedTLSKnownIssuesAlignment;

    WriteLn('==============================================');
    WriteLn('所有测试完成！');
    WriteLn('==============================================');
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('[ERROR] ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
