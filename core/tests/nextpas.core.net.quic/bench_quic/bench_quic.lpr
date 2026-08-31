program bench_quic;

{**
 * Q1/Q2（RFC 9001 适配层 + QUIC varint + 包保护）性能基准。
 *
 * 覆盖：varint 编/解码（1B/2B/8B 形态）、initial secrets 派生
 * （HKDF-Extract + 双 Expand-Label）、key/iv/hp 三元组派生、
 * header protection 掩码（AES 一次性/预扩展、ChaCha20）、
 * 整包保护/去保护（AES-GCM 与 ChaCha20-Poly1305 双套件，1200B 包）。
 *
 * 关联场景：每条 QUIC 连接握手需 1 次 initial secrets 派生 +
 * 每 packet 需要 HP 掩码与 AEAD 加解密；数字回填 proxy888
 * wiki/quic-roadmap.md「Q1 落地实测」节。
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
  nextpas.core.net.quic.pn,
  nextpas.core.net.quic.header,
  nextpas.core.net.quic.tls,
  nextpas.core.net.quic.protect,
  nextpas.core.net.quic.frame,
  nextpas.core.net.quic.reliable;

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
  { Q2 包保护固定输入（A.2 Client Initial 形态，1200B 包） }
  GPktDcid: TBytes;         { 包头用 8B DCID }
  GChaChaHp: TBytes;
  GAesKeys: TQuicPacketKeys;
  GChaChaKeys: TQuicPacketKeys;
  GClearHdr: TBytes;        { 明文头前缀（pnlen=4，Length=1182） }
  GPayload: TBytes;         { 1162B 帧载荷 }
  GProtAes: TBytes;         { 已保护整包（unprotect 输入） }
  GProtChacha: TBytes;
  GOutPkt: TBytes;
  GOutPay: TBytes;
  GOutPn: UInt64;
  { Q3 帧 + 可靠骨架固定输入 }
  GCryptoWire: TBytes;      { 已编码的 1200B CRYPTO 帧（解析输入） }
  GAckRanges: TQuicAckRangeArray;   { 8 段降序 ranges（ACK 编码输入） }
  GAckWire: TBytes;         { 已编码 ACK 帧 }
  GTracker: TQuicSentTracker;       { 512 在途包（结算输入） }
  GTSettleRanges: TQuicAckRangeArray;
  GEst: TQuicRttEstimator;
  GLost: TQuicPnArray;
  GLostBytes: Integer;

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

procedure BenchHpMaskChacha(const ACtx: IBenchContext);
begin
  GMask := QuicHeaderProtectionMaskForSuite(GChaChaHp, GSample,
    qcsChaCha20Poly1305Sha256);
end;

procedure BenchProtectAes(const ACtx: IBenchContext);
begin
  GOutPkt := QuicProtectPacket(GClearHdr, 2, 4, GPayload, GAesKeys);
end;

procedure BenchUnprotectAes(const ACtx: IBenchContext);
begin
  TryQuicUnprotectPacket(GProtAes, -1, GAesKeys, 1, GOutPn, GOutPay);
end;

procedure BenchProtectChacha(const ACtx: IBenchContext);
begin
  GOutPkt := QuicProtectPacket(GClearHdr, 2, 4, GPayload, GChaChaKeys);
end;

procedure BenchUnprotectChacha(const ACtx: IBenchContext);
begin
  TryQuicUnprotectPacket(GProtChacha, -1, GChaChaKeys, 1, GOutPn, GOutPay);
end;

{ ---- Q3：帧编解码 + 可靠骨架 ---- }

procedure BenchFrameCryptoAppend(const ACtx: IBenchContext);
begin
  GOutPkt := nil;
  QuicCryptoAppend(GOutPkt, 0, GPayload);
end;

procedure BenchFrameCryptoParse(const ACtx: IBenchContext);
var
  LFrame: TQuicFrame;
begin
  TryQuicFrameParse(GCryptoWire, 0, Length(GCryptoWire), LFrame);
end;

procedure BenchFrameAckAppend8(const ACtx: IBenchContext);
begin
  GOutPkt := nil;
  QuicAckAppend(GOutPkt, GAckRanges[0].Hi, 500, GAckRanges);
end;

procedure BenchFrameAckParse(const ACtx: IBenchContext);
var
  LFrame: TQuicFrame;
  LRng: TQuicAckRangeArray;
begin
  if TryQuicFrameParse(GAckWire, 0, Length(GAckWire), LFrame, LRng) then
    GOutPn := LFrame.LargestAcked;
end;

procedure BenchReliableTrackSettle512(const ACtx: IBenchContext);
var
  LStats: TQuicAckStats;
  LI: Integer;
begin
  { 入口恒为空转态（上一轮已全部结算）：512 登记 + 单大 range 全结算 }
  for LI := 0 to 511 do
    GTracker.Track(UInt64(LI), UInt64(LI * 100), 100, True);
  GTracker.OnAckFrame(511, GTSettleRanges, LStats);
end;

procedure BenchReliableDetectLostScan(const ACtx: IBenchContext);
begin
  GTracker.DetectLost(GEst, 1000000000, GLost, GLostBytes);
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
  LRow: array[0..18] of Double;
  LNames: array[0..18] of string;
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
  SetLength(GHpKey, 16);
  for LI := 0 to 15 do
    GHpKey[LI] := Byte(LI);
  { 预扩展必须在 HP 密钥填充之后（否则 Nr=0 只量拒绝路径） }
  GPrep := QuicHpPrepareAES(GHpKey);
  SetLength(GSample, 16);
  for LI := 0 to 15 do
    GSample[LI] := Byte(LI);

  { Q2 包保护固定输入：A.2 Client Initial 形态整包 }
  GAesKeys := QuicMakePacketKeys(GSecret, qcsAes128GcmSha256);
  GChaChaKeys := QuicMakePacketKeys(GSecret, qcsChaCha20Poly1305Sha256);
  SetLength(GChaChaHp, 32);
  for LI := 0 to 31 do
    GChaChaHp[LI] := Byte(LI * 7 + 3);
  SetLength(GPktDcid, 8);
  for LI := 0 to 7 do
    GPktDcid[LI] := Byte($A0 + LI);
  GClearHdr := nil;
  QuicBeginLongHeader(GClearHdr, qltInitial, cQuicVersionV1, GPktDcid, nil, nil);
  QuicVarintAppend(GClearHdr, 4 + 1162 + cQuicTagLen);   { pn4+载荷1162+tag16 }
  GClearHdr[0] := QuicLongFirstByte(qltInitial, 0, 3);
  SetLength(GPayload, 1162);
  for LI := 0 to Length(GPayload) - 1 do
    GPayload[LI] := Byte(LI * 31 + 5);
  GProtAes := QuicProtectPacket(GClearHdr, 2, 4, GPayload, GAesKeys);
  GProtChacha := QuicProtectPacket(GClearHdr, 2, 4, GPayload, GChaChaKeys);
  if (Length(GProtAes) <> 1200) or (Length(GProtChacha) <> 1200) or
     not TryQuicUnprotectPacket(GProtAes, -1, GAesKeys, 1, GOutPn, GOutPay) then
  begin
    WriteLn('FATAL: protect fixture self-check failed');
    Halt(1);
  end;

  { Q3 帧与可靠骨架固定输入 }
  GCryptoWire := nil;
  QuicCryptoAppend(GCryptoWire, 0, GPayload);
  SetLength(GAckRanges, 8);
  for LI := 0 to 7 do
  begin
    GAckRanges[LI].Hi := UInt64(511 - LI * 64);
    GAckRanges[LI].Lo := GAckRanges[LI].Hi - 31;   { 每段 32 包、段间 32 空档 }
  end;
  GAckWire := nil;
  if not QuicAckAppend(GAckWire, GAckRanges[0].Hi, 500, GAckRanges) then
  begin
    WriteLn('FATAL: ack fixture build failed');
    Halt(1);
  end;
  GTSettleRanges := nil;
  SetLength(GTSettleRanges, 1);
  GTSettleRanges[0].Lo := 0;
  GTSettleRanges[0].Hi := 511;
  GTracker := TQuicSentTracker.Create(cQuicSentWindowDefault);
  QuicRttInit(GEst);

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
    .Add('tls/hp_mask_aes_prepared', @BenchHpMaskAesPrepared)
    .Add('tls/hp_mask_chacha', @BenchHpMaskChacha)
    .Add('protect/aes_1200b', @BenchProtectAes)
    .Add('protect/unprotect_aes_1200b', @BenchUnprotectAes)
    .Add('protect/chacha_1200b', @BenchProtectChacha)
    .Add('protect/unprotect_chacha_1200b', @BenchUnprotectChacha)
    .Add('frame/crypto_append_1162b', @BenchFrameCryptoAppend)
    .Add('frame/crypto_parse_1162b', @BenchFrameCryptoParse)
    .Add('frame/ack_append_8ranges', @BenchFrameAckAppend8)
    .Add('frame/ack_parse_8ranges', @BenchFrameAckParse)
    .Add('reliable/track_settle_512_cycle', @BenchReliableTrackSettle512)
    .Add('reliable/detect_lost_scan_empty', @BenchReliableDetectLostScan);

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
  LNames[8] := 'tls/hp_mask_chacha';
  LNames[9] := 'protect/aes_1200b';
  LNames[10] := 'protect/unprotect_aes_1200b';
  LNames[11] := 'protect/chacha_1200b';
  LNames[12] := 'protect/unprotect_chacha_1200b';
  LNames[13] := 'frame/crypto_append_1162b';
  LNames[14] := 'frame/crypto_parse_1162b';
  LNames[15] := 'frame/ack_append_8ranges';
  LNames[16] := 'frame/ack_parse_8ranges';
  LNames[17] := 'reliable/track_settle_512_cycle';
  LNames[18] := 'reliable/detect_lost_scan_empty';

  WriteLn('  Benchmark                    ns/op       ops/s');
  WriteLn('  ---------------------------------------------------');
  for LI := 0 to 18 do
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
  if LRow[9] > 0 then
    WriteLn('  整包保护参考：AES-GCM 1200B 包 ',
      FormatFloat('0.00', LRow[9] / 1200), ' ns/byte，单核 ',
      Round(1e9 / LRow[9]), ' 包/s');
end.
