program test_sha256;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base.utils,
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.hash.base,
  nextpas.core.hash.intf,
  nextpas.core.hash.sha256,
  nextpas.core.test;

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
  CheckEqual('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    DigestToHex(LDigest));
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
  CheckEqual('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    DigestToHex(LDigest));
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
  CheckEqual('248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    DigestToHex(LDigest));
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
  CheckTrue(CompareMem(@LDigest1[0], @LDigest2[0], SHA256_DIGEST_SIZE),
    'Incremental == one-shot');
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
  CheckTrue(CompareMem(@LDigest1[0], @LDigest2[0], SHA256_DIGEST_SIZE),
    'Sum called twice gives same result');
  LHasher.Write(LMore[0], 3);
  LHasher.Sum(LDigest2, SHA256_DIGEST_SIZE);
  CheckTrue(not CompareMem(@LDigest1[0], @LDigest2[0], SHA256_DIGEST_SIZE),
    'Sum after more Write gives different result');
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
  CheckTrue(CompareMem(@LBytes[0], @LDigest[0], SHA256_DIGEST_SIZE),
    'SumBytes == Sum (empty)');
  CheckEqual(32, Length(LBytes));
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
  CheckTrue(CompareMem(@LDigest1[0], @LDigest2[0], SHA256_DIGEST_SIZE),
    'Reset returns to initial state');
end;

procedure TestMetadata;
var
  LHasher: IHasher;
begin
  LHasher := NewSHA256;
  CheckEqual(32, LHasher.DigestSize);
  CheckEqual(64, LHasher.BlockSize);
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('sha256');
  LSuite.Test('empty string', @TestEmpty);
  LSuite.Test('abc', @TestABC);
  LSuite.Test('448-bit message', @TestLong);
  LSuite.Test('incremental == one-shot', @TestIncremental);
  LSuite.Test('Sum does not mutate', @TestSumDoesNotMutate);
  LSuite.Test('SumBytes', @TestSumBytes);
  LSuite.Test('Reset', @TestReset);
  LSuite.Test('metadata', @TestMetadata);
  LRunner := TSuiteRunner.Create('nextpas.core.hash.sha256');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then
    Halt(1);
end.
