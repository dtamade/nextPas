program test_md5;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base.utils,
  nextpas.core.text.conv,
  nextpas.core.hash.base,
  nextpas.core.hash.intf,
  nextpas.core.hash.md5,
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
  LSuite := TTestSuite.Create('md5');

  LSuite.Test('MD5("")', procedure
  var LH: IHasher; LD: TMD5Digest;
  begin
    LH := NewMD5; LH.Sum(LD, 16);
    CheckEqual('d41d8cd98f00b204e9800998ecf8427e', ToHex(LD, 16));
  end);

  LSuite.Test('MD5("a")', procedure
  var LH: IHasher; LD: TMD5Digest; LData: AnsiString;
  begin
    LH := NewMD5; LData := 'a'; LH.Write(LData[1], 1); LH.Sum(LD, 16);
    CheckEqual('0cc175b9c0f1b6a831c399e269772661', ToHex(LD, 16));
  end);

  LSuite.Test('MD5("abc")', procedure
  var LH: IHasher; LD: TMD5Digest; LData: AnsiString;
  begin
    LH := NewMD5; LData := 'abc'; LH.Write(LData[1], 3); LH.Sum(LD, 16);
    CheckEqual('900150983cd24fb0d6963f7d28e17f72', ToHex(LD, 16));
  end);

  LSuite.Test('MD5("message digest")', procedure
  var LH: IHasher; LD: TMD5Digest; LData: AnsiString;
  begin
    LH := NewMD5; LData := 'message digest'; LH.Write(LData[1], Length(LData)); LH.Sum(LD, 16);
    CheckEqual('f96b697d7cb7938d525a2f31aaf161d0', ToHex(LD, 16));
  end);

  LSuite.Test('incremental == one-shot', procedure
  var LH: IHasher; LD, LD2: TMD5Digest; LData: AnsiString; I: Integer;
  begin
    LData := 'abcdefghijklmnopqrstuvwxyz';
    LH := NewMD5; LH.Write(LData[1], Length(LData)); LH.Sum(LD, 16);
    LH := NewMD5;
    for I := 1 to Length(LData) do LH.Write(LData[I], 1);
    LH.Sum(LD2, 16);
    CheckTrue(CompareMem(@LD[0], @LD2[0], 16));
  end);

  LSuite.Test('Sum idempotent', procedure
  var LH: IHasher; LD, LD2: TMD5Digest; LData: AnsiString;
  begin
    LH := NewMD5; LData := 'test'; LH.Write(LData[1], 4);
    LH.Sum(LD, 16); LH.Sum(LD2, 16);
    CheckTrue(CompareMem(@LD[0], @LD2[0], 16));
  end);

  LSuite.Test('Reset returns to initial', procedure
  var LH: IHasher; LD, LD2: TMD5Digest; LData: AnsiString;
  begin
    LH := NewMD5; LData := 'test'; LH.Write(LData[1], 4); LH.Reset; LH.Sum(LD, 16);
    LH := NewMD5; LH.Sum(LD2, 16);
    CheckTrue(CompareMem(@LD[0], @LD2[0], 16));
  end);

  LSuite.Test('metadata', procedure
  var LH: IHasher;
  begin
    LH := NewMD5;
    CheckEqual(16, LH.DigestSize);
    CheckEqual(64, LH.BlockSize);
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.hash.md5');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then
    Halt(1);
end.
