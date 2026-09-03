program test_wyhash;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.errors,
  nextpas.core.hash.wyhash,
  nextpas.core.test;

procedure CheckHash(const AData: PAnsiChar; ALen: SizeUInt; ASeed: UInt64;
  AExpected: UInt64);
var LGot: UInt64;
begin
  LGot := WyHash(AData, ALen, ASeed);
  CheckEqual(Int64(AExpected), Int64(LGot));
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('wyhash');

  LSuite.Test('empty seed=0', procedure begin
    CheckHash(nil, 0, 0, UInt64($42BC986DC5EEC4D3));
  end);

  LSuite.Test('short strings', procedure begin
    CheckHash('a', 1, 0, UInt64($6CF84E5A2465E867));
    CheckHash('abc', 3, 0, UInt64($B4808DF22D44FFCF));
    CheckHash('hello', 5, 0, UInt64($FAACEC54DF7A6205));
  end);

  LSuite.Test('medium strings', procedure begin
    CheckHash('hello world', 11, 0, UInt64($19F24A02FE04C3CA));
    CheckHash('0123456789abcdef', 16, 0, UInt64($461EBD6F5B59DFA7));
    CheckHash('0123456789abcdefgh', 18, 0, UInt64($544A776BC78FCD3F));
    CheckHash('0123456789abcdef0123456789abcdef', 32, 0, UInt64($C11B4B9E7A314A11));
  end);

  LSuite.Test('long strings', procedure begin
    CheckHash('012345678901234567890123456789012345678901234567', 48, 0,
      UInt64($D047C5859F97FB1B));
    CheckHash('0123456789012345678901234567890123456789012345678', 49, 0,
      UInt64($22DCD7F50FDCA435));
    CheckHash('01234567890123456789012345678901234567890123456789', 50, 0,
      UInt64($222A591E60007D73));
    CheckHash('01234567890123456789012345678901234567890123456789', 50, 42,
      UInt64($176750A3DF14201F));
    CheckHash('0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef', 64, 0,
      UInt64($A027DA0188933F32));
    CheckHash(
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' +
      '0123456789abcdef0123456789abcdef', 96, 0,
      UInt64($1BFFD740AA70C33A));
    CheckHash(
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' +
      '0123456789abcdef0123456789abcdef', 96, 42,
      UInt64($5F531FDFBF6940BD));
  end);

  LSuite.Test('seed variation', procedure begin
    CheckHash('hello', 5, 42, UInt64($EE351341C5960B52));
  end);

  { TestWyHashDeterministicRegressionVectors — kept for portability contract }
  LSuite.Test('deterministic regression', procedure
  var H64: UInt64; H32: UInt32; S: AnsiString;
  begin
    CheckHash(nil, 0, 0, UInt64($42BC986DC5EEC4D3));
    CheckHash('abc', 3, 0, UInt64($B4808DF22D44FFCF));
    H64 := WyHashStr('abc', 0);
    CheckEqual(Int64($B4808DF22D44FFCF), Int64(H64));
    H64 := WyHashStr('hello', 42);
    CheckEqual(Int64($EE351341C5960B52), Int64(H64));
    H32 := WyHashStr32('abc', 42);
    CheckEqual(Int64($0C14D674), Int64(H32));
    S := 'abc';
    CheckTrue(WyHash(@S[1], SizeUInt(Length(S)), 42) = WyHashStr(S, 42));
    CheckTrue(WyHash32(@S[1], SizeUInt(Length(S)), 42) = WyHashStr32(S, 42));
  end);

  LSuite.Test('WyHashStr consistency', procedure
  var H1, H2: UInt64;
  begin
    H1 := WyHashStr('hello', 0);
    H2 := WyHash(PAnsiChar('hello'), 5, 0);
    CheckTrue(H1 = H2);
  end);

  LSuite.Test('empty WyHashStr consistency', procedure
  var H1, H2: UInt64; H32A, H32B: UInt32;
  begin
    H1 := WyHashStr('', 0); H2 := WyHash(nil, 0, 0);
    CheckEqual(Int64(H2), Int64(H1));
    H1 := WyHashStr('', 42); H2 := WyHash(nil, 0, 42);
    CheckEqual(Int64(H2), Int64(H1));
    H32A := WyHashStr32('', 42); H32B := WyHash32(nil, 0, 42);
    CheckEqual(Int64(H32B), Int64(H32A));
  end);

  LSuite.Test('nil positive length rejected', procedure
  var LRaised: Boolean;
  begin
    LRaised := False;
    try WyHash(nil, 1, 0);
    except on E: EArgumentError do LRaised := True; end;
    CheckTrue(LRaised);
  end);

  LSuite.Test('WyHash32 fold', procedure
  var H64: UInt64; H32: UInt32;
  begin
    H64 := WyHash(PAnsiChar('test'), 4, 0);
    H32 := WyHash32(PAnsiChar('test'), 4, 0);
    CheckTrue(H32 = UInt32(H64 xor (H64 shr 32)));
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.hash.wyhash');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
