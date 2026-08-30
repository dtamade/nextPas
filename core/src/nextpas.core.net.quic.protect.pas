unit nextpas.core.net.quic.protect;

{**
 * nextpas.core.net.quic.protect — QUIC 包保护（RFC 9001 §5.4/§5.5）
 *
 * 语义锚点（全部经 RFC 9001 附录 A.2/A.3 黄金向量逐字节实证）：
 * - nonce = iv XOR pn(12B 大端)；
 * - AEAD AAD = 明文头（首字节未掩码）‖ 明文 PN 线上字节；
 * - HP 样本 = 受保护区（PN 字段起）第 4 字节起的 16B，与 PN 实际
 *   编码长度无关（保证样本区恒有密文可取）；
 * - 掩码应用：长头首字节 ^= mask[0]&0x0f、短头 ^= mask[0]&0x1f，
 *   PN 各字节 ^= mask[1..1+pnlen]。
 *
 * @note Thread safety: 纯函数（记录值语义，无共享状态）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes,
  nextpas.core.bytes.ops,
  nextpas.core.crypto.aesgcm,
  nextpas.core.crypto.chacha20poly1305,
  nextpas.core.net.quic.varint,
  nextpas.core.net.quic.pn,
  nextpas.core.net.quic.header,
  nextpas.core.net.quic.tls;

const
  cQuicTagLen = 16;        { 两套件 tag 恒 16B }
  cQuicMaxPnLen = 4;       { 样本偏移基准：PN 最大编码长度 }

type
  { 单方向包保护密钥组（套件自描述） }
  TQuicPacketKeys = record
    Suite: TQuicCipherSuite;
    Key: TBytes;
    Iv: TBytes;
    Hp: TBytes;
    HpPrepared: TQuicHpAesPrepared;   { AES 相预扩展态；ChaCha20 相忽略 }
  end;

{** @desc 由方向 secret 构建密钥组（AES 相同时完成 HP 密钥扩展） *}
function QuicMakePacketKeys(const ASecret: TBytes;
  ASuite: TQuicCipherSuite): TQuicPacketKeys;

{**
 * @desc 发送侧整包保护。AClearHeader 为不含 PN 的明文头前缀
 *       （首字节为未掩码形态）；APayload 为帧序列明文；载荷不足
 *       样本区时返回 nil（调用方按 RFC 负责补 PADDING 帧）。
 *}
function QuicProtectPacket(const AClearHeader: TBytes; APn: UInt64;
  APnLen: Integer; const APayload: TBytes;
  const AKeys: TQuicPacketKeys): TBytes;

{**
 * @desc 接收侧去保护。AShortDstCidLen 仅短头需要（本地已知 CID 长度）。
 *       成功输出恢复的 PN、明文帧载荷与明文头（含 PN 前缀，供 AAD
 *       复算或日志）；认证失败/结构非法返回 False。
 *}
function TryQuicUnprotectPacket(const APacket: TBytes;
  AShortDstCidLen: Integer; const AKeys: TQuicPacketKeys;
  ALargestPn: UInt64; out APn: UInt64; out APayload: TBytes): Boolean;

implementation

procedure SpanConcatInto(var ABase: TBytes; const ATail: TBytes); inline;
begin
  if Length(ATail) = 0 then
    Exit;
  ABase := nextpas.core.bytes.ops.SpanConcat(TByteSpan.FromBytes(ABase),
    TByteSpan.FromBytes(ATail));
end;

procedure NonceOf(const AIv: TBytes; APn: UInt64; out ANonce: TBytes);
var
  LPn12: array[0..11] of Byte;
  LI: Integer;
begin
  SetLength(ANonce, 12);
  { 注意：x86 上 shr 位数 >= 64 会回绕（mod 64），高 4 字节必须显式置零 }
  for LI := 0 to 11 do
    LPn12[LI] := 0;
  for LI := 0 to 7 do
    LPn12[11 - LI] := Byte(APn shr (8 * LI));
  for LI := 0 to 11 do
    ANonce[LI] := AIv[LI] xor LPn12[LI];
end;

function AeadEncrypt(const AKeys: TQuicPacketKeys; const ANonce, AAAD,
  APlain: TBytes; out ACipher: TBytes): Boolean;
var
  LTag: TBytes;
begin
  if AKeys.Suite = qcsChaCha20Poly1305Sha256 then
  begin
    Result := TryChaCha20Poly1305EncryptCombined(AKeys.Key, ANonce, AAAD,
      APlain, ACipher);
  end
  else
  begin
    Result := PurePascalAESGCMEncrypt(AKeys.Key, ANonce, APlain, AAAD,
      ACipher, LTag);
    if Result then
      { GCM 分离 tag -> 追加为 QUIC 的 ciphertext‖tag 形态 }
      SpanConcatInto(ACipher, LTag);
  end;
end;

function AeadDecrypt(const AKeys: TQuicPacketKeys; const ANonce, AAAD,
  ACipherWithTag: TBytes; out APlain: TBytes): Boolean;
var
  LBody, LTag: TBytes;
begin
  if Length(ACipherWithTag) < cQuicTagLen then
    Exit(False);
  if AKeys.Suite = qcsChaCha20Poly1305Sha256 then
    Result := TryChaCha20Poly1305DecryptCombined(AKeys.Key, ANonce, AAAD,
      ACipherWithTag, APlain)
  else
  begin
    LBody := SpanCopySlice(TByteSpan.FromBytes(ACipherWithTag), 0,
      Length(ACipherWithTag) - cQuicTagLen);
    LTag := SpanCopySlice(TByteSpan.FromBytes(ACipherWithTag),
      Length(ACipherWithTag) - cQuicTagLen, cQuicTagLen);
    Result := PurePascalAESGCMDecrypt(AKeys.Key, ANonce, LBody, LTag, AAAD,
      APlain);
  end;
end;

function QuicMakePacketKeys(const ASecret: TBytes;
  ASuite: TQuicCipherSuite): TQuicPacketKeys;
var
  LKs: TQuicKeySet;
begin
  LKs := DeriveQuicKeySetForSuite(ASecret, ASuite);
  Result := Default(TQuicPacketKeys);
  Result.Suite := ASuite;
  Result.Key := LKs.Key;
  Result.Iv := LKs.Iv;
  Result.Hp := LKs.Hp;
  if ASuite <> qcsChaCha20Poly1305Sha256 then
    Result.HpPrepared := QuicHpPrepareAES(LKs.Hp);
end;

function QuicProtectPacket(const AClearHeader: TBytes; APn: UInt64;
  APnLen: Integer; const APayload: TBytes;
  const AKeys: TQuicPacketKeys): TBytes;
var
  LPnWire, LAad, LNonce, LCipher, LSample, LMask: TBytes;
  LI: Integer;
  LFirstByte: Byte;
begin
  Result := nil;
  if (APnLen < 1) or (APnLen > cQuicMaxPnLen) then
    Exit;
  if (Length(AClearHeader) < 1) or
     (Length(AKeys.Key) <> cQuicSuiteKeyLen[AKeys.Suite]) or
     (Length(AKeys.Iv) <> 12) or
     (Length(AKeys.Hp) <> cQuicSuiteHpLen[AKeys.Suite]) then
    Exit;

  { 明文 PN 线上字节 + AAD }
  LPnWire := nil;
  QuicPnAppend(LPnWire, APn, APnLen);
  LAad := nil;
  SpanConcatInto(LAad, AClearHeader);
  SpanConcatInto(LAad, LPnWire);

  NonceOf(AKeys.Iv, APn, LNonce);
  if not AeadEncrypt(AKeys, LNonce, LAad, APayload, LCipher) then
    Exit;

  { 样本：受保护区（PN 起）第 4 字节起的 16B }
  if Length(LCipher) < (cQuicMaxPnLen - APnLen) + 16 then
    Exit;   { 载荷不足采样：调用方补 PADDING 后重试 }
  LSample := SpanCopySlice(TByteSpan.FromBytes(LCipher), cQuicMaxPnLen - APnLen, 16);
  LMask := QuicHeaderProtectionMaskForSuite(AKeys.Hp, LSample, AKeys.Suite);
  if Length(LMask) <> cQuicSuiteHpMaskLen[AKeys.Suite] then
    Exit;

  { 组装：掩码化首字节 ‖ 头余部 ‖ 掩码化 PN ‖ 密文 }
  Result := nil;
  if (AClearHeader[0] and $80) <> 0 then
    LFirstByte := AClearHeader[0] xor (LMask[0] and $0F)
  else
    LFirstByte := AClearHeader[0] xor (LMask[0] and $1F);
  QuicBufAppendByte(Result, LFirstByte);
  for LI := 1 to Length(AClearHeader) - 1 do
    QuicBufAppendByte(Result, AClearHeader[LI]);
  for LI := 0 to APnLen - 1 do
    QuicBufAppendByte(Result, LPnWire[LI] xor LMask[LI + 1]);
  SpanConcatInto(Result, LCipher);
end;

function TryQuicUnprotectPacket(const APacket: TBytes;
  AShortDstCidLen: Integer; const AKeys: TQuicPacketKeys;
  ALargestPn: UInt64; out APn: UInt64; out APayload: TBytes): Boolean;
var
  LInfo: TQuicHeaderPeek;
  LSample, LMask, LPnWire, LAad, LNonce, LCipher: TBytes;
  LPnLen, LI: Integer;
  LTrunc: UInt64;
  LFirstClear: Byte;
begin
  APn := 0;
  APayload := nil;
  Result := False;
  if not TryPeekQuicHeader(APacket, AShortDstCidLen, LInfo) then
    Exit;
  if LInfo.PnOffset < 0 then
    Exit;   { VN / Retry 无包保护 }

  { 样本与掩码 }
  if Length(APacket) < LInfo.PnOffset + cQuicMaxPnLen + 16 then
    Exit;
  LSample := SpanCopySlice(TByteSpan.FromBytes(APacket), LInfo.PnOffset + cQuicMaxPnLen, 16);
  LMask := QuicHeaderProtectionMaskForSuite(AKeys.Hp, LSample, AKeys.Suite);
  if Length(LMask) <> cQuicSuiteHpMaskLen[AKeys.Suite] then
    Exit;

  { 首字节去掩码 + 校验固定位/保留位 }
  LFirstClear := LInfo.FirstByte;
  if LInfo.IsLong then
  begin
    LFirstClear := LFirstClear xor (LMask[0] and $0F);
    if (LFirstClear and $80 = 0) or (LFirstClear and $40 = 0) then
      Exit;
    if ((LFirstClear shr 2) and $03) <> 0 then
      Exit;   { Reserved 必须为 0 }
  end
  else
  begin
    LFirstClear := LFirstClear xor (LMask[0] and $1F);
    if (LFirstClear and $40) = 0 then
      Exit;
    if ((LFirstClear shr 2) and $03) <> 0 then
      Exit;   { 短头保留位（bit3-2）必须为 0；KeyPhase 位不参与 }
  end;

  { PN 长度位 = 低 2 位（长短头同义），去掩码 PN }
  LPnLen := (LFirstClear and $03) + 1;
  if Length(APacket) < LInfo.PnOffset + LPnLen + cQuicTagLen then
    Exit;
  LPnWire := nil;
  for LI := 0 to LPnLen - 1 do
    QuicBufAppendByte(LPnWire,
      APacket[LInfo.PnOffset + LI] xor LMask[LI + 1]);
  LTrunc := 0;
  for LI := 0 to LPnLen - 1 do
    LTrunc := (LTrunc shl 8) or LPnWire[LI];
  APn := QuicPnDecode(ALargestPn, LTrunc, LPnLen * 8);

  { 受保护区裁剪（长头按 Length 字段；短头到包尾）并重建 AAD。
    密文区从 PN 之后起——掩码化 PN 字节不属于 AEAD 输入 }
  if LInfo.IsLong then
  begin
    if LInfo.Length < UInt64(LPnLen) + cQuicTagLen then
      Exit;
    LCipher := SpanCopySlice(TByteSpan.FromBytes(APacket), LInfo.PnOffset + LPnLen,
      LInfo.Length - LPnLen);
  end
  else
    LCipher := SpanCopySlice(TByteSpan.FromBytes(APacket), LInfo.PnOffset + LPnLen,
      Length(APacket) - LInfo.PnOffset - LPnLen);

  LAad := nil;
  QuicBufAppendByte(LAad, LFirstClear);
  for LI := 1 to LInfo.PnOffset - 1 do
    QuicBufAppendByte(LAad, APacket[LI]);
  SpanConcatInto(LAad, LPnWire);

  NonceOf(AKeys.Iv, APn, LNonce);
  Result := AeadDecrypt(AKeys, LNonce, LAad, LCipher, APayload);
end;

end.
