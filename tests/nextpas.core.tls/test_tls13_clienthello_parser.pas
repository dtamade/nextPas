program test_tls13_clienthello_parser;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.clienthello.parser;

procedure Fail(const AMessage: string);
begin
  WriteLn('❌ ', AMessage);
  Halt(1);
end;

procedure AssertTrue(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    Fail(AMessage);
end;

procedure AssertEqualsWord(AExpected, AActual: Word; const AMessage: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s (expected=0x%.4x actual=0x%.4x)', [AMessage, AExpected, AActual]));
end;

function BuildExtensionHeader(AType: Word; const AData: TBytes): TBytes;
begin
  Result := nil;
  AppendUInt16(Result, AType);
  AppendUInt16(Result, Word(Length(AData)));
  AppendBytes(Result, AData);
end;

function BuildClientHelloWithTwoKeyShares: TBytes;
var
  LBody: TBytes;
  LCipherSuites: TBytes;
  LCompressionMethods: TBytes;
  LExtensions: TBytes;
  LExtData: TBytes;
  LEntry: TBytes;
  LSecpShare: TBytes;
  LX25519Share: TBytes;
  I: Integer;
begin
  Result := nil;
  SetLength(LBody, 0);
  AppendUInt16(LBody, TLS_LEGACY_VERSION);

  SetLength(LX25519Share, 32);
  for I := 0 to 31 do
    LX25519Share[I] := Byte(I + 1);

  SetLength(LSecpShare, 33);
  LSecpShare[0] := $04;
  for I := 1 to 32 do
    LSecpShare[I] := Byte($80 + I);

  AppendBytes(LBody, LX25519Share); // random[32]
  AppendByte(LBody, 0); // session id len

  SetLength(LCipherSuites, 0);
  AppendUInt16(LCipherSuites, TLS13_CIPHER_CHACHA20_POLY1305_SHA256);
  AppendUInt16(LBody, Word(Length(LCipherSuites)));
  AppendBytes(LBody, LCipherSuites);

  SetLength(LCompressionMethods, 0);
  AppendByte(LCompressionMethods, 1);
  AppendByte(LCompressionMethods, 0);
  AppendBytes(LBody, LCompressionMethods);

  SetLength(LExtensions, 0);

  SetLength(LExtData, 0);
  AppendByte(LExtData, 2);
  AppendUInt16(LExtData, TLS13_VERSION);
  AppendBytes(LExtensions, BuildExtensionHeader(TLS_EXTENSION_SUPPORTED_VERSIONS, LExtData));

  SetLength(LExtData, 0);
  SetLength(LEntry, 0);
  AppendUInt16(LEntry, TLS13_GROUP_SECP256R1);
  AppendUInt16(LEntry, Word(Length(LSecpShare)));
  AppendBytes(LEntry, LSecpShare);
  AppendBytes(LExtData, LEntry);

  SetLength(LEntry, 0);
  AppendUInt16(LEntry, TLS13_GROUP_X25519);
  AppendUInt16(LEntry, Word(Length(LX25519Share)));
  AppendBytes(LEntry, LX25519Share);
  AppendBytes(LExtData, LEntry);

  SetLength(LEntry, 0);
  AppendUInt16(LEntry, Word(Length(LExtData)));
  AppendBytes(LEntry, LExtData);
  AppendBytes(LExtensions, BuildExtensionHeader(TLS_EXTENSION_KEY_SHARE, LEntry));

  AppendUInt16(LBody, Word(Length(LExtensions)));
  AppendBytes(LBody, LExtensions);

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_CLIENT_HELLO);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
end;

function BuildMalformedClientHelloSupportedVersionsOddLength: TBytes;
var
  LBody: TBytes;
  LCipherSuites: TBytes;
  LCompressionMethods: TBytes;
  LExtensions: TBytes;
  LExtData: TBytes;
  LKeyShare: TBytes;
begin
  Result := nil;
  SetLength(LBody, 0);
  AppendUInt16(LBody, TLS_LEGACY_VERSION);

  SetLength(LKeyShare, 32);
  FillChar(LKeyShare[0], 32, $11);
  AppendBytes(LBody, LKeyShare); // random

  AppendByte(LBody, 0); // session id

  SetLength(LCipherSuites, 0);
  AppendUInt16(LCipherSuites, TLS13_CIPHER_CHACHA20_POLY1305_SHA256);
  AppendUInt16(LBody, Word(Length(LCipherSuites)));
  AppendBytes(LBody, LCipherSuites);

  SetLength(LCompressionMethods, 0);
  AppendByte(LCompressionMethods, 1);
  AppendByte(LCompressionMethods, 0);
  AppendBytes(LBody, LCompressionMethods);

  SetLength(LExtensions, 0);

  SetLength(LExtData, 0);
  AppendByte(LExtData, 3);
  AppendByte(LExtData, $03);
  AppendByte(LExtData, $04);
  AppendBytes(LExtensions, BuildExtensionHeader(TLS_EXTENSION_SUPPORTED_VERSIONS, LExtData));

  SetLength(LExtData, 0);
  AppendUInt16(LExtData, 34);
  AppendUInt16(LExtData, TLS13_GROUP_X25519);
  AppendUInt16(LExtData, 32);
  AppendBytes(LExtData, LKeyShare);
  AppendBytes(LExtensions, BuildExtensionHeader(TLS_EXTENSION_KEY_SHARE, LExtData));

  AppendUInt16(LBody, Word(Length(LExtensions)));
  AppendBytes(LBody, LExtensions);

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_CLIENT_HELLO);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
end;

procedure TestParseGeneratedClientHello;
var
  LKeyShare: TBytes;
  LHandshake: TBytes;
  LInfo: TTLS13ClientHelloInfo;
  LError: string;
begin
  SetLength(LKeyShare, 32);
  FillChar(LKeyShare[0], 32, $22);

  LHandshake := BuildTLS13ClientHelloHandshake('example.com', 'h2,http/1.1', LKeyShare);
  AssertTrue(TryParseTLS13ClientHelloFromHandshake(LHandshake, LInfo, LError),
    'Parse generated ClientHello failed: ' + LError);

  AssertTrue(LInfo.Valid, 'ClientHello should be marked valid');
  AssertEqualsWord(TLS_LEGACY_VERSION, LInfo.LegacyVersion, 'legacy_version mismatch');
  AssertTrue(LInfo.HasSupportedVersions, 'supported_versions extension should exist');
  AssertTrue(TLS13ClientHelloSupportsVersion(LInfo, TLS13_VERSION), 'TLS 1.3 should be offered');
  AssertTrue(TLS13ClientHelloOffersCipherSuite(LInfo, TLS13_CIPHER_AES_256_GCM_SHA384),
    'AES256-GCM-SHA384 suite should be offered');
  AssertTrue(TLS13ClientHelloOffersCipherSuite(LInfo, TLS13_CIPHER_CHACHA20_POLY1305_SHA256),
    'CHACHA20 suite should be offered');
  AssertTrue(TLS13ClientHelloOffersCipherSuite(LInfo, TLS13_CIPHER_AES_128_GCM_SHA256),
    'AES128-GCM-SHA256 suite should be offered');

  AssertTrue(LInfo.HasSignatureAlgorithms, 'signature_algorithms extension should exist');
  AssertTrue(TLS13ClientHelloOffersSignatureScheme(LInfo, TLS13_SIG_RSA_PSS_RSAE_SHA256),
    'ClientHello should offer rsa_pss_rsae_sha256');
  AssertTrue(TLS13ClientHelloOffersSignatureScheme(LInfo, TLS13_SIG_RSA_PSS_RSAE_SHA384),
    'ClientHello should offer rsa_pss_rsae_sha384');
  AssertTrue(TLS13ClientHelloOffersSignatureScheme(LInfo, TLS13_SIG_ECDSA_SECP256R1_SHA256),
    'ClientHello should offer ecdsa_secp256r1_sha256');
  AssertTrue(TLS13ClientHelloOffersSignatureScheme(LInfo, TLS13_SIG_RSA_PKCS1_SHA384),
    'ClientHello should offer rsa_pkcs1_sha384');
  AssertTrue(TLS13ClientHelloOffersSignatureScheme(LInfo, TLS13_SIG_RSA_PSS_PSS_SHA384),
    'ClientHello should offer rsa_pss_pss_sha384');
  AssertTrue(LInfo.HasKeyShare, 'key_share should be parsed');
  AssertEqualsWord(TLS13_GROUP_X25519, LInfo.KeyShareGroup, 'key_share group mismatch');
  AssertEqualsWord(32, LInfo.KeyShareLength, 'key_share length mismatch');
  AssertTrue((Length(LInfo.PeerKeyShare) = 32) and (LInfo.PeerKeyShare[0] = $22),
    'key_share bytes mismatch');
end;

procedure TestSelectX25519FromMultipleKeyShares;
var
  LHandshake: TBytes;
  LInfo: TTLS13ClientHelloInfo;
  LError: string;
begin
  LHandshake := BuildClientHelloWithTwoKeyShares;
  AssertTrue(TryParseTLS13ClientHelloFromHandshake(LHandshake, LInfo, LError),
    'Parse multi-key-share ClientHello failed: ' + LError);

  AssertTrue(LInfo.HasKeyShare, 'key_share should exist');
  AssertEqualsWord(TLS13_GROUP_X25519, LInfo.KeyShareGroup, 'Parser should prefer X25519 key_share');
  AssertEqualsWord(32, LInfo.KeyShareLength, 'Preferred X25519 share length should be 32');
  AssertTrue((Length(LInfo.PeerKeyShare) = 32) and (LInfo.PeerKeyShare[0] = 1) and (LInfo.PeerKeyShare[31] = 32),
    'Preferred X25519 share bytes mismatch');
end;

procedure TestRejectMalformedSupportedVersions;
var
  LHandshake: TBytes;
  LInfo: TTLS13ClientHelloInfo;
  LError: string;
begin
  LHandshake := BuildMalformedClientHelloSupportedVersionsOddLength;
  AssertTrue(not TryParseTLS13ClientHelloFromHandshake(LHandshake, LInfo, LError),
    'Malformed supported_versions ClientHello should fail');
  AssertTrue(Pos('supported_versions', LowerCase(LError)) > 0,
    'Expected supported_versions related error, got: ' + LError);
end;

begin
  WriteLn('Testing TLS 1.3 ClientHello parser...');

  TestParseGeneratedClientHello;
  TestSelectX25519FromMultipleKeyShares;
  TestRejectMalformedSupportedVersions;

  WriteLn('✅ TLS 1.3 ClientHello parser checks passed');
end.
