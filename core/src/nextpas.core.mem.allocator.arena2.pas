{
# nextpas.core.mem.allocator.arena2

## 摘要

Arena Bump 分配器 — 极速顺序分配，批量释放。

特性:
- 页式 arena：每次从内部分配器获取一大块（页），在其上 bump 分配
- 分配：仅移动指针（O(1)，无元数据开销）
- 释放：不支持单个释放，只能整体 Reset
- 对齐：支持自定义对齐（默认 16 字节）
- 统计：跟踪分配次数、字节数、页数

适用场景：AST 构建、表达式求值、请求处理临时数据。

Author:    fafafaStudio
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.allocator.arena2;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

const
  {** 默认页大小 }
  ARENA2_DEFAULT_PAGE_SIZE = 64 * 1024;  { 64KB }
  {** 默认对齐 }
  ARENA2_DEFAULT_ALIGNMENT = 16;

type
  {** Arena 统计信息 }
  TArena2Stats = record
    PageSize: SizeUInt;        { 每页大小 }
    PageCount: UInt64;         { 页数量 }
    TotalCapacity: UInt64;     { 总容量 }
    UsedBytes: UInt64;         { 已使用字节 }
    AllocCount: UInt64;        { 分配次数 }
    WastedBytes: UInt64;       { 对齐浪费字节 }
  end;

  {** TArena2Allocator
   *
   *  Arena Bump 分配器。极速顺序分配，批量释放。
   *
   *  内存布局:
   *  [Page 0: 64KB][Page 1: 64KB][Page 2: 64KB]...
   *    ^ current page
   *    [used...|free...]
   *            ^ next alloc position
   *
   *  分配仅移动指针，无元数据，无碎片。
   *  不支持单个释放，只能整体 Reset。
   *}
  TArena2Allocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FPageSize: SizeUInt;
    FAlignment: SizeUInt;
    { 页管理 }
    FPages: array of Pointer;
    FPageCount: Integer;
    FPageCapacity: Integer;
    { 当前分配位置 }
    FCurrentPage: Integer;
    FCurrentOffset: SizeUInt;
    { 统计 }
    FUsedBytes: UInt64;
    FAllocCount: UInt64;
    FWastedBytes: UInt64;
    procedure GrowPage;
  public
    {** 创建 Arena 分配器
     *  @param AInner 内部分配器（用于获取页）
     *  @param APageSize 每页大小
     *  @param AAlignment 对齐（默认 16）
     *}
    constructor Create(AInner: IAllocator;
      APageSize: SizeUInt = ARENA2_DEFAULT_PAGE_SIZE;
      AAlignment: SizeUInt = ARENA2_DEFAULT_ALIGNMENT);
    destructor Destroy; override;

    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;
    function Traits: TAllocatorTraits; inline;

    {** 重置 arena（释放所有页，保留第一页） }
    procedure Reset;
    {** 获取统计信息 }
    function GetStats: TArena2Stats;
    {** 已使用字节数 }
    property UsedBytes: UInt64 read FUsedBytes;
    {** 页数量 }
    property PageCount: Integer read FPageCount;
  end;

implementation

uses
  nextpas.core.mem.error;

{ --- TArena2Allocator --- }

constructor TArena2Allocator.Create(AInner: IAllocator; APageSize: SizeUInt;
  AAlignment: SizeUInt);
begin
  inherited Create;
  if AInner = nil then
    raise EAllocError.Create(aeInvalidLayout, 'TArena2Allocator.Create: AInner cannot be nil');
  if APageSize < 1024 then
    APageSize := 1024;
  if (AAlignment = 0) or (AAlignment and (AAlignment - 1) <> 0) then
    AAlignment := ARENA2_DEFAULT_ALIGNMENT;

  FInner := AInner;
  FPageSize := APageSize;
  FAlignment := AAlignment;
  FPageCount := 0;
  FPageCapacity := 4;
  SetLength(FPages, FPageCapacity);
  FCurrentPage := -1;
  FCurrentOffset := 0;
  FUsedBytes := 0;
  FAllocCount := 0;
  FWastedBytes := 0;

  { 创建第一页 }
  GrowPage;
end;

destructor TArena2Allocator.Destroy;
begin
  Reset;
  { 释放第一页 }
  if FPageCount > 0 then
  begin
    FInner.FreeMem(FPages[0]);
    FPages[0] := nil;
  end;
  SetLength(FPages, 0);
  FInner := nil;
  inherited Destroy;
end;

procedure TArena2Allocator.GrowPage;
var
  LPage: Pointer;
begin
  if FPageCount >= FPageCapacity then
  begin
    FPageCapacity := FPageCapacity shl 1;
    SetLength(FPages, FPageCapacity);
  end;

  LPage := FInner.GetMem(FPageSize);
  if LPage = nil then
    raise EAllocError.Create(aeOutOfMemory, 'TArena2Allocator.GrowPage: page allocation failed');

  FPages[FPageCount] := LPage;
  Inc(FPageCount);
  FCurrentPage := FPageCount - 1;
  FCurrentOffset := 0;
end;

function TArena2Allocator.GetMem(ASize: SizeUInt): Pointer; inline;
var
  LAlignedOffset: SizeUInt;
  LTotalSize: SizeUInt;
  LSizePtr: PSizeUInt;
begin
  if ASize = 0 then
    Exit(nil);

  { 对齐当前偏移 }
  LAlignedOffset := (FCurrentOffset + FAlignment - 1) and not (FAlignment - 1);
  FWastedBytes := FWastedBytes + UInt64(LAlignedOffset - FCurrentOffset);

  { size header + user data }
  LTotalSize := SizeOf(SizeUInt) + ASize;

  { 检查当前页是否有足够空间 }
  if LAlignedOffset + LTotalSize > FPageSize then
  begin
    { 当前页空间不足，需要新页 }
    if LTotalSize > FPageSize then
      raise EAllocError.Create(aeOutOfMemory,
        'TArena2Allocator.GetMem: allocation size exceeds page size');
    GrowPage;
    LAlignedOffset := 0;
  end;

  { 从当前页分配: store size, return ptr past header }
  LSizePtr := PSizeUInt(PtrUInt(FPages[FCurrentPage]) + LAlignedOffset);
  LSizePtr^ := ASize;
  Result := Pointer(PByte(LSizePtr) + SizeOf(SizeUInt));
  FCurrentOffset := LAlignedOffset + LTotalSize;
  Inc(FUsedBytes, UInt64(LTotalSize));
  Inc(FAllocCount);
end;

function TArena2Allocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TArena2Allocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
var
  LOldSize, LCopySize: SizeUInt;
begin
  if APtr = nil then
    Exit(GetMem(ASize));
  if ASize = 0 then
    Exit(nil);

  { Read old size from header }
  LOldSize := PSizeUInt(PByte(APtr) - SizeOf(SizeUInt))^;

  Result := GetMem(ASize);
  if Result <> nil then
  begin
    LCopySize := LOldSize;
    if LCopySize > ASize then
      LCopySize := ASize;
    Move(APtr^, Result^, LCopySize);
  end;
  { 旧内存不释放（Arena 不支持单个释放） }
end;

procedure TArena2Allocator.FreeMem(APtr: Pointer); inline;
begin
  { Arena 不支持单个释放，忽略 }
end;

procedure TArena2Allocator.Reset;
var
  LI: Integer;
begin
  { 释放除第一页外的所有页 }
  for LI := FPageCount - 1 downto 1 do
  begin
    FInner.FreeMem(FPages[LI]);
    FPages[LI] := nil;
  end;
  FPageCount := 1;
  FCurrentPage := 0;
  FCurrentOffset := 0;
  FUsedBytes := 0;
  FAllocCount := 0;
  FWastedBytes := 0;
end;

function TArena2Allocator.GetStats: TArena2Stats;
begin
  Result.PageSize := FPageSize;
  Result.PageCount := UInt64(FPageCount);
  Result.TotalCapacity := UInt64(FPageCount) * UInt64(FPageSize);
  Result.UsedBytes := FUsedBytes;
  Result.AllocCount := FAllocCount;
  Result.WastedBytes := FWastedBytes;
end;

function TArena2Allocator.Traits: TAllocatorTraits; inline;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe      := False;
  Result.SupportsRealloc := False;
end;

end.
