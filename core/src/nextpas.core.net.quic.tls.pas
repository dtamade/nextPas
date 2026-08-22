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
 * 完整性锚点：RFC 9001 附录 A.2 固定向量逐字节比对
 * （DCID=8394c8f03e515708，client_secret=c66ca113…）；HP mask 以独立
 * oracle（OpenSSL AES-128-ECB）交叉核对。
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
    $38, $76, $2C, $F7, $AB, $8A, $8A, $A4, $BE, $AC,
    $CA, $E6, $3E, $AF, $0D, $C2, $D4, $76, $D3, $DE);

type
  { 单方向密钥三元组：包保护 AEAD 密钥 / 12B nonce 基量 / HP 掩码密钥 }
  TQuicKeySet = record
    Key: TBytes;   { AEAD key（initial 相恒 AES-128：16B） }
    Iv: TBytes;    { nonce 基量（12B） }
    Hp: TBytes;    { header protection key（16B） }
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
  nextpas.core.crypto.hkdf,
  nextpas.core.tls.keyschedule.labels;

function BytesOfConst(const AConst: array of Byte): TBytes;
var
  LI: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AConst));
  for LI := Low(AConst) to High(AConst) do
    Result[LI] := AConst[LI];
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
  const APrepared: TQuicHpAesPrepared; const ASample: TBytes): TBytes;
var
  LIn, LOut: TAESBlock;
  LI: Integer;
begin
  Result := nil;
  if (APrepared.Nr <= 0) or (Length(ASample) <> 16) then
    Exit;
  for LI := 0 to 15 do
    LIn[LI] := ASample[LI];
  AESEncryptBlock(LIn, LOut, APrepared.Expanded, APrepared.Nr);
  SetLength(Result, 16);
  for LI := 0 to 15 do
    Result[LI] := LOut[LI];
end;

end.
