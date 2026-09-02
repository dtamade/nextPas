unit nextpas.core.ssh.transport.core;

{** nextpas.core.ssh - 传输层纯内存编解码核（RFC 4253 §6）。
 *
 * 单源职责：
 *  - padding 对齐（OpenSSH packet.c：AEAD/EtM len-=aadlen，packlen%block==0；FPadBlock/FAadLen 缓存零虚调用）
 *  - EncodePacket 职责拆分：CompressIfNeeded / CalcPadLen inline + ProtectPayload 单次分配零拷贝
 *  - ShouldRekey 按字节/时间/序列号阈值（record inline，TInstant 单源）
 *
 * 被 nextpas.core.ssh.transport / transport.async 薄包装复用；纯内存，不触 IO。
 * 通道窗口回补不在此核，统一由 nextpas.core.flow.window 单源（FWindow.Consume/Grant inline
 * 零堆分配，低水位 div 2），channel / channel.async / sftp.async 100% 复用。
 * perf: CacheSenderParams/CalcPadLen/CompressIfNeeded inline 零虚调用，ProtectPayload 单次 Move 零拷贝，bytes.ops 单源，外联重路径零 I-Cache 膨胀；稳定性：SecureRandom 异常不泄漏，Seq/Account 仅成功后递增。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.ssh.base,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.cipher,
  nextpas.core.ssh.compress,
  nextpas.core.ssh.kex,
  nextpas.core.net.maintenance.rekey;

const
  SSH_SEQ_REKEY_THRESHOLD = UInt32($FFFFFF00);

type
  TSshTransportCore = class
  private
    FSender: ISshPacketSender;
    FReceiver: ISshPacketReceiver;
    FSendSeq: UInt32;
    FRecvSeq: UInt32;
    FRekey: TRekeyPolicy;
    FCompressor: ISshCompressor;
    FDecompressor: ISshCompressor;
    FNegCompCs: string;
    FNegCompSc: string;
    FCompressEnabled: Boolean;
    FPadBlock: Integer;
    FAadLen: Integer;
    procedure CacheSenderParams; inline;
    function CalcPadLen(APayloadLen: SizeUInt): SizeUInt; inline;
    function CompressIfNeeded(const APayload: TBytes): TBytes; inline;
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
  nextpas.core.exception;

constructor TSshTransportCore.Create;
begin
  inherited Create;
  FSender := CreateSshPacketSender('', '', nil, nil, nil);
  FReceiver := CreateSshPacketReceiver('', '', nil, nil, nil);
  CacheSenderParams;
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
  CacheSenderParams;
  ResetRekeyCounters;
end;

procedure TSshTransportCore.CacheSenderParams; inline;
begin
  FPadBlock := FSender.PaddingBlock;
  FAadLen := FSender.AadLen;
end;

function TSshTransportCore.CalcPadLen(APayloadLen: SizeUInt): SizeUInt; inline;
begin
  // 单源公式：OpenSSH packet.c 先 len-=aadlen 再算 padlen；FPadBlock/FAadLen 缓存零虚调用
  Result := SizeUInt(FPadBlock) - ((SizeUInt(4 + 1) + APayloadLen - SizeUInt(FAadLen)) mod SizeUInt(FPadBlock));
  if Result < SSH_MIN_PADDING then
    Inc(Result, SizeUInt(FPadBlock));
end;

function TSshTransportCore.CompressIfNeeded(const APayload: TBytes): TBytes; inline;
begin
  if FCompressEnabled and (FCompressor <> nil) and (FNegCompCs <> SSH_COMP_NONE) then
    Result := FCompressor.Compress(APayload)
  else
    Result := APayload;
end;

function TSshTransportCore.EncodePacket(const APayload: TBytes): TBytes;
var
  LOut: TBytes;
  LPad: SizeUInt;
begin
  LOut := CompressIfNeeded(APayload);
  LPad := CalcPadLen(SizeUInt(Length(LOut)));
  Result := FSender.ProtectPayload(LOut, LPad, FSendSeq);
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
