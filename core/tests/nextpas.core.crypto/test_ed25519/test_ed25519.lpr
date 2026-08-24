program test_ed25519;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.system.sysutils,
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

  LRunner := TSuiteRunner.Create('nextpas.core.crypto.ed25519');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
