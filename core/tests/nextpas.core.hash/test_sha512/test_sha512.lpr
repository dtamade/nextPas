program test_sha512;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.hash.base,
  nextpas.core.hash.intf,
  nextpas.core.hash.sha512,
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
  LSuite := TTestSuite.Create('sha512');

  LSuite.Test('SHA-512("")', procedure
  var LH: IHasher; LD: TSHA512Digest;
  begin
    LH := NewSHA512; LH.Sum(LD, SHA512_DIGEST_SIZE);
    CheckEqual('cf83e1357eefb8bd', Copy(ToHex(LD, 64), 1, 16));
  end);

  LSuite.Test('SHA-512("abc")', procedure
  var LH: IHasher; LD: TSHA512Digest; LData: AnsiString;
  begin
    LH := NewSHA512; LData := 'abc'; LH.Write(LData[1], 3); LH.Sum(LD, SHA512_DIGEST_SIZE);
    CheckEqual('ddaf35a193617aba', Copy(ToHex(LD, 64), 1, 16));
  end);

  LSuite.Test('SHA-384("")', procedure
  var LH: IHasher; LD: TSHA384Digest;
  begin
    LH := NewSHA384; LH.Sum(LD, SHA384_DIGEST_SIZE);
    CheckEqual('38b060a751ac9638', Copy(ToHex(LD, 48), 1, 16));
  end);

  LSuite.Test('SHA-384("abc")', procedure
  var LH: IHasher; LD: TSHA384Digest; LData: AnsiString;
  begin
    LH := NewSHA384; LData := 'abc'; LH.Write(LData[1], 3); LH.Sum(LD, SHA384_DIGEST_SIZE);
    CheckEqual('cb00753f45a35e8b', Copy(ToHex(LD, 48), 1, 16));
  end);

  LSuite.Test('SHA-512 metadata', procedure
  var LH: IHasher;
  begin
    LH := NewSHA512;
    CheckEqual(64, LH.DigestSize);
    CheckEqual(128, LH.BlockSize);
  end);

  LSuite.Test('SHA-384 metadata', procedure
  var LH: IHasher;
  begin
    LH := NewSHA384;
    CheckEqual(48, LH.DigestSize);
    CheckEqual(128, LH.BlockSize);
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.hash.sha512');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then
    Halt(1);
end.
