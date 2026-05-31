program test_mbedtls_connection_info_ciphersuite_contract;

{$mode ObjFPC}{$H+}
{$DEFINE ENABLE_MBEDTLS}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.mbedtls.base,
  nextpas.core.tls.mbedtls.api,
  nextpas.core.tls.mbedtls.lib;

var
  GLib: ISSLLibrary = nil;
  TotalTests: Integer = 0;
  PassedTests: Integer = 0;
  FailedTests: Integer = 0;
  SkippedTests: Integer = 0;
  GLegacySha256CipherName: AnsiString = 'TLS-ECDHE-RSA-WITH-AES-128-CBC-SHA256';
  GLegacySha1CipherName: AnsiString = 'TLS-RSA-WITH-AES-128-CBC-SHA';
  GTLS13CipherName: AnsiString = 'TLS_AES_128_GCM_SHA256';
  GStubCipherSuiteId: Integer = 0;
  GStubCipherSuiteInfo: Tmbedtls_ssl_ciphersuite_info;
  GStubCipherKeyBits: NativeUInt = 0;
  GSha1VersionString: AnsiString = 'TLSv1.2';
  GTls13VersionString: AnsiString = 'TLSv1.3';

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

function BytesToHex(const AData: TBytes): string;
const
  HEX_CHARS: array[0..15] of Char = '0123456789abcdef';
var
  I: Integer;
begin
  SetLength(Result, Length(AData) * 2);
  for I := 0 to High(AData) do
  begin
    Result[(I * 2) + 1] := HEX_CHARS[AData[I] shr 4];
    Result[(I * 2) + 2] := HEX_CHARS[AData[I] and $0F];
  end;
end;

function StubMbedTLSSSLGetVersionTLS12(ssl: Pmbedtls_ssl_context): PAnsiChar; cdecl;
begin
  Result := PAnsiChar(GSha1VersionString);
end;

function StubMbedTLSSSLGetVersionTLS13(ssl: Pmbedtls_ssl_context): PAnsiChar; cdecl;
begin
  Result := PAnsiChar(GTls13VersionString);
end;

function StubMbedTLSSSLGetCipherSuiteLegacySha256(ssl: Pmbedtls_ssl_context): PAnsiChar; cdecl;
begin
  Result := PAnsiChar(GLegacySha256CipherName);
end;

function StubMbedTLSSSLGetCipherSuiteLegacySha1(ssl: Pmbedtls_ssl_context): PAnsiChar; cdecl;
begin
  Result := PAnsiChar(GLegacySha1CipherName);
end;

function StubMbedTLSSSLGetCipherSuiteTLS13(ssl: Pmbedtls_ssl_context): PAnsiChar; cdecl;
begin
  Result := PAnsiChar(GTLS13CipherName);
end;

function StubMbedTLSSSLGetCipherSuiteIdFromSSL(const ssl: Pmbedtls_ssl_context): Integer; cdecl;
begin
  Result := GStubCipherSuiteId;
end;

function StubMbedTLSSSLGetCipherSuiteId(const ciphersuite_name: PAnsiChar): Integer; cdecl;
begin
  Result := GStubCipherSuiteId;
end;

function StubMbedTLSSSLCipherSuiteFromId(ciphersuite_id: Integer): Pmbedtls_ssl_ciphersuite_info; cdecl;
begin
  if ciphersuite_id = GStubCipherSuiteId then
    Result := @GStubCipherSuiteInfo
  else
    Result := nil;
end;

function StubMbedTLSSSLCipherSuiteGetCipherKeyBitLen(
  const info: Pmbedtls_ssl_ciphersuite_info): NativeUInt; cdecl;
begin
  Result := GStubCipherKeyBits;
end;

procedure WarmupSocketConnectionConstructor(AContext: ISSLContext);
var
  LConn: ISSLConnection;
begin
  LConn := AContext.CreateConnection(THandle(-1));
  if LConn = nil then
    raise Exception.Create('socket connection constructor warmup returned nil');
end;

function CaptureFreshConnectionInfo(AContext: ISSLContext): TSSLConnectionInfo;
var
  LConn: ISSLConnection;
  LConnInfoAccess: ISSLConnectionInfo;
begin
  LConn := AContext.CreateConnection(THandle(-1));
  if not Supports(LConn, ISSLConnectionInfo, LConnInfoAccess) then
    raise Exception.Create('MbedTLS connection does not expose ISSLConnectionInfo');
  Result := LConnInfoAccess.GetConnectionInfo;
end;

procedure AssertConnectionInfoTruth(
  const AName: string;
  AContext: ISSLContext;
  AExpectedCipherSuiteId: Word;
  AExpectedKeySize: Integer;
  AExpectedMacSize: Integer
);
var
  LInfo: TSSLConnectionInfo;
begin
  LInfo := CaptureFreshConnectionInfo(AContext);

  AssertTrue(AName + ' should derive CipherSuiteId',
    LInfo.CipherSuiteId = AExpectedCipherSuiteId,
    Format('expected CipherSuiteId=%d but got %d', [AExpectedCipherSuiteId, LInfo.CipherSuiteId]));
  AssertTrue(AName + ' should derive KeySize',
    LInfo.KeySize = AExpectedKeySize,
    Format('expected KeySize=%d but got %d', [AExpectedKeySize, LInfo.KeySize]));
  AssertTrue(AName + ' should derive MacSize',
    LInfo.MacSize = AExpectedMacSize,
    Format('expected MacSize=%d but got %d', [AExpectedMacSize, LInfo.MacSize]));
end;

procedure TestDigestConstantTruth;
const
  EXPECTED_SHA1_ABC = 'a9993e364706816aba3e25717850c26c9cd0d89d';
var
  LInput: RawByteString;
  LInfo: Pointer;
  LDigest: TBytes;
begin
  WriteLn;
  WriteLn('=== MbedTLS digest constant truth ===');

  if (not Assigned(mbedtls_md_info_from_type)) or
     (not Assigned(mbedtls_md_get_size)) or
     (not Assigned(mbedtls_md)) then
  begin
    MarkSkip('mbedtls digest constant truth',
      'required digest helpers are unavailable');
    Exit;
  end;

  LInfo := mbedtls_md_info_from_type(MBEDTLS_MD_SHA1);
  AssertTrue('MBEDTLS_MD_SHA1 should resolve to a digest info',
    LInfo <> nil);
  if LInfo = nil then
    Exit;

  LInput := 'abc';
  SetLength(LDigest, Integer(mbedtls_md_get_size(LInfo)));
  AssertTrue('MBEDTLS_MD_SHA1 should publish a 20-byte digest size',
    Length(LDigest) = 20,
    Format('expected SHA1 digest size 20 but got %d', [Length(LDigest)]));

  if mbedtls_md(LInfo, @LInput[1], Length(LInput), @LDigest[0]) <> 0 then
  begin
    AssertTrue('mbedtls_md SHA1 digest call should succeed', False);
    Exit;
  end;

  AssertTrue('MBEDTLS_MD_SHA1 should produce the canonical SHA1 digest for "abc"',
    BytesToHex(LDigest) = EXPECTED_SHA1_ABC,
    'the digest output drifted from canonical SHA1 truth');
end;

procedure TestGetConnectionInfoTruth;
var
  LContext: ISSLContext;
  LOriginalSSLGetVersion: Tmbedtls_ssl_get_version;
  LOriginalSSLGetCipherSuite: Tmbedtls_ssl_get_ciphersuite;
  LOriginalSSLGetCipherSuiteIdFromSSL: Tmbedtls_ssl_get_ciphersuite_id_from_ssl;
  LOriginalSSLGetCipherSuiteId: Tmbedtls_ssl_get_ciphersuite_id;
  LOriginalSSLCipherSuiteFromId: Tmbedtls_ssl_ciphersuite_from_id;
  LOriginalSSLCipherSuiteGetCipherKeyBitLen: Tmbedtls_ssl_ciphersuite_get_cipher_key_bitlen;
  LOriginalSSLGetPeerCert: Tmbedtls_ssl_get_peer_cert;
  LOriginalSSLGetALPNProtocol: Tmbedtls_ssl_get_alpn_protocol;
begin
  WriteLn;
  WriteLn('=== MbedTLS connection info ciphersuite truth ===');

  if (not Assigned(mbedtls_ssl_init)) or
     (not Assigned(mbedtls_ssl_setup)) or
     (not Assigned(mbedtls_ssl_set_bio)) then
  begin
    MarkSkip('mbedtls connection info ciphersuite truth',
      'required baseline MbedTLS SSL helpers are unavailable');
    Exit;
  end;

  LContext := TSSLFactory.CreateContext(sslCtxClient, sslMbedTLS);
  if LContext = nil then
    raise Exception.Create('failed to create MbedTLS client context');

  WarmupSocketConnectionConstructor(LContext);

  LOriginalSSLGetVersion := mbedtls_ssl_get_version;
  LOriginalSSLGetCipherSuite := mbedtls_ssl_get_ciphersuite;
  LOriginalSSLGetCipherSuiteIdFromSSL := mbedtls_ssl_get_ciphersuite_id_from_ssl;
  LOriginalSSLGetCipherSuiteId := mbedtls_ssl_get_ciphersuite_id;
  LOriginalSSLCipherSuiteFromId := mbedtls_ssl_ciphersuite_from_id;
  LOriginalSSLCipherSuiteGetCipherKeyBitLen := mbedtls_ssl_ciphersuite_get_cipher_key_bitlen;
  LOriginalSSLGetPeerCert := mbedtls_ssl_get_peer_cert;
  LOriginalSSLGetALPNProtocol := mbedtls_ssl_get_alpn_protocol;
  try
    mbedtls_ssl_get_peer_cert := nil;
    mbedtls_ssl_get_alpn_protocol := nil;

    mbedtls_ssl_get_version := @StubMbedTLSSSLGetVersionTLS12;
    mbedtls_ssl_get_ciphersuite := @StubMbedTLSSSLGetCipherSuiteLegacySha256;
    mbedtls_ssl_get_ciphersuite_id_from_ssl := nil;
    mbedtls_ssl_get_ciphersuite_id := nil;
    mbedtls_ssl_ciphersuite_from_id := nil;
    mbedtls_ssl_ciphersuite_get_cipher_key_bitlen := nil;
    AssertConnectionInfoTruth(
      'GetConnectionInfo should degrade safely when MbedTLS ciphersuite helpers are unavailable',
      LContext,
      0,
      128,
      0
    );

    FillChar(GStubCipherSuiteInfo, SizeOf(GStubCipherSuiteInfo), 0);
    GStubCipherSuiteId := $C027;
    GStubCipherSuiteInfo.id := GStubCipherSuiteId;
    GStubCipherSuiteInfo.name := PAnsiChar(GLegacySha256CipherName);
    GStubCipherSuiteInfo.mac := MBEDTLS_MD_SHA256;
    GStubCipherKeyBits := 128;
    mbedtls_ssl_get_version := @StubMbedTLSSSLGetVersionTLS12;
    mbedtls_ssl_get_ciphersuite := @StubMbedTLSSSLGetCipherSuiteLegacySha256;
    mbedtls_ssl_get_ciphersuite_id_from_ssl := @StubMbedTLSSSLGetCipherSuiteIdFromSSL;
    mbedtls_ssl_get_ciphersuite_id := nil;
    mbedtls_ssl_ciphersuite_from_id := @StubMbedTLSSSLCipherSuiteFromId;
    mbedtls_ssl_ciphersuite_get_cipher_key_bitlen := @StubMbedTLSSSLCipherSuiteGetCipherKeyBitLen;
    AssertConnectionInfoTruth(
      'GetConnectionInfo should derive legacy non-AEAD truth from direct MbedTLS ciphersuite helpers',
      LContext,
      $C027,
      128,
      32
    );

    FillChar(GStubCipherSuiteInfo, SizeOf(GStubCipherSuiteInfo), 0);
    GStubCipherSuiteId := $002F;
    GStubCipherSuiteInfo.id := GStubCipherSuiteId;
    GStubCipherSuiteInfo.name := PAnsiChar(GLegacySha1CipherName);
    GStubCipherSuiteInfo.mac := MBEDTLS_MD_SHA1;
    GStubCipherKeyBits := 128;
    mbedtls_ssl_get_version := @StubMbedTLSSSLGetVersionTLS12;
    mbedtls_ssl_get_ciphersuite := @StubMbedTLSSSLGetCipherSuiteLegacySha1;
    mbedtls_ssl_get_ciphersuite_id_from_ssl := nil;
    mbedtls_ssl_get_ciphersuite_id := @StubMbedTLSSSLGetCipherSuiteId;
    mbedtls_ssl_ciphersuite_from_id := @StubMbedTLSSSLCipherSuiteFromId;
    mbedtls_ssl_ciphersuite_get_cipher_key_bitlen := @StubMbedTLSSSLCipherSuiteGetCipherKeyBitLen;
    AssertConnectionInfoTruth(
      'GetConnectionInfo should fall back to name-based ciphersuite truth when direct ssl helper is unavailable',
      LContext,
      $002F,
      128,
      20
    );

    FillChar(GStubCipherSuiteInfo, SizeOf(GStubCipherSuiteInfo), 0);
    GStubCipherSuiteId := $1301;
    GStubCipherSuiteInfo.id := GStubCipherSuiteId;
    GStubCipherSuiteInfo.name := PAnsiChar(GTLS13CipherName);
    GStubCipherSuiteInfo.mac := MBEDTLS_MD_SHA256;
    GStubCipherKeyBits := 128;
    mbedtls_ssl_get_version := @StubMbedTLSSSLGetVersionTLS13;
    mbedtls_ssl_get_ciphersuite := @StubMbedTLSSSLGetCipherSuiteTLS13;
    mbedtls_ssl_get_ciphersuite_id_from_ssl := @StubMbedTLSSSLGetCipherSuiteIdFromSSL;
    mbedtls_ssl_get_ciphersuite_id := nil;
    mbedtls_ssl_ciphersuite_from_id := @StubMbedTLSSSLCipherSuiteFromId;
    mbedtls_ssl_ciphersuite_get_cipher_key_bitlen := @StubMbedTLSSSLCipherSuiteGetCipherKeyBitLen;
    AssertConnectionInfoTruth(
      'GetConnectionInfo should keep shared AEAD MacSize when MbedTLS digest truth differs',
      LContext,
      $1301,
      128,
      16
    );
  finally
    mbedtls_ssl_get_version := LOriginalSSLGetVersion;
    mbedtls_ssl_get_ciphersuite := LOriginalSSLGetCipherSuite;
    mbedtls_ssl_get_ciphersuite_id_from_ssl := LOriginalSSLGetCipherSuiteIdFromSSL;
    mbedtls_ssl_get_ciphersuite_id := LOriginalSSLGetCipherSuiteId;
    mbedtls_ssl_ciphersuite_from_id := LOriginalSSLCipherSuiteFromId;
    mbedtls_ssl_ciphersuite_get_cipher_key_bitlen := LOriginalSSLCipherSuiteGetCipherKeyBitLen;
    mbedtls_ssl_get_peer_cert := LOriginalSSLGetPeerCert;
    mbedtls_ssl_get_alpn_protocol := LOriginalSSLGetALPNProtocol;
  end;
end;

begin
  WriteLn('========================================');
  WriteLn('MbedTLS Connection Info Ciphersuite Contract Test');
  WriteLn('========================================');

  try
    GLib := TSSLFactory.GetLibraryInstance(sslMbedTLS);
    if (not Assigned(GLib)) or (not GLib.Initialize) then
      MarkSkip('mbedtls connection info ciphersuite contract',
        'failed to initialize MbedTLS library');

    if SkippedTests = 0 then
      TestDigestConstantTruth;

    if SkippedTests = 0 then
      TestGetConnectionInfoTruth;

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
      WriteLn('[UNEXPECTED] ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
