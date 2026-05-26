unit nextpas.core.mem.pool;

{$I nextpas.core.settings.inc}

interface

uses
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
  TPool = record
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

{ TPool }

procedure TPool.Init(const ABlockSize: SizeUInt; const ABlockCount: SizeUInt);
var
  LActualBlockSize: SizeUInt;
  LI: SizeUInt;
  LNode: PFreeNode;
begin
  LActualBlockSize := ABlockSize;
  if LActualBlockSize < SizeOf(TFreeNode) then
    LActualBlockSize := SizeOf(TFreeNode);
  FBlockSize := LActualBlockSize;
  FBlockCount := ABlockCount;
  FAcquired := 0;

  FBacking := GetMem(LActualBlockSize * ABlockCount);
  FillChar(FBacking^, LActualBlockSize * ABlockCount, 0);

  FFreeStack := nil;
  for LI := 0 to ABlockCount - 1 do
  begin
    LNode := PFreeNode(FBacking + LI * LActualBlockSize);
    LNode^.Next := PFreeNode(FFreeStack);
    FFreeStack := LNode;
  end;
end;

procedure TPool.Done;
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

function TPool.Acquire: Pointer;
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

procedure TPool.Release(const APtr: Pointer);
var
  LNode: PFreeNode;
begin
  LNode := PFreeNode(APtr);
  LNode^.Next := PFreeNode(FFreeStack);
  FFreeStack := LNode;
  Dec(FAcquired);
end;

procedure TPool.Reset;
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

function TPool.BlockSize: SizeUInt;
begin
  Result := FBlockSize;
end;

function TPool.BlockCount: SizeUInt;
begin
  Result := FBlockCount;
end;

function TPool.AcquiredCount: SizeUInt;
begin
  Result := FAcquired;
end;

function TPool.AvailableCount: SizeUInt;
begin
  Result := FBlockCount - FAcquired;
end;

function TPool.IsFull: Boolean;
begin
  Result := FAcquired >= FBlockCount;
end;

function TPool.IsEmpty: Boolean;
begin
  Result := FAcquired = 0;
end;

function TPool.Owns(const APtr: Pointer): Boolean;
begin
  Result := (APtr >= FBacking) and
            (APtr < FBacking + FBlockSize * FBlockCount);
end;

end.
