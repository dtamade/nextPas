program test_sha1;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base.utils,
  nextpas.core.text.conv,
  nextpas.core.hash.base,
  nextpas.core.hash.intf,
  nextpas.core.hash.sha1,
  nextpas.core.test;

function ToHex(const ABuf; ALen: Integer): string;
var
  I: Integer;
  P: PByte;
begin
  Result := '';
  P := @ABuf;
  for I := 0 to ALen - 1 do
    Result := Result + LowerCase(IntToHex(P[I], 2));
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('sha1');

  LSuite.Test('SHA-1("")', procedure
  var LH: IHasher; LD: TSHA1Digest;
  begin
    LH := NewSHA1; LH.Sum(LD, 20);
    CheckEqual('da39a3ee5e6b4b0d3255bfef95601890afd80709', ToHex(LD, 20));
  end);

  LSuite.Test('SHA-1("abc")', procedure
  var LH: IHasher; LD: TSHA1Digest; LData: AnsiString;
  begin
    LH := NewSHA1; LData := 'abc'; LH.Write(LData[1], 3); LH.Sum(LD, 20);
    CheckEqual('a9993e364706816aba3e25717850c26c9cd0d89d', ToHex(LD, 20));
  end);

  LSuite.Test('SHA-1(448-bit)', procedure
  var LH: IHasher; LD: TSHA1Digest; LData: AnsiString;
  begin
    LH := NewSHA1;
    LData := 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq';
    LH.Write(LData[1], Length(LData)); LH.Sum(LD, 20);
    CheckEqual('84983e441c3bd26ebaae4aa1f95129e5e54670f1', ToHex(LD, 20));
  end);

  LSuite.Test('incremental == one-shot', procedure
  var LH: IHasher; LD, LD2: TSHA1Digest; LData: AnsiString; I: Integer;
  begin
    LData := 'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq';
    LH := NewSHA1; LH.Write(LData[1], Length(LData)); LH.Sum(LD, 20);
    LH := NewSHA1;
    for I := 1 to Length(LData) do LH.Write(LData[I], 1);
    LH.Sum(LD2, 20);
    CheckTrue(CompareMem(@LD[0], @LD2[0], 20));
  end);

  LSuite.Test('Sum idempotent', procedure
  var LH: IHasher; LD, LD2: TSHA1Digest; LData: AnsiString;
  begin
    LH := NewSHA1; LData := 'x'; LH.Write(LData[1], 1);
    LH.Sum(LD, 20); LH.Sum(LD2, 20);
    CheckTrue(CompareMem(@LD[0], @LD2[0], 20));
  end);

  LSuite.Test('Reset', procedure
  var LH: IHasher; LD, LD2: TSHA1Digest; LData: AnsiString;
  begin
    LH := NewSHA1; LData := 'x'; LH.Write(LData[1], 1); LH.Reset; LH.Sum(LD, 20);
    LH := NewSHA1; LH.Sum(LD2, 20);
    CheckTrue(CompareMem(@LD[0], @LD2[0], 20));
  end);

  LSuite.Test('metadata', procedure
  var LH: IHasher;
  begin
    LH := NewSHA1;
    CheckEqual(20, LH.DigestSize);
    CheckEqual(64, LH.BlockSize);
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.hash.sha1');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then
    Halt(1);
end.
