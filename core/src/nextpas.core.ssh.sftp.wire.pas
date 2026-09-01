unit nextpas.core.ssh.sftp.wire;

{** nextpas.core.ssh.sftp.wire - 通道线材（CHANNEL_DATA ↔ SFTP 包流重组器）。
 *
 * 单职责：把 TSshChannel 的流式 DATA 切为 4B 长度前缀 SFTP 包流。
 * 性能：容量倍增 + 偏移零拷贝，避免逐块 SetLength+Move 的 O(n²) 抖动；
 * inline 热路径，复用 bytes.ops 单源，不自实现 Move。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.ssh.sftp.base,
  nextpas.core.ssh.sftp.intf,
  nextpas.core.ssh.channel;

type
  TSshChannelWire = class(TInterfacedObject, ISftpWire)
  private
    FChan: TSshChannel;
    FBuf: TBytes;      { 容量缓冲，Length 为容量 }
    FLen: SizeUInt;    { 已写入逻辑长度 }
    FOff: SizeUInt;    { 已消费前缀偏移，零拷贝 }
    function BufferedLen: SizeUInt; inline;
    procedure EnsureCapacity(AAdditional: SizeUInt);
    procedure BufAppend(const AChunk: TBytes); inline;
    procedure CompactIfNeeded;
    function TakeFromBuffer(ACount: Integer): TBytes; inline;
  public
    constructor Create(AChannel: TSshChannel);
    destructor Destroy; override;
    procedure Send(const APacket: TBytes);
    function Recv(ATimeoutMs: Integer): TBytes;
  end;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops,
  nextpas.core.ssh.errors,
  nextpas.core.ssh.buffer;

constructor TSshChannelWire.Create(AChannel: TSshChannel);
begin
  inherited Create;
  FChan := AChannel;
  FOff := 0;
  FLen := 0;
end;

destructor TSshChannelWire.Destroy;
begin
  { 通道所有权在 TSshFileSystem：线材仅引用 }
  inherited Destroy;
end;

function TSshChannelWire.BufferedLen: SizeUInt; inline;
begin
  if FLen <= FOff then
    Exit(0);
  Result := FLen - FOff;
end;

procedure TSshChannelWire.EnsureCapacity(AAdditional: SizeUInt);
var
  LNeed, LBuffered: SizeUInt;
begin
  if AAdditional = 0 then
    Exit;
  // overflow guard: FLen + Additional wraps beyond High => exception via SetLength
  LNeed := FLen + AAdditional;
  if LNeed <= SizeUInt(Length(FBuf)) then
    Exit;
  // lazy reclaim: if buffered+additional fits capacity, compact instead of grow
  // avoids 4B freq Move churn; single CopyMem reclaims tail, zero extra alloc
  LBuffered := BufferedLen;
  if (FOff > 0) and (LBuffered + AAdditional <= SizeUInt(Length(FBuf))) then
  begin
    if LBuffered > 0 then
      CopyMem(@FBuf[0], @FBuf[FOff], LBuffered);
    FOff := 0;
    FLen := LBuffered;
    Exit;
  end;
  // geometric doubling: single source BytesEnsureCapacity, non-inline to avoid I-Cache bloat
  BytesEnsureCapacity(FBuf, LNeed);
end;

procedure TSshChannelWire.BufAppend(const AChunk: TBytes); inline;
var
  LChunkLen: SizeUInt;
begin
  LChunkLen := SizeUInt(Length(AChunk));
  if LChunkLen = 0 then
    Exit;
  EnsureCapacity(LChunkLen);
  // zero-copy CopyMem: single source bytes.ops/base.utils Move pattern, no extra alloc
  CopyMem(@FBuf[FLen], @AChunk[0], LChunkLen);
  Inc(FLen, LChunkLen);
end;

procedure TSshChannelWire.CompactIfNeeded;
var
  LBuffered, LCap: SizeUInt;
begin
  if FOff = 0 then
    Exit;
  LBuffered := BufferedLen;
  if LBuffered = 0 then
  begin
    FOff := 0;
    FLen := 0;
    Exit;
  end;
  LCap := SizeUInt(Length(FBuf));
  // lazy compact: raise threshold to avoid 4B freq Move churn;
  // 32KB absolute or (8KB + half capacity), single CopyMem, non-inline to avoid I-Cache bloat
  // shrink only if hugely over-allocated (>8x + 64KB), keep capacity otherwise
  if (FOff > 32768) or ((FOff > 8192) and (FOff > LCap div 2)) then
  begin
    CopyMem(@FBuf[0], @FBuf[FOff], LBuffered);
    FOff := 0;
    FLen := LBuffered;
    // keep capacity (Length(FBuf) stays), avoid shrink-realloc churn; logical FLen trimmed
    if LCap > LBuffered * 8 + 65536 then
      SetLength(FBuf, LBuffered * 2 + 64);
  end;
end;

procedure TSshChannelWire.Send(const APacket: TBytes);
var
  LW: TsshWriter;
begin
  LW := TsshWriter.Create(4 + Length(APacket));
  try
    LW.PutUInt32(UInt32(Length(APacket)));
    LW.PutRaw(APacket);
    FChan.SendData(LW.ToBytes);
  finally
    LW.Free;
  end;
end;

function TSshChannelWire.TakeFromBuffer(ACount: Integer): TBytes; inline;
begin
  SetLength(Result, ACount);
  if ACount > 0 then
    CopyMem(@Result[0], @FBuf[FOff], SizeUInt(ACount));
  Inc(FOff, SizeUInt(ACount));
  CompactIfNeeded;
end;

function TSshChannelWire.Recv(ATimeoutMs: Integer): TBytes;
var
  LChunk: TBytes;
  LExt: Boolean;
  LLen: UInt32;
begin
  while BufferedLen < 4 do
  begin
    if not FChan.PumpData(LChunk, LExt) then
      raise ESSHError.Create(sekIO, 'sftp: channel closed by peer');
    BufAppend(LChunk);
  end;
  LLen := (UInt32(FBuf[FOff]) shl 24) or (UInt32(FBuf[FOff + 1]) shl 16) or
    (UInt32(FBuf[FOff + 2]) shl 8) or UInt32(FBuf[FOff + 3]);
  if (LLen < 1) or (LLen > SFTP_MAX_PACKET_SIZE) then
    raise ESSHError.Create(sekProtocol,
      'sftp: unreasonable packet length ' + IntToStr(LLen));
  while BufferedLen < SizeUInt(4 + LLen) do
  begin
    if not FChan.PumpData(LChunk, LExt) then
      raise ESSHError.Create(sekIO, 'sftp: channel closed mid-packet');
    BufAppend(LChunk);
  end;
  Inc(FOff, 4);
  CompactIfNeeded;
  Result := TakeFromBuffer(Integer(LLen));
end;

end.
