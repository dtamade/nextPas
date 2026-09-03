program test_ed25519;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.crypto.ed25519,
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
  LSuite := TTestSuite.Create('ed25519');

  LSuite.Test('RFC 8032 vector1 empty msg', procedure
  var LPriv, LPub, LMsg, LSig: TBytes; LOk: Boolean;
  begin
    LPriv := HexToBytes('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60');
    LPub := Ed25519PublicKeyFromPrivate(LPriv);
    CheckEqual('d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a', BytesToHex(LPub));
    SetLength(LMsg, 0);
    LOk := Ed25519Sign(LPriv, LMsg, LSig);
    CheckTrue(LOk);
    CheckEqual('e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b',
      BytesToHex(LSig));
    CheckTrue(Ed25519Verify(LPub, LMsg, LSig));
  end);

  LSuite.Test('RFC 8032 vector2 one byte', procedure
  var LPriv, LPub, LMsg, LSig: TBytes; LOk: Boolean;
  begin
    LPriv := HexToBytes('4ccd089b28ff96da9db6c346ec114e0f5b8a319f35aba624da8cf6ed4fb8a6fb');
    LPub := Ed25519PublicKeyFromPrivate(LPriv);
    CheckEqual('3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c', BytesToHex(LPub));
    LMsg := HexToBytes('72');
    LOk := Ed25519Sign(LPriv, LMsg, LSig);
    CheckTrue(LOk);
    CheckEqual('92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00',
      BytesToHex(LSig));
    CheckTrue(Ed25519Verify(LPub, LMsg, LSig));
  end);

  LSuite.Test('RFC 8032 vector3 two bytes', procedure
  var LPriv, LPub, LMsg, LSig: TBytes; LOk: Boolean;
  begin
    LPriv := HexToBytes('c5aa8df43f9f837bedb7442f31dcb7b166d38535076f094b85ce3a2e0b4458f7');
    LPub := Ed25519PublicKeyFromPrivate(LPriv);
    CheckEqual('fc51cd8e6218a1a38da47ed00230f0580816ed13ba3303ac5deb911548908025', BytesToHex(LPub));
    LMsg := HexToBytes('af82');
    LOk := Ed25519Sign(LPriv, LMsg, LSig);
    CheckTrue(LOk);
    CheckEqual('6291d657deec24024827e69c3abe01a30ce548a284743a445e3680d7db5ac3ac18ff9b538d16f290ae67f760984dc6594a7c15e9716ed28dc027beceea1ec40a',
      BytesToHex(LSig));
    CheckTrue(Ed25519Verify(LPub, LMsg, LSig));
  end);

  LSuite.Test('tampered signature rejected', procedure
  var LPriv, LPub, LMsg, LSig: TBytes;
  begin
    LPriv := HexToBytes('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60');
    LPub := Ed25519PublicKeyFromPrivate(LPriv);
    SetLength(LMsg, 0);
    Ed25519Sign(LPriv, LMsg, LSig);
    LSig[0] := LSig[0] xor $FF;
    CheckTrue(not Ed25519Verify(LPub, LMsg, LSig));
  end);

  { 回归：ScMulAdd 进位链曾在罕见进位条件下丢失高位进位，
    导致约 1/400 的签名非法（首个已知失败：83 字节交替填充消息）。
    扫描跨 SHA-512 边界的多种长度/填充组合，签验必须全部自洽。 }
  LSuite.Test('sign/verify roundtrip across message lengths', procedure
  var
    LSeed1, LSeed2, LPub1, LPub2, LMsg, LSig: TBytes;
    I, J: Integer;
  begin
    SetLength(LSeed1, 32);
    SetLength(LSeed2, 32);
    for J := 0 to 31 do
    begin
      LSeed1[J] := $3D;
      LSeed2[J] := Byte((J * 11 + 7) and $FF);
    end;
    LPub1 := Ed25519PublicKeyFromPrivate(LSeed1);
    LPub2 := Ed25519PublicKeyFromPrivate(LSeed2);
    for I := 0 to 320 do
    begin
      SetLength(LMsg, I);
      for J := 0 to I - 1 do
        if J mod 2 = 0 then
          LMsg[J] := $11
        else
          LMsg[J] := Byte((J * 7 + I) and $FF);
      CheckTrue(Ed25519Sign(LSeed1, LMsg, LSig));
      if not Ed25519Verify(LPub1, LMsg, LSig) then
      begin
        CheckTrue(False, 'roundtrip seed1 len=' + IntToStr(I));
        Exit;
      end;
    end;
    { 第二把密钥，$FF 填充（全 0xFF 内容曾触发另一类进位路径） }
    for I := 0 to 200 do
    begin
      SetLength(LMsg, I);
      for J := 0 to I - 1 do
        LMsg[J] := $FF;
      CheckTrue(Ed25519Sign(LSeed2, LMsg, LSig));
      if not Ed25519Verify(LPub2, LMsg, LSig) then
      begin
        CheckTrue(False, 'roundtrip seed2 len=' + IntToStr(I));
        Exit;
      end;
    end;
  end);

  { 回归：EdBasePointMul 有符号 radix-16 转换曾在末位数字回卷时丢弃最终
    进位，代表值整体偏移 -2^256，公钥错误（约 7% 的密钥触发：
    SHA-512(seed) 末字节高 nibble=7 且低 nibble≥8）。已知真实触发：
    dtamade@888933.xyz 的 id_ed25519。期望值取自 cryptography 参考实现。 }
  LSuite.Test('pubkey derivation survives top-digit carry chain', procedure
  const
    N = 8;
    SEEDS: array[0..N-1] of string = (
      { 触发组：byte31 高 nibble=7、低 nibble>=8，进位链到达 digit63 }
      '0900000000000000000000000000000000000000000000000000000000000000',
      '2000000000000000000000000000000000000000000000000000000000000000',
      '5600000000000000000000000000000000000000000000000000000000000000',
      '9300000000000000000000000000000000000000000000000000000000000000',
      { 对照组：无进位链 }
      '0200000000000000000000000000000000000000000000000000000000000000',
      '0400000000000000000000000000000000000000000000000000000000000000',
      { 真实密钥：ck（不触发）与 id_ed25519（触发）}
      'aa4d12f0cf8abc9933330727f4f30d0b0e140a99705c08196f4f18493494724b',
      '03aa02244f41c075ba8640f3511e017f5beb030099daf8443cb05dc8b9a71adc');
    PUBS: array[0..N-1] of string = (
      'bb5c672482b0dcca91a21a4ed63b15afde8aa1378da72cd01b349589d6e7dd6a',
      '3be533822b146a67b7649397f6fdcde0451233eda282997fe31c4dcc0a9b09fb',
      '9fd8db3ce25c826c641e96ef8b2e55337554fb55f5010a43e35a6b9911e06ec4',
      'bb36d43533bce51370a4fb31e6249df97f09632a7a722ed2c3d50f175bdaf96c',
      '6b79c57e6a095239282c04818e96112f3f03a4001ba97a564c23852a3f1ea5fc',
      '9be3287795907809407e14439ff198d5bfc7dce6f9bc743cb369146f610b4801',
      '8fef14f0f51ad231a3e3051d313f14b47e7bfe6b163f15a8b58ccd7d555efc8f',
      'ce083fc96321124b358be7c3b796dc85be82a552946b1ba79b6405e42c2ca6b1');
  var
    I: Integer;
  begin
    for I := 0 to N - 1 do
      CheckEqual(PUBS[I], BytesToHex(Ed25519PublicKeyFromPrivate(HexToBytes(SEEDS[I]))));
  end);

  LSuite.Test('signature vector on trigger seed (top-digit carry)', procedure
  var
    LSeed, LPub, LMsg, LSig: TBytes; LOk: Boolean;
  begin
    LSeed := HexToBytes('0900000000000000000000000000000000000000000000000000000000000000');
    LPub := Ed25519PublicKeyFromPrivate(LSeed);
    LMsg := HexToBytes('000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f');
    LOk := Ed25519Sign(LSeed, LMsg, LSig);
    CheckTrue(LOk);
    CheckEqual('c0ef54f1b72f0f6131a38ee931647e8ce50def6272ba1b7d975362ba2c225f43e658b054191cc486b127ca27f1cda8417ae8c1c20833b923986f0a5d2c01af06',
      BytesToHex(LSig));
    CheckTrue(Ed25519Verify(LPub, LMsg, LSig));
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.crypto.ed25519');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
