program test_chacha20poly1305;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.crypto.chacha20poly1305,
  nextpas.core.test;

function HexToBytes(const AHex: string): TBytes;
var I: Integer;
begin SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do Result[I] := StrToInt('$' + Copy(AHex, I*2+1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var I: Integer;
begin Result := '';
  for I := 0 to High(AData) do Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('chacha20poly1305');

  LSuite.Test('RFC 8439 AEAD encrypt', procedure
  var LKey, LNonce, LAAD, LPlain, LCipher, LTag: TBytes; LOk: Boolean;
  begin
    LKey := HexToBytes('808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f');
    LNonce := HexToBytes('070000004041424344454647');
    LAAD := HexToBytes('50515253c0c1c2c3c4c5c6c7');
    LPlain := HexToBytes('4c616469657320616e642047656e746c656d656e206f662074686520636c617373206f66202739393a204966204920636f756c64206f6666657220796f75206f6e6c79206f6e652074697020666f7220746865206675747572652c2073756e73637265656e20776f756c642062652069742e');
    LOk := TryChaCha20Poly1305Encrypt(LKey, LNonce, LAAD, LPlain, LCipher, LTag);
    CheckTrue(LOk);
    CheckEqual('d31a8d34648e60db7b86afbc53ef7ec2a4aded51296e08fea9e2b5a736ee62d63dbea45e8ca9671282fafb69da92728b1a71de0a9e060b2905d6a5b67ecd3b3692ddbd7f2d778b8c9803aee328091b58fab324e4fad675945585808b4831d7bc3ff4def08e4b7a9de576d26586cec64b6116',
      BytesToHex(LCipher));
    CheckEqual('1ae10b594f09e26a7e902ecbd0600691', BytesToHex(LTag));
  end);

  LSuite.Test('RFC 8439 AEAD decrypt', procedure
  var LKey, LNonce, LAAD, LCipher, LTag, LPlain: TBytes; LOk: Boolean;
  begin
    LKey := HexToBytes('808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f');
    LNonce := HexToBytes('070000004041424344454647');
    LAAD := HexToBytes('50515253c0c1c2c3c4c5c6c7');
    LCipher := HexToBytes('d31a8d34648e60db7b86afbc53ef7ec2a4aded51296e08fea9e2b5a736ee62d63dbea45e8ca9671282fafb69da92728b1a71de0a9e060b2905d6a5b67ecd3b3692ddbd7f2d778b8c9803aee328091b58fab324e4fad675945585808b4831d7bc3ff4def08e4b7a9de576d26586cec64b6116');
    LTag := HexToBytes('1ae10b594f09e26a7e902ecbd0600691');
    LOk := TryChaCha20Poly1305Decrypt(LKey, LNonce, LAAD, LCipher, LTag, LPlain);
    CheckTrue(LOk);
    CheckEqual('4c616469657320616e642047656e746c656d656e206f662074686520636c617373206f66202739393a204966204920636f756c64206f6666657220796f75206f6e6c79206f6e652074697020666f7220746865206675747572652c2073756e73637265656e20776f756c642062652069742e',
      BytesToHex(LPlain));
  end);

  LSuite.Test('roundtrip', procedure
  var LKey, LNonce, LAAD, LPlain, LCipher, LTag, LRecovered: TBytes; LOk: Boolean;
  begin
    LKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
    LNonce := HexToBytes('000000000000000000000001');
    LAAD := HexToBytes('aabbccdd');
    LPlain := HexToBytes('48656c6c6f20576f726c6421');
    LOk := TryChaCha20Poly1305Encrypt(LKey, LNonce, LAAD, LPlain, LCipher, LTag);
    CheckTrue(LOk);
    LOk := TryChaCha20Poly1305Decrypt(LKey, LNonce, LAAD, LCipher, LTag, LRecovered);
    CheckTrue(LOk);
    CheckEqual(BytesToHex(LPlain), BytesToHex(LRecovered));
  end);

  LSuite.Test('combined mode', procedure
  var LKey, LNonce, LAAD, LPlain, LEncrypted, LDecrypted: TBytes; LOk: Boolean;
  begin
    LKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
    LNonce := HexToBytes('000000000000000000000002');
    LAAD := HexToBytes('ff');
    LPlain := HexToBytes('deadbeefcafebabe');
    LOk := TryChaCha20Poly1305EncryptCombined(LKey, LNonce, LAAD, LPlain, LEncrypted);
    CheckTrue(LOk);
    CheckEqual(Length(LPlain) + 16, Length(LEncrypted));
    LOk := TryChaCha20Poly1305DecryptCombined(LKey, LNonce, LAAD, LEncrypted, LDecrypted);
    CheckTrue(LOk);
    CheckEqual(BytesToHex(LPlain), BytesToHex(LDecrypted));
  end);

  LSuite.Test('tampered ciphertext rejected', procedure
  var LKey, LNonce, LAAD, LPlain, LCipher, LTag, LDecrypted: TBytes; LOk: Boolean;
  begin
    LKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
    LNonce := HexToBytes('000000000000000000000003');
    LAAD := HexToBytes('');
    LPlain := HexToBytes('0102030405060708');
    TryChaCha20Poly1305Encrypt(LKey, LNonce, LAAD, LPlain, LCipher, LTag);
    if Length(LCipher) > 0 then LCipher[0] := LCipher[0] xor $FF;
    LOk := TryChaCha20Poly1305Decrypt(LKey, LNonce, LAAD, LCipher, LTag, LDecrypted);
    CheckTrue(not LOk);
  end);

  LSuite.Test('tampered AAD rejected', procedure
  var LKey, LNonce, LAAD, LPlain, LCipher, LTag, LDecrypted: TBytes; LOk: Boolean;
  begin
    LKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
    LNonce := HexToBytes('000000000000000000000004');
    LAAD := HexToBytes('aabbccdd');
    LPlain := HexToBytes('0102030405060708');
    TryChaCha20Poly1305Encrypt(LKey, LNonce, LAAD, LPlain, LCipher, LTag);
    LAAD[0] := LAAD[0] xor $01;
    LOk := TryChaCha20Poly1305Decrypt(LKey, LNonce, LAAD, LCipher, LTag, LDecrypted);
    CheckTrue(not LOk);
  end);

  LSuite.Test('empty plaintext', procedure
  var LKey, LNonce, LAAD, LPlain, LCipher, LTag, LDecrypted: TBytes; LOk: Boolean;
  begin
    LKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
    LNonce := HexToBytes('000000000000000000000005');
    LAAD := HexToBytes('aabb');
    SetLength(LPlain, 0);
    LOk := TryChaCha20Poly1305Encrypt(LKey, LNonce, LAAD, LPlain, LCipher, LTag);
    CheckTrue(LOk);
    CheckEqual(0, Length(LCipher));
    CheckEqual(16, Length(LTag));
    LOk := TryChaCha20Poly1305Decrypt(LKey, LNonce, LAAD, LCipher, LTag, LDecrypted);
    CheckTrue(LOk);
    CheckEqual(0, Length(LDecrypted));
  end);

  LSuite.Test('wrong key rejected', procedure
  var LKey, LWrongKey, LNonce, LAAD, LPlain, LCipher, LTag, LDecrypted: TBytes; LOk: Boolean;
  begin
    LKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
    LWrongKey := HexToBytes('ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff');
    LNonce := HexToBytes('000000000000000000000006');
    SetLength(LAAD, 0);
    LPlain := HexToBytes('cafebabe');
    TryChaCha20Poly1305Encrypt(LKey, LNonce, LAAD, LPlain, LCipher, LTag);
    LOk := TryChaCha20Poly1305Decrypt(LWrongKey, LNonce, LAAD, LCipher, LTag, LDecrypted);
    CheckTrue(not LOk);
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.crypto.chacha20poly1305');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
