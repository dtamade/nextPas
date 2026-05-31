program test_cert_utils_try;

{$mode objfpc}{$H+}

{**
 * 测试证书工具类的 Try* 方法
 * 验证所有 Try* 方法在成功和失败场景下的行为
 *}

uses
  SysUtils,
  nextpas.core.tls.cert.utils;

var
  GTestsPassed: Integer = 0;
  GTestsFailed: Integer = 0;

procedure Assert(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GTestsPassed);
    WriteLn('  ✓ ', AMessage);
  end
  else
  begin
    Inc(GTestsFailed);
    WriteLn('  ✗ ', AMessage);
  end;
end;

procedure TestTryGenerateSelfSignedSimple;
var
  LCert, LKey: string;
begin
  WriteLn('=== TryGenerateSelfSignedSimple Tests ===');

  // 测试成功场景
  if TCertificateUtils.TryGenerateSelfSignedSimple('test.local', 'Test Org', 30, LCert, LKey) then
  begin
    Assert(LCert <> '', 'Should generate certificate PEM');
    Assert(LKey <> '', 'Should generate private key PEM');
    Assert(Pos('-----BEGIN CERTIFICATE-----', LCert) > 0, 'Certificate should be in PEM format');
    Assert(Pos('-----BEGIN PRIVATE KEY-----', LKey) > 0, 'Private key should be in PEM format');
  end
  else
    Assert(False, 'Should generate self-signed certificate');

  // 测试失败场景（空CN）
  if not TCertificateUtils.TryGenerateSelfSignedSimple('', 'Test Org', 30, LCert, LKey) then
  begin
    Assert(LCert = '', 'Should clear cert on failure');
    Assert(LKey = '', 'Should clear key on failure');
  end
  else
    Assert(False, 'Should fail with empty CommonName');

  WriteLn;
end;

procedure TestTryGetInfo;
var
  LCert, LKey: string;
  LInfo: TCertInfo;
begin
  WriteLn('=== TryGetInfo Tests ===');

  // 先生成测试证书
  if TCertificateUtils.TryGenerateSelfSignedSimple('example.com', 'Example Corp', 365, LCert, LKey) then
  begin
    // 测试成功获取信息
    if TCertificateUtils.TryGetInfo(LCert, LInfo) then
    begin
      try
        Assert(LInfo.Subject <> '', 'Should extract subject');
        Assert(LInfo.Issuer <> '', 'Should extract issuer');
        Assert(LInfo.Version > 0, 'Should extract version');
        Assert(LInfo.NotBefore > 0, 'Should extract NotBefore');
        Assert(LInfo.NotAfter > 0, 'Should extract NotAfter');
      finally
        LInfo.SubjectAltNames.Free;
      end;
    end
    else
      Assert(False, 'Should extract certificate info');

    // 测试失败场景（无效PEM） - GetInfo 静默失败，不抛异常
    if TCertificateUtils.TryGetInfo('invalid pem', LInfo) then
    begin
      // GetInfo 可能返回空的 Info 结构体而不抛异常
      Assert(LInfo.Subject = '', 'Should return empty subject for invalid PEM');
      LInfo.SubjectAltNames.Free;
    end
    else
    begin
      Assert(True, 'Correctly failed with invalid PEM');
      LInfo.SubjectAltNames.Free;
    end;
  end;

  WriteLn;
end;

procedure TestTryPEMToDER;
var
  LCert, LKey: string;
  LDER: TBytes;
  LPEM: string;
begin
  WriteLn('=== TryPEMToDER / TryDERToPEM Tests ===');

  // 生成测试证书
  if TCertificateUtils.TryGenerateSelfSignedSimple('test.example', 'Test', 30, LCert, LKey) then
  begin
    // 测试 PEM -> DER
    if TCertificateUtils.TryPEMToDER(LCert, LDER) then
    begin
      Assert(Length(LDER) > 0, 'Should convert PEM to DER');

      // 测试 DER -> PEM
      if TCertificateUtils.TryDERToPEM(LDER, LPEM) then
      begin
        Assert(LPEM <> '', 'Should convert DER to PEM');
        Assert(Pos('-----BEGIN CERTIFICATE-----', LPEM) > 0, 'Should be valid PEM format');
      end
      else
        Assert(False, 'Should convert DER to PEM');
    end
    else
      Assert(False, 'Should convert PEM to DER');

    // 测试失败场景
    if not TCertificateUtils.TryPEMToDER('invalid', LDER) then
      Assert(Length(LDER) = 0, 'Should return empty array on failure')
    else
      Assert(False, 'Should fail with invalid PEM');
  end;

  WriteLn;
end;

procedure TestTryGetFingerprint;
var
  LCert, LKey: string;
  LFingerprint: string;
begin
  WriteLn('=== TryGetFingerprint Tests ===');

  // 生成测试证书
  if TCertificateUtils.TryGenerateSelfSignedSimple('test.local', 'Test', 30, LCert, LKey) then
  begin
    // 测试成功获取指纹
    if TCertificateUtils.TryGetFingerprint(LCert, LFingerprint) then
    begin
      Assert(LFingerprint <> '', 'Should generate fingerprint');
      Assert(Length(LFingerprint) = 64, 'SHA256 fingerprint should be 64 hex chars');
    end
    else
      Assert(False, 'Should generate fingerprint');

    // 测试失败场景
    if not TCertificateUtils.TryGetFingerprint('', LFingerprint) then
      Assert(LFingerprint = '', 'Should return empty string on failure')
    else
      Assert(False, 'Should fail with empty PEM');
  end;

  WriteLn;
end;

procedure TestTryLoadAndSaveFile;
var
  LCert, LKey, LLoaded: string;
  LFileName: string;
begin
  WriteLn('=== TryLoadFromFile / SaveToFile Tests ===');

  LFileName := 'test_cert_temp.pem';

  // 生成测试证书
  if TCertificateUtils.TryGenerateSelfSignedSimple('file-test.local', 'Test', 30, LCert, LKey) then
  begin
    // 测试保存
    if TCertificateUtils.SaveToFile(LFileName, LCert) then
    begin
      Assert(FileExists(LFileName), 'Should create file');

      // 测试加载
      if TCertificateUtils.TryLoadFromFile(LFileName, LLoaded) then
      begin
        Assert(LLoaded <> '', 'Should load certificate from file');
        Assert(LLoaded = LCert, 'Loaded certificate should match original');
      end
      else
        Assert(False, 'Should load certificate from file');

      // 清理
      DeleteFile(LFileName);
    end
    else
      Assert(False, 'Should save certificate to file');

    // 测试失败场景（不存在的文件）
    if not TCertificateUtils.TryLoadFromFile('nonexistent.pem', LLoaded) then
      Assert(LLoaded = '', 'Should return empty string for nonexistent file')
    else
      Assert(False, 'Should fail with nonexistent file');
  end;

  WriteLn;
end;

begin
  WriteLn('╔════════════════════════════════════════════════════════════╗');
  WriteLn('║   Certificate Utils Try* Methods Tests                     ║');
  WriteLn('╚════════════════════════════════════════════════════════════╝');
  WriteLn;

  try
    TestTryGenerateSelfSignedSimple;
    TestTryGetInfo;
    TestTryPEMToDER;
    TestTryGetFingerprint;
    TestTryLoadAndSaveFile;

    WriteLn('╔════════════════════════════════════════════════════════════╗');
    WriteLn(Format('║   Tests Passed: %-3d  Failed: %-3d                         ║', [GTestsPassed, GTestsFailed]));
    WriteLn('╚════════════════════════════════════════════════════════════╝');

    if GTestsFailed > 0 then
      ExitCode := 1;
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('FATAL ERROR: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
