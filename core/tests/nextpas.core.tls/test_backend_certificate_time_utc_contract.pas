program test_backend_certificate_time_utc_contract;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.freepascal.lib
  {$IFDEF UNIX}
  , nextpas.core.tls.openssl.backed
  , nextpas.core.tls.mbedtls.lib
  , nextpas.core.tls.wolfssl.lib
  {$ENDIF}
  {$IFDEF WINDOWS}
  , nextpas.core.tls.openssl.backed
  , nextpas.core.tls.winssl.lib
  , nextpas.core.tls.mbedtls.lib
  , nextpas.core.tls.wolfssl.lib
  {$ENDIF}
  ;

var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  TestsSkipped: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(TestsPassed);
    WriteLn('[PASS] ', AMessage);
  end
  else
  begin
    Inc(TestsFailed);
    WriteLn('[FAIL] ', AMessage);
  end;
end;

procedure Skip(const AMessage: string);
begin
  Inc(TestsSkipped);
  WriteLn('[SKIP] ', AMessage);
end;

function BuildCurrentValidOptions: TCertGenOptions;
begin
  Result := TCertificateUtils.DefaultGenOptions;
  Result.CommonName := 'backend-cert-time-utc-contract.local';
  Result.Organization := 'nextpas core';
  Result.ValidDays := 1;
  Result.NotBefore := Now - (1.0 / 24.0);
  Result.NotAfter := Now + (1.0 / 24.0);
end;

procedure CheckBackendIsExpiredUsesUtc(ABackend: TSSLLibraryType;
  const ABackendName, ACertPEM: string);
var
  LCert: ISSLCertificate;
begin
  if not TSSLFactory.IsLibraryAvailable(ABackend) then
  begin
    Skip(ABackendName + ' backend 当前环境不可用');
    Exit;
  end;

  LCert := TSSLFactory.CreateCertificate(ABackend);
  Check(LCert <> nil, ABackendName + ' CreateCertificate 应返回实例');
  if LCert = nil then
    Exit;

  Check(LCert.LoadFromPEM(ACertPEM), ABackendName + ' 应能载入当前有效证书');
  Check(not LCert.IsExpired,
    ABackendName + ' IsExpired 应按 UTC 判断为未过期');
end;

procedure TestBackendCertificateExpiryUsesUtc;
var
  LOptions: TCertGenOptions;
  LCertPEM: string;
  LKeyPEM: string;
begin
  WriteLn;
  WriteLn('=== 后端证书 UTC 过期契约测试 ===');

  LOptions := BuildCurrentValidOptions;
  Check(TCertificateUtils.GenerateSelfSigned(LOptions, LCertPEM, LKeyPEM),
    '生成当前有效的测试证书');
  if LCertPEM = '' then
    Exit;

  CheckBackendIsExpiredUsesUtc(sslFreePascal, 'FreePascal', LCertPEM);
  CheckBackendIsExpiredUsesUtc(sslOpenSSL, 'OpenSSL', LCertPEM);
  CheckBackendIsExpiredUsesUtc(sslWolfSSL, 'WolfSSL', LCertPEM);
  CheckBackendIsExpiredUsesUtc(sslMbedTLS, 'MbedTLS', LCertPEM);
  CheckBackendIsExpiredUsesUtc(sslWinSSL, 'WinSSL', LCertPEM);
end;

procedure ReleaseBackendLibraries;
begin
  TSSLFactory.ReleaseLibrary(sslFreePascal);
  TSSLFactory.ReleaseLibrary(sslOpenSSL);
  TSSLFactory.ReleaseLibrary(sslWolfSSL);
  TSSLFactory.ReleaseLibrary(sslMbedTLS);
  TSSLFactory.ReleaseLibrary(sslWinSSL);
end;

begin
  try
    try
      WriteLn('========================================');
      WriteLn('nextpas.core.tls 后端证书时间 UTC 契约测试');
      WriteLn('========================================');

      TestBackendCertificateExpiryUsesUtc;

      WriteLn;
      WriteLn('========================================');
      WriteLn('测试结果: ', TestsPassed, ' 通过, ', TestsFailed, ' 失败, ',
        TestsSkipped, ' 跳过');
      WriteLn('========================================');

      if TestsFailed > 0 then
        Halt(1);
    except
      on E: Exception do
      begin
        WriteLn('[FAIL] 未处理异常: ', E.ClassName, ': ', E.Message);
        Halt(1);
      end;
    end;
  finally
    ReleaseBackendLibraries;
  end;
end.
