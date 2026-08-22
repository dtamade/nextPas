program test_quic_tls;

{ QUIC-TLS 适配层（RFC 9001 §5）单元测试：
  附录 A.2 固定向量逐字节比对（initial secrets / 双方向 key-iv-hp）
  + HP mask 双 oracle 交叉核对（python cryptography 与 OpenSSL CLI
  独立计算一致：mask(hp,sample)=f075deae…、mask(hp,0^16)=d5249fc6…）。
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

  { RFC 9001 A.2：DCID = 8394c8f03e515708 }
  cDcidHex = '8394c8f03e515708';
  cClientSecretHex = 'c66ca1135e6bac2a9b747cd5d298318b5b8cbb585e7c839ffa5e9c734ac18e9e';
  cServerSecretHex = 'a517049a0ae777c6071751a320f427d47aca55f856618786ca9eebddde05a562';
  cClientKeyHex = '0c93ed1de834789f80d8ee32bdd011fb';
  cClientIvHex = '1829c4a9b9256610bb62ec60';
  cClientHpHex = 'cb2a4b6fe006bc6e649244f5cea4ecf3';
  cServerKeyHex = '8b569d5cffbe121301ff332b70e73bd7';
  cServerIvHex = '5e11d756c2ad65912b44a471';
  cServerHpHex = '176d365a889837d4731101d386284323';

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

  LSuite.Test('A.2 initial secrets byte-exact', procedure
  var
    LSec: TQuicInitialSecrets;
  begin
    LSec := DeriveQuicInitialSecrets(HexToBytes(cDcidHex));
    CheckEqual(32, Length(LSec.ClientSecret));
    CheckEqual(32, Length(LSec.ServerSecret));
    CheckEqual(cClientSecretHex, BytesToHex(LSec.ClientSecret));
    CheckEqual(cServerSecretHex, BytesToHex(LSec.ServerSecret));
  end);

  LSuite.Test('A.2 client key/iv/hp byte-exact', procedure
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

  LSuite.Test('A.2 server key/iv/hp byte-exact', procedure
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
    CheckEqual('38762cf7ab8a8aa4beaccae63eaf0dc2d476d3de', BytesToHex(LSalt));
  end);

  { HP mask oracle：双 oracle（python cryptography + OpenSSL CLI）一致值 }
  LSuite.Test('hp mask AES oracle vectors', procedure
  var
    LMask: TBytes;
  begin
    LMask := QuicHeaderProtectionMaskAES(HexToBytes(cClientHpHex),
      HexToBytes('000102030405060708090a0b0c0d0e0f'));
    CheckEqual('f075deae102815889b0969722233689e', BytesToHex(LMask));

    LMask := QuicHeaderProtectionMaskAES(HexToBytes(cClientHpHex),
      HexToBytes('00000000000000000000000000000000'));
    CheckEqual('d5249fc60b63d3d085007588de4ef133', BytesToHex(LMask));

    { server hp key 换钥自洽：同样本不同钥必不同掩码 }
    LMask := QuicHeaderProtectionMaskAES(HexToBytes(cServerHpHex),
      HexToBytes('000102030405060708090a0b0c0d0e0f'));
    CheckNotEqual('f075deae102815889b0969722233689e', BytesToHex(LMask));
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
