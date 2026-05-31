program test_tls12_record_cbc;

{$mode objfpc}{$H+}

uses
  SysUtils, nextpas.core.tls.crypto.tls12record;

var
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if ACondition then
    Inc(GPassCount)
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

procedure TestCBCHMAC_EncryptDecrypt_SHA256;
var
  LMACKey, LEncKey: TBytes;
  LPlaintext, LEncrypted, LDecrypted: TBytes;
  LSeqNum: UInt64;
  LContentType: Byte;
  LOk: Boolean;
  LError: string;
begin
  WriteLn('Test: TLS 1.2 CBC+HMAC-SHA256 encrypt/decrypt roundtrip');
  LMACKey := HexToBytes('0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20');
  LEncKey := HexToBytes('2122232425262728292a2b2c2d2e2f30');
  LPlaintext := HexToBytes('48656c6c6f20544c5320312e3221');
  LSeqNum := 0;
  LContentType := 23;

  LOk := TLS12CBCEncrypt_SHA256(LEncKey, LMACKey, LSeqNum, LContentType, LPlaintext, LEncrypted, LError);
  Check(LOk, 'Encrypt should succeed: ' + LError);
  Check(Length(LEncrypted) > Length(LPlaintext), 'Encrypted should be larger (IV + padding + MAC)');
  Check((Length(LEncrypted) mod 16) = 0, 'Encrypted length must be multiple of block size');

  LOk := TLS12CBCDecrypt_SHA256(LEncKey, LMACKey, LSeqNum, LContentType, LEncrypted, LDecrypted, LError);
  Check(LOk, 'Decrypt should succeed: ' + LError);
  Check(BytesToHex(LDecrypted) = BytesToHex(LPlaintext), 'Decrypted must match original plaintext');
end;

procedure TestCBCHMAC_EncryptDecrypt_SHA384;
var
  LMACKey, LEncKey: TBytes;
  LPlaintext, LEncrypted, LDecrypted: TBytes;
  LSeqNum: UInt64;
  LContentType: Byte;
  LOk: Boolean;
  LError: string;
begin
  WriteLn('Test: TLS 1.2 CBC+HMAC-SHA384 encrypt/decrypt roundtrip');
  SetLength(LMACKey, 48);
  FillChar(LMACKey[0], 48, $AA);
  LEncKey := HexToBytes('2122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40');
  LPlaintext := HexToBytes('54686973206973206120746573742e');
  LSeqNum := 42;
  LContentType := 23;

  LOk := TLS12CBCEncrypt_SHA384(LEncKey, LMACKey, LSeqNum, LContentType, LPlaintext, LEncrypted, LError);
  Check(LOk, 'SHA384 encrypt should succeed: ' + LError);

  LOk := TLS12CBCDecrypt_SHA384(LEncKey, LMACKey, LSeqNum, LContentType, LEncrypted, LDecrypted, LError);
  Check(LOk, 'SHA384 decrypt should succeed: ' + LError);
  Check(BytesToHex(LDecrypted) = BytesToHex(LPlaintext), 'SHA384 decrypted must match');
end;

procedure TestCBCHMAC_BadMAC;
var
  LMACKey, LEncKey: TBytes;
  LPlaintext, LEncrypted, LDecrypted: TBytes;
  LSeqNum: UInt64;
  LContentType: Byte;
  LOk: Boolean;
  LError: string;
begin
  WriteLn('Test: TLS 1.2 CBC+HMAC bad MAC detection');
  LMACKey := HexToBytes('0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20');
  LEncKey := HexToBytes('2122232425262728292a2b2c2d2e2f30');
  LPlaintext := HexToBytes('48656c6c6f');
  LSeqNum := 1;
  LContentType := 23;

  LOk := TLS12CBCEncrypt_SHA256(LEncKey, LMACKey, LSeqNum, LContentType, LPlaintext, LEncrypted, LError);
  Check(LOk, 'Encrypt should succeed');

  LEncrypted[Length(LEncrypted) - 17] := LEncrypted[Length(LEncrypted) - 17] xor $FF;

  LOk := TLS12CBCDecrypt_SHA256(LEncKey, LMACKey, LSeqNum, LContentType, LEncrypted, LDecrypted, LError);
  Check(not LOk, 'Decrypt with corrupted MAC must fail');
  Check(Length(LDecrypted) = 0, 'Failed decrypt must not leak plaintext');
end;

procedure TestCBCHMAC_BadPadding;
var
  LMACKey, LEncKey: TBytes;
  LPlaintext, LEncrypted, LDecrypted: TBytes;
  LSeqNum: UInt64;
  LContentType: Byte;
  LOk: Boolean;
  LError: string;
begin
  WriteLn('Test: TLS 1.2 CBC+HMAC bad padding detection');
  LMACKey := HexToBytes('0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20');
  LEncKey := HexToBytes('2122232425262728292a2b2c2d2e2f30');
  LPlaintext := HexToBytes('48656c6c6f');
  LSeqNum := 2;
  LContentType := 23;

  LOk := TLS12CBCEncrypt_SHA256(LEncKey, LMACKey, LSeqNum, LContentType, LPlaintext, LEncrypted, LError);
  Check(LOk, 'Encrypt should succeed');

  LEncrypted[Length(LEncrypted) - 1] := LEncrypted[Length(LEncrypted) - 1] xor $FF;

  LOk := TLS12CBCDecrypt_SHA256(LEncKey, LMACKey, LSeqNum, LContentType, LEncrypted, LDecrypted, LError);
  Check(not LOk, 'Decrypt with corrupted padding must fail');
  Check(Length(LDecrypted) = 0, 'Failed decrypt must not leak plaintext');
end;

procedure TestCBCHMAC_UnifiedError;
var
  LMACKey, LEncKey: TBytes;
  LPlaintext, LEncrypted, LDecrypted: TBytes;
  LBadMAC, LBadPad: TBytes;
  LSeqNum: UInt64;
  LContentType: Byte;
  LOk: Boolean;
  LErrorMAC, LErrorPad: string;
begin
  WriteLn('Test: TLS 1.2 CBC+HMAC unified error (no oracle)');
  LMACKey := HexToBytes('0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20');
  LEncKey := HexToBytes('2122232425262728292a2b2c2d2e2f30');
  LPlaintext := HexToBytes('48656c6c6f');
  LSeqNum := 3;
  LContentType := 23;

  TLS12CBCEncrypt_SHA256(LEncKey, LMACKey, LSeqNum, LContentType, LPlaintext, LEncrypted, LErrorMAC);

  LBadMAC := Copy(LEncrypted);
  LBadMAC[20] := LBadMAC[20] xor $FF;
  TLS12CBCDecrypt_SHA256(LEncKey, LMACKey, LSeqNum, LContentType, LBadMAC, LDecrypted, LErrorMAC);

  LBadPad := Copy(LEncrypted);
  LBadPad[Length(LBadPad) - 1] := LBadPad[Length(LBadPad) - 1] xor $FF;
  TLS12CBCDecrypt_SHA256(LEncKey, LMACKey, LSeqNum, LContentType, LBadPad, LDecrypted, LErrorPad);

  Check(LErrorMAC = LErrorPad, 'MAC failure and padding failure must produce identical error message (anti-oracle)');
end;

begin
  WriteLn('=== TLS 1.2 CBC+HMAC Record Protection Tests ===');
  WriteLn('');

  TestCBCHMAC_EncryptDecrypt_SHA256;
  TestCBCHMAC_EncryptDecrypt_SHA384;
  TestCBCHMAC_BadMAC;
  TestCBCHMAC_BadPadding;
  TestCBCHMAC_UnifiedError;

  WriteLn('');
  WriteLn(Format('Results: %d passed, %d failed', [GPassCount, GFailCount]));
  if GFailCount > 0 then
    Halt(1);
end.
