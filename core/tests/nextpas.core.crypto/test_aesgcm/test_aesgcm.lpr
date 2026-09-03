program test_aesgcm;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.crypto.aesgcm,
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
  LSuite := TTestSuite.Create('aesgcm');

  LSuite.Test('NIST TC3 encrypt/decrypt', procedure
  var LKey, LIV, LPlain, LAAD, LCipher, LTag, LDecrypted: TBytes; LOk: Boolean;
  begin
    LKey := HexToBytes('feffe9928665731c6d6a8f9467308308');
    LIV := HexToBytes('cafebabefacedbaddecaf888');
    LPlain := HexToBytes('d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a721c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b391aafd255');
    LAAD := HexToBytes('');
    LOk := PurePascalAESGCMEncrypt(LKey, LIV, LPlain, LAAD, LCipher, LTag);
    CheckTrue(LOk);
    CheckEqual('42831ec2217774244b7221b784d0d49ce3aa212f2c02a4e035c17e2329aca12e21d514b25466931c7d8f6a5aac84aa051ba30b396a0aac973d58e091473f5985',
      BytesToHex(LCipher));
    CheckEqual('4d5c2af327cd64a62cf35abd2ba6fab4', BytesToHex(LTag));
    LOk := PurePascalAESGCMDecrypt(LKey, LIV, LCipher, LTag, LAAD, LDecrypted);
    CheckTrue(LOk);
    CheckEqual(BytesToHex(LPlain), BytesToHex(LDecrypted));
  end);

  LSuite.Test('NIST TC4 with AAD', procedure
  var LKey, LIV, LPlain, LAAD, LCipher, LTag, LDecrypted: TBytes; LOk: Boolean;
  begin
    LKey := HexToBytes('feffe9928665731c6d6a8f9467308308');
    LIV := HexToBytes('cafebabefacedbaddecaf888');
    LPlain := HexToBytes('d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a721c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b39');
    LAAD := HexToBytes('feedfacedeadbeeffeedfacedeadbeefabaddad2');
    LOk := PurePascalAESGCMEncrypt(LKey, LIV, LPlain, LAAD, LCipher, LTag);
    CheckTrue(LOk);
    CheckEqual('42831ec2217774244b7221b784d0d49ce3aa212f2c02a4e035c17e2329aca12e21d514b25466931c7d8f6a5aac84aa051ba30b396a0aac973d58e091',
      BytesToHex(LCipher));
    CheckEqual('5bc94fbc3221a5db94fae95ae7121a47', BytesToHex(LTag));
    LOk := PurePascalAESGCMDecrypt(LKey, LIV, LCipher, LTag, LAAD, LDecrypted);
    CheckTrue(LOk);
    CheckEqual(BytesToHex(LPlain), BytesToHex(LDecrypted));
  end);

  LSuite.Test('NIST TC1 empty plaintext', procedure
  var LKey, LIV, LPlain, LAAD, LCipher, LTag: TBytes; LOk: Boolean;
  begin
    LKey := HexToBytes('00000000000000000000000000000000');
    LIV := HexToBytes('000000000000000000000000');
    LPlain := HexToBytes(''); LAAD := HexToBytes('');
    LOk := PurePascalAESGCMEncrypt(LKey, LIV, LPlain, LAAD, LCipher, LTag);
    CheckTrue(LOk);
    CheckEqual(0, Length(LCipher));
    CheckEqual('58e2fccefa7e3061367f1d57a4e7455a', BytesToHex(LTag));
  end);

  { 聚合 GHASH 路径（≥8 块走 GHASHUpdatePCLMULAgg）回归：曾因组间
    累加器折返缺失 + A₀ 折入路次错误导致 tag 全错、TLS 握手 AEAD
    解密整体失败（NIST 短向量 ≤4 块覆盖不到）。参考值由 Python
    cryptography AESGCM 生成。 }
  LSuite.Test('agg path 128B (2 groups) external vector', procedure
  var LKey, LIV, LPlain, LAAD, LCipher, LTag, LDecrypted: TBytes; LOk: Boolean;
  begin
    LKey := HexToBytes('000102030405060708090a0b0c0d0e0f');
    LIV := HexToBytes('000102030405060708090a0b');
    LPlain := HexToBytes('00070e151c232a31383f464d545b626970777e858c939aa1a8afb6bdc4cbd2d9e0e7eef5fc030a11181f262d343b424950575e656c737a81888f969da4abb2b9c0c7ced5dce3eaf1f8ff060d141b222930373e454c535a61686f767d848b9299a0a7aeb5bcc3cad1d8dfe6edf4fb020910171e252c333a41484f565d646b7279');
    LAAD := HexToBytes('000005fa');
    LOk := PurePascalAESGCMEncrypt(LKey, LIV, LPlain, LAAD, LCipher, LTag);
    CheckTrue(LOk);
    CheckEqual('5af1b7a95577faf8735b26f9b2d5379a', BytesToHex(LTag));
    LOk := PurePascalAESGCMDecrypt(LKey, LIV, LCipher, LTag, LAAD, LDecrypted);
    CheckTrue(LOk);
    CheckEqual(BytesToHex(LPlain), BytesToHex(LDecrypted));
  end);

  LSuite.Test('agg path 256B (4 groups) external vector', procedure
  var LKey, LIV, LPlain, LAAD, LCipher, LTag, LDecrypted: TBytes; LOk: Boolean;
  begin
    LKey := HexToBytes('000102030405060708090a0b0c0d0e0f');
    LIV := HexToBytes('000102030405060708090a0b');
    LPlain := HexToBytes('00070e151c232a31383f464d545b626970777e858c939aa1a8afb6bdc4cbd2d9e0e7eef5fc030a11181f262d343b424950575e656c737a81888f969da4abb2b9c0c7ced5dce3eaf1f8ff060d141b222930373e454c535a61686f767d848b9299a0a7aeb5bcc3cad1d8dfe6edf4fb020910171e252c333a41484f565d646b727980878e959ca3aab1b8bfc6cdd4dbe2e9f0f7fe050c131a21282f363d444b525960676e757c838a91989fa6adb4bbc2c9d0d7dee5ecf3fa01080f161d242b323940474e555c636a71787f868d949ba2a9b0b7bec5ccd3dae1e8eff6fd040b121920272e353c434a51585f666d747b828990979ea5acb3bac1c8cfd6dde4ebf2f9');
    LAAD := HexToBytes('000005fa');
    LOk := PurePascalAESGCMEncrypt(LKey, LIV, LPlain, LAAD, LCipher, LTag);
    CheckTrue(LOk);
    CheckEqual('e700078b668c91310499a3d1c857bfff', BytesToHex(LTag));
    LOk := PurePascalAESGCMDecrypt(LKey, LIV, LCipher, LTag, LAAD, LDecrypted);
    CheckTrue(LOk);
    CheckEqual(BytesToHex(LPlain), BytesToHex(LDecrypted));
  end);

  LSuite.Test('tampered tag rejected', procedure
  var LKey, LIV, LPlain, LAAD, LCipher, LTag, LBadTag, LDecrypted: TBytes; LOk: Boolean;
  begin
    LKey := HexToBytes('feffe9928665731c6d6a8f9467308308');
    LIV := HexToBytes('cafebabefacedbaddecaf888');
    LPlain := HexToBytes('d9313225f88406e5a55909c5aff5269a');
    LAAD := HexToBytes('');
    PurePascalAESGCMEncrypt(LKey, LIV, LPlain, LAAD, LCipher, LTag);
    LBadTag := Copy(LTag);
    LBadTag[0] := LBadTag[0] xor $FF;
    LOk := PurePascalAESGCMDecrypt(LKey, LIV, LCipher, LBadTag, LAAD, LDecrypted);
    CheckTrue(not LOk);
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.crypto.aesgcm');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
