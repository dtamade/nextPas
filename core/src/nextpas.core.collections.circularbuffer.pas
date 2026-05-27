unit nextpas.core.collections.circularbuffer;

{$I nextpas.core.settings.inc}
// Suppress unused parameter hints - circular buffer uses ring buffer storage
{$WARN 5024 OFF}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.collections.base,
  nextpas.core.collections.intf,
  nextpas.core.collections.circularbuffer.intf;

type
  {**
   * TCircularBuffer<T> - 固定容量的环形缓冲区
   *
   * @desc
   *   提供固定大小的FIFO缓冲区，使用环形索引实现O(1)的Push/Pop操作。
   *   当缓冲区满时，可选择覆盖最旧元素或拒绝新元素。
   *
   * @usage
   *   - 日志系统：保留最近N条日志
   *   - 滑动窗口统计
   *   - 音视频流缓冲
   *
   * @performance
   *   - Push: O(1)
   *   - Pop: O(1)
   *   - Peek: O(1)
   *   - 内存占用: 固定 (Capacity * SizeOf(T))
   *
   * @threadsafety NOT thread-safe
   *}
  generic TCircularBuffer<T> = class(specialize TGenericCollection<T>, specialize ICircularBuffer<T>)
  private
    type
      TInternalArray = array of T;
  private
    FBuffer: TInternalArray;
    FHead: SizeUInt;          // 队首索引（下一个Pop的位置）
    FTail: SizeUInt;          // 队尾索引（下一个Push的位置）
    FCount: SizeUInt;         // 当前元素数量
    FCapacity: SizeUInt;      // 固定容量
    FOverwriteOldest: Boolean; // 满时是否覆盖最旧元素

    function WrapIndex(aIndex: SizeUInt): SizeUInt; inline;
  public
    {**
     * Create
     * @desc 创建指定容量的环形缓冲区
     * @param aCapacity 缓冲区容量（必须 > 0）
     * @param aOverwriteOldest 满时是否覆盖最旧元素（默认True）
     * @Complexity O(n) where n = aCapacity
     *}
    constructor Create(aCapacity: SizeUInt; aOverwriteOldest: Boolean = True);

    {**
     * Destroy
     * @desc 释放缓冲区资源
     * @Complexity O(n) if T is managed type
     *}
    destructor Destroy; override;

    {**
     * Push
     * @desc 向缓冲区添加元素
     * @param aElement 要添加的元素
     * @return 如果成功添加返回True；如果满且不覆盖则返回False
     * @Complexity O(1)
     *}
    function Push(const aElement: T): Boolean;

    {**
     * Pop
     * @desc 从缓冲区移除并返回最旧的元素
     * @return 最旧的元素
     * @Exceptions EInvalidOperation 如果缓冲区为空
     * @Complexity O(1)
     *}
    function Pop: T;

    {**
     * TryPop
     * @desc 尝试从缓冲区移除元素（安全版本）
     * @param aElement 输出参数，存储移除的元素
     * @return 如果成功移除返回True，否则返回False
     * @Complexity O(1)
     *}
    function TryPop(var aElement: T): Boolean;

    {**
     * Peek
     * @desc 查看最旧的元素但不移除
     * @return 最旧的元素
     * @Exceptions EInvalidOperation 如果缓冲区为空
     * @Complexity O(1)
     *}
    function Peek: T;

    {**
     * PeekAt
     * @desc 查看指定偏移位置的元素
     * @param aOffset 相对于Head的偏移量（0 = 最旧元素）
     * @return 指定位置的元素
     * @Exceptions EOutOfRange 如果偏移量 >= Count
     * @Complexity O(1)
     *}
    function PeekAt(aOffset: SizeUInt): T;

    {**
     * TryPeek
     * @desc 尝试查看最旧的元素（安全版本）
     * @param aElement 输出参数，存储查看的元素
     * @return 如果成功返回True，否则返回False
     * @Complexity O(1)
     *}
    function TryPeek(var aElement: T): Boolean;

    {**
     * Clear
     * @desc 清空缓冲区
     * @Complexity O(n) if T is managed type, else O(1)
     *}
    procedure Clear; override;

    {**
     * IsFull
     * @desc 检查缓冲区是否已满
     * @return 如果满返回True
     * @Complexity O(1)
     *}
    function IsFull: Boolean; inline;

    {**
     * IsEmpty
     * @desc 检查缓冲区是否为空
     * @return 如果空返回True
     * @Complexity O(1)
     *}
    function IsEmpty: Boolean;

    {**
     * Count
     * @desc 获取当前元素数量
     * @return 元素数量
     * @Complexity O(1)
     *}
    function GetCount: SizeUInt; override;

    {**
     * Capacity
     * @desc 获取缓冲区容量
     * @return 缓冲区容量
     * @Complexity O(1)
     *}
    function Capacity: SizeUInt; inline;

    {**
     * RemainingCapacity
     * @desc 获取剩余可用空间
     * @return Capacity - Count
     * @Complexity O(1)
     *}
    function RemainingCapacity: SizeUInt; inline;

    {**
     * PopBatch
     * @desc 批量弹出多个元素
     * @param aCount 要弹出的元素数量
     * @return 弹出的元素数组
     * @Exceptions EInvalidOperation 如果 aCount > Count
     * @Complexity O(aCount)
     *}
    function PopBatch(aCount: SizeUInt): TInternalArray;

    {**
     * ToArray
     * @desc 将缓冲区内容转换为数组（按FIFO顺序）
     * @return 包含所有元素的数组
     * @Complexity O(n)
     *}
    function ToArray: TInternalArray; reintroduce;

    property OverwriteOldest: Boolean read FOverwriteOldest write FOverwriteOldest;

    { ICircularBuffer<T> 接口方法 }
    function GetOverwriteOldest: Boolean; inline;
    procedure SetOverwriteOldest(aValue: Boolean); inline;

    // ICollection / TCollection
    function PtrIter: TPtrIter; override;
    procedure SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt); override;
    procedure AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt); override;
    procedure AppendToUnChecked(const aDst: TCollection); override;
  protected
    // 实现抽象方法（TCollection）
    function IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;

    // 实现抽象方法（TGenericCollection）
    procedure DoZero; override;
    procedure DoReverse; override;
  end;

implementation

{ TCircularBuffer }

function TCircularBuffer.WrapIndex(aIndex: SizeUInt): SizeUInt;
begin
  Result := aIndex mod FCapacity;
end;

constructor TCircularBuffer.Create(aCapacity: SizeUInt; aOverwriteOldest: Boolean);
begin
  inherited Create;

  if aCapacity = 0 then
    raise EInvalidArgument.Create('TCircularBuffer.Create: Capacity must be > 0');

  FCapacity := aCapacity;
  FOverwriteOldest := aOverwriteOldest;
  FHead := 0;
  FTail := 0;
  FCount := 0;

  SetLength(FBuffer, FCapacity);
end;

destructor TCircularBuffer.Destroy;
begin
  // 如果T是托管类型，需要Finalize
  if GetIsManagedType then
  begin
    Clear;
  end;

  SetLength(FBuffer, 0);
  inherited Destroy;
end;

function TCircularBuffer.Push(const aElement: T): Boolean;
begin
  // 如果满了
  if FCount = FCapacity then
  begin
    if not FOverwriteOldest then
      Exit(False);  // 拒绝添加

    // 覆盖模式：移除最旧元素
    if GetIsManagedType then
      GetElementManager.FinalizeManagedElementsUnChecked(@FBuffer[FHead], 1);

    FHead := WrapIndex(FHead + 1);
    Dec(FCount);
  end;

  // 添加新元素
  FBuffer[FTail] := aElement;
  FTail := WrapIndex(FTail + 1);
  Inc(FCount);

  Result := True;
end;

function TCircularBuffer.Pop: T;
begin
  if FCount = 0 then
    raise EInvalidOperation.Create('TCircularBuffer.Pop: Buffer is empty');

  Result := FBuffer[FHead];

  if GetIsManagedType then
    GetElementManager.FinalizeManagedElementsUnChecked(@FBuffer[FHead], 1);

  FHead := WrapIndex(FHead + 1);
  Dec(FCount);
end;

function TCircularBuffer.TryPop(var aElement: T): Boolean;
begin
  if FCount = 0 then
    Exit(False);

  aElement := FBuffer[FHead];

  if GetIsManagedType then
    GetElementManager.FinalizeManagedElementsUnChecked(@FBuffer[FHead], 1);

  FHead := WrapIndex(FHead + 1);
  Dec(FCount);

  Result := True;
end;

function TCircularBuffer.Peek: T;
begin
  if FCount = 0 then
    raise EInvalidOperation.Create('TCircularBuffer.Peek: Buffer is empty');

  Result := FBuffer[FHead];
end;

function TCircularBuffer.PeekAt(aOffset: SizeUInt): T;
begin
  if aOffset >= FCount then
    raise EOutOfRange.CreateFmt(
      'TCircularBuffer.PeekAt: Offset %d out of range [0..%d)',
      [aOffset, FCount]
    );

  Result := FBuffer[WrapIndex(FHead + aOffset)];
end;

function TCircularBuffer.TryPeek(var aElement: T): Boolean;
begin
  if FCount = 0 then
    Exit(False);

  aElement := FBuffer[FHead];
  Result := True;
end;

procedure TCircularBuffer.Clear;
begin
  if (FCount > 0) and GetIsManagedType then
  begin
    // 需要Finalize所有元素
    if FHead < FTail then
    begin
      // 连续区间
      GetElementManager.FinalizeManagedElementsUnChecked(@FBuffer[FHead], FCount);
    end
    else
    begin
      // 分为两段
      GetElementManager.FinalizeManagedElementsUnChecked(@FBuffer[FHead], FCapacity - FHead);
      if FTail > 0 then
        GetElementManager.FinalizeManagedElementsUnChecked(@FBuffer[0], FTail);
    end;
  end;

  FHead := 0;
  FTail := 0;
  FCount := 0;
end;

function TCircularBuffer.IsFull: Boolean;
begin
  Result := FCount = FCapacity;
end;

function TCircularBuffer.IsEmpty: Boolean;
begin
  Result := FCount = 0;
end;

function TCircularBuffer.GetCount: SizeUInt;
begin
  Result := FCount;
end;

function TCircularBuffer.Capacity: SizeUInt;
begin
  Result := FCapacity;
end;

function TCircularBuffer.RemainingCapacity: SizeUInt;
begin
  Result := FCapacity - FCount;
end;

function TCircularBuffer.GetOverwriteOldest: Boolean;
begin
  Result := FOverwriteOldest;
end;

procedure TCircularBuffer.SetOverwriteOldest(aValue: Boolean);
begin
  FOverwriteOldest := aValue;
end;

function TCircularBuffer.PopBatch(aCount: SizeUInt): TInternalArray;
var
  i: SizeUInt;
begin
  if aCount > FCount then
    raise EInvalidOperation.CreateFmt(
      'TCircularBuffer.PopBatch: Requested %d elements but only %d available',
      [aCount, FCount]
    );

  Result := nil;
  SetLength(Result, aCount);

  for i := 0 to aCount - 1 do
    Result[i] := Pop;
end;

function TCircularBuffer.ToArray: TInternalArray;
var
  i, idx: SizeUInt;
begin
  Result := nil;
  SetLength(Result, FCount);

  for i := 0 to FCount - 1 do
  begin
    idx := WrapIndex(FHead + i);
    Result[i] := FBuffer[idx];
  end;
end;

{ 抽象方法实现 }

function TCircularBuffer.PtrIter: TPtrIter;
begin
  // 环形缓冲区不适合用指针迭代器（不连续）
  // Keep behavior (raise), but initialize Result to satisfy compiler analysis.
  Result := Default(TPtrIter);
  raise ENotSupported.Create('TCircularBuffer.PtrIter: Not supported for circular buffer');
end;

function TCircularBuffer.IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
begin
  // 简单的重叠检查：检查aSrc是否在FBuffer范围内
  Result := (aSrc >= @FBuffer[0]) and
            (aSrc < Pointer(PtrUInt(@FBuffer[0]) + FCapacity * SizeOf(T)));
end;

procedure TCircularBuffer.SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt);
var
  Arr: TInternalArray;
  i: SizeUInt;
  pDst: ^T;
begin
  if aCount > FCount then
    raise EOutOfRange.CreateFmt(
      'TCircularBuffer.SerializeToArrayBuffer: aCount %d > Count %d',
      [aCount, FCount]
    );

  pDst := aDst;
  for i := 0 to aCount - 1 do
  begin
    pDst^ := PeekAt(i);
    Inc(pDst);
  end;
end;

procedure TCircularBuffer.AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt);
var
  i: SizeUInt;
  pSrc: ^T;
begin
  pSrc := aSrc;
  for i := 1 to aElementCount do
  begin
    Push(pSrc^);
    Inc(pSrc);
  end;
end;

procedure TCircularBuffer.AppendToUnChecked(const aDst: TCollection);
var
  Arr: TInternalArray;
begin
  // 将当前缓冲区内容追加到目标集合
  // 这需要目标集合支持AppendUnChecked
  Arr := ToArray;
  if Length(Arr) > 0 then
    aDst.AppendUnChecked(@Arr[0], Length(Arr));
end;

procedure TCircularBuffer.DoZero;
begin
  // 清空缓冲区
  Clear;
end;

procedure TCircularBuffer.DoReverse;
var
  Arr: TInternalArray;
  i, j: SizeUInt;
  Temp: T;
begin
  // 反转缓冲区内容（原地操作）
  if FCount <= 1 then
    Exit;

  Arr := ToArray;
  Clear;

  // 反转数组
  i := 0;
  j := Length(Arr) - 1;
  while i < j do
  begin
    Temp := Arr[i];
    Arr[i] := Arr[j];
    Arr[j] := Temp;
    Inc(i);
    Dec(j);
  end;

  // 重新填充
  for i := 0 to High(Arr) do
    Push(Arr[i]);
end;

end.
