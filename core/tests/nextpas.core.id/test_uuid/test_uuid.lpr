program test_uuid;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.text.conv,
  nextpas.core.id.base,
  nextpas.core.id.uuid;

var
  T: TTestRunner;

{ --- NewV4: generation + format validation --- }

procedure TestV4Format;
var LU: TUuid; LS: string;
begin
  LU := TUuid.NewV4;
  LS := LU.ToString;
  CheckEqual(Int64(UUID_LENGTH), Int64(Length(LS)), 'length=36');
  Check(LS[9] = '-', 'dash at 9');
  Check(LS[14] = '-', 'dash at 14');
  Check(LS[19] = '-', 'dash at 19');
  Check(LS[24] = '-', 'dash at 24');
end;

procedure TestV4Version;
var LU: TUuid;
begin
  LU := TUuid.NewV4;
  CheckEqual(Int64(4), Int64(LU.Version), 'version=4');
end;

procedure TestV4Variant;
var LU: TUuid;
begin
  LU := TUuid.NewV4;
  CheckEqual(Int64(2), Int64(LU.Variant), 'variant=2 (RFC 4122)');
end;

procedure TestV4VersionNibbleInString;
var LS: string;
begin
  LS := TUuid.NewV4.ToString;
  Check(LS[15] = '4', 'version char must be 4');
end;

procedure TestV4VariantNibbleInString;
var LS: string; LCh: Char;
begin
  LS := TUuid.NewV4.ToString;
  LCh := LS[20];
  Check((LCh = '8') or (LCh = '9') or (LCh = 'a') or (LCh = 'b'),
    'variant nibble must be 8/9/a/b, got: ' + LCh);
end;

{ --- NewV7: generation + timestamp extraction --- }

procedure TestV7Format;
var LU: TUuid; LS: string;
begin
  LU := TUuid.NewV7;
  LS := LU.ToString;
  CheckEqual(Int64(UUID_LENGTH), Int64(Length(LS)), 'v7 length=36');
  Check(LS[9] = '-', 'dash at 9');
  Check(LS[14] = '-', 'dash at 14');
  Check(LS[19] = '-', 'dash at 19');
  Check(LS[24] = '-', 'dash at 24');
end;

procedure TestV7Version;
var LU: TUuid;
begin
  LU := TUuid.NewV7;
  CheckEqual(Int64(7), Int64(LU.Version), 'version=7');
end;

procedure TestV7Variant;
var LU: TUuid;
begin
  LU := TUuid.NewV7;
  CheckEqual(Int64(2), Int64(LU.Variant), 'variant=2');
end;

procedure TestV7TimestampExtract;
var LU: TUuid; LMs: UInt64;
begin
  LU := TUuid.NewV7;
  LMs := LU.TimestampMs;
  Check(LMs > 1700000000000, 'timestamp after 2023-11');
  Check(LMs < 2200000000000, 'timestamp before 2039');
end;

procedure TestV7AtKnownTimestamp;
var LU: TUuid; LMs: UInt64;
begin
  LU := TUuid.NewV7At(1717200000000);
  LMs := LU.TimestampMs;
  CheckEqual(Int64(1717200000000), Int64(LMs), 'exact timestamp preserved');
  CheckEqual(Int64(7), Int64(LU.Version), 'version=7');
  CheckEqual(Int64(2), Int64(LU.Variant), 'variant=2');
end;

{ --- Parse / TryParse --- }

procedure TestParseValid;
var LU: TUuid;
begin
  LU := TUuid.Parse('550e8400-e29b-41d4-a716-446655440000');
  Check(not LU.IsNil, 'parsed not nil');
  CheckEqual('550e8400-e29b-41d4-a716-446655440000', LU.ToString);
end;

procedure TestParseCaseInsensitive;
var LA, LB: TUuid;
begin
  LA := TUuid.Parse('550E8400-E29B-41D4-A716-446655440000');
  LB := TUuid.Parse('550e8400-e29b-41d4-a716-446655440000');
  Check(LA = LB, 'case insensitive parse');
end;

procedure TestTryParseValid;
var LU: TUuid; LOk: Boolean;
begin
  LOk := TUuid.TryParse('6ba7b810-9dad-11d1-80b4-00c04fd430c8', LU);
  Check(LOk, 'TryParse returns true');
  CheckEqual('6ba7b810-9dad-11d1-80b4-00c04fd430c8', LU.ToString);
end;

procedure TestTryParseInvalidEmpty;
var LU: TUuid; LOk: Boolean;
begin
  LOk := TUuid.TryParse('', LU);
  Check(not LOk, 'empty string fails');
end;

procedure TestTryParseInvalidShort;
var LU: TUuid; LOk: Boolean;
begin
  LOk := TUuid.TryParse('550e8400-e29b-41d4-a716', LU);
  Check(not LOk, 'too short fails');
end;

procedure TestTryParseInvalidChars;
var LU: TUuid; LOk: Boolean;
begin
  LOk := TUuid.TryParse('550e8400-e29b-41d4-a716-44665544ZZZZ', LU);
  Check(not LOk, 'invalid hex chars fail');
end;

procedure TestTryParseInvalidNoDashes;
var LU: TUuid; LOk: Boolean;
begin
  LOk := TUuid.TryParse('550e8400e29b41d4a716446655440000', LU);
  Check(not LOk, 'no dashes fails (wrong length)');
end;

procedure TestTryParseMisplacedDash;
var LU: TUuid; LOk: Boolean;
begin
  LOk := TUuid.TryParse('550e840-0e29b-41d4-a716-446655440000', LU);
  Check(not LOk, 'misplaced dash fails');
end;


{ --- ToString roundtrip --- }

procedure TestToStringRoundTrip;
var LU1, LU2: TUuid;
begin
  LU1 := TUuid.NewV4;
  LU2 := TUuid.Parse(LU1.ToString);
  Check(LU1 = LU2, 'v4 roundtrip');
end;

procedure TestToStringRoundTripV7;
var LU1, LU2: TUuid;
begin
  LU1 := TUuid.NewV7;
  LU2 := TUuid.Parse(LU1.ToString);
  Check(LU1 = LU2, 'v7 roundtrip');
end;

{ --- Nil UUID --- }

procedure TestNilUuid;
var LU: TUuid;
begin
  LU := TUuid.Nil_;
  Check(LU.IsNil, 'Nil_ is nil');
  CheckEqual('00000000-0000-0000-0000-000000000000', LU.ToString);
end;

procedure TestNilUuidVersion;
var LU: TUuid;
begin
  LU := TUuid.Nil_;
  CheckEqual(Int64(0), Int64(LU.Version), 'nil version=0');
end;

procedure TestNewV4NotNil;
var LU: TUuid;
begin
  LU := TUuid.NewV4;
  Check(not LU.IsNil, 'v4 is never nil');
end;

procedure TestNewV7NotNil;
var LU: TUuid;
begin
  LU := TUuid.NewV7;
  Check(not LU.IsNil, 'v7 is never nil');
end;

{ --- Uniqueness: 1000 non-repeating --- }

procedure TestUniqueness1000V4;
var
  LArr: array[0..999] of string;
  LI, LJ: Integer;
begin
  for LI := 0 to 999 do
    LArr[LI] := TUuid.NewV4.ToString;
  for LI := 0 to 998 do
    for LJ := LI + 1 to 999 do
      if LArr[LI] = LArr[LJ] then
      begin
        Fail('v4 collision at ' + IntToStr(LI) + ',' + IntToStr(LJ));
        Exit;
      end;
end;

procedure TestUniqueness1000V7;
var
  LArr: array[0..999] of string;
  LI, LJ: Integer;
begin
  for LI := 0 to 999 do
    LArr[LI] := TUuid.NewV7.ToString;
  for LI := 0 to 998 do
    for LJ := LI + 1 to 999 do
      if LArr[LI] = LArr[LJ] then
      begin
        Fail('v7 collision at ' + IntToStr(LI) + ',' + IntToStr(LJ));
        Exit;
      end;
end;

{ --- V7 time ordering --- }

procedure TestV7TimeOrdering;
var
  LPrev, LCur: TUuid;
  LI: Integer;
begin
  LPrev := TUuid.NewV7At(1000);
  for LI := 1 to 100 do
  begin
    LCur := TUuid.NewV7At(UInt64(1000 + LI));
    Check(LPrev < LCur, 'v7 must be ordered at step ' + IntToStr(LI));
    LPrev := LCur;
  end;
end;

procedure TestV7ConsecutiveOrdering;
var
  LA, LB: TUuid;
begin
  LA := TUuid.NewV7At(5000);
  LB := TUuid.NewV7At(6000);
  Check(LA < LB, 'earlier timestamp < later timestamp');
end;

{ --- Equal / NotEqual operators --- }

procedure TestEqualOperator;
var LA, LB: TUuid;
begin
  LA := TUuid.Parse('550e8400-e29b-41d4-a716-446655440000');
  LB := TUuid.Parse('550e8400-e29b-41d4-a716-446655440000');
  Check(LA = LB, 'same UUID must be equal');
end;

procedure TestNotEqualOperator;
var LA, LB: TUuid;
begin
  LA := TUuid.NewV4;
  LB := TUuid.NewV4;
  Check(not (LA = LB), 'different UUIDs must not be equal');
end;

procedure TestEqualSelf;
var LU: TUuid;
begin
  LU := TUuid.NewV4;
  Check(LU = LU, 'UUID must equal itself');
end;

{ --- Additional coverage --- }

procedure TestToStringNoDash;
var LU: TUuid; LS: string;
begin
  LU := TUuid.NewV4;
  LS := LU.ToStringNoDash;
  CheckEqual(Int64(32), Int64(Length(LS)), 'no-dash length=32');
  Check(Pos('-', LS) = 0, 'no dashes present');
end;

procedure TestCompareTo;
var LA, LB: TUuid;
begin
  LA := TUuid.Nil_;
  LB := TUuid.NewV4;
  Check(LA.CompareTo(LB) < 0, 'nil < random');
  Check(LA.CompareTo(LA) = 0, 'self = self');
  Check(LB.CompareTo(LA) > 0, 'random > nil');
end;

procedure TestHash;
var LA, LB: TUuid;
begin
  LA := TUuid.NewV4;
  LB := LA;
  CheckEqual(Int64(LA.Hash), Int64(LB.Hash), 'same UUID same hash');
end;

procedure TestV4Stress;
var LI: Integer; LU: TUuid;
begin
  for LI := 1 to 10000 do
  begin
    LU := TUuid.NewV4;
    if LU.Version <> 4 then begin Fail('version at ' + IntToStr(LI)); Exit; end;
    if LU.Variant <> 2 then begin Fail('variant at ' + IntToStr(LI)); Exit; end;
  end;
end;

procedure TestV7Stress;
var LI: Integer; LU: TUuid;
begin
  for LI := 1 to 10000 do
  begin
    LU := TUuid.NewV7;
    if LU.Version <> 7 then begin Fail('version at ' + IntToStr(LI)); Exit; end;
    if LU.Variant <> 2 then begin Fail('variant at ' + IntToStr(LI)); Exit; end;
  end;
end;

procedure TestParseNilString;
var LU: TUuid;
begin
  LU := TUuid.Parse('00000000-0000-0000-0000-000000000000');
  Check(LU.IsNil, 'parsed nil string is nil');
end;

procedure TestUuidIsValidFunc;
begin
  Check(UuidIsValid('550e8400-e29b-41d4-a716-446655440000'), 'valid');
  Check(not UuidIsValid('not-a-uuid'), 'invalid');
  Check(not UuidIsValid(''), 'empty');
end;


begin
  T := TTestRunner.Create('nextpas.core.id.uuid');

  { V4 generation + format }
  T.Run('V4 format (length + dashes)', @TestV4Format);
  T.Run('V4 version byte', @TestV4Version);
  T.Run('V4 variant byte', @TestV4Variant);
  T.Run('V4 version nibble in string', @TestV4VersionNibbleInString);
  T.Run('V4 variant nibble in string', @TestV4VariantNibbleInString);

  { V7 generation + timestamp }
  T.Run('V7 format (length + dashes)', @TestV7Format);
  T.Run('V7 version byte', @TestV7Version);
  T.Run('V7 variant byte', @TestV7Variant);
  T.Run('V7 timestamp extract', @TestV7TimestampExtract);
  T.Run('V7 at known timestamp', @TestV7AtKnownTimestamp);

  { Parse / TryParse }
  T.Run('Parse valid', @TestParseValid);
  T.Run('Parse case insensitive', @TestParseCaseInsensitive);
  T.Run('TryParse valid', @TestTryParseValid);
  T.Run('TryParse invalid empty', @TestTryParseInvalidEmpty);
  T.Run('TryParse invalid short', @TestTryParseInvalidShort);
  T.Run('TryParse invalid chars', @TestTryParseInvalidChars);
  T.Run('TryParse invalid no dashes', @TestTryParseInvalidNoDashes);
  T.Run('TryParse misplaced dash', @TestTryParseMisplacedDash);

  { ToString roundtrip }
  T.Run('ToString roundtrip V4', @TestToStringRoundTrip);
  T.Run('ToString roundtrip V7', @TestToStringRoundTripV7);

  { Nil UUID }
  T.Run('Nil UUID', @TestNilUuid);
  T.Run('Nil UUID version', @TestNilUuidVersion);
  T.Run('NewV4 not nil', @TestNewV4NotNil);
  T.Run('NewV7 not nil', @TestNewV7NotNil);

  { Uniqueness }
  T.Run('Uniqueness 1000 V4', @TestUniqueness1000V4);
  T.Run('Uniqueness 1000 V7', @TestUniqueness1000V7);

  { V7 time ordering }
  T.Run('V7 time ordering (NewV7At)', @TestV7TimeOrdering);
  T.Run('V7 consecutive ordering', @TestV7ConsecutiveOrdering);

  { Equal / NotEqual }
  T.Run('Equal operator', @TestEqualOperator);
  T.Run('NotEqual operator', @TestNotEqualOperator);
  T.Run('Equal self', @TestEqualSelf);

  { Additional coverage }
  T.Run('ToStringNoDash', @TestToStringNoDash);
  T.Run('CompareTo', @TestCompareTo);
  T.Run('Hash consistency', @TestHash);
  T.Run('V4 stress 10k', @TestV4Stress);
  T.Run('V7 stress 10k', @TestV7Stress);
  T.Run('Parse nil string', @TestParseNilString);
  T.Run('UuidIsValid function', @TestUuidIsValidFunc);

  T.Summary;
end.
