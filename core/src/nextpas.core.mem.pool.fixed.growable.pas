unit nextpas.core.mem.pool.fixed.growable;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.math,              // ✅ Math facade (for trunc)
  nextpas.core.mem.error,
  nextpas.core.mem.pool.base,     // IPool (decoupled)
  nextpas.core.mem.allocator;     // IAllocator + GetRtlAllocator

type
  EGrowingFixedPoolError = class(EAllocError);
  EGrowingFixedPoolInvalidPointer = class(EGrowingFixedPoolError);
  EGrowingFixedPoolDoubleFree = class(EGrowingFixedPoolError);

  TGrowthKind = (gkGeometric, gkLinear);

  TGrowingFixedPoolConfig = record
    BlockSize: SizeUInt;
    InitialCapacity: SizeUInt;
    GrowthKind: TGrowthKind;
    GrowthFactor: Double;  // for Geometric (>= 1.1)
    GrowthStep: SizeUInt;  // for Linear
    MaxCapacity: SizeUInt; // 0 = unlimited
    ZeroOnInit: Boolean;
    Allocator: IAllocator;
  end;

  { TGrowingFixedPool }
  TGrowingFixedPool = class(TInterfacedObject, IPool)
  private
    type
      TArena = record
        Base: Pointer;
        Blocks: SizeUInt; // number of blocks in this arena
        Size: SizeUInt;   // bytes = Blocks * BlockSize
        // per-block allocation tracking (1 = allocated, 0 = free)
        AllocBits: array of QWord;
      end;
  private
    FBlockSize: SizeUInt;
    FBlockShift: SizeUInt; // log2(BlockSize), BlockSize is power of two
    FBlockMask: SizeUInt;  // BlockSize - 1
    FTotalCapacity: SizeUInt;
    FAllocatedCount: SizeUInt;

    FArenas: array of TArena;

    FFreeStack: array of Pointer;
    FFreeTop: SizeUInt;

    FAllocator: IAllocator;

    FConfig: TGrowingFixedPoolConfig;

    function GetArenaCount: SizeUInt; inline;
    procedure PushFree(aPtr: Pointer); inline;
    function PopFree(out aPtr: Pointer): Boolean; inline;
    procedure AddArena(aBlocks: SizeUInt);
    function NextGrowthSize: SizeUInt;
    function FindArena(aPtr: Pointer; out aIndex: SizeInt): Boolean;
    function PointerBelongsToArena(aPtr: Pointer; const aArena: TArena): Boolean; inline;
    function IsAllocatedBitSet(aArenaIndex: SizeInt; aBlockIndex: SizeUInt): Boolean; inline;
    procedure SetAllocatedBit(aArenaIndex: SizeInt; aBlockIndex: SizeUInt); inline;
    procedure ClearAllocatedBit(aArenaIndex: SizeInt; aBlockIndex: SizeUInt); inline;
    procedure ClearArenaAllocBits(aArenaIndex: SizeInt); inline;
  public
    constructor Create(const aConfig: TGrowingFixedPoolConfig);
    destructor Destroy; override;

    // IPool
    function Acquire(out aUnit: Pointer): Boolean; inline;
    function TryAcquire(out aPtr: Pointer): Boolean; inline;
    function AcquireN(out aPtrs: array of Pointer; aCount: Integer): Integer;
    procedure Release(aUnit: Pointer); inline;
    procedure ReleaseN(const aPtrs: array of Pointer; aCount: Integer);
    procedure Reset; inline;

    // 管理
    function ShrinkTo(aMinCapacity: SizeUInt): SizeUInt; // returns freed blocks

    // Props
    property BlockSize: SizeUInt read FBlockSize;
    property TotalCapacity: SizeUInt read FTotalCapacity;
    property AllocatedCount: SizeUInt read FAllocatedCount;
    property ArenaCount: SizeUInt read GetArenaCount;
    function FreeCount: SizeUInt; inline;
  end;

implementation

function TGrowingFixedPool.GetArenaCount: SizeUInt;
begin
  Result := SizeUInt(Length(FArenas));
end;

function TGrowingFixedPool.PointerBelongsToArena(aPtr: Pointer; const aArena: TArena): Boolean;
var
  LPtrU, LBaseU: PtrUInt;
begin
  if (aPtr = nil) or (aArena.Base = nil) then
    Exit(False);
  LPtrU := PtrUInt(aPtr);
  LBaseU := PtrUInt(aArena.Base);
  if LPtrU < LBaseU then
    Exit(False);
  Result := (LPtrU - LBaseU) < PtrUInt(aArena.Size);
end;

function TGrowingFixedPool.IsAllocatedBitSet(aArenaIndex: SizeInt; aBlockIndex: SizeUInt): Boolean;
var
  LWordIndex: SizeUInt;
  LMask: QWord;
begin
  if (aArenaIndex < 0) or (aArenaIndex > High(FArenas)) then
    Exit(False);
  LWordIndex := aBlockIndex shr 6;
  if LWordIndex >= SizeUInt(Length(FArenas[aArenaIndex].AllocBits)) then
    Exit(False);
  LMask := QWord(1) shl (aBlockIndex and 63);
  Result := (FArenas[aArenaIndex].AllocBits[LWordIndex] and LMask) <> 0;
end;

procedure TGrowingFixedPool.SetAllocatedBit(aArenaIndex: SizeInt; aBlockIndex: SizeUInt);
var
  LWordIndex: SizeUInt;
  LMask: QWord;
begin
  LWordIndex := aBlockIndex shr 6;
  if (aArenaIndex < 0) or (aArenaIndex > High(FArenas)) or
     (LWordIndex >= SizeUInt(Length(FArenas[aArenaIndex].AllocBits))) then
    raise EGrowingFixedPoolError.Create(aeInternalError, 'TGrowingFixedPool: allocation bitmap out of range');
  LMask := QWord(1) shl (aBlockIndex and 63);
  if (FArenas[aArenaIndex].AllocBits[LWordIndex] and LMask) <> 0 then
    raise EGrowingFixedPoolError.Create(aeInternalError, 'TGrowingFixedPool: free stack corruption (double allocate)');
  FArenas[aArenaIndex].AllocBits[LWordIndex] := FArenas[aArenaIndex].AllocBits[LWordIndex] or LMask;
end;

procedure TGrowingFixedPool.ClearAllocatedBit(aArenaIndex: SizeInt; aBlockIndex: SizeUInt);
var
  LWordIndex: SizeUInt;
  LMask: QWord;
begin
  LWordIndex := aBlockIndex shr 6;
  if (aArenaIndex < 0) or (aArenaIndex > High(FArenas)) or
     (LWordIndex >= SizeUInt(Length(FArenas[aArenaIndex].AllocBits))) then
    raise EGrowingFixedPoolError.Create(aeInternalError, 'TGrowingFixedPool: allocation bitmap out of range');
  LMask := QWord(1) shl (aBlockIndex and 63);
  FArenas[aArenaIndex].AllocBits[LWordIndex] := FArenas[aArenaIndex].AllocBits[LWordIndex] and (not LMask);
end;

procedure TGrowingFixedPool.ClearArenaAllocBits(aArenaIndex: SizeInt);
var
  LLen: SizeInt;
begin
  if (aArenaIndex < 0) or (aArenaIndex > High(FArenas)) then
    Exit;
  LLen := Length(FArenas[aArenaIndex].AllocBits);
  if LLen <= 0 then
    Exit;
  FillChar(FArenas[aArenaIndex].AllocBits[0], SizeUInt(LLen) * SizeOf(QWord), 0);
end;


{ TGrowingFixedPool }

constructor TGrowingFixedPool.Create(const aConfig: TGrowingFixedPoolConfig);
var
  LInitCap: SizeUInt;
  LShift: SizeUInt;
  LTmp: SizeUInt;
begin
  inherited Create;

  if (aConfig.BlockSize = 0) then
    raise EGrowingFixedPoolError.Create(aeInvalidLayout, 'Block size cannot be zero');
  // 强制 2 的幂：启用位运算路径，提高释放/校验效率
  if (aConfig.BlockSize and (aConfig.BlockSize - 1)) <> 0 then
    raise EGrowingFixedPoolError.Create(aeInvalidLayout, 'Block size must be power of two');
  if (SizeOf(Pointer) <> 0) and ((aConfig.BlockSize mod SizeOf(Pointer)) <> 0) then
    raise EGrowingFixedPoolError.Create(aeInvalidLayout, 'Block size must be a multiple of pointer size');

  FConfig := aConfig;
  FBlockSize := aConfig.BlockSize;
  FBlockMask := FBlockSize - 1;

  // 计算 log2(BlockSize)
  LShift := 0;
  LTmp := FBlockSize;
  while LTmp > 1 do
  begin
    Inc(LShift);
    LTmp := LTmp shr 1;
  end;
  FBlockShift := LShift;

  if aConfig.Allocator = nil then
    FAllocator := nextpas.core.mem.allocator.GetRtlAllocator
  else
    FAllocator := aConfig.Allocator;

  SetLength(FArenas, 0);
  SetLength(FFreeStack, 0);
  FFreeTop := 0;
  FTotalCapacity := 0;
  FAllocatedCount := 0;

  // sanitize growth config
  if (FConfig.GrowthKind = gkGeometric) and (FConfig.GrowthFactor < 1.1) then
    FConfig.GrowthFactor := 2.0;
  if (FConfig.GrowthKind = gkLinear) and (FConfig.GrowthStep = 0) then
    FConfig.GrowthStep := 64;

  // initial arena
  LInitCap := aConfig.InitialCapacity;
  if LInitCap = 0 then
    LInitCap := 64;
  AddArena(LInitCap);
end;

procedure TGrowingFixedPool.AddArena(aBlocks: SizeUInt);
var
  LBytes: SizeUInt;
  LArena: TArena;
  LBlockIndex: SizeUInt;
  LNewTop: SizeUInt;
  LNewLen: SizeUInt;
  LBasePtr: PByte;
  LInsert: SizeInt;
  LWordLen: SizeUInt;
begin
  if aBlocks = 0 then
    Exit;

  if (FConfig.MaxCapacity <> 0) then
  begin
    if FTotalCapacity >= FConfig.MaxCapacity then
      Exit;
    if aBlocks > (FConfig.MaxCapacity - FTotalCapacity) then
      aBlocks := FConfig.MaxCapacity - FTotalCapacity;
    if aBlocks = 0 then
      Exit;
  end;

  LBytes := aBlocks * FBlockSize;
  if (FBlockSize <> 0) and ((LBytes div FBlockSize) <> aBlocks) then
    raise EGrowingFixedPoolError.Create(aeOutOfMemory, 'Total size overflow');

  LArena.Base := FAllocator.GetMem(LBytes);
  if LArena.Base = nil then
    raise EGrowingFixedPoolError.Create(aeOutOfMemory, 'Failed to allocate arena');
  LArena.Blocks := aBlocks;
  LArena.Size := LBytes;

  // allocation bitmap (default all-free = 0)
  LWordLen := (aBlocks + 63) shr 6;
  SetLength(LArena.AllocBits, LWordLen);
  if LWordLen > 0 then
    FillChar(LArena.AllocBits[0], LWordLen * SizeOf(QWord), 0);

  if FConfig.ZeroOnInit then
    FillChar(LArena.Base^, LArena.Size, 0);

  // append arena
  SetLength(FArenas, Length(FArenas) + 1);
  FArenas[High(FArenas)] := LArena;

  // grow free stack space and push all blocks
  if FFreeTop > (High(SizeUInt) - aBlocks) then
    raise EGrowingFixedPoolError.Create(aeOutOfMemory, 'Free stack size overflow');
  LNewLen := FFreeTop + aBlocks;
  if SizeUInt(Length(FFreeStack)) < LNewLen then
    SetLength(FFreeStack, LNewLen);

  LBasePtr := PByte(LArena.Base);
  LNewTop := FFreeTop;
  for LBlockIndex := 0 to aBlocks - 1 do
  begin
    FFreeStack[LNewTop] := Pointer(LBasePtr + LBlockIndex * FBlockSize);
    Inc(LNewTop);
  end;
  FFreeTop := LNewTop;

  Inc(FTotalCapacity, aBlocks);

  // keep arenas sorted by Base for binary search in Release
  // insertion sort (arena count is expected to be small)
  if Length(FArenas) > 1 then
  begin
    LInsert := High(FArenas);
    while (LInsert > 0) and (PtrUInt(FArenas[LInsert - 1].Base) > PtrUInt(FArenas[LInsert].Base)) do
    begin
      LArena := FArenas[LInsert - 1];
      FArenas[LInsert - 1] := FArenas[LInsert];
      FArenas[LInsert] := LArena;
      Dec(LInsert);
    end;
  end;
end;

function TGrowingFixedPool.NextGrowthSize: SizeUInt;
var
  LStep: SizeUInt;
  LFactor: Double;
  LDesiredTotalF: Double;
  LDesiredTotal: SizeUInt;
  LAdd: SizeUInt;
begin
  if (FConfig.MaxCapacity <> 0) and (FTotalCapacity >= FConfig.MaxCapacity) then
    Exit(0);

  Result := 64;
  case FConfig.GrowthKind of
    gkLinear:
    begin
      LStep := FConfig.GrowthStep;
      if LStep = 0 then
        LStep := 64;
      Result := LStep;
    end;

    gkGeometric:
    begin
      if FTotalCapacity = 0 then
        Exit(64);

      LFactor := FConfig.GrowthFactor;
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

  if (FConfig.MaxCapacity <> 0) and (Result > (FConfig.MaxCapacity - FTotalCapacity)) then
    Result := FConfig.MaxCapacity - FTotalCapacity;
end;

function TGrowingFixedPool.FindArena(aPtr: Pointer; out aIndex: SizeInt): Boolean;
var
  LLeft, LRight, LMid: SizeInt;
  LPtrU: PtrUInt;
  LBaseU: PtrUInt;
  LDiff: PtrUInt;
begin
  Result := False;
  aIndex := -1;
  if (aPtr = nil) or (Length(FArenas) = 0) then
    Exit;

  LLeft := 0;
  LRight := High(FArenas);
  LPtrU := PtrUInt(aPtr);
  while LLeft <= LRight do
  begin
    LMid := (LLeft + LRight) shr 1;
    LBaseU := PtrUInt(FArenas[LMid].Base);
    if LPtrU < LBaseU then
    begin
      LRight := LMid - 1;
      Continue;
    end
    else
    begin
      LDiff := LPtrU - LBaseU;
      if LDiff < PtrUInt(FArenas[LMid].Size) then
      begin
        aIndex := LMid;
        Exit(True);
      end;
      LLeft := LMid + 1;
    end;
  end;
end;

procedure TGrowingFixedPool.PushFree(aPtr: Pointer);
begin
  if FFreeTop >= SizeUInt(Length(FFreeStack)) then
  begin
    if SizeUInt(Length(FFreeStack)) < (FFreeTop + 1) then
      SetLength(FFreeStack, (FFreeTop + 1) * 2)
    else
      SetLength(FFreeStack, FFreeTop + 1);
  end;
  FFreeStack[FFreeTop] := aPtr;
  Inc(FFreeTop);
end;

function TGrowingFixedPool.PopFree(out aPtr: Pointer): Boolean;
begin
  if FFreeTop = 0 then Exit(False);
  Dec(FFreeTop);
  aPtr := FFreeStack[FFreeTop];
  Result := True;
end;

function TGrowingFixedPool.Acquire(out aUnit: Pointer): Boolean;
var
  LArenaIndex: SizeInt;
  LArena: TArena;
  LDiff: PtrUInt;
  LBlockIndex: SizeUInt;
begin
  aUnit := nil;
  if not PopFree(aUnit) then
  begin
    AddArena(NextGrowthSize);
    if not PopFree(aUnit) then
      Exit(False);
  end;

  if not FindArena(aUnit, LArenaIndex) then
    raise EGrowingFixedPoolError.Create(aeInternalError, 'TGrowingFixedPool: free stack corruption (unknown arena)');

  LArena := FArenas[LArenaIndex];
  LDiff := PtrUInt(aUnit) - PtrUInt(LArena.Base);
  if (LDiff >= PtrUInt(LArena.Size)) or ((LDiff and PtrUInt(FBlockMask)) <> 0) then
    raise EGrowingFixedPoolError.Create(aeInternalError, 'TGrowingFixedPool: free stack corruption (misaligned pointer)');

  LBlockIndex := SizeUInt(LDiff shr FBlockShift);
  if LBlockIndex >= LArena.Blocks then
    raise EGrowingFixedPoolError.Create(aeInternalError, 'TGrowingFixedPool: free stack corruption (block index out of range)');

  SetAllocatedBit(LArenaIndex, LBlockIndex);
  Inc(FAllocatedCount);
  Result := True;
end;

procedure TGrowingFixedPool.Release(aUnit: Pointer);
var
  LArenaIndex: SizeInt;
  LArena: TArena;
  LPtrU, LBaseU: PtrUInt;
  LDiff: PtrUInt;
  LBlockIndex: SizeUInt;
begin
  if aUnit = nil then
    Exit;

  if not FindArena(aUnit, LArenaIndex) then
    raise EGrowingFixedPoolInvalidPointer.Create(aeInvalidPointer, 'Pointer does not belong to this pool');

  LArena := FArenas[LArenaIndex];
  LPtrU := PtrUInt(aUnit);
  LBaseU := PtrUInt(LArena.Base);
  if LPtrU < LBaseU then
    raise EGrowingFixedPoolInvalidPointer.Create(aeInvalidPointer, 'Pointer out of range');
  LDiff := LPtrU - LBaseU;
  if LDiff >= PtrUInt(LArena.Size) then
    raise EGrowingFixedPoolInvalidPointer.Create(aeInvalidPointer, 'Pointer out of range');
  // 位对齐检查（FBlockSize 为 2 的幂）
  if (LDiff and PtrUInt(FBlockMask)) <> 0 then
    raise EGrowingFixedPoolInvalidPointer.Create(aeInvalidPointer, 'Pointer is not aligned to block size');

  LBlockIndex := SizeUInt(LDiff shr FBlockShift);
  if LBlockIndex >= LArena.Blocks then
    raise EGrowingFixedPoolInvalidPointer.Create(aeInvalidPointer, 'Pointer block index out of range');

  if not IsAllocatedBitSet(LArenaIndex, LBlockIndex) then
    raise EGrowingFixedPoolDoubleFree.Create(aeDoubleFree, 'Double free detected');
  ClearAllocatedBit(LArenaIndex, LBlockIndex);

  if FAllocatedCount = 0 then
    raise EGrowingFixedPoolError.Create(aeInternalError, 'TGrowingFixedPool: allocated counter underflow');

  PushFree(aUnit);
  Dec(FAllocatedCount);
end;

procedure TGrowingFixedPool.Reset;
var
  LArenaIndex: SizeInt;
  LBlockIndex: SizeUInt;
  LBasePtr: PByte;
begin
  // 重建自由栈
  FFreeTop := 0;
  if FTotalCapacity = 0 then
    SetLength(FFreeStack, 0)
  else
    SetLength(FFreeStack, FTotalCapacity);
  for LArenaIndex := 0 to High(FArenas) do
  begin
    ClearArenaAllocBits(LArenaIndex);
    LBasePtr := PByte(FArenas[LArenaIndex].Base);
    for LBlockIndex := 0 to FArenas[LArenaIndex].Blocks - 1 do
    begin
      FFreeStack[FFreeTop] := Pointer(LBasePtr + LBlockIndex * FBlockSize);
      Inc(FFreeTop);
    end;
  end;
  FAllocatedCount := 0;
end;

function TGrowingFixedPool.FreeCount: SizeUInt;
begin
  Result := FTotalCapacity - FAllocatedCount;
end;

function TGrowingFixedPool.ShrinkTo(aMinCapacity: SizeUInt): SizeUInt;
var
  LKeep: SizeUInt;
  LArenaIndex: SizeInt;
  LArena: TArena;
  LRemoved: SizeUInt;
  LScan: SizeInt;
  LPtr: Pointer;
  LWordIndex: SizeInt;
  LHasAlloc: Boolean;
begin
  Result := 0;
  if Length(FArenas) = 0 then
    Exit;
  if aMinCapacity < FAllocatedCount then
    LKeep := FAllocatedCount
  else
    LKeep := aMinCapacity;

  LArenaIndex := High(FArenas);
  while (LArenaIndex >= 0) and (FTotalCapacity > LKeep) do
  begin
    LArena := FArenas[LArenaIndex];
    if (FTotalCapacity - LArena.Blocks) < LKeep then
      Break;

    // 若该 arena 仍有已分配块，则按“只释放尾部 arena”的语义停止收缩
    LHasAlloc := False;
    for LWordIndex := 0 to High(LArena.AllocBits) do
      if LArena.AllocBits[LWordIndex] <> 0 then
      begin
        LHasAlloc := True;
        Break;
      end;
    if LHasAlloc then
      Break;

    // 统计并移除自由栈中属于该 Arena 的空闲块
    LRemoved := 0;
    if FFreeTop = 0 then
      Break;
    LScan := SizeInt(FFreeTop) - 1;
    while (LScan >= 0) and (LRemoved < LArena.Blocks) do
    begin
      LPtr := FFreeStack[LScan];
      if PointerBelongsToArena(LPtr, LArena) then
      begin
        // swap-remove at LScan with top-1; do not decrement LScan, re-examine swapped element
        FFreeStack[LScan] := FFreeStack[FFreeTop - 1];
        Dec(FFreeTop);
        Inc(LRemoved);
        Continue;
      end;
      Dec(LScan);
    end;

    if LRemoved = LArena.Blocks then
    begin
      FAllocator.FreeMem(LArena.Base);
      Dec(FTotalCapacity, LArena.Blocks);
      // 删除尾部 arena（数组按 Base 排序，尾部即最大 Base）
      SetLength(FArenas, LArenaIndex);
      Inc(Result, LArena.Blocks);
    end
    else
      Break;

    Dec(LArenaIndex);
  end;
end;

destructor TGrowingFixedPool.Destroy;
var
  LArenaIndex: SizeInt;
begin
  for LArenaIndex := 0 to High(FArenas) do
    if FArenas[LArenaIndex].Base <> nil then
      FAllocator.FreeMem(FArenas[LArenaIndex].Base);
  SetLength(FArenas, 0);
  SetLength(FFreeStack, 0);
  inherited Destroy;
end;

function TGrowingFixedPool.TryAcquire(out aPtr: Pointer): Boolean;
begin
  Result := Acquire(aPtr);
end;

function TGrowingFixedPool.AcquireN(out aPtrs: array of Pointer; aCount: Integer): Integer;
var
  LIdx: Integer;
  LPtr: Pointer;
begin
  Result := 0;
  for LIdx := 0 to aCount - 1 do
  begin
    if LIdx > High(aPtrs) then
      Break;
    if Acquire(LPtr) then
    begin
      aPtrs[LIdx] := LPtr;
      Inc(Result);
    end
    else
      Break;
  end;
end;

procedure TGrowingFixedPool.ReleaseN(const aPtrs: array of Pointer; aCount: Integer);
var
  LIdx: Integer;
begin
  for LIdx := 0 to aCount - 1 do
  begin
    if LIdx > High(aPtrs) then
      Break;
    Release(aPtrs[LIdx]);
  end;
end;


end.
