unit nextpas.core.ssh.cipher.chacha;

{** nextpas.core.ssh.cipher.chacha - chacha20-poly1305@openssh.com。
 *  单源 bytes.ops / bytes.binary；FWriteBuf move 语义消除 COW 隐藏拷贝。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.ssh.cipher.intf;

function CreateChachaSender(const AKeyMaterial: TBytes): ISshPacketSender;
function CreateChachaReceiver(const AKeyMaterial: TBytes): ISshPacketReceiver;

implementation

uses
  nextpas.core.bytes.binary,
  nextpas.core.bytes.ops,
  nextpas.core.crypto.chacha20poly1305,
  nextpas.core.crypto.constant_time,
  nextpas.core.crypto.random,
  nextpas.core.mem.secure,
  nextpas.core.ssh.cipher.base,
  nextpas.core.ssh.errors;

function SeqBytes(ASeq: UInt32): TBytes; inline;
begin
  Result := nil;
  SetLength(Result, 4);
  PutU32BE(Result, 0, ASeq);
end;

function ChachaNonce(ASeq: UInt32): TBytes; inline;
begin
  Result := nil;
  SetLength(Result, 12);
  FillChar(Result[0], 12, 0);
  WriteUInt32BE(PByte(@Result[8]), ASeq);
end;

type
  TSshChachaSender = class(TInterfacedObject, ISshPacketSender)
  private
    FMainKey: TBytes;
    FHeaderKey: TBytes;
    FWriteBuf: TBytes;
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
  Result := 4;
end;

function TSshChachaSender.Protect(const ABodyPlain: TBytes; ASeq: UInt32): TBytes;
var
  LNonce: array[0..11] of Byte;
  LHeaderBlock: array[0..63] of Byte;
  LPolyBlock: array[0..63] of Byte;
  LBodyLen: SizeUInt;
  LEncLenBE: UInt32;
begin
  LBodyLen := SizeUInt(Length(ABodyPlain));
  BytesEnsureCapacity(FWriteBuf, 4 + LBodyLen + CHACHA_TAG);
  SetLength(FWriteBuf, 4 + LBodyLen + CHACHA_TAG);
  FillChar(LNonce, SizeOf(LNonce), 0);
  WriteUInt32BE(PByte(@LNonce[8]), ASeq);
  ChaCha20BlockToBuf(FHeaderKey, @LNonce[0], 0, @LHeaderBlock[0]);
  try
    LEncLenBE := UInt32(LBodyLen) xor ReadUInt32BE(PByte(@LHeaderBlock[0]));
    PutU32BE(FWriteBuf, 0, LEncLenBE);
    if LBodyLen > 0 then
      if not ChaCha20XorToBuf(FMainKey, @LNonce[0], 1, @ABodyPlain[0], Integer(LBodyLen), @FWriteBuf[4]) then
        raise ESSHError.Create(sekCrypto, 'ssh cipher: chacha encrypt failed');
    ChaCha20BlockToBuf(FMainKey, @LNonce[0], 0, @LPolyBlock[0]);
    try
      Poly1305RawSpansDirect(@LPolyBlock[0], [TByteSpan.Create(@FWriteBuf[0], 4), TByteSpan.Create(@FWriteBuf[4], LBodyLen)], PByte(@FWriteBuf[4 + LBodyLen]));
      Result := FWriteBuf;
      FWriteBuf := nil; // move ownership single alloc zero-copy; prevent next BytesEnsureCapacity COW full copy
    finally
      SecureZeroMemory(@LPolyBlock[0], SizeOf(LPolyBlock));
    end;
  finally
    SecureZeroMemory(@LHeaderBlock[0], SizeOf(LHeaderBlock));
    SecureZeroMemory(@LNonce[0], SizeOf(LNonce));
  end;
end;

function TSshChachaSender.ProtectPayload(const APayload: TBytes; APadLen: SizeUInt; ASeq: UInt32): TBytes;
var
  LNonce: array[0..11] of Byte;
  LHeaderBlock: array[0..63] of Byte;
  LPolyBlock: array[0..63] of Byte;
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
  FillChar(LNonce, SizeOf(LNonce), 0);
  WriteUInt32BE(PByte(@LNonce[8]), ASeq);
  ChaCha20BlockToBuf(FHeaderKey, @LNonce[0], 0, @LHeaderBlock[0]);
  try
    LEncLenBE := UInt32(LBodyLen) xor ReadUInt32BE(PByte(@LHeaderBlock[0]));
    PutU32BE(FWriteBuf, 0, LEncLenBE);
    if LBodyLen > 0 then
      if not ChaCha20XorToBuf(FMainKey, @LNonce[0], 1, @FWriteBuf[4], Integer(LBodyLen), @FWriteBuf[4]) then
        raise ESSHError.Create(sekCrypto, 'ssh cipher: chacha encrypt failed');
    ChaCha20BlockToBuf(FMainKey, @LNonce[0], 0, @LPolyBlock[0]);
    try
      Poly1305RawSpansDirect(@LPolyBlock[0], [TByteSpan.Create(@FWriteBuf[0], 4), TByteSpan.Create(@FWriteBuf[4], LBodyLen)], PByte(@FWriteBuf[4 + LBodyLen]));
      Result := FWriteBuf;
      FWriteBuf := nil; // move ownership single alloc
    finally
      SecureZeroMemory(@LPolyBlock[0], SizeOf(LPolyBlock));
    end;
  finally
    SecureZeroMemory(@LHeaderBlock[0], SizeOf(LHeaderBlock));
    SecureZeroMemory(@LNonce[0], SizeOf(LNonce));
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
  LNonce: array[0..11] of Byte;
  LBlock: array[0..63] of Byte;
begin
  FillChar(LNonce, SizeOf(LNonce), 0);
  WriteUInt32BE(PByte(@LNonce[8]), ASeq);
  ChaCha20BlockToBuf(FHeaderKey, @LNonce[0], 0, @LBlock[0]);
  try
    Result := ReadUInt32BE(PByte(@AHeader[0])) xor ReadUInt32BE(PByte(@LBlock[0]));
  finally
    SecureZeroMemory(@LBlock[0], SizeOf(LBlock));
    SecureZeroMemory(@LNonce[0], SizeOf(LNonce));
  end;
end;

function TSshChachaReceiver.TrailerSize(ABodyLen: UInt32): UInt32;
begin
  Result := ABodyLen + CHACHA_TAG;
end;

function TSshChachaReceiver.Unprotect(ASeq: UInt32; const AWire: TBytes): TBytes;
var
  LNonce: array[0..11] of Byte;
  LPolyBlock: array[0..63] of Byte;
  LExpected: array[0..15] of Byte;
  LWireLen, LCtLen: SizeUInt;
begin
  LWireLen := SizeUInt(Length(AWire));
  if LWireLen < 4 + CHACHA_TAG then
    raise ESSHError.Create(sekProtocol, 'ssh cipher: chacha packet truncated');
  LCtLen := LWireLen - 4 - CHACHA_TAG;
  FillChar(LNonce, SizeOf(LNonce), 0);
  WriteUInt32BE(PByte(@LNonce[8]), ASeq);
  try
    ChaCha20BlockToBuf(FMainKey, @LNonce[0], 0, @LPolyBlock[0]);
    try
      Poly1305RawSpansDirect(@LPolyBlock[0],
        [TByteSpan.Create(@AWire[0], 4), TByteSpan.Create(@AWire[4], LCtLen)], @LExpected[0]);
      if TConstantTime.CompareBuffer(@LExpected[0], @AWire[LWireLen - CHACHA_TAG], CHACHA_TAG) <> 1 then
        raise ESSHError.Create(sekCrypto, 'ssh cipher: chacha AEAD verify failed');
      SetLength(Result, LCtLen);
      if LCtLen > 0 then
        if not ChaCha20XorToBuf(FMainKey, @LNonce[0], 1, @AWire[4], Integer(LCtLen), @Result[0]) then
          raise ESSHError.Create(sekCrypto, 'ssh cipher: chacha decrypt failed');
    finally
      SecureZeroMemory(@LExpected[0], SizeOf(LExpected));
      SecureZeroMemory(@LPolyBlock[0], SizeOf(LPolyBlock));
    end;
  finally
    SecureZeroMemory(@LNonce[0], SizeOf(LNonce));
  end;
end;

function CreateChachaSender(const AKeyMaterial: TBytes): ISshPacketSender;
begin
  Result := TSshChachaSender.Create(AKeyMaterial);
end;

function CreateChachaReceiver(const AKeyMaterial: TBytes): ISshPacketReceiver;
begin
  Result := TSshChachaReceiver.Create(AKeyMaterial);
end;

end.
