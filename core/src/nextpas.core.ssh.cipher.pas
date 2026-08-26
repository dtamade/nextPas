unit nextpas.core.ssh.cipher;

{** nextpas.core.ssh - 二进制包加密编解码器。
 *
 * 每个方向一个实例。发送方把未加密 body（[padlen][payload][padding]）打成完整
 * 线上包；接收方按 帧头→包体 两步还原。纯内存变换，帧同步由 transport 驱动。
 *
 * 支持三族：
 *  - chacha20-poly1305@openssh.com：长度字段用 header key 流加密，Poly1305
 *    裸覆盖 encLen||ct（无 RFC 8439 的 pad16/长度块），tag 追加在尾
 *    （OpenSSH PROTOCOL.chacha20poly1305 构造）
 *  - aes*-gcm@openssh.com：长度字段明文并作为 AAD，RFC 5647 调用计数器从 1 起
 *  - aes*-ctr + hmac-sha2-*-etm：长度字段明文，EtM MAC 覆盖 seq||len||密文 body
 *
 * 未协商密钥前使用 none 编解码器（长度明文、无校验）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system.sysutils,
  nextpas.core.base,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors;

type
  { 发送方向编解码器 }
  ISshPacketSender = interface
    ['{9C1E6E10-4A11-4F72-9D30-5A0000000001}']
    { padding 对齐块大小（>=8）；transport 用它计算 pad 长度 }
    function PaddingBlock: Integer;
    { 参与 pad 对齐基准的 AAD 字节数。OpenSSH packet.c 发送端先 len-=aadlen 再算
      padlen，接收端强制 need(=packlen)%blocksize=0；AEAD/EtM 的长度字段不进
      密文对齐区，返回 4；none 等整帧加密模式返回 0 }
    function AadLen: Integer;
    { body=[padlen][payload][padding] → 完整线上包（含长度字段与 tag/mac）}
    function Protect(const ABodyPlain: TBytes; ASeq: UInt32): TBytes;
  end;

  { 接收方向编解码器 }
  ISshPacketReceiver = interface
    ['{9C1E6E10-4A11-4F72-9D30-5A0000000002}']
    { 线上 4 字节长度字段 → 其后包体字节数（不含长度字段本身）}
    function BodyLengthFromHeader(ASeq: UInt32; const AHeader: TBytes): UInt32;
    { 长度字段之后还需读取的字节数 = 包体 + tag/mac 尾部 }
    function TrailerSize(ABodyLen: UInt32): UInt32;
    { 校验+解密长度字段之后的全部字节 → 未加密 body；校验失败抛 sekCrypto }
    function Unprotect(ASeq: UInt32; const AWire: TBytes): TBytes;
  end;

{ 创建单方向编解码器。ACipher 为空表示 none（未协商密钥前的明文帧）。
  AKey/AIV/AMacKey 按 ACipher 的需求取自 KDF 产物（多余尾部忽略）。}
function CreateSshPacketSender(const ACipher, AMac: string;
  const AKey, AIV, AMacKey: TBytes): ISshPacketSender;
function CreateSshPacketReceiver(const ACipher, AMac: string;
  const AKey, AIV, AMacKey: TBytes): ISshPacketReceiver;

{ 协商预检与 KDF 长度询问 }
function SshCipherSupported(const ACipher: string): Boolean;
function SshMacSupported(const AMac: string): Boolean;
function SshCipherKeySize(const ACipher: string): Integer;
function SshCipherIvSize(const ACipher: string): Integer;
function SshMacKeySize(const AMac: string): Integer;
function SshCipherRequiresMac(const ACipher: string): Boolean;

implementation

uses
  nextpas.core.crypto.aesgcm,
  nextpas.core.crypto.aesni,
  nextpas.core.crypto.aes.ct64,
  nextpas.core.crypto.chacha20poly1305,
  nextpas.core.crypto.hmac,
  nextpas.core.hash.base,
  nextpas.core.hash.intf,
  nextpas.core.crypto.constant_time;

const
  CHACHA_KEY_TOTAL = 64;   { main(32) + header(32) }
  CHACHA_TAG = 16;
  GCM_TAG = 16;
  CHACHA_PAD_BLOCK = 8;
  AES_PAD_BLOCK = 16;

{ ---- 算法名工具 ---- }

function IsChachaName(const AName: string): Boolean;
begin
  Result := AName = 'chacha20-poly1305@openssh.com';
end;

function IsGcmName(const AName: string): Boolean;
begin
  Result := (AName = 'aes128-gcm@openssh.com') or (AName = 'aes256-gcm@openssh.com')
    or (AName = 'aes128-gcm') or (AName = 'aes256-gcm');
end;

function IsCtrName(const AName: string): Boolean;
begin
  Result := (AName = 'aes128-ctr') or (AName = 'aes192-ctr') or (AName = 'aes256-ctr');
end;

function SshCipherSupported(const ACipher: string): Boolean;
begin
  Result := (ACipher = '') or IsChachaName(ACipher) or IsGcmName(ACipher) or IsCtrName(ACipher);
end;

function SshMacSupported(const AMac: string): Boolean;
begin
  Result := (AMac = '')
    or (AMac = 'hmac-sha2-256-etm@openssh.com')
    or (AMac = 'hmac-sha2-512-etm@openssh.com');
end;

function SshCipherKeySize(const ACipher: string): Integer;
begin
  if ACipher = '' then
    Exit(0);
  if IsChachaName(ACipher) then
    Exit(CHACHA_KEY_TOTAL);
  if IsGcmName(ACipher) then
  begin
    if (ACipher = 'aes256-gcm@openssh.com') or (ACipher = 'aes256-gcm') then
      Exit(32);
    Exit(16);
  end;
  if IsCtrName(ACipher) then
  begin
    if ACipher = 'aes128-ctr' then
      Exit(16);
    if ACipher = 'aes192-ctr' then
      Exit(24);
    Exit(32);
  end;
  raise ESSHError.Create(sekNegotiation, 'ssh cipher: unsupported cipher "' + ACipher + '"');
end;

function SshCipherIvSize(const ACipher: string): Integer;
begin
  if IsChachaName(ACipher) then
    Result := 0
  else if IsGcmName(ACipher) then
    Result := 12
  else if IsCtrName(ACipher) then
    Result := 16
  else
    Result := 0;
end;

function SshMacKeySize(const AMac: string): Integer;
begin
  if AMac = 'hmac-sha2-256-etm@openssh.com' then
    Result := SHA256_DIGEST_SIZE
  else if AMac = 'hmac-sha2-512-etm@openssh.com' then
    Result := SHA512_DIGEST_SIZE
  else
    Result := 0;
end;

function SshCipherRequiresMac(const ACipher: string): Boolean;
begin
  Result := IsCtrName(ACipher);
end;

{ ---- 公共小工具 ---- }

procedure PutU32BE(var ADst: TBytes; APos: SizeUInt; AValue: UInt32); inline;
begin
  ADst[APos] := Byte(AValue shr 24);
  ADst[APos + 1] := Byte((AValue shr 16) and $FF);
  ADst[APos + 2] := Byte((AValue shr 8) and $FF);
  ADst[APos + 3] := Byte(AValue and $FF);
end;

function U32BEOf(const ASrc: TBytes; APos: SizeUInt): UInt32; inline;
begin
  Result := (UInt32(ASrc[APos]) shl 24)
    or (UInt32(ASrc[APos + 1]) shl 16)
    or (UInt32(ASrc[APos + 2]) shl 8)
    or UInt32(ASrc[APos + 3]);
end;

function SeqBytes(ASeq: UInt32): TBytes;
begin
  Result := nil;
  SetLength(Result, 4);
  PutU32BE(Result, 0, ASeq);
end;

{ 12 字节 nonce：4 个零 + 大端序序列号低 32 位。
  OpenSSH 以 POKE_U64（大端）把 seq 写进 8 字节 seqbuf 供 djb chacha 的
  input[14..15] 消费；映射到 RFC 8439 字节布局即 $00000000 || seq_BE64 }
function ChachaNonce(ASeq: UInt32): TBytes;
begin
  Result := nil;
  SetLength(Result, 12);
  FillChar(Result[0], 12, 0);
  Result[8] := Byte(ASeq shr 24);
  Result[9] := Byte((ASeq shr 16) and $FF);
  Result[10] := Byte((ASeq shr 8) and $FF);
  Result[11] := Byte(ASeq and $FF);
end;


procedure RequireLen(const ABuf: TBytes; ANeeded: Integer; const AWhat: string);
begin
  if Length(ABuf) < ANeeded then
    raise ESSHError.Create(sekProtocol, 'ssh cipher: ' + AWhat + ' too short');
end;

{ HMAC 统一入口 }
function MacCompute(AMacAlgo: THashAlgorithm; const AMacKey, AData: TBytes): TBytes;
var
  LHasher: IHasher;
begin
  LHasher := NewHMAC(AMacAlgo, AMacKey[0], SizeUInt(Length(AMacKey)));
  if Length(AData) > 0 then
    LHasher.Write(AData[0], SizeUInt(Length(AData)));
  Result := LHasher.SumBytes;
end;

{ ---- none（握手前）---- }

type
  TSshNoneSender = class(TInterfacedObject, ISshPacketSender)
  public
    function PaddingBlock: Integer;
    function AadLen: Integer;
    function Protect(const ABodyPlain: TBytes; ASeq: UInt32): TBytes;
  end;

  TSshNoneReceiver = class(TInterfacedObject, ISshPacketReceiver)
  public
    function BodyLengthFromHeader(ASeq: UInt32; const AHeader: TBytes): UInt32;
    function TrailerSize(ABodyLen: UInt32): UInt32;
    function Unprotect(ASeq: UInt32; const AWire: TBytes): TBytes;
  end;

function TSshNoneSender.PaddingBlock: Integer;
begin
  Result := SSH_MIN_PAD_BLOCK;
end;

function TSshNoneSender.AadLen: Integer;
begin
  { 整帧（含长度字段）参与加密与对齐 }
  Result := 0;
end;

function TSshNoneSender.Protect(const ABodyPlain: TBytes; ASeq: UInt32): TBytes;
begin
  Result := nil;
  SetLength(Result, 4 + SizeUInt(Length(ABodyPlain)));
  PutU32BE(Result, 0, UInt32(Length(ABodyPlain)));
  if Length(ABodyPlain) > 0 then
    Move(ABodyPlain[0], Result[4], SizeUInt(Length(ABodyPlain)));
end;

function TSshNoneReceiver.BodyLengthFromHeader(ASeq: UInt32; const AHeader: TBytes): UInt32;
begin
  Result := U32BEOf(AHeader, 0);
end;

function TSshNoneReceiver.TrailerSize(ABodyLen: UInt32): UInt32;
begin
  Result := ABodyLen;
end;

function TSshNoneReceiver.Unprotect(ASeq: UInt32; const AWire: TBytes): TBytes;
begin
  if SizeUInt(Length(AWire)) < 4 then
    raise ESSHError.Create(sekProtocol, 'ssh cipher: none packet truncated');
  { 剥离明文长度字段，返回未加密 body }
  Result := Copy(AWire, 4, SizeInt(Length(AWire)) - 4);
end;

{ ---- chacha20-poly1305@openssh.com ---- }

type
  TSshChachaSender = class(TInterfacedObject, ISshPacketSender)
  private
    FMainKey: TBytes;    { key material 前 32 字节：载荷流 + poly key 派生 }
    FHeaderKey: TBytes;  { 后 32 字节：长度字段掩码流 }
  public
    constructor Create(const AKeyMaterial: TBytes);
    function PaddingBlock: Integer;
    function AadLen: Integer;
    function Protect(const ABodyPlain: TBytes; ASeq: UInt32): TBytes;
  end;

  TSshChachaReceiver = class(TInterfacedObject, ISshPacketReceiver)
  private
    FMainKey: TBytes;
    FHeaderKey: TBytes;
  public
    constructor Create(const AKeyMaterial: TBytes);
    function BodyLengthFromHeader(ASeq: UInt32; const AHeader: TBytes): UInt32;
    function TrailerSize(ABodyLen: UInt32): UInt32;
    function Unprotect(ASeq: UInt32; const AWire: TBytes): TBytes;
  end;

constructor TSshChachaSender.Create(const AKeyMaterial: TBytes);
begin
  inherited Create;
  RequireLen(AKeyMaterial, CHACHA_KEY_TOTAL, 'chacha key material');
  FMainKey := Copy(AKeyMaterial, 0, 32);
  FHeaderKey := Copy(AKeyMaterial, 32, 32);
end;

function TSshChachaSender.PaddingBlock: Integer;
begin
  Result := CHACHA_PAD_BLOCK;
end;

function TSshChachaSender.AadLen: Integer;
begin
  { AEAD：长度字段由 header key 单独加密，不进 payload 对齐区 }
  Result := 4;
end;

function TSshChachaSender.Protect(const ABodyPlain: TBytes; ASeq: UInt32): TBytes;
var
  LNonce, LMask, LEncLen, LPolyKey, LCt, LTag, LMacData: TBytes;
begin
  { OpenSSH PROTOCOL.chacha20poly1305：
    - 前 32B（main）：counter=0 派生 poly key；counter=1 起加密载荷
    - 后 32B（header）：counter=0 掩码长度字段
    - Poly1305 直接覆盖 encLen||ct（无 RFC 8439 的 pad16 与长度块） }
  LNonce := ChachaNonce(ASeq);
  LMask := ChaCha20Block(FHeaderKey, LNonce, 0);
  SetLength(LEncLen, 4);
  PutU32BE(LEncLen, 0, UInt32(Length(ABodyPlain)) xor U32BEOf(LMask, 0));
  LCt := ChaCha20Xor(FMainKey, LNonce, 1, ABodyPlain);
  LPolyKey := ChaCha20Block(FMainKey, LNonce, 0);
  SetLength(LPolyKey, 32);
  SetLength(LMacData, 4 + SizeUInt(Length(LCt)));
  Move(LEncLen[0], LMacData[0], 4);
  if Length(LCt) > 0 then
    Move(LCt[0], LMacData[4], SizeUInt(Length(LCt)));
  LTag := Poly1305Raw(LPolyKey, LMacData);
  Result := nil;
  SetLength(Result, 4 + SizeUInt(Length(LCt)) + CHACHA_TAG);
  Move(LEncLen[0], Result[0], 4);
  if Length(LCt) > 0 then
    Move(LCt[0], Result[4], SizeUInt(Length(LCt)));
  Move(LTag[0], Result[4 + SizeUInt(Length(LCt))], CHACHA_TAG);
end;

constructor TSshChachaReceiver.Create(const AKeyMaterial: TBytes);
begin
  inherited Create;
  RequireLen(AKeyMaterial, CHACHA_KEY_TOTAL, 'chacha key material');
  FMainKey := Copy(AKeyMaterial, 0, 32);
  FHeaderKey := Copy(AKeyMaterial, 32, 32);
end;

function TSshChachaReceiver.BodyLengthFromHeader(ASeq: UInt32; const AHeader: TBytes): UInt32;
var
  LMask: TBytes;
begin
  { 长度字段被 header key 流掩码；counter=0 首块前 4 字节为掩码 }
  LMask := ChaCha20Block(FHeaderKey, ChachaNonce(ASeq), 0);
  Result := U32BEOf(AHeader, 0) xor U32BEOf(LMask, 0);
end;

function TSshChachaReceiver.TrailerSize(ABodyLen: UInt32): UInt32;
begin
  Result := ABodyLen + CHACHA_TAG;
end;

function TSshChachaReceiver.Unprotect(ASeq: UInt32; const AWire: TBytes): TBytes;
var
  LEncLen, LCt, LTag, LNonce, LPolyKey, LExpect, LMacData: TBytes;
begin
  if SizeUInt(Length(AWire)) < 4 + CHACHA_TAG then
    raise ESSHError.Create(sekProtocol, 'ssh cipher: chacha packet truncated');
  LEncLen := Copy(AWire, 0, 4);
  LTag := Copy(AWire, SizeUInt(Length(AWire)) - CHACHA_TAG, CHACHA_TAG);
  LCt := Copy(AWire, 4,
    SizeInt(SizeUInt(Length(AWire)) - 4 - CHACHA_TAG));
  { Poly1305 覆盖 encLen||ct；常量时间比较后再解密 }
  LNonce := ChachaNonce(ASeq);
  LPolyKey := ChaCha20Block(FMainKey, LNonce, 0);
  SetLength(LPolyKey, 32);
  SetLength(LMacData, 4 + SizeUInt(Length(LCt)));
  Move(LEncLen[0], LMacData[0], 4);
  if Length(LCt) > 0 then
    Move(LCt[0], LMacData[4], SizeUInt(Length(LCt)));
  LExpect := Poly1305Raw(LPolyKey, LMacData);
  if TConstantTime.CompareBytes(LExpect, LTag) <> 1 then
    raise ESSHError.Create(sekCrypto, 'ssh cipher: chacha AEAD verify failed');
  Result := ChaCha20Xor(FMainKey, LNonce, 1, LCt);
end;

{ ---- aes*-gcm@openssh.com（RFC 5647 调用计数器，OpenSSH 布局）---- }

type
  TSshGcmSender = class(TInterfacedObject, ISshPacketSender)
  private
    FKey: TBytes;
    FBaseIV: TBytes;     { 12B，取 IV 前 8 字节 + 计数器后 4 字节 }
    FCounter: UInt32;    { 调用计数器，从 1 起 }
  public
    constructor Create(const AKey, AIV: TBytes);
    function PaddingBlock: Integer;
    function AadLen: Integer;
    function Protect(const ABodyPlain: TBytes; ASeq: UInt32): TBytes;
  end;

  TSshGcmReceiver = class(TInterfacedObject, ISshPacketReceiver)
  private
    FKey: TBytes;
    FBaseIV: TBytes;
    FCounter: UInt32;
  public
    constructor Create(const AKey, AIV: TBytes);
    function BodyLengthFromHeader(ASeq: UInt32; const AHeader: TBytes): UInt32;
    function TrailerSize(ABodyLen: UInt32): UInt32;
    function Unprotect(ASeq: UInt32; const AWire: TBytes): TBytes;
  end;

constructor TSshGcmSender.Create(const AKey, AIV: TBytes);
begin
  inherited Create;
  RequireLen(AIV, 12, 'gcm iv');
  FKey := Copy(AKey, 0, Length(AKey));
  FBaseIV := Copy(AIV, 0, 12);
  FCounter := 1;
end;

function TSshGcmSender.PaddingBlock: Integer;
begin
  Result := AES_PAD_BLOCK;
end;

function TSshGcmSender.AadLen: Integer;
begin
  { AEAD（RFC 5647）：长度字段明文但作为 GCM AAD 认证，不进对齐区 }
  Result := 4;
end;

function GcmNonce(const ABaseIV: TBytes; ACounter: UInt32): TBytes;
begin
  Result := nil;
  Result := Copy(ABaseIV, 0, 12);
  Result[8] := Byte(ACounter shr 24);
  Result[9] := Byte((ACounter shr 16) and $FF);
  Result[10] := Byte((ACounter shr 8) and $FF);
  Result[11] := Byte(ACounter and $FF);
end;

function TSshGcmSender.Protect(const ABodyPlain: TBytes; ASeq: UInt32): TBytes;
var
  LLens, LCt, LTag: TBytes;
begin
  SetLength(LLens, 4);
  PutU32BE(LLens, 0, UInt32(Length(ABodyPlain)));
  if not PurePascalAESGCMEncrypt(FKey, GcmNonce(FBaseIV, FCounter),
    ABodyPlain, LLens, LCt, LTag) then
    raise ESSHError.Create(sekCrypto, 'ssh cipher: gcm encrypt failed');
  Inc(FCounter);  { uint32 自然回绕 }
  Result := nil;
  SetLength(Result, 4 + SizeUInt(Length(LCt)) + SizeUInt(Length(LTag)));
  Move(LLens[0], Result[0], 4);
  Move(LCt[0], Result[4], SizeUInt(Length(LCt)));
  Move(LTag[0], Result[4 + Length(LCt)], SizeUInt(Length(LTag)));
end;

constructor TSshGcmReceiver.Create(const AKey, AIV: TBytes);
begin
  inherited Create;
  RequireLen(AIV, 12, 'gcm iv');
  FKey := Copy(AKey, 0, Length(AKey));
  FBaseIV := Copy(AIV, 0, 12);
  FCounter := 1;
end;

function TSshGcmReceiver.BodyLengthFromHeader(ASeq: UInt32; const AHeader: TBytes): UInt32;
begin
  Result := U32BEOf(AHeader, 0);
end;

function TSshGcmReceiver.TrailerSize(ABodyLen: UInt32): UInt32;
begin
  Result := ABodyLen + GCM_TAG;
end;

function TSshGcmReceiver.Unprotect(ASeq: UInt32; const AWire: TBytes): TBytes;
var
  LCt, LTag: TBytes;
begin
  if SizeUInt(Length(AWire)) < 4 + GCM_TAG then
    raise ESSHError.Create(sekProtocol, 'ssh cipher: gcm packet truncated');
  LCt := Copy(AWire, 4, SizeInt(Length(AWire)) - 4 - GCM_TAG);
  LTag := Copy(AWire, Length(AWire) - GCM_TAG, GCM_TAG);
  if not PurePascalAESGCMDecrypt(FKey, GcmNonce(FBaseIV, FCounter),
    LCt, LTag, Copy(AWire, 0, 4), Result) then
    raise ESSHError.Create(sekCrypto, 'ssh cipher: gcm auth failed');
  Inc(FCounter);
end;

{ ---- aes*-ctr + hmac-sha2-*-etm ---- }

{ AES-CTR 连续计数器流（跨包不重置），块级 XOR。
  keystream 单块生成走最快可用后端：AES-NI → ct64 → 朴素实现（aes192 兜底）。
  FKSOff 跨调用持久：部分消耗的计数器块在下次调用继续使用。}
type
  TAesCtrStream = class
  private type
    TKind = (akNi128, akNi256, akCt64, akNaive);
  private
    FKind: TKind;
    FNiKey128: TAESNIExpandedKey128;
    FNiKey256: TAESNIExpandedKey256;
    FCt64Key: TAESCt64Key;
    FExpanded: TAESExpandedKey;   { 仅 akNaive }
    FNr: Integer;
    FCtr: TAESBlock;      { 计数器块，大端递增 }
    FKS: TAESBlock;       { 当前计数器块的 keystream }
    FKSOff: Integer;      { 本块内已消耗字节 }
    FKSValid: Boolean;
    procedure RefreshKS; inline;
    procedure IncCounter; inline;
  public
    constructor Create(const AKey, AIV: TBytes);
    procedure XorInto(var AData: TBytes; AOffset, ACount: SizeUInt);
  end;

constructor TAesCtrStream.Create(const AKey, AIV: TBytes);
var
  LKey16: TAESNIBlock;
begin
  inherited Create;
  RequireLen(AIV, 16, 'ctr iv');
  FKSValid := False;   { 首次 XorInto 直接用 IV 作首块计数器，不先递增 }
  FKSOff := 0;
  Move(AIV[0], FCtr[0], 16);
  case Length(AKey) of
    16:
      if IsAESNIAvailable then
      begin
        FKind := akNi128;
        Move(AKey[0], LKey16[0], 16);
        AESNIExpandKey128(LKey16, FNiKey128);
      end
      else
      begin
        FKind := akCt64;
        AESCt64KeyExpand(Copy(AKey, 0, Length(AKey)), FCt64Key);
      end;
    32:
      if IsAESNIAvailable then
      begin
        FKind := akNi256;
        AESNIExpandKey256(AKey, FNiKey256);
      end
      else
      begin
        FKind := akCt64;
        AESCt64KeyExpand(Copy(AKey, 0, Length(AKey)), FCt64Key);
      end;
  else
    begin
      FKind := akNaive;
      AESKeyExpand(Copy(AKey, 0, Length(AKey)), FExpanded, FNr);
    end;
  end;
end;

procedure TAesCtrStream.RefreshKS;
begin
  case FKind of
    akNi128:
      AESNIEncryptBlock128(TAESNIBlock(FCtr), TAESNIBlock(FKS), FNiKey128);
    akNi256:
      AESNIEncryptBlock256(TAESNIBlock(FCtr), TAESNIBlock(FKS), FNiKey256);
    akCt64:
      AESCt64EncryptBlock(@FCtr[0], @FKS[0], FCt64Key);
  else
    AESEncryptBlock(FCtr, FKS, FExpanded, FNr);
  end;
  FKSValid := True;
end;

procedure TAesCtrStream.IncCounter;
var
  I: Integer;
begin
  I := 15;
  while I >= 0 do
  begin
    Inc(FCtr[I]);
    if FCtr[I] <> 0 then
      Break;
    Dec(I);
  end;
end;

procedure TAesCtrStream.XorInto(var AData: TBytes; AOffset, ACount: SizeUInt);
var
  LDst, LKs: PByte;
  LRem: SizeUInt;
begin
  if ACount = 0 then
    Exit;
  LDst := @AData[AOffset];
  LKs := @FKS[0];
  LRem := ACount;
  while LRem > 0 do
  begin
    if (not FKSValid) or (FKSOff >= 16) then
    begin
      if FKSOff >= 16 then
        IncCounter;
      RefreshKS;
      FKSOff := 0;
    end;
    while (LRem > 0) and (FKSOff < 16) do
    begin
      LDst^ := LDst^ xor LKs[FKSOff];
      Inc(LDst);
      Inc(FKSOff);
      Dec(LRem);
    end;
  end;
end;

{ EtM MAC 名称 → hash 算法 }
function MacAlgoOf(const AMac: string): THashAlgorithm;
begin
  if AMac = 'hmac-sha2-256-etm@openssh.com' then
    Exit(haSHA256);
  if AMac = 'hmac-sha2-512-etm@openssh.com' then
    Exit(haSHA512);
  raise ESSHError.Create(sekNegotiation, 'ssh cipher: unsupported mac "' + AMac + '"');
end;

function MacTagSizeOf(const AMac: string): Integer;
begin
  Result := SshMacKeySize(AMac);
  if Result = 0 then
    raise ESSHError.Create(sekNegotiation, 'ssh cipher: unsupported mac "' + AMac + '"');
end;

type
  TSshCtrEtmSender = class(TInterfacedObject, ISshPacketSender)
  private
    FCtr: TAesCtrStream;
    FMacKey: TBytes;
    FMacAlgo: THashAlgorithm;
  public
    constructor Create(const ACipher, AMac: string; const AKey, AIV, AMacKey: TBytes);
    destructor Destroy; override;
    function PaddingBlock: Integer;
    function AadLen: Integer;
    function Protect(const ABodyPlain: TBytes; ASeq: UInt32): TBytes;
  end;

  TSshCtrEtmReceiver = class(TInterfacedObject, ISshPacketReceiver)
  private
    FCtr: TAesCtrStream;
    FMacKey: TBytes;
    FMacAlgo: THashAlgorithm;
    FMacTagSize: Integer;
  public
    constructor Create(const ACipher, AMac: string; const AKey, AIV, AMacKey: TBytes);
    destructor Destroy; override;
    function BodyLengthFromHeader(ASeq: UInt32; const AHeader: TBytes): UInt32;
    function TrailerSize(ABodyLen: UInt32): UInt32;
    function Unprotect(ASeq: UInt32; const AWire: TBytes): TBytes;
  end;

constructor TSshCtrEtmSender.Create(const ACipher, AMac: string;
  const AKey, AIV, AMacKey: TBytes);
begin
  inherited Create;
  if not SshMacSupported(AMac) or (AMac = '') then
    raise ESSHError.Create(sekNegotiation,
      'ssh cipher: ctr requires an etm mac, got "' + AMac + '"');
  FCtr := TAesCtrStream.Create(AKey, AIV);
  FMacKey := Copy(AMacKey, 0, SshMacKeySize(AMac));
  FMacAlgo := MacAlgoOf(AMac);
end;

destructor TSshCtrEtmSender.Destroy;
begin
  FCtr.Free;
  inherited Destroy;
end;

function TSshCtrEtmSender.PaddingBlock: Integer;
begin
  Result := AES_PAD_BLOCK;
end;

function TSshCtrEtmSender.AadLen: Integer;
begin
  { EtM：长度字段明文且被 MAC 先行覆盖，不进加密对齐区 }
  Result := 4;
end;

function TSshCtrEtmSender.Protect(const ABodyPlain: TBytes; ASeq: UInt32): TBytes;
var
  LBody, LMacInput, LTag: TBytes;
begin
  Result := nil;
  LBody := Copy(ABodyPlain, 0, Length(ABodyPlain));
  FCtr.XorInto(LBody, 0, SizeUInt(Length(LBody)));
  { EtM：MAC 输入 = seq || 明文长度字段 || 密文 body（先加密后校验）}
  SetLength(LMacInput, 8 + SizeUInt(Length(LBody)));
  PutU32BE(LMacInput, 0, ASeq);
  PutU32BE(LMacInput, 4, UInt32(Length(ABodyPlain)));
  if Length(LBody) > 0 then
    Move(LBody[0], LMacInput[8], SizeUInt(Length(LBody)));
  LTag := MacCompute(FMacAlgo, FMacKey, LMacInput);
  SetLength(Result, 4 + SizeUInt(Length(LBody)) + SizeUInt(Length(LTag)));
  PutU32BE(Result, 0, UInt32(Length(ABodyPlain)));
  Move(LBody[0], Result[4], SizeUInt(Length(LBody)));
  Move(LTag[0], Result[4 + Length(LBody)], SizeUInt(Length(LTag)));
end;

constructor TSshCtrEtmReceiver.Create(const ACipher, AMac: string;
  const AKey, AIV, AMacKey: TBytes);
begin
  inherited Create;
  if not SshMacSupported(AMac) or (AMac = '') then
    raise ESSHError.Create(sekNegotiation,
      'ssh cipher: ctr requires an etm mac, got "' + AMac + '"');
  FCtr := TAesCtrStream.Create(AKey, AIV);
  FMacKey := Copy(AMacKey, 0, SshMacKeySize(AMac));
  FMacAlgo := MacAlgoOf(AMac);
  FMacTagSize := MacTagSizeOf(AMac);
end;

destructor TSshCtrEtmReceiver.Destroy;
begin
  FCtr.Free;
  inherited Destroy;
end;

function TSshCtrEtmReceiver.BodyLengthFromHeader(ASeq: UInt32; const AHeader: TBytes): UInt32;
begin
  Result := U32BEOf(AHeader, 0);
end;

function TSshCtrEtmReceiver.TrailerSize(ABodyLen: UInt32): UInt32;
begin
  Result := ABodyLen + UInt32(FMacTagSize);
end;

function TSshCtrEtmReceiver.Unprotect(ASeq: UInt32; const AWire: TBytes): TBytes;
var
  LBodyLen: UInt32;
  LMacInput, LExpect, LGot: TBytes;
begin
  if SizeUInt(Length(AWire)) < 4 + SizeUInt(FMacTagSize) then
    raise ESSHError.Create(sekProtocol, 'ssh cipher: ctr packet truncated');
  LBodyLen := U32BEOf(AWire, 0);
  { 先验 MAC（EtM：对密文 body 校验）}
  SetLength(LMacInput, 8 + SizeUInt(LBodyLen));
  PutU32BE(LMacInput, 0, ASeq);
  PutU32BE(LMacInput, 4, LBodyLen);
  if LBodyLen > 0 then
    Move(AWire[4], LMacInput[8], LBodyLen);
  LExpect := MacCompute(FMacAlgo, FMacKey, LMacInput);
  LGot := Copy(AWire, 4 + SizeInt(LBodyLen), FMacTagSize);
  if TConstantTime.CompareBytes(LExpect, LGot) <> 1 then
    raise ESSHError.Create(sekCrypto, 'ssh cipher: etm mac mismatch');
  { 再解密 }
  Result := Copy(AWire, 4, SizeInt(LBodyLen));
  FCtr.XorInto(Result, 0, SizeUInt(LBodyLen));
end;

{ ---- 工厂 ---- }

function CreateSshPacketSender(const ACipher, AMac: string;
  const AKey, AIV, AMacKey: TBytes): ISshPacketSender;
begin
  if ACipher = '' then
    Exit(TSshNoneSender.Create);   { 未协商密钥前：明文帧 }
  if not SshCipherSupported(ACipher) then
    raise ESSHError.Create(sekNegotiation, 'ssh cipher: unsupported cipher "' + ACipher + '"');
  if IsChachaName(ACipher) then
    Result := TSshChachaSender.Create(AKey)
  else if IsGcmName(ACipher) then
    Result := TSshGcmSender.Create(Copy(AKey, 0, SshCipherKeySize(ACipher)), AIV)
  else
    Result := TSshCtrEtmSender.Create(ACipher, AMac,
      Copy(AKey, 0, SshCipherKeySize(ACipher)), AIV, AMacKey);
end;

function CreateSshPacketReceiver(const ACipher, AMac: string;
  const AKey, AIV, AMacKey: TBytes): ISshPacketReceiver;
begin
  if ACipher = '' then
    Exit(TSshNoneReceiver.Create);
  if not SshCipherSupported(ACipher) then
    raise ESSHError.Create(sekNegotiation, 'ssh cipher: unsupported cipher "' + ACipher + '"');
  if IsChachaName(ACipher) then
    Result := TSshChachaReceiver.Create(AKey)
  else if IsGcmName(ACipher) then
    Result := TSshGcmReceiver.Create(Copy(AKey, 0, SshCipherKeySize(ACipher)), AIV)
  else
    Result := TSshCtrEtmReceiver.Create(ACipher, AMac,
      Copy(AKey, 0, SshCipherKeySize(ACipher)), AIV, AMacKey);
end;

end.
