program test_cert_utils_generate_selfsigned_ec_keygen_family_contract;

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
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.ec,
  nextpas.core.tls.openssl.api.obj;

type
  TInstallFailureWrapper = procedure;

var
  GLib: ISSLLibrary = nil;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;
  GOriginalOBJTxt2Nid: TOBJ_txt2nid = nil;
  GOriginalECKeyNewByCurveName: TEC_KEY_new_by_curve_name = nil;
  GOriginalECKeyGenerateKey: TEC_KEY_generate_key = nil;
  GOriginalEVPPKeyNew: TEVP_PKEY_new = nil;
  GOriginalEVPPKeyAssign: TEVP_PKEY_assign = nil;
  GOriginalEVPPKeyFree: TEVP_PKEY_free = nil;
  GOriginalECKeyFree: TEC_KEY_free = nil;

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
  Result.KeyType := ktECDSA;
  Result.ECCurve := 'prime256v1';
  Result.CommonName := 'selfsigned-ec-keygen-family-contract.local';
  Result.Organization := 'fafafa.ssl contract';
  Result.ValidDays := 30;
end;

procedure AssertECDSABaselineGenerates;
var
  LOptions: TCertGenOptions;
  LCertPEM: string;
  LKeyPEM: string;
begin
  WriteLn;
  WriteLn('=== Certificate utils GenerateSelfSigned ECDSA baseline contract ===');

  LOptions := BuildOptions;
  try
    AssertTrue('GenerateSelfSigned(ECDSA) should succeed',
      TCertificateUtils.GenerateSelfSigned(LOptions, LCertPEM, LKeyPEM));
  except
    on E: Exception do
    begin
      AssertTrue('GenerateSelfSigned(ECDSA) should succeed', False,
        E.ClassName + ': ' + E.Message);
      Exit;
    end;
  end;

  AssertTrue('ECDSA certificate PEM should contain BEGIN CERTIFICATE',
    Pos('BEGIN CERTIFICATE', LCertPEM) > 0);
  AssertTrue('ECDSA private key PEM should be non-empty',
    LKeyPEM <> '');
  AssertTrue('ECDSA private key PEM should contain EC or generic private key header',
    (Pos('BEGIN EC PRIVATE KEY', LKeyPEM) > 0) or
    (Pos('BEGIN PRIVATE KEY', LKeyPEM) > 0),
    'Unexpected key header');
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

procedure RestoreECKeygenHelpers;
begin
  OBJ_txt2nid := GOriginalOBJTxt2Nid;
  EC_KEY_new_by_curve_name := GOriginalECKeyNewByCurveName;
  EC_KEY_generate_key := GOriginalECKeyGenerateKey;
  EVP_PKEY_new := GOriginalEVPPKeyNew;
  EVP_PKEY_assign := GOriginalEVPPKeyAssign;
  EVP_PKEY_free := GOriginalEVPPKeyFree;
  EC_KEY_free := GOriginalECKeyFree;
end;

function DisableECKeyNewAfterCurveLookup(const AName: PAnsiChar): Integer; cdecl;
begin
  Result := GOriginalOBJTxt2Nid(AName);
  if Result <> NID_undef then
    EC_KEY_new_by_curve_name := nil;
end;

function DisableECGenerateAfterKeyAllocate(ANID: Integer): PEC_KEY; cdecl;
begin
  Result := GOriginalECKeyNewByCurveName(ANID);
  if Result <> nil then
    EC_KEY_generate_key := nil;
end;

function DisableEVPPKeyNewAfterECGenerate(AKey: PEC_KEY): Integer; cdecl;
begin
  Result := GOriginalECKeyGenerateKey(AKey);
  if Result = 1 then
    EVP_PKEY_new := nil;
end;

function DisableEVPPKeyAssignAfterContainerCreate: PEVP_PKEY; cdecl;
begin
  Result := GOriginalEVPPKeyNew();
  if Result <> nil then
    EVP_PKEY_assign := nil;
end;

function FailAssignAndDisableEVPPKeyFree(
  APKey: PEVP_PKEY;
  AType: Integer;
  AKey: Pointer
): Integer; cdecl;
begin
  if (APKey <> nil) and (AType = EVP_PKEY_EC) and (AKey <> nil) then
    EVP_PKEY_free := nil;
  Result := 0;
end;

function FailAssignAndDisableECKeyFree(
  APKey: PEVP_PKEY;
  AType: Integer;
  AKey: Pointer
): Integer; cdecl;
begin
  if (APKey <> nil) and (AType = EVP_PKEY_EC) and (AKey <> nil) then
    EC_KEY_free := nil;
  Result := 0;
end;

procedure InstallCurveLookupFailure;
begin
  RestoreECKeygenHelpers;
  OBJ_txt2nid := nil;
end;

procedure InstallECKeyNewFailureWrapper;
begin
  RestoreECKeygenHelpers;
  OBJ_txt2nid := @DisableECKeyNewAfterCurveLookup;
end;

procedure InstallECGenerateFailureWrapper;
begin
  RestoreECKeygenHelpers;
  EC_KEY_new_by_curve_name := @DisableECGenerateAfterKeyAllocate;
end;

procedure InstallEVPPKeyNewFailureWrapper;
begin
  RestoreECKeygenHelpers;
  EC_KEY_generate_key := @DisableEVPPKeyNewAfterECGenerate;
end;

procedure InstallEVPPKeyAssignFailureWrapper;
begin
  RestoreECKeygenHelpers;
  EVP_PKEY_new := @DisableEVPPKeyAssignAfterContainerCreate;
end;

procedure InstallEVPPKeyFreeFailureWrapper;
begin
  RestoreECKeygenHelpers;
  EVP_PKEY_assign := @FailAssignAndDisableEVPPKeyFree;
end;

procedure InstallECKeyFreeFailureWrapper;
begin
  RestoreECKeygenHelpers;
  EVP_PKEY_assign := @FailAssignAndDisableECKeyFree;
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

procedure TestGenerateSelfSignedShouldFailGracefullyWhenCurveLookupHelperIsUnavailable;
var
  LOptions: TCertGenOptions;
begin
  WriteLn;
  WriteLn('=== Certificate utils GenerateSelfSigned ECDSA OBJ_txt2nid family guard ===');

  LOptions := BuildOptions;
  AssertGenerateSelfSignedControlledFailure(
    'GenerateSelfSigned when ECDSA curve lookup helper is unavailable',
    LOptions,
    @InstallCurveLookupFailure
  );
end;

procedure TestGenerateSelfSignedShouldFailGracefullyWhenECKeyNewBecomesUnavailable;
var
  LOptions: TCertGenOptions;
begin
  WriteLn;
  WriteLn('=== Certificate utils GenerateSelfSigned ECDSA EC_KEY_new_by_curve_name delayed-loss guard ===');

  LOptions := BuildOptions;
  AssertGenerateSelfSignedControlledFailure(
    'GenerateSelfSigned when ECDSA EC_KEY_new_by_curve_name becomes unavailable',
    LOptions,
    @InstallECKeyNewFailureWrapper
  );
end;

procedure TestGenerateSelfSignedShouldFailGracefullyWhenECGenerateBecomesUnavailable;
var
  LOptions: TCertGenOptions;
begin
  WriteLn;
  WriteLn('=== Certificate utils GenerateSelfSigned ECDSA EC_KEY_generate_key delayed-loss guard ===');

  LOptions := BuildOptions;
  AssertGenerateSelfSignedControlledFailure(
    'GenerateSelfSigned when ECDSA EC_KEY_generate_key becomes unavailable',
    LOptions,
    @InstallECGenerateFailureWrapper
  );
end;

procedure TestGenerateSelfSignedShouldFailGracefullyWhenEVPPKeyNewBecomesUnavailable;
var
  LOptions: TCertGenOptions;
begin
  WriteLn;
  WriteLn('=== Certificate utils GenerateSelfSigned ECDSA EVP_PKEY_new delayed-loss guard ===');

  LOptions := BuildOptions;
  AssertGenerateSelfSignedControlledFailure(
    'GenerateSelfSigned when ECDSA EVP_PKEY_new becomes unavailable',
    LOptions,
    @InstallEVPPKeyNewFailureWrapper
  );
end;

procedure TestGenerateSelfSignedShouldFailGracefullyWhenEVPPKeyAssignBecomesUnavailable;
var
  LOptions: TCertGenOptions;
begin
  WriteLn;
  WriteLn('=== Certificate utils GenerateSelfSigned ECDSA EVP_PKEY_assign delayed-loss guard ===');

  LOptions := BuildOptions;
  AssertGenerateSelfSignedControlledFailure(
    'GenerateSelfSigned when ECDSA EVP_PKEY_assign becomes unavailable',
    LOptions,
    @InstallEVPPKeyAssignFailureWrapper
  );
end;

procedure TestGenerateSelfSignedShouldFailGracefullyWhenEVPPKeyFreeBecomesUnavailable;
var
  LOptions: TCertGenOptions;
begin
  WriteLn;
  WriteLn('=== Certificate utils GenerateSelfSigned ECDSA EVP_PKEY_free delayed-loss guard ===');

  LOptions := BuildOptions;
  AssertGenerateSelfSignedControlledFailure(
    'GenerateSelfSigned when ECDSA EVP_PKEY_free becomes unavailable',
    LOptions,
    @InstallEVPPKeyFreeFailureWrapper
  );
end;

procedure TestGenerateSelfSignedShouldFailGracefullyWhenECKeyFreeBecomesUnavailable;
var
  LOptions: TCertGenOptions;
begin
  WriteLn;
  WriteLn('=== Certificate utils GenerateSelfSigned ECDSA EC_KEY_free delayed-loss guard ===');

  LOptions := BuildOptions;
  AssertGenerateSelfSignedControlledFailure(
    'GenerateSelfSigned when ECDSA EC_KEY_free becomes unavailable',
    LOptions,
    @InstallECKeyFreeFailureWrapper
  );
end;

begin
  WriteLn('========================================');
  WriteLn('Certificate Utils GenerateSelfSigned EC Keygen Family Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('certificate utils selfsigned EC keygen family contract',
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
      if not LoadECFunctions(GetCryptoLibHandle) then
        raise Exception.Create('failed to load EC support');
      LoadOBJModule(GetCryptoLibHandle);
    end;

    if SkippedTests = 0 then
    begin
      if (not Assigned(OBJ_txt2nid)) or
         (not Assigned(EC_KEY_new_by_curve_name)) or
         (not Assigned(EC_KEY_generate_key)) or
         (not Assigned(EVP_PKEY_new)) or
         (not Assigned(EVP_PKEY_assign)) or
         (not Assigned(EVP_PKEY_free)) or
         (not Assigned(EC_KEY_free)) then
      begin
        MarkSkip('certificate utils selfsigned EC keygen family contract',
          'required baseline EC keygen helpers are unavailable');
      end
      else
      begin
        AssertECDSABaselineGenerates;
        WarmupGenerateSelfSigned(BuildOptions);

        GOriginalOBJTxt2Nid := OBJ_txt2nid;
        GOriginalECKeyNewByCurveName := EC_KEY_new_by_curve_name;
        GOriginalECKeyGenerateKey := EC_KEY_generate_key;
        GOriginalEVPPKeyNew := EVP_PKEY_new;
        GOriginalEVPPKeyAssign := EVP_PKEY_assign;
        GOriginalEVPPKeyFree := EVP_PKEY_free;
        GOriginalECKeyFree := EC_KEY_free;
        try
          TestGenerateSelfSignedShouldFailGracefullyWhenCurveLookupHelperIsUnavailable;
          TestGenerateSelfSignedShouldFailGracefullyWhenECKeyNewBecomesUnavailable;
          TestGenerateSelfSignedShouldFailGracefullyWhenECGenerateBecomesUnavailable;
          TestGenerateSelfSignedShouldFailGracefullyWhenEVPPKeyNewBecomesUnavailable;
          TestGenerateSelfSignedShouldFailGracefullyWhenEVPPKeyAssignBecomesUnavailable;
          TestGenerateSelfSignedShouldFailGracefullyWhenEVPPKeyFreeBecomesUnavailable;
          TestGenerateSelfSignedShouldFailGracefullyWhenECKeyFreeBecomesUnavailable;
        finally
          RestoreECKeygenHelpers;
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
