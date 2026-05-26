unit nextpas.core.collections.multimap;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.collections.base,
  nextpas.core.collections.hashmap,
  nextpas.core.collections.vec;

type
  {**
   * IMultiMap<K,V> - 一对多映射接口
   *
   * @desc 允许一个键对应多个值的映射接口
   *}
  generic IMultiMap<K, V> = interface
    ['{C3D4E5F6-A7B8-9012-CDEF-345678901234}']
    procedure Add(const aKey: K; const aValue: V);
    function Remove(const aKey: K; const aValue: V): Boolean;
    function RemoveAll(const aKey: K): SizeUInt;
    function Contains(const aKey: K): Boolean;
    function ContainsValue(const aKey: K; const aValue: V): Boolean;
    function GetValueCount(const aKey: K): SizeUInt;
    procedure Clear;
    function IsEmpty: Boolean;
    function KeyCount: SizeUInt;
    function TotalCount: SizeUInt;
  end;

  {**
   * TMultiMap<K,V> - 一对多映射容器
   *
   * @desc
   *   允许一个键对应多个值的映射容器。
   *   基于HashMap<K, TVec<V>>实现,提供高效的添加、查询和删除操作。
   *
   * @usage
   *   - 标签系统（一个对象多个标签）
   *   - 事件订阅（一个事件多个处理器）
   *   - HTTP头处理（一个header多个value）
   *   - 分组数据（按类别分组）
   *
   * @performance
   *   - Add: O(1) 摊销
   *   - Remove: O(n) where n = values per key
   *   - GetValues: O(1)
   *   - Contains: O(1)
   *
   * @threadsafety NOT thread-safe
   *}
  generic TMultiMap<K,V> = class(TInterfacedObject, specialize IMultiMap<K, V>)
  private
    type
      TValueVec = specialize TVec<V>;
      TInternalMap = specialize THashMap<K, TValueVec>;
      TKeyArray = array of K;
      TValueArray = array of V;
  private
    FMap: TInternalMap;
    FTotalValueCount: SizeUInt;  // 所有值的总数

  public
    {**
     * Create
     * @desc 创建空的多重映射
     * @Complexity O(1)
     *}
    constructor Create;

    {**
     * Destroy
     * @desc 释放资源
     * @Complexity O(n * m) where n=keys, m=avg values per key
     *}
    destructor Destroy; override;

    {**
     * Add
     * @desc 添加键值对（允许重复值）
     * @param aKey 键
     * @param aValue 值
     * @Complexity O(1) 摊销
     *}
    procedure Add(const aKey: K; const aValue: V);

    {**
     * Remove
     * @desc 移除特定键值对（只移除第一个匹配）
     * @param aKey 键
     * @param aValue 要移除的值
     * @return 如果成功移除返回True
     * @Complexity O(n) where n = values for this key
     *}
    function Remove(const aKey: K; const aValue: V): Boolean;

    {**
     * RemoveAll
     * @desc 移除键的所有值
     * @param aKey 键
     * @return 移除的值数量
     * @Complexity O(n) where n = values for this key
     *}
    function RemoveAll(const aKey: K): SizeUInt;

    {**
     * Contains
     * @desc 检查键是否存在
     * @param aKey 键
     * @return 如果键存在返回True
     * @Complexity O(1)
     *}
    function Contains(const aKey: K): Boolean;

    {**
     * ContainsValue
     * @desc 检查键的特定值是否存在
     * @param aKey 键
     * @param aValue 值
     * @return 如果存在返回True
     * @Complexity O(n) where n = values for this key
     *}
    function ContainsValue(const aKey: K; const aValue: V): Boolean;

    {**
     * GetValues
     * @desc 获取键对应的所有值
     * @param aKey 键
     * @return 值数组
     * @Complexity O(n) where n = values for this key
     *}
    function GetValues(const aKey: K): TValueArray;

    {**
     * TryGetValues
     * @desc 安全获取键对应的值
     * @param aKey 键
     * @param aValues 输出参数,存储值数组
     * @return 如果键存在返回True
     * @Complexity O(n) where n = values for this key
     *}
    function TryGetValues(const aKey: K; out aValues: TValueArray): Boolean;

    {**
     * GetValueCount
     * @desc 获取键对应的值数量
     * @param aKey 键
     * @return 值数量（键不存在返回0）
     * @Complexity O(1)
     *}
    function GetValueCount(const aKey: K): SizeUInt;

    {**
     * GetKeys
     * @desc 获取所有键
     * @return 键数组
     * @Complexity O(k) where k = number of keys
     *}
    function GetKeys: TKeyArray;

    {**
     * Clear
     * @desc 清空所有键值对
     * @Complexity O(n * m)
     *}
    procedure Clear;

    {**
     * IsEmpty
     * @desc 检查是否为空
     * @return 如果为空返回True
     * @Complexity O(1)
     *}
    function IsEmpty: Boolean;

    {**
     * KeyCount
     * @desc 获取键的数量
     * @return 键数量
     * @Complexity O(1)
     *}
    function KeyCount: SizeUInt;

    {**
     * TotalCount
     * @desc 获取所有值的总数
     * @return 所有值的总数
     * @Complexity O(1)
     *}
    function TotalCount: SizeUInt;
  end;

implementation

{ TMultiMap }

constructor TMultiMap.Create;
begin
  inherited Create;
  FMap := TInternalMap.Create;
  FTotalValueCount := 0;
end;

destructor TMultiMap.Destroy;
begin
  Clear;  // Clear will handle freeing all TVec instances
  FMap.Free;
  inherited Destroy;
end;

procedure TMultiMap.Add(const aKey: K; const aValue: V);
var
  Vec: TValueVec;
begin
  if not FMap.TryGetValue(aKey, Vec) then
  begin
    // 键不存在,创建新的Vec
    Vec := TValueVec.Create;
    FMap.Add(aKey, Vec);
  end;

  Vec.Push(aValue);
  Inc(FTotalValueCount);
end;

function TMultiMap.Remove(const aKey: K; const aValue: V): Boolean;
var
  Vec: TValueVec;
  i: SizeUInt;
  TempValue: V;
begin
  Result := False;

  if not FMap.TryGetValue(aKey, Vec) then
    Exit;

  // 在Vec中查找并移除第一个匹配的值
  for i := 0 to Vec.Count - 1 do
  begin
    if Vec[i] = aValue then
    begin
      // Use RemoveSwap for O(1) removal (order doesn't matter for MultiMap)
      Vec.RemoveSwap(i, TempValue);
      Dec(FTotalValueCount);

      // 如果Vec为空,移除整个键
      if Vec.IsEmpty then
      begin
        Vec.Free;
        FMap.Remove(aKey);
      end;

      Result := True;
      Exit;
    end;
  end;
end;

function TMultiMap.RemoveAll(const aKey: K): SizeUInt;
var
  Vec: TValueVec;
begin
  Result := 0;

  if not FMap.TryGetValue(aKey, Vec) then
    Exit;

  Result := Vec.Count;
  Dec(FTotalValueCount, Result);

  Vec.Free;
  FMap.Remove(aKey);
end;

function TMultiMap.Contains(const aKey: K): Boolean;
begin
  Result := FMap.ContainsKey(aKey);
end;

function TMultiMap.ContainsValue(const aKey: K; const aValue: V): Boolean;
var
  Vec: TValueVec;
  i: SizeUInt;
begin
  Result := False;

  if not FMap.TryGetValue(aKey, Vec) then
    Exit;

  for i := 0 to Vec.Count - 1 do
  begin
    if Vec[i] = aValue then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function TMultiMap.GetValues(const aKey: K): TValueArray;
var
  Vec: TValueVec;
  i: SizeUInt;
begin
  Result := nil;

  if not FMap.TryGetValue(aKey, Vec) then
    Exit;

  SetLength(Result, Vec.Count);
  for i := 0 to Vec.Count - 1 do
    Result[i] := Vec[i];
end;

function TMultiMap.TryGetValues(const aKey: K; out aValues: TValueArray): Boolean;
var
  Vec: TValueVec;
  i: SizeUInt;
begin
  Result := FMap.TryGetValue(aKey, Vec);

  if Result then
  begin
    SetLength(aValues, Vec.Count);
    for i := 0 to Vec.Count - 1 do
      aValues[i] := Vec[i];
  end
  else
    SetLength(aValues, 0);
end;

function TMultiMap.GetValueCount(const aKey: K): SizeUInt;
var
  Vec: TValueVec;
begin
  if FMap.TryGetValue(aKey, Vec) then
    Result := Vec.Count
  else
    Result := 0;
end;

function TMultiMap.GetKeys: TKeyArray;
var
  Keys: TInternalMap.TKeyArray;
  i: SizeUInt;
begin
  Result := nil;
  Keys := FMap.GetKeys;

  // CRITICAL FIX: Check if Keys array is empty to avoid High() underflow
  if Length(Keys) = 0 then
    Exit;  // Return empty array

  SetLength(Result, Length(Keys));
  for i := 0 to High(Keys) do
    Result[i] := Keys[i];
end;

procedure TMultiMap.Clear;
var
  i: SizeUInt;
  Keys: TKeyArray;
  Vec: TValueVec;
begin
  // CRITICAL FIX: Check if map is empty first to avoid High() underflow
  if FMap.IsEmpty then
  begin
    FTotalValueCount := 0;
    Exit;
  end;

  // Get all keys first
  Keys := FMap.GetKeys;

  // Free all Vec instances (but don't modify map yet)
  for i := 0 to High(Keys) do
  begin
    if FMap.TryGetValue(Keys[i], Vec) then
      Vec.Free;
  end;

  // Now clear the map (Vecs are already freed)
  FMap.Clear;
  FTotalValueCount := 0;
end;

function TMultiMap.IsEmpty: Boolean;
begin
  Result := FMap.IsEmpty;
end;

function TMultiMap.KeyCount: SizeUInt;
begin
  Result := FMap.Count;
end;

function TMultiMap.TotalCount: SizeUInt;
begin
  Result := FTotalValueCount;
end;

end.
