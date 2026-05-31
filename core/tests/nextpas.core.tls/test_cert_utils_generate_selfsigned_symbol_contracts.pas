program test_cert_utils_generate_selfsigned_symbol_contracts;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.asn1,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.x509v3,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.bn,
  nextpas.core.tls.openssl.api.rsa;

type
  TSymbolEntry = record
    Name: string;
    Ptr: PPointer;
  end;

var
  GLib: ISSLLibrary = nil;
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

function BuildOptions: TCertGenOptions;
begin
  Result := TCertificateUtils.DefaultGenOptions;
  Result.CommonName := 'selfsigned-symbol-contract.local';
  Result.Organization := 'fafafa.ssl contract';
  Result.ValidDays := 30;
  Result.KeyType := ktRSA;
end;

procedure TestSymbolGuard(const AEntry: TSymbolEntry);
var
  LOptions: TCertGenOptions;
  LSaved: Pointer;
  LCertPEM, LKeyPEM: string;
  LRaised, LControlled: Boolean;
  LTryResult: Boolean;
  LDetail: string;
begin
  if AEntry.Ptr^ = nil then
  begin
    MarkSkip(AEntry.Name, 'symbol not available at baseline');
    Exit;
  end;

  LOptions := BuildOptions;

  // Warmup: verify normal path works
  if not TCertificateUtils.TryGenerateSelfSigned(LOptions, LCertPEM, LKeyPEM) then
  begin
    MarkSkip(AEntry.Name, 'warmup TryGenerateSelfSigned failed');
    Exit;
  end;

  // Save, nil, test, restore
  LSaved := AEntry.Ptr^;
  AEntry.Ptr^ := nil;
  try
    LRaised := False;
    LControlled := False;
    LDetail := '';
    LCertPEM := '';
    LKeyPEM := '';
    try
      TCertificateUtils.GenerateSelfSigned(LOptions, LCertPEM, LKeyPEM);
    except
      on E: Exception do
      begin
        LRaised := True;
        LControlled := E is ESSLCertError;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AEntry.Name + ' should raise on nil', LRaised,
      'expected GenerateSelfSigned to fail');
    AssertTrue(AEntry.Name + ' should raise ESSLCertError', LControlled, LDetail);

    // Try variant should return False without raising
    LCertPEM := 'sentinel';
    LKeyPEM := 'sentinel';
    LRaised := False;
    try
      LTryResult := TCertificateUtils.TryGenerateSelfSigned(LOptions, LCertPEM, LKeyPEM);
    except
      on E: Exception do
      begin
        LRaised := True;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AEntry.Name + ' Try should not raise', not LRaised, LDetail);
    AssertTrue(AEntry.Name + ' Try should return False', not LTryResult, '');
  finally
    AEntry.Ptr^ := LSaved;
  end;
end;

const
  SYMBOLS: array[0..25] of TSymbolEntry = (
    (Name: 'BN_new'; Ptr: @BN_new),
    (Name: 'BN_free'; Ptr: @BN_free),
    (Name: 'BN_set_word'; Ptr: @BN_set_word),
    (Name: 'RSA_new'; Ptr: @RSA_new),
    (Name: 'RSA_generate_key_ex'; Ptr: @RSA_generate_key_ex),
    (Name: 'EVP_PKEY_new'; Ptr: @EVP_PKEY_new),
    (Name: 'EVP_PKEY_free'; Ptr: @EVP_PKEY_free),
    (Name: 'EVP_PKEY_assign'; Ptr: @EVP_PKEY_assign),
    (Name: 'EVP_sha256'; Ptr: @EVP_sha256),
    (Name: 'X509_new'; Ptr: @X509_new),
    (Name: 'X509_free'; Ptr: @X509_free),
    (Name: 'X509_set_version'; Ptr: @X509_set_version),
    (Name: 'X509_get_serialNumber'; Ptr: @X509_get_serialNumber),
    (Name: 'ASN1_INTEGER_set'; Ptr: @ASN1_INTEGER_set),
    (Name: 'X509_get_notBefore'; Ptr: @X509_get_notBefore),
    (Name: 'X509_get_notAfter'; Ptr: @X509_get_notAfter),
    (Name: 'X509_gmtime_adj'; Ptr: @X509_gmtime_adj),
    (Name: 'X509_get_subject_name'; Ptr: @X509_get_subject_name),
    (Name: 'X509_NAME_add_entry_by_txt'; Ptr: @X509_NAME_add_entry_by_txt),
    (Name: 'X509_set_issuer_name'; Ptr: @X509_set_issuer_name),
    (Name: 'X509_set_pubkey'; Ptr: @X509_set_pubkey),
    (Name: 'X509_sign'; Ptr: @X509_sign),
    (Name: 'X509_add_ext'; Ptr: @X509_add_ext),
    (Name: 'X509_EXTENSION_free'; Ptr: @X509_EXTENSION_free),
    (Name: 'X509V3_EXT_conf_nid'; Ptr: @X509V3_EXT_conf_nid),
    (Name: 'X509V3_set_ctx'; Ptr: @X509V3_set_ctx)
  );

var
  I: Integer;
begin
  WriteLn('========================================');
  WriteLn('GenerateSelfSigned Symbol Guard Contracts (consolidated)');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  except
    on E: Exception do
    begin
      WriteLn('[SKIP] [backend-not-available] OpenSSL: ', E.Message);
      Halt(0);
    end;
  end;

  if (GLib = nil) or (not GLib.IsInitialized) then
  begin
    WriteLn('[SKIP] [backend-not-available] OpenSSL not initialized');
    Halt(0);
  end;

  for I := Low(SYMBOLS) to High(SYMBOLS) do
    TestSymbolGuard(SYMBOLS[I]);

  WriteLn;
  WriteLn('========================================');
  WriteLn('Summary: ', TotalTests, ' tests, ',
    PassedTests, ' passed, ', FailedTests, ' failed, ',
    SkippedTests, ' skipped');
  WriteLn('========================================');

  if FailedTests > 0 then
    Halt(1);
end.
