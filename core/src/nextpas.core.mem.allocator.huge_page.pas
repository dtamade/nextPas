{
# nextpas.core.mem.allocator.huge_page

## 摘要

Huge page allocator — 使用大页（2MB/1GB）减少 TLB miss。

特性:
- 分配 >= 阈值时尝试大页，失败回退普通页
- 支持 2MB 和 1GB 大页
- 统计大页使用率和回退率
- Linux: MAP_HUGETLB + mmap
- 其他平台: 回退到内部分配器

适用场景: 大内存工作负载（数据库缓存、图计算、科学计算）。

Author:    fafafaStudio
Copyright: (c) 2025 fafafaStudio. All rights reserved.
}

unit nextpas.core.mem.allocator.huge_page;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

type
  {** 大页大小 }
  THugePageSize = (
    hps2MB,   { 2MB 大页 (Linux 默认) }
    hps1GB    { 1GB 大页 (需要 boot 参数预留) }
  );

  {** 大页统计 }
  THugePageStats = record
    Allocated: UInt64;      { 大页分配总字节 }
    Fallbacks: UInt64;      { 回退到普通页的次数 }
    HugePageCount: UInt64;  { 使用的大页数 }
    FallbackBytes: UInt64;  { 回退分配的总字节 }
  end;

  {** THugePageAllocator
   *
   *  包装任意 IAllocator，对大分配使用大页。
   *  分配 >= Threshold 时尝试大页，失败回退到内部分配器。
   *
   *  大页分配使用 mmap(MAP_HUGETLB)，在分配块前存储 8 字节 header
   *  记录大小，用于释放时判断是否为大页。
   *
   *  线程安全由内部分配器决定。
   *}
  THugePageAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FPageSize: THugePageSize;
    FThreshold: SizeUInt;
    FHugeAllocated: UInt64;
    FHugePageCount: UInt64;
    FFallbacks: UInt64;
    FFallbackBytes: UInt64;
    function HugePageSizeBytes: SizeUInt;
    function TryMmapHugePage(ASize: SizeUInt): Pointer;
    procedure FreeHugePage(APtr: Pointer; AAllocSize: SizeUInt);
  public

    function GetMem(ASize: SizeUInt): Pointer; inline;

    function AllocMem(ASize: SizeUInt): Pointer; inline;

    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;

    procedure FreeMem(APtr: Pointer); inline;
    {** 创建大页分配器
     *  @param AInner 内部分配器（回退用）
     *  @param APageSize 大页大小（默认 2MB）
     *  @param AThreshold 触发大页的最小分配大小（默认 2MB）
     *}
    constructor Create(AInner: IAllocator; APageSize: THugePageSize = hps2MB;
      AThreshold: SizeUInt = 2 * 1024 * 1024);
    destructor Destroy; override;

    {** 获取大页统计 }
    function GetStats: THugePageStats;
    {** 大页大小 }
    property PageSize: THugePageSize read FPageSize;
    {** 触发阈值 }
    property Threshold: SizeUInt read FThreshold;
    {** 内部分配器 }
    property Inner: IAllocator read FInner;

    function Traits: TAllocatorTraits; inline;
  end;

implementation

uses
  nextpas.core.mem.error
  {$IFDEF NEXTPAS_LINUX}
  , nextpas.core.platform.posix.ffi
  , nextpas.core.platform.posix.base
  , nextpas.core.platform.linux.base
  {$ENDIF}
  ;

{$IFDEF NEXTPAS_LINUX}
const
  MAP_HUGE_SHIFT = 26;
  MAP_HUGE_2MB   = 21;
  MAP_HUGE_1GB   = 30;
{$ENDIF}

const
  HUGE_PAGE_2MB = 2 * 1024 * 1024;
  HUGE_PAGE_1GB = 1024 * 1024 * 1024;
  HUGE_HEADER_SIZE = 8; { 存储分配大小 }

{ 向上对齐到指定边界 }
function AlignUpSize(AValue: SizeUInt; AAlignment: SizeUInt): SizeUInt; inline;
begin
  Result := (AValue + AAlignment - 1) and not (AAlignment - 1);
end;

type
  PHugeHeader = ^THugeHeader;
  THugeHeader = record
    AllocSize: SizeUInt; { 原始请求大小 }
  end;

{ THugePageAllocator }

constructor THugePageAllocator.Create(AInner: IAllocator;
  APageSize: THugePageSize; AThreshold: SizeUInt);
begin
  inherited Create;
  if AInner = nil then
    raise EArgumentNil.Create('THugePageAllocator.Create: AInner cannot be nil');
  FInner := AInner;
  FPageSize := APageSize;
  FThreshold := AThreshold;
  FHugeAllocated := 0;
  FHugePageCount := 0;
  FFallbacks := 0;
  FFallbackBytes := 0;
end;

destructor THugePageAllocator.Destroy;
begin
  FInner := nil;
  inherited Destroy;
end;

function THugePageAllocator.HugePageSizeBytes: SizeUInt;
begin
  case FPageSize of
    hps2MB: Result := HUGE_PAGE_2MB;
    hps1GB: Result := HUGE_PAGE_1GB;
  else
    Result := HUGE_PAGE_2MB;
  end;
end;

{$IFDEF NEXTPAS_LINUX}
function THugePageAllocator.TryMmapHugePage(ASize: SizeUInt): Pointer;
var
  LFlags: Int32;
  LAllocSize: SizeUInt;
  LHdr: PHugeHeader;
begin
  Result := nil;
  { 对齐到大页边界 }
  LAllocSize := AlignUpSize(HUGE_HEADER_SIZE + ASize, HugePageSizeBytes);
  case FPageSize of
    hps2MB:
      LFlags := PLATFORM_POSIX_MAP_PRIVATE or PLATFORM_POSIX_MAP_ANONYMOUS or
        MAP_HUGETLB or (MAP_HUGE_2MB shl MAP_HUGE_SHIFT);
    hps1GB:
      LFlags := PLATFORM_POSIX_MAP_PRIVATE or PLATFORM_POSIX_MAP_ANONYMOUS or
        MAP_HUGETLB or (MAP_HUGE_1GB shl MAP_HUGE_SHIFT);
  else
    Exit;
  end;
  Result := mmap(nil, PtrUInt(LAllocSize),
    PLATFORM_POSIX_PROT_READ or PLATFORM_POSIX_PROT_WRITE,
    LFlags, -1, 0);
  if Result = Pointer(-1) then
  begin
    Result := nil;
    Exit;
  end;
  { 写入 header }
  LHdr := PHugeHeader(Result);
  LHdr^.AllocSize := ASize;
  { 返回 header 之后的地址 }
  Result := Pointer(PtrUInt(Result) + HUGE_HEADER_SIZE);
end;

procedure THugePageAllocator.FreeHugePage(APtr: Pointer; AAllocSize: SizeUInt);
var
  LBase: Pointer;
  LAllocSize: SizeUInt;
begin
  LBase := Pointer(PtrUInt(APtr) - HUGE_HEADER_SIZE);
  LAllocSize := AlignUpSize(HUGE_HEADER_SIZE + AAllocSize, HugePageSizeBytes);
  munmap(LBase, PtrUInt(LAllocSize));
end;
{$ENDIF}

function THugePageAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := nil;
  if ASize = 0 then Exit;

{$IFDEF NEXTPAS_LINUX}
  { 尝试大页分配 }
  if ASize >= FThreshold then
  begin
    Result := TryMmapHugePage(ASize);
    if Result <> nil then
    begin
      FHugeAllocated := FHugeAllocated + ASize;
      FHugePageCount := FHugePageCount + 1;
      Exit;
    end;
    { 大页分配失败，回退 }
    FFallbacks := FFallbacks + 1;
    FFallbackBytes := FFallbackBytes + ASize;
  end;
{$ENDIF}

  { 回退到内部分配器 }
  Result := FInner.GetMem(ASize);
end;

function THugePageAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function THugePageAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
var
  LHdr: PHugeHeader;
  LOldSize, LCopySize: SizeUInt;
begin
  if APtr = nil then
    Exit(GetMem(ASize));
  if ASize = 0 then
  begin
    FreeMem(APtr);
    Exit(nil);
  end;

  LHdr := PHugeHeader(PByte(APtr) - HUGE_HEADER_SIZE);
  LOldSize := LHdr^.AllocSize;

  Result := GetMem(ASize);
  if Result = nil then Exit;

  LCopySize := LOldSize;
  if LCopySize > ASize then
    LCopySize := ASize;
  Move(APtr^, Result^, LCopySize);
  FreeMem(APtr);
end;

procedure THugePageAllocator.FreeMem(APtr: Pointer); inline;
{$IFDEF NEXTPAS_LINUX}
var
  LBase: Pointer;
  LHdr: PHugeHeader;
{$ENDIF}
begin
  if APtr = nil then Exit;

{$IFDEF NEXTPAS_LINUX}
  { 检查是否是大页分配（通过 mmap 标记检测） }
  LBase := Pointer(PtrUInt(APtr) - HUGE_HEADER_SIZE);
  { 简单启发式：大页分配的地址会对齐到大页边界 }
  if (PtrUInt(LBase) mod HugePageSizeBytes) = 0 then
  begin
    LHdr := PHugeHeader(LBase);
    if LHdr^.AllocSize > 0 then
    begin
      FreeHugePage(APtr, LHdr^.AllocSize);
      FHugeAllocated := FHugeAllocated - LHdr^.AllocSize;
      if FHugePageCount > 0 then
        FHugePageCount := FHugePageCount - 1;
      Exit;
    end;
  end;
{$ENDIF}

  { 普通页分配，回退到内部分配器 }
  FInner.FreeMem(APtr);
end;

function THugePageAllocator.GetStats: THugePageStats;
begin
  Result.Allocated := FHugeAllocated;
  Result.Fallbacks := FFallbacks;
  Result.HugePageCount := FHugePageCount;
  Result.FallbackBytes := FFallbackBytes;
end;

function THugePageAllocator.Traits: TAllocatorTraits; inline;
begin
  if FInner <> nil then
    Result := FInner.Traits
  else
  begin
    Result.ZeroInitialized := False;
    Result.SupportsRealloc := False;
  end;
end;

end.
