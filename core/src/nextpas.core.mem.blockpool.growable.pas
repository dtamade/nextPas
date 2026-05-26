{
  nextpas.core.mem.blockpool.growable

  Growable fixed-size block pool for v2 IBlockPool.
  - Segment-based growth (similar spirit to jemalloc/tcmalloc arenas)
  - Intrusive free-list (no external free stack)
  - Per-segment free bitmap for double-free detection
}
unit nextpas.core.mem.blockpool.growable;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.math,              // ✅ Math facade (for trunc)
  nextpas.core.mem.blockpool,
  nextpas.core.mem.alloc,
  nextpas.core.mem.layout,
  nextpas.core.mem.error;

type
  TBlockPoolGrowthKind = (bpgkGeometric, bpgkLinear);

  TGrowingBlockPoolConfig = record
    BlockSize: SizeUInt;
    InitialCapacity: SizeUInt;
    MaxCapacity: SizeUInt;         // 0 = unlimited (by blocks)
    GrowthKind: TBlockPoolGrowthKind;
    GrowthFactor: Double;          // geometric only (>= 1.1 recommended)
    GrowthStep: SizeUInt;          // linear only (>= 1)
    Alignment: SizeUInt;           // 0 = DEFAULT_ALIGNMENT, must be power of two
    Allocator: IAlloc;             // nil = system heap (GetMem/FreeMem)
    KeepSegments: Boolean;         // keep extra segments on Reset

    class function Default(aBlockSize, aInitialCapacity: SizeUInt): TGrowingBlockPoolConfig; static;
  end;

  {**
   * TGrowingBlockPool
   *
   * @desc Growable fixed-size block pool (segment-based).
   *
   * @thread_safety Not thread-safe; wrap with mutex/sharded pool for concurrency.
   *}
  TGrowingBlockPool = class(TInterfacedObject, IBlockPool, IBlockPoolBatch)
  private
    type
      TSegment = record
        Raw: Pointer;          // pointer returned by allocator/GetMem (for free)
        RawSize: SizeUInt;     // bytes passed to allocator/GetMem
        Base: PByte;           // aligned base
        Size: SizeUInt;        // usable bytes (= Blocks * BlockSize)
        Blocks: SizeUInt;      // number of blocks in this segment
        FreeBits: array of QWord; // 1=free, 0=allocated
      end;
  private
    FBlockSize: SizeUInt;
    FBlockShift: SizeUInt; // log2(BlockSize) if power-of-two, else 0
    FBlockMask: SizeUInt;  // BlockSize-1 if power-of-two, else 0
    FAlignment: SizeUInt;

    FSegments: array of TSegment; // sorted by Base asc
    FFreeHead: Pointer;

    FTotalCapacity: SizeUInt; // blocks
    FAllocCount: SizeUInt;    // blocks in-use

    // ✅ Phase 4.7 优化：缓存最后查找的段（利用局部性原理，预期提升 20-40%）
    FLastSegmentIndex: SizeInt;  // 缓存最后查找的段索引（-1 = 无缓存）
    FLastSegmentBase: PByte;     // 缓存最后查找的段基址
    FLastSegmentEnd: PByte;      // 缓存最后查找的段结束地址

    // growth policy
    FInitialCapacity: SizeUInt;
    FMaxCapacity: SizeUInt;
    FGrowthKind: TBlockPoolGrowthKind;
    FGrowthFactor: Double;
    FGrowthStep: SizeUInt;
    FKeepSegments: Boolean;

    FAllocator: IAlloc;

    // statistics
    FPeakAlloc: SizeUInt;
    FTotalAllocs: QWord;
    FTotalFrees: QWord;
  private
    function IsFreeBitSet(aSegIndex: SizeInt; aBlockIndex: SizeUInt): Boolean; inline;
    procedure SetFreeBit(aSegIndex: SizeInt; aBlockIndex: SizeUInt); inline;
    procedure ClearFreeBit(aSegIndex: SizeInt; aBlockIndex: SizeUInt); inline;

    procedure PushFree(aPtr: Pointer); inline;
    function PopFree: Pointer; inline;

    // ✅ Phase 4.5 优化：添加 inline 指令强制编译器内联（最关键的热路径）
    function FindSegment(aPtr: Pointer; out aIndex: SizeInt): Boolean; inline;
    function NextGrowthBlocks: SizeUInt;
    function AddSegment(aBlocks: SizeUInt): Boolean;

    procedure RebuildFreeList;
    procedure FreeSegment(aIndex: SizeInt);
    procedure ShrinkToSegmentCount(aCount: SizeInt);
  public
    constructor Create(const aConfig: TGrowingBlockPoolConfig); overload;
    constructor Create(aBlockSize, aInitialCapacity: SizeUInt; aAlignment: SizeUInt = DEFAULT_ALIGNMENT); overload;
    destructor Destroy; override;

    { IBlockPool }
    function Acquire: Pointer;
    function TryAcquire(out aPtr: Pointer): Boolean;
    procedure Release(aPtr: Pointer);
    procedure Reset;
    function BlockSize: SizeUInt;
    function Capacity: SizeUInt;
    function Available: SizeUInt;
    function InUse: SizeUInt;

    { IBlockPoolBatch }
    function AcquireN(out aPtrs: array of Pointer; aCount: Integer): Integer;
    procedure ReleaseN(const aPtrs: array of Pointer; aCount: Integer);

    { Diagnostics }
    function SegmentCount: SizeUInt; inline;
    function GetSegmentRegion(aIndex: SizeInt; out aStart, aEnd: PByte): Boolean;

    property PeakAlloc: SizeUInt read FPeakAlloc;
    property TotalAllocs: QWord read FTotalAllocs;
    property TotalFrees: QWord read FTotalFrees;
    property Alignment: SizeUInt read FAlignment;
  end;

implementation

{$PUSH}
{$WARN 4055 OFF} // pointer/ordinal conversions in pool internals

class function TGrowingBlockPoolConfig.Default(aBlockSize, aInitialCapacity: SizeUInt): TGrowingBlockPoolConfig;
begin
  Result.BlockSize := aBlockSize;
  Result.InitialCapacity := aInitialCapacity;
  Result.MaxCapacity := 0;
  Result.GrowthKind := bpgkGeometric;
  Result.GrowthFactor := 2.0;
  Result.GrowthStep := 0;
  Result.Alignment := 0;
  Result.Allocator := nil;
  Result.KeepSegments := True;
end;

function TGrowingBlockPool.IsFreeBitSet(aSegIndex: SizeInt; aBlockIndex: SizeUInt): Boolean;
var
  LWordIndex: SizeUInt;
  LMask: QWord;
begin
  LWordIndex := aBlockIndex shr 6;
  LMask := QWord(1) shl (aBlockIndex and 63);
  Result := (FSegments[aSegIndex].FreeBits[LWordIndex] and LMask) <> 0;
end;

procedure TGrowingBlockPool.SetFreeBit(aSegIndex: SizeInt; aBlockIndex: SizeUInt);
var
  LWordIndex: SizeUInt;
  LMask: QWord;
begin
  LWordIndex := aBlockIndex shr 6;
  LMask := QWord(1) shl (aBlockIndex and 63);
  FSegments[aSegIndex].FreeBits[LWordIndex] := FSegments[aSegIndex].FreeBits[LWordIndex] or LMask;
end;

procedure TGrowingBlockPool.ClearFreeBit(aSegIndex: SizeInt; aBlockIndex: SizeUInt);
var
  LWordIndex: SizeUInt;
  LMask: QWord;
begin
  LWordIndex := aBlockIndex shr 6;
  LMask := QWord(1) shl (aBlockIndex and 63);
  FSegments[aSegIndex].FreeBits[LWordIndex] := FSegments[aSegIndex].FreeBits[LWordIndex] and (not LMask);
end;

procedure TGrowingBlockPool.PushFree(aPtr: Pointer);
begin
  PPointer(aPtr)^ := FFreeHead;
  FFreeHead := aPtr;
end;

function TGrowingBlockPool.PopFree: Pointer;
begin
  Result := FFreeHead;
  if Result = nil then
    Exit(nil);
  FFreeHead := PPointer(Result)^;
end;

// ✅ Phase 4.5 优化：添加 inline 指令强制编译器内联（最关键的热路径）
// ✅ Phase 4.7 优化：添加段缓存，利用局部性原理减少二分查找次数（预期提升 20-40%）
function TGrowingBlockPool.FindSegment(aPtr: Pointer; out aIndex: SizeInt): Boolean; inline;
var
  LLeft, LRight, LMid: SizeInt;
  LPtrU: PtrUInt;
  LBaseU: PtrUInt;
  LDiff: PtrUInt;
begin
  Result := False;
  aIndex := -1;
  if (aPtr = nil) or (Length(FSegments) = 0) then
    Exit;

  LPtrU := PtrUInt(aPtr);

  // ✅ Phase 4.7 优化：快速路径 - 检查缓存的段（O(1) vs O(log n)）
  // 利用局部性原理：连续的 Acquire/Release 操作通常在同一段内
  if (FLastSegmentIndex >= 0) and (FLastSegmentIndex <= High(FSegments)) then
  begin
    if (LPtrU >= PtrUInt(FLastSegmentBase)) and (LPtrU < PtrUInt(FLastSegmentEnd)) then
    begin
      aIndex := FLastSegmentIndex;
      Exit(True);
    end;
  end;

  // ✅ Phase 4.7 优化：慢速路径 - 缓存未命中，执行二分查找
  LLeft := 0;
  LRight := High(FSegments);
  while LLeft <= LRight do
  begin
    LMid := (LLeft + LRight) shr 1;
    LBaseU := PtrUInt(FSegments[LMid].Base);
    if LPtrU < LBaseU then
    begin
      LRight := LMid - 1;
      Continue;
    end;
    LDiff := LPtrU - LBaseU;
    if LDiff < PtrUInt(FSegments[LMid].Size) then
    begin
      aIndex := LMid;
      // ✅ Phase 4.7 优化：更新缓存，为下次查找做准备
      FLastSegmentIndex := LMid;
      FLastSegmentBase := FSegments[LMid].Base;
      FLastSegmentEnd := FSegments[LMid].Base + FSegments[LMid].Size;
      Exit(True);
    end;
    LLeft := LMid + 1;
  end;
end;

function TGrowingBlockPool.NextGrowthBlocks: SizeUInt;
var
  LStep: SizeUInt;
  LFactor: Double;
  LDesiredTotalF: Double;
  LDesiredTotal: SizeUInt;
  LAdd: SizeUInt;
begin
  if (FMaxCapacity <> 0) and (FTotalCapacity >= FMaxCapacity) then
    Exit(0);

  Result := 64;
  case FGrowthKind of
    bpgkLinear:
      begin
        LStep := FGrowthStep;
        if LStep = 0 then
          LStep := 64;
        Result := LStep;
      end;
  else
    begin
      if FTotalCapacity = 0 then
        Exit(64);

      LFactor := FGrowthFactor;
      if LFactor < 1.1 then
        LFactor := 2.0;

      LDesiredTotalF := Double(FTotalCapacity) * LFactor;
      if LDesiredTotalF > Double(High(SizeUInt)) then
        LDesiredTotal := High(SizeUInt)
      else
      begin
        LDesiredTotal := SizeUInt(Trunc(LDesiredTotalF));
        if Double(LDesiredTotal) < LDesiredTotalF then
          Inc(LDesiredTotal);
      end;

      if LDesiredTotal <= FTotalCapacity then
      begin
        if FTotalCapacity > (High(SizeUInt) - FTotalCapacity) then
          LDesiredTotal := High(SizeUInt)
        else
          LDesiredTotal := FTotalCapacity + FTotalCapacity;
      end;

      LAdd := LDesiredTotal - FTotalCapacity;
      if LAdd = 0 then
        LAdd := 1;
      Result := LAdd;
    end;
  end;

  if (FMaxCapacity <> 0) and (Result > (FMaxCapacity - FTotalCapacity)) then
    Result := FMaxCapacity - FTotalCapacity;
end;

function TGrowingBlockPool.AddSegment(aBlocks: SizeUInt): Boolean;
var
  LBytes: SizeUInt;
  LAllocSize: SizeUInt;
  LRaw: Pointer;
  LRes: TAllocResult;
  LAddr, LAligned: PtrUInt;
  LMask: SizeUInt;
  LSeg: TSegment;
  LNewBase: PByte;
  LNewBlocks: SizeUInt;
  LWordLen: SizeUInt;
  LIdx: SizeInt;
  LInsert: SizeInt;
  LTmpSeg: TSegment;
  LPtr: PByte;
  LBlockIndex: SizeUInt;
begin
  Result := False;
  if aBlocks = 0 then
    Exit(False);

  if (FMaxCapacity <> 0) then
  begin
    if FTotalCapacity >= FMaxCapacity then
      Exit(False);
    if aBlocks > (FMaxCapacity - FTotalCapacity) then
      aBlocks := FMaxCapacity - FTotalCapacity;
    if aBlocks = 0 then
      Exit(False);
  end;

  LBytes := aBlocks * FBlockSize;
  if (FBlockSize <> 0) and ((LBytes div FBlockSize) <> aBlocks) then
    raise EAllocError.Create(aeOutOfMemory, 'TGrowingBlockPool: segment size overflow');

  if FAlignment <= 1 then
    LAllocSize := LBytes
  else
    LAllocSize := LBytes + (FAlignment - 1);
  if LAllocSize < LBytes then
    raise EAllocError.Create(aeOutOfMemory, 'TGrowingBlockPool: allocation size overflow');

  if FAllocator <> nil then
  begin
    LRes := FAllocator.Alloc(TMemLayout.Create(LAllocSize, MEM_DEFAULT_ALIGN));
    if LRes.IsErr or (LRes.Ptr = nil) then
      Exit(False);
    LRaw := LRes.Ptr;
  end
  else
  begin
    GetMem(LRaw, LAllocSize);
    if LRaw = nil then
      Exit(False);
  end;

  LAddr := PtrUInt(LRaw);
  if FAlignment <= 1 then
    LAligned := LAddr
  else
  begin
    LMask := FAlignment - 1;
    if PtrUInt(LMask) > (High(PtrUInt) - LAddr) then
    begin
      if FAllocator <> nil then
        FAllocator.Dealloc(LRaw, TMemLayout.Create(LAllocSize, MEM_DEFAULT_ALIGN))
      else
        FreeMem(LRaw);
      Exit(False);
    end;
    LAligned := (LAddr + PtrUInt(LMask)) and not PtrUInt(LMask);
  end;

  LSeg.Raw := LRaw;
  LSeg.RawSize := LAllocSize;
  LSeg.Base := PByte(LAligned);
  LSeg.Size := LBytes;
  LSeg.Blocks := aBlocks;

  LNewBase := LSeg.Base;
  LNewBlocks := aBlocks;

  LWordLen := (aBlocks + 63) shr 6;
  SetLength(LSeg.FreeBits, SizeInt(LWordLen));
  if LWordLen > 0 then
    FillChar(LSeg.FreeBits[0], LWordLen * SizeOf(QWord), $FF);

  // append segment then keep array sorted by Base
  LIdx := Length(FSegments);
  SetLength(FSegments, LIdx + 1);
  FSegments[LIdx] := LSeg;

  if Length(FSegments) > 1 then
  begin
    LInsert := High(FSegments);
    while (LInsert > 0) and (PtrUInt(FSegments[LInsert - 1].Base) > PtrUInt(FSegments[LInsert].Base)) do
    begin
      LTmpSeg := FSegments[LInsert - 1];
      FSegments[LInsert - 1] := FSegments[LInsert];
      FSegments[LInsert] := LTmpSeg;
      Dec(LInsert);
    end;
    // ✅ Phase 4.7 优化：更新缓存到新添加的段（排序后的最终位置）
    FLastSegmentIndex := LInsert;
    FLastSegmentBase := FSegments[LInsert].Base;
    FLastSegmentEnd := FSegments[LInsert].Base + FSegments[LInsert].Size;
  end
  else
  begin
    // ✅ Phase 4.7 优化：第一个段，直接设置缓存
    FLastSegmentIndex := 0;
    FLastSegmentBase := FSegments[0].Base;
    FLastSegmentEnd := FSegments[0].Base + FSegments[0].Size;
  end;

  // build a contiguous intrusive free-list for this segment and link it to current head
  if (LNewBase <> nil) and (LNewBlocks > 0) then
  begin
    LPtr := LNewBase;
    if LNewBlocks > 1 then
      for LBlockIndex := 0 to LNewBlocks - 2 do
      begin
        PPointer(LPtr)^ := Pointer(LPtr + FBlockSize);
        Inc(LPtr, FBlockSize);
      end;
    PPointer(LPtr)^ := FFreeHead;
    FFreeHead := LNewBase;
  end;

  Inc(FTotalCapacity, LNewBlocks);
  Result := True;
end;

procedure TGrowingBlockPool.RebuildFreeList;
var
  LSegIndex: SizeInt;
  LLen: SizeInt;
  LPtr: PByte;
  LBlockIndex: SizeUInt;
  LBlocks: SizeUInt;
begin
  FAllocCount := 0;
  FFreeHead := nil;

  if Length(FSegments) = 0 then
    Exit;

  for LSegIndex := 0 to High(FSegments) do
  begin
    LLen := Length(FSegments[LSegIndex].FreeBits);
    if LLen > 0 then
      FillChar(FSegments[LSegIndex].FreeBits[0], SizeUInt(LLen) * SizeOf(QWord), $FF);

    if (FSegments[LSegIndex].Base = nil) or (FSegments[LSegIndex].Blocks = 0) then
      Continue;

    LBlocks := FSegments[LSegIndex].Blocks;
    LPtr := FSegments[LSegIndex].Base;
    if LBlocks > 1 then
      for LBlockIndex := 0 to LBlocks - 2 do
      begin
        PPointer(LPtr)^ := Pointer(LPtr + FBlockSize);
        Inc(LPtr, FBlockSize);
      end;
    PPointer(LPtr)^ := FFreeHead;
    FFreeHead := FSegments[LSegIndex].Base;
  end;
end;

procedure TGrowingBlockPool.FreeSegment(aIndex: SizeInt);
var
  LRaw: Pointer;
  LRawSize: SizeUInt;
  LBlocks: SizeUInt;
begin
  if (aIndex < 0) or (aIndex > High(FSegments)) then
    Exit;

  LRaw := FSegments[aIndex].Raw;
  LRawSize := FSegments[aIndex].RawSize;
  LBlocks := FSegments[aIndex].Blocks;

  FSegments[aIndex].Raw := nil;
  FSegments[aIndex].RawSize := 0;
  FSegments[aIndex].Base := nil;
  FSegments[aIndex].Size := 0;
  FSegments[aIndex].Blocks := 0;
  SetLength(FSegments[aIndex].FreeBits, 0);

  if LBlocks <> 0 then
    Dec(FTotalCapacity, LBlocks);

  if LRaw = nil then
    Exit;

  if FAllocator <> nil then
    FAllocator.Dealloc(LRaw, TMemLayout.Create(LRawSize, MEM_DEFAULT_ALIGN))
  else
    FreeMem(LRaw);
end;

procedure TGrowingBlockPool.ShrinkToSegmentCount(aCount: SizeInt);
var
  LIdx: SizeInt;
begin
  if aCount < 0 then
    aCount := 0;
  if aCount >= Length(FSegments) then
    Exit;

  for LIdx := High(FSegments) downto aCount do
    FreeSegment(LIdx);

  SetLength(FSegments, aCount);
end;

constructor TGrowingBlockPool.Create(const aConfig: TGrowingBlockPoolConfig);
var
  LAlign: SizeUInt;
  LActualBlockSize: SizeUInt;
  LMask: SizeUInt;
  LShift: SizeUInt;
  LTmp: SizeUInt;
  LInitCap: SizeUInt;
begin
  inherited Create;

  if aConfig.BlockSize = 0 then
    raise EAllocError.Create(aeInvalidLayout, 'TGrowingBlockPool: block size must be > 0');

  LAlign := aConfig.Alignment;
  if LAlign = 0 then
    LAlign := DEFAULT_ALIGNMENT
  else
  begin
    if (LAlign and (LAlign - 1)) <> 0 then
      raise EAllocError.Create(aeAlignmentNotSupported, 'TGrowingBlockPool: alignment must be power of 2');
    if LAlign < MEM_DEFAULT_ALIGN then
      LAlign := MEM_DEFAULT_ALIGN;
  end;

  if aConfig.BlockSize < LAlign then
    LActualBlockSize := LAlign
  else
  begin
    LMask := LAlign - 1;
    if aConfig.BlockSize > (High(SizeUInt) - LMask) then
      raise EAllocError.Create(aeInvalidLayout, 'TGrowingBlockPool: block size overflow');
    LActualBlockSize := (aConfig.BlockSize + LMask) and not LMask;
  end;

  FBlockSize := LActualBlockSize;
  FAlignment := LAlign;

  if IsPowerOfTwo(FBlockSize) then
  begin
    FBlockMask := FBlockSize - 1;
    LShift := 0;
    LTmp := FBlockSize;
    while LTmp > 1 do
    begin
      Inc(LShift);
      LTmp := LTmp shr 1;
    end;
    FBlockShift := LShift;
  end
  else
  begin
    FBlockMask := 0;
    FBlockShift := 0;
  end;

  FAllocator := aConfig.Allocator;
  FKeepSegments := aConfig.KeepSegments;
  FInitialCapacity := aConfig.InitialCapacity;
  if FInitialCapacity = 0 then
    FInitialCapacity := 64;

  FMaxCapacity := aConfig.MaxCapacity;
  if (FMaxCapacity <> 0) and (FMaxCapacity < FInitialCapacity) then
    FMaxCapacity := FInitialCapacity;

  FGrowthKind := aConfig.GrowthKind;
  FGrowthFactor := aConfig.GrowthFactor;
  FGrowthStep := aConfig.GrowthStep;
  if (FGrowthKind = bpgkGeometric) and (FGrowthFactor < 1.1) then
    FGrowthFactor := 2.0;
  if (FGrowthKind = bpgkLinear) and (FGrowthStep = 0) then
    FGrowthStep := 64;

  SetLength(FSegments, 0);
  FFreeHead := nil;
  FTotalCapacity := 0;
  FAllocCount := 0;
  FPeakAlloc := 0;
  FTotalAllocs := 0;
  FTotalFrees := 0;

  // ✅ Phase 4.7 优化：初始化段缓存为无效状态
  FLastSegmentIndex := -1;
  FLastSegmentBase := nil;
  FLastSegmentEnd := nil;

  LInitCap := FInitialCapacity;
  if not AddSegment(LInitCap) then
    raise EAllocError.Create(aeOutOfMemory, 'TGrowingBlockPool: failed to allocate initial segment');
end;

constructor TGrowingBlockPool.Create(aBlockSize, aInitialCapacity: SizeUInt; aAlignment: SizeUInt);
var
  LConfig: TGrowingBlockPoolConfig;
begin
  LConfig := TGrowingBlockPoolConfig.Default(aBlockSize, aInitialCapacity);
  LConfig.Alignment := aAlignment;
  Create(LConfig);
end;

destructor TGrowingBlockPool.Destroy;
begin
  ShrinkToSegmentCount(0);
  FFreeHead := nil;
  inherited Destroy;
end;

function TGrowingBlockPool.Acquire: Pointer;
var
  LPtr: Pointer;
  LSegIndex: SizeInt;
  LSeg: TSegment;
  LDiff: PtrUInt;
  LIdx: SizeUInt;
begin
  LPtr := PopFree;
  if LPtr = nil then
  begin
    if not AddSegment(NextGrowthBlocks) then
      Exit(nil);
    LPtr := PopFree;
    if LPtr = nil then
      Exit(nil);
  end;

  if not FindSegment(LPtr, LSegIndex) then
    raise EAllocError.Create(aeInternalError, 'TGrowingBlockPool.Acquire: free list corruption (unknown segment)');
  LSeg := FSegments[LSegIndex];

  LDiff := PtrUInt(LPtr) - PtrUInt(LSeg.Base);
  if FBlockMask <> 0 then
  begin
    {$IFDEF DEBUG}
    Assert((LDiff and PtrUInt(FBlockMask)) = 0, 'TGrowingBlockPool.Acquire: internal misalignment');
    {$ENDIF}
    LIdx := SizeUInt(LDiff shr FBlockShift);
  end
  else
    LIdx := SizeUInt(LDiff div FBlockSize);

  {$IFDEF DEBUG}
  Assert(LIdx < LSeg.Blocks, 'TGrowingBlockPool.Acquire: internal block index out of range');
  Assert(IsFreeBitSet(LSegIndex, LIdx), 'TGrowingBlockPool.Acquire: internal corruption (double allocate)');
  {$ENDIF}
  ClearFreeBit(LSegIndex, LIdx);

  Inc(FAllocCount);
  Inc(FTotalAllocs);
  if FAllocCount > FPeakAlloc then
    FPeakAlloc := FAllocCount;

  Result := LPtr;
end;

function TGrowingBlockPool.TryAcquire(out aPtr: Pointer): Boolean;
begin
  aPtr := Acquire;
  Result := aPtr <> nil;
end;

function TGrowingBlockPool.AcquireN(out aPtrs: array of Pointer; aCount: Integer): Integer;
var
  LIdx: Integer;
  LPtr: Pointer;
begin
  Result := 0;
  if aCount <= 0 then Exit(0);
  for LIdx := 0 to aCount - 1 do
  begin
    if LIdx > High(aPtrs) then
      Break;
    LPtr := Acquire;
    if LPtr = nil then
      Break;
    aPtrs[LIdx] := LPtr;
    Inc(Result);
  end;
end;

procedure TGrowingBlockPool.ReleaseN(const aPtrs: array of Pointer; aCount: Integer);
var
  LIdx: Integer;
begin
  if aCount <= 0 then Exit;
  for LIdx := 0 to aCount - 1 do
  begin
    if LIdx > High(aPtrs) then
      Break;
    Release(aPtrs[LIdx]);
  end;
end;

procedure TGrowingBlockPool.Release(aPtr: Pointer);
var
  LSegIndex: SizeInt;
  LSeg: TSegment;
  LDiff: PtrUInt;
  LIdx: SizeUInt;
begin
  if aPtr = nil then
    Exit;

  if not FindSegment(aPtr, LSegIndex) then
    raise EAllocError.Create(aeInvalidPointer, 'TGrowingBlockPool.Release: pointer not owned');
  LSeg := FSegments[LSegIndex];

  LDiff := PtrUInt(aPtr) - PtrUInt(LSeg.Base);
  if (LDiff >= PtrUInt(LSeg.Size)) then
    raise EAllocError.Create(aeInvalidPointer, 'TGrowingBlockPool.Release: pointer out of range');

  if FBlockMask <> 0 then
  begin
    if (LDiff and PtrUInt(FBlockMask)) <> 0 then
      raise EAllocError.Create(aeInvalidPointer, 'TGrowingBlockPool.Release: misaligned pointer');
    LIdx := SizeUInt(LDiff shr FBlockShift);
  end
  else
  begin
    if (LDiff mod FBlockSize) <> 0 then
      raise EAllocError.Create(aeInvalidPointer, 'TGrowingBlockPool.Release: misaligned pointer');
    LIdx := SizeUInt(LDiff div FBlockSize);
  end;

  if LIdx >= LSeg.Blocks then
    raise EAllocError.Create(aeInvalidPointer, 'TGrowingBlockPool.Release: block index out of range');

  if IsFreeBitSet(LSegIndex, LIdx) then
    raise EAllocError.Create(aeDoubleFree, 'TGrowingBlockPool.Release: double free detected');

  {$IFDEF FAF_MEM_DEBUG}
  FillChar((PByte(LSeg.Base) + LIdx * FBlockSize)^, FBlockSize, $A5);
  {$ENDIF}

  SetFreeBit(LSegIndex, LIdx);
  {$IFDEF DEBUG}
  Assert(FAllocCount > 0, 'TGrowingBlockPool.Release: internal corruption (alloc count underflow)');
  {$ENDIF}
  Dec(FAllocCount);
  Inc(FTotalFrees);
  PushFree(aPtr);
end;

procedure TGrowingBlockPool.Reset;
begin
  if not FKeepSegments then
  begin
    // keep at least one segment to preserve basic usability
    if Length(FSegments) > 1 then
      ShrinkToSegmentCount(1);
  end;
  RebuildFreeList;
end;

function TGrowingBlockPool.BlockSize: SizeUInt;
begin
  Result := FBlockSize;
end;

function TGrowingBlockPool.Capacity: SizeUInt;
begin
  Result := FTotalCapacity;
end;

function TGrowingBlockPool.Available: SizeUInt;
begin
  Result := FTotalCapacity - FAllocCount;
end;

function TGrowingBlockPool.InUse: SizeUInt;
begin
  Result := FAllocCount;
end;

function TGrowingBlockPool.SegmentCount: SizeUInt;
begin
  Result := SizeUInt(Length(FSegments));
end;

function TGrowingBlockPool.GetSegmentRegion(aIndex: SizeInt; out aStart, aEnd: PByte): Boolean;
begin
  aStart := nil;
  aEnd := nil;
  Result := False;

  if (aIndex < 0) or (aIndex > High(FSegments)) then
    Exit(False);
  if FSegments[aIndex].Base = nil then
    Exit(False);
  aStart := FSegments[aIndex].Base;
  aEnd := FSegments[aIndex].Base + FSegments[aIndex].Size;
  Result := aEnd > aStart;
end;

{$POP}

end.
