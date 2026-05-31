program test_cert_utils_generate_signed_symbol_contracts;

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
  GCACertPEM: string = '';
  GCAKeyPEM: string = '';

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

procedure PrepareCAMaterial;
var
  LCAOptions: TCertGenOptions;
begin
  LCAOptions := TCertificateUtils.DefaultGenOptions;
  LCAOptions.CommonName := 'signed-contract-root.local';
  LCAOptions.Organization := 'fafafa.ssl contract';
  LCAOptions.IsCA := True;
  LCAOptions.ValidDays := 30;
  if not TCertificateUtils.TryGenerateSelfSigned(LCAOptions, GCACertPEM, GCAKeyPEM) then
    raise Exception.Create('Failed to generate CA material for signed contracts');
end;

procedure TestSymbolGuard(const AEntry: TSymbolEntry);
var
  LLeafOptions: TCertGenOptions;
  LSaved: Pointer;
  LCertPEM, LKeyPEM: string;
  LRaised, LControlled: Boolean;
  LTryResult: Boolean;
  LDetail: string;
begin
  if AEntry.Ptr^ = nil then
  begin
    MarkSkip(AEntry.Name, 'symbol not available');
    Exit;
  end;

  LLeafOptions := TCertificateUtils.DefaultGenOptions;
  LLeafOptions.CommonName := 'signed-leaf.local';
  LLeafOptions.Organization := 'fafafa.ssl contract';
  LLeafOptions.IsCA := False;
  LLeafOptions.ValidDays := 30;

  // Warmup
  if not TCertificateUtils.TryGenerateSigned(LLeafOptions, GCACertPEM, GCAKeyPEM, LCertPEM, LKeyPEM) then
  begin
    MarkSkip(AEntry.Name, 'warmup TryGenerateSigned failed');
    Exit;
  end;

  LSaved := AEntry.Ptr^;
  AEntry.Ptr^ := nil;
  try
    LRaised := False;
    LControlled := False;
    LDetail := '';
    LCertPEM := '';
    LKeyPEM := '';
    try
      TCertificateUtils.GenerateSigned(LLeafOptions, GCACertPEM, GCAKeyPEM, LCertPEM, LKeyPEM);
    except
      on E: Exception do
      begin
        LRaised := True;
        LControlled := E is ESSLCertError;
        LDetail := E.ClassName + ': ' + E.Message;
      end;
    end;

    AssertTrue(AEntry.Name + ' should raise on nil', LRaised,
      'expected GenerateSigned to fail');
    AssertTrue(AEntry.Name + ' should raise ESSLCertError', LControlled, LDetail);

    LCertPEM := 'sentinel';
    LKeyPEM := 'sentinel';
    LRaised := False;
    try
      LTryResult := TCertificateUtils.TryGenerateSigned(LLeafOptions, GCACertPEM, GCAKeyPEM, LCertPEM, LKeyPEM);
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
  SYMBOLS: array[0..11] of TSymbolEntry = (
    (Name: 'ASN1_INTEGER_set'; Ptr: @ASN1_INTEGER_set),
    (Name: 'BIO_read'; Ptr: @BIO_read),
    (Name: 'EVP_PKEY_free'; Ptr: @EVP_PKEY_free),
    (Name: 'X509_get_notAfter'; Ptr: @X509_get_notAfter),
    (Name: 'X509_get_notBefore'; Ptr: @X509_get_notBefore),
    (Name: 'X509_get_serialNumber'; Ptr: @X509_get_serialNumber),
    (Name: 'X509_get_subject_name'; Ptr: @X509_get_subject_name),
    (Name: 'X509_gmtime_adj'; Ptr: @X509_gmtime_adj),
    (Name: 'X509_new'; Ptr: @X509_new),
    (Name: 'X509_set_issuer_name'; Ptr: @X509_set_issuer_name),
    (Name: 'X509_set_pubkey'; Ptr: @X509_set_pubkey),
    (Name: 'X509_set_version'; Ptr: @X509_set_version)
  );

var
  I: Integer;
begin
  WriteLn('========================================');
  WriteLn('GenerateSigned Symbol Guard Contracts (consolidated)');
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

  PrepareCAMaterial;

  for I := Low(SYMBOLS) to High(SYMBOLS) do
    TestSymbolGuard(SYMBOLS[I]);

  WriteLn;
  WriteLn('Summary: ', TotalTests, ' tests, ',
    PassedTests, ' passed, ', FailedTests, ' failed, ',
    SkippedTests, ' skipped');

  if FailedTests > 0 then
    Halt(1);
end.
