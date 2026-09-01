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
    { 单分配零拷贝：payload + padLen → 完整线上包；内部生成随机 padding、单次
      SetLength 线上包后原位加密/MAC，消除 transport 侧 LBody 中间拷贝。 }
    function ProtectPayload(const APayload: TBytes; APadLen: SizeUInt; ASeq: UInt32): TBytes;
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

{** AES-CTR 加解密（对称 XOR）。供加密私钥容器解密复用。*}
function SshAesCtrCrypt(const AKey, AIV, AInput: TBytes): TBytes;

implementation

uses
  nextpas.core.bytes.binary,
  nextpas.core.bytes.ops,
  nextpas.core.crypto.random,
  nextpas.core.crypto.aesgcm,
  nextpas.core.crypto.aesctr,
  nextpas.core.crypto.aesni,
  nextpas.core.crypto.aes.ct64,
  nextpas.core.crypto.chacha20poly1305,
  nextpas.core.crypto.errors,
  nextpas.core.crypto.hmac,
  nextpas.core.hash.base,
  nextpas.core.hash.intf,
  nextpas.core.crypto.constant_time,
  nextpas.core.mem.secure;

const
  CHACHA_KEY_TOTAL = 64;   { main(32) + header(32) }
  CHACHA_TAG = 16;
  GCM_TAG = 16;
  CHACHA_PAD_BLOCK = 8;
  AES_PAD_BLOCK = 16;
  GCM_SEQ_THRESHOLD = UInt64($FFFFFF00);

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

{ ---- 公共小工具 ----
  单源：大端读写复用 bytes.binary.Write/ReadUInt32BE (L1 单源)，
  本单元仅作 TBytes + offset 的 inline 薄转发，避免手写移位漂移。
  perf: inline + PByte 直接写入，结果与手写移位等价，零额外分支/拷贝。 }

procedure PutU32BE(var ADst: TBytes; APos: SizeUInt; AValue: UInt32); inline;
begin
  WriteUInt32BE(PByte(@ADst[APos]), AValue);
end;

function U32BEOf(const ASrc: TBytes; APos: SizeUInt): UInt32; inline;
begin
  Result := ReadUInt32BE(PByte(@ASrc[APos]));
end;

function SeqBytes(ASeq: UInt32): TBytes;
begin
  Result := nil;
  SetLength(Result, 4);
  PutU32BE(Result, 0, ASeq);
end;

{ 12 字节 nonce：4 个零 + 大端序序列号低 32 位。
  OpenSSH 以 POKE_U64（大端）把 seq 写进 8 字节 seqbuf 供 djb chacha 的
  input[14..15] 消费；映射到 RFC 8439 字节布局即 $00000000 || seq_BE64
  单源：尾 4 字节用 bytes.binary.WriteUInt32BE，零手写移位。 }
function ChachaNonce(ASeq: UInt32): TBytes;
begin
  Result := nil;
  SetLength(Result, 12);
  FillChar(Result[0], 12, 0);
  WriteUInt32BE(PByte(@Result[8]), ASeq);
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
  if Length(AMacKey) = 0 then
    raise ESSHError.Create(sekNegotiation, 'ssh cipher: mac key empty');
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
    function ProtectPayload(const APayload: TBytes; APadLen: SizeUInt; ASeq: UInt32): TBytes;
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

function TSshNoneSender.ProtectPayload(const APayload: TBytes; APadLen: SizeUInt; ASeq: UInt32): TBytes;
var LPayloadLen, LBodyLen: SizeUInt;
begin
  LPayloadLen := SizeUInt(Length(APayload));
  LBodyLen := 1 + LPayloadLen + APadLen;
  // perf: 单次 SetLength 线上包，零拷贝 Move payload + SecureRandom padding，单源 bytes.ops/bulk
  SetLength(Result, 4 + LBodyLen);
  PutU32BE(Result, 0, UInt32(LBodyLen));
  Result[4] := Byte(APadLen);
  if LPayloadLen > 0 then
    Move(APayload[0], Result[5], LPayloadLen);
  if APadLen > 0 then
    if not SecureRandomBytes(@Result[5 + LPayloadLen], Integer(APadLen)) then
      raise ESSHError.Create(sekCrypto, 'ssh cipher: SecureRandom failed');
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
    FWriteBuf: TBytes;   { perf: cached write buffer reuse, single alloc zero-copy }
  public
    constructor Create(const AKeyMaterial: TBytes);
    destructor Destroy; override;
    function PaddingBlock: Integer;
    function AadLen: Integer;
    function Protect(const ABodyPlain: TBytes; ASeq: UInt32): TBytes;
    function ProtectPayload(const APayload: TBytes; APadLen: SizeUInt; ASeq: UInt32): TBytes;
  end;

  TSshChachaReceiver = class(TInterfacedObject, ISshPacketReceiver)
  private
    FMainKey: TBytes;
    FHeaderKey: TBytes;
  public
    constructor Create(const AKeyMaterial: TBytes);
    destructor Destroy; override;
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

destructor TSshChachaSender.Destroy;
begin
  SecureZeroBytes(FMainKey);
  SecureZeroBytes(FHeaderKey);
  SecureZeroBytes(FWriteBuf);
  inherited;
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
  LNonce, LMask, LPolyKey, LTag: TBytes;
  LBodyLen: SizeUInt;
  LEncLenBE: UInt32;
begin
  { OpenSSH PROTOCOL.chacha20poly1305：
    - 前 32B（main）：counter=0 派生 poly key；counter=1 起加密载荷
    - 后 32B（header）：counter=0 掩码长度字段
    - Poly1305 直接覆盖 encLen||ct（无 RFC 8439 的 pad16 与长度块） }
  LBodyLen := SizeUInt(Length(ABodyPlain));
  // perf: FWriteBuf single alloc reuse via bytes.ops BytesEnsureCapacity — 16KB×8192 首包后复用容量，零额外 churn；Result 零拷贝复用 FWriteBuf 单次分配，消除双大块分配，bytes.ops/bytes.binary 单源 inline
  BytesEnsureCapacity(FWriteBuf, 4 + LBodyLen + CHACHA_TAG);
  SetLength(FWriteBuf, 4 + LBodyLen + CHACHA_TAG);
  LNonce := ChachaNonce(ASeq);
  LMask := ChaCha20Block(FHeaderKey, LNonce, 0);
  try
    LEncLenBE := UInt32(LBodyLen) xor U32BEOf(LMask, 0);
    PutU32BE(FWriteBuf, 0, LEncLenBE);
    if LBodyLen > 0 then
    begin
      if not ChaCha20XorTo(FMainKey, LNonce, 1, @ABodyPlain[0], Integer(LBodyLen), @FWriteBuf[4]) then
        raise ESSHError.Create(sekCrypto, 'ssh cipher: chacha encrypt failed');
    end;
    LPolyKey := ChaCha20Block(FMainKey, LNonce, 0);
    SetLength(LPolyKey, 32);
    try
      LTag := Poly1305RawSpans(LPolyKey, [TByteSpan.Create(@FWriteBuf[0], 4), TByteSpan.Create(@FWriteBuf[4], LBodyLen)]);
      Move(LTag[0], FWriteBuf[4 + LBodyLen], CHACHA_TAG);
      Result := FWriteBuf; // zero-copy share, single alloc; 下次 Protect 共享时 BytesEnsureCapacity/SetLength 自动唯一化，保正确性
    finally
      SecureZeroBytes(LPolyKey);
      SecureZeroBytes(LTag);
    end;
  finally
    SecureZeroBytes(LMask);
    SecureZeroBytes(LNonce);
  end;
end;

function TSshChachaSender.ProtectPayload(const APayload: TBytes; APadLen: SizeUInt; ASeq: UInt32): TBytes;
var
  LNonce, LMask, LPolyKey, LTag: TBytes;
  LPayloadLen, LBodyLen: SizeUInt;
  LEncLenBE: UInt32;
begin
  LPayloadLen := SizeUInt(Length(APayload));
  LBodyLen := 1 + LPayloadLen + APadLen;
  BytesEnsureCapacity(FWriteBuf, 4 + LBodyLen + CHACHA_TAG);
  SetLength(FWriteBuf, 4 + LBodyLen + CHACHA_TAG);
  FWriteBuf[4] := Byte(APadLen);
  if LPayloadLen > 0 then
    Move(APayload[0], FWriteBuf[5], LPayloadLen);
  if APadLen > 0 then
    if not SecureRandomBytes(@FWriteBuf[5 + LPayloadLen], Integer(APadLen)) then
      raise ESSHError.Create(sekCrypto, 'ssh cipher: SecureRandom failed');
  LNonce := ChachaNonce(ASeq);
  LMask := ChaCha20Block(FHeaderKey, LNonce, 0);
  try
    LEncLenBE := UInt32(LBodyLen) xor U32BEOf(LMask, 0);
    PutU32BE(FWriteBuf, 0, LEncLenBE);
    if LBodyLen > 0 then
      if not ChaCha20XorTo(FMainKey, LNonce, 1, @FWriteBuf[4], Integer(LBodyLen), @FWriteBuf[4]) then
        raise ESSHError.Create(sekCrypto, 'ssh cipher: chacha encrypt failed');
    LPolyKey := ChaCha20Block(FMainKey, LNonce, 0);
    SetLength(LPolyKey, 32);
    try
      LTag := Poly1305RawSpans(LPolyKey, [TByteSpan.Create(@FWriteBuf[0], 4), TByteSpan.Create(@FWriteBuf[4], LBodyLen)]);
      Move(LTag[0], FWriteBuf[4 + LBodyLen], CHACHA_TAG);
      Result := FWriteBuf; // zero-copy share, single alloc, bytes.ops 单源
    finally
      SecureZeroBytes(LPolyKey);
      SecureZeroBytes(LTag);
    end;
  finally
    SecureZeroBytes(LMask);
    SecureZeroBytes(LNonce);
  end;
end;

constructor TSshChachaReceiver.Create(const AKeyMaterial: TBytes);
begin
  inherited Create;
  RequireLen(AKeyMaterial, CHACHA_KEY_TOTAL, 'chacha key material');
  FMainKey := Copy(AKeyMaterial, 0, 32);
  FHeaderKey := Copy(AKeyMaterial, 32, 32);
end;

destructor TSshChachaReceiver.Destroy;
begin
  SecureZeroBytes(FMainKey);
  SecureZeroBytes(FHeaderKey);
  inherited;
end;

function TSshChachaReceiver.BodyLengthFromHeader(ASeq: UInt32; const AHeader: TBytes): UInt32;
var
  LMask, LNonce: TBytes;
begin
  { 长度字段被 header key 流掩码；counter=0 首块前 4 字节为掩码 }
  LNonce := ChachaNonce(ASeq);
  LMask := ChaCha20Block(FHeaderKey, LNonce, 0);
  try
    Result := U32BEOf(AHeader, 0) xor U32BEOf(LMask, 0);
  finally
    SecureZeroBytes(LMask);
    SecureZeroBytes(LNonce);
  end;
end;

function TSshChachaReceiver.TrailerSize(ABodyLen: UInt32): UInt32;
begin
  Result := ABodyLen + CHACHA_TAG;
end;

function TSshChachaReceiver.Unprotect(ASeq: UInt32; const AWire: TBytes): TBytes;
var
  LNonce, LPolyKey, LExpect: TBytes;
  LWireLen, LCtLen: SizeUInt;
begin
  LWireLen := SizeUInt(Length(AWire));
  if LWireLen < 4 + CHACHA_TAG then
    raise ESSHError.Create(sekProtocol, 'ssh cipher: chacha packet truncated');
  LCtLen := LWireLen - 4 - CHACHA_TAG;
  // perf: zero-copy spans over AWire (no LEncLen/LCt/LTag Copy alloc), bytes.ops single source
  LNonce := ChachaNonce(ASeq);
  try
    LPolyKey := ChaCha20Block(FMainKey, LNonce, 0);
    SetLength(LPolyKey, 32);
    try
      LExpect := Poly1305RawSpans(LPolyKey,
        [TByteSpan.Create(@AWire[0], 4), TByteSpan.Create(@AWire[4], LCtLen)]);
      if TConstantTime.CompareBuffer(@LExpect[0], @AWire[LWireLen - CHACHA_TAG], CHACHA_TAG) <> 1 then
        raise ESSHError.Create(sekCrypto, 'ssh cipher: chacha AEAD verify failed');
      // zero-copy decrypt directly into Result (no LCt alloc)
      SetLength(Result, LCtLen);
      if LCtLen > 0 then
        if not ChaCha20XorTo(FMainKey, LNonce, 1, @AWire[4], Integer(LCtLen), @Result[0]) then
          raise ESSHError.Create(sekCrypto, 'ssh cipher: chacha decrypt failed');
    finally
      SecureZeroBytes(LExpect);
      SecureZeroBytes(LPolyKey);
    end;
  finally
    SecureZeroBytes(LNonce);
  end;
end;

{ ---- aes*-gcm@openssh.com（RFC 5647 调用计数器，OpenSSH 布局）---- }

type
  TSshGcmSender = class(TInterfacedObject, ISshPacketSender)
  private
    FKey: TBytes;
    FBaseIV: TBytes;     { 12B，取 IV 前 8 字节 + 计数器后 4 字节 }
    FCounter: UInt64;    { 调用计数器，从 1 起，UInt64防回绕 }
    FWriteBuf: TBytes;   { perf: cached write buf reuse, single alloc }
  public
    constructor Create(const AKey, AIV: TBytes);
    destructor Destroy; override;
    function PaddingBlock: Integer;
    function AadLen: Integer;
    function Protect(const ABodyPlain: TBytes; ASeq: UInt32): TBytes;
    function ProtectPayload(const APayload: TBytes; APadLen: SizeUInt; ASeq: UInt32): TBytes;
  end;

  TSshGcmReceiver = class(TInterfacedObject, ISshPacketReceiver)
  private
    FKey: TBytes;
    FBaseIV: TBytes;
    FCounter: UInt64;
  public
    constructor Create(const AKey, AIV: TBytes);
    destructor Destroy; override;
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

destructor TSshGcmSender.Destroy;
begin
  SecureZeroBytes(FKey);
  SecureZeroBytes(FBaseIV);
  SecureZeroBytes(FWriteBuf);
  inherited;
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

function GcmNonce(const ABaseIV: TBytes; ACounter: UInt64): TBytes;
begin
  Result := nil;
  Result := Copy(ABaseIV, 0, 12);
  // 单源：计数器尾 4 字节用 bytes.binary 大端写入
  WriteUInt32BE(PByte(@Result[8]), UInt32(ACounter));
end;

function TSshGcmSender.Protect(const ABodyPlain: TBytes; ASeq: UInt32): TBytes;
var
  LNonce: TBytes;
  LBodyLen: SizeUInt;
  LPlainPtr, LDestPtr: PByte;
  LOk: Boolean;
begin
  if FCounter = High(UInt64) then
    raise ESSHError.Create(sekProtocol, 'ssh cipher: gcm counter wrap, rekey required');
  if FCounter >= GCM_SEQ_THRESHOLD then
    raise ESSHError.Create(sekCrypto, 'ssh cipher: gcm counter exhausted, rekey required');
  LBodyLen := SizeUInt(Length(ABodyPlain));
  BytesEnsureCapacity(FWriteBuf, 4 + LBodyLen + GCM_TAG);
  SetLength(FWriteBuf, 4 + LBodyLen + GCM_TAG);
  LNonce := GcmNonce(FBaseIV, FCounter);
  try
    PutU32BE(FWriteBuf, 0, UInt32(LBodyLen));
    if LBodyLen > 0 then
      LPlainPtr := @ABodyPlain[0]
    else
      LPlainPtr := nil;
    LDestPtr := @FWriteBuf[4];
    LOk := False;
    if IsAESNIAvailable then
    begin
      if Length(FKey) = 16 then
        LOk := AESNIGCMEncryptTo128PtrAAD(FKey, @LNonce[0], 12, LPlainPtr, Integer(LBodyLen), @FWriteBuf[0], 4, LDestPtr, Integer(LBodyLen + GCM_TAG))
      else if Length(FKey) = 32 then
        LOk := AESNIGCMEncryptTo256PtrAAD(FKey, @LNonce[0], 12, LPlainPtr, Integer(LBodyLen), @FWriteBuf[0], 4, LDestPtr, Integer(LBodyLen + GCM_TAG));
      if LOk then
      begin
        Inc(FCounter);
        Result := FWriteBuf; // zero-copy share, single alloc
        Exit;
      end
      else if Length(FKey) in [16, 32] then
        raise ESSHError.Create(sekCrypto, 'ssh cipher: gcm encrypt failed');
    end;
    if not PurePascalAESGCMEncryptPtrAAD(FKey, @LNonce[0], 12, LPlainPtr, Integer(LBodyLen), @FWriteBuf[0], 4, LDestPtr, Integer(LBodyLen + GCM_TAG)) then
      raise ESSHError.Create(sekCrypto, 'ssh cipher: gcm encrypt failed');
    Inc(FCounter);
    Result := FWriteBuf; // zero-copy share, single alloc
  finally
    SecureZeroBytes(LNonce);
  end;
end;

function TSshGcmSender.ProtectPayload(const APayload: TBytes; APadLen: SizeUInt; ASeq: UInt32): TBytes;
var
  LNonce: TBytes;
  LPayloadLen, LBodyLen: SizeUInt;
  LOk: Boolean;
begin
  if FCounter = High(UInt64) then
    raise ESSHError.Create(sekProtocol, 'ssh cipher: gcm counter wrap, rekey required');
  if FCounter >= GCM_SEQ_THRESHOLD then
    raise ESSHError.Create(sekCrypto, 'ssh cipher: gcm counter exhausted, rekey required');
  LPayloadLen := SizeUInt(Length(APayload));
  LBodyLen := 1 + LPayloadLen + APadLen;
  BytesEnsureCapacity(FWriteBuf, 4 + LBodyLen + GCM_TAG);
  SetLength(FWriteBuf, 4 + LBodyLen + GCM_TAG);
  PutU32BE(FWriteBuf, 0, UInt32(LBodyLen));
  FWriteBuf[4] := Byte(APadLen);
  if LPayloadLen > 0 then
    Move(APayload[0], FWriteBuf[5], LPayloadLen);
  if APadLen > 0 then
    if not SecureRandomBytes(@FWriteBuf[5 + LPayloadLen], Integer(APadLen)) then
      raise ESSHError.Create(sekCrypto, 'ssh cipher: SecureRandom failed');
  LNonce := GcmNonce(FBaseIV, FCounter);
  try
    LOk := False;
    if IsAESNIAvailable then
    begin
      if Length(FKey) = 16 then
        LOk := AESNIGCMEncryptTo128PtrAAD(FKey, @LNonce[0], 12, @FWriteBuf[4], Integer(LBodyLen), @FWriteBuf[0], 4, @FWriteBuf[4], Integer(LBodyLen + GCM_TAG))
      else if Length(FKey) = 32 then
        LOk := AESNIGCMEncryptTo256PtrAAD(FKey, @LNonce[0], 12, @FWriteBuf[4], Integer(LBodyLen), @FWriteBuf[0], 4, @FWriteBuf[4], Integer(LBodyLen + GCM_TAG));
      if LOk then
      begin
        Inc(FCounter);
        Result := FWriteBuf; // zero-copy share
        Exit;
      end
      else if Length(FKey) in [16, 32] then
        raise ESSHError.Create(sekCrypto, 'ssh cipher: gcm encrypt failed');
    end;
    if not PurePascalAESGCMEncryptPtrAAD(FKey, @LNonce[0], 12, @FWriteBuf[4], Integer(LBodyLen), @FWriteBuf[0], 4, @FWriteBuf[4], Integer(LBodyLen + GCM_TAG)) then
      raise ESSHError.Create(sekCrypto, 'ssh cipher: gcm encrypt failed');
    Inc(FCounter);
    Result := FWriteBuf; // zero-copy share, single alloc
  finally
    SecureZeroBytes(LNonce);
  end;
end;

constructor TSshGcmReceiver.Create(const AKey, AIV: TBytes);
begin
  inherited Create;
  RequireLen(AIV, 12, 'gcm iv');
  FKey := Copy(AKey, 0, Length(AKey));
  FBaseIV := Copy(AIV, 0, 12);
  FCounter := 1;
end;

destructor TSshGcmReceiver.Destroy;
begin
  SecureZeroBytes(FKey);
  SecureZeroBytes(FBaseIV);
  inherited;
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
  LNonce: TBytes;
  LWireLen, LCtLen: SizeUInt;
  LOk: Boolean;
  LCtPtr, LTagPtr, LAadPtr, LDestPtr: PByte;
begin
  LWireLen := SizeUInt(Length(AWire));
  if LWireLen < 4 + GCM_TAG then
    raise ESSHError.Create(sekProtocol, 'ssh cipher: gcm packet truncated');
  if FCounter = High(UInt64) then
    raise ESSHError.Create(sekProtocol, 'ssh cipher: gcm counter wrap, rekey required');
  if FCounter >= GCM_SEQ_THRESHOLD then
    raise ESSHError.Create(sekCrypto, 'ssh cipher: gcm counter exhausted');
  LCtLen := LWireLen - 4 - GCM_TAG;
  LNonce := GcmNonce(FBaseIV, FCounter);
  try
    // perf: zero-copy direct decrypt into Result via AES-NI, no LCt/LTag Copy (vs 3 Copies)
    SetLength(Result, LCtLen);
    LOk := False;
    if IsAESNIAvailable then
    begin
      if Length(FKey) = 16 then
      begin
        if LCtLen = 0 then
          LOk := AESNIGCMDecryptTo128PtrAAD(FKey, @LNonce[0], 12, nil, 0, PByte(@AWire[LWireLen - GCM_TAG]), PByte(@AWire[0]), 4, nil, 0)
        else
          LOk := AESNIGCMDecryptTo128PtrAAD(FKey, @LNonce[0], 12, PByte(@AWire[4]), Integer(LCtLen), PByte(@AWire[LWireLen - GCM_TAG]), PByte(@AWire[0]), 4, PByte(@Result[0]), Integer(LCtLen));
      end
      else if Length(FKey) = 32 then
      begin
        if LCtLen = 0 then
          LOk := AESNIGCMDecryptTo256PtrAAD(FKey, @LNonce[0], 12, nil, 0, PByte(@AWire[LWireLen - GCM_TAG]), PByte(@AWire[0]), 4, nil, 0)
        else
          LOk := AESNIGCMDecryptTo256PtrAAD(FKey, @LNonce[0], 12, PByte(@AWire[4]), Integer(LCtLen), PByte(@AWire[LWireLen - GCM_TAG]), PByte(@AWire[0]), 4, PByte(@Result[0]), Integer(LCtLen));
      end;
      if LOk then
      begin
        Inc(FCounter);
        Exit;
      end
      else if Length(FKey) in [16, 32] then
        raise ESSHError.Create(sekCrypto, 'ssh cipher: gcm auth failed');
    end;
    // fallback pure pascal zero-copy: PByte AAD/CT/Tag direct, no Copy alloc (fast path parity)
    if LCtLen > 0 then
      LCtPtr := PByte(@AWire[4])
    else
      LCtPtr := nil;
    LTagPtr := PByte(@AWire[LWireLen - GCM_TAG]);
    LAadPtr := PByte(@AWire[0]);
    if LCtLen > 0 then
      LDestPtr := PByte(@Result[0])
    else
      LDestPtr := nil;
    if not PurePascalAESGCMDecryptPtrAAD(FKey, @LNonce[0], 12, LCtPtr, Integer(LCtLen), LTagPtr, LAadPtr, 4, LDestPtr, Integer(LCtLen)) then
      raise ESSHError.Create(sekCrypto, 'ssh cipher: gcm auth failed');
    Inc(FCounter);
  finally
    SecureZeroBytes(LNonce);
  end;
end;

{ ---- aes*-ctr + hmac-sha2-*-etm ----
  TAesCtrStream single source: nextpas.core.crypto.aesctr (crypto Owner).
  ssh 仅持有实例与 Done 生命周期，不再散落 keystream 状态；SshAesCtrCrypt 薄转发至 AesCtrCrypt。 }

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
    FWriteBuf: TBytes; { perf: cached buf reuse, single alloc }
  public
    constructor Create(const ACipher, AMac: string; const AKey, AIV, AMacKey: TBytes);
    destructor Destroy; override;
    function PaddingBlock: Integer;
    function AadLen: Integer;
    function Protect(const ABodyPlain: TBytes; ASeq: UInt32): TBytes;
    function ProtectPayload(const APayload: TBytes; APadLen: SizeUInt; ASeq: UInt32): TBytes;
  end;

  TSshCtrEtmReceiver = class(TInterfacedObject, ISshPacketReceiver)
  private
    FCtr: TAesCtrStream;
    FMacKey: TBytes;
    FMacAlgo: THashAlgorithm;
    FMacTagSize: Integer;
    FWriteBuf: TBytes; { perf: cached }
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
  FCtr.Init(AKey, AIV);
  FMacKey := Copy(AMacKey, 0, SshMacKeySize(AMac));
  FMacAlgo := MacAlgoOf(AMac);
end;

destructor TSshCtrEtmSender.Destroy;
begin
  FCtr.Done;
  SecureZeroBytes(FMacKey);
  SecureZeroBytes(FWriteBuf);
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
  LTag: TBytes;
  LBodyLen, LTagLen: SizeUInt;
  LHasher: IHasher;
  LSeqBE: array[0..3] of Byte;
begin
  LBodyLen := SizeUInt(Length(ABodyPlain));
  LTagLen := SizeUInt(Length(FMacKey));
  BytesEnsureCapacity(FWriteBuf, 4 + LBodyLen + LTagLen);
  SetLength(FWriteBuf, 4 + LBodyLen + LTagLen);
  PutU32BE(FWriteBuf, 0, UInt32(LBodyLen));
  if LBodyLen > 0 then
    Move(ABodyPlain[0], FWriteBuf[4], LBodyLen);
  FCtr.XorInto(FWriteBuf, 4, LBodyLen); // encrypt ct in place, bulk MemXor single source via bytes.ops
  WriteUInt32BE(@LSeqBE[0], ASeq);
  LHasher := NewHMAC(FMacAlgo, FMacKey[0], SizeUInt(Length(FMacKey)));
  LHasher.Write(LSeqBE[0], 4);
  LHasher.Write(FWriteBuf[0], 4);
  if LBodyLen > 0 then
    LHasher.Write(FWriteBuf[4], LBodyLen);
  LTag := LHasher.SumBytes;
  Move(LTag[0], FWriteBuf[4 + LBodyLen], LTagLen);
  SecureZeroBytes(LTag);
  SecureZeroMemory(@LSeqBE[0], SizeOf(LSeqBE));
  Result := FWriteBuf; // zero-copy share, single alloc; BytesEnsureCapacity 复用容量，消除双大块分配，bytes.ops/bytes.binary 单源 inline
end;

function TSshCtrEtmSender.ProtectPayload(const APayload: TBytes; APadLen: SizeUInt; ASeq: UInt32): TBytes;
var
  LTag: TBytes;
  LPayloadLen, LBodyLen, LTagLen: SizeUInt;
  LHasher: IHasher;
  LSeqBE: array[0..3] of Byte;
begin
  LPayloadLen := SizeUInt(Length(APayload));
  LBodyLen := 1 + LPayloadLen + APadLen;
  LTagLen := SizeUInt(Length(FMacKey));
  BytesEnsureCapacity(FWriteBuf, 4 + LBodyLen + LTagLen);
  SetLength(FWriteBuf, 4 + LBodyLen + LTagLen);
  PutU32BE(FWriteBuf, 0, UInt32(LBodyLen));
  FWriteBuf[4] := Byte(APadLen);
  if LPayloadLen > 0 then
    Move(APayload[0], FWriteBuf[5], LPayloadLen);
  if APadLen > 0 then
    if not SecureRandomBytes(@FWriteBuf[5 + LPayloadLen], Integer(APadLen)) then
      raise ESSHError.Create(sekCrypto, 'ssh cipher: SecureRandom failed');
  FCtr.XorInto(FWriteBuf, 4, LBodyLen);
  WriteUInt32BE(@LSeqBE[0], ASeq);
  LHasher := NewHMAC(FMacAlgo, FMacKey[0], SizeUInt(Length(FMacKey)));
  LHasher.Write(LSeqBE[0], 4);
  LHasher.Write(FWriteBuf[0], 4);
  if LBodyLen > 0 then
    LHasher.Write(FWriteBuf[4], LBodyLen);
  LTag := LHasher.SumBytes;
  Move(LTag[0], FWriteBuf[4 + LBodyLen], LTagLen);
  SecureZeroBytes(LTag);
  SecureZeroMemory(@LSeqBE[0], SizeOf(LSeqBE));
  Result := FWriteBuf; // zero-copy share, single alloc, bytes.ops 单源
end;

constructor TSshCtrEtmReceiver.Create(const ACipher, AMac: string;
  const AKey, AIV, AMacKey: TBytes);
begin
  inherited Create;
  if not SshMacSupported(AMac) or (AMac = '') then
    raise ESSHError.Create(sekNegotiation,
      'ssh cipher: ctr requires an etm mac, got "' + AMac + '"');
  FCtr.Init(AKey, AIV);
  FMacKey := Copy(AMacKey, 0, SshMacKeySize(AMac));
  FMacAlgo := MacAlgoOf(AMac);
  FMacTagSize := MacTagSizeOf(AMac);
end;

destructor TSshCtrEtmReceiver.Destroy;
begin
  FCtr.Done;
  SecureZeroBytes(FMacKey);
  SecureZeroBytes(FWriteBuf);
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
  LExpect: TBytes;
  LHasher: IHasher;
  LSeqBE: array[0..3] of Byte;
  LWireLen: SizeUInt;
begin
  LWireLen := SizeUInt(Length(AWire));
  if LWireLen < 4 + SizeUInt(FMacTagSize) then
    raise ESSHError.Create(sekProtocol, 'ssh cipher: ctr packet truncated');
  LBodyLen := U32BEOf(AWire, 0);
  if LWireLen < 4 + SizeUInt(LBodyLen) + SizeUInt(FMacTagSize) then
    raise ESSHError.Create(sekProtocol, 'ssh cipher: ctr packet truncated');
  { 先验 MAC（EtM：对密文 body 校验）零拷贝 incremental Write, 无 LMacInput 堆分配, bytes.binary 单源 }
  WriteUInt32BE(@LSeqBE[0], ASeq);
  LHasher := NewHMAC(FMacAlgo, FMacKey[0], SizeUInt(Length(FMacKey)));
  try
    LHasher.Write(LSeqBE[0], 4);
    LHasher.Write(AWire[0], 4);
    if LBodyLen > 0 then
      LHasher.Write(AWire[4], LBodyLen);
    LExpect := LHasher.SumBytes;
    try
      if TConstantTime.CompareBuffer(@LExpect[0], @AWire[4 + LBodyLen], UInt32(FMacTagSize)) <> 1 then
        raise ESSHError.Create(sekCrypto, 'ssh cipher: etm mac mismatch');
      { 再解密：zero-copy Move + in-place bytes.ops MemXor }
      SetLength(Result, LBodyLen);
      if LBodyLen > 0 then
        Move(AWire[4], Result[0], LBodyLen);
      FCtr.XorInto(Result, 0, SizeUInt(LBodyLen));
    finally
      SecureZeroBytes(LExpect);
    end;
  finally
    SecureZeroMemory(@LSeqBE[0], SizeOf(LSeqBE));
  end;
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

function SshAesCtrCrypt(const AKey, AIV, AInput: TBytes): TBytes;
begin
  // single source forward to crypto.aesctr (zero-copy keystream via TAesCtrStream, bytes.ops single source)
  try
    Result := AesCtrCrypt(AKey, AIV, AInput);
  except
    on E: ECryptoError do
      raise ESSHError.Create(sekCrypto, E.Message);
  end;
end;

end.
