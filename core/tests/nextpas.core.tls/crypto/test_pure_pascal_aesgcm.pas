program test_pure_pascal_aesgcm;

{$mode objfpc}{$H+}

uses
  SysUtils, nextpas.core.tls.crypto.aesgcm;

var
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
  begin
    Inc(GPassCount);
  end
  else
  begin
    Inc(GFailCount);
    WriteLn('  FAIL: ', AMessage);
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to Length(Result) - 1 do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function BytesToHex(const ABytes: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Length(ABytes) - 1 do
    Result := Result + LowerCase(IntToHex(ABytes[I], 2));
end;

procedure TestNISTVector1_AES128GCM;
var
  LKey, LIV, LPlaintext, LAAD: TBytes;
  LCiphertext, LTag: TBytes;
  LDecrypted: TBytes;
  LOk: Boolean;
begin
  WriteLn('Test: NIST AES-128-GCM Test Case 3 (SP 800-38D)');
  LKey := HexToBytes('feffe9928665731c6d6a8f9467308308');
  LIV := HexToBytes('cafebabefacedbaddecaf888');
  LPlaintext := HexToBytes('d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a721c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b391aafd255');
  LAAD := HexToBytes('');

  LOk := PurePascalAESGCMEncrypt(LKey, LIV, LPlaintext, LAAD, LCiphertext, LTag);
  Check(LOk, 'Encrypt should succeed');
  Check(BytesToHex(LCiphertext) = '42831ec2217774244b7221b784d0d49ce3aa212f2c02a4e035c17e2329aca12e21d514b25466931c7d8f6a5aac84aa051ba30b396a0aac973d58e091473f5985', 'Ciphertext mismatch');
  Check(BytesToHex(LTag) = '4d5c2af327cd64a62cf35abd2ba6fab4', 'Tag mismatch');

  LOk := PurePascalAESGCMDecrypt(LKey, LIV, LCiphertext, LTag, LAAD, LDecrypted);
  Check(LOk, 'Decrypt should succeed');
  Check(BytesToHex(LDecrypted) = BytesToHex(LPlaintext), 'Decrypted plaintext mismatch');
end;

procedure TestNISTVector2_AES128GCM_WithAAD;
var
  LKey, LIV, LPlaintext, LAAD: TBytes;
  LCiphertext, LTag: TBytes;
  LDecrypted: TBytes;
  LOk: Boolean;
begin
  WriteLn('Test: NIST AES-128-GCM Test Case 4 (with AAD)');
  LKey := HexToBytes('feffe9928665731c6d6a8f9467308308');
  LIV := HexToBytes('cafebabefacedbaddecaf888');
  LPlaintext := HexToBytes('d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a721c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b39');
  LAAD := HexToBytes('feedfacedeadbeeffeedfacedeadbeefabaddad2');

  LOk := PurePascalAESGCMEncrypt(LKey, LIV, LPlaintext, LAAD, LCiphertext, LTag);
  Check(LOk, 'Encrypt should succeed');
  Check(BytesToHex(LCiphertext) = '42831ec2217774244b7221b784d0d49ce3aa212f2c02a4e035c17e2329aca12e21d514b25466931c7d8f6a5aac84aa051ba30b396a0aac973d58e091', 'Ciphertext mismatch');
  Check(BytesToHex(LTag) = '5bc94fbc3221a5db94fae95ae7121a47', 'Tag mismatch');

  LOk := PurePascalAESGCMDecrypt(LKey, LIV, LCiphertext, LTag, LAAD, LDecrypted);
  Check(LOk, 'Decrypt should succeed');
  Check(BytesToHex(LDecrypted) = BytesToHex(LPlaintext), 'Decrypted plaintext mismatch');
end;

procedure TestNISTVector3_AES256GCM;
var
  LKey, LIV, LPlaintext, LAAD: TBytes;
  LCiphertext, LTag: TBytes;
  LDecrypted: TBytes;
  LOk: Boolean;
begin
  WriteLn('Test: NIST AES-256-GCM Test Case 15 (SP 800-38D)');
  LKey := HexToBytes('feffe9928665731c6d6a8f9467308308feffe9928665731c6d6a8f9467308308');
  LIV := HexToBytes('cafebabefacedbaddecaf888');
  LPlaintext := HexToBytes('d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a721c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b391aafd255');
  LAAD := HexToBytes('');

  LOk := PurePascalAESGCMEncrypt(LKey, LIV, LPlaintext, LAAD, LCiphertext, LTag);
  Check(LOk, 'Encrypt should succeed');
  Check(BytesToHex(LCiphertext) = '522dc1f099567d07f47f37a32a84427d643a8cdcbfe5c0c97598a2bd2555d1aa8cb08e48590dbb3da7b08b1056828838c5f61e6393ba7a0abcc9f662898015ad', 'Ciphertext mismatch');
  Check(BytesToHex(LTag) = 'b094dac5d93471bdec1a502270e3cc6c', 'Tag mismatch');

  LOk := PurePascalAESGCMDecrypt(LKey, LIV, LCiphertext, LTag, LAAD, LDecrypted);
  Check(LOk, 'Decrypt should succeed');
  Check(BytesToHex(LDecrypted) = BytesToHex(LPlaintext), 'Decrypted plaintext mismatch');
end;

procedure TestNISTVector4_AES256GCM_WithAAD;
var
  LKey, LIV, LPlaintext, LAAD: TBytes;
  LCiphertext, LTag: TBytes;
  LDecrypted: TBytes;
  LOk: Boolean;
begin
  WriteLn('Test: NIST AES-256-GCM Test Case 16 (with AAD)');
  LKey := HexToBytes('feffe9928665731c6d6a8f9467308308feffe9928665731c6d6a8f9467308308');
  LIV := HexToBytes('cafebabefacedbaddecaf888');
  LPlaintext := HexToBytes('d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a721c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b39');
  LAAD := HexToBytes('feedfacedeadbeeffeedfacedeadbeefabaddad2');

  LOk := PurePascalAESGCMEncrypt(LKey, LIV, LPlaintext, LAAD, LCiphertext, LTag);
  Check(LOk, 'Encrypt should succeed');
  Check(BytesToHex(LCiphertext) = '522dc1f099567d07f47f37a32a84427d643a8cdcbfe5c0c97598a2bd2555d1aa8cb08e48590dbb3da7b08b1056828838c5f61e6393ba7a0abcc9f662', 'Ciphertext mismatch');
  Check(BytesToHex(LTag) = '76fc6ece0f4e1768cddf8853bb2d551b', 'Tag mismatch');

  LOk := PurePascalAESGCMDecrypt(LKey, LIV, LCiphertext, LTag, LAAD, LDecrypted);
  Check(LOk, 'Decrypt should succeed');
  Check(BytesToHex(LDecrypted) = BytesToHex(LPlaintext), 'Decrypted plaintext mismatch');
end;

procedure TestTagVerificationFailure;
var
  LKey, LIV, LPlaintext, LAAD: TBytes;
  LCiphertext, LTag, LBadTag: TBytes;
  LDecrypted: TBytes;
  LOk: Boolean;
begin
  WriteLn('Test: AES-GCM tag verification failure');
  LKey := HexToBytes('feffe9928665731c6d6a8f9467308308');
  LIV := HexToBytes('cafebabefacedbaddecaf888');
  LPlaintext := HexToBytes('d9313225f88406e5a55909c5aff5269a');
  LAAD := HexToBytes('');

  LOk := PurePascalAESGCMEncrypt(LKey, LIV, LPlaintext, LAAD, LCiphertext, LTag);
  Check(LOk, 'Encrypt should succeed');

  LBadTag := Copy(LTag);
  LBadTag[0] := LBadTag[0] xor $FF;

  LOk := PurePascalAESGCMDecrypt(LKey, LIV, LCiphertext, LBadTag, LAAD, LDecrypted);
  Check(not LOk, 'Decrypt with bad tag must fail');
  Check(Length(LDecrypted) = 0, 'Failed decrypt must not leak plaintext');
end;

procedure TestEmptyPlaintext;
var
  LKey, LIV, LAAD: TBytes;
  LCiphertext, LTag: TBytes;
  LDecrypted: TBytes;
  LOk: Boolean;
begin
  WriteLn('Test: AES-128-GCM empty plaintext (auth-only)');
  LKey := HexToBytes('00000000000000000000000000000000');
  LIV := HexToBytes('000000000000000000000000');

  LOk := PurePascalAESGCMEncrypt(LKey, LIV, nil, nil, LCiphertext, LTag);
  Check(LOk, 'Encrypt empty should succeed');
  Check(Length(LCiphertext) = 0, 'Empty plaintext produces empty ciphertext');
  Check(BytesToHex(LTag) = '58e2fccefa7e3061367f1d57a4e7455a', 'Tag for empty input mismatch');

  LOk := PurePascalAESGCMDecrypt(LKey, LIV, nil, LTag, nil, LDecrypted);
  Check(LOk, 'Decrypt empty should succeed');
  Check(Length(LDecrypted) = 0, 'Empty decrypt produces empty plaintext');
end;

begin
  WriteLn('=== Pure Pascal AES-GCM NIST Vector Tests ===');
  WriteLn('');

  TestNISTVector1_AES128GCM;
  TestNISTVector2_AES128GCM_WithAAD;
  TestNISTVector3_AES256GCM;
  TestNISTVector4_AES256GCM_WithAAD;
  TestTagVerificationFailure;
  TestEmptyPlaintext;

  WriteLn('');
  WriteLn(Format('Results: %d passed, %d failed', [GPassCount, GFailCount]));
  if GFailCount > 0 then
    Halt(1);
end.
