program test_id;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.id,
  nextpas.core.id.base,
  nextpas.core.id.uuid,
  nextpas.core.id.ulid,
  nextpas.core.id.rng,
  nextpas.core.id.v7.monotonic,
  nextpas.core.id.snowflake,
  nextpas.core.id.ksuid,
  nextpas.core.id.xid;

var
  T: TTestRunner;

{ UUID tests }

procedure TestUuidLength;
var
  LId: TUuidString;
begin
  LId := UuidV4;
  CheckEqual(Int64(UUID_LENGTH), Int64(Length(LId)));
end;

procedure TestUuidFormat;
var
  LId: TUuidString;
begin
  LId := UuidV4;
  Check(LId[9] = '-', 'dash at pos 9');
  Check(LId[14] = '-', 'dash at pos 14');
  Check(LId[19] = '-', 'dash at pos 19');
  Check(LId[24] = '-', 'dash at pos 24');
end;

procedure TestUuidVersion;
var
  LId: TUuidString;
begin
  LId := UuidV4;
  Check(LId[15] = '4', 'version nibble must be 4');
end;

procedure TestUuidVariant;
var
  LId: TUuidString;
  LCh: Char;
begin
  LId := UuidV4;
  LCh := LId[20];
  Check((LCh = '8') or (LCh = '9') or (LCh = 'a') or (LCh = 'b'),
    'variant nibble must be 8/9/a/b');
end;

procedure TestUuidUniqueness;
var
  LId1, LId2: TUuidString;
begin
  LId1 := UuidV4;
  LId2 := UuidV4;
  Check(LId1 <> LId2, 'two UUIDs must differ');
end;

{ ULID tests }

procedure TestUlidLength;
var
  LId: TUlidString;
begin
  LId := Ulid;
  CheckEqual(Int64(ULID_LENGTH), Int64(Length(LId)));
end;

procedure TestUlidCrockfordChars;
var
  LId: TUlidString;
  LI: Integer;
  LCh: Char;
  LValid: Boolean;
begin
  LId := Ulid;
  for LI := 1 to Length(LId) do
  begin
    LCh := LId[LI];
    LValid := (LCh >= '0') and (LCh <= '9');
    LValid := LValid or ((LCh >= 'A') and (LCh <= 'Z')
      and (LCh <> 'I') and (LCh <> 'L') and (LCh <> 'O') and (LCh <> 'U'));
    Check(LValid, 'invalid Crockford char: ' + LCh);
  end;
end;

procedure TestUlidTimestampOrdering;
var
  LId1, LId2: TUlidString;
begin
  LId1 := UlidFromTimestamp(1000);
  LId2 := UlidFromTimestamp(2000);
  Check(Copy(LId1, 1, 10) < Copy(LId2, 1, 10),
    'earlier timestamp must sort before later');
end;

procedure TestUlidFromKnownTimestamp;
var
  LId: TUlidString;
  LTimePart: string;
begin
  LId := UlidFromTimestamp(0);
  LTimePart := Copy(LId, 1, 10);
  CheckEqual('0000000000', LTimePart);
end;

procedure TestUlidUniqueness;
var
  LId1, LId2: TUlidString;
begin
  LId1 := Ulid;
  LId2 := Ulid;
  Check(LId1 <> LId2, 'two ULIDs must differ');
end;

{ NanoID tests }

procedure TestNanoIdDefaultLength;
var
  LId: TNanoIdString;
begin
  LId := NanoId;
  CheckEqual(Int64(NANOID_DEFAULT_LENGTH), Int64(Length(LId)));
end;

procedure TestNanoIdCustomLength;
var
  LId: TNanoIdString;
begin
  LId := NanoIdCustom(NANOID_DEFAULT_ALPHABET, 10);
  CheckEqual(Int64(10), Int64(Length(LId)));
  LId := NanoIdCustom(NANOID_DEFAULT_ALPHABET, 50);
  CheckEqual(Int64(50), Int64(Length(LId)));
end;

procedure TestNanoIdCustomAlphabet;
var
  LId: TNanoIdString;
  LI: Integer;
begin
  LId := NanoIdCustom('abc', 100);
  CheckEqual(Int64(100), Int64(Length(LId)));
  for LI := 1 to Length(LId) do
    Check((LId[LI] = 'a') or (LId[LI] = 'b') or (LId[LI] = 'c'),
      'char must be from alphabet');
end;

procedure TestNanoIdUrlSafe;
var
  LId: TNanoIdString;
  LI: Integer;
  LCh: Char;
  LValid: Boolean;
begin
  LId := NanoId;
  for LI := 1 to Length(LId) do
  begin
    LCh := LId[LI];
    LValid := (LCh >= 'a') and (LCh <= 'z');
    LValid := LValid or ((LCh >= 'A') and (LCh <= 'Z'));
    LValid := LValid or ((LCh >= '0') and (LCh <= '9'));
    LValid := LValid or (LCh = '_') or (LCh = '-');
    Check(LValid, 'NanoID char must be URL-safe: ' + LCh);
  end;
end;

procedure TestNanoIdUniqueness;
var
  LId1, LId2: TNanoIdString;
begin
  LId1 := NanoId;
  LId2 := NanoId;
  Check(LId1 <> LId2, 'two NanoIDs must differ');
end;

{ UUID v7 tests }

procedure TestUuidV7Length;
var LId: string;
begin
  LId := UuidV7;
  CheckEqual(Int64(UUID_LENGTH), Int64(Length(LId)));
end;

procedure TestUuidV7Version;
var LId: string;
begin
  LId := UuidV7;
  Check(LId[15] = '7', 'version nibble must be 7');
end;

procedure TestUuidV7Variant;
var LId: string; LCh: Char;
begin
  LId := UuidV7;
  LCh := LId[20];
  Check((LCh = '8') or (LCh = '9') or (LCh = 'a') or (LCh = 'b'), 'variant');
end;

procedure TestUuidV7Ordering;
var LU1, LU2: TUuid;
begin
  LU1 := TUuid.NewV7At(1000);
  LU2 := TUuid.NewV7At(2000);
  Check(LU1 < LU2, 'v7 earlier ts must sort before later');
end;

procedure TestUuidV7Timestamp;
var LU: TUuid; LMs: UInt64;
begin
  LU := TUuid.NewV7;
  LMs := LU.TimestampMs;
  Check(LMs > 1700000000000, 'after 2023');
  Check(LMs < 2100000000000, 'before 2036');
end;

{ TUuid record tests }

procedure TestUuidRecordV4;
var LU: TUuid;
begin
  LU := TUuid.NewV4;
  CheckEqual(Int64(4), Int64(LU.Version));
  CheckEqual(Int64(2), Int64(LU.Variant));
end;

procedure TestUuidRecordNil;
var LU: TUuid;
begin
  LU := TUuid.Nil_;
  Check(LU.IsNil, 'Nil_ must be nil');
end;

procedure TestUuidRecordEquals;
var LA, LB: TUuid;
begin
  LA := TUuid.NewV4;
  LB := LA;
  Check(LA.Equals(LB), 'copy must equal');
  LB := TUuid.NewV4;
  Check(not LA.Equals(LB), 'different must not equal');
end;

procedure TestUuidRecordCompare;
var LA, LB: TUuid;
begin
  LA := TUuid.Nil_;
  LB := TUuid.NewV4;
  Check(LA.CompareTo(LB) < 0, 'nil < random');
  Check(LA.CompareTo(LA) = 0, 'self = self');
end;

procedure TestUuidParseValid;
var LU: TUuid;
begin
  LU := TUuid.Parse('550e8400-e29b-41d4-a716-446655440000');
  Check(not LU.IsNil, 'parsed not nil');
  CheckEqual('550e8400-e29b-41d4-a716-446655440000', LU.ToString);
end;

procedure TestUuidParseNilStr;
var LU: TUuid;
begin
  LU := TUuid.Parse('00000000-0000-0000-0000-000000000000');
  Check(LU.IsNil, 'parsed nil');
end;

procedure TestUuidParseCaseInsensitive;
var LU1, LU2: TUuid;
begin
  LU1 := TUuid.Parse('550E8400-E29B-41D4-A716-446655440000');
  LU2 := TUuid.Parse('550e8400-e29b-41d4-a716-446655440000');
  Check(LU1.Equals(LU2), 'case insensitive');
end;

procedure TestUuidParseInvalid;
begin
  Check(not UuidIsValid('not-a-uuid'), 'invalid');
  Check(not UuidIsValid('550e8400-e29b-41d4-a716'), 'too short');
  Check(not UuidIsValid(''), 'empty');
end;

procedure TestUuidRoundTrip;
var LU1, LU2: TUuid;
begin
  LU1 := TUuid.NewV4;
  LU2 := TUuid.Parse(LU1.ToString);
  Check(LU1.Equals(LU2), 'roundtrip');
end;

{ V7 Monotonic tests }

procedure TestV7MonotonicOrdering;
var LA, LB: TUuid;
begin
  LA := GlobalV7Gen.Next;
  LB := GlobalV7Gen.Next;
  Check(LA < LB, 'monotonic must be strictly ordered');
end;

procedure TestV7MonotonicVersion;
var LU: TUuid;
begin
  LU := UuidV7MonotonicRaw;
  CheckEqual(Int64(7), Int64(LU.Version));
  CheckEqual(Int64(2), Int64(LU.Variant));
end;

procedure TestV7MonotonicBurst;
var
  LPrev, LCur: TUuid;
  LI: Integer;
begin
  LPrev := GlobalV7Gen.Next;
  for LI := 1 to 100 do
  begin
    LCur := GlobalV7Gen.Next;
    Check(LPrev < LCur, 'burst must be monotonic at ' + IntToStr(LI));
    LPrev := LCur;
  end;
end;

{ Snowflake tests }

procedure TestSnowflakePositive;
var LGen: TSnowflakeGenerator; LId: TSnowflakeId;
begin
  LGen.Init(1);
  LId := LGen.Next;
  Check(LId > 0, 'snowflake must be positive');
end;

procedure TestSnowflakeOrdering;
var LGen: TSnowflakeGenerator; LA, LB: TSnowflakeId;
begin
  LGen.Init(1);
  LA := LGen.Next;
  LB := LGen.Next;
  Check(LA < LB, 'snowflake must be ordered');
end;

procedure TestSnowflakeExtract;
var
  LGen: TSnowflakeGenerator;
  LId: TSnowflakeId;
  LTs: Int64;
  LWorker, LSeq: UInt16;
begin
  LGen.Init(42, SNOWFLAKE_EPOCH_TWITTER);
  LId := LGen.Next;
  Check(TSnowflakeGenerator.Extract(LId, SNOWFLAKE_EPOCH_TWITTER, LTs, LWorker, LSeq), 'extract ok');
  CheckEqual(Int64(42), Int64(LWorker));
  Check(LTs > SNOWFLAKE_EPOCH_TWITTER, 'timestamp after epoch');
end;

procedure TestSnowflakeBurst;
var
  LGen: TSnowflakeGenerator;
  LPrev, LCur: TSnowflakeId;
  LI: Integer;
begin
  LGen.Init(7);
  LPrev := LGen.Next;
  for LI := 1 to 1000 do
  begin
    LCur := LGen.Next;
    Check(LCur > LPrev, 'burst must be ordered at ' + IntToStr(LI));
    LPrev := LCur;
  end;
end;

{ KSUID tests }

procedure TestKsuidLength;
begin
  CheckEqual(Int64(KSUID_STRING_LENGTH), Int64(Length(KsuidNew)));
end;

procedure TestKsuidTimestamp;
var LK: TKsuid;
begin
  LK := TKsuid.New;
  Check(LK.TimestampUnix > 1700000000, 'after 2023');
end;

procedure TestKsuidOrdering;
var LA, LB: TKsuid;
begin
  LA := TKsuid.NewAt(100);
  LB := TKsuid.NewAt(200);
  Check(LA < LB, 'earlier must sort before later');
end;

procedure TestKsuidRoundTrip;
var LK: TKsuid; LS: string;
begin
  LK := TKsuid.New;
  LS := LK.ToString;
  Check(TKsuid.Parse(LS) = LK, 'roundtrip');
end;

procedure TestKsuidUniqueness;
var LA, LB: string;
begin
  LA := KsuidNew;
  LB := KsuidNew;
  Check(LA <> LB, 'must differ');
end;

{ XID tests }

procedure TestXidLength;
begin
  CheckEqual(Int64(XID_STRING_LENGTH), Int64(Length(XidNew)));
end;

procedure TestXidTimestamp;
var LX: TXid;
begin
  LX := TXid.New;
  Check(LX.Timestamp > 1700000000, 'after 2023');
end;

procedure TestXidOrdering;
var LA, LB: TXid;
begin
  LA := TXid.New;
  LB := TXid.New;
  Check(LA < LB, 'sequential must be ordered');
end;

procedure TestXidUniqueness;
var LA, LB: string;
begin
  LA := XidNew;
  LB := XidNew;
  Check(LA <> LB, 'must differ');
end;

{ Boundary tests (L5) }

procedure TestUlidValidation;
begin
  Check(UlidIsValid(Ulid), 'valid ULID');
  Check(not UlidIsValid(''), 'empty invalid');
  Check(not UlidIsValid('short'), 'short invalid');
  Check(not UlidIsValid('01ARZ3NDEKTSV4RRFFQ69G5FAI'), 'I invalid in Crockford');
end;

procedure TestUlidTimestamp;
var LMs: UInt64;
begin
  LMs := UlidTimestampMs(UlidFromTimestamp(12345678));
  CheckEqual(Int64(12345678), Int64(LMs));
end;

procedure TestUlidOverflow;
var LS: string;
begin
  LS := UlidFromTimestamp(UInt64($FFFFFFFFFFFFFF));
  CheckEqual(Int64(0), Int64(Length(LS)));
end;

procedure TestKsuidParseInvalid;
var LK: TKsuid;
begin
  LK := TKsuid.Parse('invalid');
  Check(LK.IsNil, 'invalid parse returns nil');
  Check(not TKsuid.TryParse('', LK), 'empty fails');
end;

procedure TestXidRoundTrip;
var LX: TXid; LS: string;
begin
  LX := TXid.New;
  LS := LX.ToString;
  Check(TXid.Parse(LS) = LX, 'xid roundtrip');
end;

procedure TestNanoIdBoundary;
var LS: string;
begin
  LS := NanoIdCustom('abc', 0);
  CheckEqual(Int64(0), Int64(Length(LS)));
  LS := NanoIdCustom('', 10);
  CheckEqual(Int64(0), Int64(Length(LS)));
  LS := NanoIdCustom(StringOfChar('x', 300), 5);
  CheckEqual(Int64(0), Int64(Length(LS)));
end;

procedure TestUuidNoDash;
var LU: TUuid; LS: string;
begin
  LU := TUuid.NewV4;
  LS := LU.ToStringNoDash;
  CheckEqual(Int64(32), Int64(Length(LS)));
  Check(Pos('-', LS) = 0, 'no dashes');
end;

procedure TestUuidHash;
var LA, LB: TUuid;
begin
  LA := TUuid.NewV4;
  LB := LA;
  CheckEqual(Int64(LA.Hash), Int64(LB.Hash));
  LB := TUuid.NewV4;
  Check(LA.Hash <> LB.Hash, 'different UUIDs should have different hashes (probabilistic)');
end;

procedure TestXidNil;
var LX: TXid;
begin
  LX := TXid.Nil_;
  Check(LX.IsNil, 'Nil_ must be nil');
end;

procedure TestXidParseInvalid;
begin
  Check(TXid.Parse('').IsNil, 'empty');
  Check(TXid.Parse('too-short').IsNil, 'short');
  Check(TXid.Parse('ZZZZZZZZZZZZZZZZZZZZ').IsNil, 'invalid chars');
end;

procedure TestKsuidParseInvalidChars;
var LK: TKsuid;
begin
  Check(not TKsuid.TryParse('!!!!!!!!!!!!!!!!!!!!!!!!!!!', LK), 'invalid base62');
end;

{ Stress + boundary tests }

procedure TestUuidV4Stress;
var LI: Integer; LU: TUuid;
begin
  for LI := 1 to 10000 do
  begin
    LU := TUuid.NewV4;
    if LU.Version <> 4 then begin Check(False, 'v4 version at ' + IntToStr(LI)); Exit; end;
    if LU.Variant <> 2 then begin Check(False, 'v4 variant at ' + IntToStr(LI)); Exit; end;
  end;
  Check(True, '10000 v4 all valid');
end;

procedure TestSnowflakeStress;
var LGen: TSnowflakeGenerator; LPrev, LCur: TSnowflakeId; LI: Integer;
begin
  LGen.Init(1);
  LPrev := LGen.Next;
  for LI := 1 to 10000 do
  begin
    LCur := LGen.Next;
    if LCur <= LPrev then begin Check(False, 'ordering at ' + IntToStr(LI)); Exit; end;
    LPrev := LCur;
  end;
  Check(True, '10000 snowflakes ordered');
end;

procedure TestXidStress;
var LPrev, LCur: TXid; LI: Integer;
begin
  LPrev := TXid.New;
  for LI := 1 to 10000 do
  begin
    LCur := TXid.New;
    if not (LPrev < LCur) then begin Check(False, 'xid order at ' + IntToStr(LI)); Exit; end;
    LPrev := LCur;
  end;
  Check(True, '10000 XIDs ordered');
end;

procedure TestKsuidRoundTripStress;
var LI: Integer; LK: TKsuid; LS: string;
begin
  for LI := 1 to 1000 do
  begin
    LK := TKsuid.New;
    LS := LK.ToString;
    if not (TKsuid.Parse(LS) = LK) then begin Check(False, 'ksuid rt at ' + IntToStr(LI)); Exit; end;
  end;
  Check(True, '1000 KSUID roundtrips');
end;

procedure TestUuidParseAllZeros;
var LU: TUuid;
begin
  LU := TUuid.Parse('00000000-0000-0000-0000-000000000000');
  Check(LU.IsNil, 'all zeros is nil');
  CheckEqual(Int64(0), Int64(LU.Version));
  CheckEqual(Int64(0), Int64(LU.TimestampMs));
end;

procedure TestUuidParseAllF;
var LU: TUuid;
begin
  LU := TUuid.Parse('ffffffff-ffff-ffff-ffff-ffffffffffff');
  Check(not LU.IsNil, 'all-F not nil');
  CheckEqual(Int64(15), Int64(LU.Version));
end;

{ === Defect-hunting tests === }

procedure TestUuidUniqueness1000;
var
  LArr: array[0..999] of string;
  LI, LJ: Integer;
begin
  for LI := 0 to 999 do
    LArr[LI] := UuidV4;
  for LI := 0 to 998 do
    for LJ := LI + 1 to 999 do
      if LArr[LI] = LArr[LJ] then
      begin
        Check(False, 'collision at ' + IntToStr(LI) + ',' + IntToStr(LJ));
        Exit;
      end;
  Check(True, '1000 UUIDs unique');
end;

procedure TestKsuidBoundaryAllZero;
var LK: TKsuid; LS: string;
begin
  FillChar(LK.FBytes, 20, 0);
  LS := LK.ToString;
  CheckEqual(Int64(27), Int64(Length(LS)));
  Check(TKsuid.Parse(LS) = LK, 'all-zero roundtrip');
end;

procedure TestKsuidBoundaryAllFF;
var LK: TKsuid; LS: string;
begin
  FillChar(LK.FBytes, 20, $FF);
  LS := LK.ToString;
  CheckEqual(Int64(27), Int64(Length(LS)));
  Check(TKsuid.Parse(LS) = LK, 'all-FF roundtrip');
end;

procedure TestUlidMaxTimestamp;
var LS: string; LMs: UInt64;
begin
  LS := UlidFromTimestamp(UInt64($FFFFFFFFFFFF));
  Check(Length(LS) = ULID_LENGTH, 'max ts produces valid ULID');
  LMs := UlidTimestampMs(LS);
  CheckEqual(Int64($FFFFFFFFFFFF), Int64(LMs));
end;

procedure TestUlidLowercaseRoundTrip;
var LS, LLower: string; LI: Integer; LMs1, LMs2: UInt64;
begin
  LS := Ulid;
  SetLength(LLower, Length(LS));
  for LI := 1 to Length(LS) do
    if (LS[LI] >= 'A') and (LS[LI] <= 'Z') then
      LLower[LI] := Chr(Ord(LS[LI]) + 32)
    else
      LLower[LI] := LS[LI];
  Check(UlidIsValid(LLower), 'lowercase valid');
  LMs1 := UlidTimestampMs(LS);
  LMs2 := UlidTimestampMs(LLower);
  CheckEqual(Int64(LMs1), Int64(LMs2));
end;

procedure TestXidHighCharParse;
var LX: TXid;
begin
  Check(not TXid.TryParse(StringOfChar(#128, 20), LX), 'high-byte chars rejected');
  Check(not TXid.TryParse(StringOfChar(#255, 20), LX), 'FF chars rejected');
end;

procedure TestSnowflakeExtractRoundTrip;
var
  LGen: TSnowflakeGenerator;
  LId: TSnowflakeId;
  LTs: Int64;
  LW, LS: UInt16;
  LI: Integer;
begin
  LGen.Init(999, SNOWFLAKE_EPOCH_DISCORD);
  for LI := 1 to 100 do
  begin
    LId := LGen.Next;
    TSnowflakeGenerator.Extract(LId, SNOWFLAKE_EPOCH_DISCORD, LTs, LW, LS);
    if LW <> 999 then begin Check(False, 'worker mismatch at ' + IntToStr(LI)); Exit; end;
    if LTs <= SNOWFLAKE_EPOCH_DISCORD then begin Check(False, 'ts too low at ' + IntToStr(LI)); Exit; end;
  end;
  Check(True, '100 extract roundtrips');
end;

procedure TestRngReseedSafety;
begin
  IdRngReseed;
  Check(Length(UuidV4) = UUID_LENGTH, 'generation works after reseed');
  Check(Length(KsuidNew) = KSUID_STRING_LENGTH, 'ksuid works after reseed');
  Check(Length(XidNew) = XID_STRING_LENGTH, 'xid works after reseed');
end;

begin
  Randomize;
  T := TTestRunner.Create('nextpas.core.id');

  T.Run('UUID length', @TestUuidLength);
  T.Run('UUID format (dashes)', @TestUuidFormat);
  T.Run('UUID version 4', @TestUuidVersion);
  T.Run('UUID variant', @TestUuidVariant);
  T.Run('UUID uniqueness', @TestUuidUniqueness);

  T.Run('UUID v7 length', @TestUuidV7Length);
  T.Run('UUID v7 version', @TestUuidV7Version);
  T.Run('UUID v7 variant', @TestUuidV7Variant);
  T.Run('UUID v7 ordering', @TestUuidV7Ordering);
  T.Run('UUID v7 timestamp', @TestUuidV7Timestamp);
  T.Run('TUuid record v4', @TestUuidRecordV4);
  T.Run('TUuid Nil', @TestUuidRecordNil);
  T.Run('TUuid Equals', @TestUuidRecordEquals);
  T.Run('TUuid CompareTo', @TestUuidRecordCompare);
  T.Run('UUID parse valid', @TestUuidParseValid);
  T.Run('UUID parse nil', @TestUuidParseNilStr);
  T.Run('UUID parse case', @TestUuidParseCaseInsensitive);
  T.Run('UUID parse invalid', @TestUuidParseInvalid);
  T.Run('UUID roundtrip', @TestUuidRoundTrip);

  T.Run('ULID length', @TestUlidLength);
  T.Run('ULID Crockford chars', @TestUlidCrockfordChars);
  T.Run('ULID timestamp ordering', @TestUlidTimestampOrdering);
  T.Run('ULID from known timestamp', @TestUlidFromKnownTimestamp);
  T.Run('ULID uniqueness', @TestUlidUniqueness);

  T.Run('NanoID default length', @TestNanoIdDefaultLength);
  T.Run('NanoID custom length', @TestNanoIdCustomLength);
  T.Run('NanoID custom alphabet', @TestNanoIdCustomAlphabet);
  T.Run('NanoID URL-safe chars', @TestNanoIdUrlSafe);
  T.Run('NanoID uniqueness', @TestNanoIdUniqueness);

  T.Run('V7 monotonic ordering', @TestV7MonotonicOrdering);
  T.Run('V7 monotonic version', @TestV7MonotonicVersion);
  T.Run('V7 monotonic burst', @TestV7MonotonicBurst);

  T.Run('Snowflake positive', @TestSnowflakePositive);
  T.Run('Snowflake ordering', @TestSnowflakeOrdering);
  T.Run('Snowflake extract', @TestSnowflakeExtract);
  T.Run('Snowflake burst', @TestSnowflakeBurst);

  T.Run('KSUID length', @TestKsuidLength);
  T.Run('KSUID timestamp', @TestKsuidTimestamp);
  T.Run('KSUID ordering', @TestKsuidOrdering);
  T.Run('KSUID roundtrip', @TestKsuidRoundTrip);
  T.Run('KSUID uniqueness', @TestKsuidUniqueness);

  T.Run('XID length', @TestXidLength);
  T.Run('XID timestamp', @TestXidTimestamp);
  T.Run('XID ordering', @TestXidOrdering);
  T.Run('XID uniqueness', @TestXidUniqueness);

  T.Run('ULID validation', @TestUlidValidation);
  T.Run('ULID timestamp extract', @TestUlidTimestamp);
  T.Run('ULID overflow', @TestUlidOverflow);
  T.Run('KSUID parse invalid', @TestKsuidParseInvalid);
  T.Run('XID roundtrip', @TestXidRoundTrip);
  T.Run('NanoID boundary', @TestNanoIdBoundary);
  T.Run('UUID NoDash', @TestUuidNoDash);
  T.Run('UUID Hash', @TestUuidHash);
  T.Run('XID Nil', @TestXidNil);
  T.Run('XID parse invalid', @TestXidParseInvalid);
  T.Run('KSUID parse invalid chars', @TestKsuidParseInvalidChars);

  T.Run('UUID v4 stress 10k', @TestUuidV4Stress);
  T.Run('Snowflake stress 10k', @TestSnowflakeStress);
  T.Run('XID stress 10k', @TestXidStress);
  T.Run('KSUID roundtrip stress 1k', @TestKsuidRoundTripStress);
  T.Run('UUID parse all-zeros', @TestUuidParseAllZeros);
  T.Run('UUID parse all-F', @TestUuidParseAllF);

  T.Run('UUID uniqueness 1000', @TestUuidUniqueness1000);
  T.Run('KSUID boundary all-zero', @TestKsuidBoundaryAllZero);
  T.Run('KSUID boundary all-FF', @TestKsuidBoundaryAllFF);
  T.Run('ULID max timestamp', @TestUlidMaxTimestamp);
  T.Run('ULID lowercase roundtrip', @TestUlidLowercaseRoundTrip);
  T.Run('XID high-char parse', @TestXidHighCharParse);
  T.Run('Snowflake extract roundtrip', @TestSnowflakeExtractRoundTrip);
  T.Run('RNG reseed safety', @TestRngReseedSafety);

  T.Summary;
end.
