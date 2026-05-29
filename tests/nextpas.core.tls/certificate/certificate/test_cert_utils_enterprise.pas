program test_cert_utils_enterprise;

{$mode objfpc}{$H+}

{**
 * TCertificateUtils 企业级功能测试
 * 验证证书生成、异常处理和指纹计算
 *}

uses
  SysUtils, Classes,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.exceptions;

procedure TestGenerateRSA;
var
  LOptions: TCertGenOptions;
  LCert, LKey: string;
begin
  WriteLn('[1] 测试RSA证书生成...');
  
  LOptions := TCertificateUtils.DefaultGenOptions;
  LOptions.CommonName := 'test.example.com';
  LOptions.KeyBits := 2048;
  
  try
    if TCertificateUtils.GenerateSelfSigned(LOptions, LCert, LKey) then
    begin
      WriteLn('  ✓ 证书生成成功');
      Assert(Pos('BEGIN CERTIFICATE', LCert) > 0, 'Should contain certificate header');
      Assert(Pos('BEGIN PRIVATE KEY', LKey) > 0, 'Should contain private key header');
    end
    else
      WriteLn('  ✗ 证书生成返回False (不应发生，应抛异常)');
  except
    on E: Exception do
    begin
      WriteLn('  ✗ 异常: ', E.Message);
      Halt(1);
    end;
  end;
  WriteLn;
end;

procedure TestGenerateEC;
var
  LOptions: TCertGenOptions;
  LCert, LKey: string;
begin
  WriteLn('[2] 测试EC证书生成...');
  
  LOptions := TCertificateUtils.DefaultGenOptions;
  LOptions.KeyType := ktECDSA;
  LOptions.ECCurve := 'prime256v1';
  LOptions.CommonName := 'ec.example.com';
  
  try
    TCertificateUtils.GenerateSelfSigned(LOptions, LCert, LKey);
    WriteLn('  ✓ EC证书生成成功');
    Assert(Pos('BEGIN CERTIFICATE', LCert) > 0, 'Should contain certificate header');
  except
    on E: Exception do
    begin
      WriteLn('  ✗ 异常: ', E.Message);
      Halt(1);
    end;
  end;
  WriteLn;
end;

procedure TestFingerprint;
var
  LOptions: TCertGenOptions;
  LCert, LKey: string;
  LFingerprint: string;
begin
  WriteLn('[3] 测试证书指纹...');
  
  LOptions := TCertificateUtils.DefaultGenOptions;
  TCertificateUtils.GenerateSelfSigned(LOptions, LCert, LKey);
  
  LFingerprint := TCertificateUtils.GetFingerprint(LCert);
  WriteLn('  指纹: ', LFingerprint);
  
  Assert(Length(LFingerprint) = 64, 'SHA-256 fingerprint should be 64 chars');
  WriteLn('  ✓ 指纹计算成功');
  WriteLn;
end;

procedure TestExceptions;
var
  LCaught: Boolean;
  LOptions: TCertGenOptions;
  LCert, LKey: string;
begin
  WriteLn('[4] 测试异常处理...');
  
  // 测试无效参数
  LCaught := False;
  try
    LOptions := TCertificateUtils.DefaultGenOptions;
    LOptions.CommonName := ''; // 无效CN
    TCertificateUtils.GenerateSelfSigned(LOptions, LCert, LKey);
  except
    on E: ESSLInvalidArgument do
    begin
      WriteLn('  捕获预期异常: ', E.Message);
      LCaught := True;
    end;
  end;
  Assert(LCaught, 'Should throw ESSLInvalidArgument for empty CN');
  
  // 测试无效密钥大小
  LCaught := False;
  try
    LOptions := TCertificateUtils.DefaultGenOptions;
    LOptions.KeyBits := 512; // 太小
    TCertificateUtils.GenerateSelfSigned(LOptions, LCert, LKey);
  except
    on E: ESSLInvalidArgument do
    begin
      WriteLn('  捕获预期异常: ', E.Message);
      LCaught := True;
    end;
  end;
  Assert(LCaught, 'Should throw ESSLInvalidArgument for small key');
  
  WriteLn('  ✓ 异常测试通过');
  WriteLn;
end;

begin
  WriteLn('==========================================');
  WriteLn('  TCertificateUtils 企业级功能测试');
  WriteLn('==========================================');
  WriteLn;
  
  try
    TestGenerateRSA;
    TestGenerateEC;
    TestFingerprint;
    TestExceptions;
    
    WriteLn('==========================================');
    WriteLn('✅ 所有测试通过！');
    WriteLn('==========================================');
  except
    on E: Exception do
    begin
      WriteLn('!!! 测试失败 !!!');
      WriteLn(E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
