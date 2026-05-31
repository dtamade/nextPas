program test_cert_utils_simple;

{$mode objfpc}{$H+}

{
  简化的证书工具测试 - 用于调试
}

uses
  SysUtils,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.openssl.loader, nextpas.core.tls.openssl.api.core;

var
  LOptions: TCertGenOptions;
  LCert, LKey: string;
begin
  WriteLn('========================================');
  WriteLn('Simple Certificate Utilities Test');
  WriteLn('========================================');
  WriteLn;
  
  try
    // 初始化OpenSSL
    WriteLn('[1/3] Loading OpenSSL...');
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      WriteLn('ERROR: Failed to load OpenSSL');
      Halt(1);
    end;
    WriteLn('  ✓ OpenSSL loaded: ', GetOpenSSLVersionString);
    WriteLn;
    
    // 获取默认选项
    WriteLn('[2/3] Getting default options...');
    LOptions := TCertificateUtils.DefaultGenOptions;
    WriteLn('  ✓ CN: ', LOptions.CommonName);
    WriteLn('  ✓ Org: ', LOptions.Organization);
    WriteLn('  ✓ ValidDays: ', LOptions.ValidDays);
    WriteLn('  ✓ KeyType: ', Ord(LOptions.KeyType));
    WriteLn('  ✓ KeyBits: ', LOptions.KeyBits);
    WriteLn;
    
   // 生成证书
    WriteLn('[3/3] Generating self-signed certificate...');
    try
      if TCertificateUtils.GenerateSelfSignedSimple(
        'test.example.com',
        'Test Org',
        365,
        LCert,
        LKey
      ) then
      begin
        WriteLn('  ✓ Generation succeeded!');
        WriteLn('  ✓ Cert length: ', Length(LCert));
        WriteLn('  ✓ Key length: ', Length(LKey));
        
        if Length(LCert) > 0 then
          WriteLn('  ✓ Cert preview: ', Copy(LCert, 1, 50), '...');
      end
      else
      begin
        WriteLn('  ✗ Generation failed');
        Halt(1);
      end;
    except
      on E: Exception do
      begin
        WriteLn('  ✗ Exception: ', E.ClassName, ': ', E.Message);
        Halt(1);
      end;
    end;
    
    WriteLn;
    WriteLn('========================================');
    WriteLn('✓ Test completed successfully!');
    WriteLn('========================================');
    
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('========================================');
      WriteLn('✗ FATAL ERROR: ', E.ClassName);
      WriteLn('  ', E.Message);
      WriteLn('========================================');
      Halt(1);
    end;
  end;
  
  WriteLn;
  WriteLn('Press Enter to exit...');
  ReadLn;
end.
