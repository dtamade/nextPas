program test_cert_utils_generate_selfsigned_ed25519_keygen_family_contract;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  fafafa.ssl,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.cert.utils,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.x509v3,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.evp;

type
  TInstallFailureWrapper = procedure;

var
  GLib: ISSLLibrary = nil;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;
  GOriginalEVPPKeyCtxNewId: TEVP_PKEY_CTX_new_id = nil;
  GOriginalEVPPKeygenInit: TEVP_PKEY_keygen_init = nil;
  GOriginalEVPPKeygen: TEVP_PKEY_keygen = nil;
  GOriginalEVPPKeyCtxFree: TEVP_PKEY_CTX_free = nil;

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
  Result.KeyType := ktEd25519;
  Result.CommonName := 'selfsigned-ed25519-keygen-family-contract.local';
  Result.Organization := 'fafafa.ssl contract';
  Result.ValidDays := 30;
end;

procedure WarmupGenerateSelfSigned(const AOptions: TCertGenOptions);
var
  LCertPEM: string;
  LKeyPEM: string;
begin
  if not TCertificateUtils.GenerateSelfSigned(AOptions, LCertPEM, LKeyPEM) then
    raise Exception.Create('GenerateSelfSigned warmup returned False');
  if (LCertPEM = '') or (LKeyPEM = '') then
    raise Exception.Create('GenerateSelfSigned warmup returned empty PEM output');
end;

procedure RestoreEd25519KeygenHelpers;
begin
  EVP_PKEY_CTX_new_id := GOriginalEVPPKeyCtxNewId;
  EVP_PKEY_keygen_init := GOriginalEVPPKeygenInit;
  EVP_PKEY_keygen := GOriginalEVPPKeygen;
  EVP_PKEY_CTX_free := GOriginalEVPPKeyCtxFree;
end;

function DisableEd25519KeygenInitAfterContextCreate(
  AId: Integer;
  AEngine: PENGINE
): PEVP_PKEY_CTX; cdecl;
begin
  Result := GOriginalEVPPKeyCtxNewId(AId, AEngine);
  if (AId = EVP_PKEY_ED25519) and (Result <> nil) then
    EVP_PKEY_keygen_init := nil;
end;

function DisableEd25519KeygenAfterInit(ACtx: PEVP_PKEY_CTX): Integer; cdecl;
begin
  Result := GOriginalEVPPKeygenInit(ACtx);
  if Result = 1 then
    EVP_PKEY_keygen := nil;
end;

function DisableEd25519ContextFreeAfterKeygen(
  ACtx: PEVP_PKEY_CTX;
  var APKey: PEVP_PKEY
): Integer; cdecl;
begin
  Result := GOriginalEVPPKeygen(ACtx, APKey);
  if (Result = 1) and (APKey <> nil) then
    EVP_PKEY_CTX_free := nil;
end;

procedure InstallEd25519KeygenInitFailureWrapper;
begin
  RestoreEd25519KeygenHelpers;
  EVP_PKEY_CTX_new_id := @DisableEd25519KeygenInitAfterContextCreate;
end;

procedure InstallEd25519KeygenFailureWrapper;
begin
  RestoreEd25519KeygenHelpers;
  EVP_PKEY_keygen_init := @DisableEd25519KeygenAfterInit;
end;

procedure InstallEd25519ContextFreeFailureWrapper;
begin
  RestoreEd25519KeygenHelpers;
  EVP_PKEY_keygen := @DisableEd25519ContextFreeAfterKeygen;
end;

procedure AssertGenerateSelfSignedControlledFailure(
  const AName: string;
  const AOptions: TCertGenOptions;
  AInstallFailureWrapper: TInstallFailureWrapper
);
var
  LRaised: Boolean;
  LControlled: Boolean;
  LDetail: string;
  LCertPEM: string;
  LKeyPEM: string;
  LTryRaised: Boolean;
  LTryDetail: string;
  LTryResult: Boolean;
begin
  AInstallFailureWrapper;

  LRaised := False;
  LControlled := False;
  LDetail := '';
  LCertPEM := '';
  LKeyPEM := '';
  try
    TCertificateUtils.GenerateSelfSigned(AOptions, LCertPEM, LKeyPEM);
  except
    on E: Exception do
    begin
      LRaised := True;
      LControlled := E is ESSLCertError;
      LDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' should raise', LRaised,
    'expected GenerateSelfSigned(...) to fail');
  AssertTrue(AName + ' should raise controlled ESSLCertError', LControlled, LDetail);

  AInstallFailureWrapper;

  LTryRaised := False;
  LTryDetail := '';
  LTryResult := True;
  LCertPEM := 'sentinel-cert';
  LKeyPEM := 'sentinel-key';
  try
    LTryResult := TCertificateUtils.TryGenerateSelfSigned(AOptions, LCertPEM, LKeyPEM);
  except
    on E: Exception do
    begin
      LTryRaised := True;
      LTryDetail := E.ClassName + ': ' + E.Message;
    end;
  end;

  AssertTrue(AName + ' TryGenerateSelfSigned should not raise', not LTryRaised, LTryDetail);
  AssertTrue(AName + ' TryGenerateSelfSigned should return False', not LTryResult,
    'expected TryGenerateSelfSigned to return False');
  AssertTrue(AName + ' TryGenerateSelfSigned should clear cert output', LCertPEM = '',
    'expected cleared certificate output');
  AssertTrue(AName + ' TryGenerateSelfSigned should clear key output', LKeyPEM = '',
    'expected cleared key output');
end;

procedure TestGenerateSelfSignedShouldFailGracefullyWhenEd25519KeygenInitBecomesUnavailable;
var
  LOptions: TCertGenOptions;
begin
  WriteLn;
  WriteLn('=== Certificate utils GenerateSelfSigned Ed25519 EVP_PKEY_keygen_init delayed-loss guard ===');

  LOptions := BuildOptions;
  AssertGenerateSelfSignedControlledFailure(
    'GenerateSelfSigned when Ed25519 EVP_PKEY_keygen_init becomes unavailable',
    LOptions,
    @InstallEd25519KeygenInitFailureWrapper
  );
end;

procedure TestGenerateSelfSignedShouldFailGracefullyWhenEd25519KeygenBecomesUnavailable;
var
  LOptions: TCertGenOptions;
begin
  WriteLn;
  WriteLn('=== Certificate utils GenerateSelfSigned Ed25519 EVP_PKEY_keygen delayed-loss guard ===');

  LOptions := BuildOptions;
  AssertGenerateSelfSignedControlledFailure(
    'GenerateSelfSigned when Ed25519 EVP_PKEY_keygen becomes unavailable',
    LOptions,
    @InstallEd25519KeygenFailureWrapper
  );
end;

procedure TestGenerateSelfSignedShouldFailGracefullyWhenEd25519ContextFreeBecomesUnavailable;
var
  LOptions: TCertGenOptions;
begin
  WriteLn;
  WriteLn('=== Certificate utils GenerateSelfSigned Ed25519 EVP_PKEY_CTX_free delayed-loss guard ===');

  LOptions := BuildOptions;
  AssertGenerateSelfSignedControlledFailure(
    'GenerateSelfSigned when Ed25519 EVP_PKEY_CTX_free becomes unavailable',
    LOptions,
    @InstallEd25519ContextFreeFailureWrapper
  );
end;

begin
  WriteLn('========================================');
  WriteLn('Certificate Utils GenerateSelfSigned Ed25519 Keygen Family Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('certificate utils selfsigned Ed25519 keygen family contract',
        'failed to initialize OpenSSL library');

    if SkippedTests = 0 then
    begin
      LoadOpenSSLCore();
      LoadOpenSSLBIO();
      LoadOpenSSLX509();
      LoadX509V3Functions(GetCryptoLibHandle);
      if not LoadOpenSSLPEM(GetCryptoLibHandle) then
        raise Exception.Create('failed to load PEM support');
      if not LoadEVP(GetCryptoLibHandle) then
        raise Exception.Create('failed to load EVP support');
    end;

    if SkippedTests = 0 then
    begin
      if (not Assigned(EVP_PKEY_CTX_new_id)) or
         (not Assigned(EVP_PKEY_keygen_init)) or
         (not Assigned(EVP_PKEY_keygen)) or
         (not Assigned(EVP_PKEY_CTX_free)) or
         (not Assigned(EVP_PKEY_free)) then
      begin
        MarkSkip('certificate utils selfsigned Ed25519 keygen family contract',
          'required baseline Ed25519 keygen helpers are unavailable');
      end
      else
      begin
        WarmupGenerateSelfSigned(BuildOptions);

        GOriginalEVPPKeyCtxNewId := EVP_PKEY_CTX_new_id;
        GOriginalEVPPKeygenInit := EVP_PKEY_keygen_init;
        GOriginalEVPPKeygen := EVP_PKEY_keygen;
        GOriginalEVPPKeyCtxFree := EVP_PKEY_CTX_free;
        try
          TestGenerateSelfSignedShouldFailGracefullyWhenEd25519KeygenInitBecomesUnavailable;
          TestGenerateSelfSignedShouldFailGracefullyWhenEd25519KeygenBecomesUnavailable;
          TestGenerateSelfSignedShouldFailGracefullyWhenEd25519ContextFreeBecomesUnavailable;
        finally
          RestoreEd25519KeygenHelpers;
        end;
      end;
    end;

    WriteLn;
    WriteLn('========================================');
    WriteLn('Summary');
    WriteLn('========================================');
    WriteLn('Total tests: ', TotalTests);
    WriteLn('Passed: ', PassedTests);
    WriteLn('Failed: ', FailedTests);
    WriteLn('Skipped: ', SkippedTests);

    if FailedTests > 0 then
      Halt(1);
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('[FATAL] ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
