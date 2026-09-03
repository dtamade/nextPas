unit nextpas.core.net.quic.tls;

{**
 * nextpas.core.net.quic.tls — QUIC-TLS 适配层（RFC 9001 §5）
 *
 * 职责（Q1，见 proxy888 wiki/quic-roadmap.md）：
 * - initial secret 从 DCID 派生（v1 盐值；版本扩展位后续加 QuicInitialSaltOf）；
 * - 方向 secret -> AEAD key / nonce iv / header-protection hp 三元组
 *   （"quic key"/"quic iv"/"quic hp"，HKDF-Expand-Label 构造复用
 *   tls.keyschedule.labels —— 与 RFC 8446 §7.1 同构）；
 * - header protection mask（AES-128-ECB 单块；ChaCha20 变体随 Q2 套件
 *   协商落地）。
 *
 * 完整性锚点：RFC 9001 附录 A.1 固定向量逐字节比对
 * （v1 盐=38762cf7f55934b34d179ae6a4c80cadccbb7f0a，
 * DCID=8394c8f03e515708，client_secret=c00cf151…）；HP mask 以
 * python cryptography AES-ECB 独立 oracle 交叉核对。黄金常量只认
 * 一手文档（Q2 盐值事故教训，见 proxy888 wiki/quic-roadmap.md §3.1）。
 *
 * @note Thread safety: 纯函数（无共享状态）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.crypto.aesgcm;

const
  { RFC 9001 §5.2 Version 1 initial salt（20 字节） }
  cQuicV1Salt: array[0..19] of Byte = (
    $38, $76, $2C, $F7, $F5, $59, $34, $B3, $4D, $17,
    $9A, $E6, $A4, $C8, $0C, $AD, $CC, $BB, $7F, $0A);

type
  { QUIC-TLS 密码套件（RFC 9001 §7 表格子集；initial 相恒 AES-128-GCM） }
  TQuicCipherSuite = (
    qcsAes128GcmSha256 = 0,
    qcsChaCha20Poly1305Sha256 = 1
  );

const
  { 套件对应密钥形态长度：AEAD key / HP key / iv（RFC 9001 §7） }
  cQuicSuiteKeyLen: array[TQuicCipherSuite] of Integer = (16, 32);
  cQuicSuiteHpLen: array[TQuicCipherSuite] of Integer = (16, 32);
  cQuicSuiteIvLen: array[TQuicCipherSuite] of Integer = (12, 12);
  { HP 掩码输出长度：AES-ECB 全块 16B（§5.4.3）/ ChaCha20 密钥流前 5B（§5.4.4）；
    包头掩码至多消费 mask[0..4]，两套件均够用 }
  cQuicSuiteHpMaskLen: array[TQuicCipherSuite] of Integer = (16, 5);

type
  { 单方向密钥三元组：包保护 AEAD 密钥 / 12B nonce 基量 / HP 掩码密钥 }
  TQuicKeySet = record
    Key: TBytes;   { AEAD key（initial 相恒 AES-128：16B） }
    Iv: TBytes;    { nonce 基量（12B） }
    Hp: TBytes;    { header protection key（AES 相 16B / ChaCha20 相 32B） }
  end;

  { DCID 派生的双方向 initial secret }
  TQuicInitialSecrets = record
    ClientSecret: TBytes;   { 客户端方向（我方为客户端时用于发初始包） }
    ServerSecret: TBytes;   { 服务端方向 }
  end;

{**
 * @desc RFC 9001 §5.2：initial_secret = HKDF-Extract(v1 salt, DCID) 后按
 *       "client in"/"server in" 展开为双方向 32B secret
 *}
function DeriveQuicInitialSecrets(const ADestCid: TBytes): TQuicInitialSecrets;

{**
 * @desc 方向 secret -> key/iv/hp 三元组（AES-128-GCM 形态：
 *       key/hp 各 16B、iv 12B）。initial 相固定本套件（RFC 9001 §5.2）；
 *       握手/应用相套件协商后走同一函数（key 长度随套件）。
 *}
function DeriveQuicKeySet(const ASecret: TBytes): TQuicKeySet;

{**
 * @desc 按套件的 key/hp 长度派生三元组（ChaCha20 相 key/hp 各 32B，
 *       iv 仍 12B）。ASecret 长度必须 32B，否则返回空三元组。
 *}
function DeriveQuicKeySetForSuite(const ASecret: TBytes;
  ASuite: TQuicCipherSuite): TQuicKeySet;

{**
 * @desc 套件分派的 HP 掩码：AES 相 = AES-ECB 单块（16B，消费方取前
 *       5 字节）；ChaCha20 相 = RFC 9001 §5.4.4——counter =
 *       sample[0..3] 小端、nonce = sample[4..15]、掩码取密钥流前
 *       5 字节。密钥长度不符套件或样本非 16B 返回 nil。
 *}
function QuicHeaderProtectionMaskForSuite(const AHpKey, ASample: TBytes;
  ASuite: TQuicCipherSuite): TBytes;

{**
 * @desc RFC 9001 §5.4.2：mask = AES-ECB(hp, sample)。sample 为包头内
 *       保护区间之后的 16 字节（Q2 包层取样传入）。
 *       ASample 必须 16 字节，否则返回 nil。
 *}
function QuicHeaderProtectionMaskAES(const AHpKey, ASample: TBytes): TBytes;

type
  { HP 掩码预扩展态：密钥相位切换时 Prepare 一次，逐包仅单块加密 }
  TQuicHpAesPrepared = record
    Expanded: TAESExpandedKey;
    Nr: Integer;   { 0 = 未准备（密钥长度非 16B） }
  end;

{**
 * @desc 密钥扩展提前到密钥相位切换点（每密钥一次）；逐包路径用
 *       QuicHeaderProtectionMaskAESPrepared 免去重复扩展。
 *       AHpKey 非 16 字节时 Nr=0（后续 Mask 调用返回 nil）。
 *}
function QuicHpPrepareAES(const AHpKey: TBytes): TQuicHpAesPrepared;

{**
 * @desc 预扩展热路径形态：与 QuicHeaderProtectionMaskAES 同结果，
 *       省去每次 AESKeyExpand。ASample 必须 16 字节，否则返回 nil。
 *}
function QuicHeaderProtectionMaskAESPrepared(
  const APrepared: TQuicHpAesPrepared; const ASample: TBytes): TBytes;

implementation

uses
  nextpas.core.bytes,
  nextpas.core.bytes.ops,
  nextpas.core.crypto.hkdf,
  nextpas.core.crypto.chacha20poly1305,
  nextpas.core.tls.keyschedule.labels;

function BytesOfConst(const AConst: array of Byte): TBytes; inline;
begin
  Result := nil;
  SetLength(Result, Length(AConst));
  if Length(AConst) > 0 then
    BytesCopy(@Result[0], @AConst[Low(AConst)], SizeUInt(Length(AConst))); // perf: inline single Move via bytes.ops single source (zero-copy)
end;

function DeriveQuicInitialSecrets(const ADestCid: TBytes): TQuicInitialSecrets;
var
  LInitSecret: TBytes;
begin
  LInitSecret := HKDF_Extract_SHA256(BytesOfConst(cQuicV1Salt), ADestCid);
  Result.ClientSecret := TLS13_HKDF_Expand_Label_SHA256(
    LInitSecret, 'client in', nil, 32);
  Result.ServerSecret := TLS13_HKDF_Expand_Label_SHA256(
    LInitSecret, 'server in', nil, 32);
end;

function DeriveQuicKeySet(const ASecret: TBytes): TQuicKeySet;
begin
  Result.Key := TLS13_HKDF_Expand_Label_SHA256(ASecret, 'quic key', nil, 16);
  Result.Iv := TLS13_HKDF_Expand_Label_SHA256(ASecret, 'quic iv', nil, 12);
  Result.Hp := TLS13_HKDF_Expand_Label_SHA256(ASecret, 'quic hp', nil, 16);
end;

function DeriveQuicKeySetForSuite(const ASecret: TBytes;
  ASuite: TQuicCipherSuite): TQuicKeySet;
begin
  Result := Default(TQuicKeySet);
  if Length(ASecret) <> 32 then
    Exit;
  if ASuite = qcsChaCha20Poly1305Sha256 then
  begin
    Result.Key := TLS13_HKDF_Expand_Label_SHA256(ASecret, 'quic key', nil, 32);
    Result.Iv := TLS13_HKDF_Expand_Label_SHA256(ASecret, 'quic iv', nil, 12);
    Result.Hp := TLS13_HKDF_Expand_Label_SHA256(ASecret, 'quic hp', nil, 32);
  end
  else
    Result := DeriveQuicKeySet(ASecret);
end;

function QuicHeaderProtectionMaskForSuite(const AHpKey, ASample: TBytes;
  ASuite: TQuicCipherSuite): TBytes;
var
  LBlock: TBytes;
  LCounter: UInt32;
  LNonce12: TBytes;
begin
  Result := nil;
  if (Length(ASample) <> 16) or
     (Length(AHpKey) <> cQuicSuiteHpLen[ASuite]) then
    Exit;
  if ASuite = qcsChaCha20Poly1305Sha256 then
  begin
    { RFC 9001 §5.4.4：counter = LE(sample[0..3])，nonce = sample[4..15]，
      mask = 密钥流前 5 字节（A.5 向量 aefefe7d03 实证） }
    LCounter := UInt32(ASample[0]) or (UInt32(ASample[1]) shl 8) or
      (UInt32(ASample[2]) shl 16) or (UInt32(ASample[3]) shl 24);
    SetLength(LNonce12, 12);
    BytesCopy(@LNonce12[0], @ASample[4], 12); // perf: inline single Move via bytes.ops single source (zero-copy)
    LBlock := ChaCha20Block(AHpKey, LNonce12, LCounter);
    Result := SpanCopySlice(TByteSpan.FromBytes(LBlock), 0, 5);
  end
  else
    Result := QuicHeaderProtectionMaskAES(AHpKey, ASample);
end;

function QuicHeaderProtectionMaskAES(const AHpKey, ASample: TBytes): TBytes;
var
  LPrepared: TQuicHpAesPrepared;
begin
  LPrepared := QuicHpPrepareAES(AHpKey);
  Result := QuicHeaderProtectionMaskAESPrepared(LPrepared, ASample);
end;

function QuicHpPrepareAES(const AHpKey: TBytes): TQuicHpAesPrepared;
begin
  Result.Nr := 0;
  Result.Expanded := Default(TAESExpandedKey);
  if Length(AHpKey) <> 16 then
    Exit;
  AESKeyExpand(AHpKey, Result.Expanded, Result.Nr);
end;

function QuicHeaderProtectionMaskAESPrepared(
  const APrepared: TQuicHpAesPrepared; const ASample: TBytes): TBytes; inline;
var
  LIn, LOut: TAESBlock;
begin
  Result := nil;
  if (APrepared.Nr <= 0) or (Length(ASample) <> 16) then
    Exit;
  BytesCopy(@LIn[0], @ASample[0], 16); // perf: inline single Move via bytes.ops single source (zero-copy)
  AESEncryptBlock(LIn, LOut, APrepared.Expanded, APrepared.Nr);
  SetLength(Result, 16);
  BytesCopy(@Result[0], @LOut[0], 16); // perf: inline single Move via bytes.ops single source (zero-copy)
end;

end.
