program test_chacha20poly1305;

{$mode objfpc}{$H+}

uses
  {$IFDEF USE_HEAPTRC}heaptrc,{$ENDIF}
  SysUtils,
  nextpas.core.tls.tls13.chacha20poly1305;

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

{ RFC 8439 Section 2.8.2 — AEAD Construction Test Vector }
procedure TestRFC8439_AEAD_Encrypt;
var
  LKey, LNonce, LAAD, LPlaintext: TBytes;
  LCiphertext, LTag: TBytes;
  LExpectedCT, LExpectedTag: TBytes;
  LOk: Boolean;
begin
  LKey := HexToBytes(
    '808182838485868788898a8b8c8d8e8f' +
    '909192939495969798999a9b9c9d9e9f');
  LNonce := HexToBytes('070000004041424344454647');
  LAAD := HexToBytes('50515253c0c1c2c3c4c5c6c7');
  LPlaintext := HexToBytes(
    '4c616469657320616e642047656e746c' +
    '656d656e206f662074686520636c6173' +
    '73206f66202739393a20496620492063' +
    '6f756c64206f6666657220796f75206f' +
    '6e6c79206f6e652074697020666f7220' +
    '746865206675747572652c2073756e73' +
    '637265656e20776f756c642062652069' +
    '742e');

  LExpectedCT := HexToBytes(
    'd31a8d34648e60db7b86afbc53ef7ec2' +
    'a4aded51296e08fea9e2b5a736ee62d6' +
    '3dbea45e8ca9671282fafb69da92728b' +
    '1a71de0a9e060b2905d6a5b67ecd3b36' +
    '92ddbd7f2d778b8c9803aee328091b58' +
    'fab324e4fad675945585808b4831d7bc' +
    '3ff4def08e4b7a9de576d26586cec64b' +
    '6116');
  LExpectedTag := HexToBytes('1ae10b594f09e26a7e902ecbd0600691');

  LOk := TryChaCha20Poly1305Encrypt(LKey, LNonce, LAAD, LPlaintext, LCiphertext, LTag);
  Check('RFC8439 AEAD encrypt ok', LOk);
  if LOk then
  begin
    Check('RFC8439 ciphertext matches', BytesToHex(LCiphertext) = BytesToHex(LExpectedCT));
    Check('RFC8439 tag matches', BytesToHex(LTag) = BytesToHex(LExpectedTag));
  end;
end;

{ RFC 8439 Section 2.8.2 — AEAD Decrypt }
procedure TestRFC8439_AEAD_Decrypt;
var
  LKey, LNonce, LAAD, LCiphertext, LTag: TBytes;
  LPlaintext: TBytes;
  LExpectedPT: TBytes;
  LOk: Boolean;
begin
  LKey := HexToBytes(
    '808182838485868788898a8b8c8d8e8f' +
    '909192939495969798999a9b9c9d9e9f');
  LNonce := HexToBytes('070000004041424344454647');
  LAAD := HexToBytes('50515253c0c1c2c3c4c5c6c7');
  LCiphertext := HexToBytes(
    'd31a8d34648e60db7b86afbc53ef7ec2' +
    'a4aded51296e08fea9e2b5a736ee62d6' +
    '3dbea45e8ca9671282fafb69da92728b' +
    '1a71de0a9e060b2905d6a5b67ecd3b36' +
    '92ddbd7f2d778b8c9803aee328091b58' +
    'fab324e4fad675945585808b4831d7bc' +
    '3ff4def08e4b7a9de576d26586cec64b' +
    '6116');
  LTag := HexToBytes('1ae10b594f09e26a7e902ecbd0600691');
  LExpectedPT := HexToBytes(
    '4c616469657320616e642047656e746c' +
    '656d656e206f662074686520636c6173' +
    '73206f66202739393a20496620492063' +
    '6f756c64206f6666657220796f75206f' +
    '6e6c79206f6e652074697020666f7220' +
    '746865206675747572652c2073756e73' +
    '637265656e20776f756c642062652069' +
    '742e');

  LOk := TryChaCha20Poly1305Decrypt(LKey, LNonce, LAAD, LCiphertext, LTag, LPlaintext);
  Check('RFC8439 AEAD decrypt ok', LOk);
  if LOk then
    Check('RFC8439 plaintext matches', BytesToHex(LPlaintext) = BytesToHex(LExpectedPT));
end;

{ Roundtrip: encrypt then decrypt }
procedure TestRoundtrip;
var
  LKey, LNonce, LAAD, LPlain, LCipher, LTag, LRecovered: TBytes;
  LOk: Boolean;
begin
  LKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
  LNonce := HexToBytes('000000000000000000000001');
  LAAD := HexToBytes('aabbccdd');
  LPlain := HexToBytes('48656c6c6f20576f726c6421');

  LOk := TryChaCha20Poly1305Encrypt(LKey, LNonce, LAAD, LPlain, LCipher, LTag);
  Check('roundtrip encrypt ok', LOk);

  LOk := TryChaCha20Poly1305Decrypt(LKey, LNonce, LAAD, LCipher, LTag, LRecovered);
  Check('roundtrip decrypt ok', LOk);
  if LOk then
    Check('roundtrip plaintext matches', BytesToHex(LRecovered) = BytesToHex(LPlain));
end;

{ Combined mode roundtrip }
procedure TestCombinedMode;
var
  LKey, LNonce, LAAD, LPlain, LEncrypted, LDecrypted: TBytes;
  LOk: Boolean;
begin
  LKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
  LNonce := HexToBytes('000000000000000000000002');
  LAAD := HexToBytes('ff');
  LPlain := HexToBytes('deadbeefcafebabe');

  LOk := TryChaCha20Poly1305EncryptCombined(LKey, LNonce, LAAD, LPlain, LEncrypted);
  Check('combined encrypt ok', LOk);
  Check('combined output = ct + tag (len+16)', Length(LEncrypted) = Length(LPlain) + 16);

  LOk := TryChaCha20Poly1305DecryptCombined(LKey, LNonce, LAAD, LEncrypted, LDecrypted);
  Check('combined decrypt ok', LOk);
  if LOk then
    Check('combined plaintext matches', BytesToHex(LDecrypted) = BytesToHex(LPlain));
end;

{ Tampered ciphertext rejection }
procedure TestTamperedCiphertext;
var
  LKey, LNonce, LAAD, LPlain, LCipher, LTag, LDecrypted: TBytes;
  LOk: Boolean;
begin
  LKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
  LNonce := HexToBytes('000000000000000000000003');
  LAAD := HexToBytes('');
  LPlain := HexToBytes('0102030405060708');

  TryChaCha20Poly1305Encrypt(LKey, LNonce, LAAD, LPlain, LCipher, LTag);

  // Tamper
  if Length(LCipher) > 0 then
    LCipher[0] := LCipher[0] xor $FF;

  LOk := TryChaCha20Poly1305Decrypt(LKey, LNonce, LAAD, LCipher, LTag, LDecrypted);
  Check('tampered ciphertext rejected', not LOk);
end;

{ Tampered AAD rejection }
procedure TestTamperedAAD;
var
  LKey, LNonce, LAAD, LPlain, LCipher, LTag, LDecrypted: TBytes;
  LOk: Boolean;
begin
  LKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
  LNonce := HexToBytes('000000000000000000000004');
  LAAD := HexToBytes('aabbccdd');
  LPlain := HexToBytes('0102030405060708');

  TryChaCha20Poly1305Encrypt(LKey, LNonce, LAAD, LPlain, LCipher, LTag);

  // Tamper AAD
  LAAD[0] := LAAD[0] xor $01;

  LOk := TryChaCha20Poly1305Decrypt(LKey, LNonce, LAAD, LCipher, LTag, LDecrypted);
  Check('tampered AAD rejected', not LOk);
end;

{ Empty plaintext }
procedure TestEmptyPlaintext;
var
  LKey, LNonce, LAAD, LPlain, LCipher, LTag, LDecrypted: TBytes;
  LOk: Boolean;
begin
  LKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
  LNonce := HexToBytes('000000000000000000000005');
  LAAD := HexToBytes('aabb');
  SetLength(LPlain, 0);

  LOk := TryChaCha20Poly1305Encrypt(LKey, LNonce, LAAD, LPlain, LCipher, LTag);
  Check('empty plaintext encrypt ok', LOk);
  Check('empty plaintext → empty ciphertext', Length(LCipher) = 0);
  Check('empty plaintext → 16-byte tag', Length(LTag) = 16);

  LOk := TryChaCha20Poly1305Decrypt(LKey, LNonce, LAAD, LCipher, LTag, LDecrypted);
  Check('empty plaintext decrypt ok', LOk);
  Check('empty plaintext recovered', Length(LDecrypted) = 0);
end;

{ Wrong key rejection }
procedure TestWrongKey;
var
  LKey, LWrongKey, LNonce, LAAD, LPlain, LCipher, LTag, LDecrypted: TBytes;
  LOk: Boolean;
begin
  LKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
  LWrongKey := HexToBytes('ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff');
  LNonce := HexToBytes('000000000000000000000006');
  SetLength(LAAD, 0);
  LPlain := HexToBytes('cafebabe');

  TryChaCha20Poly1305Encrypt(LKey, LNonce, LAAD, LPlain, LCipher, LTag);

  LOk := TryChaCha20Poly1305Decrypt(LWrongKey, LNonce, LAAD, LCipher, LTag, LDecrypted);
  Check('wrong key rejected', not LOk);
end;

begin
  GPass := 0;
  GFail := 0;
  WriteLn('=== ChaCha20-Poly1305 (RFC 8439) Tests ===');
  WriteLn;

  TestRFC8439_AEAD_Encrypt;
  TestRFC8439_AEAD_Decrypt;
  TestRoundtrip;
  TestCombinedMode;
  TestTamperedCiphertext;
  TestTamperedAAD;
  TestEmptyPlaintext;
  TestWrongKey;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPass, GFail]));
  if GFail > 0 then
    Halt(1);
end.
