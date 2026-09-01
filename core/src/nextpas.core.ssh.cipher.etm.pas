unit nextpas.core.ssh.cipher.etm;

{** nextpas.core.ssh.cipher.etm - aes*-ctr + hmac-sha2-*-etm。
 *  TAesCtrStream 单源 crypto.aesctr；EtM MAC 先验后解密；FWriteBuf move 零拷贝。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.ssh.cipher.intf;

function CreateCtrEtmSender(const ACipher, AMac: string; const AKey, AIV, AMacKey: TBytes): ISshPacketSender;
function CreateCtrEtmReceiver(const ACipher, AMac: string; const AKey, AIV, AMacKey: TBytes): ISshPacketReceiver;
function SshAesCtrCrypt(const AKey, AIV, AInput: TBytes): TBytes;

implementation

uses
  nextpas.core.bytes.binary,
  nextpas.core.bytes.ops,
  nextpas.core.crypto.aesctr,
  nextpas.core.crypto.constant_time,
  nextpas.core.crypto.errors,
  nextpas.core.crypto.hmac,
  nextpas.core.crypto.random,
  nextpas.core.hash.base,
  nextpas.core.hash.intf,
  nextpas.core.mem.secure,
  nextpas.core.ssh.cipher.base,
  nextpas.core.ssh.errors;

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
    FWriteBuf: TBytes;
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
  Result := FWriteBuf;
  FWriteBuf := nil; // move ownership single alloc zero-copy
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
  Result := FWriteBuf;
  FWriteBuf := nil;
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

function CreateCtrEtmSender(const ACipher, AMac: string; const AKey, AIV, AMacKey: TBytes): ISshPacketSender;
begin
  Result := TSshCtrEtmSender.Create(ACipher, AMac, AKey, AIV, AMacKey);
end;

function CreateCtrEtmReceiver(const ACipher, AMac: string; const AKey, AIV, AMacKey: TBytes): ISshPacketReceiver;
begin
  Result := TSshCtrEtmReceiver.Create(ACipher, AMac, AKey, AIV, AMacKey);
end;

function SshAesCtrCrypt(const AKey, AIV, AInput: TBytes): TBytes;
begin
  try
    Result := AesCtrCrypt(AKey, AIV, AInput);
  except
    on E: ECryptoError do
      raise ESSHError.Create(sekCrypto, E.Message);
  end;
end;

end.
