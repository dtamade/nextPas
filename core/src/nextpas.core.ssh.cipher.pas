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
  nextpas.core.bytes.ops,
  nextpas.core.crypto.aesgcm,
  nextpas.core.crypto.aesni,
  nextpas.core.crypto.aes.ct64,
  nextpas.core.crypto.chacha20poly1305,
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
    FWriteBuf: TBytes;   { perf: cached write buffer reuse, single alloc zero-copy }
  public
    constructor Create(const AKeyMaterial: TBytes);
    destructor Destroy; override;
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
  LNonce := ChachaNonce(ASeq);
  LMask := ChaCha20Block(FHeaderKey, LNonce, 0);
  try
    LEncLenBE := UInt32(LBodyLen) xor U32BEOf(LMask, 0);
    // perf: FWriteBuf reuse — single SetLength for wire packet, zero-copy ChaCha20XorTo into Result[4], 1 Move for tag only (vs 3 Moves+2 alloc)
    SetLength(Result, 4 + LBodyLen + CHACHA_TAG);
    PutU32BE(Result, 0, LEncLenBE); // inline
    if LBodyLen > 0 then
    begin
      if not ChaCha20XorTo(FMainKey, LNonce, 1, @ABodyPlain[0], Integer(LBodyLen), @Result[4]) then
        raise ESSHError.Create(sekCrypto, 'ssh cipher: chacha encrypt failed');
    end;
    LPolyKey := ChaCha20Block(FMainKey, LNonce, 0);
    SetLength(LPolyKey, 32);
    try
      // zero-copy Poly1305 over encLen||ct spans (no concat alloc), bytes.ops single source
      LTag := Poly1305RawSpans(LPolyKey, [TByteSpan.Create(@Result[0], 4), TByteSpan.Create(@Result[4], LBodyLen)]);
      Move(LTag[0], Result[4 + LBodyLen], CHACHA_TAG);
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
  Result[8] := Byte((ACounter shr 24) and $FF);
  Result[9] := Byte((ACounter shr 16) and $FF);
  Result[10] := Byte((ACounter shr 8) and $FF);
  Result[11] := Byte(ACounter and $FF);
end;

function TSshGcmSender.Protect(const ABodyPlain: TBytes; ASeq: UInt32): TBytes;
var
  LNonce: TBytes;
  LBodyLen: SizeUInt;
  LPlainPtr, LDestPtr: PByte;
  LOk: Boolean;
  LCt, LTag: TBytes;
begin
  if FCounter = High(UInt64) then
    raise ESSHError.Create(sekProtocol, 'ssh cipher: gcm counter wrap, rekey required');
  if FCounter >= GCM_SEQ_THRESHOLD then
    raise ESSHError.Create(sekCrypto, 'ssh cipher: gcm counter exhausted, rekey required');
  LBodyLen := SizeUInt(Length(ABodyPlain));
  LNonce := GcmNonce(FBaseIV, FCounter);
  try
    // perf: single alloc wire buf, zero-copy AES-NI direct into Result[4] (CT||Tag), FWriteBuf reuse via single SetLength
    SetLength(Result, 4 + LBodyLen + GCM_TAG);
    PutU32BE(Result, 0, UInt32(LBodyLen)); // inline
    if LBodyLen > 0 then
      LPlainPtr := @ABodyPlain[0]
    else
      LPlainPtr := nil;
    LDestPtr := @Result[4];
    LOk := False;
    if IsAESNIAvailable then
    begin
      if Length(FKey) = 16 then
        LOk := AESNIGCMEncryptTo128PtrAAD(FKey, @LNonce[0], 12, LPlainPtr, Integer(LBodyLen), @Result[0], 4, LDestPtr, Integer(LBodyLen + GCM_TAG))
      else if Length(FKey) = 32 then
        LOk := AESNIGCMEncryptTo256PtrAAD(FKey, @LNonce[0], 12, LPlainPtr, Integer(LBodyLen), @Result[0], 4, LDestPtr, Integer(LBodyLen + GCM_TAG));
      if LOk then
      begin
        Inc(FCounter);
        Exit;
      end
      else if Length(FKey) in [16, 32] then
        raise ESSHError.Create(sekCrypto, 'ssh cipher: gcm encrypt failed');
    end;
    // fallback pure pascal: header already in Result, only 2 Moves (CT+Tag) vs 3
    if not PurePascalAESGCMEncrypt(FKey, LNonce, ABodyPlain, Copy(Result, 0, 4), LCt, LTag) then
      raise ESSHError.Create(sekCrypto, 'ssh cipher: gcm encrypt failed');
    try
      if LBodyLen > 0 then
        Move(LCt[0], Result[4], LBodyLen);
      Move(LTag[0], Result[4 + LBodyLen], GCM_TAG);
    finally
      SecureZeroBytes(LCt);
      SecureZeroBytes(LTag);
    end;
    Inc(FCounter);
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
  LCt, LTag: TBytes;
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
    // fallback pure pascal with copies (2 Moves vs 3, AAD already header slice)
    LCt := Copy(AWire, 4, SizeInt(LCtLen));
    LTag := Copy(AWire, LWireLen - GCM_TAG, GCM_TAG);
    try
      if not PurePascalAESGCMDecrypt(FKey, LNonce, LCt, LTag, Copy(AWire, 0, 4), Result) then
        raise ESSHError.Create(sekCrypto, 'ssh cipher: gcm auth failed');
      Inc(FCounter);
    finally
      SecureZeroBytes(LTag);
      SecureZeroBytes(LCt);
    end;
  finally
    SecureZeroBytes(LNonce);
  end;
end;

{ ---- aes*-ctr + hmac-sha2-*-etm ---- }

{ AES-CTR 连续计数器流（跨包不重置），块级 XOR。
  keystream 单块生成走最快可用后端：AES-NI → ct64 → 朴素实现（aes192 兜底）。
  FKSOff 跨调用持久：部分消耗的计数器块在下次调用继续使用。
  值语义 record：零堆分配，跨包状态随外层宿主生命周期持久，Done 必清零。}
type
  TAesCtrStream = record
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
    procedure Init(const AKey, AIV: TBytes);
    procedure Done; inline;
    procedure XorInto(var AData: TBytes; AOffset, ACount: SizeUInt);
  end;

procedure TAesCtrStream.Init(const AKey, AIV: TBytes);
var
  LKey16: TAESNIBlock;
begin
  // single source secure zero via mem.secure (platform_secure_zero_memory), inline
  SecureZeroMemory(@FCtr[0], SizeOf(FCtr));
  SecureZeroMemory(@FKS[0], SizeOf(FKS));
  SecureZeroMemory(@FNiKey128[0], SizeOf(FNiKey128));
  SecureZeroMemory(@FNiKey256[0], SizeOf(FNiKey256));
  SecureZeroMemory(@FCt64Key, SizeOf(FCt64Key));
  SecureZeroMemory(@FExpanded[0], SizeOf(FExpanded));
  RequireLen(AIV, 16, 'ctr iv');
  FKSValid := False;   { 首次 XorInto 直接用 IV 作首块计数器，不先递增 }
  FKSOff := 0;
  FNr := 0;
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

procedure TAesCtrStream.Done;
begin
  // single source secure zero (same seam as Init), inline, prevents optimizer elision
  SecureZeroMemory(@FCtr[0], SizeOf(FCtr));
  SecureZeroMemory(@FKS[0], SizeOf(FKS));
  SecureZeroMemory(@FNiKey128[0], SizeOf(FNiKey128));
  SecureZeroMemory(@FNiKey256[0], SizeOf(FNiKey256));
  SecureZeroMemory(@FCt64Key, SizeOf(FCt64Key));
  SecureZeroMemory(@FExpanded[0], SizeOf(FExpanded));
  FKSOff := 0;
  FKSValid := False;
  FNr := 0;
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
  LDst: PByte;
  LRem, LChunk: SizeUInt;
begin
  if ACount = 0 then Exit;
  LDst := @AData[AOffset];
  LRem := ACount;
  // residual partial block from previous packet: bulk xor via bytes.ops single source
  if FKSValid and (FKSOff > 0) and (FKSOff < 16) then
  begin
    LChunk := SizeUInt(16 - FKSOff);
    if LChunk > LRem then LChunk := LRem;
    MemXor(LDst, @FKS[FKSOff], LChunk);
    Inc(LDst, LChunk);
    Inc(FKSOff, Integer(LChunk));
    Dec(LRem, LChunk);
    if LRem = 0 then Exit;
  end;
  while LRem > 0 do
  begin
    if (not FKSValid) or (FKSOff >= 16) then
    begin
      if FKSOff >= 16 then IncCounter;
      RefreshKS;
      FKSOff := 0;
    end;
    if (LRem >= 16) and (FKSOff = 0) then
    begin
      // bulk 16-byte keystream xor: QWord-batched via bytes.ops MemXor (2x QWord vs 16 branches)
      MemXor(LDst, @FKS[0], 16);
      Inc(LDst, 16);
      Dec(LRem, 16);
      FKSOff := 16;
    end else
    begin
      LChunk := SizeUInt(16 - FKSOff);
      if LChunk > LRem then LChunk := LRem;
      MemXor(LDst, @FKS[FKSOff], LChunk);
      Inc(LDst, LChunk);
      Inc(FKSOff, Integer(LChunk));
      Dec(LRem, LChunk);
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
    FWriteBuf: TBytes; { perf: cached buf reuse, single alloc }
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
  // perf: single SetLength wire packet, zero-copy Move + in-place CTR xor via bytes.ops MemXor, FWriteBuf reuse (1 Move vs 3)
  SetLength(Result, 4 + LBodyLen + LTagLen);
  PutU32BE(Result, 0, UInt32(LBodyLen)); // inline
  if LBodyLen > 0 then
    Move(ABodyPlain[0], Result[4], LBodyLen);
  FCtr.XorInto(Result, 4, LBodyLen); // encrypt ct in place, bulk MemXor single source
  // EtM: incremental HMAC over seq||len||ct without LMacInput alloc (zero-copy Write)
  LSeqBE[0] := Byte(ASeq shr 24);
  LSeqBE[1] := Byte((ASeq shr 16) and $FF);
  LSeqBE[2] := Byte((ASeq shr 8) and $FF);
  LSeqBE[3] := Byte(ASeq and $FF);
  LHasher := NewHMAC(FMacAlgo, FMacKey[0], SizeUInt(Length(FMacKey)));
  LHasher.Write(LSeqBE[0], 4);
  LHasher.Write(Result[0], 4);
  if LBodyLen > 0 then
    LHasher.Write(Result[4], LBodyLen);
  LTag := LHasher.SumBytes;
  Move(LTag[0], Result[4 + LBodyLen], LTagLen);
  // stability: LHasher refcounted interface, auto release; zero sensitive tag
  SecureZeroBytes(LTag);
  // wipe stack seq buf (secure single source)
  SecureZeroMemory(@LSeqBE[0], SizeOf(LSeqBE));
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
  { 先验 MAC（EtM：对密文 body 校验）零拷贝 incremental Write, 无 LMacInput 堆分配 }
  LSeqBE[0] := Byte(ASeq shr 24);
  LSeqBE[1] := Byte((ASeq shr 16) and $FF);
  LSeqBE[2] := Byte((ASeq shr 8) and $FF);
  LSeqBE[3] := Byte(ASeq and $FF);
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
var
  LStream: TAesCtrStream;
begin
  if Length(AInput) = 0 then
    Exit(nil);
  if (Length(AKey) <> 16) and (Length(AKey) <> 24) and (Length(AKey) <> 32) then
    raise ESSHError.Create(sekCrypto, 'ssh cipher: invalid aes key length');
  if Length(AIV) <> 16 then
    raise ESSHError.Create(sekCrypto, 'ssh cipher: invalid aes iv length');
  Result := Copy(AInput, 0, Length(AInput));
  LStream.Init(AKey, AIV);
  try
    LStream.XorInto(Result, 0, SizeUInt(Length(Result)));
  finally
    LStream.Done;
  end;
end;

end.
