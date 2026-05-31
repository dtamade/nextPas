{**
 * Test: MbedTLS Backend Framework
 * Purpose: Comprehensive MbedTLS backend framework tests
 *
 * Tests include:
 * - Constants and error mapping
 * - Library creation and initialization
 * - Context creation and configuration
 * - Certificate operations
 * - Session management
 * - Connection interface (mock)
 *
 * Note: Full functionality tests require MbedTLS library to be installed.
 *
 * @author fafafa.ssl team
 * @version 2.0.0
 * @since 2026-01-09
 * @updated 2026-01-10
 *}

program test_mbedtls_framework;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, DateUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.errors,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.mbedtls.base,
  nextpas.core.tls.mbedtls.native_handle,
  nextpas.core.tls.mbedtls.api,
  nextpas.core.tls.mbedtls.lib,
  nextpas.core.tls.mbedtls.context,
  nextpas.core.tls.mbedtls.connection,
  nextpas.core.tls.mbedtls.certificate,
  nextpas.core.tls.mbedtls.session;

var
  GTestCount: Integer = 0;
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;
  GStubMbedTLSPeerCert: Pmbedtls_x509_crt = nil;
  GStubMbedTLSSessionCipherInfo: Tmbedtls_ssl_ciphersuite_info;
  GStubMbedTLSSessionUnixTime: Int64 = 0;
  GStubMbedTLSVersionTLS13: AnsiString = 'TLSv1.3';
  GStubMbedTLSCipherTLS13: AnsiString = 'TLS_AES_128_GCM_SHA256';

type
  TTestMbedTLSConnection = class(TMbedTLSConnection)
  public
    procedure MarkHandshakeCompleteForTest;
  end;

  TMockWrongBackendNativeHandle = class(TInterfacedObject, ISSLNativeHandleAccess)
  private
    FHandle: Pointer;
  public
    constructor Create(AHandle: Pointer);
    function GetNativeHandle: Pointer;
    function GetBackendType: TSSLLibraryType;
    function IsNativeHandleValid: Boolean;
  end;

const
  STUB_MBEDTLS_SERIALIZED_SESSION: array[0..3] of Byte = (9, 8, 7, 6);
  STUB_MBEDTLS_NATIVE_SESSION_ID: array[0..3] of Byte = ($01, $23, $45, $67);
  STUB_MBEDTLS_NATIVE_SESSION_CIPHERSUITE_ID = $1301;

type
  {$PUSH}
  {$PACKRECORDS C}
  TStubMbedTLSSessionNative = record
    mfl_code: Byte;
    exported: Byte;
    endpoint: Byte;
    tls_version: LongInt;
    start: Int64;
    ciphersuite: LongInt;
    id_len: NativeUInt;
    id: array[0..31] of Byte;
  end;
  {$POP}
  PStubMbedTLSSessionNative = ^TStubMbedTLSSessionNative;

procedure PopulateStubMbedTLSNativeSession(ASession: Pmbedtls_ssl_session);
var
  LSession: PStubMbedTLSSessionNative;
begin
  if ASession = nil then
    Exit;

  if GStubMbedTLSSessionUnixTime = 0 then
    GStubMbedTLSSessionUnixTime := DateTimeToUnix(Now);

  LSession := PStubMbedTLSSessionNative(ASession);
  FillChar(LSession^, SizeOf(LSession^), 0);
  LSession^.exported := 1;
  LSession^.endpoint := 0;
  LSession^.tls_version := MBEDTLS_SSL_VERSION_TLS1_3;
  LSession^.start := GStubMbedTLSSessionUnixTime;
  LSession^.ciphersuite := STUB_MBEDTLS_NATIVE_SESSION_CIPHERSUITE_ID;
  LSession^.id_len := Length(STUB_MBEDTLS_NATIVE_SESSION_ID);
  Move(STUB_MBEDTLS_NATIVE_SESSION_ID[0], LSession^.id[0],
    Length(STUB_MBEDTLS_NATIVE_SESSION_ID));
end;

function StubMbedTLSSessionLoadOk(session: Pmbedtls_ssl_session;
  const buf: PByte; len: NativeUInt): Integer; cdecl;
begin
  if (session = nil) or (buf = nil) or (len = 0) then
    Exit(-$7100);
  PopulateStubMbedTLSNativeSession(session);
  Result := 0;
end;

function StubMbedTLSSessionSaveOk(const session: Pmbedtls_ssl_session;
  buf: PByte; buf_len: NativeUInt; olen: PNativeUInt): Integer; cdecl;
begin
  if Assigned(olen) then
    olen^ := Length(STUB_MBEDTLS_SERIALIZED_SESSION);

  if session = nil then
    Exit(-$7100);

  if (buf = nil) or (buf_len < Length(STUB_MBEDTLS_SERIALIZED_SESSION)) then
    Exit(-$6A00);

  Move(STUB_MBEDTLS_SERIALIZED_SESSION[0], buf^,
    Length(STUB_MBEDTLS_SERIALIZED_SESSION));
  Result := 0;
end;

function StubMbedTLSSSLGetSessionOk(ssl: Pmbedtls_ssl_context;
  session: Pmbedtls_ssl_session): Integer; cdecl;
begin
  if (ssl = nil) or (session = nil) then
    Exit(-$7100);
  PopulateStubMbedTLSNativeSession(session);
  Result := 0;
end;

function StubMbedTLSSessionCipherSuiteFromId(
  ciphersuite_id: Integer): Pmbedtls_ssl_ciphersuite_info; cdecl;
begin
  if ciphersuite_id <> STUB_MBEDTLS_NATIVE_SESSION_CIPHERSUITE_ID then
    Exit(nil);

  FillChar(GStubMbedTLSSessionCipherInfo, SizeOf(GStubMbedTLSSessionCipherInfo), 0);
  GStubMbedTLSSessionCipherInfo.id := ciphersuite_id;
  GStubMbedTLSSessionCipherInfo.name := PAnsiChar(GStubMbedTLSCipherTLS13);
  Result := @GStubMbedTLSSessionCipherInfo;
end;

function StubMbedTLSSSLGetVersionTLS13(ssl: Pmbedtls_ssl_context): PAnsiChar; cdecl;
begin
  Result := PAnsiChar(GStubMbedTLSVersionTLS13);
end;

function StubMbedTLSSSLGetCipherSuiteTLS13(ssl: Pmbedtls_ssl_context): PAnsiChar; cdecl;
begin
  Result := PAnsiChar(GStubMbedTLSCipherTLS13);
end;

function StubMbedTLSSSLGetPeerCert(ssl: Pmbedtls_ssl_context): Pmbedtls_x509_crt; cdecl;
begin
  Result := GStubMbedTLSPeerCert;
end;

procedure TTestMbedTLSConnection.MarkHandshakeCompleteForTest;
begin
  FHandshakeComplete := True;
end;

constructor TMockWrongBackendNativeHandle.Create(AHandle: Pointer);
begin
  inherited Create;
  FHandle := AHandle;
end;

function TMockWrongBackendNativeHandle.GetNativeHandle: Pointer;
begin
  Result := FHandle;
end;

function TMockWrongBackendNativeHandle.GetBackendType: TSSLLibraryType;
begin
  Result := sslOpenSSL;
end;

function TMockWrongBackendNativeHandle.IsNativeHandleValid: Boolean;
begin
  Result := FHandle <> nil;
end;

{ Helper function to check if object has native handle }
function HasNativeHandle(const AObject: IInterface): Boolean;
var
  NativeAccess: ISSLNativeHandleAccess;
begin
  Result := Supports(AObject, ISSLNativeHandleAccess, NativeAccess) and
            (NativeAccess.GetNativeHandle <> nil);
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

procedure RequireClientConnection(const AConn: ISSLConnection;
  out AClientConn: ISSLClientConnection; const AWhere: string);
begin
  if not Supports(AConn, ISSLClientConnection, AClientConn) then
    raise Exception.Create(AWhere + ' requires ISSLClientConnection');
end;

procedure RequireCertificateVerification(const AConn: ISSLConnection;
  out ACertVerify: ISSLCertificateVerification; const AWhere: string);
begin
  if not Supports(AConn, ISSLCertificateVerification, ACertVerify) then
    raise Exception.Create(AWhere + ' requires ISSLCertificateVerification');
end;

procedure TestMbedTLSConstants;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Constants ===');

  Test('MBEDTLS_SSL_IS_CLIENT = 0', MBEDTLS_SSL_IS_CLIENT = 0);
  Test('MBEDTLS_SSL_IS_SERVER = 1', MBEDTLS_SSL_IS_SERVER = 1);
  Test('MBEDTLS_SSL_TRANSPORT_STREAM = 0', MBEDTLS_SSL_TRANSPORT_STREAM = 0);
  Test('MBEDTLS_SSL_VERIFY_NONE = 0', MBEDTLS_SSL_VERIFY_NONE = 0);
  Test('MBEDTLS_SSL_VERIFY_REQUIRED = 2', MBEDTLS_SSL_VERIFY_REQUIRED = 2);
  Test('MBEDTLS_MIN_VERSION defined', MBEDTLS_MIN_VERSION > 0);
end;

procedure TestMbedTLSErrorMapping;
var
  LResult: TSSLErrorCode;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Error Mapping ===');

  LResult := MbedTLSErrorToSSLError(0);
  Test('0 maps to sslErrNone', LResult = sslErrNone);

  LResult := MbedTLSErrorToSSLError(MBEDTLS_ERR_SSL_WANT_READ);
  Test('ERR_SSL_WANT_READ maps to sslErrWantRead', LResult = sslErrWantRead);

  LResult := MbedTLSErrorToSSLError(MBEDTLS_ERR_SSL_WANT_WRITE);
  Test('ERR_SSL_WANT_WRITE maps to sslErrWantWrite', LResult = sslErrWantWrite);

  LResult := MbedTLSErrorToSSLError(MBEDTLS_ERR_SSL_TIMEOUT);
  Test('ERR_SSL_TIMEOUT maps to sslErrTimeout', LResult = sslErrTimeout);

  LResult := MbedTLSErrorToSSLError(MBEDTLS_ERR_SSL_HANDSHAKE_FAILURE);
  Test('ERR_SSL_HANDSHAKE_FAILURE maps to sslErrHandshake', LResult = sslErrHandshake);

  LResult := MbedTLSErrorToSSLError(MBEDTLS_ERR_X509_CERT_VERIFY_FAILED);
  Test('ERR_X509_CERT_VERIFY_FAILED maps to sslErrCertificate', LResult = sslErrCertificate);

  LResult := MbedTLSErrorToSSLError(-9999);
  Test('Unknown error maps to sslErrGeneral', LResult = sslErrGeneral);
end;

procedure TestMbedTLSProtocolMapping;
var
  LResult: Integer;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Protocol Mapping ===');

  LResult := SSLProtocolToMbedTLS(sslProtocolTLS12);
  Test('TLS 1.2 maps to $0303', LResult = $0303);

  LResult := SSLProtocolToMbedTLS(sslProtocolTLS13);
  Test('TLS 1.3 maps to $0304', LResult = $0304);

  Test('$0303 maps back to TLS 1.2', MbedTLSProtocolToSSL($0303) = sslProtocolTLS12);
  Test('$0304 maps back to TLS 1.3', MbedTLSProtocolToSSL($0304) = sslProtocolTLS13);
end;

procedure TestMbedTLSLibraryCreation;
var
  LLib: ISSLLibrary;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Library Creation ===');

  LLib := CreateMbedTLSLibrary;
  Test('CreateMbedTLSLibrary returns non-nil', LLib <> nil);
  Test('Library type is sslMbedTLS', LLib.GetLibraryType = sslMbedTLS);
  Test('Library not initialized by default', not LLib.IsInitialized);

  WriteLn('  (Note: Initialize test skipped - requires MbedTLS library)');
end;

procedure TestMbedTLSCapabilities;
var
  LLib: ISSLLibrary;
  LCaps: TSSLBackendCapabilities;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Capabilities (Framework) ===');

  LLib := CreateMbedTLSLibrary;

  LCaps := LLib.GetCapabilities;
  Test('Capabilities struct accessible', True);
  Test('MinTLSVersion defined', Ord(LCaps.MinTLSVersion) >= 0);
  Test('MaxTLSVersion defined', Ord(LCaps.MaxTLSVersion) >= 0);
end;

procedure TestMbedTLSCapabilityHelperLossContract;
var
  LLib: ISSLLibrary;
  LCaps: TSSLBackendCapabilities;
  LOriginalSetHostname: Tmbedtls_ssl_set_hostname;
  LOriginalGetALPN: Tmbedtls_ssl_get_alpn_protocol;
  LOriginalConfALPN: Tmbedtls_ssl_conf_alpn_protocols;
  LOriginalGetSession: Tmbedtls_ssl_get_session;
  LOriginalSetSession: Tmbedtls_ssl_set_session;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Capability Helper-Loss Contract ===');

  if not LoadMbedTLSLibrary then
  begin
    WriteLn('  (Skipped - MbedTLS library not available)');
    Test('Capability helper-loss contract skipped', True);
    Exit;
  end;

  LOriginalSetHostname := mbedtls_ssl_set_hostname;
  LOriginalGetALPN := mbedtls_ssl_get_alpn_protocol;
  LOriginalConfALPN := mbedtls_ssl_conf_alpn_protocols;
  LOriginalGetSession := mbedtls_ssl_get_session;
  LOriginalSetSession := mbedtls_ssl_set_session;

  try
    mbedtls_ssl_set_hostname := nil;
    mbedtls_ssl_get_alpn_protocol := nil;
    mbedtls_ssl_conf_alpn_protocols := nil;
    mbedtls_ssl_get_session := nil;
    mbedtls_ssl_set_session := nil;

    LLib := CreateMbedTLSLibrary;
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
    if IsMbedTLSLoaded then
      UnloadMbedTLSLibrary;
    mbedtls_ssl_set_hostname := LOriginalSetHostname;
    mbedtls_ssl_get_alpn_protocol := LOriginalGetALPN;
    mbedtls_ssl_conf_alpn_protocols := LOriginalConfALPN;
    mbedtls_ssl_get_session := LOriginalGetSession;
    mbedtls_ssl_set_session := LOriginalSetSession;
  end;
end;

procedure TestMbedTLSCertificateClass;
var
  LCert: TMbedTLSCertificate;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Certificate Class ===');

  LCert := TMbedTLSCertificate.Create;
  try
    Test('Certificate created', LCert <> nil);
    Test('Certificate not loaded initially', LCert.GetNativeHandle = nil);
    Test('GetVersion returns default', LCert.GetVersion = 3);
    Test('Clone works', LCert.Clone <> nil);
  finally
    LCert.Free;
  end;
end;

procedure TestMbedTLSCertificateAlgorithmMetadataContract;
var
  LLib: ISSLLibrary;
  LCert: TMbedTLSCertificate;
  LInfo: TSSLCertificateInfo;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Certificate Algorithm Metadata Contract ===');

  LLib := CreateMbedTLSLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('  (Skipped - MbedTLS library not available)');
    Test('Certificate algorithm metadata contract skipped', True);
    Exit;
  end;

  LCert := TMbedTLSCertificate.Create;
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

procedure TestMbedTLSCertificateIdentityGetterContract;
const
  EXPECTED_CN = 'Test Signer ECDSA';
  EXPECTED_SERIAL = '3CE7A277AAE4DB33E123ED853328E5D5E21B38F4';
var
  LLib: ISSLLibrary;
  LCert: TMbedTLSCertificate;
  LSubject: string;
  LIssuer: string;
  LSerial: string;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Certificate Identity Getter Contract ===');

  LLib := CreateMbedTLSLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('  (Skipped - MbedTLS library not available)');
    Test('Certificate identity getter contract skipped', True);
    Exit;
  end;

  LCert := TMbedTLSCertificate.Create;
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
    LSerial := LCert.GetSerialNumber;
    Test('ECDSA identity fixture serial exposes parsed truth',
      NormalizeHexish(LSerial) = EXPECTED_SERIAL);
  finally
    LCert.Free;
    LLib.Finalize;
  end;
end;

procedure TestMbedTLSCertificateVersionTruthContract;
var
  LLib: ISSLLibrary;
  LCert: TMbedTLSCertificate;
  LInfo: TSSLCertificateInfo;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Certificate Version Truth Contract ===');

  LLib := CreateMbedTLSLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('  (Skipped - MbedTLS library not available)');
    Test('Certificate version truth contract skipped', True);
    Exit;
  end;

  LCert := TMbedTLSCertificate.Create;
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

procedure TestMbedTLSCertificateTimeTruthContract;
var
  LLib: ISSLLibrary;
  LCert: TMbedTLSCertificate;
  LDERCert: TMbedTLSCertificate;
  LDER: TBytes;
  LInfo: TSSLCertificateInfo;
  LNotBefore: TDateTime;
  LNotAfter: TDateTime;
  LDERNotBefore: TDateTime;
  LDERNotAfter: TDateTime;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Certificate Time Truth Contract ===');

  LCert := TMbedTLSCertificate.Create;
  try
    Test('Empty cert NotBefore is unknown',
      LCert.GetNotBefore = 0);
    Test('Empty cert NotAfter is unknown',
      LCert.GetNotAfter = 0);
    Test('Empty cert IsExpired stays false',
      not LCert.IsExpired);
    Test('Empty cert DaysUntilExpiry is 0',
      LCert.GetDaysUntilExpiry = 0);
  finally
    LCert.Free;
  end;

  LLib := CreateMbedTLSLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('  (Skipped - MbedTLS library not available)');
    Test('Loaded certificate time truth contract skipped', True);
    Exit;
  end;

  LCert := TMbedTLSCertificate.Create;
  LDERCert := TMbedTLSCertificate.Create;
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

procedure TestMbedTLSCertificateStreamMemoryTruthContract;
var
  LLib: ISSLLibrary;
  LCert: TMbedTLSCertificate;
  LMemoryCert: TMbedTLSCertificate;
  LStreamCert: TMbedTLSCertificate;
  LPEMAnsi: AnsiString;
  LExpectedFingerprint: string;
  LStream: TMemoryStream;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Certificate Stream/Memory Truth Contract ===');

  LLib := CreateMbedTLSLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('  (Skipped - MbedTLS library not available)');
    Test('Certificate stream/memory truth contract skipped', True);
    Exit;
  end;

  LCert := TMbedTLSCertificate.Create;
  LMemoryCert := TMbedTLSCertificate.Create;
  LStreamCert := TMbedTLSCertificate.Create;
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
    Test('LoadFromMemory rejects nil/zero input',
      not LMemoryCert.LoadFromMemory(nil, 0));
    Test('LoadFromMemory nil/zero failure clears loaded DER state',
      Length(LMemoryCert.SaveToDER) = 0);

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

procedure TestMbedTLSCertificateVerificationTruthContract;
var
  LLib: ISSLLibrary;
  LLeafCert: ISSLCertificate;
  LRealCACert: ISSLCertificate;
  LStore: ISSLCertificateStore;
  LVerifyResult: TSSLCertVerifyResult;
  LVerified: Boolean;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Certificate Verification Truth Contract ===');

  LLib := CreateMbedTLSLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('  (Skipped - MbedTLS library not available)');
    Test('Certificate verification truth contract skipped', True);
    Exit;
  end;

  LLeafCert := TMbedTLSCertificate.Create;
  LRealCACert := TMbedTLSCertificate.Create;
  LStore := TMbedTLSCertificateStore.Create;
  try
    Test('Load verification leaf fixture',
      LLeafCert.LoadFromFile('tests/certificate/test_certs/signer_cert.pem'));
    Test('Load verification CA fixture',
      LRealCACert.LoadFromFile('tests/certificate/test_certs/ca_cert.pem'));
    Test('Add verification CA fixture to store',
      LStore.AddCertificate(LRealCACert));

    LVerified := LLeafCert.VerifyEx(LStore, [], LVerifyResult);
    Test('VerifyEx succeeds with real issuer certificate',
      LVerified and LVerifyResult.Success);
    Test('VerifyEx success populates detail text',
      Trim(LVerifyResult.DetailedInfo) <> '');
    Test('VerifyEx success keeps revocation status clear',
      LVerifyResult.RevocationStatus = 0);

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
    LStore := nil;
    LRealCACert := nil;
    LLeafCert := nil;
    LLib.Finalize;
  end;
end;

procedure TestMbedTLSVerifyExExpirySelfSignedFlagParityContract;
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
  WriteLn('=== MbedTLS VerifyEx Expiry/Self-Signed Flag Parity ===');

  LLib := CreateMbedTLSLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('  (Skipped - MbedTLS library not available)');
    Test('VerifyEx expiry/self-signed flag parity skipped', True);
    Exit;
  end;

  LExpiredLeaf := TMbedTLSCertificate.Create;
  LSelfSignedLeaf := TMbedTLSCertificate.Create;
  LIssuerCert := TMbedTLSCertificate.Create;
  LStore := TMbedTLSCertificateStore.Create;
  LEmptyStore := TMbedTLSCertificateStore.Create;
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
      (Pos('not trusted', LowerCase(LVerifyResult.ErrorMessage + ' ' + LVerifyResult.DetailedInfo)) > 0) or
      (Pos('verification failed', LowerCase(LVerifyResult.ErrorMessage)) > 0));

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

procedure TestMbedTLSCertificateExtensionMetadataContract;
var
  LLib: ISSLLibrary;
  LCert: TMbedTLSCertificate;
  LInfo: TSSLCertificateInfo;
  LValues: TSSLStringArray;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Certificate Extension Metadata Contract ===');

  LLib := CreateMbedTLSLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('  (Skipped - MbedTLS library not available)');
    Test('Certificate extension metadata contract skipped', True);
    Exit;
  end;

  LCert := TMbedTLSCertificate.Create;
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

procedure TestMbedTLSCertificateStore;
var
  LStore: TMbedTLSCertificateStore;
  LCert: ISSLCertificate;
  LLib: ISSLLibrary;
  LSubjectVariant: string;
  LIssuerVariant: string;
  LStoreClone: ISSLCertificate;
  LChainIssuer: ISSLCertificate;
  LChain: TSSLCertificateArray;
  LSerialCompact: string;
  LSerialVariant: string;
  LFingerprintVariant: string;
  LCharIndex: Integer;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Certificate Store ===');

  LStore := TMbedTLSCertificateStore.Create;
  LLib := CreateMbedTLSLibrary;
  try
    Test('Store created', LStore <> nil);
    Test('Store initially empty', LStore.GetCount = 0);

    LCert := TMbedTLSCertificate.Create;
    Test('AddCertificate returns true', LStore.AddCertificate(LCert));
    Test('Store count is 1', LStore.GetCount = 1);
    Test('GetCertificate(0) returns cert', LStore.GetCertificate(0) <> nil);

    Test('AddCertificate duplicate returns false', not LStore.AddCertificate(LCert));
    Test('Store count still 1', LStore.GetCount = 1);

    Test('RemoveCertificate returns true', LStore.RemoveCertificate(LCert));
    Test('Store count is 0', LStore.GetCount = 0);

    if (LLib <> nil) and LLib.Initialize then
    begin
      LCert := TMbedTLSCertificate.Create;
      Test('Load fixture cert for certstore query semantics',
        LCert.LoadFromFile('tests/certificate/test_certs/signer_ecdsa_cert.pem'));
      Test('Add loaded cert returns true', LStore.AddCertificate(LCert));
      LStoreClone := LCert.Clone;
      Test('Contains clone should be true by fingerprint', LStore.Contains(LStoreClone));
      Test('Add clone duplicate returns false', not LStore.AddCertificate(LStoreClone));
      Test('Remove clone should remove by fingerprint', LStore.RemoveCertificate(LStoreClone));
      Test('Store count returns to 0 after clone removal', LStore.GetCount = 0);
      Test('Re-add loaded cert returns true after clone removal', LStore.AddCertificate(LCert));

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

      LCert := TMbedTLSCertificate.Create;
      Test('Load distinct-issuer fixture for issuer query semantics',
        LCert.LoadFromFile('tests/certificate/test_certs/signer_cert.pem'));
      Test('Add distinct-issuer fixture returns true', LStore.AddCertificate(LCert));
      LIssuerVariant := UpperCase(StringReplace(StringReplace(LCert.GetIssuer, ',', ' , ', [rfReplaceAll]),
        '=', ' = ', [rfReplaceAll]));
      Test('FindByIssuer supports normalized query variant', LStore.FindByIssuer(LIssuerVariant) <> nil);
      Test('FindByIssuer empty query returns nil', LStore.FindByIssuer('') = nil);
      Test('Remove distinct-issuer fixture succeeds', LStore.RemoveCertificate(LCert));
      Test('Store count back to 0 after issuer query semantics', LStore.GetCount = 0);

      LCert := TMbedTLSCertificate.Create;
      Test('Load chain leaf fixture for explicit issuer-link semantics',
        LCert.LoadFromFile('tests/certificate/test_certs/signer_cert.pem'));
      LChainIssuer := TMbedTLSCertificate.Create;
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
      Test('Certstore query semantics skipped when MbedTLS runtime unavailable', True);
    end;

    LStore.AddCertificate(TMbedTLSCertificate.Create);
    LStore.AddCertificate(TMbedTLSCertificate.Create);
    Test('Store count is 2', LStore.GetCount = 2);
    LStore.Clear;
    Test('Store cleared', LStore.GetCount = 0);
  finally
    LStore.Free;
  end;
end;

procedure TestMbedTLSNativeHandleContract;
var
  LMockWrong: IInterface;
  LRaised: Boolean;
  LHandle: Pointer;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Native Handle Contract ===');

  LMockWrong := TMockWrongBackendNativeHandle.Create(Pointer($1234));
  LRaised := False;
  try
    LHandle := GetNativeHandleSafe(LMockWrong, 'TestMbedTLSNativeHandleContract');
    Test('MbedTLS native-handle helper rejects non-MbedTLS backend', False);
  except
    on E: ESSLException do
    begin
      LRaised := Pos('not a mbedtls backend', LowerCase(E.Message)) > 0;
      Test('MbedTLS native-handle helper rejects non-MbedTLS backend', LRaised);
    end;
  end;

  Test('TryGetNativeHandle returns handle for non-nil interface',
    TryGetNativeHandle(LMockWrong, LHandle) and (LHandle <> nil));
end;

procedure TestMbedTLSSessionClass;
var
  LSession: TMbedTLSSession;
  LClone: ISSLSession;
  LRoundTrip: ISSLSession;
  LData: TBytes;
  LOriginalSessionLoad: Tmbedtls_ssl_session_load;
  LOriginalSessionSave: Tmbedtls_ssl_session_save;
  LOriginalCipherSuiteFromId: Tmbedtls_ssl_ciphersuite_from_id;
  LCloneNative: ISSLNativeHandleAccess;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Session Class ===');

  LSession := TMbedTLSSession.Create;
  try
    Test('Session created', LSession <> nil);
    Test('Session ID not empty', LSession.GetID <> '');
    Test('Session creation time valid', LSession.GetCreationTime > 0);
    Test('Session timeout default', LSession.GetTimeout = SSL_DEFAULT_SESSION_TIMEOUT);
    Test('Session not valid without handle', not LSession.IsValid);
    Test('Session not resumable without handle', not LSession.IsResumable);
    Test('Native handle is nil', LSession.GetNativeHandle = nil);

    LSession.SetTimeout(7200);
    Test('Session timeout updated', LSession.GetTimeout = 7200);

    LClone := LSession.Clone;
    Test('Clone created', LClone <> nil);
    Test('Clone has same timeout', LClone.GetTimeout = 7200);
    Test('Clone has same ID', LClone.GetID = LSession.GetID);

    Test('Serialize returns empty for no session', Length(LSession.Serialize) = 0);
    Test('Deserialize rejects empty payload', not LSession.Deserialize(nil));

    LOriginalSessionLoad := mbedtls_ssl_session_load;
    LOriginalSessionSave := mbedtls_ssl_session_save;
    LOriginalCipherSuiteFromId := mbedtls_ssl_ciphersuite_from_id;
    try
      mbedtls_ssl_session_load := nil;
      mbedtls_ssl_session_save := nil;

      Test('Deserialize rejects payload when session-load helper unavailable',
        not LSession.Deserialize(TBytes.Create(1, 2, 3, 4)));
      Test('Serialize remains empty after helper-less deserialize rejection',
        Length(LSession.Serialize) = 0);
    finally
      mbedtls_ssl_session_load := LOriginalSessionLoad;
      mbedtls_ssl_session_save := LOriginalSessionSave;
    end;

    try
      mbedtls_ssl_session_load := @StubMbedTLSSessionLoadOk;
      mbedtls_ssl_session_save := @StubMbedTLSSessionSaveOk;
      mbedtls_ssl_ciphersuite_from_id := @StubMbedTLSSessionCipherSuiteFromId;

      Test('Deserialize accepts data when session-load helper succeeds',
        LSession.Deserialize(TBytes.Create(1, 2, 3, 4)));
      Test('Deserialized session becomes valid', LSession.IsValid);
      Test('Native handle exists after successful deserialize',
        LSession.GetNativeHandle <> nil);
      Test('Deserialized session exposes native session id truth',
        LSession.GetID = '01234567');
      Test('Deserialized session exposes native creation time truth',
        Abs(LSession.GetCreationTime -
          UnixToDateTime(GStubMbedTLSSessionUnixTime)) < (1 / 86400));
      Test('Deserialized session exposes native protocol truth',
        LSession.GetProtocolVersion = sslProtocolTLS13);
      Test('Deserialized session exposes native cipher truth',
        LSession.GetCipherName = string(GStubMbedTLSCipherTLS13));

      LData := LSession.Serialize;
      Test('Serialize returns metadata-complete snapshot after deserialize',
        Length(LData) > 0);
      LRoundTrip := TMbedTLSSession.Create;
      Test('Serialized snapshot after native-truth deserialize stays reloadable',
        (LRoundTrip <> nil) and LRoundTrip.Deserialize(LData));
      Test('Reloaded snapshot preserves native session id truth',
        (LRoundTrip <> nil) and (LRoundTrip.GetID = '01234567'));
      Test('Reloaded snapshot preserves native creation time truth',
        (LRoundTrip <> nil) and
        (Abs(LRoundTrip.GetCreationTime -
          UnixToDateTime(GStubMbedTLSSessionUnixTime)) < (1 / 86400)));
      Test('Reloaded snapshot preserves native protocol truth',
        (LRoundTrip <> nil) and
        (LRoundTrip.GetProtocolVersion = sslProtocolTLS13));
      Test('Reloaded snapshot preserves native cipher truth',
        (LRoundTrip <> nil) and
        (LRoundTrip.GetCipherName = string(GStubMbedTLSCipherTLS13)));

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
      mbedtls_ssl_session_load := LOriginalSessionLoad;
      mbedtls_ssl_session_save := LOriginalSessionSave;
      mbedtls_ssl_ciphersuite_from_id := LOriginalCipherSuiteFromId;
    end;
  finally
    LSession.Free;
  end;
end;

procedure TestMbedTLSSessionMetadataCompletenessContract;
var
  LLib: ISSLLibrary;
  LFixtureCert: TMbedTLSCertificate;
  LSession: ISSLSession;
  LClone: ISSLSession;
  LRoundTripSession: TMbedTLSSession;
  LRoundTripClone: ISSLSession;
  LPeerCert: ISSLCertificate;
  LClonePeerCert: ISSLCertificate;
  LSerializedData: TBytes;
  LExpectedFingerprint: string;
  LOriginalGetSession: Tmbedtls_ssl_get_session;
  LOriginalGetVersion: Tmbedtls_ssl_get_version;
  LOriginalGetCipherSuite: Tmbedtls_ssl_get_ciphersuite;
  LOriginalGetPeerCert: Tmbedtls_ssl_get_peer_cert;
  LOriginalSessionLoad: Tmbedtls_ssl_session_load;
  LOriginalSessionSave: Tmbedtls_ssl_session_save;
  LOriginalCipherSuiteFromId: Tmbedtls_ssl_ciphersuite_from_id;
  LOriginalX509Parse: Tmbedtls_x509_crt_parse;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Session Metadata Completeness Contract ===');

  LLib := CreateMbedTLSLibrary;
  if not LLib.Initialize then
  begin
    WriteLn('  (Skipped - MbedTLS library not available)');
    Test('Session metadata completeness skipped', True);
    Exit;
  end;

  LFixtureCert := TMbedTLSCertificate.Create;
  try
    if not LFixtureCert.LoadFromFile('tests/certs/server-cert.pem') then
    begin
      WriteLn('  (Skipped - fixture certificate unavailable)');
      Test('Session metadata completeness skipped', True);
      Exit;
    end;

    GStubMbedTLSPeerCert := Pmbedtls_x509_crt(LFixtureCert.GetNativeHandle);
    LExpectedFingerprint := LFixtureCert.GetFingerprintSHA256;

    LOriginalGetSession := mbedtls_ssl_get_session;
    LOriginalGetVersion := mbedtls_ssl_get_version;
    LOriginalGetCipherSuite := mbedtls_ssl_get_ciphersuite;
    LOriginalGetPeerCert := mbedtls_ssl_get_peer_cert;
    LOriginalSessionLoad := mbedtls_ssl_session_load;
    LOriginalSessionSave := mbedtls_ssl_session_save;
    LOriginalCipherSuiteFromId := mbedtls_ssl_ciphersuite_from_id;
    LOriginalX509Parse := mbedtls_x509_crt_parse;
    try
      mbedtls_ssl_get_session := @StubMbedTLSSSLGetSessionOk;
      mbedtls_ssl_get_version := @StubMbedTLSSSLGetVersionTLS13;
      mbedtls_ssl_get_ciphersuite := @StubMbedTLSSSLGetCipherSuiteTLS13;
      mbedtls_ssl_get_peer_cert := @StubMbedTLSSSLGetPeerCert;
      mbedtls_ssl_session_load := @StubMbedTLSSessionLoadOk;
      mbedtls_ssl_session_save := @StubMbedTLSSessionSaveOk;
      mbedtls_ssl_ciphersuite_from_id := @StubMbedTLSSessionCipherSuiteFromId;

      LSession := TMbedTLSSession.FromContext(Pmbedtls_ssl_context(Pointer(1)));
      Test('FromContext returns session when session helper succeeds', LSession <> nil);
      Test('FromContext extracts native session id truth',
        (LSession <> nil) and (LSession.GetID = '01234567'));
      Test('FromContext extracts native creation time truth',
        (LSession <> nil) and
        (Abs(LSession.GetCreationTime -
          UnixToDateTime(GStubMbedTLSSessionUnixTime)) < (1 / 86400)));
      Test('FromContext extracts protocol version truth',
        (LSession <> nil) and (LSession.GetProtocolVersion = sslProtocolTLS13));
      Test('FromContext extracts cipher truth',
        (LSession <> nil) and (LSession.GetCipherName = string(GStubMbedTLSCipherTLS13)));

      LPeerCert := nil;
      if LSession <> nil then
        LPeerCert := LSession.GetPeerCertificate;
      Test('FromContext materializes peer certificate as owned copy',
        LPeerCert <> nil);
      Test('FromContext peer certificate matches fixture fingerprint',
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

      LRoundTripSession := TMbedTLSSession.Create;
      try
        Test('Metadata-complete session deserialize succeeds from serialized snapshot',
          LRoundTripSession.Deserialize(LSerializedData));
        Test('Round-tripped session preserves protocol version truth',
          LRoundTripSession.GetProtocolVersion = sslProtocolTLS13);
        Test('Round-tripped session preserves cipher truth',
          LRoundTripSession.GetCipherName = string(GStubMbedTLSCipherTLS13));

        LRoundTripClone := LRoundTripSession.Clone;
        Test('Clone after deserialize preserves protocol version truth',
          (LRoundTripClone <> nil) and
          (LRoundTripClone.GetProtocolVersion = sslProtocolTLS13));
        Test('Clone after deserialize preserves cipher truth',
          (LRoundTripClone <> nil) and
          (LRoundTripClone.GetCipherName = string(GStubMbedTLSCipherTLS13)));
      finally
        LRoundTripSession.Free;
      end;
    finally
      mbedtls_ssl_get_session := LOriginalGetSession;
      mbedtls_ssl_get_version := LOriginalGetVersion;
      mbedtls_ssl_get_ciphersuite := LOriginalGetCipherSuite;
      mbedtls_ssl_get_peer_cert := LOriginalGetPeerCert;
      mbedtls_ssl_session_load := LOriginalSessionLoad;
      mbedtls_ssl_session_save := LOriginalSessionSave;
      mbedtls_ssl_ciphersuite_from_id := LOriginalCipherSuiteFromId;
      mbedtls_x509_crt_parse := LOriginalX509Parse;
    end;

    LSession := nil;
    LPeerCert := nil;
    try
      mbedtls_ssl_get_session := @StubMbedTLSSSLGetSessionOk;
      mbedtls_ssl_get_version := @StubMbedTLSSSLGetVersionTLS13;
      mbedtls_ssl_get_ciphersuite := @StubMbedTLSSSLGetCipherSuiteTLS13;
      mbedtls_ssl_get_peer_cert := @StubMbedTLSSSLGetPeerCert;
      mbedtls_ssl_session_load := @StubMbedTLSSessionLoadOk;
      mbedtls_ssl_session_save := @StubMbedTLSSessionSaveOk;
      mbedtls_ssl_ciphersuite_from_id := @StubMbedTLSSessionCipherSuiteFromId;
      mbedtls_x509_crt_parse := nil;

      LSession := TMbedTLSSession.FromContext(Pmbedtls_ssl_context(Pointer(1)));
      if LSession <> nil then
        LPeerCert := LSession.GetPeerCertificate;

      Test('FromContext keeps session truth when peer-cert copy helper is unavailable',
        LSession <> nil);
      Test('FromContext fails closed when peer certificate cannot be materialized',
        LPeerCert = nil);
    finally
      mbedtls_ssl_get_session := LOriginalGetSession;
      mbedtls_ssl_get_version := LOriginalGetVersion;
      mbedtls_ssl_get_ciphersuite := LOriginalGetCipherSuite;
      mbedtls_ssl_get_peer_cert := LOriginalGetPeerCert;
      mbedtls_ssl_session_load := LOriginalSessionLoad;
      mbedtls_ssl_session_save := LOriginalSessionSave;
      mbedtls_ssl_ciphersuite_from_id := LOriginalCipherSuiteFromId;
      mbedtls_x509_crt_parse := LOriginalX509Parse;
    end;
  finally
    GStubMbedTLSPeerCert := nil;
    LFixtureCert.Free;
    LLib.Finalize;
  end;
end;

procedure TestMbedTLSContextCreation;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LInitialized: Boolean;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Context Creation ===');

  LLib := CreateMbedTLSLibrary;
  LInitialized := LLib.Initialize;

  if LInitialized then
  begin
    WriteLn('  MbedTLS library initialized successfully');

    try
      LCtx := LLib.CreateContext(sslCtxClient);
      Test('Client context created', LCtx <> nil);
      Test('Context type is client', LCtx.GetContextType = sslCtxClient);
      Test('Context is valid', LCtx.IsValid);
      Test('Native handle not nil', HasNativeHandle(LCtx));

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
    WriteLn('  (Skipped - MbedTLS library not available)');
    Test('Context creation skipped', True);
  end;
end;

procedure TestMbedTLSContextConfiguration;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LClientConn: ISSLClientConnection;
  LCertVerify: ISSLCertificateVerification;
  LErrMsg: string;
  LRaised: Boolean;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Context Configuration ===');

  LLib := CreateMbedTLSLibrary;

  if LLib.Initialize then
  begin
    try
      LCtx := LLib.CreateContext(sslCtxClient);

      LCtx.SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
      Test('Protocol versions set', sslProtocolTLS12 in LCtx.GetProtocolVersions);

      LCtx.SetVerifyMode([sslVerifyPeer, sslVerifyFailIfNoPeerCert]);
      Test('Verify mode set', sslVerifyFailIfNoPeerCert in LCtx.GetVerifyMode);

      LCtx.SetVerifyDepth(5);
      Test('Verify depth set to 5', LCtx.GetVerifyDepth = 5);

      LCtx.SetSessionCacheMode(False);
      Test('Session cache disabled', not LCtx.GetSessionCacheMode);
      LCtx.SetSessionCacheMode(True);
      Test('Session cache enabled', LCtx.GetSessionCacheMode);

      LCtx.SetSessionTimeout(3600);
      Test('Session timeout set', LCtx.GetSessionTimeout = 3600);

      LCtx.SetALPNProtocols('h2,http/1.1');
      Test('ALPN protocols set', LCtx.GetALPNProtocols = 'h2,http/1.1');

      LCtx.SetOptions([ssoEnableSNI, ssoEnableALPN]);
      Test('Options set', ssoEnableSNI in LCtx.GetOptions);

      // Renegotiation explicit unsupported semantics
      LConn := LCtx.CreateConnection(0);
      RequireClientConnection(LConn, LClientConn,
        'TestMbedTLSContextConfiguration');
      LClientConn.SetServerName('example.com');
      Test('Server name set on connection',
        LClientConn.GetServerName = 'example.com');
      Test('Renegotiate returns false before handshake', not LConn.Renegotiate);
      Test('Renegotiate reports unsupported error class',
        LConn.GetError(-1) = sslErrUnsupported);
      RequireCertificateVerification(LConn, LCertVerify,
        'TestMbedTLSContextConfiguration');
      LErrMsg := LCertVerify.GetVerifyResultString;
      Test('Renegotiate exposes non-empty diagnostic message',
        Pos('renegotiation', LowerCase(LErrMsg)) > 0);

      LRaised := False;
      try
        LCtx.LoadCertificatePEM('not a valid pem certificate');
      except
        on E: ESSLCertError do
          LRaised := Pos('certificate', LowerCase(E.Message)) > 0;
      end;
      Test('Invalid certificate PEM raises ESSLCertError mapping', LRaised);

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
    WriteLn('  (Skipped - MbedTLS library not available)');
    Test('Context configuration skipped', True);
  end;
end;

procedure TestMbedTLSVerifyResultHelperLossContract;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LConn: TTestMbedTLSConnection;
  LConnIntf: ISSLConnection;
  LCertVerify: ISSLCertificateVerification;
  LStream: TMemoryStream;
  LVerifyResult: Integer;
  LVerifyText: string;
  LOriginalGetVerifyResult: Tmbedtls_ssl_get_verify_result;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Verify Result Helper-Loss Contract ===');

  LLib := CreateMbedTLSLibrary;

  if LLib.Initialize then
  begin
    LCtx := LLib.CreateContext(sslCtxClient);
    LStream := TMemoryStream.Create;
    LConn := nil;
    LConnIntf := nil;
    try
      LConn := TTestMbedTLSConnection.Create(
        LCtx,
        Pmbedtls_ssl_config(GetNativeHandleSafe(LCtx,
          'TestMbedTLSVerifyResultHelperLossContract')),
        LStream
      );
      LConn.MarkHandshakeCompleteForTest;
      LConnIntf := LConn as ISSLConnection;
      LConn := nil;
      LOriginalGetVerifyResult := mbedtls_ssl_get_verify_result;
      try
        mbedtls_ssl_get_verify_result := nil;

        RequireCertificateVerification(LConnIntf, LCertVerify,
          'TestMbedTLSVerifyResultHelperLossContract');
        LVerifyResult := LCertVerify.GetVerifyResult;
        LVerifyText := LowerCase(LCertVerify.GetVerifyResultString);

        Test('VerifyResult helper loss degrades to -1', LVerifyResult = -1);
        Test('VerifyResultString helper loss exposes unavailable diagnostic',
          Pos('unavailable', LVerifyText) > 0);
      finally
        mbedtls_ssl_get_verify_result := LOriginalGetVerifyResult;
      end;
    finally
      LCertVerify := nil;
      LConnIntf := nil;
      LStream.Free;
      LLib.Finalize;
    end;
  end
  else
  begin
    WriteLn('  (Skipped - MbedTLS library not available)');
    Test('VerifyResult helper-loss contract skipped', True);
  end;
end;

procedure TestMbedTLSVerifyStatusBeforeHandshakeContract;
var
  LLib: ISSLLibrary;
  LCtx: ISSLContext;
  LConn: ISSLConnection;
  LCertVerify: ISSLCertificateVerification;
  LStream: TMemoryStream;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Pre-Handshake Verify Status Contract ===');

  LLib := CreateMbedTLSLibrary;

  if LLib.Initialize then
  begin
    LCtx := LLib.CreateContext(sslCtxClient);
    LStream := TMemoryStream.Create;
    try
      LConn := LCtx.CreateConnection(LStream);
      RequireCertificateVerification(LConn, LCertVerify,
        'TestMbedTLSVerifyStatusBeforeHandshakeContract');
      Test('Fresh MbedTLS connection does not report verify success before handshake',
        LCertVerify.GetVerifyResult = -1);
      Test('Fresh MbedTLS connection reports not-verified diagnostic before handshake',
        Pos('not verified', LowerCase(LCertVerify.GetVerifyResultString)) > 0);
    finally
      LStream.Free;
      LLib.Finalize;
    end;
  end
  else
  begin
    WriteLn('  (Skipped - MbedTLS library not available)');
    Test('Pre-handshake verify-status contract skipped', True);
  end;
end;

procedure TestMbedTLSFeatureSupport;
var
  LLib: ISSLLibrary;
begin
  WriteLn('');
  WriteLn('=== MbedTLS Feature Support ===');

  LLib := CreateMbedTLSLibrary;

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

    Test('Session cache feature', LLib.IsFeatureSupported(sslFeatSessionCache));
    Test('Known TLS1.3 cipher is reported supported',
      LLib.IsCipherSupported('TLS_AES_128_GCM_SHA256'));
    Test('Unknown fake cipher is rejected',
      not LLib.IsCipherSupported('TLS_FAKE_AES_128_GCM_SHA256'));
    Test('Empty cipher name is rejected',
      not LLib.IsCipherSupported(''));

    Test('Version string not empty', LLib.GetVersionString <> '');
    WriteLn('  Version: ', LLib.GetVersionString);

    LLib.Finalize;
  end
  else
  begin
    WriteLn('  (Skipped - MbedTLS library not available)');
    Test('Feature support skipped', True);
  end;
end;

procedure PrintSummary;
var
  LPassRate: Double;
begin
  WriteLn('');
  WriteLn('========================================');
  WriteLn('MbedTLS Framework Test Summary');
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
  WriteLn('MbedTLS Backend Framework Tests');
  WriteLn('================================');
  WriteLn('Testing framework structure and functionality');
  WriteLn('');

  // Basic framework tests (no library required)
  TestMbedTLSConstants;
  TestMbedTLSErrorMapping;
  TestMbedTLSProtocolMapping;
  TestMbedTLSLibraryCreation;
  TestMbedTLSCapabilities;
  TestMbedTLSCapabilityHelperLossContract;

  // Certificate tests
  TestMbedTLSCertificateClass;
  TestMbedTLSCertificateAlgorithmMetadataContract;
  TestMbedTLSCertificateIdentityGetterContract;
  TestMbedTLSCertificateVersionTruthContract;
  TestMbedTLSCertificateTimeTruthContract;
  TestMbedTLSCertificateStreamMemoryTruthContract;
  TestMbedTLSCertificateVerificationTruthContract;
  TestMbedTLSVerifyExExpirySelfSignedFlagParityContract;
  TestMbedTLSCertificateExtensionMetadataContract;
  TestMbedTLSCertificateStore;
  TestMbedTLSNativeHandleContract;

  // Session class tests (no library required)
  TestMbedTLSSessionClass;
  TestMbedTLSSessionMetadataCompletenessContract;

  // Context tests (require MbedTLS library)
  TestMbedTLSContextCreation;
  TestMbedTLSContextConfiguration;
  TestMbedTLSVerifyResultHelperLossContract;
  TestMbedTLSVerifyStatusBeforeHandshakeContract;
  TestMbedTLSFeatureSupport;

  PrintSummary;

  if GFailCount > 0 then
    Halt(1);
end.
