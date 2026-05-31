program test_tls13_posthandshake;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.tls.tls13.wire,
  nextpas.core.tls.tls13.posthandshake;

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

procedure AssertEqualInt(AExpected, AActual: Int64; const AMessage: string);
begin
  if AExpected <> AActual then
    Fail(Format('%s (expected=%d actual=%d)', [AMessage, AExpected, AActual]));
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

function BuildSampleNewSessionTicket: TBytes;
var
  LBody: TBytes;
begin
  SetLength(LBody, 0);

  AppendByte(LBody, $00);
  AppendByte(LBody, $00);
  AppendByte(LBody, $0E);
  AppendByte(LBody, $10);

  AppendByte(LBody, $11);
  AppendByte(LBody, $22);
  AppendByte(LBody, $33);
  AppendByte(LBody, $44);

  AppendByte(LBody, 3);
  AppendByte(LBody, $01);
  AppendByte(LBody, $02);
  AppendByte(LBody, $03);

  AppendUInt16(LBody, 4);
  AppendByte(LBody, $AA);
  AppendByte(LBody, $BB);
  AppendByte(LBody, $CC);
  AppendByte(LBody, $DD);

  AppendUInt16(LBody, 4);
  AppendUInt16(LBody, $002A);
  AppendUInt16(LBody, 0);

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_NEW_SESSION_TICKET);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
end;

procedure TestParseValidTicket;
var
  LMsg: TBytes;
  LTicket: TTLS13NewSessionTicket;
  LErr: string;
  LExpectedNonce: TBytes;
  LExpectedTicket: TBytes;
  LExpectedExt: TBytes;
begin
  LMsg := BuildSampleNewSessionTicket;

  AssertTrue(
    TryParseTLS13NewSessionTicket(LMsg, LTicket, LErr),
    'Valid NewSessionTicket should parse'
  );

  AssertTrue(LTicket.Valid, 'Parsed ticket should be marked valid');
  AssertEqualInt($00000E10, LTicket.TicketLifetime, 'Ticket lifetime mismatch');
  AssertEqualInt($11223344, LTicket.TicketAgeAdd, 'Ticket age_add mismatch');

  LExpectedNonce := [$01, $02, $03];
  LExpectedTicket := [$AA, $BB, $CC, $DD];
  LExpectedExt := [$00, $2A, $00, $00];

  AssertBytesEqual(LExpectedNonce, LTicket.TicketNonce, 'Ticket nonce mismatch');
  AssertBytesEqual(LExpectedTicket, LTicket.Ticket, 'Ticket blob mismatch');
  AssertBytesEqual(LExpectedExt, LTicket.Extensions, 'Ticket extensions mismatch');
end;

procedure TestParseTicketWithMaxEarlyDataSize;
var
  LMsg: TBytes;
  LTicket: TTLS13NewSessionTicket;
  LErr: string;
  LExtensions: TBytes;
begin
  SetLength(LExtensions, 0);
  AppendUInt16(LExtensions, TLS_EXTENSION_EARLY_DATA);
  AppendUInt16(LExtensions, 4);
  AppendByte(LExtensions, $00);
  AppendByte(LExtensions, $00);
  AppendByte(LExtensions, $40);
  AppendByte(LExtensions, $00);

  LMsg := BuildTLS13NewSessionTicketHandshake(
    7200,
    $01020304,
    [$10, $11, $12],
    [$AA, $BB, $CC, $DD],
    LExtensions
  );

  AssertTrue(
    TryParseTLS13NewSessionTicket(LMsg, LTicket, LErr),
    'NewSessionTicket with max_early_data_size should parse'
  );
  AssertTrue(LTicket.HasMaxEarlyDataSize,
    'Ticket should expose parsed max_early_data_size');
  AssertEqualInt($00004000, LTicket.MaxEarlyDataSize,
    'max_early_data_size mismatch');
end;

procedure TestRejectWrongType;
var
  LMsg: TBytes;
  LTicket: TTLS13NewSessionTicket;
  LErr: string;
begin
  LMsg := BuildSampleNewSessionTicket;
  LMsg[0] := TLS_HANDSHAKE_TYPE_FINISHED;

  AssertTrue(
    not TryParseTLS13NewSessionTicket(LMsg, LTicket, LErr),
    'Wrong handshake type must fail parsing'
  );
  AssertTrue(Pos('unexpected handshake type', LowerCase(LErr)) > 0, 'Expected wrong-type error');
end;

procedure TestRejectZeroTicketLen;
var
  LMsg: TBytes;
  LTicket: TTLS13NewSessionTicket;
  LErr: string;
begin
  LMsg := BuildSampleNewSessionTicket;

  LMsg[16] := 0;
  LMsg[17] := 0;
  LMsg[20] := 0;
  LMsg[21] := 0;
  LMsg[22] := 0;

  AssertTrue(
    not TryParseTLS13NewSessionTicket(LMsg, LTicket, LErr),
    'Zero ticket length must fail parsing'
  );
  AssertTrue(Pos('ticket length must be > 0', LowerCase(LErr)) > 0, 'Expected ticket length error');
end;


function BuildSampleKeyUpdate(ARequestValue: Byte): TBytes;
begin
  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_KEY_UPDATE);
  AppendUInt24(Result, 1);
  AppendByte(Result, ARequestValue);
end;

procedure TestParseValidKeyUpdate;
var
  LMsg: TBytes;
  LInfo: TTLS13KeyUpdateInfo;
  LErr: string;
begin
  LMsg := BuildSampleKeyUpdate(1);
  AssertTrue(TryParseTLS13KeyUpdate(LMsg, LInfo, LErr), 'KeyUpdate(requested) should parse');
  AssertTrue(LInfo.Valid, 'Parsed KeyUpdate should be valid');
  AssertTrue(LInfo.RequestUpdate, 'RequestUpdate flag should be true');

  LMsg := BuildSampleKeyUpdate(0);
  AssertTrue(TryParseTLS13KeyUpdate(LMsg, LInfo, LErr), 'KeyUpdate(not_requested) should parse');
  AssertTrue(not LInfo.RequestUpdate, 'RequestUpdate flag should be false');
end;

procedure TestRejectInvalidKeyUpdate;
var
  LMsg: TBytes;
  LInfo: TTLS13KeyUpdateInfo;
  LErr: string;
begin
  LMsg := BuildSampleKeyUpdate(2);
  AssertTrue(not TryParseTLS13KeyUpdate(LMsg, LInfo, LErr), 'Invalid request value must fail');
  AssertTrue(Pos('invalid keyupdate request value', LowerCase(LErr)) > 0, 'Expected invalid value error');

  LMsg := BuildSampleKeyUpdate(1);
  LMsg[3] := 2;
  AppendByte(LMsg, 0);
  AssertTrue(not TryParseTLS13KeyUpdate(LMsg, LInfo, LErr), 'Invalid body length must fail');
  AssertTrue(Pos('invalid keyupdate body length', LowerCase(LErr)) > 0, 'Expected invalid length error');
end;

procedure TestBuildAndParseEndOfEarlyData;
var
  LMsg: TBytes;
  LInfo: TTLS13EndOfEarlyDataInfo;
  LErr: string;
begin
  LMsg := BuildTLS13EndOfEarlyDataHandshake;
  AssertTrue(TryParseTLS13EndOfEarlyData(LMsg, LInfo, LErr),
    'EndOfEarlyData should parse');
  AssertTrue(LInfo.Valid, 'Parsed EndOfEarlyData should be valid');

  LMsg[0] := TLS_HANDSHAKE_TYPE_FINISHED;
  AssertTrue(not TryParseTLS13EndOfEarlyData(LMsg, LInfo, LErr),
    'Wrong handshake type must fail for EndOfEarlyData');
  AssertTrue(Pos('unexpected handshake type', LowerCase(LErr)) > 0,
    'Expected wrong-type error for EndOfEarlyData');
end;

begin
  WriteLn('Testing TLS 1.3 post-handshake parser...');

  TestParseValidTicket;
  TestParseTicketWithMaxEarlyDataSize;
  TestRejectWrongType;
  TestRejectZeroTicketLen;
  TestParseValidKeyUpdate;
  TestRejectInvalidKeyUpdate;
  TestBuildAndParseEndOfEarlyData;

  WriteLn('✅ TLS 1.3 post-handshake parser checks passed');
end.
