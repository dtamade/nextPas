program test_chacha20poly1305;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.system.sysutils,
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

  LSuite.Test('multi-block >=256B KAT (AVX2 4block regression)', procedure
  var LKey, LNonce, LAAD, LPlain, LCipher, LTag: TBytes; LOk: Boolean; I: Integer;
  begin
    // 权威实现(python cryptography)对拍向量；明文公式 i*7+13 mod 256。
    // 历史 AVX2 4-block 路径对 >=256 字节输入从第 16 字节起错乱，
    // 旧 114 字节 RFC 向量覆盖不到该路径，此组用例防止回归。
    LKey := HexToBytes('808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f');
    LNonce := HexToBytes('070000000000000000000000');
    LAAD := HexToBytes('0102030405');

    // N=300
    SetLength(LPlain, 300);
    for I := 0 to 299 do LPlain[I] := Byte((I * 7 + 13) mod 256);
    LOk := TryChaCha20Poly1305Encrypt(LKey, LNonce, LAAD, LPlain, LCipher, LTag);
    CheckTrue(LOk);
    CheckEqual(
      '121e57c70764edb8350c469d32972fa816e7cedd733ee66786616b4021f82dc0' +
      'd1bd459b306097f3cab57c0cee60ca2c84ce0307b1663a1f12dba4d94e885b53' +
      '91b3fcc7c1450862c74cd1eee6a5fd47c71c2f91af2439a2e976e39a80b3c004' +
      'eb88660f753ecf8ae34b4c12e20e157b3ed0735645177b375a06732813a4e67f' +
      'a748f8a53bd1c54326614b420c4bd06b3889966bbd01d1eda0b68bc978dda5a9' +
      'c57e807dfe78638a240ba343e82723053874a5da41a6fa5a5290a2ec9a7e43cf' +
      '54c391c8ea3ac14ae6e1d241780af9148c3f2dd8de407120d171b23f7e00789b' +
      'b79b72e503f82b25fdb0b9d92d9180fbb74c6c532610518b8b0d47598901ae0c' +
      'f41f0f053934c21ce5b2115d790160eb860486100dc4912c2c278af1f1a8ff65' +
      'c0944ab3230f57a4039844df'
      , BytesToHex(LCipher));
    CheckEqual('cdfcd6f20704e4c9fa1ea285f0b48281', BytesToHex(LTag));
    LOk := TryChaCha20Poly1305Decrypt(LKey, LNonce, LAAD, LCipher, LTag, LPlain);
    CheckTrue(LOk);

    // N=600
    SetLength(LPlain, 600);
    for I := 0 to 599 do LPlain[I] := Byte((I * 7 + 13) mod 256);
    LOk := TryChaCha20Poly1305Encrypt(LKey, LNonce, LAAD, LPlain, LCipher, LTag);
    CheckTrue(LOk);
    CheckEqual(
      '121e57c70764edb8350c469d32972fa816e7cedd733ee66786616b4021f82dc0' +
      'd1bd459b306097f3cab57c0cee60ca2c84ce0307b1663a1f12dba4d94e885b53' +
      '91b3fcc7c1450862c74cd1eee6a5fd47c71c2f91af2439a2e976e39a80b3c004' +
      'eb88660f753ecf8ae34b4c12e20e157b3ed0735645177b375a06732813a4e67f' +
      'a748f8a53bd1c54326614b420c4bd06b3889966bbd01d1eda0b68bc978dda5a9' +
      'c57e807dfe78638a240ba343e82723053874a5da41a6fa5a5290a2ec9a7e43cf' +
      '54c391c8ea3ac14ae6e1d241780af9148c3f2dd8de407120d171b23f7e00789b' +
      'b79b72e503f82b25fdb0b9d92d9180fbb74c6c532610518b8b0d47598901ae0c' +
      'f41f0f053934c21ce5b2115d790160eb860486100dc4912c2c278af1f1a8ff65' +
      'c0944ab3230f57a4039844df1f005fd24ecef75294a6eee765a46bc6ebb58c16' +
      '0273408a253221bdfc72b02ab2455ec21314e6fc5b0d6567cf5d9eb73b626103' +
      '18a5673760c221dbca8e894d5e136d80a518d6d021a90828b8e0d3aee34cd65e' +
      'e226e51c7d2c6e7453d1332fa8cef2c866595a0e90204fcaa9d00893a05d99bd' +
      '1bae11aad7d6c4ab7abcb9e6df90226ef8c50d5b88ab24da6ef439ece2a3a350' +
      '7346343fd3539a41e8f01e3151d532acb75d3e1ef57da3d2b653bc1155d90fe8' +
      'd19b5a8dce4dbbb15bcbb62cbfcad7e3449fa22eb84214106375985d1db4d3f5' +
      '21e78909182be0fde6dfc8a0a0e9be9e67c5e640c34bee325b5108d44038c9fb' +
      '20a69401c6cb89c0fea83758f72d86a13f37de8c0eb39d8aa04b6c6a15b1bd4c' +
      '16225aacb0f4f8aefcbd5e9f188c09a7cf502904e6932bb9'
      , BytesToHex(LCipher));
    CheckEqual('ace6c124cca36b791af4e814646bac26', BytesToHex(LTag));
    LOk := TryChaCha20Poly1305Decrypt(LKey, LNonce, LAAD, LCipher, LTag, LPlain);
    CheckTrue(LOk);

  end);

  LRunner := TSuiteRunner.Create('nextpas.core.crypto.chacha20poly1305');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
