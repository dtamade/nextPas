program test_pkcs8;

{$mode objfpc}{$H+}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils,
  nextpas.core.crypto.pkcs8;

var
  GPass, GFail: Integer;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('  [PASS] ', AName);
    Inc(GPass);
  end
  else
  begin
    WriteLn('  [FAIL] ', AName);
    Inc(GFail);
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

procedure TestPBKDF2_SHA256_RFC6070;
var
  LPassword, LSalt, LResult: TBytes;
begin
  // RFC 6070 test vector adapted for HMAC-SHA256
  // password = "password", salt = "salt", iterations = 1, dkLen = 32
  SetLength(LPassword, 8);
  Move(PAnsiChar('password')^, LPassword[0], 8);
  SetLength(LSalt, 4);
  Move(PAnsiChar('salt')^, LSalt[0], 4);

  LResult := PBKDF2_HMAC_SHA256(LPassword, LSalt, 1, 32);
  Check('PBKDF2-SHA256 output length = 32', Length(LResult) = 32);
  Check('PBKDF2-SHA256 non-zero', BytesToHex(LResult) <> StringOfChar('0', 64));

  // Known answer: PBKDF2-HMAC-SHA256("password", "salt", 1, 32)
  // = 120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b
  Check('PBKDF2-SHA256 known answer',
    BytesToHex(LResult) = '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
end;

procedure TestPBKDF2_SHA256_MultiIter;
var
  LPassword, LSalt, LResult: TBytes;
begin
  SetLength(LPassword, 8);
  Move(PAnsiChar('password')^, LPassword[0], 8);
  SetLength(LSalt, 4);
  Move(PAnsiChar('salt')^, LSalt[0], 4);

  // iterations = 2
  LResult := PBKDF2_HMAC_SHA256(LPassword, LSalt, 2, 32);
  Check('PBKDF2-SHA256 iter=2 length', Length(LResult) = 32);
  // Known: ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43
  Check('PBKDF2-SHA256 iter=2 value',
    BytesToHex(LResult) = 'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43');

  // iterations = 4096
  LResult := PBKDF2_HMAC_SHA256(LPassword, LSalt, 4096, 32);
  Check('PBKDF2-SHA256 iter=4096 length', Length(LResult) = 32);
  // Known: c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a
  Check('PBKDF2-SHA256 iter=4096 value',
    BytesToHex(LResult) = 'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a');
end;

procedure TestPBKDF2_SHA256_LongOutput;
var
  LPassword, LSalt, LResult: TBytes;
begin
  SetLength(LPassword, 8);
  Move(PAnsiChar('password')^, LPassword[0], 8);
  SetLength(LSalt, 4);
  Move(PAnsiChar('salt')^, LSalt[0], 4);

  LResult := PBKDF2_HMAC_SHA256(LPassword, LSalt, 1, 64);
  Check('PBKDF2-SHA256 64-byte output', Length(LResult) = 64);
end;

procedure TestDecryptPKCS8_InvalidDER;
var
  LBadDER, LDecrypted: TBytes;
  LError: string;
  LOk: Boolean;
begin
  LBadDER := HexToBytes('30820100300d06092a864886f70d0101010500048200f0');
  try
    LOk := TryDecryptPKCS8EncryptedPrivateKey(LBadDER, 'password', LDecrypted, LError);
    Check('invalid DER rejected', not LOk);
  except
    on E: Exception do
      Check('invalid DER handled (exception)', True);
  end;
end;

procedure TestDecryptTraditional_InvalidAlgo;
var
  LData, LDecrypted: TBytes;
  LError: string;
  LOk: Boolean;
begin
  SetLength(LData, 32);
  FillChar(LData[0], 32, $AA);
  try
    LOk := TryDecryptTraditionalPEMPrivateKey(LData, 'UNKNOWN-ALGO', 'aabbccdd', 'pass', LDecrypted, LError);
    Check('unknown algo rejected', not LOk);
  except
    on E: Exception do
      Check('unknown algo handled (exception)', True);
  end;
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== PKCS8 / PBKDF2 Tests ===');
  WriteLn;

  TestPBKDF2_SHA256_RFC6070;
  TestPBKDF2_SHA256_MultiIter;
  TestPBKDF2_SHA256_LongOutput;
  TestDecryptPKCS8_InvalidDER;
  TestDecryptTraditional_InvalidAlgo;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then
    Halt(1);
end.
