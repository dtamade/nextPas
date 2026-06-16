program test_id_killer;
{$I nextpas.core.settings.inc}
{$R+}{$Q+}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.id.uuid,
  nextpas.core.id.v7.monotonic,
  nextpas.core.id.snowflake,
  nextpas.core.id.ksuid,
  nextpas.core.id.xid,
  nextpas.core.id.ulid,
  nextpas.core.id.nanoid,
  nextpas.core.id.rng;

var
  T: TTestRunner;

{ === Range Check Tests — expose integer overflow === }

procedure TestXidParseRangeCheck;
var LX: TXid; LS: string; LI: Integer;
begin
  for LI := 1 to 100 do
  begin
    LS := XidNew;
    if not TXid.TryParse(LS, LX) then
    begin
      Check(False, 'roundtrip fail at ' + IntToStr(LI));
      Exit;
    end;
    if LX.ToString <> LS then
    begin
      Check(False, 'mismatch at ' + IntToStr(LI));
      Exit;
    end;
  end;
  Check(True, '100 XID roundtrips with range checks');
end;

procedure TestKsuidParseRangeCheck;
var LK: TKsuid; LS: string; LI: Integer;
begin
  for LI := 1 to 100 do
  begin
    LK := TKsuid.New;
    LS := LK.ToString;
    if not (TKsuid.Parse(LS) = LK) then
    begin
      Check(False, 'ksuid roundtrip fail at ' + IntToStr(LI));
      Exit;
    end;
  end;
  Check(True, '100 KSUID roundtrips with range checks');
end;

procedure TestUuidParseRangeCheck;
var LU: TUuid; LS: string; LI: Integer;
begin
  for LI := 1 to 100 do
  begin
    LU := TUuid.NewV4;
    LS := LU.ToString;
    if not TUuid.Parse(LS).Equals(LU) then
    begin
      Check(False, 'uuid roundtrip fail at ' + IntToStr(LI));
      Exit;
    end;
  end;
  Check(True, '100 UUID roundtrips with range checks');
end;

{ === Sequence Overflow Tests — force >4096 calls in tight loop === }

procedure TestSnowflakeSequenceOverflow;
var
  LGen: TSnowflakeGenerator;
  LPrev, LCur: TSnowflakeId;
  LI: Integer;
begin
  LGen.Init(1);
  LPrev := LGen.Next;
  for LI := 1 to 5000 do
  begin
    LCur := LGen.Next;
    if LCur <= LPrev then
    begin
      Check(False, 'ordering broken at ' + IntToStr(LI) +
        ' prev=' + IntToStr(LPrev) + ' cur=' + IntToStr(LCur));
      Exit;
    end;
    LPrev := LCur;
  end;
  Check(True, '5000 snowflakes strictly ordered (crosses seq boundary)');
end;

procedure TestV7MonotonicOverflow;
var
  LGen: TUuidV7Generator;
  LPrev, LCur: TUuid;
  LI: Integer;
begin
  LGen.Init;
  LPrev := LGen.Next;
  for LI := 1 to 5000 do
  begin
    LCur := LGen.Next;
    if not (LPrev < LCur) then
    begin
      Check(False, 'v7 monotonic broken at ' + IntToStr(LI));
      Exit;
    end;
    LPrev := LCur;
  end;
  Check(True, '5000 v7 monotonic strictly ordered (may cross randA boundary)');
end;

{ === Boundary Value Tests — extreme inputs === }

procedure TestKsuidAllZeroBytes;
var LK: TKsuid; LS: string;
begin
  FillChar(LK.FBytes, 20, 0);
  LS := LK.ToString;
  CheckEqual(Int64(27), Int64(Length(LS)));
  Check(TKsuid.Parse(LS) = LK, 'all-zero encode/decode');
end;

procedure TestKsuidAllFFBytes;
var LK: TKsuid; LS: string;
begin
  FillChar(LK.FBytes, 20, $FF);
  LS := LK.ToString;
  CheckEqual(Int64(27), Int64(Length(LS)));
  Check(TKsuid.Parse(LS) = LK, 'all-FF encode/decode');
end;

procedure TestKsuidSingleBitPatterns;
var LK: TKsuid; LS: string; LI, LBit: Integer;
begin
  for LI := 0 to 19 do
    for LBit := 0 to 7 do
    begin
      FillChar(LK.FBytes, 20, 0);
      LK.FBytes[LI] := 1 shl LBit;
      LS := LK.ToString;
      if not (TKsuid.Parse(LS) = LK) then
      begin
        Check(False, 'single-bit fail byte=' + IntToStr(LI) + ' bit=' + IntToStr(LBit));
        Exit;
      end;
    end;
  Check(True, '160 single-bit KSUID patterns all roundtrip');
end;

procedure TestXidSingleBitPatterns;
var LX: TXid; LS: string; LI, LBit: Integer;
begin
  for LI := 0 to 11 do
    for LBit := 0 to 7 do
    begin
      FillChar(LX.FBytes, 12, 0);
      LX.FBytes[LI] := 1 shl LBit;
      LS := LX.ToString;
      if not (TXid.Parse(LS) = LX) then
      begin
        Check(False, 'xid single-bit fail byte=' + IntToStr(LI) + ' bit=' + IntToStr(LBit));
        Exit;
      end;
    end;
  Check(True, '96 single-bit XID patterns all roundtrip');
end;

procedure TestUuidSingleBitPatterns;
var LU: TUuid; LS: string; LI, LBit: Integer;
begin
  for LI := 0 to 15 do
    for LBit := 0 to 7 do
    begin
      FillChar(LU.FBytes, 16, 0);
      LU.FBytes[LI] := 1 shl LBit;
      LS := LU.ToString;
      if not TUuid.Parse(LS).Equals(LU) then
      begin
        Check(False, 'uuid single-bit fail byte=' + IntToStr(LI) + ' bit=' + IntToStr(LBit));
        Exit;
      end;
    end;
  Check(True, '128 single-bit UUID patterns all roundtrip');
end;

{ === RNG Runtime Smoke === }

procedure TestRngLargeFill;
var
  LBuf: array[0..1023] of Byte;
begin
  FillChar(LBuf, SizeOf(LBuf), 0);
  IdRngFillBytes(@LBuf[0], 1024);
  Check(True, '1024 byte RNG fill completed');
end;

{ === Resource Management === }

procedure TestRngReseedMultiple;
var LI: Integer; LU: TUuid;
begin
  for LI := 1 to 10 do
  begin
    IdRngReseed;
    LU := TUuid.NewV4;
    if LU.Version <> 4 then
    begin
      Check(False, 'generation failed after reseed ' + IntToStr(LI));
      Exit;
    end;
  end;
  Check(True, '10 reseed cycles all produce valid UUIDs');
end;

begin
  T := TTestRunner.Create('nextpas.core.id.killer');
  T.Run('XID parse range-check', @TestXidParseRangeCheck);
  T.Run('KSUID parse range-check', @TestKsuidParseRangeCheck);
  T.Run('UUID parse range-check', @TestUuidParseRangeCheck);
  T.Run('Snowflake seq overflow 5k', @TestSnowflakeSequenceOverflow);
  T.Run('V7 monotonic overflow 5k', @TestV7MonotonicOverflow);
  T.Run('KSUID all-zero bytes', @TestKsuidAllZeroBytes);
  T.Run('KSUID all-FF bytes', @TestKsuidAllFFBytes);
  T.Run('KSUID single-bit patterns', @TestKsuidSingleBitPatterns);
  T.Run('XID single-bit patterns', @TestXidSingleBitPatterns);
  T.Run('UUID single-bit patterns', @TestUuidSingleBitPatterns);
  T.Run('RNG large fill', @TestRngLargeFill);
  T.Run('RNG reseed multiple', @TestRngReseedMultiple);
  T.Summary;
end.
