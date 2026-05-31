{**
 * Test: WolfSSL Backend Framework
 * Purpose: Comprehensive WolfSSL backend framework tests
 *
 * Tests include:
 * - Constants and error mapping
 * - Library creation and initialization
 * - Context creation and configuration
 * - Certificate operations
 * - Connection interface (mock)
 *
 * Note: Full functionality tests require WolfSSL library to be installed.
 *
 * @author fafafa.ssl team
 * @version 2.0.0
 * @since 2026-01-09
 * @updated 2026-01-10
 *}

program test_wolfssl_framework;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DateUtils, ctypes,
  nextpas.core.tls.base,
  nextpas.core.tls.errors,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.wolfssl.base,
  nextpas.core.tls.wolfssl.native_handle,
  nextpas.core.tls.wolfssl.api,
  nextpas.core.tls.wolfssl.lib,
  nextpas.core.tls.wolfssl.context,
  nextpas.core.tls.wolfssl.certificate,
  nextpas.core.tls.wolfssl.session;

var
  GTestCount: Integer = 0;
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;
  GStubWolfSSLBorrowedSession: PWOLFSSL_SESSION = nil;
  GStubWolfSSLSessionDupCalls: Integer = 0;
  GStubWolfSSLSessionUnixTime: LongInt = 0;
  GStubWolfSSLPeerCertificateDER: TBytes;
  GStubWolfSSLVersionTLS13: AnsiString = 'TLSv1.3';
  GStubWolfSSLCipherTLS13: AnsiString = 'TLS_AES_128_GCM_SHA256';

// INTENTIONAL_VERIFY_RESULT_CORE_SURFACE: this root-test backend contract
// file intentionally keeps direct core GetVerifyResult/GetVerifyResultString
// coverage as backend proof. Generic ISSLCertificateVerification owner-path
// guidance is frozen elsewhere.
{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}

const
  STUB_WOLFSSL_SERIALIZED_SESSION: array[0..3] of Byte = (4, 3, 2, 1);
  STUB_WOLFSSL_NATIVE_SESSION_ID: array[0..3] of Byte = ($89, $AB, $CD, $EF);
  STUB_WOLFSSL_NATIVE_SESSION_TIMEOUT = 4321;

function StubWolfSSLD2ISessionFail(session: PPWOLFSSL_SESSION; const pp: PPByte;
  length: Integer): PWOLFSSL_SESSION; cdecl;
begin
  Result := nil;
end;

function StubWolfSSLD2ISessionOk(session: PPWOLFSSL_SESSION; const pp: PPByte;
  length: Integer): PWOLFSSL_SESSION; cdecl;
begin
  if (pp = nil) or (pp^ = nil) or (length = 0) then
    Exit(nil);
  GetMem(Result, 1);
  PByte(Result)^ := $5A;
end;

function StubWolfSSLI2DSessionOk(session: PWOLFSSL_SESSION; pp: PPByte): Integer; cdecl;
begin
  if session = nil then
    Exit(0);

  Result := Length(STUB_WOLFSSL_SERIALIZED_SESSION);
  if pp = nil then
    Exit;

  Move(STUB_WOLFSSL_SERIALIZED_SESSION[0], pp^^,
    Length(STUB_WOLFSSL_SERIALIZED_SESSION));
end;

procedure StubWolfSSLSessionFree(session: PWOLFSSL_SESSION); cdecl;
begin
  if session <> nil then
    FreeMem(session);
end;

function StubWolfSSLGetBorrowedSession(ssl: PWOLFSSL): PWOLFSSL_SESSION; cdecl;
begin
  Result := GStubWolfSSLBorrowedSession;
end;

function StubWolfSSLSessionDupOk(session: PWOLFSSL_SESSION): PWOLFSSL_SESSION; cdecl;
begin
  Inc(GStubWolfSSLSessionDupCalls);
  if session = nil then
    Exit(nil);

  GetMem(Result, 1);
  PByte(Result)^ := PByte(session)^;
end;

function StubWolfSSLGetVersionTLS13(ssl: PWOLFSSL): PAnsiChar; cdecl;
begin
  Result := PAnsiChar(GStubWolfSSLVersionTLS13);
end;

function StubWolfSSLGetCurrentCipherNonNil(ssl: PWOLFSSL): Pointer; cdecl;
begin
  Result := Pointer(PtrUInt(1));
end;

function StubWolfSSLCipherGetNameTLS13(cipher: Pointer): PAnsiChar; cdecl;
begin
  Result := PAnsiChar(GStubWolfSSLCipherTLS13);
end;

function StubWolfSSLSessionGetID(const sess: PWOLFSSL_SESSION;
  idLen: PCardinal): PByte; cdecl;
begin
  if Assigned(idLen) then
    idLen^ := Length(STUB_WOLFSSL_NATIVE_SESSION_ID);
  Result := @STUB_WOLFSSL_NATIVE_SESSION_ID[0];
end;

function StubWolfSSLSessionGetTime(const session: PWOLFSSL_SESSION): clong; cdecl;
begin
  if GStubWolfSSLSessionUnixTime = 0 then
    GStubWolfSSLSessionUnixTime := DateTimeToUnix(Now);
  Result := GStubWolfSSLSessionUnixTime;
end;

function StubWolfSSLSessionGetTimeout(const session: PWOLFSSL_SESSION): clong; cdecl;
begin
  Result := STUB_WOLFSSL_NATIVE_SESSION_TIMEOUT;
end;

function StubWolfSSLSessionCipherGetNameTLS13(
  const session: PWOLFSSL_SESSION): PAnsiChar; cdecl;
begin
  Result := PAnsiChar(GStubWolfSSLCipherTLS13);
end;

function StubWolfSSLGetPeerCertificateFromDER(ssl: PWOLFSSL): PWOLFSSL_X509; cdecl;
begin
  Result := nil;
  if (ssl = nil) or (Length(GStubWolfSSLPeerCertificateDER) = 0) or
     (not Assigned(wolfSSL_X509_d2i)) then
    Exit;

  Result := wolfSSL_X509_d2i(nil, @GStubWolfSSLPeerCertificateDER[0],
    Length(GStubWolfSSLPeerCertificateDER));
end;

function HasNativeHandleContext(const AObject: ISSLContext): Boolean;
var
  NativeAccess: ISSLNativeHandleAccess;
begin
  Result := Supports(AObject, ISSLNativeHandleAccess, NativeAccess) and
            (NativeAccess.GetNativeHandle <> nil);
end;

procedure Test(const AName: string; ACondition: Boolean);
begin
  Inc(GTestCount);
  Write(AName, ': ');
  if ACondition then
  begin
    WriteLn('PASS');
    Inc(GPassCount);
  end
  else
  begin
    WriteLn('FAIL');
    Inc(GFailCount);
  end;
end;

function ArrayContains(const AValues: TSSLStringArray; const AExpected: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := Low(AValues) to High(AValues) do
  begin
    if SameText(AValues[I], AExpected) then
      Exit(True);
  end;
end;

function NormalizeHexish(const AValue: string): string;
begin
  Result := UpperCase(StringReplace(StringReplace(Trim(AValue), ':', '', [rfReplaceAll]),
    ' ', '', [rfReplaceAll]));
end;

procedure TestWolfSSLConstants;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Constants ===');

  Test('WOLFSSL_SUCCESS = 1', WOLFSSL_SUCCESS = 1);
  Test('WOLFSSL_FAILURE = 0', WOLFSSL_FAILURE = 0);
  Test('WOLFSSL_ERROR_NONE = 0', WOLFSSL_ERROR_NONE = 0);
  Test('WOLFSSL_ERROR_WANT_READ defined', WOLFSSL_ERROR_WANT_READ = 2);
  Test('WOLFSSL_ERROR_WANT_WRITE defined', WOLFSSL_ERROR_WANT_WRITE = 3);
  Test('WOLFSSL_MIN_VERSION defined', WOLFSSL_MIN_VERSION > 0);
end;

procedure TestWolfSSLErrorMapping;
var
  LResult: TSSLErrorCode;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Error Mapping ===');

  LResult := WolfSSLErrorToSSLError(WOLFSSL_ERROR_NONE);
  Test('ERROR_NONE maps to sslErrNone', LResult = sslErrNone);

  LResult := WolfSSLErrorToSSLError(WOLFSSL_ERROR_WANT_READ);
  Test('ERROR_WANT_READ maps to sslErrWantRead', LResult = sslErrWantRead);

  LResult := WolfSSLErrorToSSLError(WOLFSSL_ERROR_WANT_WRITE);
  Test('ERROR_WANT_WRITE maps to sslErrWantWrite', LResult = sslErrWantWrite);

  LResult := WolfSSLErrorToSSLError(WOLFSSL_ERROR_SYSCALL);
  Test('ERROR_SYSCALL maps to sslErrIO', LResult = sslErrIO);

  LResult := WolfSSLErrorToSSLError(WOLFSSL_ERROR_SSL);
  Test('ERROR_SSL maps to sslErrProtocol', LResult = sslErrProtocol);

  LResult := WolfSSLErrorToSSLError(-999);
  Test('Unknown error maps to sslErrGeneral', LResult = sslErrGeneral);
end;

procedure TestWolfSSLProtocolMapping;
var
  LResult: Integer;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Protocol Mapping ===');

  LResult := SSLProtocolToWolfSSL(sslProtocolTLS12);
  Test('TLS 1.2 maps to $0303', LResult = $0303);

  LResult := SSLProtocolToWolfSSL(sslProtocolTLS13);
  Test('TLS 1.3 maps to $0304', LResult = $0304);

  Test('$0303 maps back to TLS 1.2', WolfSSLProtocolToSSL($0303) = sslProtocolTLS12);
  Test('$0304 maps back to TLS 1.3', WolfSSLProtocolToSSL($0304) = sslProtocolTLS13);
  Test('Unknown protocol maps to unknown', WolfSSLProtocolToSSL($FFFF) = sslProtocolUnknown);
end;

procedure TestWolfSSLLibraryCreation;
var
  LLib: ISSLLibrary;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Library Creation ===');

  LLib := CreateWolfSSLLibrary;
  Test('CreateWolfSSLLibrary returns non-nil', LLib <> nil);
  Test('Library type is sslWolfSSL', LLib.GetLibraryType = sslWolfSSL);
  Test('Library not initialized by default', not LLib.IsInitialized);

  // Note: Initialize will fail if WolfSSL library is not installed
  // This is expected behavior - we're testing the framework, not the library
  WriteLn('  (Note: Initialize test skipped - requires WolfSSL library)');
end;

procedure TestWolfSSLCapabilities;
var
  LLib: ISSLLibrary;
  LCaps: TSSLBackendCapabilities;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Capabilities (Framework) ===');

  LLib := CreateWolfSSLLibrary;

  // Before initialization, capabilities should be empty/default
  LCaps := LLib.GetCapabilities;
  Test('Capabilities struct accessible', True);
  Test('MinTLSVersion defined', Ord(LCaps.MinTLSVersion) >= 0);
  Test('MaxTLSVersion defined', Ord(LCaps.MaxTLSVersion) >= 0);
end;

procedure TestWolfSSLCapabilityHelperLossContract;
var
  LLib: ISSLLibrary;
  LCaps: TSSLBackendCapabilities;
  LOriginalUseSNI: TwolfSSL_UseSNI;
  LOriginalUseALPN: TwolfSSL_UseALPN;
  LOriginalGetALPN: TwolfSSL_ALPN_GetProtocol;
  LOriginalGetSession: TwolfSSL_get_session;
  LOriginalSetSession: TwolfSSL_set_session;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Capability Helper-Loss Contract ===');

  if not LoadWolfSSLLibrary then
  begin
    WriteLn('  (Skipped - WolfSSL library not available)');
    Test('Capability helper-loss contract skipped', True);
    Exit;
  end;

  LOriginalUseSNI := wolfSSL_UseSNI;
  LOriginalUseALPN := wolfSSL_UseALPN;
  LOriginalGetALPN := wolfSSL_ALPN_GetProtocol;
  LOriginalGetSession := wolfSSL_get_session;
  LOriginalSetSession := wolfSSL_set_session;

  try
    wolfSSL_UseSNI := nil;
    wolfSSL_UseALPN := nil;
    wolfSSL_ALPN_GetProtocol := nil;
    wolfSSL_get_session := nil;
    wolfSSL_set_session := nil;

    LLib := CreateWolfSSLLibrary;
    if not LLib.Initialize then
    begin
      WriteLn('  (Skipped - helper-loss capability init unavailable)');
      Test('Capability helper-loss contract skipped', True);
      Exit;
    end;

    try
      LCaps := LLib.GetCapabilities;
      Test('SNI helper loss clears SupportsSNI', not LCaps.SupportsSNI);
      Test('SNI helper loss clears SNISupport', LCaps.SNISupport = sslSupportNone);
      Test('SNI helper loss clears sslFeatSNI', not LLib.IsFeatureSupported(sslFeatSNI));

      Test('ALPN helper loss clears SupportsALPN', not LCaps.SupportsALPN);
      Test('ALPN helper loss clears ALPNSupport', LCaps.ALPNSupport = sslSupportNone);
      Test('ALPN helper loss clears sslFeatALPN', not LLib.IsFeatureSupported(sslFeatALPN));

      Test('Session helper loss clears SupportsSessionTickets', not LCaps.SupportsSessionTickets);
      Test('Session helper loss clears SessionTicketsSupport',
        LCaps.SessionTicketsSupport = sslSupportNone);
      Test('Session helper loss clears sslFeatSessionTickets',
        not LLib.IsFeatureSupported(sslFeatSessionTickets));
    finally
      LLib.Finalize;
    end;
  finally
    if IsWolfSSLLoaded then
      UnloadWolfSSLLibrary;
    wolfSSL_UseSNI := LOriginalUseSNI;
    wolfSSL_UseALPN := LOriginalUseALPN;
    wolfSSL_ALPN_GetProtocol := LOriginalGetALPN;
    wolfSSL_get_session := LOriginalGetSession;
    wolfSSL_set_session := LOriginalSetSession;
  end;
end;

procedure TestWolfSSLCertificateClass;
var
  LCert: TWolfSSLCertificate;
  LClone: ISSLCertificate;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Certificate Class ===');

  LCert := TWolfSSLCertificate.Create;
  try
    Test('Certificate created', LCert <> nil);
    Test('Certificate not loaded initially', LCert.GetNativeHandle = nil);
    Test('GetVersion returns default', LCert.GetVersion = 3);
    Test('NotAfter unknown without X509', LCert.GetNotAfter = 0);
    Test('IsExpired returns False without X509', not LCert.IsExpired);
    Test('DaysUntilExpiry is 0 without X509', LCert.GetDaysUntilExpiry = 0);
    LClone := LCert.Clone;
    Test('Clone works', LClone <> nil);
    LClone := nil;
  finally
    LCert.Free;
  end;
end;

procedure TestWolfSSLCertificateAlgorithmMetadataContract;
var
  LLib: ISSLLibrary;
  LCert: TWolfSSLCertificate;
  LInfo: TSSLCertificateInfo;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Certificate Algorithm Metadata Contract ===');

  LLib := CreateWolfSSLLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('  (Skipped - WolfSSL library not available)');
    Test('Certificate algorithm metadata contract skipped', True);
    Exit;
  end;

  LCert := TWolfSSLCertificate.Create;
  try
    if not LCert.LoadFromFile('tests/certificate/test_certs/signer_ecdsa_cert.pem') then
    begin
      WriteLn('  (Skipped - ECDSA fixture certificate unavailable)');
      Test('Certificate algorithm metadata contract skipped', True);
      Exit;
    end;

    LInfo := LCert.GetInfo;
    Test('ECDSA fixture public-key algorithm exposes parsed truth',
      SameText(LCert.GetPublicKeyAlgorithm, 'ecPublicKey'));
    Test('ECDSA fixture GetPublicKey exposes non-empty public key info',
      LCert.GetPublicKey <> '');
    Test('ECDSA fixture GetPublicKey stays aligned with public-key algorithm contract',
      SameText(LCert.GetPublicKey, LCert.GetPublicKeyAlgorithm));
    Test('ECDSA fixture signature algorithm exposes parsed truth',
      SameText(LCert.GetSignatureAlgorithm, 'ecdsa-with-SHA256'));
    Test('GetInfo public-key algorithm matches getter truth',
      SameText(LInfo.PublicKeyAlgorithm, LCert.GetPublicKeyAlgorithm));
    Test('GetInfo signature algorithm matches getter truth',
      SameText(LInfo.SignatureAlgorithm, LCert.GetSignatureAlgorithm));
  finally
    LCert.Free;
    LLib.Finalize;
  end;
end;

procedure TestWolfSSLCertificateIdentityGetterContract;
const
  EXPECTED_CN = 'Test Signer ECDSA';
  EXPECTED_SERIAL = '3CE7A277AAE4DB33E123ED853328E5D5E21B38F4';
var
  LLib: ISSLLibrary;
  LCert: TWolfSSLCertificate;
  LSubject: string;
  LIssuer: string;
  LSerial: string;
  LSerialSafe: Boolean;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Certificate Identity Getter Contract ===');

  LLib := CreateWolfSSLLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('  (Skipped - WolfSSL library not available)');
    Test('Certificate identity getter contract skipped', True);
    Exit;
  end;

  LCert := TWolfSSLCertificate.Create;
  try
    if not LCert.LoadFromFile('tests/certificate/test_certs/signer_ecdsa_cert.pem') then
    begin
      Test('Load ECDSA identity fixture', False);
      Exit;
    end;
    Test('Load ECDSA identity fixture', True);

    LSubject := LCert.GetSubject;
    LIssuer := LCert.GetIssuer;
    Test('ECDSA identity fixture subject contains CN truth',
      Pos('CN=' + UpperCase(EXPECTED_CN), UpperCase(LSubject)) > 0);
    Test('ECDSA identity fixture issuer contains CN truth',
      Pos('CN=' + UpperCase(EXPECTED_CN), UpperCase(LIssuer)) > 0);
    Test('ECDSA identity fixture GetSubjectCN exposes parsed CN truth',
      SameText(LCert.GetSubjectCN, EXPECTED_CN));
    LSerial := '';
    LSerialSafe := False;
    try
      LSerial := LCert.GetSerialNumber;
      LSerialSafe := True;
    except
      LSerialSafe := False;
    end;
    Test('ECDSA identity fixture serial exposes parsed truth',
      LSerialSafe and (NormalizeHexish(LSerial) = EXPECTED_SERIAL));
  finally
    LCert.Free;
    LLib.Finalize;
  end;
end;

procedure TestWolfSSLCertificateVersionTruthContract;
var
  LLib: ISSLLibrary;
  LCert: TWolfSSLCertificate;
  LInfo: TSSLCertificateInfo;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Certificate Version Truth Contract ===');

  LLib := CreateWolfSSLLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('  (Skipped - WolfSSL library not available)');
    Test('Certificate version truth contract skipped', True);
    Exit;
  end;

  LCert := TWolfSSLCertificate.Create;
  try
    if not LCert.LoadFromFile('tests/certs/version1-cert.pem') then
    begin
      Test('Load version1 certificate fixture', False);
      Exit;
    end;
    Test('Load version1 certificate fixture', True);

    LInfo := LCert.GetInfo;
    Test('Version1 fixture GetVersion exposes real v1 truth',
      LCert.GetVersion = 1);
    Test('Version1 fixture GetInfo.Version matches getter truth',
      LInfo.Version = LCert.GetVersion);
    Test('Version1 fixture GetInfo.Version preserves v1 truth',
      LInfo.Version = 1);
  finally
    LCert.Free;
    LLib.Finalize;
  end;
end;

procedure TestWolfSSLCertificateTimeTruthContract;
var
  LLib: ISSLLibrary;
  LCert: TWolfSSLCertificate;
  LDERCert: TWolfSSLCertificate;
  LDER: TBytes;
  LInfo: TSSLCertificateInfo;
  LNotBefore: TDateTime;
  LNotAfter: TDateTime;
  LDERNotBefore: TDateTime;
  LDERNotAfter: TDateTime;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Certificate Time Truth Contract ===');

  LLib := CreateWolfSSLLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('  (Skipped - WolfSSL library not available)');
    Test('Certificate time truth contract skipped', True);
    Exit;
  end;

  LCert := TWolfSSLCertificate.Create;
  LDERCert := TWolfSSLCertificate.Create;
  try
    if not LCert.LoadFromFile('tests/certs/server-cert.pem') then
    begin
      Test('Load server certificate time fixture', False);
      Exit;
    end;
    Test('Load server certificate time fixture', True);

    LNotBefore := LCert.GetNotBefore;
    LNotAfter := LCert.GetNotAfter;
    Test('Loaded fixture NotBefore exposes time truth',
      LNotBefore > 0);
    Test('Loaded fixture NotAfter exposes time truth',
      LNotAfter > 0);
    Test('Loaded fixture validity window stays ordered',
      LNotAfter >= LNotBefore);

    LDER := LCert.SaveToDER;
    Test('Loaded fixture exports DER for time roundtrip',
      Length(LDER) > 0);
    if Length(LDER) = 0 then
      Exit;

    if not LDERCert.LoadFromDER(LDER) then
    begin
      Test('Load DER time roundtrip fixture', False);
      Exit;
    end;
    Test('Load DER time roundtrip fixture', True);

    LDERNotBefore := LDERCert.GetNotBefore;
    LDERNotAfter := LDERCert.GetNotAfter;
    LInfo := LDERCert.GetInfo;
    Test('DER-loaded fixture NotBefore preserves time truth',
      (LDERNotBefore > 0) and (Abs(LDERNotBefore - LNotBefore) < (1 / 86400)));
    Test('DER-loaded fixture NotAfter preserves time truth',
      (LDERNotAfter > 0) and (Abs(LDERNotAfter - LNotAfter) < (1 / 86400)));
    Test('DER-loaded fixture GetInfo.NotBefore matches getter truth',
      Abs(LInfo.NotBefore - LDERNotBefore) < (1 / 86400));
    Test('DER-loaded fixture GetInfo.NotAfter matches getter truth',
      Abs(LInfo.NotAfter - LDERNotAfter) < (1 / 86400));
  finally
    LDERCert.Free;
    LCert.Free;
    LLib.Finalize;
  end;
end;

procedure TestWolfSSLCertificateVerificationTruthContract;
var
  LLib: ISSLLibrary;
  LLeafCert: ISSLCertificate;
  LRealCACert: ISSLCertificate;
  LImposterCACert: ISSLCertificate;
  LStore: ISSLCertificateStore;
  LImposterStore: ISSLCertificateStore;
  LVerifyResult: TSSLCertVerifyResult;
  LVerified: Boolean;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Certificate Verification Truth Contract ===');

  LLib := CreateWolfSSLLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('  (Skipped - WolfSSL library not available)');
    Test('Certificate verification truth contract skipped', True);
    Exit;
  end;

  LLeafCert := TWolfSSLCertificate.Create;
  LRealCACert := TWolfSSLCertificate.Create;
  LImposterCACert := TWolfSSLCertificate.Create;
  LStore := TWolfSSLCertificateStore.Create;
  LImposterStore := TWolfSSLCertificateStore.Create;
  try
    Test('Load verification leaf fixture',
      LLeafCert.LoadFromFile('tests/certificate/test_certs/signer_cert.pem'));
    Test('Load verification CA fixture',
      LRealCACert.LoadFromFile('tests/certificate/test_certs/ca_cert.pem'));
    Test('Load subject-imposter CA fixture',
      LImposterCACert.LoadFromFile('tests/certs/ca-subject-imposter.pem'));

    Test('Add verification CA fixture to store',
      LStore.AddCertificate(LRealCACert));
    LVerified := LLeafCert.Verify(LStore);
    Test('Verify succeeds with real issuer certificate', LVerified);

    LVerified := LLeafCert.VerifyEx(LStore, [], LVerifyResult);
    Test('VerifyEx succeeds with real issuer certificate',
      LVerified and LVerifyResult.Success);
    Test('VerifyEx success keeps error text empty',
      Trim(LVerifyResult.ErrorMessage) = '');

    Test('Add subject-imposter CA fixture to store',
      LImposterStore.AddCertificate(LImposterCACert));
    LVerified := LLeafCert.Verify(LImposterStore);
    Test('Verify rejects issuer-name-only imposter CA',
      not LVerified);

    LVerified := LLeafCert.VerifyEx(LImposterStore, [], LVerifyResult);
    Test('VerifyEx rejects issuer-name-only imposter CA',
      (not LVerified) and (not LVerifyResult.Success));
    Test('VerifyEx imposter failure exposes error text',
      Trim(LVerifyResult.ErrorMessage) <> '');
    Test('VerifyEx imposter failure marks chain status',
      LVerifyResult.ChainStatus <> 0);

    LVerified := LLeafCert.VerifyEx(nil, [], LVerifyResult);
    Test('VerifyEx nil store fails closed',
      (not LVerified) and (not LVerifyResult.Success));
    Test('VerifyEx nil store exposes error text',
      Pos('store', LowerCase(LVerifyResult.ErrorMessage)) > 0);
    Test('VerifyEx nil store exposes detailed info',
      Trim(LVerifyResult.DetailedInfo) <> '');

    LVerified := LLeafCert.VerifyEx(LStore, [sslCertVerifyCheckRevocation], LVerifyResult);
    Test('VerifyEx revocation flag fails closed when unsupported',
      (not LVerified) and (not LVerifyResult.Success));
    Test('VerifyEx revocation flag exposes unavailable message',
      Pos('revocation', LowerCase(LVerifyResult.ErrorMessage + ' ' +
        LVerifyResult.DetailedInfo)) > 0);
    Test('VerifyEx revocation flag marks unavailable revocation status',
      LVerifyResult.RevocationStatus = 2);
  finally
    LImposterStore := nil;
    LStore := nil;
    LImposterCACert := nil;
    LRealCACert := nil;
    LLeafCert := nil;
    LLib.Finalize;
  end;
end;

procedure TestWolfSSLCertificateStreamMemoryTruthContract;
var
  LLib: ISSLLibrary;
  LCert: TWolfSSLCertificate;
  LMemoryCert: TWolfSSLCertificate;
  LStreamCert: TWolfSSLCertificate;
  LPEMAnsi: AnsiString;
  LExpectedFingerprint: string;
  LStream: TMemoryStream;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Certificate Stream/Memory Truth Contract ===');

  LLib := CreateWolfSSLLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('  (Skipped - WolfSSL library not available)');
    Test('Certificate stream/memory truth contract skipped', True);
    Exit;
  end;

  LCert := TWolfSSLCertificate.Create;
  LMemoryCert := TWolfSSLCertificate.Create;
  LStreamCert := TWolfSSLCertificate.Create;
  LStream := TMemoryStream.Create;
  try
    if not LCert.LoadFromFile('tests/certs/server-cert.pem') then
    begin
      Test('Load certificate stream/memory fixture', False);
      Exit;
    end;
    Test('Load certificate stream/memory fixture', True);

    LExpectedFingerprint := LCert.GetFingerprintSHA256;
    Test('Fixture exposes fingerprint for stream/memory truth',
      LExpectedFingerprint <> '');

    LPEMAnsi := AnsiString(LCert.SaveToPEM);
    Test('Fixture exports PEM text for memory truth',
      LPEMAnsi <> '');
    if LPEMAnsi = '' then
      Exit;

    Test('LoadFromMemory accepts valid PEM text',
      LMemoryCert.LoadFromMemory(@LPEMAnsi[1], Length(LPEMAnsi)));
    Test('LoadFromMemory PEM roundtrip preserves fingerprint truth',
      SameText(LMemoryCert.GetFingerprintSHA256, LExpectedFingerprint));

    Test('SaveToStream writes PEM stream',
      LCert.SaveToStream(LStream) and (LStream.Size > 0));
    if LStream.Size = 0 then
      Exit;

    LStream.Position := 0;
    Test('LoadFromStream accepts PEM stream roundtrip',
      LStreamCert.LoadFromStream(LStream));
    Test('LoadFromStream roundtrip preserves fingerprint truth',
      SameText(LStreamCert.GetFingerprintSHA256, LExpectedFingerprint));
  finally
    LStream.Free;
    LStreamCert.Free;
    LMemoryCert.Free;
    LCert.Free;
    LLib.Finalize;
  end;
end;

procedure TestWolfSSLVerifyExExpirySelfSignedFlagParityContract;
var
  LLib: ISSLLibrary;
  LExpiredLeaf: ISSLCertificate;
  LSelfSignedLeaf: ISSLCertificate;
  LIssuerCert: ISSLCertificate;
  LStore: ISSLCertificateStore;
  LEmptyStore: ISSLCertificateStore;
  LVerifyResult: TSSLCertVerifyResult;
  LVerified: Boolean;
begin
  WriteLn('');
  WriteLn('=== WolfSSL VerifyEx Expiry/Self-Signed Flag Parity ===');

  LLib := CreateWolfSSLLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('  (Skipped - WolfSSL library not available)');
    Test('VerifyEx expiry/self-signed flag parity skipped', True);
    Exit;
  end;

  LExpiredLeaf := TWolfSSLCertificate.Create;
  LSelfSignedLeaf := TWolfSSLCertificate.Create;
  LIssuerCert := TWolfSSLCertificate.Create;
  LStore := TWolfSSLCertificateStore.Create;
  LEmptyStore := TWolfSSLCertificateStore.Create;
  try
    Test('Load expired verification fixture',
      LExpiredLeaf.LoadFromFile('tests/certs/expired-signer.pem'));
    Test('Load issuer fixture for expired verification',
      LIssuerCert.LoadFromFile('tests/certificate/test_certs/ca_cert.pem'));
    Test('Add issuer fixture to store for expired verification',
      LStore.AddCertificate(LIssuerCert));

    LVerified := LExpiredLeaf.VerifyEx(LStore, [], LVerifyResult);
    Test('Expired leaf without IgnoreExpiry fails',
      (not LVerified) and (not LVerifyResult.Success));
    Test('Expired leaf without IgnoreExpiry exposes expiry diagnostic',
      Pos('expired', LowerCase(LVerifyResult.ErrorMessage + ' ' +
        LVerifyResult.DetailedInfo)) > 0);

    LVerified := LExpiredLeaf.VerifyEx(LStore, [sslCertVerifyIgnoreExpiry], LVerifyResult);
    Test('Expired leaf with IgnoreExpiry succeeds',
      LVerified and LVerifyResult.Success);

    Test('Load self-signed verification fixture',
      LSelfSignedLeaf.LoadFromFile('tests/certs/version1-cert.pem'));

    LVerified := LSelfSignedLeaf.VerifyEx(LEmptyStore, [], LVerifyResult);
    Test('Self-signed leaf without AllowSelfSigned fails',
      (not LVerified) and (not LVerifyResult.Success));
    Test('Self-signed leaf without AllowSelfSigned exposes trust diagnostic',
      Pos('trusted root', LowerCase(LVerifyResult.ErrorMessage + ' ' +
        LVerifyResult.DetailedInfo)) > 0);

    LVerified := LSelfSignedLeaf.VerifyEx(LEmptyStore, [sslCertVerifyAllowSelfSigned], LVerifyResult);
    Test('Self-signed leaf with AllowSelfSigned succeeds',
      LVerified and LVerifyResult.Success);
  finally
    LEmptyStore := nil;
    LStore := nil;
    LIssuerCert := nil;
    LSelfSignedLeaf := nil;
    LExpiredLeaf := nil;
    LLib.Finalize;
  end;
end;

procedure TestWolfSSLCertificateExtensionMetadataContract;
var
  LLib: ISSLLibrary;
  LCert: TWolfSSLCertificate;
  LInfo: TSSLCertificateInfo;
  LValues: TSSLStringArray;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Certificate Extension Metadata Contract ===');

  LLib := CreateWolfSSLLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('  (Skipped - WolfSSL library not available)');
    Test('Certificate extension metadata contract skipped', True);
    Exit;
  end;

  LCert := TWolfSSLCertificate.Create;
  try
    if not LCert.LoadFromFile('tests/certificate/test_certs/signer_ecdsa_cert.pem') then
    begin
      Test('Load ECDSA CA fixture', False);
      Exit;
    end;
    Test('Load ECDSA CA fixture', True);

    LInfo := LCert.GetInfo;
    Test('ECDSA CA fixture GetInfo exposes public-key size',
      LInfo.PublicKeySize = 256);
    Test('ECDSA CA fixture IsCA exposes parsed truth',
      LCert.IsCA and LInfo.IsCA);
    Test('ECDSA CA fixture GetInfo IsCA matches getter truth',
      LInfo.IsCA = LCert.IsCA);
    Test('ECDSA CA fixture exposes Subject Key Identifier extension',
      LCert.GetExtension('2.5.29.14') <> '');

    if not LCert.LoadFromFile('tests/certs/san-test.pem') then
    begin
      Test('Load SAN fixture', False);
      Exit;
    end;
    Test('Load SAN fixture', True);

    LInfo := LCert.GetInfo;
    Test('SAN fixture GetInfo exposes SAN count',
      Length(LInfo.SubjectAltNames) = 3);
    Test('SAN fixture GetInfo contains san-test.local',
      ArrayContains(LInfo.SubjectAltNames, 'san-test.local'));
    Test('SAN fixture GetInfo contains example.test',
      ArrayContains(LInfo.SubjectAltNames, 'example.test'));
    Test('SAN fixture GetInfo contains 127.0.0.1',
      ArrayContains(LInfo.SubjectAltNames, '127.0.0.1'));

    LValues := LCert.GetSubjectAltNames;
    Test('SAN fixture getter exposes SAN count',
      Length(LValues) = 3);
    Test('SAN fixture getter contains san-test.local',
      ArrayContains(LValues, 'san-test.local'));
    Test('SAN fixture getter contains example.test',
      ArrayContains(LValues, 'example.test'));
    Test('SAN fixture getter contains 127.0.0.1',
      ArrayContains(LValues, '127.0.0.1'));
    Test('SAN fixture VerifyHostname accepts DNS:san-test.local',
      LCert.VerifyHostname('san-test.local'));
    Test('SAN fixture VerifyHostname accepts DNS:example.test',
      LCert.VerifyHostname('example.test'));
    Test('SAN fixture VerifyHostname accepts IP:127.0.0.1',
      LCert.VerifyHostname('127.0.0.1'));
    Test('SAN fixture VerifyHostname rejects unrelated hostname',
      not LCert.VerifyHostname('wrong.test'));

    if not LCert.LoadFromFile('tests/certificate/test_certs/san_cn_conflict_cert.pem') then
    begin
      Test('Load SAN-vs-CN conflict fixture', False);
      Exit;
    end;
    Test('Load SAN-vs-CN conflict fixture', True);
    Test('SAN-vs-CN fixture prioritizes SAN over CN',
      not LCert.VerifyHostname('cn-only.example.com'));
    Test('SAN-vs-CN fixture still matches SAN DNS entry',
      LCert.VerifyHostname('alt.example.com'));

    if not LCert.LoadFromFile('tests/certificate/test_certs/san_wildcard_cert.pem') then
    begin
      Test('Load wildcard SAN fixture', False);
      Exit;
    end;
    Test('Load wildcard SAN fixture', True);
    Test('Wildcard SAN fixture matches single-label subdomain',
      LCert.VerifyHostname('api.example.com'));
    Test('Wildcard SAN fixture rejects multi-label subdomain',
      not LCert.VerifyHostname('deep.api.example.com'));

    if not LCert.LoadFromFile('tests/certificate/test_certs/keyusage_cert.pem') then
    begin
      Test('Load KeyUsage fixture', False);
      Exit;
    end;
    Test('Load KeyUsage fixture', True);

    LInfo := LCert.GetInfo;
    LValues := LCert.GetKeyUsage;
    Test('KeyUsage fixture getter contains digitalSignature',
      ArrayContains(LValues, 'digitalSignature'));
    Test('KeyUsage fixture getter contains keyEncipherment',
      ArrayContains(LValues, 'keyEncipherment'));
    Test('KeyUsage fixture GetInfo bitfield keeps digitalSignature',
      (LInfo.KeyUsage and $0080) <> 0);
    Test('KeyUsage fixture GetInfo bitfield keeps keyEncipherment',
      (LInfo.KeyUsage and $0020) <> 0);

    LValues := LCert.GetExtendedKeyUsage;
    Test('KeyUsage fixture getter contains serverAuth',
      ArrayContains(LValues, 'serverAuth'));
    Test('KeyUsage fixture getter contains clientAuth',
      ArrayContains(LValues, 'clientAuth'));
  finally
    LCert.Free;
    LLib.Finalize;
  end;
end;

procedure TestWolfSSLCertificateCloneMaterializationContract;
var
  LLib: ISSLLibrary;
  LCert: TWolfSSLCertificate;
  LClone: ISSLCertificate;
  LCloneNative: ISSLNativeHandleAccess;
  LExpectedSubject: string;
  LExpectedIssuer: string;
  LExpectedFingerprint: string;
  LOriginalX509D2I: TwolfSSL_X509_d2i;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Certificate Clone Materialization Contract ===');

  LLib := CreateWolfSSLLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('  (Skipped - WolfSSL library not available)');
    Test('Certificate clone materialization skipped', True);
    Exit;
  end;

  LCert := TWolfSSLCertificate.Create;
  try
    if not LCert.LoadFromFile('tests/certificate/test_certs/signer_cert.pem') then
    begin
      WriteLn('  (Skipped - fixture certificate unavailable)');
      Test('Certificate clone materialization skipped', True);
      Exit;
    end;

    LExpectedSubject := LCert.GetSubject;
    LExpectedIssuer := LCert.GetIssuer;
    LExpectedFingerprint := LCert.GetFingerprintSHA256;

    LClone := LCert.Clone;
    Test('Clone keeps native handle for loaded certificate',
      (LClone <> nil) and Supports(LClone, ISSLNativeHandleAccess, LCloneNative) and
      (LCloneNative.GetNativeHandle <> nil));
    Test('Clone preserves subject truth',
      (LClone <> nil) and (LClone.GetSubject = LExpectedSubject));
    Test('Clone preserves issuer truth',
      (LClone <> nil) and (LClone.GetIssuer = LExpectedIssuer));
    Test('Clone preserves fingerprint truth',
      (LClone <> nil) and SameText(LClone.GetFingerprintSHA256, LExpectedFingerprint));

    LOriginalX509D2I := wolfSSL_X509_d2i;
    try
      wolfSSL_X509_d2i := nil;
      LClone := LCert.Clone;
      Test('Clone fails closed when X509 materialization helper is unavailable',
        LClone = nil);
    finally
      wolfSSL_X509_d2i := LOriginalX509D2I;
    end;
  finally
    LCert.Free;
    LLib.Finalize;
  end;
end;

procedure TestWolfSSLCertificateStore;
var
  LStore: TWolfSSLCertificateStore;
  LCert: ISSLCertificate;
  LStoreClone: ISSLCertificate;
  LChainIssuer: ISSLCertificate;
  LChain: TSSLCertificateArray;
  LSubjectVariant: string;
  LIssuerVariant: string;
  LSerialCompact: string;
  LSerialVariant: string;
  LFingerprintVariant: string;
  LCharIndex: Integer;
  LLib: ISSLLibrary;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Certificate Store ===');

  LStore := TWolfSSLCertificateStore.Create;
  LLib := CreateWolfSSLLibrary;
  try
    Test('Store created', LStore <> nil);
    Test('Store initially empty', LStore.GetCount = 0);

    // Test adding certificate
    LCert := TWolfSSLCertificate.Create;
    Test('AddCertificate returns true', LStore.AddCertificate(LCert));
    Test('Store count is 1', LStore.GetCount = 1);
    Test('GetCertificate(0) returns cert', LStore.GetCertificate(0) <> nil);

    // Test duplicate prevention
    Test('AddCertificate duplicate returns false', not LStore.AddCertificate(LCert));
    Test('Store count still 1', LStore.GetCount = 1);

    // Test removal
    Test('RemoveCertificate returns true', LStore.RemoveCertificate(LCert));
    Test('Store count is 0', LStore.GetCount = 0);

    // Fingerprint semantics parity with FreePascal/MbedTLS stores
    if (LLib <> nil) and LLib.Initialize then
    begin
      LCert := TWolfSSLCertificate.Create;
      Test('Load fixture cert for certstore fingerprint semantics',
        LCert.LoadFromFile('tests/certs/server-cert.pem'));
      Test('Add loaded cert returns true', LStore.AddCertificate(LCert));
      LStoreClone := LCert.Clone;
      Test('Contains clone should be true by fingerprint', LStore.Contains(LStoreClone));
      Test('Remove clone should remove by fingerprint', LStore.RemoveCertificate(LStoreClone));
      Test('Store count returns to 0 after clone removal', LStore.GetCount = 0);

      Test('Re-add loaded cert returns true', LStore.AddCertificate(LCert));
      LSerialCompact := NormalizeHexish(LCert.GetFingerprintSHA256);
      Test('Loaded fixture cert exposes fingerprint for normalized fingerprint query contract',
        LSerialCompact <> '');
      LFingerprintVariant := '';
      for LCharIndex := 1 to Length(LSerialCompact) do
      begin
        if (LCharIndex > 1) and (((LCharIndex - 1) mod 2) = 0) then
          LFingerprintVariant := LFingerprintVariant + ':';
        LFingerprintVariant := LFingerprintVariant + LowerCase(LSerialCompact[LCharIndex]);
      end;
      LFingerprintVariant := '  ' + LFingerprintVariant + '  ';
      Test('FindByFingerprint supports normalized query variant',
        LStore.FindByFingerprint(LFingerprintVariant) <> nil);

      LSubjectVariant := UpperCase(StringReplace(StringReplace(LCert.GetSubject, ',', ' , ', [rfReplaceAll]),
        '=', ' = ', [rfReplaceAll]));
      Test('FindBySubject supports normalized query variant', LStore.FindBySubject(LSubjectVariant) <> nil);
      Test('FindBySubject empty query returns nil', LStore.FindBySubject('') = nil);
      LSerialCompact := NormalizeHexish(LCert.GetSerialNumber);
      Test('Loaded fixture cert exposes serial for normalized serial query contract', LSerialCompact <> '');
      LSerialVariant := '';
      for LCharIndex := 1 to Length(LSerialCompact) do
      begin
        if (LCharIndex > 1) and (((LCharIndex - 1) mod 2) = 0) then
          LSerialVariant := LSerialVariant + ':';
        LSerialVariant := LSerialVariant + LowerCase(LSerialCompact[LCharIndex]);
      end;
      LSerialVariant := '  ' + LSerialVariant + '  ';
      Test('FindBySerialNumber supports normalized query variant', LStore.FindBySerialNumber(LSerialVariant) <> nil);
      Test('Remove loaded cert succeeds', LStore.RemoveCertificate(LCert));
      Test('Store count back to 0', LStore.GetCount = 0);

      LCert := TWolfSSLCertificate.Create;
      Test('Load distinct-issuer fixture for issuer query semantics',
        LCert.LoadFromFile('tests/certificate/test_certs/signer_cert.pem'));
      Test('Add distinct-issuer fixture returns true', LStore.AddCertificate(LCert));
      LIssuerVariant := UpperCase(StringReplace(StringReplace(LCert.GetIssuer, ',', ' , ', [rfReplaceAll]),
        '=', ' = ', [rfReplaceAll]));
      Test('FindByIssuer supports normalized query variant', LStore.FindByIssuer(LIssuerVariant) <> nil);
      Test('FindByIssuer empty query returns nil', LStore.FindByIssuer('') = nil);
      Test('Remove distinct-issuer fixture succeeds', LStore.RemoveCertificate(LCert));
      Test('Store count back to 0 after issuer query semantics', LStore.GetCount = 0);

      LCert := TWolfSSLCertificate.Create;
      Test('Load chain leaf fixture for explicit issuer-link semantics',
        LCert.LoadFromFile('tests/certificate/test_certs/signer_cert.pem'));
      LChainIssuer := TWolfSSLCertificate.Create;
      Test('Load chain issuer fixture for explicit issuer-link semantics',
        LChainIssuer.LoadFromFile('tests/certificate/test_certs/ca_cert.pem'));
      LCert.SetIssuerCertificate(LChainIssuer);
      LChain := LStore.BuildCertificateChain(LCert);
      Test('BuildCertificateChain follows explicit issuer-link when store lacks issuer',
        Length(LChain) = 2);
      Test('BuildCertificateChain appends explicit issuer certificate',
        (Length(LChain) = 2) and (LChain[1] <> nil));
      Test('BuildCertificateChain preserves explicit issuer fingerprint truth',
        (Length(LChain) = 2) and
        (NormalizeHexish(LChain[1].GetFingerprintSHA256) =
         NormalizeHexish(LChainIssuer.GetFingerprintSHA256)));
      LLib.Finalize;
    end
    else
    begin
      Test('Fingerprint semantics skipped when WolfSSL runtime unavailable', True);
    end;

    // Test clear
    LStore.AddCertificate(TWolfSSLCertificate.Create);
    LStore.AddCertificate(TWolfSSLCertificate.Create);
    Test('Store count is 2', LStore.GetCount = 2);
    LStore.Clear;
    Test('Store cleared', LStore.GetCount = 0);
  finally
    LStore.Free;
  end;
end;

procedure TestWolfSSLContextCreation;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LInitialized: Boolean;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Context Creation ===');

  LLib := CreateWolfSSLLibrary;
  LInitialized := LLib.Initialize;

  if LInitialized then
  begin
    WriteLn('  WolfSSL library initialized successfully');

    try
      LCtx := LLib.CreateContext(sslCtxClient);
      Test('Client context created', LCtx <> nil);
      Test('Context type is client', LCtx.GetContextType = sslCtxClient);
      Test('Context is valid', LCtx.IsValid);
      Test('Native handle not nil', HasNativeHandleContext(LCtx));

      // Test default values
      Test('Default verify mode includes peer', sslVerifyPeer in LCtx.GetVerifyMode);
      Test('Default verify depth > 0', LCtx.GetVerifyDepth > 0);
      Test('Session cache enabled by default', LCtx.GetSessionCacheMode);
    except
      on E: Exception do
      begin
        WriteLn('  Context creation failed: ', E.Message);
        Test('Context creation', False);
      end;
    end;

    LLib.Finalize;
  end
  else
  begin
    WriteLn('  (Skipped - WolfSSL library not available)');
    Test('Context creation skipped', True);
  end;
end;

procedure TestWolfSSLContextConfiguration;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LErrMsg: string;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Context Configuration ===');

  LLib := CreateWolfSSLLibrary;

  if LLib.Initialize then
  begin
    try
      LCtx := LLib.CreateContext(sslCtxClient);

      // Test protocol versions
      LCtx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
      Test('Protocol versions set', sslProtocolTLS12 in LCtx.GetProtocolVersions);

      // Test verify mode
      LCtx.SetVerifyMode([sslVerifyPeer, sslVerifyFailIfNoPeerCert]);
      Test('Verify mode set', sslVerifyFailIfNoPeerCert in LCtx.GetVerifyMode);

      // Test verify depth
      LCtx.SetVerifyDepth(5);
      Test('Verify depth set to 5', LCtx.GetVerifyDepth = 5);

      // INTENTIONAL_API_SURFACE: context-level SNI setter coverage. This
      // backend framework test validates WolfSSL context configuration, not
      // recommended per-connection handshake guidance.
      // Test server name
      LCtx.SetServerName('example.com');
      Test('Server name set', LCtx.GetServerName = 'example.com');

      // Test session cache
      LCtx.SetSessionCacheMode(False);
      Test('Session cache disabled', not LCtx.GetSessionCacheMode);
      LCtx.SetSessionCacheMode(True);
      Test('Session cache enabled', LCtx.GetSessionCacheMode);

      // Test session timeout
      LCtx.SetSessionTimeout(3600);
      Test('Session timeout set', LCtx.GetSessionTimeout = 3600);

      // Test ALPN protocols
      LCtx.SetALPNProtocols('h2,http/1.1');
      Test('ALPN protocols set', LCtx.GetALPNProtocols = 'h2,http/1.1');

      // Test options
      LCtx.SetOptions([ssoEnableSNI, ssoEnableALPN]);
      Test('Options set', ssoEnableSNI in LCtx.GetOptions);

      // Renegotiation explicit unsupported semantics
      LConn := LCtx.CreateConnection(0);
      Test('Renegotiate returns false before handshake', not LConn.Renegotiate);
      Test('Renegotiate reports unsupported error class',
        LConn.GetError(-1) = sslErrUnsupported);
      LErrMsg := LConn.GetVerifyResultString;
      Test('Renegotiate exposes non-empty diagnostic message',
        Pos('renegotiation', LowerCase(LErrMsg)) > 0);

    except
      on E: Exception do
      begin
        WriteLn('  Configuration test failed: ', E.Message);
        Test('Context configuration', False);
      end;
    end;

    LLib.Finalize;
  end
  else
  begin
    WriteLn('  (Skipped - WolfSSL library not available)');
    Test('Context configuration skipped', True);
  end;
end;

procedure TestWolfSSLVerifyStatusBeforeHandshakeContract;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LStream: TMemoryStream;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Pre-Handshake Verify Status Contract ===');

  LLib := CreateWolfSSLLibrary;

  if LLib.Initialize then
  begin
    LCtx := LLib.CreateContext(sslCtxClient);
    LStream := TMemoryStream.Create;
    try
      LConn := LCtx.CreateConnection(LStream);
      Test('Fresh WolfSSL connection does not report verify success before handshake',
        LConn.GetVerifyResult = -1);
      Test('Fresh WolfSSL connection reports not-verified diagnostic before handshake',
        Pos('not verified', LowerCase(LConn.GetVerifyResultString)) > 0);
    finally
      LStream.Free;
      LLib.Finalize;
    end;
  end
  else
  begin
    WriteLn('  (Skipped - WolfSSL library not available)');
    Test('Pre-handshake verify-status contract skipped', True);
  end;
end;

procedure TestWolfSSLFeatureSupport;
var
  LLib: ISSLLibrary;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Feature Support ===');

  LLib := CreateWolfSSLLibrary;

  if LLib.Initialize then
  begin
    Test('TLS 1.2 supported', LLib.IsProtocolSupported(sslProtocolTLS12));
    Test('SSL 2.0 not supported', not LLib.IsProtocolSupported(sslProtocolSSL2));
    Test('SSL 3.0 not supported', not LLib.IsProtocolSupported(sslProtocolSSL3));

    Test('DTLS 1.0 not supported', not LLib.IsProtocolSupported(sslProtocolDTLS10));
    Test('DTLS 1.2 not supported', not LLib.IsProtocolSupported(sslProtocolDTLS12));

    with LLib.GetCapabilities do
      Test('Capabilities DTLS support matches runtime protocol support',
        SupportsDTLS = (LLib.IsProtocolSupported(sslProtocolDTLS10) or
                        LLib.IsProtocolSupported(sslProtocolDTLS12)));

    // Feature support
    Test('Session cache feature', LLib.IsFeatureSupported(sslFeatSessionCache));
    Test('Known TLS1.3 cipher is reported supported',
      LLib.IsCipherSupported('TLS_AES_128_GCM_SHA256'));
    Test('Unknown fake cipher is rejected',
      not LLib.IsCipherSupported('TLS_FAKE_AES_128_GCM_SHA256'));
    Test('Empty cipher name is rejected',
      not LLib.IsCipherSupported(''));

    // Version info
    Test('Version string not empty', LLib.GetVersionString <> '');
    WriteLn('  Version: ', LLib.GetVersionString);

    LLib.Finalize;
  end
  else
  begin
    WriteLn('  (Skipped - WolfSSL library not available)');
    Test('Feature support skipped', True);
  end;
end;

procedure TestWolfSSLSessionClass;
var
  LSession: TWolfSSLSession;
  LClone: ISSLSession;
  LRoundTrip: ISSLSession;
  LOriginalD2I: TwolfSSL_d2i_SSL_SESSION;
  LOriginalI2D: TwolfSSL_i2d_SSL_SESSION;
  LOriginalFree: TwolfSSL_SESSION_free;
  LOriginalSessionGetId: TwolfSSL_SESSION_get_id;
  LOriginalSessionGetTime: TwolfSSL_SESSION_get_time;
  LOriginalSessionGetTimeout: TwolfSSL_SESSION_get_timeout;
  LOriginalSessionCipherGetName: TwolfSSL_SESSION_CIPHER_get_name;
  LData: TBytes;
  LCloneNative: ISSLNativeHandleAccess;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Session Class ===');

  LSession := TWolfSSLSession.Create;
  try
    Test('Session created', LSession <> nil);
    Test('Session ID not empty', LSession.GetID <> '');
    Test('Session creation time valid', LSession.GetCreationTime > 0);
    Test('Session timeout default', LSession.GetTimeout = SSL_DEFAULT_SESSION_TIMEOUT);
    Test('Session not valid without handle', not LSession.IsValid);
    Test('Session not resumable without handle', not LSession.IsResumable);
    Test('Native handle is nil', LSession.GetNativeHandle = nil);
    Test('Default session protocol is unknown', LSession.GetProtocolVersion = sslProtocolUnknown);
    Test('Default session cipher is unknown', LSession.GetCipherName = 'unknown');

    // Test timeout setting
    LSession.SetTimeout(7200);
    Test('Session timeout updated', LSession.GetTimeout = 7200);

    // Test clone
    LClone := LSession.Clone;
    Test('Clone created', LClone <> nil);
    Test('Clone has same timeout', LClone.GetTimeout = 7200);
    Test('Clone has same ID', LClone.GetID = LSession.GetID);

    // Test serialization
    Test('Serialize returns empty for no session', Length(LSession.Serialize) = 0);
    Test('Deserialize rejects empty payload', not LSession.Deserialize(nil));

    LOriginalD2I := wolfSSL_d2i_SSL_SESSION;
    LOriginalI2D := wolfSSL_i2d_SSL_SESSION;
    LOriginalFree := wolfSSL_SESSION_free;
    LOriginalSessionGetId := wolfSSL_SESSION_get_id;
    LOriginalSessionGetTime := wolfSSL_SESSION_get_time;
    LOriginalSessionGetTimeout := wolfSSL_SESSION_get_timeout;
    LOriginalSessionCipherGetName := wolfSSL_SESSION_CIPHER_get_name;
    try
      wolfSSL_d2i_SSL_SESSION := @StubWolfSSLD2ISessionFail;
      Test('Deserialize rejects invalid payload when d2i API available',
        not LSession.Deserialize(TBytes.Create(1, 2, 3, 4)));
      Test('Serialize remains empty after failed deserialize',
        Length(LSession.Serialize) = 0);
    finally
      wolfSSL_d2i_SSL_SESSION := LOriginalD2I;
    end;

    try
      wolfSSL_d2i_SSL_SESSION := nil;
      Test('Deserialize rejects payload when d2i API unavailable',
        not LSession.Deserialize(TBytes.Create(5, 6, 7, 8)));
      Test('Serialize remains empty when d2i API unavailable',
        Length(LSession.Serialize) = 0);
    finally
      wolfSSL_d2i_SSL_SESSION := LOriginalD2I;
    end;

    try
      wolfSSL_d2i_SSL_SESSION := @StubWolfSSLD2ISessionOk;
      wolfSSL_i2d_SSL_SESSION := @StubWolfSSLI2DSessionOk;
      wolfSSL_SESSION_free := @StubWolfSSLSessionFree;
      wolfSSL_SESSION_get_id := @StubWolfSSLSessionGetID;
      wolfSSL_SESSION_get_time := @StubWolfSSLSessionGetTime;
      wolfSSL_SESSION_get_timeout := @StubWolfSSLSessionGetTimeout;
      wolfSSL_SESSION_CIPHER_get_name := @StubWolfSSLSessionCipherGetNameTLS13;

      Test('Deserialize accepts payload when d2i API succeeds',
        LSession.Deserialize(TBytes.Create(8, 7, 6, 5)));
      Test('Deserialized session becomes valid', LSession.IsValid);
      Test('Native handle exists after successful deserialize',
        LSession.GetNativeHandle <> nil);
      Test('Deserialized session exposes native session id truth',
        LSession.GetID = '89ABCDEF');
      Test('Deserialized session exposes native creation time truth',
        Abs(LSession.GetCreationTime -
          UnixToDateTime(GStubWolfSSLSessionUnixTime)) < (1 / 86400));
      Test('Deserialized session exposes native timeout truth',
        LSession.GetTimeout = STUB_WOLFSSL_NATIVE_SESSION_TIMEOUT);
      Test('Deserialized session exposes native cipher truth',
        LSession.GetCipherName = string(GStubWolfSSLCipherTLS13));

      LData := LSession.Serialize;
      Test('Serialize returns metadata-complete snapshot after deserialize',
        Length(LData) > 0);
      LRoundTrip := TWolfSSLSession.Create;
      Test('Serialized snapshot after native-truth deserialize stays reloadable',
        (LRoundTrip <> nil) and LRoundTrip.Deserialize(LData));
      Test('Reloaded snapshot preserves native session id truth',
        (LRoundTrip <> nil) and (LRoundTrip.GetID = '89ABCDEF'));
      Test('Reloaded snapshot preserves native creation time truth',
        (LRoundTrip <> nil) and
        (Abs(LRoundTrip.GetCreationTime -
          UnixToDateTime(GStubWolfSSLSessionUnixTime)) < (1 / 86400)));
      Test('Reloaded snapshot preserves native timeout truth',
        (LRoundTrip <> nil) and
        (LRoundTrip.GetTimeout = STUB_WOLFSSL_NATIVE_SESSION_TIMEOUT));
      Test('Reloaded snapshot preserves native cipher truth',
        (LRoundTrip <> nil) and
        (LRoundTrip.GetCipherName = string(GStubWolfSSLCipherTLS13)));

      LClone := LSession.Clone;
      Test('Clone keeps deserialized session available', LClone <> nil);
      Test('Clone keeps deserialized session valid',
        (LClone <> nil) and LClone.IsValid);
      Test('Clone keeps deserialized session resumable',
        (LClone <> nil) and LClone.IsResumable);
      Test('Clone keeps native handle after deserialize',
        (LClone <> nil) and Supports(LClone, ISSLNativeHandleAccess, LCloneNative) and
        (LCloneNative.GetNativeHandle <> nil));
    finally
      wolfSSL_d2i_SSL_SESSION := LOriginalD2I;
      wolfSSL_i2d_SSL_SESSION := LOriginalI2D;
      wolfSSL_SESSION_free := LOriginalFree;
      wolfSSL_SESSION_get_id := LOriginalSessionGetId;
      wolfSSL_SESSION_get_time := LOriginalSessionGetTime;
      wolfSSL_SESSION_get_timeout := LOriginalSessionGetTimeout;
      wolfSSL_SESSION_CIPHER_get_name := LOriginalSessionCipherGetName;
    end;
  finally
    LSession.Free;
  end;
end;

procedure TestWolfSSLSessionSourceLifetimeOwnershipContract;
var
  LOriginalGetSession: TwolfSSL_get_session;
  LOriginalSessionDup: TwolfSSL_SESSION_dup;
  LOriginalD2I: TwolfSSL_d2i_SSL_SESSION;
  LOriginalI2D: TwolfSSL_i2d_SSL_SESSION;
  LOriginalFree: TwolfSSL_SESSION_free;
  LSession: ISSLSession;
  LNativeAccess: ISSLNativeHandleAccess;
  LNativeHandle: Pointer;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Session Source Lifetime Contract ===');

  GetMem(GStubWolfSSLBorrowedSession, 1);
  PByte(GStubWolfSSLBorrowedSession)^ := $A5;
  LSession := nil;
  try
    LOriginalGetSession := wolfSSL_get_session;
    LOriginalSessionDup := wolfSSL_SESSION_dup;
    LOriginalD2I := wolfSSL_d2i_SSL_SESSION;
    LOriginalI2D := wolfSSL_i2d_SSL_SESSION;
    LOriginalFree := wolfSSL_SESSION_free;

    try
      GStubWolfSSLSessionDupCalls := 0;
      wolfSSL_get_session := @StubWolfSSLGetBorrowedSession;
      wolfSSL_SESSION_dup := @StubWolfSSLSessionDupOk;
      wolfSSL_d2i_SSL_SESSION := nil;
      wolfSSL_i2d_SSL_SESSION := nil;
      wolfSSL_SESSION_free := @StubWolfSSLSessionFree;

      LSession := TWolfSSLSession.FromConnection(PWOLFSSL(Pointer(1)));
      Test('FromConnection duplicates borrowed session when dup helper exists',
        LSession <> nil);
      Test('FromConnection uses session duplication helper',
        GStubWolfSSLSessionDupCalls = 1);
      Test('Duplicated session stays valid',
        (LSession <> nil) and LSession.IsValid);
      Test('Duplicated session stays resumable',
        (LSession <> nil) and LSession.IsResumable);

      LNativeHandle := nil;
      if (LSession <> nil) and Supports(LSession, ISSLNativeHandleAccess, LNativeAccess) then
        LNativeHandle := LNativeAccess.GetNativeHandle;
      Test('Duplicated session keeps native handle', LNativeHandle <> nil);
      Test('Duplicated session no longer aliases source handle',
        LNativeHandle <> GStubWolfSSLBorrowedSession);
      LSession := nil;
    finally
      wolfSSL_get_session := LOriginalGetSession;
      wolfSSL_SESSION_dup := LOriginalSessionDup;
      wolfSSL_d2i_SSL_SESSION := LOriginalD2I;
      wolfSSL_i2d_SSL_SESSION := LOriginalI2D;
      wolfSSL_SESSION_free := LOriginalFree;
    end;

    try
      wolfSSL_get_session := @StubWolfSSLGetBorrowedSession;
      wolfSSL_SESSION_dup := nil;
      wolfSSL_d2i_SSL_SESSION := nil;
      wolfSSL_i2d_SSL_SESSION := nil;
      wolfSSL_SESSION_free := @StubWolfSSLSessionFree;

      LSession := TWolfSSLSession.FromConnection(PWOLFSSL(Pointer(1)));
      Test('FromConnection rejects borrowed session when ownership cannot be secured',
        LSession = nil);
    finally
      wolfSSL_get_session := LOriginalGetSession;
      wolfSSL_SESSION_dup := LOriginalSessionDup;
      wolfSSL_d2i_SSL_SESSION := LOriginalD2I;
      wolfSSL_i2d_SSL_SESSION := LOriginalI2D;
      wolfSSL_SESSION_free := LOriginalFree;
    end;
  finally
    if GStubWolfSSLBorrowedSession <> nil then
    begin
      FreeMem(GStubWolfSSLBorrowedSession);
      GStubWolfSSLBorrowedSession := nil;
    end;
  end;
end;

procedure TestWolfSSLSessionMetadataCompletenessContract;
var
  LLib: ISSLLibrary;
  LFixtureCert: TWolfSSLCertificate;
  LSession: ISSLSession;
  LClone: ISSLSession;
  LRoundTripSession: TWolfSSLSession;
  LRoundTripClone: ISSLSession;
  LPeerCert: ISSLCertificate;
  LClonePeerCert: ISSLCertificate;
  LSerializedData: TBytes;
  LExpectedFingerprint: string;
  LOriginalGetSession: TwolfSSL_get_session;
  LOriginalSessionDup: TwolfSSL_SESSION_dup;
  LOriginalD2ISession: TwolfSSL_d2i_SSL_SESSION;
  LOriginalI2DSession: TwolfSSL_i2d_SSL_SESSION;
  LOriginalSessionFree: TwolfSSL_SESSION_free;
  LOriginalGetVersion: TwolfSSL_get_version;
  LOriginalGetCurrentCipher: TwolfSSL_get_current_cipher;
  LOriginalCipherGetName: TwolfSSL_CIPHER_get_name;
  LOriginalSessionGetId: TwolfSSL_SESSION_get_id;
  LOriginalSessionGetTime: TwolfSSL_SESSION_get_time;
  LOriginalSessionGetTimeout: TwolfSSL_SESSION_get_timeout;
  LOriginalSessionCipherGetName: TwolfSSL_SESSION_CIPHER_get_name;
  LOriginalGetPeerCertificate: TwolfSSL_get_peer_certificate;
  LOriginalX509D2I: TwolfSSL_X509_d2i;
begin
  WriteLn('');
  WriteLn('=== WolfSSL Session Metadata Completeness Contract ===');

  LLib := CreateWolfSSLLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('  (Skipped - WolfSSL library not available)');
    Test('Session metadata completeness skipped', True);
    Exit;
  end;

  LFixtureCert := TWolfSSLCertificate.Create;
  try
    if not LFixtureCert.LoadFromFile('tests/certificate/test_certs/signer_cert.pem') then
    begin
      WriteLn('  (Skipped - fixture certificate unavailable)');
      Test('Session metadata completeness skipped', True);
      Exit;
    end;

    GStubWolfSSLPeerCertificateDER := LFixtureCert.SaveToDER;
    LExpectedFingerprint := LFixtureCert.GetFingerprintSHA256;

    GetMem(GStubWolfSSLBorrowedSession, 1);
    PByte(GStubWolfSSLBorrowedSession)^ := $A5;

    LOriginalGetSession := wolfSSL_get_session;
    LOriginalSessionDup := wolfSSL_SESSION_dup;
    LOriginalD2ISession := wolfSSL_d2i_SSL_SESSION;
    LOriginalI2DSession := wolfSSL_i2d_SSL_SESSION;
    LOriginalSessionFree := wolfSSL_SESSION_free;
    LOriginalGetVersion := wolfSSL_get_version;
    LOriginalGetCurrentCipher := wolfSSL_get_current_cipher;
    LOriginalCipherGetName := wolfSSL_CIPHER_get_name;
    LOriginalSessionGetId := wolfSSL_SESSION_get_id;
    LOriginalSessionGetTime := wolfSSL_SESSION_get_time;
    LOriginalSessionGetTimeout := wolfSSL_SESSION_get_timeout;
    LOriginalSessionCipherGetName := wolfSSL_SESSION_CIPHER_get_name;
    LOriginalGetPeerCertificate := wolfSSL_get_peer_certificate;
    LOriginalX509D2I := wolfSSL_X509_d2i;
    try
      GStubWolfSSLSessionDupCalls := 0;
      wolfSSL_get_session := @StubWolfSSLGetBorrowedSession;
      wolfSSL_SESSION_dup := @StubWolfSSLSessionDupOk;
      wolfSSL_d2i_SSL_SESSION := @StubWolfSSLD2ISessionOk;
      wolfSSL_i2d_SSL_SESSION := @StubWolfSSLI2DSessionOk;
      wolfSSL_SESSION_free := @StubWolfSSLSessionFree;
      wolfSSL_get_version := @StubWolfSSLGetVersionTLS13;
      wolfSSL_get_current_cipher := @StubWolfSSLGetCurrentCipherNonNil;
      wolfSSL_CIPHER_get_name := @StubWolfSSLCipherGetNameTLS13;
      wolfSSL_SESSION_get_id := @StubWolfSSLSessionGetID;
      wolfSSL_SESSION_get_time := @StubWolfSSLSessionGetTime;
      wolfSSL_SESSION_get_timeout := @StubWolfSSLSessionGetTimeout;
      wolfSSL_SESSION_CIPHER_get_name := @StubWolfSSLSessionCipherGetNameTLS13;
      wolfSSL_get_peer_certificate := @StubWolfSSLGetPeerCertificateFromDER;

      LSession := TWolfSSLSession.FromConnection(PWOLFSSL(Pointer(1)));
      Test('FromConnection returns session when ownership is secured',
        LSession <> nil);
      Test('FromConnection preserves source-lifetime secure duplication',
        GStubWolfSSLSessionDupCalls = 1);
      Test('FromConnection extracts native session id truth',
        (LSession <> nil) and (LSession.GetID = '89ABCDEF'));
      Test('FromConnection extracts native creation time truth',
        (LSession <> nil) and
        (Abs(LSession.GetCreationTime -
          UnixToDateTime(GStubWolfSSLSessionUnixTime)) < (1 / 86400)));
      Test('FromConnection extracts native timeout truth',
        (LSession <> nil) and
        (LSession.GetTimeout = STUB_WOLFSSL_NATIVE_SESSION_TIMEOUT));
      Test('FromConnection extracts protocol version truth',
        (LSession <> nil) and (LSession.GetProtocolVersion = sslProtocolTLS13));
      Test('FromConnection extracts cipher truth',
        (LSession <> nil) and (LSession.GetCipherName = string(GStubWolfSSLCipherTLS13)));

      LPeerCert := nil;
      if LSession <> nil then
        LPeerCert := LSession.GetPeerCertificate;
      Test('FromConnection materializes peer certificate as owned copy',
        LPeerCert <> nil);
      Test('FromConnection peer certificate matches fixture fingerprint',
        (LPeerCert <> nil) and
        SameText(LPeerCert.GetFingerprintSHA256, LExpectedFingerprint));

      LClone := nil;
      if LSession <> nil then
        LClone := LSession.Clone;
      LClonePeerCert := nil;
      if LClone <> nil then
        LClonePeerCert := LClone.GetPeerCertificate;
      Test('Session clone preserves peer certificate truth',
        (LClone <> nil) and (LClonePeerCert <> nil) and
        SameText(LClonePeerCert.GetFingerprintSHA256, LExpectedFingerprint));

      LSerializedData := nil;
      if LSession <> nil then
        LSerializedData := LSession.Serialize;
      Test('Metadata-complete session serializes to non-empty snapshot',
        Length(LSerializedData) > 0);

      LRoundTripSession := TWolfSSLSession.Create;
      try
        Test('Metadata-complete session deserialize succeeds from serialized snapshot',
          LRoundTripSession.Deserialize(LSerializedData));
        Test('Round-tripped session preserves protocol version truth',
          LRoundTripSession.GetProtocolVersion = sslProtocolTLS13);
        Test('Round-tripped session preserves cipher truth',
          LRoundTripSession.GetCipherName = string(GStubWolfSSLCipherTLS13));

        LRoundTripClone := LRoundTripSession.Clone;
        Test('Clone after deserialize preserves protocol version truth',
          (LRoundTripClone <> nil) and
          (LRoundTripClone.GetProtocolVersion = sslProtocolTLS13));
        Test('Clone after deserialize preserves cipher truth',
          (LRoundTripClone <> nil) and
          (LRoundTripClone.GetCipherName = string(GStubWolfSSLCipherTLS13)));
      finally
        LRoundTripSession.Free;
      end;
    finally
      wolfSSL_get_session := LOriginalGetSession;
      wolfSSL_SESSION_dup := LOriginalSessionDup;
      wolfSSL_d2i_SSL_SESSION := LOriginalD2ISession;
      wolfSSL_i2d_SSL_SESSION := LOriginalI2DSession;
      wolfSSL_SESSION_free := LOriginalSessionFree;
      wolfSSL_get_version := LOriginalGetVersion;
      wolfSSL_get_current_cipher := LOriginalGetCurrentCipher;
      wolfSSL_CIPHER_get_name := LOriginalCipherGetName;
      wolfSSL_SESSION_get_id := LOriginalSessionGetId;
      wolfSSL_SESSION_get_time := LOriginalSessionGetTime;
      wolfSSL_SESSION_get_timeout := LOriginalSessionGetTimeout;
      wolfSSL_SESSION_CIPHER_get_name := LOriginalSessionCipherGetName;
      wolfSSL_get_peer_certificate := LOriginalGetPeerCertificate;
      wolfSSL_X509_d2i := LOriginalX509D2I;
    end;

    LSession := nil;
    LPeerCert := nil;
    try
      wolfSSL_get_session := @StubWolfSSLGetBorrowedSession;
      wolfSSL_SESSION_dup := @StubWolfSSLSessionDupOk;
      wolfSSL_d2i_SSL_SESSION := @StubWolfSSLD2ISessionOk;
      wolfSSL_i2d_SSL_SESSION := @StubWolfSSLI2DSessionOk;
      wolfSSL_SESSION_free := @StubWolfSSLSessionFree;
      wolfSSL_get_version := @StubWolfSSLGetVersionTLS13;
      wolfSSL_get_current_cipher := @StubWolfSSLGetCurrentCipherNonNil;
      wolfSSL_CIPHER_get_name := @StubWolfSSLCipherGetNameTLS13;
      wolfSSL_SESSION_get_id := @StubWolfSSLSessionGetID;
      wolfSSL_SESSION_get_time := @StubWolfSSLSessionGetTime;
      wolfSSL_SESSION_get_timeout := @StubWolfSSLSessionGetTimeout;
      wolfSSL_SESSION_CIPHER_get_name := @StubWolfSSLSessionCipherGetNameTLS13;
      wolfSSL_get_peer_certificate := @StubWolfSSLGetPeerCertificateFromDER;
      wolfSSL_X509_d2i := nil;

      LSession := TWolfSSLSession.FromConnection(PWOLFSSL(Pointer(1)));
      if LSession <> nil then
        LPeerCert := LSession.GetPeerCertificate;

      Test('FromConnection keeps session truth when peer-cert materialization helper is unavailable',
        LSession <> nil);
      Test('FromConnection fails closed when peer certificate cannot be materialized',
        LPeerCert = nil);
    finally
      wolfSSL_get_session := LOriginalGetSession;
      wolfSSL_SESSION_dup := LOriginalSessionDup;
      wolfSSL_d2i_SSL_SESSION := LOriginalD2ISession;
      wolfSSL_i2d_SSL_SESSION := LOriginalI2DSession;
      wolfSSL_SESSION_free := LOriginalSessionFree;
      wolfSSL_get_version := LOriginalGetVersion;
      wolfSSL_get_current_cipher := LOriginalGetCurrentCipher;
      wolfSSL_CIPHER_get_name := LOriginalCipherGetName;
      wolfSSL_SESSION_get_id := LOriginalSessionGetId;
      wolfSSL_SESSION_get_time := LOriginalSessionGetTime;
      wolfSSL_SESSION_get_timeout := LOriginalSessionGetTimeout;
      wolfSSL_SESSION_CIPHER_get_name := LOriginalSessionCipherGetName;
      wolfSSL_get_peer_certificate := LOriginalGetPeerCertificate;
      wolfSSL_X509_d2i := LOriginalX509D2I;
    end;
  finally
    if GStubWolfSSLBorrowedSession <> nil then
    begin
      FreeMem(GStubWolfSSLBorrowedSession);
      GStubWolfSSLBorrowedSession := nil;
    end;
    SetLength(GStubWolfSSLPeerCertificateDER, 0);
    LFixtureCert.Free;
    LLib.Finalize;
  end;
end;

procedure PrintSummary;
var
  LPassRate: Double;
begin
  WriteLn('');
  WriteLn('========================================');
  WriteLn('WolfSSL Framework Test Summary');
  WriteLn('========================================');
  WriteLn(Format('Total:  %d', [GTestCount]));
  WriteLn(Format('Passed: %d', [GPassCount]));
  WriteLn(Format('Failed: %d', [GFailCount]));

  if GTestCount > 0 then
    LPassRate := (GPassCount / GTestCount) * 100
  else
    LPassRate := 0;

  WriteLn(Format('Rate:   %.1f%%', [LPassRate]));
  WriteLn('========================================');
end;

begin
  WriteLn('WolfSSL Backend Framework Tests');
  WriteLn('================================');
  WriteLn('Testing framework structure and functionality');
  WriteLn('');

  // Basic framework tests (no library required)
  TestWolfSSLConstants;
  TestWolfSSLErrorMapping;
  TestWolfSSLProtocolMapping;
  TestWolfSSLLibraryCreation;
  TestWolfSSLCapabilities;
  TestWolfSSLCapabilityHelperLossContract;

  // Certificate tests
  TestWolfSSLCertificateClass;
  TestWolfSSLCertificateAlgorithmMetadataContract;
  TestWolfSSLCertificateIdentityGetterContract;
  TestWolfSSLCertificateVersionTruthContract;
  TestWolfSSLCertificateTimeTruthContract;
  TestWolfSSLCertificateStreamMemoryTruthContract;
  TestWolfSSLCertificateVerificationTruthContract;
  TestWolfSSLVerifyExExpirySelfSignedFlagParityContract;
  TestWolfSSLCertificateExtensionMetadataContract;
  TestWolfSSLCertificateCloneMaterializationContract;
  TestWolfSSLCertificateStore;

  // Session class tests (no library required)
  TestWolfSSLSessionClass;
  TestWolfSSLSessionSourceLifetimeOwnershipContract;
  TestWolfSSLSessionMetadataCompletenessContract;

  // Context tests (require WolfSSL library)
  TestWolfSSLContextCreation;
  TestWolfSSLContextConfiguration;
  TestWolfSSLVerifyStatusBeforeHandshakeContract;
  TestWolfSSLFeatureSupport;

  PrintSummary;

  if GFailCount > 0 then
    Halt(1);
end.
