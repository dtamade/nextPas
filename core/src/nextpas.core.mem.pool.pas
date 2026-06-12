unit nextpas.core.mem.pool;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.error,
  nextpas.core.mem.allocator.base,
  nextpas.core.mem.pool.base,
  nextpas.core.mem.pool.memory_pool,
  nextpas.core.mem.pool.fixed_slab;

type
  IPool = nextpas.core.mem.pool.base.IPool;
  IMemoryPool = nextpas.core.mem.pool.memory_pool.IMemoryPool;
  IFixedSlabPool = nextpas.core.mem.pool.fixed_slab.IFixedSlabPool;
  TFixedSlabPool = nextpas.core.mem.pool.fixed_slab.TFixedSlabPool;

  {**
   * @desc 固定大小块池，O(1) 分配/释放
   * @note 非线程安全。适用于频繁创建/销毁相同大小对象的场景
   *}
  TLocalBlockPool = record
  private
    FBacking: Pointer;
    FBlockSize: SizeUInt;
    FBlockCount: SizeUInt;
    FFreeStack: Pointer;
    FAcquired: SizeUInt;
  public
    procedure Init(const ABlockSize: SizeUInt; const ABlockCount: SizeUInt);
    procedure Done;

    function Acquire: Pointer;
    procedure Release(const APtr: Pointer);
    procedure Reset;

    function BlockSize: SizeUInt; inline;
    function BlockCount: SizeUInt; inline;
    function AcquiredCount: SizeUInt; inline;
    function AvailableCount: SizeUInt; inline;
    function IsFull: Boolean; inline;
    function IsEmpty: Boolean; inline;
    function Owns(const APtr: Pointer): Boolean;
  end;

  TPool = TLocalBlockPool;

function MakeFixedSlabPool(ACapacity: SizeUInt; AAllocator: IAllocator; AMinShift: SizeUInt = 3): IFixedSlabPool; overload;
function MakeFixedSlabPool(ACapacity: SizeUInt; AAllocator: IAllocator): IFixedSlabPool; overload;
function MakeFixedSlabPool(ACapacity: SizeUInt): IFixedSlabPool; overload;

implementation

type
  PFreeNode = ^TFreeNode;
  TFreeNode = record
    Next: PFreeNode;
  end;

function MakeFixedSlabPool(ACapacity: SizeUInt; AAllocator: IAllocator; AMinShift: SizeUInt): IFixedSlabPool;
begin
  Result := TFixedSlabPool.Create(ACapacity, AAllocator, AMinShift);
end;

function MakeFixedSlabPool(ACapacity: SizeUInt; AAllocator: IAllocator): IFixedSlabPool;
begin
  Result := TFixedSlabPool.Create(ACapacity, AAllocator);
end;

function MakeFixedSlabPool(ACapacity: SizeUInt): IFixedSlabPool;
begin
  Result := TFixedSlabPool.Create(ACapacity);
end;

{ TLocalBlockPool }

procedure TLocalBlockPool.Init(const ABlockSize: SizeUInt; const ABlockCount: SizeUInt);
var
  LActualBlockSize: SizeUInt;
  LI: SizeUInt;
  LNode: PFreeNode;
  LTotalSize: SizeUInt;
begin
  LActualBlockSize := ABlockSize;
  if LActualBlockSize < SizeOf(TFreeNode) then
    LActualBlockSize := SizeOf(TFreeNode);
  FBlockSize := LActualBlockSize;
  FBlockCount := ABlockCount;
  FAcquired := 0;

  LTotalSize := LActualBlockSize * ABlockCount;
  if (LActualBlockSize <> 0) and ((LTotalSize div LActualBlockSize) <> ABlockCount) then
    raise EOutOfMemory.Create(aeOutOfMemory, 'TLocalBlockPool.Init: size overflow');
  FBacking := GetMem(LTotalSize);
  if FBacking = nil then
    raise EOutOfMemory.Create(aeOutOfMemory, 'TLocalBlockPool.Init: out of memory');
  FillChar(FBacking^, LTotalSize, 0);

  FFreeStack := nil;
  for LI := 0 to ABlockCount - 1 do
  begin
    LNode := PFreeNode(FBacking + LI * LActualBlockSize);
    LNode^.Next := PFreeNode(FFreeStack);
    FFreeStack := LNode;
  end;
end;

procedure TLocalBlockPool.Done;
begin
  if FBacking <> nil then
  begin
    FreeMem(FBacking);
    FBacking := nil;
  end;
  FFreeStack := nil;
  FBlockCount := 0;
  FAcquired := 0;
end;

function TLocalBlockPool.Acquire: Pointer;
var
  LNode: PFreeNode;
begin
  LNode := PFreeNode(FFreeStack);
  if LNode = nil then
    Exit(nil);
  FFreeStack := LNode^.Next;
  Inc(FAcquired);
  Result := Pointer(LNode);
end;

procedure TLocalBlockPool.Release(const APtr: Pointer);
var
  LNode: PFreeNode;
  LScan: PFreeNode;
  LDiff: PtrUInt;
  LScanned: SizeUInt;
begin
  if APtr = nil then
    Exit;
  if not Owns(APtr) then
    raise EAllocError.Create(aeInvalidPointer, 'TLocalBlockPool.Release: pointer not owned');
  LDiff := PtrUInt(APtr) - PtrUInt(FBacking);
  if (FBlockSize = 0) or ((LDiff mod FBlockSize) <> 0) then
    raise EAllocError.Create(aeInvalidPointer, 'TLocalBlockPool.Release: misaligned pointer');

  LScan := PFreeNode(FFreeStack);
  LScanned := 0;
  while (LScan <> nil) and (LScanned < FBlockCount) do
  begin
    if Pointer(LScan) = APtr then
      raise EAllocError.Create(aeDoubleFree, 'TLocalBlockPool.Release: double free detected');
    LScan := LScan^.Next;
    Inc(LScanned);
  end;
  if FAcquired = 0 then
    raise EAllocError.Create(aeDoubleFree, 'TLocalBlockPool.Release: allocation count underflow');

  LNode := PFreeNode(APtr);
  LNode^.Next := PFreeNode(FFreeStack);
  FFreeStack := LNode;
  Dec(FAcquired);
end;

procedure TLocalBlockPool.Reset;
var
  LI: SizeUInt;
  LNode: PFreeNode;
begin
  FFreeStack := nil;
  FAcquired := 0;
  for LI := 0 to FBlockCount - 1 do
  begin
    LNode := PFreeNode(FBacking + LI * FBlockSize);
    LNode^.Next := PFreeNode(FFreeStack);
    FFreeStack := LNode;
  end;
end;

function TLocalBlockPool.BlockSize: SizeUInt;
begin
  Result := FBlockSize;
end;

function TLocalBlockPool.BlockCount: SizeUInt;
begin
  Result := FBlockCount;
end;

function TLocalBlockPool.AcquiredCount: SizeUInt;
begin
  Result := FAcquired;
end;

function TLocalBlockPool.AvailableCount: SizeUInt;
begin
  Result := FBlockCount - FAcquired;
end;

function TLocalBlockPool.IsFull: Boolean;
begin
  Result := FAcquired >= FBlockCount;
end;

function TLocalBlockPool.IsEmpty: Boolean;
begin
  Result := FAcquired = 0;
end;

function TLocalBlockPool.Owns(const APtr: Pointer): Boolean;
var
  LStart: PtrUInt;
  LAddr: PtrUInt;
  LTotalSize: SizeUInt;
begin
  Result := False;
  if (APtr = nil) or (FBacking = nil) or (FBlockSize = 0) or (FBlockCount = 0) then
    Exit;

  LStart := PtrUInt(FBacking);
  LAddr := PtrUInt(APtr);
  if LAddr < LStart then
    Exit;

  LTotalSize := FBlockSize * FBlockCount;
  Result := (LAddr - LStart) < LTotalSize;
end;

end.
