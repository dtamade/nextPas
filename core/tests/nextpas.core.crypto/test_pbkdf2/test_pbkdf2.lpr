program test_pbkdf2;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.hash.base,
  nextpas.core.crypto.pbkdf2,
  nextpas.core.test;

function ToHex(const A: TBytes): string;
var I: Integer;
begin Result := '';
  for I := 0 to High(A) do Result := Result + LowerCase(IntToHex(A[I], 2));
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('pbkdf2');

  LSuite.Test('SHA256 iter=1', procedure
  var LPwd, LSalt, LKey: TBytes;
  begin
    LPwd := StringToUTF8Bytes('password');
    LSalt := StringToUTF8Bytes('salt');
    LKey := PBKDF2_SHA256(LPwd, LSalt, 1, 32);
    CheckEqual(32, Length(LKey));
    CheckEqual('120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b', ToHex(LKey));
  end);

  LSuite.Test('SHA256 iter=2', procedure
  var LPwd, LSalt, LKey: TBytes;
  begin
    LPwd := StringToUTF8Bytes('password');
    LSalt := StringToUTF8Bytes('salt');
    LKey := PBKDF2_SHA256(LPwd, LSalt, 2, 32);
    CheckEqual('ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43', ToHex(LKey));
  end);

  LSuite.Test('SHA256 iter=4096', procedure
  var LPwd, LSalt, LKey: TBytes;
  begin
    LPwd := StringToUTF8Bytes('password');
    LSalt := StringToUTF8Bytes('salt');
    LKey := PBKDF2_SHA256(LPwd, LSalt, 4096, 32);
    CheckEqual('c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a', ToHex(LKey));
  end);

  LSuite.Test('SHA256 dkLen=64', procedure
  var LPwd, LSalt, LKey: TBytes;
  begin
    LPwd := StringToUTF8Bytes('password');
    LSalt := StringToUTF8Bytes('salt');
    LKey := PBKDF2_SHA256(LPwd, LSalt, 1, 64);
    CheckEqual(64, Length(LKey));
    CheckEqual('120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      Copy(ToHex(LKey), 1, 64));
  end);

  LSuite.Test('SHA1 iter=1', procedure
  var LPwd, LSalt, LKey: TBytes;
  begin
    LPwd := StringToUTF8Bytes('password');
    LSalt := StringToUTF8Bytes('salt');
    LKey := PBKDF2_SHA1(LPwd, LSalt, 1, 20);
    CheckEqual(20, Length(LKey));
    CheckEqual('0c60c80f961f0e71f3a9b524af6012062fe037a6', ToHex(LKey));
  end);

  LSuite.Test('SHA1 iter=2', procedure
  var LPwd, LSalt, LKey: TBytes;
  begin
    LPwd := StringToUTF8Bytes('password');
    LSalt := StringToUTF8Bytes('salt');
    LKey := PBKDF2_SHA1(LPwd, LSalt, 2, 20);
    CheckEqual('ea6c014dc72d6f8ccd1ed92ace1d41f0d8de8957', ToHex(LKey));
  end);

  LSuite.Test('SHA1 iter=4096', procedure
  var LPwd, LSalt, LKey: TBytes;
  begin
    LPwd := StringToUTF8Bytes('password');
    LSalt := StringToUTF8Bytes('salt');
    LKey := PBKDF2_SHA1(LPwd, LSalt, 4096, 20);
    CheckEqual('4b007901b765489abead49d926f721d065a429c1', ToHex(LKey));
  end);

  LSuite.Test('edge cases', procedure
  var LPwd, LSalt, LKey: TBytes;
  begin
    SetLength(LPwd, 0);
    LSalt := StringToUTF8Bytes('salt');
    LKey := PBKDF2_SHA256(LPwd, LSalt, 1, 32);
    CheckEqual(32, Length(LKey));
    LPwd := StringToUTF8Bytes('password');
    SetLength(LSalt, 0);
    LKey := PBKDF2_SHA256(LPwd, LSalt, 1, 32);
    CheckEqual(32, Length(LKey));
    LSalt := StringToUTF8Bytes('s');
    LKey := PBKDF2_SHA256(LPwd, LSalt, 1, 1);
    CheckEqual(1, Length(LKey));
    LPwd := StringToUTF8Bytes('password');
    LSalt := StringToUTF8Bytes('salt');
    LKey := PBKDF2(haSHA256, LPwd, LSalt, 1, 32);
    CheckEqual('120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b', ToHex(LKey));
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.crypto.pbkdf2');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
