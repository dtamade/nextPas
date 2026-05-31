program test_x509_ed25519_algorithm_truth;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.x509;

var
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;

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

procedure MarkSkip(const AName, AReason: string);
begin
  Inc(TotalTests);
  Inc(SkippedTests);
  WriteLn('[SKIP] [capability] ', AName, ' - ', AReason);
end;

function HasEd25519KeygenCapability: Boolean;
begin
  Result := Assigned(EVP_PKEY_CTX_new_id) and
            Assigned(EVP_PKEY_keygen_init) and
            Assigned(EVP_PKEY_keygen);
end;

procedure TestGeneratedEd25519CertificateParserTruth;
var
  LOptions: TCertGenOptions;
  LCertPEM: string;
  LKeyPEM: string;
  LGenerated: Boolean;
  LParser: TX509Certificate;
begin
  WriteLn;
  WriteLn('=== X509 parser Ed25519 algorithm metadata truth ===');

  LOptions := TCertificateUtils.DefaultGenOptions;
  LOptions.KeyType := ktEd25519;
  LOptions.CommonName := 'x509-ed25519-parser-truth.local';
  LOptions.Organization := 'fafafa.ssl';

  LGenerated := False;
  try
    LGenerated := TCertificateUtils.GenerateSelfSigned(LOptions, LCertPEM, LKeyPEM);
    AssertTrue('GenerateSelfSigned(Ed25519) should succeed', LGenerated);
  except
    on E: Exception do
    begin
      AssertTrue('GenerateSelfSigned(Ed25519) should succeed', False,
        E.ClassName + ': ' + E.Message);
      Exit;
    end;
  end;

  if not LGenerated then
    Exit;

  LParser := TX509Certificate.Create;
  try
    try
      LParser.LoadFromPEM(LCertPEM);
      AssertTrue('Parser public-key algorithm name exposes Ed25519 truth',
        SameText(LParser.PublicKeyInfo.Algorithm.Name, 'Ed25519'),
        'Actual=' + LParser.PublicKeyInfo.Algorithm.Name);
      AssertTrue('Parser public-key algorithm OID stays Ed25519 OID',
        LParser.PublicKeyInfo.Algorithm.OID = '1.3.101.112',
        'Actual=' + LParser.PublicKeyInfo.Algorithm.OID);
      AssertTrue('Parser public-key type exposes Ed25519 truth',
        SameText(LParser.PublicKeyInfo.KeyType, 'Ed25519'),
        'Actual=' + LParser.PublicKeyInfo.KeyType);
      AssertTrue('Parser public-key size exposes 256-bit truth',
        LParser.PublicKeyInfo.KeySize = 256,
        'Actual=' + IntToStr(LParser.PublicKeyInfo.KeySize));
      AssertTrue('Parser signature algorithm name exposes Ed25519 truth',
        SameText(LParser.SignatureAlgorithm.Name, 'Ed25519'),
        'Actual=' + LParser.SignatureAlgorithm.Name);
      AssertTrue('Parser signature algorithm OID stays Ed25519 OID',
        LParser.SignatureAlgorithm.OID = '1.3.101.112',
        'Actual=' + LParser.SignatureAlgorithm.OID);
    except
      on E: Exception do
        AssertTrue('Parser should load generated Ed25519 certificate', False,
          E.ClassName + ': ' + E.Message);
    end;
  finally
    LParser.Free;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('X509 Ed25519 Algorithm Metadata Truth');
  WriteLn('========================================');

  try
    LoadOpenSSLCore;
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
    begin
      MarkSkip('X509 Ed25519 algorithm metadata truth', 'OpenSSL core unavailable');
    end
    else
    begin
      LoadEVP(GetCryptoLibHandle);
      if not HasEd25519KeygenCapability then
        MarkSkip('X509 Ed25519 algorithm metadata truth',
          'EVP_PKEY Ed25519 keygen symbols unavailable')
      else
        TestGeneratedEd25519CertificateParserTruth;
    end;
  except
    on E: Exception do
      AssertTrue('Test harness should not raise', False,
        E.ClassName + ': ' + E.Message);
  end;

  WriteLn;
  WriteLn('========================================');
  WriteLn('Summary');
  WriteLn('========================================');
  WriteLn('Total Tests: ', TotalTests);
  WriteLn('Passed: ', PassedTests);
  WriteLn('Failed: ', FailedTests);
  WriteLn('Skipped: ', SkippedTests);

  if FailedTests > 0 then
    Halt(1);
end.
