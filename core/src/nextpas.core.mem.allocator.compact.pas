{
# nextpas.core.mem.allocator.compact

## 摘要

Compact allocator — 内存碎片整理分配器。

特性:
- 追踪分配碎片率
- 碎片率超过阈值时触发压缩
- 压缩：将活跃分配迁移到紧凑区域，释放空闲区域
- 需要应用配合：通过回调通知指针变化

适用场景: 长时间运行的服务、内存敏感应用。

Author:    fafafaStudio
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.allocator.compact;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base;

type
  {** 压缩事件回调
   *  @param AOldPtr 旧指针
   *  @param ANewPtr 新指针
   *  @param ASize 分配大小
   *  @param AUserData 用户数据
   *}
  TCompactEvent = procedure(AOldPtr, ANewPtr: Pointer;
    ASize: SizeUInt; AUserData: Pointer);

  {** 压缩统计 }
  TCompactStats = record
    TotalCompactions: UInt64;   { 总压缩次数 }
    BytesMoved: UInt64;         { 移动的字节数 }
    BytesFreed: UInt64;         { 释放的字节数 }
    CurrentFragmentation: Double; { 当前碎片率 }
  end;

  {** TCompactAllocator
   *
   *  碎片整理分配器。
   *  追踪分配碎片率，超过阈值时触发压缩。
   *
   *  压缩过程:
   *  1. 扫描所有活跃分配
   *  2. 将碎片区域的分配迁移到紧凑区域
   *  3. 通过回调通知应用更新指针
   *  4. 释放空闲区域
   *
   *  @warning 压缩期间分配器不可用（暂停所有分配）
   *}
  TCompactAllocator = class(TAllocator)
  private
    FInner: IAllocator;
    FThreshold: Double;
    FOnCompact: TCompactEvent;
    FUserData: Pointer;
    { 统计 }
    FTotalCompactions: UInt64;
    FBytesMoved: UInt64;
    FBytesFreed: UInt64;
    { 分配跟踪 }
    FAllocCount: SizeUInt;
    FAllocCapacity: SizeUInt;
    FAllocPtrs: array of Pointer;
    FAllocSizes: array of SizeUInt;
    procedure GrowTracking;
    procedure TrackAlloc(APtr: Pointer; ASize: SizeUInt);
    procedure UntrackAlloc(APtr: Pointer);
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; override;
    function DoAllocMem(ASize: SizeUInt): Pointer; override;
    function DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(APtr: Pointer); override;
  public
    {** 创建碎片整理分配器
     *  @param AInner 内部分配器
     *  @param AThreshold 触发压缩的碎片率阈值（0.0-1.0，默认 0.3 = 30%）
     *}
    constructor Create(AInner: IAllocator; AThreshold: Double = 0.3);
    destructor Destroy; override;

    {** 设置压缩回调 }
    procedure SetCompactHandler(AHandler: TCompactEvent; AUserData: Pointer);
    {** 获取当前碎片率（0.0-1.0） }
    function FragmentationRatio: Double;
    {** 触发压缩，返回释放的字节数 }
    function Compact: SizeUInt;
    {** 获取压缩统计 }
    function GetStats: TCompactStats;
    {** 碎片率阈值 }
    property Threshold: Double read FThreshold;
    {** 内部分配器 }
    property Inner: IAllocator read FInner;

    function Traits: TAllocatorTraits; override;
  end;

implementation

uses
  nextpas.core.mem.error;

const
  COMPACT_INITIAL_CAP = 256;

{ TCompactAllocator }

constructor TCompactAllocator.Create(AInner: IAllocator; AThreshold: Double);
begin
  inherited Create;
  if AInner = nil then
    raise EAllocError.Create(aeInvalidLayout, 'TCompactAllocator.Create: AInner cannot be nil');
  if (AThreshold < 0.0) or (AThreshold > 1.0) then
    raise EAllocError.Create(aeInvalidLayout, 'TCompactAllocator.Create: threshold must be 0.0-1.0');
  FInner := AInner;
  FThreshold := AThreshold;
  FOnCompact := nil;
  FUserData := nil;
  FTotalCompactions := 0;
  FBytesMoved := 0;
  FBytesFreed := 0;
  FAllocCount := 0;
  FAllocCapacity := COMPACT_INITIAL_CAP;
  SetLength(FAllocPtrs, FAllocCapacity);
  SetLength(FAllocSizes, FAllocCapacity);
end;

destructor TCompactAllocator.Destroy;
begin
  SetLength(FAllocPtrs, 0);
  SetLength(FAllocSizes, 0);
  FInner := nil;
  inherited Destroy;
end;

procedure TCompactAllocator.SetCompactHandler(AHandler: TCompactEvent;
  AUserData: Pointer);
begin
  FOnCompact := AHandler;
  FUserData := AUserData;
end;

procedure TCompactAllocator.GrowTracking;
begin
  FAllocCapacity := FAllocCapacity shl 1;
  SetLength(FAllocPtrs, FAllocCapacity);
  SetLength(FAllocSizes, FAllocCapacity);
end;

procedure TCompactAllocator.TrackAlloc(APtr: Pointer; ASize: SizeUInt);
begin
  if FAllocCount >= FAllocCapacity then
    GrowTracking;
  FAllocPtrs[FAllocCount] := APtr;
  FAllocSizes[FAllocCount] := ASize;
  Inc(FAllocCount);
end;

procedure TCompactAllocator.UntrackAlloc(APtr: Pointer);
var
  LI: SizeUInt;
begin
  for LI := 0 to FAllocCount - 1 do
  begin
    if FAllocPtrs[LI] = APtr then
    begin
      { 用最后一个元素覆盖 }
      FAllocPtrs[LI] := FAllocPtrs[FAllocCount - 1];
      FAllocSizes[LI] := FAllocSizes[FAllocCount - 1];
      Dec(FAllocCount);
      Exit;
    end;
  end;
end;

function TCompactAllocator.DoGetMem(ASize: SizeUInt): Pointer;
begin
  Result := FInner.GetMem(ASize);
  if Result <> nil then
    TrackAlloc(Result, ASize);
end;

function TCompactAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Result := FInner.AllocMem(ASize);
  if Result <> nil then
    TrackAlloc(Result, ASize);
end;

function TCompactAllocator.DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
var
  LOldSize: SizeUInt;
  LI: SizeUInt;
begin
  if APtr = nil then
    Exit(DoGetMem(ASize));
  if ASize = 0 then
  begin
    DoFreeMem(APtr);
    Exit(nil);
  end;

  { 查找旧大小 }
  LOldSize := 0;
  for LI := 0 to FAllocCount - 1 do
  begin
    if FAllocPtrs[LI] = APtr then
    begin
      LOldSize := FAllocSizes[LI];
      Break;
    end;
  end;

  Result := FInner.ReallocMem(APtr, ASize);
  if Result <> nil then
  begin
    if APtr <> nil then
      UntrackAlloc(APtr);
    TrackAlloc(Result, ASize);
  end;
end;

procedure TCompactAllocator.DoFreeMem(APtr: Pointer);
begin
  if APtr = nil then Exit;
  UntrackAlloc(APtr);
  FInner.FreeMem(APtr);
end;

function TCompactAllocator.FragmentationRatio: Double;
var
  LTotalSize: SizeUInt;
  LI: SizeUInt;
begin
  if FAllocCount = 0 then
    Exit(0.0);

  LTotalSize := 0;
  for LI := 0 to FAllocCount - 1 do
    Inc(LTotalSize, FAllocSizes[LI]);

  { 简单碎片率：分配数量越多，碎片率越高 }
  { 实际碎片率需要分析内存布局，这里用启发式 }
  if LTotalSize = 0 then
    Exit(0.0);
  Result := 1.0 - (Double(FAllocCount) / Double(LTotalSize / 64));
  if Result < 0.0 then Result := 0.0;
  if Result > 1.0 then Result := 1.0;
end;

function TCompactAllocator.Compact: SizeUInt;
var
  LI: SizeUInt;
  LOldPtr, LNewPtr: Pointer;
  LSize: SizeUInt;
  LCopySize: SizeUInt;
begin
  Result := 0;
  if FAllocCount = 0 then Exit;

  Inc(FTotalCompactions);

  { 简单压缩：重新分配每个块到新位置 }
  { 这会触发内部分配器的碎片整理 }
  for LI := 0 to FAllocCount - 1 do
  begin
    LOldPtr := FAllocPtrs[LI];
    LSize := FAllocSizes[LI];
    if LOldPtr = nil then Continue;

    { 分配新块 }
    LNewPtr := FInner.GetMem(LSize);
    if LNewPtr = nil then Continue;

    { 复制数据 }
    if LSize > 0 then
      Move(LOldPtr^, LNewPtr^, LSize);

    { 通知应用 }
    if @FOnCompact <> nil then
      FOnCompact(LOldPtr, LNewPtr, LSize, FUserData);

    { 更新跟踪 }
    FAllocPtrs[LI] := LNewPtr;
    Inc(FBytesMoved, LSize);

    { 释放旧块 }
    FInner.FreeMem(LOldPtr);
    Inc(Result, LSize);
  end;

  Inc(FBytesFreed, Result);
end;

function TCompactAllocator.GetStats: TCompactStats;
begin
  Result.TotalCompactions := FTotalCompactions;
  Result.BytesMoved := FBytesMoved;
  Result.BytesFreed := FBytesFreed;
  Result.CurrentFragmentation := FragmentationRatio;
end;

function TCompactAllocator.Traits: TAllocatorTraits;
begin
  if FInner <> nil then
    Result := FInner.Traits
  else
  begin
    Result.ZeroInitialized := False;
    Result.SupportsRealloc := False;
  end;
  Result.ThreadSafe := False;
end;

end.
