program bench_quic;

{**
 * Q1（RFC 9001 适配层 + QUIC varint）性能基准。
 *
 * 覆盖：varint 编/解码（1B/2B/8B 形态）、initial secrets 派生
 * （HKDF-Extract + 双 Expand-Label）、key/iv/hp 三元组派生、
 * header protection AES 掩码。
 *
 * 关联场景：每条 QUIC 连接握手需 1 次 initial secrets 派生 +
 * 每 packet 需要 HP 掩码；数字回填 proxy888 wiki/quic-roadmap.md
 * 「Q1 落地实测」节。
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.time.base,
  nextpas.core.text.conv,
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.net.quic.varint,
  nextpas.core.net.quic.tls;

const
  cValue1B: UInt64 = 25;
  cValue2B: UInt64 = 15293;
  cValue8B: UInt64 = UInt64($02197C5EFF14D889);

var
  { 预构造的固定输入（基准循环外一次性建好） }
  GWire1B: TBytes;
  GWire2B: TBytes;
  GWire8B: TBytes;
  GDcid: TBytes;
  GSecret: TBytes;
  GHpKey: TBytes;
  GSample: TBytes;
  GOutBuf: TBytes;      { encode 追加目标（每次清尾） }
  GOutVal: UInt64;
  GOutConsumed: Integer;
  GSecs: TQuicInitialSecrets;
  GKs: TQuicKeySet;
  GMask: TBytes;
  GPrep: TQuicHpAesPrepared;

procedure BenchVarintEncode1B(const ACtx: IBenchContext);
begin
  SetLength(GOutBuf, 0);
  QuicVarintAppend(GOutBuf, cValue1B);
end;

procedure BenchVarintEncode2B(const ACtx: IBenchContext);
begin
  SetLength(GOutBuf, 0);
  QuicVarintAppend(GOutBuf, cValue2B);
end;

procedure BenchVarintEncode8B(const ACtx: IBenchContext);
begin
  SetLength(GOutBuf, 0);
  QuicVarintAppend(GOutBuf, cValue8B);
end;

procedure BenchVarintDecode8B(const ACtx: IBenchContext);
begin
  QuicVarintDecode(GWire8B, 0, GOutVal, GOutConsumed);
end;

procedure BenchDeriveInitialSecrets(const ACtx: IBenchContext);
begin
  GSecs := DeriveQuicInitialSecrets(GDcid);
end;

procedure BenchDeriveKeySet(const ACtx: IBenchContext);
begin
  GKs := DeriveQuicKeySet(GSecret);
end;

procedure BenchHpMaskAes(const ACtx: IBenchContext);
begin
  GMask := QuicHeaderProtectionMaskAES(GHpKey, GSample);
end;

procedure BenchHpMaskAesPrepared(const ACtx: IBenchContext);
begin
  GMask := QuicHeaderProtectionMaskAESPrepared(GPrep, GSample);
end;

function FindNsPerOp(const AAll: TBenchResultArray;
  const AName: string): Double;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Length(AAll) - 1 do
    if AAll[I].Name = AName then
      Exit(AAll[I].NsPerOp);
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  LAll: TBenchResultArray;
  LN, LI: Integer;
  LRow: array[0..7] of Double;
  LNames: array[0..7] of string;
begin
  WriteLn('QUIC Q1 Primitives Benchmark (nextpas.core.net.quic.*)');
  WriteLn('======================================================');
  WriteLn;

  GWire1B := QuicVarintEncode(cValue1B);
  GWire2B := QuicVarintEncode(cValue2B);
  GWire8B := QuicVarintEncode(cValue8B);
  SetLength(GDcid, 32);
  for LI := 0 to 31 do
    GDcid[LI] := Byte(LI);   { 固定 32B DCID（握手典型形态） }
  GSecs := DeriveQuicInitialSecrets(GDcid);
  GSecret := GSecs.ClientSecret;
  GPrep := QuicHpPrepareAES(GHpKey);
  SetLength(GHpKey, 16);
  for LI := 0 to 15 do
    GHpKey[LI] := Byte(LI);
  SetLength(GSample, 16);
  for LI := 0 to 15 do
    GSample[LI] := Byte(LI);

  LSuite := TBenchSuite.Create('quic_q1')
    .SetMinDuration(TDuration.FromMilliseconds(300))
    .SetMaxIterations(200000)
    .SetMinSamples(10)
    .SetWarmupIters(1000);

  LSuite
    .Add('varint/encode_1b', @BenchVarintEncode1B)
    .Add('varint/encode_2b', @BenchVarintEncode2B)
    .Add('varint/encode_8b', @BenchVarintEncode8B)
    .Add('varint/decode_8b', @BenchVarintDecode8B)
    .Add('tls/derive_initial_secrets', @BenchDeriveInitialSecrets)
    .Add('tls/derive_keyset', @BenchDeriveKeySet)
    .Add('tls/hp_mask_aes', @BenchHpMaskAes)
    .Add('tls/hp_mask_aes_prepared', @BenchHpMaskAesPrepared);

  LResults := LSuite.Run;
  LAll := LResults.GetAll;

  LNames[0] := 'varint/encode_1b';
  LNames[1] := 'varint/encode_2b';
  LNames[2] := 'varint/encode_8b';
  LNames[3] := 'varint/decode_8b';
  LNames[4] := 'tls/derive_initial_secrets';
  LNames[5] := 'tls/derive_keyset';
  LNames[6] := 'tls/hp_mask_aes';
  LNames[7] := 'tls/hp_mask_aes_prepared';

  WriteLn('  Benchmark                    ns/op       ops/s');
  WriteLn('  ---------------------------------------------------');
  for LI := 0 to 7 do
  begin
    LRow[LI] := FindNsPerOp(LAll, LNames[LI]);
    if LRow[LI] > 0 then
      LN := Round(1e9 / LRow[LI])
    else
      LN := 0;
    while Length(LNames[LI]) < 29 do
      LNames[LI] := LNames[LI] + ' ';
    WriteLn('  ', LNames[LI], FormatFloat('0.0', LRow[LI]),
      TextOfChar(' ', 12 - Length(FormatFloat('0.0', LRow[LI]))), LN);
  end;
  WriteLn;
  if LRow[4] > 0 then
    WriteLn('  握手吞吐参考：单核 initial secrets 派生 ',
      Round(1e9 / LRow[4]), ' 次/s（每连接 1 次）');
  if LRow[6] > 0 then
    WriteLn('  包保护参考：单核 HP mask ', Round(1e9 / LRow[6]),
      ' 次/s（每短包头 1 次）');
end.
