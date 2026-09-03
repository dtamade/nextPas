unit nextpas.core.ssh.cipher.none;

{** nextpas.core.ssh.cipher.none - none 编解码器（握手前明文帧）。
 *  零密钥、零校验；仅剥离/追加长度字段。单源 bytes.binary。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.ssh.cipher.intf;

function CreateNoneSender: ISshPacketSender;
function CreateNoneReceiver: ISshPacketReceiver;

implementation

uses
  nextpas.core.bytes.binary,
  nextpas.core.bytes.ops,
  nextpas.core.crypto.random,
  nextpas.core.mem.secure,
  nextpas.core.ssh.base,
  nextpas.core.ssh.cipher.base,
  nextpas.core.ssh.errors;

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
  Result := Copy(AWire, 4, SizeInt(Length(AWire)) - 4);
end;

function CreateNoneSender: ISshPacketSender;
begin
  Result := TSshNoneSender.Create;
end;

function CreateNoneReceiver: ISshPacketReceiver;
begin
  Result := TSshNoneReceiver.Create;
end;

end.
