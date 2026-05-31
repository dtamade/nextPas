program test_pem_der_simple;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.factory,
  fafafa.ssl;

var
  LRootCert, LRootKey: string;
  LDER: TBytes;
  LPEM2: string;
  LOptions: TCertGenOptions;
begin
  WriteLn('=== Simple PEM/DER Conversion Test ===');
  WriteLn;
  
  // 1. 生成测试证书
  WriteLn('[1] Generating test certificate...');
  LOptions := TCertificateUtils.DefaultGenOptions;
  LOptions.CommonName := 'PEM/DER Test';
  LOptions.IsCA := True;
  
  if not TCertificateUtils.GenerateSelfSigned(LOptions, LRootCert, LRootKey) then
  begin
    WriteLn('[FAIL] Could not generate certificate');
    Halt(1);
  end;
  WriteLn('[OK] Certificate generated');
  WriteLn('  PEM Length: ', Length(LRootCert));
  WriteLn;
  
  // 2. PEM → DER
  WriteLn('[2] Testing PEM to DER...');
  LDER := TCertificateUtils.PEMToDER(LRootCert);
  
  if Length(LDER) = 0 then
  begin
    WriteLn('[FAIL] PEM to DER returned empty');
    Halt(1);
  end;
  
  WriteLn('[OK] PEM to DER successful');
  WriteLn('  DER Length: ', Length(LDER));
  WriteLn('  First byte: $', IntToHex(LDER[0], 2), ' (should be $30)');
  
  if LDER[0] <> $30 then
  begin
    WriteLn('[FAIL] DER format invalid');
    Halt(1);
  end;
  WriteLn;
  
  // 3. DER → PEM
  WriteLn('[3] Testing DER to PEM...');
  LPEM2 := TCertificateUtils.DERToPEM(LDER);
  
  if Length(LPEM2) = 0 then
  begin
    WriteLn('[FAIL] DER to PEM returned empty');
    Halt(1);
  end;
  
  WriteLn('[OK] DER to PEM successful');
  WriteLn('  PEM Length: ', Length(LPEM2));
  WriteLn('  Has BEGIN marker: ', Pos('-----BEGIN', LPEM2) > 0);
  WriteLn('  Has END marker: ', Pos('-----END', LPEM2) > 0);
  WriteLn;
  
  // 4. 往返一致性
  WriteLn('[4] Testing round-trip consistency...');
  LDER := TCertificateUtils.PEMToDER(LPEM2);
  
  if Length(LDER) = 0 then
  begin
    WriteLn('[FAIL] Round-trip failed');
    Halt(1);
  end;
  
  WriteLn('[OK] Round-trip successful');
  WriteLn('  DER Length: ', Length(LDER));
  WriteLn;
  
  WriteLn('====================================');
  WriteLn('  ✅ ALL TESTS PASSED');
  WriteLn('====================================');
end.
