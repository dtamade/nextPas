program test_sha256;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.hash.base,
  nextpas.core.hash.intf,
  nextpas.core.hash.sha256;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    Inc(GPass);
    WriteLn('  [PASS] ', AName);
  end
  else
  begin
    Inc(GFail);
    WriteLn('  [FAIL] ', AName);
    Halt(1);
  end;
end;

function DigestToHex(const ADigest: TSHA256Digest): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to 31 do
    Result := Result + LowerCase(IntToHex(ADigest[I], 2));
end;

procedure TestEmpty;
var
  LHasher: IHasher;
  LDigest: TSHA256Digest;
begin
  LHasher := NewSHA256;
  LHasher.Sum(LDigest, SHA256_DIGEST_SIZE);
  Check('SHA-256("") = e3b0c44298fc1c14...',
    DigestToHex(LDigest) = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
end;

procedure TestABC;
var
  LHasher: IHasher;
  LDigest: TSHA256Digest;
  LData: array[0..2] of Byte;
begin
  LData[0] := Ord('a'); LData[1] := Ord('b'); LData[2] := Ord('c');
  LHasher := NewSHA256;
  LHasher.Write(LData[0], 3);
  LHasher.Sum(LDigest, SHA256_DIGEST_SIZE);
  Check('SHA-256("abc") = ba7816bf8f01cfea...',
    DigestToHex(LDigest) = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
end;

procedure TestLong;
var
  LHasher: IHasher;
  LDigest: TSHA256Digest;
  LData: AnsiString;
begin
  LData := 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq';
  LHasher := NewSHA256;
  LHasher.Write(LData[1], Length(LData));
  LHasher.Sum(LDigest, SHA256_DIGEST_SIZE);
  Check('SHA-256(448-bit msg) = 248d6a61d20638b8...',
    DigestToHex(LDigest) = '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1');
end;

procedure TestIncremental;
var
  LHasher: IHasher;
  LDigest1, LDigest2: TSHA256Digest;
  LData: AnsiString;
  I: Integer;
begin
  LData := 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq';

  LHasher := NewSHA256;
  LHasher.Write(LData[1], Length(LData));
  LHasher.Sum(LDigest1, SHA256_DIGEST_SIZE);

  LHasher := NewSHA256;
  for I := 1 to Length(LData) do
    LHasher.Write(LData[I], 1);
  LHasher.Sum(LDigest2, SHA256_DIGEST_SIZE);

  Check('Incremental == one-shot',
    CompareMem(@LDigest1[0], @LDigest2[0], SHA256_DIGEST_SIZE));
end;

procedure TestSumDoesNotMutate;
var
  LHasher: IHasher;
  LDigest1, LDigest2: TSHA256Digest;
  LMore: array[0..2] of Byte;
begin
  LHasher := NewSHA256;
  LMore[0] := Ord('x'); LMore[1] := Ord('y'); LMore[2] := Ord('z');
  LHasher.Write(LMore[0], 3);
  LHasher.Sum(LDigest1, SHA256_DIGEST_SIZE);
  LHasher.Sum(LDigest2, SHA256_DIGEST_SIZE);
  Check('Sum called twice gives same result',
    CompareMem(@LDigest1[0], @LDigest2[0], SHA256_DIGEST_SIZE));

  LHasher.Write(LMore[0], 3);
  LHasher.Sum(LDigest2, SHA256_DIGEST_SIZE);
  Check('Sum after more Write gives different result',
    not CompareMem(@LDigest1[0], @LDigest2[0], SHA256_DIGEST_SIZE));
end;

procedure TestSumBytes;
var
  LHasher: IHasher;
  LBytes: TBytes;
  LDigest: TSHA256Digest;
begin
  LHasher := NewSHA256;
  LBytes := LHasher.SumBytes;
  LHasher.Sum(LDigest, SHA256_DIGEST_SIZE);
  Check('SumBytes == Sum (empty)',
    CompareMem(@LBytes[0], @LDigest[0], SHA256_DIGEST_SIZE));
  Check('SumBytes length = 32', Length(LBytes) = 32);
end;

procedure TestReset;
var
  LHasher: IHasher;
  LDigest1, LDigest2: TSHA256Digest;
  LData: array[0..2] of Byte;
begin
  LData[0] := Ord('a'); LData[1] := Ord('b'); LData[2] := Ord('c');
  LHasher := NewSHA256;
  LHasher.Write(LData[0], 3);
  LHasher.Reset;
  LHasher.Sum(LDigest1, SHA256_DIGEST_SIZE);

  LHasher := NewSHA256;
  LHasher.Sum(LDigest2, SHA256_DIGEST_SIZE);

  Check('Reset returns to initial state',
    CompareMem(@LDigest1[0], @LDigest2[0], SHA256_DIGEST_SIZE));
end;

procedure TestMetadata;
var
  LHasher: IHasher;
begin
  LHasher := NewSHA256;
  Check('DigestSize = 32', LHasher.DigestSize = 32);
  Check('BlockSize = 64', LHasher.BlockSize = 64);
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== nextpas.core.hash.sha256 unit tests ===');

  TestEmpty;
  TestABC;
  TestLong;
  TestIncremental;
  TestSumDoesNotMutate;
  TestSumBytes;
  TestReset;
  TestMetadata;

  WriteLn;
  WriteLn('Results: ', GPass, ' passed, ', GFail, ' failed');
  if GFail > 0 then Halt(1);
end.
