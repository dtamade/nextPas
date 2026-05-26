unit nextpas.core.mem.pool.slab;

{$I nextpas.core.settings.inc}

{$PUSH}
{$HINTS OFF} // pointer/ordinal conversions in slab internals

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.mem.allocator,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.pool.memory_pool,
  nextpas.core.mem.pool.fixed_slab,
  nextpas.core.mem.error;        // EAllocError, TAllocError

type
  // 性能计数器（供测试）
  TSlabPerfCounters = record
    AllocCalls : QWord;
    FreeCalls  : QWord;
    AllocTime  : QWord;
    FreeTime   : QWord;
    PageMerges : QWord;
    MergeTime  : QWord;
    MergedPages: QWord;
  end;

  // 只读统计快照（不改变池行为）
  TSlabPoolStats = record
    SegmentCount: Integer;
    TotalCapacity: SizeUInt;
    TotalUsed: SizeUInt;
    FallbackAllocCount: Integer;
    FallbackBytes: SizeUInt;
  end;

  // 兼容配置
  TSlabConfig = record
    MinShift: SizeUInt;            // 默认 3 (8B)
    EnablePageMerging: Boolean;    // 兼容字段（当前未用）
    MaxAllocSize: SizeUInt;        // 0=不限制；>0 时限制单次分配（超过返回 nil）
    EnablePerfMonitoring: Boolean; // 性能计数开关（默认启用）
    EnableDebug: Boolean;          // 调试开关（预留）
    PageSize: SizeUInt;            // 兼容字段（默认 4096）
  end;

  // Fallback allocation record (oversize / high-alignment allocations)
  TSlabFallbackAlloc = record
    UserPtr: Pointer;
    RawPtr: Pointer;
    Size: SizeUInt;
    Alignment: SizeUInt;
  end;

  {** 无效大小异常（继承自 EAllocError）| Invalid size exception *}
  ESlabPoolInvalidSize = class(EAllocError);
  {** Slab 池损坏异常 | Slab pool corruption exception *}
  ESlabPoolCorruption  = class(EAllocError);


  {**
   * TSlabPool
   *
   * @desc
   *   自动扩展的 Slab 内存池，基于 TFixedSlabPool 段构建。
   *   Auto-expanding slab pool built atop TFixedSlabPool segments.
   *
   * @usage
   *   适用于频繁分配/释放小对象的场景，提供 O(1) 分配和释放性能。
   *   Ideal for frequent allocation/deallocation of small objects with O(1) performance.
   *
   * @features
   *   - 自动扩展：按需添加新段
   *   - 多尺寸支持：8B-2048B 的对象
   *   - 回退机制：超大对象使用标准分配器
   *   - 性能监控：可选的性能计数器
   *
   * @thread_safety
   *   不是线程安全的。多线程环境请使用 TSlabPoolConcurrent。
   *   Not thread-safe. Use TSlabPoolConcurrent for multi-threaded scenarios.
   *
   * @example
   *   // 创建 Slab 池
   *   var Pool: TSlabPool;
   *   Pool := TSlabPool.Create(4096);  // 初始容量 4KB
   *   try
   *     // 分配小对象
   *     Ptr := Pool.GetMem(64);
   *     try
   *       // 使用内存...
   *     finally
   *       Pool.FreeMem(Ptr);
   *     end;
   *   finally
   *     Pool.Free;
   *   end;
   *
   * @performance
   *   - 分配：O(1) 平均，最坏 O(n) 当需要扩展时
   *   - 释放：O(1)
   *   - 内存开销：每段约 5-10% 元数据开销
   *
   * @see TFixedSlabPool, TSlabPoolConcurrent, IMemoryPool
   *}
  TSlabPool = class(TInterfacedObject, IMemoryPool, IAllocator)
  private
    FAllocator: IAllocator;
    FSegments: array of TFixedSlabPool;
    FActive: Integer;
    FInitialCapacity, FMinShift: SizeUInt;
    FAvail: array of Integer; // LIFO of segments likely with free space
    FAvailCount: Integer;     // 实际使用的元素数量（避免每次 SetLength）
    FConfig: TSlabConfig;
    FTotalAllocs: SizeUInt;
    FTotalFrees: SizeUInt;
    FPerf: TSlabPerfCounters;
    // Fallback allocations tracking (oversize / high-alignment)
    FFbKeys: array of PtrUInt;      // 0 = empty, 1 = tombstone
    FFbRawPtrs: array of Pointer;   // raw pointer (for FreeMem)
    FFbSizes: array of SizeUInt;    // requested size
    FFbAlignments: array of SizeUInt;// requested alignment (power of two)
    FFbMask: SizeUInt;
    FFbHighShift: SizeUInt;
    FFbCount: SizeUInt;             // live entries
    FFbFill: SizeUInt;              // live + tombstones
    FFbBytes: SizeUInt;             // sum of live sizes
    // Page -> segment hash map (O(1) owner lookup)
    FPageKeys: array of PtrUInt;  // store key+1; 0 = empty
    FPageVals: array of Integer;  // segment index
    FPageMask: SizeUInt;          // capacity - 1, power of two
    FPageHighShift: SizeUInt;     // 64 - log2(capacity)
    FPageCount: SizeUInt;         // number of occupied entries
  private
    function TryAllocFromSeg(const aIdx: Integer; const aSize: SizeUInt): Pointer; inline;
    function PopAvail(out aIdx: Integer): Boolean; inline;
    procedure PushAvail(const aIdx: Integer); inline;
    function NewSegmentCapacity: SizeUInt; inline;
    function FindOwnerSegment(aPtr: Pointer): Integer; inline; // fallback scan
    function IsOversize(const aSize: SizeUInt): Boolean; inline;
    function ShouldUseFallback(const aSize: SizeUInt): Boolean; inline;
    function NaturalAlignmentForSize(const aSize: SizeUInt): SizeUInt; inline;
    function AllocFallback(const aSize, aAlignment: SizeUInt): Pointer;
    function TryGetFallbackAlloc(const aPtr: Pointer; out aAlloc: TSlabFallbackAlloc): Boolean; inline;
    function TryUntrackFallbackAlloc(const aPtr: Pointer; out aAlloc: TSlabFallbackAlloc): Boolean;
    procedure FreeAllFallbackAllocs;
    function GetFallbackAllocCount: Integer; inline;
    // fallback map helpers
    procedure FbMapInit(aMinCapacity: SizeUInt);
    procedure FbMapClear;
    procedure FbMapRehash(aNewCapacity: SizeUInt);
    procedure FbMapGrowIfNeeded(aNeedMore: SizeUInt);
    procedure FbMapInsert(aUserPtr, aRawPtr: Pointer; aSize, aAlignment: SizeUInt);
    function FbMapLookup(aUserPtr: Pointer; out aRawPtr: Pointer; out aSize, aAlignment: SizeUInt): Boolean; inline;
    function FbMapDelete(aUserPtr: Pointer; out aRawPtr: Pointer; out aSize, aAlignment: SizeUInt): Boolean;
    function GetSegmentCount: Integer; inline;
    // page map helpers
    function PageKeyOf(aPtr: Pointer): PtrUInt; inline;
    procedure PageMapInit(aMinCapacity: SizeUInt);
    procedure PageMapClear;
    procedure PageMapGrowIfNeeded(aNeedMore: SizeUInt);
    procedure PageMapInsert(aKey: PtrUInt; aSegIdx: Integer);
    function PageMapLookup(aKey: PtrUInt; out aSegIdx: Integer): Boolean; inline;
    procedure IndexSegmentPages(aSegIdx: Integer);
  public
    constructor Create(aCapacity: SizeUInt; aAllocator: IAllocator = nil; aMinShift: SizeUInt = 3); overload;
    constructor Create(aCapacity: SizeUInt; const aConfig: TSlabConfig; aAllocator: IAllocator = nil); overload;
    destructor Destroy; override;
    // IPool
    function Acquire(out aPtr: Pointer): Boolean;
    function TryAcquire(out aPtr: Pointer): Boolean; inline;
    function AcquireN(out aUnits: array of Pointer; aCount: Integer): Integer;
    procedure Release(aPtr: Pointer);
    procedure ReleaseN(const aUnits: array of Pointer; aCount: Integer);
    procedure Reset;
    // IAllocator aligned allocation
    function AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
    procedure FreeAligned(aPtr: Pointer);
    // IMemoryPool + IAllocator
    // Compatibility helpers for older tests
    function Alloc(aSize: SizeUInt): Pointer; inline;
    procedure Free(aPtr: Pointer); overload; inline;
    procedure ReleasePtr(aPtr: Pointer); inline;
    function Warmup(aUnitSize: SizeUInt; aMinPages: SizeUInt): SizeUInt;
    // 诊断/自省 helpers
    function Owns(aPtr: Pointer): Boolean; inline;
    function MemSizeOf(aPtr: Pointer): SizeUInt;
    function Stats: TSlabPoolStats;
    // 性能计数器快照（只读）
    function GetPerfCounters: TSlabPerfCounters; inline;
    function GetSegmentRegion(aIndex: Integer; out aStart, aEnd: PByte; out aPageShift: SizeUInt): Boolean;
    function TryGetFallbackAllocInfo(aPtr: Pointer; out aSize, aAlignment: SizeUInt): Boolean;
    property SegmentCount: Integer read GetSegmentCount;
    property FallbackAllocCount: Integer read GetFallbackAllocCount;

    function GetMem(aSize: SizeUInt): Pointer;
    function AllocMem(aSize: SizeUInt): Pointer;
    function ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
    procedure FreeMem(aDst: Pointer);
    function Allocate(const ASize: SizeUInt): Pointer;
    function Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
    procedure Deallocate(const APtr: Pointer);
    // 兼容统计
    property TotalAllocs: SizeUInt read FTotalAllocs;
    property TotalFrees : SizeUInt read FTotalFrees;
    // IAllocator capability
    function Traits: TAllocatorTraits;

  end;

function CreateDefaultSlabConfig: TSlabConfig;
function CreateSlabConfigWithPageMerging: TSlabConfig;
implementation

const
  HASH_MIN_CAP = 64;
  FB_TOMBSTONE = PtrUInt(1);

{$push}
{$Q-}
function MulHash64(x: QWord): QWord; inline;
begin
  Result := x * QWord(11400714819323198485);
end;
{$pop}

function CreateDefaultSlabConfig: TSlabConfig;
begin
  Result.MinShift := 3;
  Result.EnablePageMerging := False;
  Result.MaxAllocSize := 0; // unlimited by default
  Result.EnablePerfMonitoring := True;
  Result.EnableDebug := False;
  Result.PageSize := 4096;
end;

function CreateSlabConfigWithPageMerging: TSlabConfig;
begin
  Result := CreateDefaultSlabConfig;
  Result.EnablePageMerging := True;
end;

function TSlabPool.IsOversize(const aSize: SizeUInt): Boolean; inline;
begin
  // 兼容字段：仅用于“硬限制”单次分配的最大尺寸
  Result := (aSize <> 0) and (FConfig.MaxAllocSize > 0) and (aSize > FConfig.MaxAllocSize);
end;

function IsPowerOfTwoSize(aValue: SizeUInt): Boolean; inline;
begin
  Result := (aValue <> 0) and ((aValue and (aValue - 1)) = 0);
end;

function AlignUpPtrLocal(aPtr: Pointer; aAlignment: SizeUInt): Pointer; inline;
var
  LAddr, LMask: PtrUInt;
begin
  LAddr := PtrUInt(aPtr);
  LMask := PtrUInt(aAlignment - 1);
  Result := Pointer((LAddr + LMask) and not LMask);
end;

function NextPow2(const aValue: SizeUInt): SizeUInt; inline;
var
  LResult: SizeUInt;
begin
  if aValue <= 1 then Exit(1);
  LResult := 1;
  while LResult < aValue do
    LResult := LResult shl 1;
  Result := LResult;
end;

function TSlabPool.ShouldUseFallback(const aSize: SizeUInt): Boolean; inline;
begin
  // 专业策略：大对象不进入 slab（避免一次性大申请导致 segment 巨大扩容）
  Result := aSize > FInitialCapacity;
end;

function TSlabPool.NaturalAlignmentForSize(const aSize: SizeUInt): SizeUInt; inline;
var
  LMinSize, LPageSize: SizeUInt;
begin
  // nginx slab：小对象按 2^k chunk；大对象按 page 分配
  if aSize = 0 then Exit(SizeOf(Pointer));
  LMinSize := SizeUInt(1) shl FMinShift;
  if aSize <= LMinSize then Exit(LMinSize);
  LPageSize := SizeUInt(1) shl FSegments[0].PageShift;
  if aSize >= (LPageSize shr 1) then Exit(LPageSize);
  Result := NextPow2(aSize);
end;

function TSlabPool.GetFallbackAllocCount: Integer; inline;
begin
  if FFbCount > SizeUInt(High(Integer)) then
    Result := High(Integer)
  else
    Result := Integer(FFbCount);
end;

procedure TSlabPool.FbMapInit(aMinCapacity: SizeUInt);
var
  LCap, LIdx, LLog, LTmp: SizeUInt;
begin
  LCap := HASH_MIN_CAP;
  while LCap < aMinCapacity do
    LCap := LCap shl 1;

  SetLength(FFbKeys, LCap);
  SetLength(FFbRawPtrs, LCap);
  SetLength(FFbSizes, LCap);
  SetLength(FFbAlignments, LCap);

  for LIdx := 0 to LCap - 1 do
  begin
    FFbKeys[LIdx] := 0;
    FFbRawPtrs[LIdx] := nil;
    FFbSizes[LIdx] := 0;
    FFbAlignments[LIdx] := 0;
  end;

  FFbMask := LCap - 1;
  LLog := 0;
  LTmp := LCap;
  while LTmp > 1 do
  begin
    Inc(LLog);
    LTmp := LTmp shr 1;
  end;
  FFbHighShift := SizeUInt(64 - LLog);

  FFbCount := 0;
  FFbFill := 0;
  FFbBytes := 0;
end;

procedure TSlabPool.FbMapClear;
var
  LIdx: SizeUInt;
begin
  if Length(FFbKeys) = 0 then
  begin
    FFbMask := 0;
    FFbHighShift := 0;
    FFbCount := 0;
    FFbFill := 0;
    FFbBytes := 0;
    Exit;
  end;

  for LIdx := 0 to FFbMask do
  begin
    FFbKeys[LIdx] := 0;
    FFbRawPtrs[LIdx] := nil;
    FFbSizes[LIdx] := 0;
    FFbAlignments[LIdx] := 0;
  end;
  FFbCount := 0;
  FFbFill := 0;
  FFbBytes := 0;
end;

procedure TSlabPool.FbMapRehash(aNewCapacity: SizeUInt);
var
  LOldKeys: array of PtrUInt;
  LOldRawPtrs: array of Pointer;
  LOldSizes: array of SizeUInt;
  LOldAlignments: array of SizeUInt;
  LOldCap: SizeUInt;

  LIdx, LLog, LTmp: SizeUInt;
  LKey: PtrUInt;
  LPos: SizeUInt;
  LHash: QWord;
begin
  if aNewCapacity < HASH_MIN_CAP then
    aNewCapacity := HASH_MIN_CAP;
  if not IsPowerOfTwoSize(aNewCapacity) then
    aNewCapacity := NextPow2(aNewCapacity);

  LOldCap := SizeUInt(Length(FFbKeys));
  LOldKeys := FFbKeys;
  LOldRawPtrs := FFbRawPtrs;
  LOldSizes := FFbSizes;
  LOldAlignments := FFbAlignments;

  SetLength(FFbKeys, aNewCapacity);
  SetLength(FFbRawPtrs, aNewCapacity);
  SetLength(FFbSizes, aNewCapacity);
  SetLength(FFbAlignments, aNewCapacity);
  FFbMask := aNewCapacity - 1;

  LLog := 0;
  LTmp := aNewCapacity;
  while LTmp > 1 do
  begin
    Inc(LLog);
    LTmp := LTmp shr 1;
  end;
  FFbHighShift := SizeUInt(64 - LLog);

  for LIdx := 0 to FFbMask do
  begin
    FFbKeys[LIdx] := 0;
    FFbRawPtrs[LIdx] := nil;
    FFbSizes[LIdx] := 0;
    FFbAlignments[LIdx] := 0;
  end;
  FFbCount := 0;
  FFbFill := 0;
  FFbBytes := 0;

  for LIdx := 0 to LOldCap - 1 do
  begin
    LKey := LOldKeys[LIdx];
    if (LKey <> 0) and (LKey <> FB_TOMBSTONE) then
    begin
      LHash := MulHash64(LKey);
      LPos := (LHash shr FFbHighShift) and FFbMask;
      while FFbKeys[LPos] <> 0 do
        LPos := (LPos + 1) and FFbMask;

      FFbKeys[LPos] := LKey;
      FFbRawPtrs[LPos] := LOldRawPtrs[LIdx];
      FFbSizes[LPos] := LOldSizes[LIdx];
      FFbAlignments[LPos] := LOldAlignments[LIdx];
      Inc(FFbCount);
      Inc(FFbFill);
      Inc(FFbBytes, LOldSizes[LIdx]);
    end;
  end;
end;

procedure TSlabPool.FbMapGrowIfNeeded(aNeedMore: SizeUInt);
begin
  if Length(FFbKeys) = 0 then
    FbMapInit(HASH_MIN_CAP);
  if (FFbFill + aNeedMore) <= ((FFbMask + 1) shr 1) then Exit; // load <= 0.5 (incl tombstones)
  FbMapRehash((FFbMask + 1) shl 1);
end;

procedure TSlabPool.FbMapInsert(aUserPtr, aRawPtr: Pointer; aSize, aAlignment: SizeUInt);
var
  LKey: PtrUInt;
  LPos, LTomb: SizeUInt;
  LHash: QWord;
begin
  if aUserPtr = nil then
    raise EInvalidArgument.Create('TSlabPool.FbMapInsert: aUserPtr is nil');

  LKey := PtrUInt(aUserPtr);
  if (LKey = 0) or (LKey = FB_TOMBSTONE) then
    raise EInvalidArgument.Create('TSlabPool.FbMapInsert: invalid pointer key');

  FbMapGrowIfNeeded(1);
  LHash := MulHash64(LKey);
  LPos := (LHash shr FFbHighShift) and FFbMask;
  LTomb := High(SizeUInt);
  while True do
  begin
    if FFbKeys[LPos] = 0 then Break;
    if FFbKeys[LPos] = LKey then
    begin
      // replace existing entry (should be rare)
      if FFbSizes[LPos] <= FFbBytes then
        Dec(FFbBytes, FFbSizes[LPos])
      else
        FFbBytes := 0;
      FFbRawPtrs[LPos] := aRawPtr;
      FFbSizes[LPos] := aSize;
      FFbAlignments[LPos] := aAlignment;
      Inc(FFbBytes, aSize);
      Exit;
    end;
    if (LTomb = High(SizeUInt)) and (FFbKeys[LPos] = FB_TOMBSTONE) then
      LTomb := LPos;
    LPos := (LPos + 1) and FFbMask;
  end;

  if LTomb <> High(SizeUInt) then
    LPos := LTomb
  else
    Inc(FFbFill); // used a previously empty slot

  FFbKeys[LPos] := LKey;
  FFbRawPtrs[LPos] := aRawPtr;
  FFbSizes[LPos] := aSize;
  FFbAlignments[LPos] := aAlignment;
  Inc(FFbCount);
  Inc(FFbBytes, aSize);
end;

function TSlabPool.FbMapLookup(aUserPtr: Pointer; out aRawPtr: Pointer; out aSize, aAlignment: SizeUInt): Boolean; inline;
var
  LKey: PtrUInt;
  LPos: SizeUInt;
  LHash: QWord;
begin
  aRawPtr := nil;
  aSize := 0;
  aAlignment := 0;

  if aUserPtr = nil then Exit(False);
  if Length(FFbKeys) = 0 then Exit(False);

  LKey := PtrUInt(aUserPtr);
  if (LKey = 0) or (LKey = FB_TOMBSTONE) then Exit(False);

  LHash := MulHash64(LKey);
  LPos := (LHash shr FFbHighShift) and FFbMask;
  while True do
  begin
    if FFbKeys[LPos] = 0 then Exit(False);
    if FFbKeys[LPos] = LKey then
    begin
      aRawPtr := FFbRawPtrs[LPos];
      aSize := FFbSizes[LPos];
      aAlignment := FFbAlignments[LPos];
      Exit(True);
    end;
    LPos := (LPos + 1) and FFbMask;
  end;
end;

function TSlabPool.FbMapDelete(aUserPtr: Pointer; out aRawPtr: Pointer; out aSize, aAlignment: SizeUInt): Boolean;
var
  LKey: PtrUInt;
  LPos: SizeUInt;
  LHash: QWord;
begin
  aRawPtr := nil;
  aSize := 0;
  aAlignment := 0;
  Result := False;

  if aUserPtr = nil then Exit(False);
  if Length(FFbKeys) = 0 then Exit(False);

  LKey := PtrUInt(aUserPtr);
  if (LKey = 0) or (LKey = FB_TOMBSTONE) then Exit(False);

  LHash := MulHash64(LKey);
  LPos := (LHash shr FFbHighShift) and FFbMask;
  while True do
  begin
    if FFbKeys[LPos] = 0 then Exit(False);
    if FFbKeys[LPos] = LKey then
    begin
      aRawPtr := FFbRawPtrs[LPos];
      aSize := FFbSizes[LPos];
      aAlignment := FFbAlignments[LPos];

      FFbKeys[LPos] := FB_TOMBSTONE;
      FFbRawPtrs[LPos] := nil;
      FFbSizes[LPos] := 0;
      FFbAlignments[LPos] := 0;

      if FFbCount > 0 then
        Dec(FFbCount);
      if aSize <= FFbBytes then
        Dec(FFbBytes, aSize)
      else
        FFbBytes := 0;
      Result := True;
      Exit;
    end;
    LPos := (LPos + 1) and FFbMask;
  end;
end;

function TSlabPool.TryGetFallbackAlloc(const aPtr: Pointer; out aAlloc: TSlabFallbackAlloc): Boolean; inline;
var
  LRaw: Pointer;
  LSize, LAlign: SizeUInt;
begin
  aAlloc.UserPtr := nil;
  aAlloc.RawPtr := nil;
  aAlloc.Size := 0;
  aAlloc.Alignment := 0;

  Result := FbMapLookup(aPtr, LRaw, LSize, LAlign);
  if Result then
  begin
    aAlloc.UserPtr := aPtr;
    aAlloc.RawPtr := LRaw;
    aAlloc.Size := LSize;
    aAlloc.Alignment := LAlign;
  end;
end;

function TSlabPool.TryUntrackFallbackAlloc(const aPtr: Pointer; out aAlloc: TSlabFallbackAlloc): Boolean;
var
  LRaw: Pointer;
  LSize, LAlign: SizeUInt;
begin
  aAlloc.UserPtr := nil;
  aAlloc.RawPtr := nil;
  aAlloc.Size := 0;
  aAlloc.Alignment := 0;

  Result := FbMapDelete(aPtr, LRaw, LSize, LAlign);
  if Result then
  begin
    aAlloc.UserPtr := aPtr;
    aAlloc.RawPtr := LRaw;
    aAlloc.Size := LSize;
    aAlloc.Alignment := LAlign;
  end;
end;

procedure TSlabPool.FreeAllFallbackAllocs;
var
  LIdx: SizeUInt;
  LKey: PtrUInt;
begin
  if (FAllocator <> nil) and (Length(FFbKeys) > 0) then
    for LIdx := 0 to FFbMask do
    begin
      LKey := FFbKeys[LIdx];
      if (LKey <> 0) and (LKey <> FB_TOMBSTONE) then
        if FFbRawPtrs[LIdx] <> nil then
          FAllocator.FreeMem(FFbRawPtrs[LIdx]);
    end;
  FbMapClear;
end;

function TSlabPool.AllocFallback(const aSize, aAlignment: SizeUInt): Pointer;
var
  LAlign, LNeeded: SizeUInt;
  LRaw, LUser: Pointer;
begin
  Result := nil;
  if (aSize = 0) or (FAllocator = nil) then Exit(nil);

  LAlign := aAlignment;
  if LAlign = 0 then
    LAlign := 16;
  if LAlign < SizeOf(Pointer) then
    LAlign := SizeOf(Pointer);
  if not IsPowerOfTwoSize(LAlign) then
    raise EInvalidArgument.Create('TSlabPool.AllocFallback: aAlignment must be power of two and >= pointer size');

  // over-allocate for alignment; raw pointer is tracked out-of-band
  LNeeded := aSize + (LAlign - 1);
  LRaw := FAllocator.GetMem(LNeeded);
  if LRaw = nil then Exit(nil);

  LUser := AlignUpPtrLocal(LRaw, LAlign);
  try
    FbMapInsert(LUser, LRaw, aSize, LAlign);
  except
    // strong exception safety: do not leak raw pointer
    FAllocator.FreeMem(LRaw);
    raise;
  end;
  Result := LUser;
end;

function TSlabPool.GetSegmentCount: Integer; inline;
begin
  Result := Length(FSegments);
end;

function TSlabPool.Owns(aPtr: Pointer): Boolean; inline;
var
  LSegIdx: Integer;
  LAlloc: TSlabFallbackAlloc;
begin
  if aPtr = nil then Exit(False);
  LSegIdx := FindOwnerSegment(aPtr);
  if LSegIdx >= 0 then Exit(True);
  Result := TryGetFallbackAlloc(aPtr, LAlloc);
end;

function TSlabPool.MemSizeOf(aPtr: Pointer): SizeUInt;
var
  LSegIdx: Integer;
  LAlloc: TSlabFallbackAlloc;
begin
  if aPtr = nil then Exit(0);
  LSegIdx := FindOwnerSegment(aPtr);
  if LSegIdx >= 0 then
    Exit(FSegments[LSegIdx].MemSizeOf(aPtr));
  if TryGetFallbackAlloc(aPtr, LAlloc) then
    Exit(LAlloc.Size);
  Result := 0;
end;

function TSlabPool.Stats: TSlabPoolStats;
var
  LIdx: Integer;
  LTotalCapacity: SizeUInt;
  LTotalUsed: SizeUInt;
begin
  LTotalCapacity := 0;
  LTotalUsed := 0;
  for LIdx := 0 to High(FSegments) do
    if FSegments[LIdx] <> nil then
    begin
      Inc(LTotalCapacity, FSegments[LIdx].Capacity);
      Inc(LTotalUsed, FSegments[LIdx].Used);
    end;

  Result.SegmentCount := Length(FSegments);
  Result.TotalCapacity := LTotalCapacity;
  Result.TotalUsed := LTotalUsed;
  Result.FallbackAllocCount := GetFallbackAllocCount;
  Result.FallbackBytes := FFbBytes;
end;

function TSlabPool.GetPerfCounters: TSlabPerfCounters; inline;
begin
  Result := FPerf;
end;

function TSlabPool.GetSegmentRegion(aIndex: Integer; out aStart, aEnd: PByte; out aPageShift: SizeUInt): Boolean;
begin
  Result := False;
  aStart := nil;
  aEnd := nil;
  aPageShift := 0;

  if (aIndex < 0) or (aIndex > High(FSegments)) then Exit(False);
  if FSegments[aIndex] = nil then Exit(False);

  aStart := FSegments[aIndex].RegionStart;
  aEnd := FSegments[aIndex].RegionEnd;
  aPageShift := FSegments[aIndex].PageShift;
  Result := (aStart <> nil) and (aEnd <> nil);
end;

function TSlabPool.TryGetFallbackAllocInfo(aPtr: Pointer; out aSize, aAlignment: SizeUInt): Boolean;
var
  LAlloc: TSlabFallbackAlloc;
begin
  aSize := 0;
  aAlignment := 0;
  Result := TryGetFallbackAlloc(aPtr, LAlloc);
  if Result then
  begin
    aSize := LAlloc.Size;
    aAlignment := LAlloc.Alignment;
  end;
end;

function TSlabPool.PageKeyOf(aPtr: Pointer): PtrUInt; inline;
begin
  Result := PtrUInt(aPtr) shr TFixedSlabPool(FSegments[0]).PageShift;
end;

procedure TSlabPool.PageMapInit(aMinCapacity: SizeUInt);
var
  LCap, LIndex, LLog, LTmp: SizeUInt;
begin
  LCap := HASH_MIN_CAP;
  while LCap < aMinCapacity do
    LCap := LCap shl 1;
  SetLength(FPageKeys, LCap);
  SetLength(FPageVals, LCap);
  for LIndex := 0 to LCap - 1 do
  begin
    FPageKeys[LIndex] := 0;
    FPageVals[LIndex] := -1;
  end;
  FPageMask := LCap - 1;
  // compute high-bit shift = 64 - log2(cap)
  LLog := 0;
  LTmp := LCap;
  while LTmp > 1 do
  begin
    Inc(LLog);
    LTmp := LTmp shr 1;
  end;
  FPageHighShift := SizeUInt(64 - LLog);
  FPageCount := 0;
end;

procedure TSlabPool.PageMapClear;
var
  LIndex: SizeUInt;
begin
  for LIndex := 0 to FPageMask do
  begin
    FPageKeys[LIndex] := 0;
    FPageVals[LIndex] := -1;
  end;
  FPageCount := 0;
end;

procedure TSlabPool.PageMapGrowIfNeeded(aNeedMore: SizeUInt);
var
  LOldKeys: array of PtrUInt;
  LOldVals: array of Integer;
  LOldCap, LIndex, LLog, LTmp: SizeUInt;
  LKey: PtrUInt;
  LVal: Integer;
  LPos: SizeUInt;
  LHash: QWord;
begin
  if (FPageCount + aNeedMore) <= ((FPageMask + 1) shr 1) then Exit; // load <= 0.5
  LOldCap := FPageMask + 1;
  LOldKeys := FPageKeys;
  LOldVals := FPageVals;
  SetLength(FPageKeys, LOldCap shl 1);
  SetLength(FPageVals, LOldCap shl 1);
  FPageMask := (LOldCap shl 1) - 1;
  // recompute high shift
  LLog := 0;
  LTmp := (FPageMask + 1);
  while LTmp > 1 do
  begin
    Inc(LLog);
    LTmp := LTmp shr 1;
  end;
  FPageHighShift := SizeUInt(64 - LLog);
  for LIndex := 0 to FPageMask do
  begin
    FPageKeys[LIndex] := 0;
    FPageVals[LIndex] := -1;
  end;
  FPageCount := 0;
  for LIndex := 0 to LOldCap - 1 do
  begin
    LKey := LOldKeys[LIndex];
    if LKey <> 0 then
    begin
      LVal := LOldVals[LIndex];
      // reinsert
      LHash := MulHash64(LKey);
      LPos := (LHash shr FPageHighShift) and FPageMask;
      while FPageKeys[LPos] <> 0 do
        LPos := (LPos + 1) and FPageMask;
      FPageKeys[LPos] := LKey;
      FPageVals[LPos] := LVal;
      Inc(FPageCount);
    end;
  end;
end;

procedure TSlabPool.PageMapInsert(aKey: PtrUInt; aSegIdx: Integer);
var
  LIndex: SizeUInt;
  LHash: QWord;
begin
  if aKey = 0 then aKey := 1; // reserve 0 as empty
  LHash := MulHash64(aKey);
  LIndex := (LHash shr FPageHighShift) and FPageMask;
  while FPageKeys[LIndex] <> 0 do
    LIndex := (LIndex + 1) and FPageMask;
  FPageKeys[LIndex] := aKey;
  FPageVals[LIndex] := aSegIdx;
  Inc(FPageCount);
end;

function TSlabPool.PageMapLookup(aKey: PtrUInt; out aSegIdx: Integer): Boolean; inline;
var
  LIndex: SizeUInt;
  LHash: QWord;
begin
  if aKey = 0 then aKey := 1;
  LHash := MulHash64(aKey);
  LIndex := (LHash shr FPageHighShift) and FPageMask;
  while True do
  begin
    if FPageKeys[LIndex] = 0 then Exit(False);
    if FPageKeys[LIndex] = aKey then
    begin
      aSegIdx := FPageVals[LIndex];
      Exit(True);
    end;
    LIndex := (LIndex + 1) and FPageMask;
  end;
end;

procedure TSlabPool.IndexSegmentPages(aSegIdx: Integer);
var
  LPtr, LEnd: PByte;
  LStep, LNeed, LCount: SizeUInt;
  LKey: PtrUInt;
begin
  LPtr := FSegments[aSegIdx].RegionStart;
  LEnd := FSegments[aSegIdx].RegionEnd;
  LStep := SizeUInt(1) shl FSegments[aSegIdx].PageShift;
  if LPtr = nil then Exit;
  // estimate number of pages to grow
  LNeed := (PtrUInt(LEnd) - PtrUInt(LPtr)) shr FSegments[aSegIdx].PageShift;
  if LNeed = 0 then Exit;
  PageMapGrowIfNeeded(LNeed);
  LCount := 0;
  while PtrUInt(LPtr) < PtrUInt(LEnd) do
  begin
    LKey := (PtrUInt(LPtr) shr FSegments[aSegIdx].PageShift);
    PageMapInsert(LKey, aSegIdx);
    Inc(LCount);
    Inc(PtrUInt(LPtr), LStep);
  end;
end;

constructor TSlabPool.Create(aCapacity: SizeUInt; aAllocator: IAllocator; aMinShift: SizeUInt);
var
  LSegment: TFixedSlabPool;
begin
  inherited Create;
  if aAllocator=nil then FAllocator:=nextpas.core.mem.allocator.GetRtlAllocator else FAllocator:=aAllocator;
  if aCapacity=0 then aCapacity:=64*1024;
  if aMinShift=0 then aMinShift:=3;

  if FConfig.MinShift = 0 then
  begin
    FConfig := CreateDefaultSlabConfig;
    FConfig.MinShift := aMinShift;
  end;
  if FConfig.PageSize = 0 then
    FConfig.PageSize := 4096;


  FInitialCapacity:=aCapacity; FMinShift:=aMinShift; FActive:=0;
  FillChar(FPerf, SizeOf(FPerf), 0);
  SetLength(FSegments,1);
  LSegment:=TFixedSlabPool.Create(aCapacity,FAllocator,aMinShift);
  FSegments[0]:=LSegment;
  FAvailCount := 0;  // 显式初始化
  FbMapInit(8);
  PageMapInit( (aCapacity shr LSegment.PageShift) * 2 );
  IndexSegmentPages(0);
end;

function TSlabPool.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := True;   // AllocMem 保证零填充
  Result.ThreadSafe      := False;  // 当前未加锁
  Result.HasMemSize      := True;   // 通过 ChunkSizeOf/MemSizeOf
  Result.SupportsAligned := False;  // 未提供对齐 API
end;

constructor TSlabPool.Create(aCapacity: SizeUInt; const aConfig: TSlabConfig; aAllocator: IAllocator);
begin
  // 忽略 aConfig.EnablePageMerging（兼容字段）
  // MinShift 和 MaxAllocSize 采纳
  FConfig := aConfig;
  if FConfig.MinShift=0 then FConfig.MinShift := 3;
  Create(aCapacity, aAllocator, FConfig.MinShift);
end;

function TSlabPool.Alloc(aSize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(aSize);
end;

procedure TSlabPool.Free(aPtr: Pointer); inline;
begin
  FreeMem(aPtr);
end;

procedure TSlabPool.ReleasePtr(aPtr: Pointer); inline;
begin
  FreeMem(aPtr);
end;





function TSlabPool.Warmup(aUnitSize: SizeUInt; aMinPages: SizeUInt): SizeUInt;
var
  LIndex: SizeUInt;
  LPerPage, LNeedUnits: SizeUInt;
  LTmp: array of Pointer;
begin
  if aUnitSize = 0 then Exit(0);
  LTmp := nil;
  LPerPage := (SizeUInt(1) shl FSegments[0].PageShift) div aUnitSize;
  if LPerPage = 0 then LPerPage := 1;
  LNeedUnits := LPerPage * aMinPages;
  SetLength(LTmp, LNeedUnits);
  Result := 0;
  for LIndex := 0 to LNeedUnits-1 do
  begin
    LTmp[LIndex] := GetMem(aUnitSize);
    if LTmp[LIndex] <> nil then Inc(Result) else Break;
  end;
  for LIndex := 0 to Result-1 do
    FreeMem(LTmp[LIndex]);
end;




destructor TSlabPool.Destroy;
var
  LIndex: Integer;
begin
  FreeAllFallbackAllocs;
  for LIndex:=0 to High(FSegments) do if FSegments[LIndex]<>nil then FSegments[LIndex].Free;
  inherited Destroy;
end;

function TSlabPool.TryAllocFromSeg(const aIdx: Integer; const aSize: SizeUInt): Pointer; inline;
begin
  if (aIdx>=0) and (aIdx<=High(FSegments)) and (FSegments[aIdx]<>nil) then Result:=FSegments[aIdx].GetMem(aSize)
  else Result:=nil;
end;

function TSlabPool.PopAvail(out aIdx: Integer): Boolean; inline;
begin
  if FAvailCount = 0 then Exit(False);
  Dec(FAvailCount);
  aIdx := FAvail[FAvailCount];
  Result := True;
end;

procedure TSlabPool.PushAvail(const aIdx: Integer); inline;
var
  LCap: Integer;
begin
  LCap := Length(FAvail);
  if FAvailCount >= LCap then
  begin
    // 容量倍增策略，最小 8
    if LCap < 8 then LCap := 8
    else LCap := LCap * 2;
    SetLength(FAvail, LCap);
  end;
  FAvail[FAvailCount] := aIdx;
  Inc(FAvailCount);
end;

function TSlabPool.NewSegmentCapacity: SizeUInt; inline;
var
  LCurrent: SizeUInt;
begin
  if (FActive>=0) and (FActive<=High(FSegments)) and (FSegments[FActive]<>nil) then LCurrent:=FSegments[FActive].Capacity else LCurrent:=FInitialCapacity;
  if LCurrent< FInitialCapacity then LCurrent:=FInitialCapacity;
  if LCurrent> (High(SizeUInt) shr 1) then Exit(LCurrent);
  Result:=LCurrent shl 1;
end;

function TSlabPool.FindOwnerSegment(aPtr: Pointer): Integer;
var
  LKey: PtrUInt;
  LSeg: Integer;
begin
  if aPtr=nil then Exit(-1);
  LKey := PageKeyOf(aPtr);
  if PageMapLookup(LKey, LSeg) then Exit(LSeg) else Exit(-1);
end;

function TSlabPool.Acquire(out aPtr: Pointer): Boolean;
var
  LUnitSize: SizeUInt;
begin
  LUnitSize := SizeUInt(1) shl FMinShift;
  if LUnitSize < SizeOf(Pointer) then
    LUnitSize := SizeOf(Pointer);
  aPtr := GetMem(LUnitSize);
  Result := aPtr <> nil;
end;

procedure TSlabPool.Release(aPtr: Pointer);
begin FreeMem(aPtr); end;

function TSlabPool.GetMem(aSize: SizeUInt): Pointer;
var
  LIndex: Integer;
  LPtr: Pointer;
  LNewSeg: TFixedSlabPool;
  LPerfEnabled: Boolean;
  LStart: QWord;
begin
  if aSize=0 then Exit(nil);
  LPerfEnabled := FConfig.EnablePerfMonitoring;
  if LPerfEnabled then
  begin
    Inc(FPerf.AllocCalls);
    LStart := GetTickCount64;
  end;
  try
    if IsOversize(aSize) then Exit(nil);
    if ShouldUseFallback(aSize) then
    begin
      Result := AllocFallback(aSize, 16);
      if Result <> nil then Inc(FTotalAllocs);
      Exit;
    end;
    LPtr:=TryAllocFromSeg(FActive,aSize);
    if LPtr<>nil then
    begin
      Inc(FTotalAllocs);
      Exit(LPtr);
    end;
    while PopAvail(LIndex) do
    begin
      LPtr:=TryAllocFromSeg(LIndex,aSize);
      if LPtr<>nil then
      begin
        FActive:=LIndex;
        Inc(FTotalAllocs);
        Exit(LPtr);
      end;
    end;
    LIndex:=Length(FSegments);
    SetLength(FSegments,LIndex+1);
    // ✅ P1-1: 添加 OOM 检查，防止 TFixedSlabPool.Create 失败后崩溃
    try
      LNewSeg := TFixedSlabPool.Create(NewSegmentCapacity,FAllocator,FMinShift);
    except
      on LError: Exception do
      begin
        SetLength(FSegments, LIndex); // 回滚数组长度
        Exit(nil);
      end;
    end;
    FSegments[LIndex] := LNewSeg;
    IndexSegmentPages(LIndex);
    FActive:=LIndex;
    Result:=FSegments[LIndex].GetMem(aSize);
    if Result<>nil then Inc(FTotalAllocs);
  finally
    if LPerfEnabled then
      Inc(FPerf.AllocTime, GetTickCount64 - LStart);
  end;
end;

function TSlabPool.AllocMem(aSize: SizeUInt): Pointer;
begin Result:=GetMem(aSize); if Result<>nil then FillChar(Result^,aSize,0); end;

function TSlabPool.ReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
var
  LIndex: Integer;
  LOldSize, LCopySize: SizeUInt;
  LAlloc: TSlabFallbackAlloc;
  LNew: Pointer;
begin
  if aDst=nil then Exit(GetMem(aSize));
  if aSize=0 then begin FreeMem(aDst); Exit(nil); end;
  if IsOversize(aSize) then Exit(nil);
  LIndex:=FindOwnerSegment(aDst);
  if LIndex>=0 then
  begin
    Result:=FSegments[LIndex].ReallocMem(aDst,aSize);
    if Result<>nil then Exit;
    // 跨段：安全拷贝再释放旧指针
    Result := GetMem(aSize);
    if Result=nil then Exit(nil);
    LOldSize := FSegments[LIndex].MemSizeOf(aDst);
    if LOldSize > aSize then LCopySize := aSize else LCopySize := LOldSize;
    if LCopySize>0 then Move(aDst^, Result^, LCopySize);
    FSegments[LIndex].FreeMem(aDst);
    Exit;
  end;
  // Fallback 路径：只有本池创建的 fallback 指针才允许被 Realloc
  if not TryGetFallbackAlloc(aDst, LAlloc) then
    raise ESlabPoolCorruption.Create(aeInvalidPointer, 'Pointer does not belong to this pool');

  // 尽可能保持对齐语义（复用原分配时的 Alignment）
  LNew := AllocAligned(aSize, LAlloc.Alignment);
  if LNew = nil then Exit(nil); // 失败时不修改原指针

  if LAlloc.Size > aSize then LCopySize := aSize else LCopySize := LAlloc.Size;
  if LCopySize > 0 then Move(aDst^, LNew^, LCopySize);

  // 释放旧块并移除 tracking（注意：先分配成功再销毁旧块）
  if TryUntrackFallbackAlloc(aDst, LAlloc) then
    if (FAllocator <> nil) and (LAlloc.RawPtr <> nil) then
      FAllocator.FreeMem(LAlloc.RawPtr);

  Result := LNew;
end;

procedure TSlabPool.FreeMem(aDst: Pointer);
var
  LIndex: Integer;
  LAlloc: TSlabFallbackAlloc;
  LPerfEnabled: Boolean;
  LStart: QWord;
begin
  if aDst=nil then Exit;
  LPerfEnabled := FConfig.EnablePerfMonitoring;
  if LPerfEnabled then
  begin
    Inc(FPerf.FreeCalls);
    LStart := GetTickCount64;
  end;
  try
    LIndex:=FindOwnerSegment(aDst);
    if LIndex>=0 then
    begin
      FSegments[LIndex].FreeMem(aDst);
      PushAvail(LIndex);
      Inc(FTotalFrees);
    end
    else if TryUntrackFallbackAlloc(aDst, LAlloc) then
    begin
      if (FAllocator <> nil) and (LAlloc.RawPtr <> nil) then
        FAllocator.FreeMem(LAlloc.RawPtr);
      Inc(FTotalFrees);
    end
    else
      raise ESlabPoolCorruption.Create(aeInvalidPointer, 'Pointer does not belong to this pool');
  finally
    if LPerfEnabled then
      Inc(FPerf.FreeTime, GetTickCount64 - LStart);
  end;
end;

function TSlabPool.Allocate(const ASize: SizeUInt): Pointer;
begin
  Result := GetMem(ASize);
end;

function TSlabPool.Reallocate(const APtr: Pointer; const ANewSize: SizeUInt): Pointer;
begin
  Result := ReallocMem(APtr, ANewSize);
end;

procedure TSlabPool.Deallocate(const APtr: Pointer);
begin
  FreeMem(APtr);
end;

procedure TSlabPool.Reset;
var
  LIndex: Integer;
begin
  FreeAllFallbackAllocs;
  for LIndex:=0 to High(FSegments) do if FSegments[LIndex]<>nil then FSegments[LIndex].Reset;
  FAvailCount := 0;  // 只重置计数，保留容量
  FActive:=0;
  // ✅ P0-1: Reset 必须清理并重建 PageMap，否则查找不一致
  PageMapClear;
  for LIndex := 0 to High(FSegments) do
    if FSegments[LIndex] <> nil then
      IndexSegmentPages(LIndex);
end;

function TSlabPool.TryAcquire(out aPtr: Pointer): Boolean;
begin
  Result := Acquire(aPtr);
end;

function TSlabPool.AcquireN(out aUnits: array of Pointer; aCount: Integer): Integer;
var
  LIdx: Integer;
begin
  Result := 0;
  for LIdx := 0 to aCount - 1 do
  begin
    if LIdx > High(aUnits) then
      Break;
    if not Acquire(aUnits[LIdx]) then
      Break;
    Inc(Result);
  end;
end;

procedure TSlabPool.ReleaseN(const aUnits: array of Pointer; aCount: Integer);
var
  LIdx: Integer;
begin
  for LIdx := 0 to aCount - 1 do
  begin
    if LIdx > High(aUnits) then
      Break;
    Release(aUnits[LIdx]);
  end;
end;

function TSlabPool.AllocAligned(aSize, aAlignment: SizeUInt): Pointer;
var
  LNaturalAlign: SizeUInt;
  LPerfEnabled: Boolean;
  LStart: QWord;
begin
  if aSize = 0 then Exit(nil);
  if IsOversize(aSize) then Exit(nil);

  LPerfEnabled := FConfig.EnablePerfMonitoring;

  if aAlignment < SizeOf(Pointer) then
    aAlignment := SizeOf(Pointer);
  if not IsPowerOfTwoSize(aAlignment) then
    raise EInvalidArgument.Create('TSlabPool.AllocAligned: aAlignment must be power of two and >= pointer size');

  if ShouldUseFallback(aSize) then
  begin
    if LPerfEnabled then
    begin
      Inc(FPerf.AllocCalls);
      LStart := GetTickCount64;
      try
        Result := AllocFallback(aSize, aAlignment);
      finally
        Inc(FPerf.AllocTime, GetTickCount64 - LStart);
      end;
    end
    else
      Result := AllocFallback(aSize, aAlignment);
    if Result <> nil then Inc(FTotalAllocs);
    Exit;
  end;

  LNaturalAlign := NaturalAlignmentForSize(aSize);
  if aAlignment <= LNaturalAlign then
    Result := GetMem(aSize)
  else
  begin
    if LPerfEnabled then
    begin
      Inc(FPerf.AllocCalls);
      LStart := GetTickCount64;
      try
        Result := AllocFallback(aSize, aAlignment);
      finally
        Inc(FPerf.AllocTime, GetTickCount64 - LStart);
      end;
    end
    else
      Result := AllocFallback(aSize, aAlignment);
    if Result <> nil then Inc(FTotalAllocs);
  end;
end;

procedure TSlabPool.FreeAligned(aPtr: Pointer);
begin
  // 与 FreeMem 语义保持一致：只要是本池分配的指针（slab / fallback）都可安全释放
  FreeMem(aPtr);
end;

{$POP}

end.
