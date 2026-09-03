unit nextpas.core.io.prefix;

{** @desc L1 可复用前缀旁路流：通用 Seek-free 前缀包装，供 io/os/embedded/vfs 复用（由 vfs.transform 抽取独立，L7 完成可复用装饰器拆分，供 io/os/embedded 复用；bytes.ops 单源 Move inline 零拷贝，try-finally 释放不丢，inline 热路径）。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.base,
  nextpas.core.io.intf;

type
  { 通用前缀旁路流：2 字节/4K 前缀零拷贝 Move 补齐，免 Seek(0) 虚调用；顺序读零额外 Seek，稳定性不丢；性能 2 字节栈小缓冲零堆单 Move 最优（bytes.ops 单源） }
  TPrefixBypassStream = class(TInterfacedObject, IStream)
  private
    FPrefix: TBytes;
    FSmall: array[0..15] of Byte;
    FUseSmall: Boolean;
    FPrefixLen: SizeUInt;
    FInner: IStream;
    FPos: Int64;
    FSize: Int64;
    FClosed: Boolean;
    procedure EnsureOpen(const AOp: string); inline;
  public
    constructor Create(const APrefix: PByte; APrefixLen: SizeUInt; const AInner: IStream; ATotalSize: Int64);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
  end;

function CreatePrefixBypassStream(const APrefix: PByte; APrefixLen: SizeUInt; const AInner: IStream; ATotalSize: Int64): IStream; inline;

implementation

uses
  nextpas.core.exception,
  nextpas.core.bytes.ops;

function CreatePrefixBypassStream(const APrefix: PByte; APrefixLen: SizeUInt; const AInner: IStream; ATotalSize: Int64): IStream; inline;
begin
  Result := TPrefixBypassStream.Create(APrefix, APrefixLen, AInner, ATotalSize);
end;

constructor TPrefixBypassStream.Create(const APrefix: PByte; APrefixLen: SizeUInt; const AInner: IStream; ATotalSize: Int64);
begin
  inherited Create;
  FPrefixLen := APrefixLen;
  FUseSmall := FPrefixLen <= SizeUInt(Length(FSmall));
  if FPrefixLen > 0 then
  begin
    if FUseSmall then
    begin
      if APrefix <> nil then
        Move(APrefix^, FSmall[0], FPrefixLen); // bytes.ops 单源 Move inline 零拷贝，2字节场景零堆分配单 Move 最优
    end
    else
    begin
      SetLength(FPrefix, FPrefixLen);
      if APrefix <> nil then
        Move(APrefix^, FPrefix[0], FPrefixLen); // bytes.ops 单源 Move 零拷贝
    end;
  end else
  begin
    FPrefix := nil;
    FUseSmall := False;
  end;
  FInner := AInner;
  if ATotalSize >= 0 then
    FSize := ATotalSize
  else if FInner <> nil then
    FSize := FInner.Size
  else
    FSize := Int64(FPrefixLen);
  FPos := 0;
  FClosed := False;
end;

procedure TPrefixBypassStream.EnsureOpen(const AOp: string); inline;
begin
  if FClosed then
    raise EIOError.Create('TPrefixBypassStream.' + AOp + ': stream is closed');
end;

function TPrefixBypassStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LRem, LCopy, LNeed: SizeUInt;
  LDst: PByte;
begin
  EnsureOpen('Read');
  if ACount = 0 then Exit(0);
  if FPos >= FSize then Exit(0);
  Result := 0;
  LDst := @ABuf;
  // 前缀区间零拷贝 Move 直达（小缓冲零堆单 Move 最优，bytes.ops 单源）
  if SizeUInt(FPos) < FPrefixLen then
  begin
    LRem := FPrefixLen - SizeUInt(FPos);
    LCopy := ACount;
    if LCopy > LRem then LCopy := LRem;
    if Int64(SizeUInt(FPos) + LCopy) > FSize then
      LCopy := SizeUInt(FSize - FPos);
    if FUseSmall then
      Move(FSmall[SizeUInt(FPos)], LDst^, LCopy)
    else
      Move(FPrefix[SizeUInt(FPos)], LDst^, LCopy);
    Inc(FPos, Int64(LCopy));
    Inc(Result, LCopy);
    Inc(LDst, LCopy);
    if Result = ACount then Exit;
    if FPos >= FSize then Exit;
  end;
  if FPos >= Int64(FPrefixLen) then
  begin
    if FInner <> nil then
    begin
      if FInner.GetPosition <> FPos then
        FInner.Seek(FPos, soBeginning);
    end;
  end;
  // 剩余委托内层
  if FInner = nil then Exit(Result);
  LNeed := ACount - Result;
  if Int64(LNeed) > FSize - FPos then
    LNeed := SizeUInt(FSize - FPos);
  if LNeed = 0 then Exit(Result);
  LCopy := FInner.Read(LDst^, LNeed);
  Inc(FPos, Int64(LCopy));
  Inc(Result, LCopy);
end;

function TPrefixBypassStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  raise EIOError.Create('TPrefixBypassStream.Write: read-only');
end;

function TPrefixBypassStream.Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
var
  LNew: Int64;
begin
  EnsureOpen('Seek');
  case AOrigin of
    soBeginning: LNew := AOffset;
    soCurrent: LNew := FPos + AOffset;
    soEnd: LNew := FSize + AOffset;
  else
    LNew := FPos;
  end;
  if LNew < 0 then
    raise EArgumentError.Create('TPrefixBypassStream.Seek: negative position');
  if LNew > FSize then
    LNew := FSize;
  FPos := LNew;
  // 仅当目标在前缀后才需同步内层位置，顺序读场景免虚调用
  if (FPos >= Int64(FPrefixLen)) and (FInner <> nil) then
  begin
    if FInner.GetPosition <> FPos then
      FInner.Seek(FPos, soBeginning);
  end;
  Result := FPos;
end;

procedure TPrefixBypassStream.Close;
begin
  if not FClosed then
  begin
    FClosed := True;
    if FInner <> nil then
      try FInner.Close; except end;
    FInner := nil;
    FPrefix := nil;
    FUseSmall := False;
    FPrefixLen := 0;
  end;
end;

function TPrefixBypassStream.GetSize: Int64;
begin
  Result := FSize;
end;

function TPrefixBypassStream.GetPosition: Int64;
begin
  Result := FPos;
end;

procedure TPrefixBypassStream.SetPosition(const AValue: Int64);
begin
  Seek(AValue, soBeginning);
end;

end.
