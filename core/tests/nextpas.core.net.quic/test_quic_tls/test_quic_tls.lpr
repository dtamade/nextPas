program test_quic_tls;

{ QUIC-TLS 适配层（RFC 9001 §5）单元测试：
  附录 A.1 固定向量逐字节比对（initial secrets / 双方向 key-iv-hp）
  + HP mask oracle 对拍（python cryptography AES-ECB 独立计算：
  mask(client_hp,sample000102..)=64017422…、mask(client_hp,0^16)=3c84e0ab…）。
  常量基线 = RFC v1 盐 38762cf7f55934b34d179ae6a4c80cadccbb7f0a
  （一手 RFC 原文定案；python cryptography 独立重算全链一致）。
  仅依赖 nextPas/core（无 system 垫片）。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.fs.path,
  nextpas.core.fs.util,
  nextpas.core.net.quic.tls,
  nextpas.core.test;

{$I ../../fpc_rtl_uses_scan.inc}

const
  cHexDigits: array[0..15] of Char = '0123456789abcdef';

  { RFC 9001 A.1：DCID = 8394c8f03e515708（v1 盐派生） }
  cDcidHex = '8394c8f03e515708';
  cClientSecretHex = 'c00cf151ca5be075ed0ebfb5c80323c42d6b7db67881289af4008f1f6c357aea';
  cServerSecretHex = '3c199828fd139efd216c155ad844cc81fb82fa8d7446fa7d78be803acdda951b';
  cClientKeyHex = '1f369613dd76d5467730efcbe3b1a22d';
  cClientIvHex = 'fa044b2f42a3fd3b46fb255c';
  cClientHpHex = '9f50449e04a0e810283a1e9933adedd2';
  cServerKeyHex = 'cf3a5331653c364c88f0f379b6067e37';
  cServerIvHex = '0ac1493ca1905853b0bba03e';
  cServerHpHex = 'c206b8d9b9f0f37644430b490eeaa314';

function HexNibbleVal(C: Char): Byte;
begin
  case C of
    '0'..'9': Result := Ord(C) - Ord('0');
    'a'..'f': Result := Ord(C) - Ord('a') + 10;
    'A'..'F': Result := Ord(C) - Ord('A') + 10;
  else
    Result := 0;
  end;
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to Length(Result) - 1 do
    Result[I] := (HexNibbleVal(AHex[I * 2 + 1]) shl 4) or HexNibbleVal(AHex[I * 2 + 2]);
end;

function BytesToHex(const AData: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Length(AData) - 1 do
  begin
    Result := Result + cHexDigits[AData[I] shr 4];
    Result := Result + cHexDigits[AData[I] and $0F];
  end;
end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('quic_tls');

  LSuite.Test('A.1 initial secrets byte-exact', procedure
  var
    LSec: TQuicInitialSecrets;
  begin
    LSec := DeriveQuicInitialSecrets(HexToBytes(cDcidHex));
    CheckEqual(32, Length(LSec.ClientSecret));
    CheckEqual(32, Length(LSec.ServerSecret));
    CheckEqual(cClientSecretHex, BytesToHex(LSec.ClientSecret));
    CheckEqual(cServerSecretHex, BytesToHex(LSec.ServerSecret));
  end);

  LSuite.Test('A.1 client key/iv/hp byte-exact', procedure
  var
    LKs: TQuicKeySet;
  begin
    LKs := DeriveQuicKeySet(HexToBytes(cClientSecretHex));
    CheckEqual(16, Length(LKs.Key));
    CheckEqual(12, Length(LKs.Iv));
    CheckEqual(16, Length(LKs.Hp));
    CheckEqual(cClientKeyHex, BytesToHex(LKs.Key));
    CheckEqual(cClientIvHex, BytesToHex(LKs.Iv));
    CheckEqual(cClientHpHex, BytesToHex(LKs.Hp));
  end);

  LSuite.Test('A.1 server key/iv/hp byte-exact', procedure
  var
    LKs: TQuicKeySet;
  begin
    LKs := DeriveQuicKeySet(HexToBytes(cServerSecretHex));
    CheckEqual(cServerKeyHex, BytesToHex(LKs.Key));
    CheckEqual(cServerIvHex, BytesToHex(LKs.Iv));
    CheckEqual(cServerHpHex, BytesToHex(LKs.Hp));
  end);

  LSuite.Test('salt constant is RFC v1 salt', procedure
  var
    LSalt: TBytes;
    LI: Integer;
  begin
    SetLength(LSalt, Length(cQuicV1Salt));
    for LI := 0 to High(cQuicV1Salt) do
      LSalt[LI] := cQuicV1Salt[LI];
    CheckEqual('38762cf7f55934b34d179ae6a4c80cadccbb7f0a', BytesToHex(LSalt));
  end);

  { HP mask oracle：python cryptography AES-ECB 独立计算值 }
  LSuite.Test('hp mask AES oracle vectors', procedure
  var
    LMask: TBytes;
  begin
    LMask := QuicHeaderProtectionMaskAES(HexToBytes(cClientHpHex),
      HexToBytes('000102030405060708090a0b0c0d0e0f'));
    CheckEqual('640174229de556fd4dd99e709f66a13e', BytesToHex(LMask));

    LMask := QuicHeaderProtectionMaskAES(HexToBytes(cClientHpHex),
      HexToBytes('00000000000000000000000000000000'));
    CheckEqual('3c84e0abe1ade2049cf3770c8eefd2f4', BytesToHex(LMask));

    { server hp key 换钥自洽：同样本不同钥必不同掩码 }
    LMask := QuicHeaderProtectionMaskAES(HexToBytes(cServerHpHex),
      HexToBytes('000102030405060708090a0b0c0d0e0f'));
    CheckNotEqual('640174229de556fd4dd99e709f66a13e', BytesToHex(LMask));
    CheckEqual(16, Length(LMask));
  end);

  LSuite.Test('hp mask rejects wrong lengths', procedure
  var
    LOut: TBytes;
  begin
    LOut := QuicHeaderProtectionMaskAES(HexToBytes('cb2a4b6fe006bc6e649244f5cea4ec'),
      HexToBytes('000102030405060708090a0b0c0d0e0f'));   { 钥 15B }
    CheckEqual(0, Length(LOut));
    LOut := QuicHeaderProtectionMaskAES(HexToBytes(cClientHpHex),
      HexToBytes('000102030405060708090a0b0c0d0e0fff'));  { 样本 17B }
    CheckEqual(0, Length(LOut));
    LOut := QuicHeaderProtectionMaskAES(nil, nil);
    CheckEqual(0, Length(LOut));
  end);

  { 端到端链路自检：DCID -> secret -> keyset 再派生确定性（两次调用同结果） }
  LSuite.Test('derivation deterministic across calls', procedure
  var
    LA, LB: TQuicInitialSecrets;
    LKa, LKb: TQuicKeySet;
  begin
    LA := DeriveQuicInitialSecrets(HexToBytes(cDcidHex));
    LB := DeriveQuicInitialSecrets(HexToBytes(cDcidHex));
    CheckEqual(BytesToHex(LA.ClientSecret), BytesToHex(LB.ClientSecret));
    LKa := DeriveQuicKeySet(LA.ClientSecret);
    LKb := DeriveQuicKeySet(LB.ClientSecret);
    CheckEqual(BytesToHex(LKa.Key), BytesToHex(LKb.Key));
  end);

  { 预扩展热路径：与一次性形态同结果；未准备态（Nr=0）拒出 }
  LSuite.Test('hp mask prepared form equals one-shot', procedure
  var
    LPrep: TQuicHpAesPrepared;
    LOneShot, LPreparedMask: TBytes;
  begin
    LPrep := QuicHpPrepareAES(HexToBytes(cClientHpHex));
    CheckTrue(LPrep.Nr > 0);
    LOneShot := QuicHeaderProtectionMaskAES(HexToBytes(cClientHpHex),
      HexToBytes('000102030405060708090a0b0c0d0e0f'));
    LPreparedMask := QuicHeaderProtectionMaskAESPrepared(LPrep,
      HexToBytes('000102030405060708090a0b0c0d0e0f'));
    CheckEqual(BytesToHex(LOneShot), BytesToHex(LPreparedMask));

    LPrep := QuicHpPrepareAES(HexToBytes('cb'));   { 非 16B 钥 }
    CheckEqual(0, LPrep.Nr);
    LPreparedMask := QuicHeaderProtectionMaskAESPrepared(LPrep,
      HexToBytes('000102030405060708090a0b0c0d0e0f'));
    CheckEqual(0, Length(LPreparedMask));
  end);

  { 源码契约：本单元不得裸 uses FPC RTL }
  LSuite.Test('source contract: no bare FPC RTL', procedure
  var
    LSrcPath, LHit: string;
  begin
    LSrcPath := FsPathAbs(FsPathJoin([FsPathDir(ParamStr(0)),
      '..', '..', '..', '..',
      'src', 'nextpas.core.net.quic.tls.pas']));
    Check(not FindBareFpcRtlInUses(FsReadFileText(LSrcPath), LHit),
      'no bare FPC RTL in uses (hit: ' + LHit + ')');
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.net.quic.tls');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
