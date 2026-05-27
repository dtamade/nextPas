unit nextpas.core.collections.smallvec;

{**
 * TSmallVec<T, N> - Stack-optimized small vector
 *
 * 类似 Rust 的 smallvec 或 LLVM 的 SmallVector，当元素数量 <= N 时
 * 数据存储在 record 内部（栈上），超过 N 时自动迁移到堆分配。
 *
 * 优点：
 * - 小容量场景避免堆分配，减少内存碎片
 * - 缓存友好（数据局部性好）
 * - 适合临时小集合、函数局部容器
 *
 * 注意：
 * - 这是 record 类型，非引用计数，需要手动调用 Done 释放堆内存
 * - N 应该是一个合理的小值（建议 4-32）
 * - 不适合存储大对象或托管类型（string/interface 等需要特殊处理）
 *}

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.collections.smallvec.base;

type
  {**
   * TSmallVec<T, N> - 栈优化小向量
   *
   * @param T 元素类型
   * @param N 内联容量（栈上存储的最大元素数）
   *}
  generic TSmallVec<T; const N: Integer> = record
  public type
    PT = ^T;
    TArray = array of T;
    TInlineArray = array[0..N-1] of T;

    { 迭代器支持 }
    TEnumerator = record
    private
      FOwner: ^TSmallVec;
      FIndex: SizeInt;
      function GetCurrent: T;
    public
      function MoveNext: Boolean;
      property Current: T read GetCurrent;
    end;

  private
    FInline: TInlineArray;       // 内联存储（栈上）
    FHeap: TArray;               // 堆存储（溢出时使用）
    FCount: SizeUInt;            // 当前元素数量
    FCapacity: SizeUInt;         // 堆容量（仅当 FHeap 非空时有效）
    FIsInline: Boolean;          // 是否使用内联存储

    function GetDataPtr: PT; inline;
    procedure SpillToHeap;
    procedure GrowHeap;

  public
    {** 初始化（必须在使用前调用） *}
    procedure Init;

    {** 清理（释放堆内存，必须在不再使用时调用） *}
    procedure Done;

    {** 清空元素（保持内联状态） *}
    procedure Clear;

    {** 添加元素到末尾 *}
    procedure Push(const aValue: T);

    {** 弹出末尾元素 *}
    function Pop(out aValue: T): Boolean;

    {** 获取指定索引的元素 *}
    function Get(aIndex: SizeUInt): T; inline;

    {** 设置指定索引的元素 *}
    procedure Put(aIndex: SizeUInt; const aValue: T); inline;

    {** 获取指定索引元素的指针 *}
    function GetPtr(aIndex: SizeUInt): PT; inline;

    {** 获取元素数量 *}
    function Count: SizeUInt; inline;

    {** 获取容量 *}
    function Capacity: SizeUInt; inline;

    {** 是否为空 *}
    function IsEmpty: Boolean; inline;

    {** 是否使用内联存储（未溢出到堆） *}
    function IsInline: Boolean; inline;

    {** 转换为动态数组 *}
    function ToArray: TArray;

    {** for-in 迭代支持 *}
    function GetEnumerator: TEnumerator;

    {** 属性访问 *}
    property Items[aIndex: SizeUInt]: T read Get write Put; default;
  end;

implementation

{ TSmallVec<T, N>.TEnumerator }

function TSmallVec.TEnumerator.GetCurrent: T;
begin
  Result := FOwner^.Get(FIndex);
end;

function TSmallVec.TEnumerator.MoveNext: Boolean;
begin
  Inc(FIndex);
  Result := FIndex < SizeInt(FOwner^.FCount);
end;

{ TSmallVec<T, N> }

function TSmallVec.GetDataPtr: PT;
begin
  if FIsInline then
    Result := @FInline[0]
  else
    Result := @FHeap[0];
end;

procedure TSmallVec.SpillToHeap;
var
  LNewCapacity: SizeUInt;
  i: SizeUInt;
begin
  // 计算新的堆容量（至少 N*2）
  LNewCapacity := N * 2;
  if LNewCapacity < SMALLVEC_MIN_HEAP_CAPACITY then
    LNewCapacity := SMALLVEC_MIN_HEAP_CAPACITY;

  // 分配堆空间
  SetLength(FHeap, LNewCapacity);
  FCapacity := LNewCapacity;

  // 复制内联数据到堆
  for i := 0 to FCount - 1 do
    FHeap[i] := FInline[i];

  // 切换到堆模式
  FIsInline := False;
end;

procedure TSmallVec.GrowHeap;
var
  LNewCapacity: SizeUInt;
begin
  if FCapacity = 0 then
    LNewCapacity := SMALLVEC_MIN_HEAP_CAPACITY
  else
    LNewCapacity := FCapacity + FCapacity div 2; // 1.5x growth

  SetLength(FHeap, LNewCapacity);
  FCapacity := LNewCapacity;
end;

procedure TSmallVec.Init;
begin
  FCount := 0;
  FCapacity := 0;
  FIsInline := True;
  FHeap := nil;
  // FInline 不需要初始化（栈内存）
end;

procedure TSmallVec.Done;
begin
  if not FIsInline then
  begin
    SetLength(FHeap, 0);
    FHeap := nil;
  end;
  FCount := 0;
  FCapacity := 0;
  FIsInline := True;
end;

procedure TSmallVec.Clear;
begin
  // 释放堆内存，回到内联状态
  if not FIsInline then
  begin
    SetLength(FHeap, 0);
    FHeap := nil;
    FCapacity := 0;
    FIsInline := True;
  end;
  FCount := 0;
end;

procedure TSmallVec.Push(const aValue: T);
begin
  if FIsInline then
  begin
    // 内联模式
    {$PUSH}{$WARN 4044 OFF}{$WARN 6018 OFF}
    // NOTE: Some FPC versions emit false-positive range/unreachable warnings here for const-generic N.
    if FCount < SizeUInt(N) then
    begin
      FInline[FCount] := aValue;
      Inc(FCount);
    end
    else
    begin
      // 需要溢出到堆
      SpillToHeap;
      // 现在添加新元素
      if FCount >= FCapacity then
        GrowHeap;
      FHeap[FCount] := aValue;
      Inc(FCount);
    end;
    {$POP}
  end
  else
  begin
    // 堆模式
    if FCount >= FCapacity then
      GrowHeap;
    FHeap[FCount] := aValue;
    Inc(FCount);
  end;
end;

function TSmallVec.Pop(out aValue: T): Boolean;
begin
  if FCount = 0 then
    Exit(False);

  Dec(FCount);
  if FIsInline then
    aValue := FInline[FCount]
  else
    aValue := FHeap[FCount];

  Result := True;
end;

function TSmallVec.Get(aIndex: SizeUInt): T;
begin
  {$IFDEF DEBUG}
  if aIndex >= FCount then
    raise ERangeError.CreateFmt('TSmallVec.Get: index %d out of range [0..%d)', [aIndex, FCount]);
  {$ENDIF}
  if FIsInline then
    Result := FInline[aIndex]
  else
    Result := FHeap[aIndex];
end;

procedure TSmallVec.Put(aIndex: SizeUInt; const aValue: T);
begin
  {$IFDEF DEBUG}
  if aIndex >= FCount then
    raise ERangeError.CreateFmt('TSmallVec.Put: index %d out of range [0..%d)', [aIndex, FCount]);
  {$ENDIF}
  if FIsInline then
    FInline[aIndex] := aValue
  else
    FHeap[aIndex] := aValue;
end;

function TSmallVec.GetPtr(aIndex: SizeUInt): PT;
begin
  {$IFDEF DEBUG}
  if aIndex >= FCount then
    raise ERangeError.CreateFmt('TSmallVec.GetPtr: index %d out of range [0..%d)', [aIndex, FCount]);
  {$ENDIF}
  if FIsInline then
    Result := @FInline[aIndex]
  else
    Result := @FHeap[aIndex];
end;

function TSmallVec.Count: SizeUInt;
begin
  Result := FCount;
end;

function TSmallVec.Capacity: SizeUInt;
begin
  if FIsInline then
    Result := N
  else
    Result := FCapacity;
end;

function TSmallVec.IsEmpty: Boolean;
begin
  Result := FCount = 0;
end;

function TSmallVec.IsInline: Boolean;
begin
  Result := FIsInline;
end;

function TSmallVec.ToArray: TArray;
var
  i: SizeUInt;
begin
  Result := nil;
  SetLength(Result, FCount);
  if FIsInline then
  begin
    for i := 0 to FCount - 1 do
      Result[i] := FInline[i];
  end
  else
  begin
    for i := 0 to FCount - 1 do
      Result[i] := FHeap[i];
  end;
end;

function TSmallVec.GetEnumerator: TEnumerator;
begin
  Result.FOwner := @Self;
  Result.FIndex := -1;
end;

end.
