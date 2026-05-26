program test_id;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.id,
  nextpas.core.id.base;

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

begin
  Randomize;
  T := TTestRunner.Create('nextpas.core.id');

  T.Run('UUID length', @TestUuidLength);
  T.Run('UUID format (dashes)', @TestUuidFormat);
  T.Run('UUID version 4', @TestUuidVersion);
  T.Run('UUID variant', @TestUuidVariant);
  T.Run('UUID uniqueness', @TestUuidUniqueness);

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

  T.Summary;
end.
