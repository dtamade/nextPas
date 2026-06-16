unit nextpas.core.mem.pool;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.error,
  nextpas.core.mem.intf,
  nextpas.core.mem.pool.base,
  nextpas.core.mem.pool.memory_pool,
  nextpas.core.mem.pool.fixed_slab;

type
  IPool = nextpas.core.mem.pool.base.IPool;
  IMemoryPool = nextpas.core.mem.pool.memory_pool.IMemoryPool;
  IFixedSlabPool = nextpas.core.mem.pool.fixed_slab.IFixedSlabPool;
  TFixedSlabPool = nextpas.core.mem.pool.fixed_slab.TFixedSlabPool;

  {**
   * @desc 固定大小块池，O(1) 分配/释放，O(1) double-free 检测（位图）。
   *       以 class 实现以避免 owning record 的隐式复制 double-free 风险。
   * @note 非线程安全。适用于频繁创建/销毁相同大小对象的场景。
   *}
  TLocalBlockPool = class
  private
    FBacking: Pointer;
    FBlockSize: SizeUInt;
    FBlockCount: SizeUInt;
    FFreeStack: Pointer;
    FAcquired: SizeUInt;
    {** 位图：1=free, 0=allocated。用于 O(1) double-free 检测。 }
    FFreeBits: array of QWord;
    function BlockIndex(const APtr: Pointer): SizeUInt; inline;
    function IsFreeBit(const AIdx: SizeUInt): Boolean; inline;
    procedure ClearFreeBit(const AIdx: SizeUInt); inline;
    procedure SetFreeBit(const AIdx: SizeUInt); inline;
  public
    {** 创建块池，分配 ABlockCount 个 ABlockSize 字节的块。 }
    constructor Create(const ABlockSize: SizeUInt; const ABlockCount: SizeUInt);
    {** 释放后备内存。 }
    destructor Destroy; override;

    {** 从池中获取一个块，池空返回 nil。 }
    function Acquire: Pointer;
    {** 尝试从池中获取一个块，成功返回 True。 }
    function TryAcquire(out APtr: Pointer): Boolean;
    {** 归还一个块到池中。非法指针或重复释放抛出异常。 }
    procedure Release(const APtr: Pointer);
    {** 重置池，所有块可重新分配。 }
    procedure Reset;

    {** 返回每个块的字节大小。 }
    function BlockSize: SizeUInt; inline;
    {** 返回块池总块数。 }
    function Capacity: SizeUInt; inline;
    {** 返回当前可用（未分配）块数。 }
    function Available: SizeUInt; inline;
    {** 返回当前已分配块数。 }
    function InUse: SizeUInt; inline;
    {** 池是否已满（所有块已分配）。 }
    function IsFull: Boolean; inline;
    {** 池是否为空（无块被分配）。 }
    function IsEmpty: Boolean; inline;
    {** 指针是否属于本池。 }
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

{ TLocalBlockPool - bitmap helpers }

function TLocalBlockPool.BlockIndex(const APtr: Pointer): SizeUInt;
begin
  Result := (PtrUInt(APtr) - PtrUInt(FBacking)) div FBlockSize;
end;

function TLocalBlockPool.IsFreeBit(const AIdx: SizeUInt): Boolean;
begin
  Result := (FFreeBits[AIdx shr 6] and (QWord(1) shl (AIdx and 63))) <> 0;
end;

procedure TLocalBlockPool.ClearFreeBit(const AIdx: SizeUInt);
begin
  FFreeBits[AIdx shr 6] := FFreeBits[AIdx shr 6] and not (QWord(1) shl (AIdx and 63));
end;

procedure TLocalBlockPool.SetFreeBit(const AIdx: SizeUInt);
begin
  FFreeBits[AIdx shr 6] := FFreeBits[AIdx shr 6] or (QWord(1) shl (AIdx and 63));
end;

{ TLocalBlockPool }

constructor TLocalBlockPool.Create(const ABlockSize: SizeUInt; const ABlockCount: SizeUInt);
var
  LActualBlockSize: SizeUInt;
  LI: SizeUInt;
  LNode: PFreeNode;
  LTotalSize: SizeUInt;
  LBitWords: SizeUInt;
begin
  inherited Create;
  LActualBlockSize := ABlockSize;
  if LActualBlockSize < SizeOf(TFreeNode) then
    LActualBlockSize := SizeOf(TFreeNode);
  FBlockSize := LActualBlockSize;
  FBlockCount := ABlockCount;
  FAcquired := 0;

  LTotalSize := LActualBlockSize * ABlockCount;
  if (LActualBlockSize <> 0) and ((LTotalSize div LActualBlockSize) <> ABlockCount) then
    raise EOutOfMemory.Create(aeOutOfMemory, 'TLocalBlockPool.Create: size overflow');
  FBacking := GetMem(LTotalSize);
  if FBacking = nil then
    raise EOutOfMemory.Create(aeOutOfMemory, 'TLocalBlockPool.Create: out of memory');
  FillChar(FBacking^, LTotalSize, 0);

  { 初始化位图：所有块标记为 free（位=1） }
  LBitWords := (ABlockCount + 63) shr 6;
  SetLength(FFreeBits, LBitWords);
  FillChar(FFreeBits[0], LBitWords * SizeOf(QWord), $FF);

  FFreeStack := nil;
  for LI := 0 to ABlockCount - 1 do
  begin
    LNode := PFreeNode(PtrUInt(FBacking) + LI * LActualBlockSize);
    LNode^.Next := PFreeNode(FFreeStack);
    FFreeStack := LNode;
  end;
end;

destructor TLocalBlockPool.Destroy;
begin
  if FBacking <> nil then
  begin
    FreeMem(FBacking);
    FBacking := nil;
  end;
  FFreeStack := nil;
  FBlockCount := 0;
  FAcquired := 0;
  FFreeBits := nil;
  inherited;
end;

function TLocalBlockPool.Acquire: Pointer;
var
  LNode: PFreeNode;
  LIdx: SizeUInt;
begin
  LNode := PFreeNode(FFreeStack);
  if LNode = nil then
    Exit(nil);
  FFreeStack := LNode^.Next;
  Inc(FAcquired);
  { 标记为 allocated（清除 free 位） }
  LIdx := BlockIndex(Pointer(LNode));
  ClearFreeBit(LIdx);
  Result := Pointer(LNode);
end;

function TLocalBlockPool.TryAcquire(out APtr: Pointer): Boolean;
begin
  APtr := Acquire;
  Result := APtr <> nil;
end;

procedure TLocalBlockPool.Release(const APtr: Pointer);
var
  LNode: PFreeNode;
  LDiff: PtrUInt;
  LIdx: SizeUInt;
begin
  if APtr = nil then
    Exit;
  if not Owns(APtr) then
    raise EAllocError.Create(aeInvalidPointer, 'TLocalBlockPool.Release: pointer not owned');
  LDiff := PtrUInt(APtr) - PtrUInt(FBacking);
  if (FBlockSize = 0) or ((LDiff mod FBlockSize) <> 0) then
    raise EAllocError.Create(aeInvalidPointer, 'TLocalBlockPool.Release: misaligned pointer');

  { O(1) double-free 检测：位图查询 }
  LIdx := BlockIndex(APtr);
  if IsFreeBit(LIdx) then
    raise EAllocError.Create(aeDoubleFree, 'TLocalBlockPool.Release: double free detected');
  if FAcquired = 0 then
    raise EAllocError.Create(aeDoubleFree, 'TLocalBlockPool.Release: allocation count underflow');

  { 标记为 free（设置位） }
  SetFreeBit(LIdx);

  LNode := PFreeNode(APtr);
  LNode^.Next := PFreeNode(FFreeStack);
  FFreeStack := LNode;
  Dec(FAcquired);
end;

procedure TLocalBlockPool.Reset;
var
  LI: SizeUInt;
  LNode: PFreeNode;
  LBitWords: SizeUInt;
begin
  FFreeStack := nil;
  FAcquired := 0;
  for LI := 0 to FBlockCount - 1 do
  begin
    LNode := PFreeNode(PtrUInt(FBacking) + LI * FBlockSize);
    LNode^.Next := PFreeNode(FFreeStack);
    FFreeStack := LNode;
  end;
  { 重置位图：所有块标记为 free }
  LBitWords := (FBlockCount + 63) shr 6;
  FillChar(FFreeBits[0], LBitWords * SizeOf(QWord), $FF);
end;

function TLocalBlockPool.BlockSize: SizeUInt;
begin
  Result := FBlockSize;
end;

function TLocalBlockPool.Capacity: SizeUInt;
begin
  Result := FBlockCount;
end;

function TLocalBlockPool.Available: SizeUInt;
begin
  Result := FBlockCount - FAcquired;
end;

function TLocalBlockPool.InUse: SizeUInt;
begin
  Result := FAcquired;
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
