program test_cert_utils_getinfo_symbol_contracts;

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
  nextpas.core.tls.openssl.api.stack,
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
  GTestCertPEM: string = '';

procedure AssertTrue(const AName: string; ACondition: Boolean; const ADetail: string = '');
begin
  Inc(TotalTests);
  if ACondition then
    Inc(PassedTests)
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
  WriteLn('[SKIP] ', AName, ' - ', AReason);
end;

procedure PrepareCertMaterial;
var
  LOptions: TCertGenOptions;
  LKeyPEM: string;
begin
  LOptions := TCertificateUtils.DefaultGenOptions;
  LOptions.CommonName := 'getinfo-contract.local';
  LOptions.Organization := 'fafafa.ssl contract';
  LOptions.ValidDays := 30;
  LOptions.KeyType := ktRSA;
  if not TCertificateUtils.TryGenerateSelfSigned(LOptions, GTestCertPEM, LKeyPEM) then
    raise Exception.Create('Failed to generate test certificate for getinfo contracts');
end;

procedure TestSymbolGuard(const AEntry: TSymbolEntry);
var
  LSaved: Pointer;
  LInfo: TCertInfo;
  LRaised, LControlled: Boolean;
  LDetail: string;
begin
  if AEntry.Ptr^ = nil then
  begin
    MarkSkip(AEntry.Name, 'symbol not available');
    Exit;
  end;

  // Warmup
  LInfo := TCertificateUtils.GetInfo(GTestCertPEM);
  if LInfo.Subject = '' then
  begin
    MarkSkip(AEntry.Name, 'warmup GetInfo returned empty subject');
    Exit;
  end;

  LSaved := AEntry.Ptr^;
  AEntry.Ptr^ := nil;
  try
    LRaised := False;
    LDetail := '';
    try
      LInfo := TCertificateUtils.GetInfo(GTestCertPEM);
    except
      on E: Exception do
      begin
        LRaised := True;
        LControlled := (E is ESSLCertError) or (E is ESSLException);
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    if LRaised then
      AssertTrue(AEntry.Name + ' raised controlled exception', LControlled, LDetail)
    else
      AssertTrue(AEntry.Name + ' did not crash (graceful degradation)', True, '');
  finally
    AEntry.Ptr^ := LSaved;
  end;
end;

const
  SYMBOLS: array[0..16] of TSymbolEntry = (
    (Name: 'BIO_free'; Ptr: @BIO_free),
    (Name: 'BIO_read'; Ptr: @BIO_read),
    (Name: 'BIO_s_mem'; Ptr: @BIO_s_mem),
    (Name: 'EVP_PKEY_free'; Ptr: @EVP_PKEY_free),
    (Name: 'GENERAL_NAME_get0_value'; Ptr: @GENERAL_NAME_get0_value),
    (Name: 'GENERAL_NAMES_free'; Ptr: @GENERAL_NAMES_free),
    (Name: 'OPENSSL_sk_num'; Ptr: @OPENSSL_sk_num),
    (Name: 'OPENSSL_sk_value'; Ptr: @OPENSSL_sk_value),
    (Name: 'X509_free'; Ptr: @X509_free),
    (Name: 'X509_get_issuer_name'; Ptr: @X509_get_issuer_name),
    (Name: 'X509_get_notAfter'; Ptr: @X509_get_notAfter),
    (Name: 'X509_get_notBefore'; Ptr: @X509_get_notBefore),
    (Name: 'X509_get_pubkey'; Ptr: @X509_get_pubkey),
    (Name: 'X509_get_serialNumber'; Ptr: @X509_get_serialNumber),
    (Name: 'X509_get_subject_name'; Ptr: @X509_get_subject_name),
    (Name: 'X509_get_version'; Ptr: @X509_get_version),
    (Name: 'X509_NAME_print_ex'; Ptr: @X509_NAME_print_ex)
  );

var
  I: Integer;
begin
  WriteLn('========================================');
  WriteLn('GetInfo Symbol Guard Contracts (consolidated)');
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

  PrepareCertMaterial;

  for I := Low(SYMBOLS) to High(SYMBOLS) do
    TestSymbolGuard(SYMBOLS[I]);

  WriteLn;
  WriteLn('Summary: ', TotalTests, ' tests, ',
    PassedTests, ' passed, ', FailedTests, ' failed, ',
    SkippedTests, ' skipped');

  if FailedTests > 0 then
    Halt(1);
end.
