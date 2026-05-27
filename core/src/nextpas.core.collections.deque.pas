unit nextpas.core.collections.deque;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.mem.allocator,
  nextpas.core.collections.queue.intf,
  nextpas.core.collections.deque.intf,
  nextpas.core.collections.vecdeque.intf,
  nextpas.core.collections.vecdeque;

type

  {**
   * TArrayDeque<T>
   *
   * @desc 数组双端队列 - 基于 TVecDeque 的接口包装器
   * @param T 元素类型
   * @note
   *   - 实现 IDeque<T> 和 IVecDeque<T> 接口
   *   - 内部委托给 TVecDeque 实现
   *   - 支持接口引用计数
   *   - 使用 MakeDeque<T>() 工厂函数创建
   *
   *   示例:
   *     var Deque: specialize IDeque<Integer>;
   *     Deque := specialize MakeDeque<Integer>();
   *     Deque.PushBack(1);
   *     Deque.PushFront(0);
   *     // 接口自动释放
   *}
  generic TArrayDeque<T> = class(TInterfacedObject, specialize IDeque<T>, specialize IVecDeque<T>)
  type
    TInternalDeque = specialize TVecDeque<T>;
    TQueueIntf = specialize IQueue<T>;
    TVecDequeIntf = specialize IVecDeque<T>;
  private
    FDeque: TInternalDeque;
    FAllocator: IAllocator;

  public
    constructor Create(const aAllocator: IAllocator = nil); overload;
    constructor Create(const aElements: array of T; const aAllocator: IAllocator = nil); overload;
    destructor Destroy; override;

    { IQueue 接口实现 }
    procedure Push(const aElement: T); overload;
    procedure Push(const aSrc: array of T); overload;
    procedure Push(const aSrc: Pointer; aElementCount: SizeUInt); overload;

    function Pop(out aElement: T): Boolean; overload;
    function Pop: T; overload;

    function TryPeek(out aElement: T): Boolean; overload;
    function Peek: T; overload;

    function IsEmpty: Boolean;
    procedure Clear;
    function Count: SizeUInt;

    { IDeque 接口实现 }
    function Front: T; overload;
    function Front(var aElement: T): Boolean; overload;
    function Back: T; overload;
    function Back(var aElement: T): Boolean; overload;

    procedure PushFront(const aElement: T); overload;
    procedure PushFront(const aElements: array of T); overload;
    procedure PushFront(const aSrc: Pointer; aElementCount: SizeUInt); overload;
    procedure PushBack(const aElement: T); overload;
    procedure PushBack(const aElements: array of T); overload;
    procedure PushBack(const aSrc: Pointer; aElementCount: SizeUInt); overload;
    function PopFront: T; overload;
    function PopFront(var aElement: T): Boolean; overload;
    function PopBack: T; overload;
    function PopBack(var aElement: T): Boolean; overload;

    procedure Swap(aIndex1, aIndex2: SizeUInt);
    function Get(aIndex: SizeUInt): T;
    function TryGet(aIndex: SizeUInt; var aElement: T): Boolean;
    procedure Insert(aIndex: SizeUInt; const aElement: T);
    function Remove(aIndex: SizeUInt): T;
    function TryRemove(aIndex: SizeUInt; var aElement: T): Boolean;

    procedure Reserve(aAdditional: SizeUInt);
    procedure ReserveExact(aAdditional: SizeUInt);
    procedure ShrinkToFit;
    procedure ShrinkTo(aMinCapacity: SizeUInt);
    procedure Truncate(aLen: SizeUInt);
    procedure Resize(aNewSize: SizeUInt; const aValue: T);

    procedure Append(const aOther: specialize IQueue<T>);
    function SplitOff(aAt: SizeUInt): specialize IQueue<T>;

    { IVecDeque 接口实现 - 批量操作 }
    procedure LoadFromPointer(aSrc: Pointer; aCount: SizeUInt);
    procedure LoadFromArray(const aSrc: array of T);
    procedure AppendFrom(const aSrc: specialize IVecDeque<T>; aSrcIndex: SizeUInt; aCount: SizeUInt);
    procedure InsertFrom(aIndex: SizeUInt; aSrc: Pointer; aCount: SizeUInt); overload;
    procedure InsertFrom(aIndex: SizeUInt; const aSrc: array of T); overload;
  end;

  { 泛型双端队列工厂函数 }
  generic function MakeDeque<T>(const aAllocator: IAllocator = nil): specialize IDeque<T>;
  generic function MakeDeque<T>(const aElements: array of T; const aAllocator: IAllocator = nil): specialize IDeque<T>;

implementation

{ TArrayDeque<T> }

constructor TArrayDeque.Create(const aAllocator: IAllocator = nil);
begin
  inherited Create;
  if aAllocator <> nil then
    FAllocator := aAllocator
  else
    FAllocator := GetRtlAllocator;
  FDeque := TInternalDeque.Create(FAllocator);
end;

constructor TArrayDeque.Create(const aElements: array of T; const aAllocator: IAllocator = nil);
begin
  inherited Create;
  if aAllocator <> nil then
    FAllocator := aAllocator
  else
    FAllocator := GetRtlAllocator;
  FDeque := TInternalDeque.Create(FAllocator);
  FDeque.Push(aElements);
end;

destructor TArrayDeque.Destroy;
begin
  FDeque.Free;
  inherited Destroy;
end;

{ IQueue 接口实现 }

procedure TArrayDeque.Push(const aElement: T);
begin
  FDeque.PushBack(aElement);
end;

procedure TArrayDeque.Push(const aSrc: array of T);
begin
  FDeque.Push(aSrc);
end;

procedure TArrayDeque.Push(const aSrc: Pointer; aElementCount: SizeUInt);
begin
  FDeque.Push(aSrc, aElementCount);
end;

function TArrayDeque.Pop(out aElement: T): Boolean;
begin
  if FDeque.IsEmpty then
    Exit(False);
  aElement := FDeque.PopFront;
  Result := True;
end;

function TArrayDeque.Pop: T;
begin
  if FDeque.IsEmpty then
    raise EEmptyCollection.Create('TArrayDeque.Pop: collection is empty');
  Result := FDeque.PopFront;
end;

function TArrayDeque.TryPeek(out aElement: T): Boolean;
begin
  if FDeque.IsEmpty then
    Exit(False);
  aElement := FDeque.Front;
  Result := True;
end;

function TArrayDeque.Peek: T;
begin
  if FDeque.IsEmpty then
    raise EEmptyCollection.Create('TArrayDeque.Peek: collection is empty');
  Result := FDeque.Front;
end;

function TArrayDeque.IsEmpty: Boolean;
begin
  Result := FDeque.IsEmpty;
end;

procedure TArrayDeque.Clear;
begin
  FDeque.Clear;
end;

function TArrayDeque.Count: SizeUInt;
begin
  Result := FDeque.Count;
end;

{ IDeque 接口实现 }

function TArrayDeque.Front: T;
begin
  if FDeque.IsEmpty then
    raise EEmptyCollection.Create('TArrayDeque.Front: collection is empty');
  Result := FDeque.Front;
end;

function TArrayDeque.Front(var aElement: T): Boolean;
begin
  if FDeque.IsEmpty then
    Exit(False);
  aElement := FDeque.Front;
  Result := True;
end;

function TArrayDeque.Back: T;
begin
  if FDeque.IsEmpty then
    raise EEmptyCollection.Create('TArrayDeque.Back: collection is empty');
  Result := FDeque.Back;
end;

function TArrayDeque.Back(var aElement: T): Boolean;
begin
  if FDeque.IsEmpty then
    Exit(False);
  aElement := FDeque.Back;
  Result := True;
end;

procedure TArrayDeque.PushFront(const aElement: T);
begin
  FDeque.PushFront(aElement);
end;

procedure TArrayDeque.PushFront(const aElements: array of T);
begin
  FDeque.PushFront(aElements);
end;

procedure TArrayDeque.PushFront(const aSrc: Pointer; aElementCount: SizeUInt);
begin
  FDeque.PushFront(aSrc, aElementCount);
end;

procedure TArrayDeque.PushBack(const aElement: T);
begin
  FDeque.PushBack(aElement);
end;

procedure TArrayDeque.PushBack(const aElements: array of T);
begin
  FDeque.PushBack(aElements);
end;

procedure TArrayDeque.PushBack(const aSrc: Pointer; aElementCount: SizeUInt);
begin
  FDeque.PushBack(aSrc, aElementCount);
end;

function TArrayDeque.PopFront: T;
begin
  if FDeque.IsEmpty then
    raise EEmptyCollection.Create('TArrayDeque.PopFront: collection is empty');
  Result := FDeque.PopFront;
end;

function TArrayDeque.PopFront(var aElement: T): Boolean;
begin
  if FDeque.IsEmpty then
    Exit(False);
  aElement := FDeque.PopFront;
  Result := True;
end;

function TArrayDeque.PopBack: T;
begin
  if FDeque.IsEmpty then
    raise EEmptyCollection.Create('TArrayDeque.PopBack: collection is empty');
  Result := FDeque.PopBack;
end;

function TArrayDeque.PopBack(var aElement: T): Boolean;
begin
  if FDeque.IsEmpty then
    Exit(False);
  aElement := FDeque.PopBack;
  Result := True;
end;

procedure TArrayDeque.Swap(aIndex1, aIndex2: SizeUInt);
begin
  if aIndex1 >= FDeque.Count then
    raise EOutOfRange.CreateFmt('TArrayDeque.Swap: aIndex1 %d out of range [0..%d)', [aIndex1, FDeque.Count]);
  if aIndex2 >= FDeque.Count then
    raise EOutOfRange.CreateFmt('TArrayDeque.Swap: aIndex2 %d out of range [0..%d)', [aIndex2, FDeque.Count]);
  FDeque.Swap(aIndex1, aIndex2);
end;

function TArrayDeque.Get(aIndex: SizeUInt): T;
begin
  if aIndex >= FDeque.Count then
    raise EOutOfRange.CreateFmt('TArrayDeque.Get: index %d out of range [0..%d)', [aIndex, FDeque.Count]);
  Result := FDeque.Get(aIndex);
end;

function TArrayDeque.TryGet(aIndex: SizeUInt; var aElement: T): Boolean;
begin
  if aIndex >= FDeque.Count then
    Exit(False);
  aElement := FDeque.Get(aIndex);
  Result := True;
end;

procedure TArrayDeque.Insert(aIndex: SizeUInt; const aElement: T);
begin
  if aIndex > FDeque.Count then
    raise EOutOfRange.CreateFmt('TArrayDeque.Insert: index %d out of range [0..%d]', [aIndex, FDeque.Count]);
  FDeque.Insert(aIndex, aElement);
end;

function TArrayDeque.Remove(aIndex: SizeUInt): T;
begin
  if aIndex >= FDeque.Count then
    raise EOutOfRange.CreateFmt('TArrayDeque.Remove: index %d out of range [0..%d)', [aIndex, FDeque.Count]);
  Result := FDeque.Remove(aIndex);
end;

function TArrayDeque.TryRemove(aIndex: SizeUInt; var aElement: T): Boolean;
begin
  if aIndex >= FDeque.Count then
    Exit(False);
  aElement := FDeque.Remove(aIndex);
  Result := True;
end;

procedure TArrayDeque.Reserve(aAdditional: SizeUInt);
begin
  FDeque.Reserve(aAdditional);
end;

procedure TArrayDeque.ReserveExact(aAdditional: SizeUInt);
begin
  FDeque.ReserveExact(aAdditional);
end;

procedure TArrayDeque.ShrinkToFit;
begin
  FDeque.ShrinkToFit;
end;

procedure TArrayDeque.ShrinkTo(aMinCapacity: SizeUInt);
begin
  FDeque.ShrinkTo(aMinCapacity);
end;

procedure TArrayDeque.Truncate(aLen: SizeUInt);
begin
  FDeque.Truncate(aLen);
end;

procedure TArrayDeque.Resize(aNewSize: SizeUInt; const aValue: T);
begin
  FDeque.Resize(aNewSize, aValue);
end;

procedure TArrayDeque.Append(const aOther: specialize IQueue<T>);
{**
| * 批量追加元素
| * 优化要点：
| *  - 支持 IVecDeque 队列的批量搬移（避免逐元素 Pop/Push）
| *  - 防御性处理 self-append
| *  - 其他实现退化到安全的逐元素搬移
| *}
var
  LSelfQueue: TQueueIntf;
  LCount: SizeUInt;
  LVecDequeSrc: TVecDequeIntf;
  LElement: T;
begin
  if aOther = nil then
    Exit;

  LSelfQueue := Self as TQueueIntf;
  if Pointer(aOther) = Pointer(LSelfQueue) then
    raise EInvalidOperation.Create('TArrayDeque.Append: cannot append to itself');

  LCount := aOther.Count;
  if LCount = 0 then
    Exit;

  // 快速路径：源实现同样暴露 IVecDeque 接口，可直接批量复制
  if Supports(aOther, TVecDequeIntf, LVecDequeSrc) then
  begin
    AppendFrom(LVecDequeSrc, 0, LCount);
    LVecDequeSrc.Clear;
    Exit;
  end;

  // 回退：逐个弹出并推入，保持行为一致
  FDeque.Reserve(LCount);
  while aOther.Pop(LElement) do
    FDeque.PushBack(LElement);
end;

function TArrayDeque.SplitOff(aAt: SizeUInt): specialize IQueue<T>;
begin
  Result := FDeque.SplitOff(aAt);
end;

{ IVecDeque 批量操作实现 }

procedure TArrayDeque.LoadFromPointer(aSrc: Pointer; aCount: SizeUInt);
begin
  FDeque.LoadFromPointer(aSrc, aCount);
end;

procedure TArrayDeque.LoadFromArray(const aSrc: array of T);
begin
  FDeque.LoadFromArray(aSrc);
end;

procedure TArrayDeque.AppendFrom(const aSrc: specialize IVecDeque<T>; aSrcIndex: SizeUInt; aCount: SizeUInt);
var
  LVecDequeSrc: TInternalDeque;
begin
  if aCount = 0 then
    Exit;

  if aSrc = nil then
    Exit;

  if Supports(aSrc, TInternalDeque, LVecDequeSrc) then
  begin
    FDeque.AppendFrom(LVecDequeSrc, aSrcIndex, aCount);
    Exit;
  end;

  if (aSrcIndex + aCount) > aSrc.Count then
    raise EOutOfRange.CreateFmt('TArrayDeque.AppendFrom: range [%d..%d) exceeds source count %d', [aSrcIndex, aSrcIndex + aCount, aSrc.Count]);

  FDeque.Reserve(aCount);
  while aCount > 0 do
  begin
    FDeque.PushBack(aSrc.Get(aSrcIndex));
    Inc(aSrcIndex);
    Dec(aCount);
  end;
end;

procedure TArrayDeque.InsertFrom(aIndex: SizeUInt; aSrc: Pointer; aCount: SizeUInt);
begin
  FDeque.InsertFrom(aIndex, aSrc, aCount);
end;

procedure TArrayDeque.InsertFrom(aIndex: SizeUInt; const aSrc: array of T);
begin
  FDeque.InsertFrom(aIndex, aSrc);
end;

{ 泛型工厂函数实现 }

generic function MakeDeque<T>(const aAllocator: IAllocator = nil): specialize IDeque<T>;
type
  TDequeImpl = specialize TArrayDeque<T>;
var
  LDeque: TDequeImpl;
begin
  LDeque := TDequeImpl.Create(aAllocator);
  Result := LDeque;  // 接口引用
end;

generic function MakeDeque<T>(const aElements: array of T; const aAllocator: IAllocator = nil): specialize IDeque<T>;
type
  TDequeImpl = specialize TArrayDeque<T>;
var
  LDeque: TDequeImpl;
begin
  LDeque := TDequeImpl.Create(aElements, aAllocator);
  Result := LDeque;  // 接口引用
end;

end.
