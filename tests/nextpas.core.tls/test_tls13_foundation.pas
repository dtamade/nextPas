program test_tls13_foundation;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.parser;

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
    Fail(Format('%s (expected=0x%.4x, actual=0x%.4x)', [AMessage, AExpected, AActual]));
end;

function BuildExtensionHeader(AType: Word; const AData: TBytes): TBytes;
begin
  Result := nil;
  SetLength(Result, 0);
  AppendUInt16(Result, AType);
  AppendUInt16(Result, Word(Length(AData)));
  AppendBytes(Result, AData);
end;

function BuildSyntheticServerHelloHandshake: TBytes;
var
  LBody: TBytes;
  LExtensions: TBytes;
  LExtensionData: TBytes;
  LDummyKey: TBytes;
  I: Integer;
begin
  Result := nil;
  SetLength(LBody, 0);

  AppendUInt16(LBody, TLS_LEGACY_VERSION);

  SetLength(LDummyKey, 32);
  for I := 0 to High(LDummyKey) do
    LDummyKey[I] := Byte(I);
  AppendBytes(LBody, LDummyKey); // random[32]

  AppendByte(LBody, 0); // legacy_session_id_echo len
  AppendUInt16(LBody, TLS13_CIPHER_AES_128_GCM_SHA256);
  AppendByte(LBody, 0); // legacy_compression_method

  SetLength(LExtensions, 0);

  SetLength(LExtensionData, 0);
  AppendUInt16(LExtensionData, TLS13_VERSION);
  AppendBytes(LExtensions, BuildExtensionHeader(TLS_EXTENSION_SUPPORTED_VERSIONS, LExtensionData));

  SetLength(LExtensionData, 0);
  AppendUInt16(LExtensionData, TLS13_GROUP_X25519);
  AppendUInt16(LExtensionData, Word(Length(LDummyKey)));
  AppendBytes(LExtensionData, LDummyKey);
  AppendBytes(LExtensions, BuildExtensionHeader(TLS_EXTENSION_KEY_SHARE, LExtensionData));

  AppendUInt16(LBody, Word(Length(LExtensions)));
  AppendBytes(LBody, LExtensions);

  SetLength(Result, 0);
  AppendByte(Result, TLS_HANDSHAKE_TYPE_SERVER_HELLO);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
end;

procedure TestBuildClientHelloRecord;
var
  LKeyShare: TBytes;
  LRecord: TBytes;
  LHeader: TTLSRecordHeader;
  LHandshake: TBytes;
  LOffset: Integer;
  LSessionLen: Integer;
  LCipherLen: Word;
  LCipherSuite1: Word;
  LCipherSuite2: Word;
  LCipherSuite3: Word;
begin
  LKeyShare := nil;
  SetLength(LKeyShare, 32);
  FillChar(LKeyShare[0], 32, $11);

  LRecord := BuildTLS13ClientHelloRecord('example.com', 'h2,http/1.1', LKeyShare);
  AssertTrue(Length(LRecord) > 9, 'ClientHello record should not be empty');
  AssertTrue(ParseTLSRecordHeader(LRecord, LHeader), 'ClientHello header parse failed');
  AssertEqualsWord(TLS_LEGACY_VERSION, LHeader.LegacyVersion, 'Record legacy version mismatch');
  AssertTrue(LHeader.ContentType = TLS_CONTENT_TYPE_HANDSHAKE, 'Record content type should be handshake');

  AssertTrue(TryExtractHandshakePayloadFromRecord(LRecord, LHandshake), 'Extract handshake from ClientHello failed');
  AssertTrue((Length(LHandshake) >= 4) and (LHandshake[0] = TLS_HANDSHAKE_TYPE_CLIENT_HELLO),
    'Handshake payload should start with ClientHello');

  LOffset := 4; // handshake header
  Inc(LOffset, 2); // legacy_version
  Inc(LOffset, 32); // random

  LSessionLen := LHandshake[LOffset];
  Inc(LOffset);
  Inc(LOffset, LSessionLen);

  LCipherLen := ReadUInt16(LHandshake, LOffset);
  Inc(LOffset, 2);
  AssertEqualsWord(6, LCipherLen, 'ClientHello cipher_suites length should be 6 bytes (three suites)');

  LCipherSuite1 := ReadUInt16(LHandshake, LOffset);
  LCipherSuite2 := ReadUInt16(LHandshake, LOffset + 2);
  LCipherSuite3 := ReadUInt16(LHandshake, LOffset + 4);
  AssertEqualsWord(
    TLS13_CIPHER_AES_256_GCM_SHA384,
    LCipherSuite1,
    'ClientHello should offer AES256-GCM-SHA384 first in pure FreePascal path'
  );
  AssertEqualsWord(
    TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
    LCipherSuite2,
    'ClientHello should offer CHACHA20-POLY1305 second in pure FreePascal path'
  );
  AssertEqualsWord(
    TLS13_CIPHER_AES_128_GCM_SHA256,
    LCipherSuite3,
    'ClientHello should offer AES128-GCM-SHA256 third in pure FreePascal path'
  );
end;

procedure TestParseSyntheticServerHello;
var
  LHandshake: TBytes;
  LRecord: TBytes;
  LRecordPayload: TBytes;
  LInfo: TTLS13ServerHelloInfo;
begin
  LHandshake := BuildSyntheticServerHelloHandshake;
  LRecord := BuildTLSPlaintext(TLS_CONTENT_TYPE_HANDSHAKE, LHandshake);

  AssertTrue(TryExtractHandshakePayloadFromRecord(LRecord, LRecordPayload),
    'Extract handshake from synthetic ServerHello failed');
  AssertTrue(TryParseServerHelloFromHandshake(LRecordPayload, LInfo),
    'Synthetic ServerHello parse failed');

  AssertTrue(LInfo.Valid, 'ServerHello parsed but marked invalid');
  AssertEqualsWord(TLS13_VERSION, LInfo.SelectedVersion, 'Selected TLS version mismatch');
  AssertEqualsWord(TLS13_CIPHER_AES_128_GCM_SHA256, LInfo.SelectedCipherSuite, 'Selected cipher mismatch');
  AssertTrue(LInfo.HasKeyShare, 'KeyShare should be detected');
  AssertEqualsWord(TLS13_GROUP_X25519, LInfo.KeyShareGroup, 'KeyShare group mismatch');
  AssertEqualsWord(32, LInfo.KeyShareLength, 'KeyShare length mismatch');
  AssertTrue(Length(LInfo.PeerKeyShare) = 32, 'Peer key_share bytes should be extracted');
  AssertTrue((LInfo.PeerKeyShare[0] = 0) and (LInfo.PeerKeyShare[31] = 31),
    'Peer key_share content mismatch');
end;

begin
  WriteLn('Testing TLS 1.3 foundation units...');

  TestBuildClientHelloRecord;
  TestParseSyntheticServerHello;

  WriteLn('✅ TLS 1.3 foundation checks passed');
end.
