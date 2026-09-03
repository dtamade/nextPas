unit nextpas.core.ssh.cipher.gcm;

{** nextpas.core.ssh.cipher.gcm - aes*-gcm@openssh.com。
 *  单源 bytes.ops / bytes.binary；FWriteBuf move 零拷贝；栈上 12B nonce 零堆分配。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.ssh.cipher.intf;

function CreateGcmSender(const AKey, AIV: TBytes): ISshPacketSender;
function CreateGcmReceiver(const AKey, AIV: TBytes): ISshPacketReceiver;

implementation

uses
  nextpas.core.bytes.binary,
  nextpas.core.bytes.ops,
  nextpas.core.crypto.aesgcm,
  nextpas.core.crypto.aesni,
  nextpas.core.crypto.random,
  nextpas.core.mem.secure,
  nextpas.core.ssh.cipher.base,
  nextpas.core.ssh.errors;

type
  TGcmNonceBuf = array[0..11] of Byte;

procedure FillGcmNonce(var ANonce: TGcmNonceBuf; const ABaseIV: TGcmNonceBuf; ACounter: UInt64); inline;
begin
  Move(ABaseIV[0], ANonce[0], 12);
  WriteUInt32BE(PByte(@ANonce[8]), UInt32(ACounter));
end;

type
  TSshGcmSender = class(TInterfacedObject, ISshPacketSender)
  private
    FKey: TBytes;
    FBaseIV: TGcmNonceBuf;
    FCounter: UInt64;
    FWriteBuf: TBytes;
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
    FBaseIV: TGcmNonceBuf;
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
  Move(AIV[0], FBaseIV[0], 12);
  FCounter := 1;
end;

destructor TSshGcmSender.Destroy;
begin
  SecureZeroBytes(FKey);
  SecureZeroMemory(@FBaseIV[0], SizeOf(FBaseIV));
  SecureZeroBytes(FWriteBuf);
  inherited;
end;

function TSshGcmSender.PaddingBlock: Integer;
begin
  Result := AES_PAD_BLOCK;
end;

function TSshGcmSender.AadLen: Integer;
begin
  Result := 4;
end;

function TSshGcmSender.Protect(const ABodyPlain: TBytes; ASeq: UInt32): TBytes;
var
  LNonce: TGcmNonceBuf;
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
  FillGcmNonce(LNonce, FBaseIV, FCounter);
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
        Result := FWriteBuf;
        FWriteBuf := nil; // move ownership single alloc zero-copy
        Exit;
      end
      else if Length(FKey) in [16, 32] then
        raise ESSHError.Create(sekCrypto, 'ssh cipher: gcm encrypt failed');
    end;
    if not PurePascalAESGCMEncryptPtrAAD(FKey, @LNonce[0], 12, LPlainPtr, Integer(LBodyLen), @FWriteBuf[0], 4, LDestPtr, Integer(LBodyLen + GCM_TAG)) then
      raise ESSHError.Create(sekCrypto, 'ssh cipher: gcm encrypt failed');
    Inc(FCounter);
    Result := FWriteBuf;
    FWriteBuf := nil; // move ownership
  finally
    SecureZeroMemory(@LNonce[0], SizeOf(LNonce));
  end;
end;

function TSshGcmSender.ProtectPayload(const APayload: TBytes; APadLen: SizeUInt; ASeq: UInt32): TBytes;
var
  LNonce: TGcmNonceBuf;
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
  FillGcmNonce(LNonce, FBaseIV, FCounter);
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
        Result := FWriteBuf;
        FWriteBuf := nil;
        Exit;
      end
      else if Length(FKey) in [16, 32] then
        raise ESSHError.Create(sekCrypto, 'ssh cipher: gcm encrypt failed');
    end;
    if not PurePascalAESGCMEncryptPtrAAD(FKey, @LNonce[0], 12, @FWriteBuf[4], Integer(LBodyLen), @FWriteBuf[0], 4, @FWriteBuf[4], Integer(LBodyLen + GCM_TAG)) then
      raise ESSHError.Create(sekCrypto, 'ssh cipher: gcm encrypt failed');
    Inc(FCounter);
    Result := FWriteBuf;
    FWriteBuf := nil;
  finally
    SecureZeroMemory(@LNonce[0], SizeOf(LNonce));
  end;
end;

constructor TSshGcmReceiver.Create(const AKey, AIV: TBytes);
begin
  inherited Create;
  RequireLen(AIV, 12, 'gcm iv');
  FKey := Copy(AKey, 0, Length(AKey));
  Move(AIV[0], FBaseIV[0], 12);
  FCounter := 1;
end;

destructor TSshGcmReceiver.Destroy;
begin
  SecureZeroBytes(FKey);
  SecureZeroMemory(@FBaseIV[0], SizeOf(FBaseIV));
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
  LNonce: TGcmNonceBuf;
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
  FillGcmNonce(LNonce, FBaseIV, FCounter);
  try
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
    SecureZeroMemory(@LNonce[0], SizeOf(LNonce));
  end;
end;

function CreateGcmSender(const AKey, AIV: TBytes): ISshPacketSender;
begin
  Result := TSshGcmSender.Create(AKey, AIV);
end;

function CreateGcmReceiver(const AKey, AIV: TBytes): ISshPacketReceiver;
begin
  Result := TSshGcmReceiver.Create(AKey, AIV);
end;

end.
