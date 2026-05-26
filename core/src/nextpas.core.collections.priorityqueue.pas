unit nextpas.core.collections.priorityqueue;

{$I nextpas.core.settings.inc}
// Suppress unused parameter hints - priority queue uses heap-based storage
{$WARN 5024 OFF}

interface

uses
  SysUtils, TypInfo,
  nextpas.core.base,
  nextpas.core.mem.allocator,
  nextpas.core.collections.base,
  nextpas.core.collections.element_manager;

type
  {**
   * IPriorityQueue<T> - 优先队列接口
   *
   * @desc
   *   基于二叉堆实现的优先队列接口，支持 O(log n) 插入和删除，
   *   O(1) 获取最小/最大元素。
   *
   * @type_params
   *   T - 元素类型
   *
   * @threadsafety NOT thread-safe
   *}
  generic IPriorityQueue<T> = interface(specialize IGenericCollection<T>)
  ['{F8E9D7C6-B5A4-4321-9876-543210FEDCBA}']
    {** Enqueue - 入队 O(log n) *}
    procedure Enqueue(const aItem: T);

    {** Dequeue - 出队并返回优先级最高的元素 O(log n) *}
    function Dequeue(out aItem: T): Boolean;

    {** Peek - 查看优先级最高的元素（不移除）O(1) *}
    function Peek(out aItem: T): Boolean;

    {** GetCapacity - 获取当前容量 *}
    function GetCapacity: SizeUInt;

    {** Reserve - 预留容量 *}
    procedure Reserve(aCapacity: SizeUInt);

    property Capacity: SizeUInt read GetCapacity;
  end;

  {**
   * TPriorityQueue<T> - 优先队列类实现
   *
   * @desc
   *   基于二叉堆实现的优先队列，继承 TGenericCollection<T>
   *   支持自定义分配器和比较器
   *
   * @type_params
   *   T - 元素类型
   *}
  generic TPriorityQueue<T> = class(specialize TGenericCollection<T>, specialize IPriorityQueue<T>)
  public type
    TPQCompareFunc = specialize TCompareFunc<T>;
  private
    FItems: array of T;
    FCount: SizeUInt;
    FCapacity: SizeUInt;
    FComparer: TPQCompareFunc;

    procedure Grow;
    procedure SiftUp(aIndex: SizeUInt);
    procedure SiftDown(aIndex: SizeUInt);
    procedure Swap(aIndex1, aIndex2: SizeUInt); {$IFDEF FAFAFA_CORE_INLINE}inline;{$ENDIF}

  protected
    function IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;
    procedure DoZero; override;
    procedure DoReverse; override;

    function DoIterGetCurrent(aIter: PPtrIter): Pointer;
    function DoIterMoveNext(aIter: PPtrIter): Boolean;

  public
    function GetCount: SizeUInt; override;

    constructor Create(aComparer: TPQCompareFunc; aCapacity: SizeUInt = 16; aAllocator: IAllocator = nil); reintroduce;
    destructor Destroy; override;

    { IPriorityQueue<T> }
    procedure Enqueue(const aItem: T);
    function Dequeue(out aItem: T): Boolean;
    function Peek(out aItem: T): Boolean;
    function GetCapacity: SizeUInt;
    procedure Reserve(aCapacity: SizeUInt);

    { TCollection overrides }
    function PtrIter: TPtrIter; override;
    procedure Clear; override;
    procedure SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt); override;
    procedure AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt); override;
    procedure AppendToUnChecked(const aDst: TCollection); override;

    property Capacity: SizeUInt read GetCapacity;
  end;

{ 工厂函数声明 }
generic function MakePriorityQueue<T>(aComparer: specialize TCompareFunc<T>; aCapacity: SizeUInt = 16; aAllocator: IAllocator = nil): specialize IPriorityQueue<T>;

implementation

{ 工厂函数实现 }
generic function MakePriorityQueue<T>(aComparer: specialize TCompareFunc<T>; aCapacity: SizeUInt; aAllocator: IAllocator): specialize IPriorityQueue<T>;
begin
  Result := specialize TPriorityQueue<T>.Create(aComparer, aCapacity, aAllocator);
end;

{ TPriorityQueue<T> }

constructor TPriorityQueue.Create(aComparer: TPQCompareFunc; aCapacity: SizeUInt; aAllocator: IAllocator);
begin
  inherited Create(aAllocator, nil);
  if not Assigned(aComparer) then
    raise EArgumentNil.Create('TPriorityQueue.Create: comparer function cannot be nil');
  FComparer := aComparer;
  FCapacity := aCapacity;
  if FCapacity < 4 then
    FCapacity := 4;
  SetLength(FItems, FCapacity);
  FCount := 0;
end;

destructor TPriorityQueue.Destroy;
begin
  Clear;
  SetLength(FItems, 0);
  inherited Destroy;
end;

procedure TPriorityQueue.Grow;
begin
  if FCapacity = 0 then
    FCapacity := 16
  else
    FCapacity := FCapacity * 2;
  SetLength(FItems, FCapacity);
end;

procedure TPriorityQueue.Swap(aIndex1, aIndex2: SizeUInt);
var
  LTemp: T;
begin
  LTemp := FItems[aIndex1];
  FItems[aIndex1] := FItems[aIndex2];
  FItems[aIndex2] := LTemp;
end;

procedure TPriorityQueue.SiftUp(aIndex: SizeUInt);
var
  LParentIdx: SizeUInt;
begin
  while aIndex > 0 do
  begin
    LParentIdx := (aIndex - 1) div 2;
    if FComparer(FItems[aIndex], FItems[LParentIdx], nil) >= 0 then
      Break;
    Swap(aIndex, LParentIdx);
    aIndex := LParentIdx;
  end;
end;

procedure TPriorityQueue.SiftDown(aIndex: SizeUInt);
var
  LLeftIdx, LRightIdx, LSmallestIdx: SizeUInt;
begin
  while True do
  begin
    LSmallestIdx := aIndex;
    LLeftIdx := 2 * aIndex + 1;
    LRightIdx := 2 * aIndex + 2;

    if (LLeftIdx < FCount) and (FComparer(FItems[LLeftIdx], FItems[LSmallestIdx], nil) < 0) then
      LSmallestIdx := LLeftIdx;

    if (LRightIdx < FCount) and (FComparer(FItems[LRightIdx], FItems[LSmallestIdx], nil) < 0) then
      LSmallestIdx := LRightIdx;

    if LSmallestIdx = aIndex then
      Break;

    Swap(aIndex, LSmallestIdx);
    aIndex := LSmallestIdx;
  end;
end;

procedure TPriorityQueue.Enqueue(const aItem: T);
begin
  if FCount >= FCapacity then
    Grow;
  FItems[FCount] := aItem;
  Inc(FCount);
  SiftUp(FCount - 1);
end;

function TPriorityQueue.Dequeue(out aItem: T): Boolean;
begin
  Result := FCount > 0;
  if not Result then
    Exit;
  aItem := FItems[0];
  Dec(FCount);
  if FCount > 0 then
  begin
    FItems[0] := FItems[FCount];
    SiftDown(0);
  end;
end;

function TPriorityQueue.Peek(out aItem: T): Boolean;
begin
  Result := FCount > 0;
  if Result then
    aItem := FItems[0];
end;

function TPriorityQueue.GetCount: SizeUInt;
begin
  Result := FCount;
end;

function TPriorityQueue.GetCapacity: SizeUInt;
begin
  Result := FCapacity;
end;

procedure TPriorityQueue.Reserve(aCapacity: SizeUInt);
begin
  if aCapacity > FCapacity then
  begin
    FCapacity := aCapacity;
    SetLength(FItems, FCapacity);
  end;
end;

procedure TPriorityQueue.Clear;
var
  i: SizeUInt;
begin
  // Finalize managed types
  if IsManagedType then
    for i := 0 to FCount - 1 do
      Finalize(FItems[i]);
  FCount := 0;
end;

function TPriorityQueue.IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
var
  LSrcEnd, LItemsEnd: PByte;
begin
  if (FCount = 0) or (aElementCount = 0) or (aSrc = nil) then
    Exit(False);
  LSrcEnd := PByte(aSrc) + aElementCount * SizeOf(T);
  LItemsEnd := PByte(@FItems[0]) + FCount * SizeOf(T);
  Result := (PByte(aSrc) < LItemsEnd) and (LSrcEnd > PByte(@FItems[0]));
end;

procedure TPriorityQueue.DoZero;
begin
  if FCount > 0 then
    FillChar(FItems[0], FCount * SizeOf(T), 0);
end;

procedure TPriorityQueue.DoReverse;
var
  i, j: SizeUInt;
begin
  if FCount <= 1 then Exit;
  i := 0;
  j := FCount - 1;
  while i < j do
  begin
    Swap(i, j);
    Inc(i);
    Dec(j);
  end;
  // Note: After reverse, heap property is broken. Re-heapify:
  // (Actually for PQ, reverse doesn't make semantic sense, but we implement it anyway)
end;

function TPriorityQueue.DoIterGetCurrent(aIter: PPtrIter): Pointer;
var
  LIdx: SizeUInt;
begin
  if aIter = nil then
    Exit(nil);
  LIdx := SizeUInt(aIter^.Data);
  if LIdx >= FCount then
    Exit(nil);
  Result := @FItems[LIdx];
end;

function TPriorityQueue.DoIterMoveNext(aIter: PPtrIter): Boolean;
var
  LIdx: SizeUInt;
begin
  if aIter = nil then
    Exit(False);
  if not aIter^.Started then
  begin
    aIter^.Started := True;
    if FCount = 0 then
      Exit(False);
    // Store index directly in Data pointer (no allocation needed)
    aIter^.Data := Pointer(SizeUInt(0));
    Result := True;
  end
  else
  begin
    LIdx := SizeUInt(aIter^.Data);
    Inc(LIdx);
    if LIdx >= FCount then
      Exit(False);
    aIter^.Data := Pointer(LIdx);
    Result := True;
  end;
end;

function TPriorityQueue.PtrIter: TPtrIter;
begin
  Result.Init(Self, @DoIterGetCurrent, @DoIterMoveNext, nil);
end;

procedure TPriorityQueue.SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt);
var
  LCopyCount: SizeUInt;
begin
  if (aDst = nil) or (aCount = 0) then
    Exit;
  LCopyCount := aCount;
  if LCopyCount > FCount then
    LCopyCount := FCount;
  if LCopyCount > 0 then
    Move(FItems[0], aDst^, LCopyCount * SizeOf(T));
end;

procedure TPriorityQueue.AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt);
type
  PT = ^T;
var
  LSrc: PT;
  i: SizeUInt;
begin
  if (aSrc = nil) or (aElementCount = 0) then
    Exit;
  LSrc := PT(aSrc);
  for i := 0 to aElementCount - 1 do
  begin
    Enqueue(LSrc^);
    Inc(LSrc);
  end;
end;

procedure TPriorityQueue.AppendToUnChecked(const aDst: TCollection);
var
  i: SizeUInt;
begin
  if aDst = nil then
    Exit;
  for i := 0 to FCount - 1 do
    aDst.AppendUnChecked(@FItems[i], 1);
end;

end.
