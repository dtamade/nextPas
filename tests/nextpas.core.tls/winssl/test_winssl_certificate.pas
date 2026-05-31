program test_winssl_certificate;

{$mode objfpc}{$H+}
{$CODEPAGE UTF8}

uses
  SysUtils
  {$IFDEF WINDOWS}
  , Classes, Windows,
  nextpas.core.tls.base,
  nextpas.core.tls.winssl.base,
  nextpas.core.tls.winssl.api,
  nextpas.core.tls.winssl.certificate,
  nextpas.core.tls.winssl.certstore
  {$ENDIF}
  ;

{$IFDEF WINDOWS}
var
  TestsPassed: Integer = 0;
  TestsFailed: Integer = 0;
  TestsSkipped: Integer = 0;
  SkipNoCert: Integer = 0;

procedure WriteTest(const TestName: string);
begin
  Write('  [', TestName, '] ... ');
end;

procedure WritePass;
begin
  WriteLn('[PASS]');
  Inc(TestsPassed);
end;

procedure WriteFail(const Reason: string = '');
begin
  if Reason <> '' then
    WriteLn('[FAIL] - ', Reason)
  else
    WriteLn('[FAIL]');
  Inc(TestsFailed);
end;

procedure WriteSkip(const Reason: string; const Category: string = 'other');
begin
  WriteLn('[SKIP] [', Category, '] ', Reason);
  Inc(TestsSkipped);
end;

procedure WriteNoCertSkip(const Reason: string = '无证书');
begin
  Inc(SkipNoCert);
  WriteSkip(Reason, 'no-cert');
end;

procedure TestStoreAccessAndBasicCert;
var
  Store: ISSLCertificateStore;
  Cert: ISSLCertificate;
  Count: Integer;
  Subject: string;
begin
  WriteLn('=== 测试 1: 证书存储访问与枚举 ===');
  WriteLn;

  WriteTest('打开 ROOT 系统存储');
  try
    Store := OpenSystemStore(SSL_STORE_ROOT);
    if Store <> nil then
      WritePass
    else
      WriteFail('存储为 nil');
  except
    on E: Exception do
    begin
      WriteFail(E.Message);
      Exit;
    end;
  end;

  WriteTest('ROOT 存储证书计数');
  Count := Store.GetCount;
  if Count > 0 then
    WritePass
  else
    WriteNoCertSkip('ROOT 存储为空');

  if Count = 0 then
  begin
    WriteLn;
    Exit;
  end;

  WriteTest('获取第一个证书');
  Cert := Store.GetCertificate(0);
  if Cert <> nil then
    WritePass
  else
    WriteFail('获取证书失败');

  if Cert = nil then
  begin
    WriteLn;
    Exit;
  end;

  WriteTest('读取证书主题');
  Subject := Cert.GetSubject;
  if Subject <> '' then
    WritePass
  else
    WriteFail('主题为空');

  WriteLn;
end;

procedure TestFingerprintAndExtension;
var
  Store: ISSLCertificateStore;
  Cert: ISSLCertificate;
  FP_SHA1: string;
  FP_SHA256: string;
  KeyUsage: TSSLStringArray;
begin
  WriteLn('=== 测试 2: 指纹与扩展 ===');
  WriteLn;

  Store := OpenSystemStore(SSL_STORE_ROOT);
  if (Store = nil) or (Store.GetCount = 0) then
  begin
    WriteNoCertSkip('无法获取可用 ROOT 证书');
    WriteLn;
    Exit;
  end;

  Cert := Store.GetCertificate(0);
  if Cert = nil then
  begin
    WriteNoCertSkip('无法获取首个证书');
    WriteLn;
    Exit;
  end;

  WriteTest('计算 SHA-1 指纹');
  FP_SHA1 := Cert.GetFingerprintSHA1;
  if (FP_SHA1 <> '') and (Length(FP_SHA1) > 20) then
    WritePass
  else
    WriteFail('SHA-1 指纹无效');

  WriteTest('计算 SHA-256 指纹');
  FP_SHA256 := Cert.GetFingerprintSHA256;
  if (FP_SHA256 <> '') and (Length(FP_SHA256) > 40) then
    WritePass
  else
    WriteFail('SHA-256 指纹无效');

  WriteTest('读取 Key Usage 扩展');
  KeyUsage := Cert.GetKeyUsage;
  if Length(KeyUsage) > 0 then
    WritePass
  else
    WriteFail('KeyUsage 为空');

  WriteLn;
end;

procedure PrintSummary;
var
  Total: Integer;
begin
  Total := TestsPassed + TestsFailed + TestsSkipped;
  WriteLn('==============================================');
  WriteLn('测试摘要:');
  WriteLn('  总计: ', Total);
  if Total > 0 then
    WriteLn('  通过: ', TestsPassed, ' (', FormatFloat('0.0', TestsPassed / Total * 100), '%)')
  else
    WriteLn('  通过: ', TestsPassed, ' (0.0%)');
  WriteLn('  失败: ', TestsFailed);
  WriteLn('  跳过: ', TestsSkipped, ' (no-cert=', SkipNoCert, ')');

  if TestsFailed = 0 then
    WriteLn('✅ WinSSL 证书测试通过')
  else
    WriteLn('⚠️ WinSSL 证书测试存在失败');
  WriteLn('==============================================');
end;

begin
  WriteLn('');
  WriteLn('==============================================');
  WriteLn('  fafafa.ssl - WinSSL 证书功能测试');
  WriteLn('==============================================');
  WriteLn('');
  WriteLn('测试环境:');
  WriteLn('  操作系统: Windows ', GetVersion shr 16, '.', GetVersion and $FFFF);
  WriteLn('  编译器: Free Pascal ', {$I %FPCVERSION%});
  WriteLn('');

  try
    TestStoreAccessAndBasicCert;
    TestFingerprintAndExtension;
  except
    on E: Exception do
    begin
      WriteLn('!!! 严重错误: ', E.Message);
      Inc(TestsFailed);
    end;
  end;

  PrintSummary;
  if TestsFailed > 0 then
    Halt(1);
end.
{$ELSE}
begin
  WriteLn('==============================================');
  WriteLn('  fafafa.ssl - WinSSL 证书功能测试');
  WriteLn('==============================================');
  WriteLn('[BLOCKED] [platform] WinSSL 证书测试仅支持 Windows 运行时');
  WriteLn('[SKIP] [platform] 当前平台非 Windows，跳过 WinSSL 证书功能验证');
end.
{$ENDIF}
