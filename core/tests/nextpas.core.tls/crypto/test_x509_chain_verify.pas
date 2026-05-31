program test_x509_chain_verify;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.x509,
  nextpas.core.tls.crypto.x509verify;

var
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
    Inc(GPassCount)
  else
  begin
    Inc(GFailCount);
    WriteLn('  FAIL: ', AMessage);
  end;
end;

procedure TestSelfSignedTrusted;
var
  LRoot: TX509Certificate;
  LStore: TX509TrustStore;
  LResult: TX509VerifyResult;
begin
  WriteLn('Test: Self-signed root in trust store should verify');
  LRoot := TX509Certificate.Create;
  LRoot.LoadFromFile('tests/fixtures/x509/root_ca.pem');

  LStore := TX509TrustStore.Create;
  LStore.AddTrustedCertificate(LRoot);

  LResult := VerifyX509Chain([LRoot], LStore, '');
  Check(LResult.IsValid, 'Self-signed root in trust store should be valid');
  Check(LResult.ErrorCode = 0, 'No error expected');

  LStore.Free;
  LRoot.Free;
end;

procedure TestUntrustedSelfSigned;
var
  LCert: TX509Certificate;
  LStore: TX509TrustStore;
  LResult: TX509VerifyResult;
begin
  WriteLn('Test: Self-signed cert NOT in trust store should fail');
  LCert := TX509Certificate.Create;
  LCert.LoadFromFile('tests/fixtures/x509/untrusted_self_signed.pem');

  LStore := TX509TrustStore.Create;

  LResult := VerifyX509Chain([LCert], LStore, '');
  Check(not LResult.IsValid, 'Untrusted self-signed must fail');
  Check(LResult.ErrorCode <> 0, 'Should have error code');

  LStore.Free;
  LCert.Free;
end;

procedure TestLeafIntermediateRoot;
var
  LLeaf, LIntermediate, LRoot: TX509Certificate;
  LStore: TX509TrustStore;
  LResult: TX509VerifyResult;
begin
  WriteLn('Test: Leaf -> Intermediate -> Root chain verification');
  LLeaf := TX509Certificate.Create;
  LLeaf.LoadFromFile('tests/fixtures/x509/leaf.pem');
  LIntermediate := TX509Certificate.Create;
  LIntermediate.LoadFromFile('tests/fixtures/x509/intermediate.pem');
  LRoot := TX509Certificate.Create;
  LRoot.LoadFromFile('tests/fixtures/x509/root_ca.pem');

  LStore := TX509TrustStore.Create;
  LStore.AddTrustedCertificate(LRoot);

  LResult := VerifyX509Chain([LLeaf, LIntermediate], LStore, 'leaf.example.com');
  Check(LResult.IsValid, 'Valid chain should verify: ' + LResult.ErrorMessage);
  Check(LResult.ChainDepth = 3, 'Chain depth should be 3 (leaf+intermediate+root)');

  LStore.Free;
  LRoot.Free;
  LIntermediate.Free;
  LLeaf.Free;
end;

procedure TestExpiredLeaf;
var
  LCert, LRoot: TX509Certificate;
  LStore: TX509TrustStore;
  LResult: TX509VerifyResult;
begin
  WriteLn('Test: Expired leaf certificate should fail');
  LCert := TX509Certificate.Create;
  LCert.LoadFromFile('tests/fixtures/x509/expired_leaf.pem');
  LRoot := TX509Certificate.Create;
  LRoot.LoadFromFile('tests/fixtures/x509/root_ca.pem');

  LStore := TX509TrustStore.Create;
  LStore.AddTrustedCertificate(LRoot);

  LResult := VerifyX509Chain([LCert], LStore, '');
  Check(not LResult.IsValid, 'Expired cert must fail');
  Check(Pos('expired', LowerCase(LResult.ErrorMessage)) > 0, 'Error should mention expiry');

  LStore.Free;
  LRoot.Free;
  LCert.Free;
end;

procedure TestHostnameMismatch;
var
  LCert: TX509Certificate;
  LStore: TX509TrustStore;
  LResult: TX509VerifyResult;
begin
  WriteLn('Test: Hostname mismatch should fail');
  LCert := TX509Certificate.Create;
  LCert.LoadFromFile('tests/fixtures/x509/root_ca.pem');

  LStore := TX509TrustStore.Create;
  LStore.AddTrustedCertificate(LCert);

  LResult := VerifyX509Chain([LCert], LStore, 'wrong.example.com');
  Check(not LResult.IsValid, 'Wrong hostname must fail');
  Check(Pos('hostname', LowerCase(LResult.ErrorMessage)) > 0,
    'Error should mention hostname, got: ' + LResult.ErrorMessage);

  LStore.Free;
  LCert.Free;
end;

procedure TestBasicConstraintsViolation;
var
  LLeaf, LFakeCA, LRoot: TX509Certificate;
  LStore: TX509TrustStore;
  LResult: TX509VerifyResult;
begin
  WriteLn('Test: Non-CA cert used as intermediate should fail');
  LLeaf := TX509Certificate.Create;
  LLeaf.LoadFromFile('tests/fixtures/x509/leaf_signed_by_non_ca.pem');
  LFakeCA := TX509Certificate.Create;
  LFakeCA.LoadFromFile('tests/fixtures/x509/non_ca_cert.pem');
  LRoot := TX509Certificate.Create;
  LRoot.LoadFromFile('tests/fixtures/x509/root_ca.pem');

  LStore := TX509TrustStore.Create;
  LStore.AddTrustedCertificate(LRoot);

  LResult := VerifyX509Chain([LLeaf, LFakeCA], LStore, '');
  Check(not LResult.IsValid, 'Non-CA intermediate must fail');
  Check(Pos('basic', LowerCase(LResult.ErrorMessage)) > 0,
    'Error should mention BasicConstraints');

  LStore.Free;
  LRoot.Free;
  LFakeCA.Free;
  LLeaf.Free;
end;

procedure TestSignatureVerification;
var
  LLeaf, LIntermediate, LRoot: TX509Certificate;
  LStore: TX509TrustStore;
  LResult: TX509VerifyResult;
begin
  WriteLn('Test: Tampered signature should fail');
  LLeaf := TX509Certificate.Create;
  LLeaf.LoadFromFile('tests/fixtures/x509/tampered_signature.pem');
  LIntermediate := TX509Certificate.Create;
  LIntermediate.LoadFromFile('tests/fixtures/x509/intermediate.pem');
  LRoot := TX509Certificate.Create;
  LRoot.LoadFromFile('tests/fixtures/x509/root_ca.pem');

  LStore := TX509TrustStore.Create;
  LStore.AddTrustedCertificate(LRoot);

  LResult := VerifyX509Chain([LLeaf, LIntermediate], LStore, '');
  Check(not LResult.IsValid, 'Tampered signature must fail');
  Check(Pos('signature', LowerCase(LResult.ErrorMessage)) > 0,
    'Error should mention signature, got: ' + LResult.ErrorMessage);

  LStore.Free;
  LRoot.Free;
  LIntermediate.Free;
  LLeaf.Free;
end;

begin
  WriteLn('=== X.509 Certificate Chain Verification Tests ===');
  WriteLn('');

  TestSelfSignedTrusted;
  TestUntrustedSelfSigned;
  TestLeafIntermediateRoot;
  TestExpiredLeaf;
  TestHostnameMismatch;
  TestBasicConstraintsViolation;
  TestSignatureVerification;

  WriteLn('');
  WriteLn(Format('Results: %d passed, %d failed', [GPassCount, GFailCount]));
  if GFailCount > 0 then
    Halt(1);
end.
