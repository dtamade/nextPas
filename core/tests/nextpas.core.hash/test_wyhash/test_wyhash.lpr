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
end;

procedure TestLong;
begin
  CheckHash('01234567890123456789012345678901234567890123456789', 50, 0,
    UInt64($8F3F90705D27CB20), '50 bytes');
end;

procedure TestSeed;
begin
  CheckHash('hello', 5, 42, UInt64($EE351341C5960B52), '''hello'' seed=42');
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

procedure TestDistribution;
var
  I: Integer;
  Buckets: array[0..15] of Integer;
  H: UInt32;
  LBuf: array[0..3] of Byte;
begin
  FillChar(Buckets, SizeOf(Buckets), 0);
  for I := 0 to 9999 do
  begin
    PInt32(@LBuf[0])^ := I;
    H := WyHash32(@LBuf[0], 4, 0);
    Inc(Buckets[H and $F]);
  end;
  for I := 0 to 15 do
    Check((Buckets[I] > 400) and (Buckets[I] < 800), 'bucket ' + IntToStr(I) + ' in range');
end;

begin
  T := TTestRunner.Create('nextpas.core.hash.wyhash');
  T.Run('empty input', @TestEmpty);
  T.Run('short strings (1-5 bytes)', @TestShort);
  T.Run('medium strings (11-18 bytes)', @TestMedium);
  T.Run('long string (50 bytes)', @TestLong);
  T.Run('seed variation', @TestSeed);
  T.Run('WyHashStr consistency', @TestStr);
  T.Run('empty WyHashStr consistency', @TestStrEmptyMatchesRaw);
  T.Run('nil positive length rejected', @TestNilPositiveLengthRejected);
  T.Run('WyHash32 fold', @Test32);
  T.Run('distribution uniformity', @TestDistribution);
  T.Summary;
end.
