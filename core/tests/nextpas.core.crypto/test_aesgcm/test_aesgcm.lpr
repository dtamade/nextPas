program test_aesgcm;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nextpas.core.crypto.aesgcm;

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

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I*2+1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AData) do
    Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

procedure TestNISTVector1;
var
  LKey, LIV, LPlain, LAAD, LCipher, LTag, LDecrypted: TBytes;
  LOk: Boolean;
begin
  // NIST GCM Test Case 3 (AES-128, 64-byte plaintext)
  LKey := HexToBytes('feffe9928665731c6d6a8f9467308308');
  LIV := HexToBytes('cafebabefacedbaddecaf888');
  LPlain := HexToBytes('d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a721c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b391aafd255');
  LAAD := HexToBytes('');

  LOk := PurePascalAESGCMEncrypt(LKey, LIV, LPlain, LAAD, LCipher, LTag);
  Check('TC3 encrypt succeeds', LOk);
  Check('TC3 ciphertext', BytesToHex(LCipher) =
    '42831ec2217774244b7221b784d0d49ce3aa212f2c02a4e035c17e2329aca12e21d514b25466931c7d8f6a5aac84aa051ba30b396a0aac973d58e091473f5985');
  Check('TC3 tag', BytesToHex(LTag) = '4d5c2af327cd64a62cf35abd2ba6fab4');

  LOk := PurePascalAESGCMDecrypt(LKey, LIV, LCipher, LTag, LAAD, LDecrypted);
  Check('TC3 decrypt succeeds', LOk);
  Check('TC3 roundtrip', BytesToHex(LDecrypted) = BytesToHex(LPlain));
end;

procedure TestNISTVector2;
var
  LKey, LIV, LPlain, LAAD, LCipher, LTag, LDecrypted: TBytes;
  LOk: Boolean;
begin
  // NIST GCM Test Case 4 (AES-128, with AAD)
  LKey := HexToBytes('feffe9928665731c6d6a8f9467308308');
  LIV := HexToBytes('cafebabefacedbaddecaf888');
  LPlain := HexToBytes('d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a721c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b39');
  LAAD := HexToBytes('feedfacedeadbeeffeedfacedeadbeefabaddad2');

  LOk := PurePascalAESGCMEncrypt(LKey, LIV, LPlain, LAAD, LCipher, LTag);
  Check('TC4 encrypt succeeds', LOk);
  Check('TC4 ciphertext', BytesToHex(LCipher) =
    '42831ec2217774244b7221b784d0d49ce3aa212f2c02a4e035c17e2329aca12e21d514b25466931c7d8f6a5aac84aa051ba30b396a0aac973d58e091');
  Check('TC4 tag', BytesToHex(LTag) = '5bc94fbc3221a5db94fae95ae7121a47');

  LOk := PurePascalAESGCMDecrypt(LKey, LIV, LCipher, LTag, LAAD, LDecrypted);
  Check('TC4 decrypt succeeds', LOk);
  Check('TC4 roundtrip', BytesToHex(LDecrypted) = BytesToHex(LPlain));
end;

procedure TestNISTVector3;
var
  LKey, LIV, LPlain, LAAD, LCipher, LTag: TBytes;
  LOk: Boolean;
begin
  // NIST GCM Test Case 1 (AES-128, empty plaintext)
  LKey := HexToBytes('00000000000000000000000000000000');
  LIV := HexToBytes('000000000000000000000000');
  LPlain := HexToBytes('');
  LAAD := HexToBytes('');

  LOk := PurePascalAESGCMEncrypt(LKey, LIV, LPlain, LAAD, LCipher, LTag);
  Check('TC1 encrypt succeeds', LOk);
  Check('TC1 empty ciphertext', Length(LCipher) = 0);
  Check('TC1 tag', BytesToHex(LTag) = '58e2fccefa7e3061367f1d57a4e7455a');
end;

procedure TestTagTamper;
var
  LKey, LIV, LPlain, LAAD, LCipher, LTag, LBadTag, LDecrypted: TBytes;
  LOk: Boolean;
begin
  LKey := HexToBytes('feffe9928665731c6d6a8f9467308308');
  LIV := HexToBytes('cafebabefacedbaddecaf888');
  LPlain := HexToBytes('d9313225f88406e5a55909c5aff5269a');
  LAAD := HexToBytes('');

  PurePascalAESGCMEncrypt(LKey, LIV, LPlain, LAAD, LCipher, LTag);

  // Tamper with tag
  LBadTag := Copy(LTag);
  LBadTag[0] := LBadTag[0] xor $FF;

  LOk := PurePascalAESGCMDecrypt(LKey, LIV, LCipher, LBadTag, LAAD, LDecrypted);
  Check('Tampered tag rejected', not LOk);
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== AES-GCM unit tests ===');

  TestNISTVector1;
  TestNISTVector2;
  TestNISTVector3;
  TestTagTamper;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
end.
