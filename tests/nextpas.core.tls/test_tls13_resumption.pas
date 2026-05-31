program test_tls13_resumption;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.clienthello.parser,
  nextpas.core.tls.tls13.parser,
  nextpas.core.tls.tls13.serverhello,
  nextpas.core.tls.tls13.keyschedule,
  nextpas.core.tls.tls13.appschedule;

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

procedure AssertEqualsInt(AExpected, AActual: Int64; const AMessage: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s (expected=%d actual=%d)', [AMessage, AExpected, AActual]));
end;

procedure AssertEqualsWord(AExpected, AActual: Word; const AMessage: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s (expected=0x%.4x actual=0x%.4x)', [AMessage, AExpected, AActual]));
end;

function HexNibble(AChar: Char): Byte;
begin
  case AChar of
    '0'..'9': Result := Ord(AChar) - Ord('0');
    'a'..'f': Result := 10 + Ord(AChar) - Ord('a');
    'A'..'F': Result := 10 + Ord(AChar) - Ord('A');
  else
    Fail('Invalid hex character: ' + AChar);
    Result := 0;
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I, LLen: Integer;
begin
  Result := nil;
  LLen := Length(AHex);
  if (LLen = 0) or ((LLen and 1) <> 0) then
    Fail('Invalid hex string length');

  SetLength(Result, LLen div 2);
  for I := 0 to High(Result) do
    Result[I] := (HexNibble(AHex[2 * I + 1]) shl 4) or HexNibble(AHex[2 * I + 2]);
end;

function BytesEqual(const ALeft, ARight: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(ALeft) <> Length(ARight) then
    Exit(False);

  Result := True;
  for I := 0 to High(ALeft) do
    if ALeft[I] <> ARight[I] then
      Exit(False);
end;

procedure AssertBytesEqual(const AExpected, AActual: TBytes; const AMessage: string);
begin
  if not BytesEqual(AExpected, AActual) then
    Fail(AMessage);
end;

function FindExtensionsStart(const AHandshake: TBytes): Integer;
var
  LOffset: Integer;
  LSessionLen: Integer;
  LCipherLen: Integer;
  LCompressionLen: Integer;
begin
  Result := -1;
  if Length(AHandshake) < 4 + 2 + 32 + 1 then
    Exit;

  LOffset := 4;
  Inc(LOffset, 2);
  Inc(LOffset, 32);

  LSessionLen := AHandshake[LOffset];
  Inc(LOffset);
  Inc(LOffset, LSessionLen);
  if LOffset + 2 > Length(AHandshake) then
    Exit;

  LCipherLen := ReadUInt16(AHandshake, LOffset);
  Inc(LOffset, 2 + LCipherLen);
  if LOffset + 1 > Length(AHandshake) then
    Exit;

  LCompressionLen := AHandshake[LOffset];
  Inc(LOffset, 1 + LCompressionLen);
  if LOffset + 2 > Length(AHandshake) then
    Exit;

  Result := LOffset;
end;

function LastExtensionType(const AHandshake: TBytes): Word;
var
  LOffset: Integer;
  LExtLen: Integer;
  LExtEnd: Integer;
begin
  Result := 0;
  LOffset := FindExtensionsStart(AHandshake);
  if LOffset < 0 then
    Fail('Failed to locate ClientHello extensions');

  LExtLen := ReadUInt16(AHandshake, LOffset);
  Inc(LOffset, 2);
  LExtEnd := LOffset + LExtLen;
  if LExtEnd > Length(AHandshake) then
    Fail('ClientHello extensions length exceeds handshake');

  while LOffset + 4 <= LExtEnd do
  begin
    Result := ReadUInt16(AHandshake, LOffset);
    Inc(LOffset, 4);
    Inc(LOffset, ReadUInt16(AHandshake, LOffset - 2));
  end;

  if LOffset <> LExtEnd then
    Fail('ClientHello extensions have trailing bytes');
end;

function AppendClientHelloExtension(
  const AHandshake: TBytes;
  AExtensionType: Word;
  const AExtensionData: TBytes
): TBytes;
var
  LExtensionsOffset: Integer;
  LExtensionsLen: Integer;
  LBodyLen: Integer;
begin
  Result := Copy(AHandshake);
  LExtensionsOffset := FindExtensionsStart(Result);
  if LExtensionsOffset < 0 then
    Fail('Failed to locate ClientHello extensions for append');

  LExtensionsLen := ReadUInt16(Result, LExtensionsOffset);
  Insert(Byte(AExtensionType shr 8), Result, LExtensionsOffset + 2 + LExtensionsLen);
  Insert(Byte(AExtensionType and $FF), Result, LExtensionsOffset + 3 + LExtensionsLen);
  Insert(Byte(Length(AExtensionData) shr 8), Result, LExtensionsOffset + 4 + LExtensionsLen);
  Insert(Byte(Length(AExtensionData) and $FF), Result, LExtensionsOffset + 5 + LExtensionsLen);
  if Length(AExtensionData) > 0 then
    Insert(AExtensionData, Result, LExtensionsOffset + 6 + LExtensionsLen);

  Inc(LExtensionsLen, 4 + Length(AExtensionData));
  Result[LExtensionsOffset] := Byte((LExtensionsLen shr 8) and $FF);
  Result[LExtensionsOffset + 1] := Byte(LExtensionsLen and $FF);

  LBodyLen := Length(Result) - 4;
  Result[1] := Byte((LBodyLen shr 16) and $FF);
  Result[2] := Byte((LBodyLen shr 8) and $FF);
  Result[3] := Byte(LBodyLen and $FF);
end;

procedure TestPskClientHelloAndBinderSHA384;
var
  LOffer: TTLS13ClientHelloPSKOffer;
  LMasterSecret: TBytes;
  LFullHandshakeTranscript: TBytes;
  LTicketNonce: TBytes;
  LPsk: TBytes;
  LKeyShare: TBytes;
  LPartialHandshake: TBytes;
  LHandshake: TBytes;
  LBinder: TBytes;
  LInfo: TTLS13ClientHelloInfo;
  LError: string;
begin
  LMasterSecret := HexToBytes(
    '00112233445566778899AABBCCDDEEFF' +
    '102132435465768798A9BACBDCEDFE0F' +
    '112233445566778899AABBCCDDEEFF00'
  );
  LFullHandshakeTranscript := HexToBytes(
    '8899AABBCCDDEEFF0011223344556677' +
    'FEDCBA98765432100123456789ABCDEF' +
    '0102030405060708090A0B0C0D0E0F10'
  );
  LTicketNonce := [$01, $02, $03, $04];

  LPsk := TLS13DeriveResumptionPSK(
    TLS13_CIPHER_AES_256_GCM_SHA384,
    LMasterSecret,
    LFullHandshakeTranscript,
    LTicketNonce
  );
  AssertEqualsInt(48, Length(LPsk), 'SHA384 resumption PSK length mismatch');

  FillChar(LOffer, SizeOf(LOffer), 0);
  LOffer.Valid := True;
  LOffer.Identity := [$AA, $BB, $CC, $DD];
  LOffer.ObfuscatedTicketAge := $11223344;
  SetLength(LOffer.Binder, 48);
  FillChar(LOffer.Binder[0], Length(LOffer.Binder), 0);

  SetLength(LKeyShare, 32);
  FillChar(LKeyShare[0], Length(LKeyShare), $22);

  LHandshake := BuildTLS13ClientHelloHandshakeWithPSK(
    'example.com',
    'h2',
    LKeyShare,
    LOffer,
    LPartialHandshake
  );
  AssertTrue(Length(LPartialHandshake) > 0, 'Partial ClientHello for binder should not be empty');

  LBinder := TLS13ComputePSKBinderForCipherSuite(
    TLS13_CIPHER_AES_256_GCM_SHA384,
    LPsk,
    LPartialHandshake
  );
  AssertEqualsInt(48, Length(LBinder), 'SHA384 binder length mismatch');

  LOffer.Binder := LBinder;
  LHandshake := BuildTLS13ClientHelloHandshakeWithPSK(
    'example.com',
    'h2',
    LKeyShare,
    LOffer,
    LPartialHandshake
  );

  AssertTrue(TryParseTLS13ClientHelloFromHandshake(LHandshake, LInfo, LError),
    'PSK ClientHello should parse: ' + LError);
  AssertTrue(LInfo.HasPreSharedKey, 'PSK ClientHello should advertise pre_shared_key');
  AssertEqualsInt(1, LInfo.PSKIdentityCount, 'PSK identity count mismatch');
  AssertBytesEqual(LOffer.Identity, LInfo.FirstPSKIdentity, 'PSK identity bytes mismatch');
  AssertEqualsInt(LOffer.ObfuscatedTicketAge, LInfo.FirstPSKObfuscatedTicketAge,
    'Obfuscated ticket age mismatch');
  AssertBytesEqual(LBinder, LInfo.FirstPSKBinder, 'Parsed binder mismatch');
  AssertEqualsWord(TLS_EXTENSION_PRE_SHARED_KEY, LastExtensionType(LHandshake),
    'pre_shared_key must be the last ClientHello extension');
end;

procedure TestRebuildPskBinderTranscriptFromFullClientHello;
var
  LOffer: TTLS13ClientHelloPSKOffer;
  LKeyShare: TBytes;
  LPartialHandshake: TBytes;
  LHandshake: TBytes;
  LRebuiltPartial: TBytes;
  LError: string;
begin
  FillChar(LOffer, SizeOf(LOffer), 0);
  LOffer.Valid := True;
  LOffer.Identity := [$10, $11, $12, $13, $14];
  LOffer.ObfuscatedTicketAge := $55667788;
  LOffer.Binder := HexToBytes(
    '00112233445566778899AABBCCDDEEFF' +
    '102132435465768798A9BACBDCEDFE0F'
  );

  SetLength(LKeyShare, 32);
  FillChar(LKeyShare[0], Length(LKeyShare), $44);

  LHandshake := BuildTLS13ClientHelloHandshakeWithPSK(
    'example.com',
    'h2',
    LKeyShare,
    LOffer,
    LPartialHandshake
  );

  AssertTrue(TryBuildTLS13ClientHelloPSKBinderTranscript(LHandshake, LRebuiltPartial, LError),
    'Parser should rebuild PSK binder transcript from full ClientHello: ' + LError);
  AssertBytesEqual(LPartialHandshake, LRebuiltPartial,
    'Rebuilt binder transcript should match builder partial ClientHello');
end;

procedure TestPskClientHelloWithEarlyDataExtension;
var
  LOffer: TTLS13ClientHelloPSKOffer;
  LKeyShare: TBytes;
  LPartialHandshake: TBytes;
  LHandshake: TBytes;
  LInfo: TTLS13ClientHelloInfo;
  LError: string;
begin
  FillChar(LOffer, SizeOf(LOffer), 0);
  LOffer.Valid := True;
  LOffer.AllowEarlyData := True;
  LOffer.Identity := [$A0, $A1, $A2, $A3];
  LOffer.ObfuscatedTicketAge := $01020304;
  LOffer.Binder := HexToBytes(
    '00112233445566778899AABBCCDDEEFF' +
    '102132435465768798A9BACBDCEDFE0F'
  );

  SetLength(LKeyShare, 32);
  FillChar(LKeyShare[0], Length(LKeyShare), $33);

  LHandshake := BuildTLS13ClientHelloHandshakeWithPSK(
    'early.example.com',
    'h2',
    LKeyShare,
    LOffer,
    LPartialHandshake
  );

  AssertTrue(TryParseTLS13ClientHelloFromHandshake(LHandshake, LInfo, LError),
    'PSK ClientHello with early_data should parse: ' + LError);
  AssertTrue(LInfo.HasPreSharedKey, 'PSK ClientHello should still advertise pre_shared_key');
  AssertTrue(LInfo.HasEarlyData, 'PSK ClientHello should advertise early_data when requested');
  AssertEqualsWord(TLS_EXTENSION_PRE_SHARED_KEY, LastExtensionType(LHandshake),
    'pre_shared_key must remain the last ClientHello extension when early_data is present');
end;

procedure TestRejectClientHelloWithTrailingExtensionAfterPSK;
var
  LOffer: TTLS13ClientHelloPSKOffer;
  LKeyShare: TBytes;
  LPartialHandshake: TBytes;
  LHandshake: TBytes;
  LTamperedHandshake: TBytes;
  LInfo: TTLS13ClientHelloInfo;
  LError: string;
begin
  FillChar(LOffer, SizeOf(LOffer), 0);
  LOffer.Valid := True;
  LOffer.Identity := [$21, $22, $23, $24];
  LOffer.ObfuscatedTicketAge := $09080706;
  LOffer.Binder := HexToBytes(
    '00112233445566778899AABBCCDDEEFF' +
    '102132435465768798A9BACBDCEDFE0F'
  );

  SetLength(LKeyShare, 32);
  FillChar(LKeyShare[0], Length(LKeyShare), $51);

  LHandshake := BuildTLS13ClientHelloHandshakeWithPSK(
    'order.example.com',
    'h2',
    LKeyShare,
    LOffer,
    LPartialHandshake
  );

  LTamperedHandshake := AppendClientHelloExtension(LHandshake, $F0F0, [$00]);

  AssertTrue(not TryParseTLS13ClientHelloFromHandshake(LTamperedHandshake, LInfo, LError),
    'ClientHello with trailing extension after pre_shared_key must be rejected');
  AssertTrue(Pos('pre_shared_key', LowerCase(LError)) > 0,
    'Parser error should mention pre_shared_key ordering');

  AssertTrue(not TryBuildTLS13ClientHelloPSKBinderTranscript(LTamperedHandshake, LPartialHandshake, LError),
    'Binder transcript helper must reject trailing extension after pre_shared_key');
  AssertTrue(Pos('pre_shared_key', LowerCase(LError)) > 0,
    'Binder transcript error should mention pre_shared_key ordering');
end;

procedure TestRejectClientHelloWithEarlyDataButNoPSK;
var
  LKeyShare: TBytes;
  LHandshake: TBytes;
  LTamperedHandshake: TBytes;
  LInfo: TTLS13ClientHelloInfo;
  LError: string;
begin
  SetLength(LKeyShare, 32);
  FillChar(LKeyShare[0], Length(LKeyShare), $61);

  LHandshake := BuildTLS13ClientHelloHandshake(
    'early-without-psk.example.com',
    'h2',
    LKeyShare
  );
  LTamperedHandshake := AppendClientHelloExtension(LHandshake, TLS_EXTENSION_EARLY_DATA, []);

  AssertTrue(not TryParseTLS13ClientHelloFromHandshake(LTamperedHandshake, LInfo, LError),
    'ClientHello with early_data but without pre_shared_key must be rejected');
  AssertTrue((Pos('early_data', LowerCase(LError)) > 0) and (Pos('pre_shared_key', LowerCase(LError)) > 0),
    'Parser error should mention early_data/pre_shared_key coupling');
end;

procedure TestRejectClientHelloWithEmptyPreSharedKeyVectors;
var
  LKeyShare: TBytes;
  LHandshake: TBytes;
  LTamperedHandshake: TBytes;
  LInfo: TTLS13ClientHelloInfo;
  LPartialHandshake: TBytes;
  LError: string;
begin
  SetLength(LKeyShare, 32);
  FillChar(LKeyShare[0], Length(LKeyShare), $71);

  LHandshake := BuildTLS13ClientHelloHandshake(
    'empty-psk.example.com',
    'h2',
    LKeyShare
  );
  LTamperedHandshake := AppendClientHelloExtension(LHandshake, TLS_EXTENSION_PRE_SHARED_KEY,
    [$00, $00, $00, $00]);

  AssertTrue(not TryParseTLS13ClientHelloFromHandshake(LTamperedHandshake, LInfo, LError),
    'ClientHello with empty pre_shared_key vectors must be rejected');
  AssertTrue(Pos('pre_shared_key', LowerCase(LError)) > 0,
    'Parser error should mention pre_shared_key emptiness');

  AssertTrue(not TryBuildTLS13ClientHelloPSKBinderTranscript(LTamperedHandshake, LPartialHandshake, LError),
    'Binder transcript helper must reject empty pre_shared_key vectors');
  AssertTrue(Pos('pre_shared_key', LowerCase(LError)) > 0,
    'Binder transcript helper should mention pre_shared_key emptiness');
end;

procedure TestParseServerHelloSelectedPSK;
var
  LServerHello: TBytes;
  LServerKeyShare: TBytes;
  LInfo: TTLS13ServerHelloInfo;
begin
  SetLength(LServerKeyShare, 32);
  FillChar(LServerKeyShare[0], Length(LServerKeyShare), $55);

  LServerHello := BuildTLS13ServerHelloHandshakeWithSelectedPSK(
    [$10, $20, $30, $40],
    TLS13_CIPHER_CHACHA20_POLY1305_SHA256,
    LServerKeyShare,
    0
  );

  AssertTrue(TryParseServerHelloFromHandshake(LServerHello, LInfo),
    'ServerHello with selected_identity should parse');
  AssertTrue(LInfo.Valid, 'ServerHello should be marked valid');
  AssertTrue(LInfo.HasPreSharedKey, 'ServerHello should expose pre_shared_key selection');
  AssertEqualsWord(0, LInfo.SelectedPSKIdentity, 'selected_identity mismatch');
end;

begin
  WriteLn('Testing TLS 1.3 session resumption primitives...');

  TestPskClientHelloAndBinderSHA384;
  TestRebuildPskBinderTranscriptFromFullClientHello;
  TestParseServerHelloSelectedPSK;
  TestPskClientHelloWithEarlyDataExtension;
  TestRejectClientHelloWithTrailingExtensionAfterPSK;
  TestRejectClientHelloWithEarlyDataButNoPSK;
  TestRejectClientHelloWithEmptyPreSharedKeyVectors;

  WriteLn('✅ TLS 1.3 session resumption primitive checks passed');
end.
