unit nextpas.core.bytes.framing;

{** 4B 长度前缀帧缓冲：BytesEnsureCapacity 几何 + FOff 零拷贝 + 16KB/4KB 懒压实（长流水线季窗 quarter-cap 回收）。 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.bytes.base,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.binary;

const
  WIRE_BUFFER_COMPACT_OFFSET_ABSOLUTE = SizeUInt(16384);
  WIRE_BUFFER_COMPACT_OFFSET_HALF = SizeUInt(4096);
  WIRE_BUFFER_DEFAULT_MAX = SizeUInt(256 * 1024);

type
  TWireBuffer = record
  private
    FBuf: TBytes;
    FLen: SizeUInt;
    FOff: SizeUInt;
    procedure EnsureCapacity(AAdditional: SizeUInt);
    procedure CompactIfNeeded;
  public
    procedure Clear; inline;
    procedure Append(const AChunk: TBytes); inline;
    procedure AppendRaw(const APtr: PByte; ALength: SizeUInt); inline;
    function BufferedLen: SizeUInt; inline;
    function Capacity: SizeUInt; inline;
    function BufferedData: PByte; inline;
    function HasHeader: Boolean; inline;
    function HasCompleteFrame(const AMax: SizeUInt = WIRE_BUFFER_DEFAULT_MAX): Boolean; inline;
    function TryPeekFrameLength(out ALen: UInt32; const AMax: SizeUInt = WIRE_BUFFER_DEFAULT_MAX): Boolean; inline;
    function TryTakeFrame(out AFrame: TBytes; const AMax: SizeUInt = WIRE_BUFFER_DEFAULT_MAX): Boolean;
    function TakeFrame(const AMax: SizeUInt = WIRE_BUFFER_DEFAULT_MAX): TBytes;
    procedure Compact; inline;
  end;

function WireEncodeFrame(const APayload: TBytes): TBytes; inline;
procedure WireAppendEncoded(var ADest: TBytes; const APayload: TBytes); inline;

implementation

procedure TWireBuffer.Clear; inline;
begin
  FOff := 0;
  FLen := 0;
end;

function TWireBuffer.BufferedLen: SizeUInt; inline;
begin
  if FLen <= FOff then
    Exit(0);
  Result := FLen - FOff;
end;

function TWireBuffer.Capacity: SizeUInt; inline;
begin
  Result := SizeUInt(Length(FBuf));
end;

function TWireBuffer.BufferedData: PByte; inline;
begin
  if BufferedLen = 0 then
    Exit(nil);
  Result := PByte(@FBuf[FOff]);
end;

function TWireBuffer.HasHeader: Boolean; inline;
begin
  Result := BufferedLen >= 4;
end;

function TWireBuffer.HasCompleteFrame(const AMax: SizeUInt): Boolean; inline;
var
  LLen: UInt32;
begin
  if not TryPeekFrameLength(LLen, AMax) then
    Exit(False);
  Result := BufferedLen >= SizeUInt(4 + LLen);
end;

function TWireBuffer.TryPeekFrameLength(out ALen: UInt32; const AMax: SizeUInt): Boolean; inline;
var
  LLen: UInt32;
begin
  ALen := 0;
  if BufferedLen < 4 then
    Exit(False);
  LLen := ReadUInt32BE(PByte(@FBuf[FOff]));
  if (LLen < 1) or (LLen > AMax) then
    Exit(False);
  ALen := LLen;
  Result := True;
end;

procedure TWireBuffer.EnsureCapacity(AAdditional: SizeUInt);
var
  LNeed, LBuffered: SizeUInt;
begin
  if AAdditional = 0 then
    Exit;
  LNeed := FLen + AAdditional;
  if LNeed <= SizeUInt(Length(FBuf)) then
    Exit;
  LBuffered := BufferedLen;
  if (FOff > 0) and (LBuffered + AAdditional <= SizeUInt(Length(FBuf))) then
  begin
    if LBuffered > 0 then
      Move(FBuf[FOff], FBuf[0], LBuffered);
    FOff := 0;
    FLen := LBuffered;
    Exit;
  end;
  BytesEnsureCapacity(FBuf, LNeed);
end;

procedure TWireBuffer.Append(const AChunk: TBytes); inline;
var
  LChunkLen: SizeUInt;
begin
  LChunkLen := SizeUInt(Length(AChunk));
  if LChunkLen = 0 then
    Exit;
  EnsureCapacity(LChunkLen);
  Move(AChunk[0], FBuf[FLen], LChunkLen);
  Inc(FLen, LChunkLen);
end;

procedure TWireBuffer.AppendRaw(const APtr: PByte; ALength: SizeUInt); inline;
begin
  if (APtr = nil) or (ALength = 0) then
    Exit;
  EnsureCapacity(ALength);
  Move(APtr^, FBuf[FLen], ALength);
  Inc(FLen, ALength);
end;

procedure TWireBuffer.CompactIfNeeded;
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
  // 长流水线残留空洞：16KB 绝对阈值 + 4KB/quarter-cap 季节回补，避免 32KB 阈值长期持洞导致尾部余量假缺与终局大 Move
  if (FOff > WIRE_BUFFER_COMPACT_OFFSET_ABSOLUTE) or (FOff > WIRE_BUFFER_COMPACT_OFFSET_HALF) or (FOff > LCap div 4) then
  begin
    Move(FBuf[FOff], FBuf[0], LBuffered);
    FOff := 0;
    FLen := LBuffered;
    if LCap > LBuffered * 8 + 65536 then
      SetLength(FBuf, LBuffered * 2 + 64);
  end;
end;

procedure TWireBuffer.Compact; inline;
begin
  CompactIfNeeded;
end;

function TWireBuffer.TryTakeFrame(out AFrame: TBytes; const AMax: SizeUInt): Boolean;
var
  LLen: UInt32;
begin
  AFrame := nil;
  if not TryPeekFrameLength(LLen, AMax) then
    Exit(False);
  if BufferedLen < SizeUInt(4 + LLen) then
    Exit(False);
  // 单包单次 Move+单次压实：先零拷贝取载荷再一次性推进 FOff，避免 Inc(4)+Compact 与 Move+Compact 双压实双 Move
  SetLength(AFrame, LLen);
  if LLen > 0 then
    Move(FBuf[FOff + 4], AFrame[0], LLen);
  Inc(FOff, SizeUInt(4 + LLen));
  if BufferedLen = 0 then
  begin
    FOff := 0;
    FLen := 0;
  end
  else
    CompactIfNeeded;
  Result := True;
end;

function TWireBuffer.TakeFrame(const AMax: SizeUInt): TBytes;
begin
  if not TryTakeFrame(Result, AMax) then
    raise EInvalidArgument.Create('TWireBuffer.TakeFrame: incomplete or invalid frame');
end;

function WireEncodeFrame(const APayload: TBytes): TBytes; inline;
var
  LLen: SizeUInt;
begin
  LLen := SizeUInt(Length(APayload));
  SetLength(Result, 4 + LLen);
  WriteUInt32BE(PByte(@Result[0]), UInt32(LLen));
  if LLen > 0 then
    Move(APayload[0], Result[4], LLen);
end;

procedure WireAppendEncoded(var ADest: TBytes; const APayload: TBytes); inline;
var
  LOld, LLen: SizeUInt;
begin
  LLen := SizeUInt(Length(APayload));
  LOld := SizeUInt(Length(ADest));
  SetLength(ADest, LOld + 4 + LLen);
  WriteUInt32BE(PByte(@ADest[LOld]), UInt32(LLen));
  if LLen > 0 then
    Move(APayload[0], ADest[LOld + 4], LLen);
end;

end.
