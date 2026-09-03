program test_pem_der_conversion;

{$mode objfpc}{$H+}

uses
  nextpas.core.tls.openssl.backed,
  nextpas.core.tls.cert.utils, nextpas.core.base, nextpas.core.exception, nextpas.core.text;

var
  GPassed, GFailed: Integer;
  GTestCert: string;
  GTestKey: string;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GPassed);
    WriteLn('[OK] ', AMessage);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('[FAIL] ', AMessage);
  end;
end;

procedure GenerateTestCertificate;
var
  LOptions: TCertGenOptions;
begin
  WriteLn('=== Generating Test Certificate ===');

  LOptions := TCertificateUtils.DefaultGenOptions;
  LOptions.CommonName := 'test.example.com';
  LOptions.Organization := 'Test Org';
  LOptions.IsCA := False;
  LOptions.ValidDays := 365;

  if not TCertificateUtils.GenerateSelfSigned(LOptions, GTestCert, GTestKey) then
  begin
    WriteLn('[FATAL] Failed to generate test certificate');
    Halt(1);
  end;

  WriteLn('[OK] Test certificate generated');
  WriteLn('  PEM Length: ', Length(GTestCert));
  WriteLn;
end;

procedure TestPEMToDER;
var
  LPEM: string;
  LDER: TBytes;
begin
  WriteLn('=== Test: PEM to DER Conversion ===');

  // Test 1: 有效PEM转换
  LPEM := GTestCert;
  LDER := TCertificateUtils.PEMToDER(LPEM);

  AssertTrue(Length(LDER) > 0, 'PEM to DER should return non-empty bytes');
  if Length(LDER) > 0 then
    AssertTrue(LDER[0] = $30, 'DER should start with SEQUENCE tag (0x30)');

  // Test 2: 空PEM
  LPEM := '';
  LDER := TCertificateUtils.PEMToDER(LPEM);
  AssertTrue(Length(LDER) = 0, 'Empty PEM should return empty DER');

  WriteLn;
end;

procedure TestDERToPEM;
var
  LPEM, LPEM2: string;
  LDER: TBytes;
begin
  WriteLn('=== Test: DER to PEM Conversion ===');

  // Test 1: 往返转换
  LPEM := GTestCert;
  LDER := TCertificateUtils.PEMToDER(LPEM);
  LPEM2 := TCertificateUtils.DERToPEM(LDER);

  AssertTrue(Length(LPEM2) > 0, 'DER to PEM should return non-empty string');
  AssertTrue(Pos('-----BEGIN CERTIFICATE-----', LPEM2) > 0,
    'PEM should contain BEGIN marker');
  AssertTrue(Pos('-----END CERTIFICATE-----', LPEM2) > 0,
    'PEM should contain END marker');

  // Test 2: 往返一致性
  LDER := TCertificateUtils.PEMToDER(LPEM2);
  AssertTrue(Length(LDER) > 0, 'Round-trip PEM->DER->PEM->DER should work');

  WriteLn;
end;

procedure TestConvertFormat;
var
  LInput, LOutput: TBytes;
  LInputStr: string;
begin
  WriteLn('=== Test: ConvertFormat ===');

  // Test 1: PEM输入转DER
  LInputStr := GTestCert;
  SetLength(LInput, Length(LInputStr));
  if Length(LInputStr) > 0 then
    Move(LInputStr[1], LInput[0], Length(LInputStr));

  LOutput := TCertificateUtils.ConvertFormat(LInput, cfPEM, cfDER);

  AssertTrue(Length(LOutput) > 0, 'ConvertFormat PEM->DER should work');
  if Length(LOutput) > 0 then
    AssertTrue(LOutput[0] = $30, 'Converted DER should be valid');

  WriteLn;
end;

begin
  GPassed := 0;
  GFailed := 0;

  WriteLn('====================================');
  WriteLn('  PEM/DER Conversion Test Suite');
  WriteLn('====================================');
  WriteLn;

  try
    GenerateTestCertificate;
    TestPEMToDER;
    TestDERToPEM;
    TestConvertFormat;

    WriteLn('====================================');
    WriteLn('Results:');
    WriteLn('  Passed: ', GPassed);
    WriteLn('  Failed: ', GFailed);
    WriteLn('====================================');

    if GFailed > 0 then
      Halt(1);

  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.Message);
      Halt(1);
    end;
  end;
end.