program test_cert_utils_verify_chain_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  fafafa.ssl,
  nextpas.core.tls.cert.utils;

var
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;

procedure AssertTrue(const AName: string; ACondition: Boolean; const ADetail: string = '');
begin
  Inc(TotalTests);
  if ACondition then
  begin
    Inc(PassedTests);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(FailedTests);
    WriteLn('[FAIL] ', AName);
    if ADetail <> '' then
      WriteLn('       ', ADetail);
  end;
end;

procedure TestVerifyChainWithBundledIntermediate;
var
  LRootOptions: TCertGenOptions;
  LInterOptions: TCertGenOptions;
  LLeafOptions: TCertGenOptions;
  LRootCertPEM, LRootKeyPEM: string;
  LInterCertPEM, LInterKeyPEM: string;
  LLeafCertPEM, LLeafKeyPEM: string;
  LBundlePEM: string;
  LTempDir: string;
  LRootPath: string;
  LResult: Boolean;
begin
  WriteLn;
  WriteLn('=== VerifyChain intermediate contract ===');

  LTempDir := 'tmp/cert_utils_verify_chain_contract';
  if not DirectoryExists(LTempDir) then
    ForceDirectories(LTempDir);
  LRootPath := LTempDir + PathDelim + 'root.crt';

  LRootOptions := TCertificateUtils.DefaultGenOptions;
  LRootOptions.CommonName := 'contract-root-ca.local';
  LRootOptions.IsCA := True;
  AssertTrue('Generate root CA should succeed',
    TCertificateUtils.GenerateSelfSigned(LRootOptions, LRootCertPEM, LRootKeyPEM));

  TCertificateUtils.SaveToFile(LRootPath, LRootCertPEM);

  LInterOptions := TCertificateUtils.DefaultGenOptions;
  LInterOptions.CommonName := 'contract-intermediate-ca.local';
  LInterOptions.IsCA := True;
  AssertTrue('Generate intermediate CA should succeed',
    TCertificateUtils.GenerateSigned(
      LInterOptions,
      LRootCertPEM,
      LRootKeyPEM,
      LInterCertPEM,
      LInterKeyPEM
    ));

  LLeafOptions := TCertificateUtils.DefaultGenOptions;
  LLeafOptions.CommonName := 'contract-leaf.local';
  LLeafOptions.IsCA := False;
  AssertTrue('Generate leaf cert should succeed',
    TCertificateUtils.GenerateSigned(
      LLeafOptions,
      LInterCertPEM,
      LInterKeyPEM,
      LLeafCertPEM,
      LLeafKeyPEM
    ));

  LResult := TCertificateUtils.VerifyChain(LLeafCertPEM, LRootPath);
  AssertTrue('VerifyChain(leaf only, root) should fail without intermediate',
    not LResult,
    'Expected False, actual=True');

  LBundlePEM := LLeafCertPEM + LineEnding + LInterCertPEM;
  LResult := TCertificateUtils.VerifyChain(LBundlePEM, LRootPath);
  AssertTrue('VerifyChain(leaf+intermediate, root) should succeed',
    LResult,
    'Expected True, actual=False');
end;

begin
  WriteLn('========================================');
  WriteLn('Cert Utils VerifyChain Contract Test');
  WriteLn('========================================');

  try
    TestVerifyChainWithBundledIntermediate;

    WriteLn;
    WriteLn('========================================');
    WriteLn('Summary');
    WriteLn('========================================');
    WriteLn('Total tests: ', TotalTests);
    WriteLn('Passed: ', PassedTests);
    WriteLn('Failed: ', FailedTests);

    if FailedTests > 0 then
      Halt(1);
  except
    on E: Exception do
    begin
      WriteLn('FATAL: ', E.ClassName, ': ', E.Message);
      Halt(2);
    end;
  end;
end.
