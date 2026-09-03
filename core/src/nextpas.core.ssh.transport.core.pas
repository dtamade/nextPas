unit nextpas.core.ssh.transport.core;

{** nextpas.core.ssh - 传输层纯内存编解码核（RFC 4253 §6）。
 *
 * 单源职责：
 *  - padding 对齐公式（OpenSSH packet.c：AEAD/EtM 时 len-=aadlen，packlen%block==0）
 *  - cipher Protect/Unprotect + 压缩 + 序列号递增 + rekey 计数/阈值
 *  - ShouldRekey 按字节/时间/序列号阈值判断
 *
 * 被 nextpas.core.ssh.transport / transport.async 薄包装复用；纯内存，不触 IO。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.cipher,
  nextpas.core.ssh.compress,
  nextpas.core.ssh.kex,
  nextpas.core.ssh.rekey;

const
  SSH_SEQ_REKEY_THRESHOLD = UInt32($FFFFFF00);

type
  TSshTransportCore = class
  private
    FSender: ISshPacketSender;
    FReceiver: ISshPacketReceiver;
    FSendSeq: UInt32;
    FRecvSeq: UInt32;
    FRekey: TSshRekeyPolicy;
    FCompressor: ISshCompressor;
    FDecompressor: ISshCompressor;
    FNegCompCs: string;
    FNegCompSc: string;
    FCompressEnabled: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    procedure SetNegotiatedCompression(const ANeg: TSshNegotiated);
    procedure EnableCompression;
    function IsCompressionEnabled: Boolean;

    procedure ConfigureRekey(ABytes: UInt64; AIntervalMs: Integer);
    function ShouldRekey(AEncrypted: Boolean): Boolean;
    procedure ResetRekeyCounters;

    procedure ApplyNewKeys(const ANegotiated: TSshNegotiated;
      const AIvCs, AKeyCs, AMacCs, AIvSc, AKeySc, AMacSc: TBytes);

    function EncodePacket(const APayload: TBytes): TBytes;
    function DecodePacket(const AWire: TBytes): TBytes;

    function BodyLengthFromHeader(const AHeader: TBytes): UInt32;
    function TrailerSize(ABodyLen: UInt32): UInt32;

    property SendSeq: UInt32 read FSendSeq write FSendSeq;
    property RecvSeq: UInt32 read FRecvSeq write FRecvSeq;
    property Sender: ISshPacketSender read FSender;
    property Receiver: ISshPacketReceiver read FReceiver;
  end;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.crypto.random;

constructor TSshTransportCore.Create;
begin
  inherited Create;
  FSender := CreateSshPacketSender('', '', nil, nil, nil);
  FReceiver := CreateSshPacketReceiver('', '', nil, nil, nil);
  FRekey.Init(SSH_REKEY_BYTES, SSH_REKEY_INTERVAL_MS);
  FCompressEnabled := False;
end;

destructor TSshTransportCore.Destroy;
begin
  FCompressor := nil;
  FDecompressor := nil;
  inherited Destroy;
end;

procedure TSshTransportCore.SetNegotiatedCompression(const ANeg: TSshNegotiated);
begin
  FNegCompCs := ANeg.CompCs;
  FNegCompSc := ANeg.CompSc;
  FCompressEnabled := False;
  if (FNegCompCs = SSH_COMP_ZLIB) or (FNegCompSc = SSH_COMP_ZLIB) then
    EnableCompression
  else if (FNegCompCs = SSH_COMP_NONE) and (FNegCompSc = SSH_COMP_NONE) then
  begin
    FCompressor := nil;
    FDecompressor := nil;
  end;
end;

procedure TSshTransportCore.EnableCompression;
begin
  if FCompressEnabled then Exit;
  if (FNegCompCs = SSH_COMP_NONE) and (FNegCompSc = SSH_COMP_NONE) then Exit;
  if (FCompressor = nil) or (FDecompressor = nil) then
  begin
    FCompressor := CreateSshZlibCompressor;
    FDecompressor := FCompressor;
  end;
  FCompressEnabled := True;
end;

function TSshTransportCore.IsCompressionEnabled: Boolean;
begin
  Result := FCompressEnabled;
end;

procedure TSshTransportCore.ConfigureRekey(ABytes: UInt64; AIntervalMs: Integer);
begin
  FRekey.Init(ABytes, AIntervalMs);
end;

function TSshTransportCore.ShouldRekey(AEncrypted: Boolean): Boolean;
begin
  Result := FRekey.ShouldRekey(AEncrypted);
  if not Result and AEncrypted then
    if (FSendSeq >= SSH_SEQ_REKEY_THRESHOLD) or (FRecvSeq >= SSH_SEQ_REKEY_THRESHOLD) then
      Result := True;
end;

procedure TSshTransportCore.ResetRekeyCounters;
begin
  FRekey.Reset;
end;

procedure TSshTransportCore.ApplyNewKeys(const ANegotiated: TSshNegotiated;
  const AIvCs, AKeyCs, AMacCs, AIvSc, AKeySc, AMacSc: TBytes);
begin
  FSender := CreateSshPacketSender(ANegotiated.EncCs, ANegotiated.MacCs,
    AKeyCs, AIvCs, AMacCs);
  FReceiver := CreateSshPacketReceiver(ANegotiated.EncSc, ANegotiated.MacSc,
    AKeySc, AIvSc, AMacSc);
  ResetRekeyCounters;
end;

function TSshTransportCore.EncodePacket(const APayload: TBytes): TBytes;
var
  LOut: TBytes;
  LPayloadLen, LPad, LBodyLen, LAad: SizeUInt;
  LBlock: Integer;
  LBody: TBytes;
begin
  LOut := APayload;
  if FCompressEnabled and (FCompressor <> nil) and (FNegCompCs <> SSH_COMP_NONE) then
    LOut := FCompressor.Compress(APayload);
  LPayloadLen := SizeUInt(Length(LOut));
  LBlock := FSender.PaddingBlock;
  LAad := SizeUInt(FSender.AadLen);
  // 单源公式：OpenSSH packet.c 发送端先 len-=aadlen 再算 padlen
  LPad := SizeUInt(LBlock) - ((SizeUInt(4 + 1) + LPayloadLen - LAad) mod SizeUInt(LBlock));
  if LPad < SSH_MIN_PADDING then
    Inc(LPad, SizeUInt(LBlock));
  LBodyLen := 1 + LPayloadLen + LPad;
  SetLength(LBody, LBodyLen);
  LBody[0] := Byte(LPad);
  if LPayloadLen > 0 then
    BytesCopy(@LBody[1], @LOut[0], LPayloadLen); // perf: inline single Move via bytes.ops.BytesCopy single source (zero-copy, INV-5)
  if not SecureRandomBytes(@LBody[1 + LPayloadLen], Integer(LPad)) then
    raise ESSHError.Create(sekCrypto, 'ssh transport: SecureRandom failed');
  Result := FSender.Protect(LBody, FSendSeq);
  Inc(FSendSeq);
  FRekey.Account(UInt64(Length(APayload)));
end;

function TSshTransportCore.DecodePacket(const AWire: TBytes): TBytes;
var
  LBody: TBytes;
  LPadLen: Byte;
  LPayloadLen: UInt32;
begin
  LBody := FReceiver.Unprotect(FRecvSeq, AWire);
  Inc(FRecvSeq);
  if Length(LBody) < 1 then
    raise ESSHError.Create(sekProtocol, 'ssh transport: bad padding');
  LPadLen := LBody[0];
  if (LPadLen < SSH_MIN_PADDING) or (UInt32(LPadLen) >= UInt32(Length(LBody))) then
    raise ESSHError.Create(sekProtocol, 'ssh transport: bad padding length');
  LPayloadLen := UInt32(Length(LBody)) - 1 - UInt32(LPadLen);
  Result := Copy(LBody, 1, SizeInt(LPayloadLen));
  if FCompressEnabled and (FDecompressor <> nil) and (FNegCompSc <> SSH_COMP_NONE) then
  try
    Result := FDecompressor.Decompress(Result);
  except
    on E: ESSHError do
    begin
      try if FDecompressor <> nil then FDecompressor.Reset; except end;
      raise;
    end;
    on E: Exception do
    begin
      try if FDecompressor <> nil then FDecompressor.Reset; except end;
      raise ESSHError.Create(sekProtocol, E.Message);
    end;
  end;
  FRekey.Account(UInt64(Length(Result)));
end;

function TSshTransportCore.BodyLengthFromHeader(const AHeader: TBytes): UInt32;
begin
  Result := FReceiver.BodyLengthFromHeader(FRecvSeq, AHeader);
end;

function TSshTransportCore.TrailerSize(ABodyLen: UInt32): UInt32;
begin
  Result := FReceiver.TrailerSize(ABodyLen);
end;

end.
