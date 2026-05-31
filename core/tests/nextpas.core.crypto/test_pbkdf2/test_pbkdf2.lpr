program test_pbkdf2;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.hash.base,
  nextpas.core.crypto.pbkdf2;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then begin WriteLn('  [PASS] ', AName); Inc(GPass); end
  else begin WriteLn('  [FAIL] ', AName); Inc(GFail); end;
end;

function ToHex(const A: TBytes): string;
var I: Integer;
begin
  Result := '';
  for I := 0 to High(A) do Result := Result + LowerCase(IntToHex(A[I], 2));
end;

procedure TestPBKDF2_SHA256;
var
  LPwd, LSalt, LKey: TBytes;
begin
  WriteLn('--- PBKDF2-HMAC-SHA256 (RFC 6070 style) ---');

  // "password" / "salt" / iter=1 / dkLen=32
  LPwd := TEncoding.UTF8.GetBytes(UnicodeString('password'));
  LSalt := TEncoding.UTF8.GetBytes(UnicodeString('salt'));

  LKey := PBKDF2_SHA256(LPwd, LSalt, 1, 32);
  Check('iter=1 length=32', Length(LKey) = 32);
  Check('iter=1 value',
    ToHex(LKey) = '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');

  LKey := PBKDF2_SHA256(LPwd, LSalt, 2, 32);
  Check('iter=2 value',
    ToHex(LKey) = 'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43');

  LKey := PBKDF2_SHA256(LPwd, LSalt, 4096, 32);
  Check('iter=4096 value',
    ToHex(LKey) = 'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a');

  // dkLen=64 (multi-block)
  LKey := PBKDF2_SHA256(LPwd, LSalt, 1, 64);
  Check('iter=1 dkLen=64 length', Length(LKey) = 64);
  Check('iter=1 dkLen=64 first 32 bytes match',
    Copy(ToHex(LKey), 1, 64) = '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
end;

procedure TestPBKDF2_SHA1;
var
  LPwd, LSalt, LKey: TBytes;
begin
  WriteLn('--- PBKDF2-HMAC-SHA1 (RFC 6070) ---');

  // RFC 6070 Test Vector 1: "password" / "salt" / iter=1 / dkLen=20
  LPwd := TEncoding.UTF8.GetBytes(UnicodeString('password'));
  LSalt := TEncoding.UTF8.GetBytes(UnicodeString('salt'));

  LKey := PBKDF2_SHA1(LPwd, LSalt, 1, 20);
  Check('SHA1 iter=1 length=20', Length(LKey) = 20);
  Check('SHA1 iter=1 value',
    ToHex(LKey) = '0c60c80f961f0e71f3a9b524af6012062fe037a6');

  LKey := PBKDF2_SHA1(LPwd, LSalt, 2, 20);
  Check('SHA1 iter=2 value',
    ToHex(LKey) = 'ea6c014dc72d6f8ccd1ed92ace1d41f0d8de8957');

  LKey := PBKDF2_SHA1(LPwd, LSalt, 4096, 20);
  Check('SHA1 iter=4096 value',
    ToHex(LKey) = '4b007901b765489abead49d926f721d065a429c1');
end;

procedure TestEdgeCases;
var
  LPwd, LSalt, LKey: TBytes;
begin
  WriteLn('--- Edge cases ---');

  // Empty password
  SetLength(LPwd, 0);
  LSalt := TEncoding.UTF8.GetBytes(UnicodeString('salt'));
  LKey := PBKDF2_SHA256(LPwd, LSalt, 1, 32);
  Check('empty password: length=32', Length(LKey) = 32);

  // Empty salt
  LPwd := TEncoding.UTF8.GetBytes(UnicodeString('password'));
  SetLength(LSalt, 0);
  LKey := PBKDF2_SHA256(LPwd, LSalt, 1, 32);
  Check('empty salt: length=32', Length(LKey) = 32);

  // dkLen=1
  LSalt := TEncoding.UTF8.GetBytes(UnicodeString('s'));
  LKey := PBKDF2_SHA256(LPwd, LSalt, 1, 1);
  Check('dkLen=1', Length(LKey) = 1);

  // Generic API
  LPwd := TEncoding.UTF8.GetBytes(UnicodeString('password'));
  LSalt := TEncoding.UTF8.GetBytes(UnicodeString('salt'));
  LKey := PBKDF2(haSHA256, LPwd, LSalt, 1, 32);
  Check('Generic API == PBKDF2_SHA256',
    ToHex(LKey) = '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== PBKDF2 Tests ===');
  WriteLn;

  TestPBKDF2_SHA256;
  TestPBKDF2_SHA1;
  TestEdgeCases;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then Halt(1);
end.
