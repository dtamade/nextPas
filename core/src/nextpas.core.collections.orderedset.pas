unit nextpas.core.collections.orderedset;

{$I nextpas.core.settings.inc}
// Suppress unused parameter hints - ordered set delegates to internal map
{$WARN 5024 OFF}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.collections.base,
  nextpas.core.collections.hashmap,
  nextpas.core.collections.linkedhashmap;

type
  {**
   * IOrderedSet<T> - 有序集合接口（保持插入顺序）
   *
   * @desc 集合接口，元素不重复，保持插入顺序
   *}
  generic IOrderedSet<T> = interface
    ['{D4E5F6A7-B8C9-0123-DEF0-456789ABCDEF}']
    function Add(const aElement: T): Boolean;
    function Remove(const aElement: T): Boolean;
    function Contains(const aElement: T): Boolean;
    procedure Clear;
    function First: T;
    function Last: T;
    function TryGetFirst(var aElement: T): Boolean;
    function TryGetLast(var aElement: T): Boolean;
    function IsEmpty: Boolean;
    function GetCount: SizeUInt;
    property Count: SizeUInt read GetCount;
  end;

  {**
   * TOrderedSet<T> - 有序集合（保持插入顺序）
   *
   * @desc
   *   集合容器，元素不重复，保持插入顺序。
   *   基于LinkedHashMap<T, Boolean>实现，值始终为True。
   *
   * @usage
   *   - 配置文件键列表（保持用户定义顺序）
   *   - UI组件渲染顺序（去重 + 保持顺序）
   *   - 任务执行队列（不重复执行，按添加顺序）
   *
   * @performance
   *   - Add: O(1) 摊销
   *   - Remove: O(1)
   *   - Contains: O(1)
   *   - 遍历: O(n)，按插入顺序
   *
   * @threadsafety NOT thread-safe
   *}
  generic TOrderedSet<T> = class(specialize TGenericCollection<T>, specialize IOrderedSet<T>)
  private
    type
      TInternalMap = specialize TLinkedHashMap<T, Boolean>;
      TPairType = specialize TPair<T, Boolean>;
      TMapEntryType = specialize TMapEntry<T, Boolean>;
      TInternalArray = array of T;
  private
    FMap: TInternalMap;

    // 辅助方法：手动从FMap中提取所有键
    // 因为TLinkedHashMap不支持for-in迭代(PtrIter为空)
    function ExtractAllKeys: TInternalArray;
  public
    {**
     * Create
     * @desc 创建空的有序集合
     * @Complexity O(1)
     *}
    constructor Create;

    {**
     * Destroy
     * @desc 释放集合资源
     * @Complexity O(n)
     *}
    destructor Destroy; override;

    {**
     * Add
     * @desc 添加元素到集合（如果不存在）
     * @param aElement 要添加的元素
     * @return 如果元素是新添加的返回True，已存在返回False
     * @Complexity O(1) 摊销
     *}
    function Add(const aElement: T): Boolean;

    {**
     * Remove
     * @desc 从集合中移除元素
     * @param aElement 要移除的元素
     * @return 如果成功移除返回True，元素不存在返回False
     * @Complexity O(1)
     *}
    function Remove(const aElement: T): Boolean;

    {**
     * Contains
     * @desc 检查元素是否在集合中
     * @param aElement 要检查的元素
     * @return 如果元素存在返回True
     * @Complexity O(1)
     *}
    function Contains(const aElement: T): Boolean;

    {**
     * Clear
     * @desc 清空集合
     * @Complexity O(n)
     *}
    procedure Clear;

    {**
     * First
     * @desc 获取第一个插入的元素
     * @return 第一个元素
     * @Exceptions EInvalidOperation 如果集合为空
     * @Complexity O(1)
     *}
    function First: T;

    {**
     * Last
     * @desc 获取最后插入的元素
     * @return 最后一个元素
     * @Exceptions EInvalidOperation 如果集合为空
     * @Complexity O(1)
     *}
    function Last: T;

    {**
     * TryGetFirst
     * @desc 安全地获取第一个元素
     * @param aElement 输出参数，存储第一个元素
     * @return 如果成功返回True
     * @Complexity O(1)
     *}
    function TryGetFirst(var aElement: T): Boolean;

    {**
     * TryGetLast
     * @desc 安全地获取最后一个元素
     * @param aElement 输出参数，存储最后一个元素
     * @return 如果成功返回True
     * @Complexity O(1)
     *}
    function TryGetLast(var aElement: T): Boolean;

    {**
     * GetAt
     * @desc 按插入顺序获取第N个元素（从0开始）
     * @param aIndex 索引位置
     * @return 指定位置的元素
     * @Exceptions EOutOfRange 如果索引越界
     * @Complexity O(n) - 需要遍历链表
     *}
    function GetAt(aIndex: SizeUInt): T;

    {**
     * Union
     * @desc 并集：将另一个集合的所有元素添加到当前集合
     * @param aOther 另一个集合
     * @Complexity O(m) where m = aOther.Count
     *}
    procedure Union(const aOther: TOrderedSet);

    {**
     * Intersect
     * @desc 交集：保留当前集合中也在另一个集合中的元素
     * @param aOther 另一个集合
     * @Complexity O(n + m)
     *}
    procedure Intersect(const aOther: TOrderedSet);

    {**
     * Difference
     * @desc 差集：移除当前集合中也在另一个集合中的元素
     * @param aOther 另一个集合
     * @Complexity O(m) where m = aOther.Count
     *}
    procedure Difference(const aOther: TOrderedSet);

    {**
     * IsSubsetOf
     * @desc 检查当前集合是否是另一个集合的子集
     * @param aOther 另一个集合
     * @return 如果是子集返回True
     * @Complexity O(n)
     *}
    function IsSubsetOf(const aOther: TOrderedSet): Boolean;

    {**
     * ToArray
     * @desc 将集合转换为数组（按插入顺序）
     * @return 包含所有元素的数组
     * @Complexity O(n)
     *}
    function ToArray: TInternalArray;

    {**
     * IsEmpty
     * @desc 检查集合是否为空
     * @return 如果为空返回True
     * @Complexity O(1)
     *}
    function IsEmpty: Boolean;

    {**
     * GetCount
     * @desc 获取集合中的元素数量
     * @return 元素数量
     * @Complexity O(1)
     *}
    function GetCount: SizeUInt; override;

  protected
    // 实现抽象方法（TCollection）
    function PtrIter: TPtrIter; override;
    function IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;
    procedure SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt); override;
    procedure AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt); override;
    procedure AppendToUnChecked(const aDst: TCollection); override;

    // 实现抽象方法（TGenericCollection）
    procedure DoZero; override;
    procedure DoReverse; override;
  end;

implementation

{ TOrderedSet }

constructor TOrderedSet.Create;
begin
  inherited Create;
  FMap := TInternalMap.Create;
end;

destructor TOrderedSet.Destroy;
begin
  FMap.Free;
  inherited Destroy;
end;

function TOrderedSet.Add(const aElement: T): Boolean;
begin
  if FMap.ContainsKey(aElement) then
    Exit(False);  // 已存在

  FMap.Add(aElement, True);
  Result := True;
end;

function TOrderedSet.Remove(const aElement: T): Boolean;
begin
  Result := FMap.Remove(aElement);
end;

function TOrderedSet.Contains(const aElement: T): Boolean;
begin
  Result := FMap.ContainsKey(aElement);
end;

procedure TOrderedSet.Clear;
begin
  FMap.Clear;
end;

function TOrderedSet.First: T;
var
  Pair: TPairType;
begin
  Pair := FMap.First;
  Result := Pair.Key;
end;

function TOrderedSet.Last: T;
var
  Pair: TPairType;
begin
  Pair := FMap.Last;
  Result := Pair.Key;
end;

function TOrderedSet.TryGetFirst(var aElement: T): Boolean;
var
  Pair: TPairType;
begin
  Result := FMap.TryGetFirst(Pair);
  if Result then
    aElement := Pair.Key;
end;

function TOrderedSet.TryGetLast(var aElement: T): Boolean;
var
  Pair: TPairType;
begin
  Result := FMap.TryGetLast(Pair);
  if Result then
    aElement := Pair.Key;
end;

function TOrderedSet.GetAt(aIndex: SizeUInt): T;
var
  Keys: TInternalArray;
begin
  if aIndex >= FMap.GetCount then
    raise EOutOfRange.CreateFmt(
      'TOrderedSet.GetAt: Index %d out of range [0..%d)',
      [aIndex, FMap.GetCount]
    );

  // 使用ExtractAllKeys获取所有键
  Keys := ExtractAllKeys;
  Result := Keys[aIndex];
end;

procedure TOrderedSet.Union(const aOther: TOrderedSet);
var
  Keys: TInternalArray;
  i: SizeUInt;
begin
  if aOther = nil then
    Exit;

  // 添加other中的所有元素（已存在的会被Add忽略）
  Keys := aOther.ExtractAllKeys;

  // CRITICAL FIX: Check if Keys array is empty to avoid High() underflow
  if Length(Keys) = 0 then
    Exit;

  for i := 0 to High(Keys) do
    Add(Keys[i]);
end;

procedure TOrderedSet.Intersect(const aOther: TOrderedSet);
var
  Keys: TInternalArray;
  ToRemove: TInternalArray;
  i, ItemCount: SizeUInt;
begin
  if aOther = nil then
  begin
    Clear;
    Exit;
  end;

  // 收集需要移除的元素
  Keys := ExtractAllKeys;
  SetLength(ToRemove, Length(Keys));
  ItemCount := 0;

  // CRITICAL FIX: Check if Keys array is empty to avoid High() underflow
  if Length(Keys) > 0 then
  begin
    for i := 0 to High(Keys) do
    begin
      if not aOther.Contains(Keys[i]) then
      begin
        ToRemove[ItemCount] := Keys[i];
        Inc(ItemCount);
      end;
    end;
  end;

  // 移除
  for i := 0 to ItemCount - 1 do
    Remove(ToRemove[i]);
end;

procedure TOrderedSet.Difference(const aOther: TOrderedSet);
var
  Keys: TInternalArray;
  i: SizeUInt;
begin
  if aOther = nil then
    Exit;

  // 移除other中存在的元素
  Keys := aOther.ExtractAllKeys;

  // CRITICAL FIX: Check if Keys array is empty to avoid High() underflow
  if Length(Keys) = 0 then
    Exit;

  for i := 0 to High(Keys) do
    Remove(Keys[i]);
end;

function TOrderedSet.IsSubsetOf(const aOther: TOrderedSet): Boolean;
var
  Keys: TInternalArray;
  i: SizeUInt;
begin
  if aOther = nil then
    Exit(False);

  // 检查当前集合的所有元素是否都在other中
  Keys := ExtractAllKeys;

  // CRITICAL FIX: Check if Keys array is empty to avoid High() underflow
  // Empty set is a subset of any set
  if Length(Keys) = 0 then
    Exit(True);

  for i := 0 to High(Keys) do
  begin
    if not aOther.Contains(Keys[i]) then
      Exit(False);
  end;

  Result := True;
end;

function TOrderedSet.ToArray: TInternalArray;
begin
  // 直接使用ExtractAllKeys
  Result := ExtractAllKeys;
end;

function TOrderedSet.IsEmpty: Boolean;
begin
  Result := FMap.IsEmpty;
end;

function TOrderedSet.GetCount: SizeUInt;
begin
  Result := FMap.GetCount;
end;

{ 抽象方法实现 }

function TOrderedSet.PtrIter: TPtrIter;
begin
  // OrderedSet基于LinkedHashMap的链表结构，不适合指针迭代
  // 调用者应使用枚举器/迭代方法
  // 返回空迭代器，实际迭代通过FMap的枚举器完成
  FillChar(Result, SizeOf(TPtrIter), 0);
end;

function TOrderedSet.IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
begin
  Result := FMap.IsOverlap(aSrc, aElementCount);
end;

procedure TOrderedSet.SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt);
var
  Arr: TInternalArray;
  i: SizeUInt;
  pDst: ^T;
begin
  if aCount > FMap.GetCount then
    raise EOutOfRange.CreateFmt(
      'TOrderedSet.SerializeToArrayBuffer: aCount %d > Count %d',
      [aCount, FMap.GetCount]
    );

  Arr := ToArray;
  pDst := aDst;
  for i := 0 to aCount - 1 do
  begin
    pDst^ := Arr[i];
    Inc(pDst);
  end;
end;

procedure TOrderedSet.AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt);
var
  i: SizeUInt;
  pSrc: ^T;
begin
  pSrc := aSrc;
  for i := 1 to aElementCount do
  begin
    Add(pSrc^);
    Inc(pSrc);
  end;
end;

procedure TOrderedSet.AppendToUnChecked(const aDst: TCollection);
var
  Arr: TInternalArray;
begin
  Arr := ToArray;
  if Length(Arr) > 0 then
    aDst.AppendUnChecked(@Arr[0], Length(Arr));
end;

procedure TOrderedSet.DoZero;
begin
  Clear;
end;

procedure TOrderedSet.DoReverse;
var
  Arr: TInternalArray;
  i, j: SizeUInt;
  Temp: T;
begin
  // 反转集合顺序
  if FMap.GetCount <= 1 then
    Exit;

  Arr := ToArray;
  Clear;

  // 反转数组
  i := 0;
  j := High(Arr);
  while i < j do
  begin
    Temp := Arr[i];
    Arr[i] := Arr[j];
    Arr[j] := Temp;
    Inc(i);
    Dec(j);
  end;

  // CRITICAL FIX: Check if Arr is empty (defensive, already protected by Count check above)
  if Length(Arr) = 0 then
    Exit;

  // 重新添加
  for i := 0 to High(Arr) do
    Add(Arr[i]);
end;

{ 辅助方法实现 }

function TOrderedSet.ExtractAllKeys: TInternalArray;
begin
  // 委托给TLinkedHashMap的GetAllKeys方法
  Result := FMap.GetAllKeys;
end;

end.