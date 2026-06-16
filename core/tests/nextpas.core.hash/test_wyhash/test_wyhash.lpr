program test_wyhash;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.hash.wyhash;

var
  T: TTestRunner;

procedure CheckHash(const AData: PAnsiChar; ALen: SizeUInt; ASeed: UInt64;
  AExpected: UInt64; const AName: string);
var LGot: UInt64;
begin
  LGot := WyHash(AData, ALen, ASeed);
  if LGot <> AExpected then
  begin
    WriteLn('  FAIL: ', AName, ' — got $', HexStr(LGot, 16), ' expected $', HexStr(AExpected, 16));
    Halt(1);
  end;
end;

procedure TestEmpty;
begin
  CheckHash(nil, 0, 0, UInt64($42BC986DC5EEC4D3), 'empty seed=0');
end;

procedure TestShort;
begin
  CheckHash('a', 1, 0, UInt64($6CF84E5A2465E867), '''a'' seed=0');
  CheckHash('abc', 3, 0, UInt64($B4808DF22D44FFCF), '''abc'' seed=0');
  CheckHash('hello', 5, 0, UInt64($FAACEC54DF7A6205), '''hello'' seed=0');
end;

procedure TestMedium;
begin
  CheckHash('hello world', 11, 0, UInt64($19F24A02FE04C3CA), '''hello world''');
  CheckHash('0123456789abcdef', 16, 0, UInt64($461EBD6F5B59DFA7), '16 bytes');
  CheckHash('0123456789abcdefgh', 18, 0, UInt64($544A776BC78FCD3F), '18 bytes');
  CheckHash('0123456789abcdef0123456789abcdef', 32, 0,
    UInt64($C11B4B9E7A314A11), '32 bytes');
end;

procedure TestLong;
begin
  CheckHash('012345678901234567890123456789012345678901234567', 48, 0,
    UInt64($D047C5859F97FB1B), '48 bytes');
  CheckHash('0123456789012345678901234567890123456789012345678', 49, 0,
    UInt64($22DCD7F50FDCA435), '49 bytes');
  CheckHash('01234567890123456789012345678901234567890123456789', 50, 0,
    UInt64($222A591E60007D73), '50 bytes');
  CheckHash('01234567890123456789012345678901234567890123456789', 50, 42,
    UInt64($176750A3DF14201F), '50 bytes seed=42');
  CheckHash('0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef', 64, 0,
    UInt64($A027DA0188933F32), '64 bytes');
  CheckHash(
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' +
    '0123456789abcdef0123456789abcdef', 96, 0,
    UInt64($1BFFD740AA70C33A), '96 bytes');
  CheckHash(
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' +
    '0123456789abcdef0123456789abcdef', 96, 42,
    UInt64($5F531FDFBF6940BD), '96 bytes seed=42');
end;

procedure TestSeed;
begin
  CheckHash('hello', 5, 42, UInt64($EE351341C5960B52), '''hello'' seed=42');
end;

procedure TestWyHashDeterministicRegressionVectors;
var
  H64: UInt64;
  H32: UInt32;
  S: AnsiString;
begin
  CheckHash(nil, 0, 0, UInt64($42BC986DC5EEC4D3), 'regression empty seed=0');
  CheckHash('abc', 3, 0, UInt64($B4808DF22D44FFCF), 'regression abc raw seed=0');

  H64 := WyHashStr('abc', 0);
  Check(H64 = UInt64($B4808DF22D44FFCF), 'WyHashStr abc seed=0 regression');

  H64 := WyHashStr('hello', 42);
  Check(H64 = UInt64($EE351341C5960B52), 'WyHashStr hello seed=42 regression');

  H32 := WyHashStr32('abc', 42);
  Check(H32 = UInt32($0C14D674), 'WyHashStr32 abc seed=42 regression');

  S := 'abc';
  Check(WyHash(@S[1], SizeUInt(Length(S)), 42) = WyHashStr(S, 42),
    'WyHashStr matches pointer hash with seed');
  Check(WyHash32(@S[1], SizeUInt(Length(S)), 42) = WyHashStr32(S, 42),
    'WyHashStr32 matches pointer hash with seed');
end;

procedure TestStr;
var H1, H2: UInt64;
begin
  H1 := WyHashStr('hello', 0);
  H2 := WyHash(PAnsiChar('hello'), 5, 0);
  Check(H1 = H2, 'WyHashStr matches WyHash');
end;

procedure TestStrEmptyMatchesRaw;
var
  H1, H2: UInt64;
  H32A, H32B: UInt32;
begin
  H1 := WyHashStr('', 0);
  H2 := WyHash(nil, 0, 0);
  CheckEqual(Int64(H2), Int64(H1), 'empty WyHashStr seed=0 matches raw empty');

  H1 := WyHashStr('', 42);
  H2 := WyHash(nil, 0, 42);
  CheckEqual(Int64(H2), Int64(H1), 'empty WyHashStr seed=42 matches raw empty');

  H32A := WyHashStr32('', 42);
  H32B := WyHash32(nil, 0, 42);
  CheckEqual(Int64(H32B), Int64(H32A), 'empty WyHashStr32 matches raw empty');
end;

procedure TestNilPositiveLengthRejected;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    WyHash(nil, 1, 0);
  except
    on E: EArgumentError do
      LRaised := True;
    on E: Exception do
      Fail('expected EArgumentError, got ' + E.ClassName + ': ' + E.Message);
  end;
  Check(LRaised, 'WyHash(nil, positive length) must reject malformed input');
end;

procedure Test32;
var H64: UInt64; H32: UInt32;
begin
  H64 := WyHash(PAnsiChar('test'), 4, 0);
  H32 := WyHash32(PAnsiChar('test'), 4, 0);
  Check(H32 = UInt32(H64 xor (H64 shr 32)), 'WyHash32 = fold of WyHash');
end;

begin
  T := TTestRunner.Create('nextpas.core.hash.wyhash');
  T.Run('empty input', @TestEmpty);
  T.Run('short strings (1-5 bytes)', @TestShort);
  T.Run('medium strings (11-18 bytes)', @TestMedium);
  T.Run('long string (50 bytes)', @TestLong);
  T.Run('seed variation', @TestSeed);
  T.Run('deterministic regression vectors', @TestWyHashDeterministicRegressionVectors);
  T.Run('WyHashStr consistency', @TestStr);
  T.Run('empty WyHashStr consistency', @TestStrEmptyMatchesRaw);
  T.Run('nil positive length rejected', @TestNilPositiveLengthRejected);
  T.Run('WyHash32 fold', @Test32);
  T.Summary;
end.
