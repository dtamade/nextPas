program test_tls13_serverhello_builder;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.parser,
  nextpas.core.tls.tls13.serverhello;

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

procedure TestBuildServerHelloHandshakeAndParse;
var
  LSessionID: TBytes;
  LKeyShare: TBytes;
  LHandshake: TBytes;
  LInfo: TTLS13ServerHelloInfo;
  I: Integer;
begin
  SetLength(LSessionID, 32);
  for I := 0 to 31 do
    LSessionID[I] := Byte($A0 + I);

  SetLength(LKeyShare, 32);
  for I := 0 to 31 do
    LKeyShare[I] := Byte(I);

  LHandshake := BuildTLS13ServerHelloHandshake(
    LSessionID,
    TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
    LKeyShare,
    TLS13_GROUP_X25519
  );

  AssertTrue(Length(LHandshake) > 40, 'ServerHello handshake should not be empty');
  AssertTrue(TryParseServerHelloFromHandshake(LHandshake, LInfo), 'Generated ServerHello should parse');

  AssertTrue(LInfo.Valid, 'Parsed ServerHello should be valid');
  AssertEqualsWord(TLS13_VERSION, LInfo.SelectedVersion, 'Selected TLS version mismatch');
  AssertEqualsWord(TLS13_CIPHER_CHACHA20_POLY1305_SHA256, LInfo.SelectedCipherSuite, 'Selected cipher mismatch');
  AssertTrue(LInfo.HasKeyShare, 'key_share should exist');
  AssertEqualsWord(TLS13_GROUP_X25519, LInfo.KeyShareGroup, 'key_share group mismatch');
  AssertEqualsWord(32, LInfo.KeyShareLength, 'key_share length mismatch');
  AssertTrue((Length(LInfo.PeerKeyShare) = 32) and (LInfo.PeerKeyShare[0] = 0) and (LInfo.PeerKeyShare[31] = 31),
    'key_share bytes mismatch');
end;

procedure TestBuildServerHelloRecord;
var
  LSessionID: TBytes;
  LKeyShare: TBytes;
  LRecord: TBytes;
  LHeader: TTLSRecordHeader;
  LHandshake: TBytes;
begin
  SetLength(LSessionID, 0);
  SetLength(LKeyShare, 32);
  FillChar(LKeyShare[0], 32, $77);

  LRecord := BuildTLS13ServerHelloRecord(
    LSessionID,
    TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
    LKeyShare,
    TLS13_GROUP_X25519
  );

  AssertTrue(ParseTLSRecordHeader(LRecord, LHeader), 'Record header parse failed');
  AssertEqualsWord(TLS_LEGACY_VERSION, LHeader.LegacyVersion, 'Record legacy version mismatch');
  AssertTrue(LHeader.ContentType = TLS_CONTENT_TYPE_HANDSHAKE, 'Record type should be handshake');

  AssertTrue(TryExtractHandshakePayloadFromRecord(LRecord, LHandshake),
    'Extract handshake from ServerHello record failed');
  AssertTrue((Length(LHandshake) >= 4) and (LHandshake[0] = TLS_HANDSHAKE_TYPE_SERVER_HELLO),
    'Record payload should be ServerHello');
end;

procedure TestRejectTooLongSessionID;
var
  LSessionID: TBytes;
  LKeyShare: TBytes;
  LRaised: Boolean;
begin
  SetLength(LSessionID, 33);
  FillChar(LSessionID[0], 33, $10);

  SetLength(LKeyShare, 32);
  FillChar(LKeyShare[0], 32, $11);

  LRaised := False;
  try
    BuildTLS13ServerHelloHandshake(
      LSessionID,
      TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
      LKeyShare,
      TLS13_GROUP_X25519
    );
  except
    on E: Exception do
      LRaised := True;
  end;

  AssertTrue(LRaised, 'Session ID length > 32 should be rejected');
end;

begin
  WriteLn('Testing TLS 1.3 ServerHello builder...');

  TestBuildServerHelloHandshakeAndParse;
  TestBuildServerHelloRecord;
  TestRejectTooLongSessionID;

  WriteLn('✅ TLS 1.3 ServerHello builder checks passed');
end.
