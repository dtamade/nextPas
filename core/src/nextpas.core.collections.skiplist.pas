unit nextpas.core.collections.skiplist;

{$I nextpas.core.settings.inc}

{**
 * nextpas.core.collections.skiplist - 跳表实现
 *
 * 随机化跳表，O(log n) 平均时间复杂度的有序映射
 * 适合需要有序遍历和范围查询的场景
 *}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.mem.allocator,
  nextpas.core.collections.base,
  nextpas.core.collections.skiplist.base,
  nextpas.core.collections.skiplist.intf;

type
  {**
   * TSkipList<K,V>
   *
   * @desc 跳表实现
   *}
  generic TSkipList<K, V> = class(TInterfacedObject, specialize ISkipList<K, V>)
  public type
    TEntry = specialize TSkipListEntry<K, V>;
    TEntryArray = array of TEntry;
    TKeyCompareFunc = function(const A, B: K): SizeInt;
  private type
    PNode = ^TNode;
    TNode = record
      Key: K;
      Value: V;
      Level: Integer;
      Forward: array of PNode;
    end;
  private
    FHead: PNode;
    FLevel: Integer;
    FCount: SizeUInt;
    FCompare: TKeyCompareFunc;

    function RandomLevel: Integer;
    function CreateNode(aLevel: Integer; const aKey: K; const aValue: V): PNode;
    procedure FreeNode(aNode: PNode);
    function DefaultCompare(const A, B: K): SizeInt;
    function FindNode(const aKey: K; out aUpdate: array of PNode): PNode;
  public
    constructor Create;
    constructor Create(aCompare: TKeyCompareFunc);
    destructor Destroy; override;

    {**
     * Put
     *
     * @desc 插入或更新键值对
     * @param aKey 键
     * @param aValue 值
     * @return Boolean 如果是新键返回 True
     *}
    function Put(const aKey: K; const aValue: V): Boolean;

    {**
     * Get
     *
     * @desc 获取值
     * @param aKey 键
     * @param aValue 输出值
     * @return Boolean 如果键存在返回 True
     *}
    function Get(const aKey: K; out aValue: V): Boolean;

    {**
     * ContainsKey
     *
     * @desc 检查键是否存在
     * @param aKey 键
     * @return Boolean 如果存在返回 True
     *}
    function ContainsKey(const aKey: K): Boolean;

    {**
     * Remove
     *
     * @desc 移除键值对
     * @param aKey 键
     * @return Boolean 如果移除成功返回 True
     *}
    function Remove(const aKey: K): Boolean;

    {**
     * Clear
     *
     * @desc 清空所有元素
     *}
    procedure Clear;

    {**
     * Min
     *
     * @desc 获取最小键值对
     * @param aKey 输出最小键
     * @param aValue 输出对应值
     * @return Boolean 如果非空返回 True
     *}
    function Min(out aKey: K; out aValue: V): Boolean;

    {**
     * Max
     *
     * @desc 获取最大键值对
     * @param aKey 输出最大键
     * @param aValue 输出对应值
     * @return Boolean 如果非空返回 True
     *}
    function Max(out aKey: K; out aValue: V): Boolean;

    {**
     * Range
     *
     * @desc 获取范围内的所有键值对 [aFrom, aTo]
     * @param aFrom 起始键（包含）
     * @param aTo 结束键（包含）
     * @return TEntryArray 范围内的条目数组
     *}
    function Range(const aFrom, aTo: K): TEntryArray;

    {**
     * ToArray
     *
     * @desc 按键顺序导出所有条目
     * @return TEntryArray 所有条目的有序数组
     *}
    function ToArray: TEntryArray;

    function GetCount: SizeUInt;
    function IsEmpty: Boolean;

    property Count: SizeUInt read GetCount;
  end;

implementation

{ TSkipList<K,V> }

constructor TSkipList.Create;
begin
  Create(nil);
end;

constructor TSkipList.Create(aCompare: TKeyCompareFunc);
begin
  inherited Create;
  FCompare := aCompare;
  FLevel := 1;
  FCount := 0;

  // Create header node with max levels
  New(FHead);
  SetLength(FHead^.Forward, SKIPLIST_MAX_LEVEL);
  FillChar(FHead^.Forward[0], SKIPLIST_MAX_LEVEL * SizeOf(PNode), 0);
  FHead^.Level := SKIPLIST_MAX_LEVEL;

  Randomize;
end;

destructor TSkipList.Destroy;
begin
  Clear;
  Dispose(FHead);
  inherited Destroy;
end;

function TSkipList.RandomLevel: Integer;
begin
  Result := 1;
  while (Random < SKIPLIST_P) and (Result < SKIPLIST_MAX_LEVEL) do
    Inc(Result);
end;

function TSkipList.CreateNode(aLevel: Integer; const aKey: K; const aValue: V): PNode;
begin
  New(Result);
  Result^.Key := aKey;
  Result^.Value := aValue;
  Result^.Level := aLevel;
  SetLength(Result^.Forward, aLevel);
  FillChar(Result^.Forward[0], aLevel * SizeOf(PNode), 0);
end;

procedure TSkipList.FreeNode(aNode: PNode);
begin
  SetLength(aNode^.Forward, 0);
  Dispose(aNode);
end;

function TSkipList.DefaultCompare(const A, B: K): SizeInt;
begin
  if A < B then
    Result := -1
  else if A > B then
    Result := 1
  else
    Result := 0;
end;

function TSkipList.FindNode(const aKey: K; out aUpdate: array of PNode): PNode;
var
  x: PNode;
  i: Integer;
  cmp: SizeInt;
begin
  x := FHead;

  for i := FLevel - 1 downto 0 do
  begin
    while x^.Forward[i] <> nil do
    begin
      if Assigned(FCompare) then
        cmp := FCompare(x^.Forward[i]^.Key, aKey)
      else
        cmp := DefaultCompare(x^.Forward[i]^.Key, aKey);

      if cmp < 0 then
        x := x^.Forward[i]
      else
        Break;
    end;
    aUpdate[i] := x;
  end;

  Result := x^.Forward[0];
end;

function TSkipList.Put(const aKey: K; const aValue: V): Boolean;
var
  update: array[0..SKIPLIST_MAX_LEVEL-1] of PNode;
  x: PNode;
  lvl, i: Integer;
  cmp: SizeInt;
begin
  x := FindNode(aKey, update);

  // Check if key exists
  if x <> nil then
  begin
    if Assigned(FCompare) then
      cmp := FCompare(x^.Key, aKey)
    else
      cmp := DefaultCompare(x^.Key, aKey);

    if cmp = 0 then
    begin
      x^.Value := aValue;
      Exit(False); // Updated existing
    end;
  end;

  // Insert new node
  lvl := RandomLevel;
  if lvl > FLevel then
  begin
    for i := FLevel to lvl - 1 do
      update[i] := FHead;
    FLevel := lvl;
  end;

  x := CreateNode(lvl, aKey, aValue);
  for i := 0 to lvl - 1 do
  begin
    x^.Forward[i] := update[i]^.Forward[i];
    update[i]^.Forward[i] := x;
  end;

  Inc(FCount);
  Result := True;
end;

function TSkipList.Get(const aKey: K; out aValue: V): Boolean;
var
  update: array[0..SKIPLIST_MAX_LEVEL-1] of PNode;
  x: PNode;
  cmp: SizeInt;
begin
  x := FindNode(aKey, update);

  if x <> nil then
  begin
    if Assigned(FCompare) then
      cmp := FCompare(x^.Key, aKey)
    else
      cmp := DefaultCompare(x^.Key, aKey);

    if cmp = 0 then
    begin
      aValue := x^.Value;
      Exit(True);
    end;
  end;

  Result := False;
end;

function TSkipList.ContainsKey(const aKey: K): Boolean;
var
  dummy: V;
begin
  Result := Get(aKey, dummy);
end;

function TSkipList.Remove(const aKey: K): Boolean;
var
  update: array[0..SKIPLIST_MAX_LEVEL-1] of PNode;
  x: PNode;
  i: Integer;
  cmp: SizeInt;
begin
  x := FindNode(aKey, update);

  if x = nil then
    Exit(False);

  if Assigned(FCompare) then
    cmp := FCompare(x^.Key, aKey)
  else
    cmp := DefaultCompare(x^.Key, aKey);

  if cmp <> 0 then
    Exit(False);

  // Remove from all levels
  for i := 0 to FLevel - 1 do
  begin
    if update[i]^.Forward[i] <> x then
      Break;
    update[i]^.Forward[i] := x^.Forward[i];
  end;

  FreeNode(x);

  // Reduce level if needed
  while (FLevel > 1) and (FHead^.Forward[FLevel - 1] = nil) do
    Dec(FLevel);

  Dec(FCount);
  Result := True;
end;

procedure TSkipList.Clear;
var
  x, next: PNode;
begin
  x := FHead^.Forward[0];
  while x <> nil do
  begin
    next := x^.Forward[0];
    FreeNode(x);
    x := next;
  end;

  FillChar(FHead^.Forward[0], SKIPLIST_MAX_LEVEL * SizeOf(PNode), 0);
  FLevel := 1;
  FCount := 0;
end;

function TSkipList.Min(out aKey: K; out aValue: V): Boolean;
var
  x: PNode;
begin
  x := FHead^.Forward[0];
  if x = nil then
    Exit(False);

  aKey := x^.Key;
  aValue := x^.Value;
  Result := True;
end;

function TSkipList.Max(out aKey: K; out aValue: V): Boolean;
var
  x: PNode;
  i: Integer;
begin
  if FHead^.Forward[0] = nil then
    Exit(False);

  // Traverse to rightmost node using higher levels for speed
  x := FHead;
  for i := FLevel - 1 downto 0 do
  begin
    while x^.Forward[i] <> nil do
      x := x^.Forward[i];
  end;

  aKey := x^.Key;
  aValue := x^.Value;
  Result := True;
end;

function TSkipList.Range(const aFrom, aTo: K): TEntryArray;
var
  update: array[0..SKIPLIST_MAX_LEVEL-1] of PNode;
  x: PNode;
  cnt: SizeUInt;
  cmp: SizeInt;
begin
  Result := nil;

  x := FindNode(aFrom, update);

  // x is now at or after aFrom
  // But FindNode returns first node >= aFrom, handle case where x is before
  if x = nil then
    Exit;

  cnt := 0;
  while x <> nil do
  begin
    if Assigned(FCompare) then
      cmp := FCompare(x^.Key, aTo)
    else
      cmp := DefaultCompare(x^.Key, aTo);

    if cmp > 0 then
      Break;

    SetLength(Result, cnt + 1);
    Result[cnt].Key := x^.Key;
    Result[cnt].Value := x^.Value;
    Inc(cnt);

    x := x^.Forward[0];
  end;
end;

function TSkipList.ToArray: TEntryArray;
var
  x: PNode;
  i: SizeUInt;
begin
  Result := nil;
  SetLength(Result, FCount);

  x := FHead^.Forward[0];
  i := 0;
  while x <> nil do
  begin
    Result[i].Key := x^.Key;
    Result[i].Value := x^.Value;
    Inc(i);
    x := x^.Forward[0];
  end;
end;

function TSkipList.GetCount: SizeUInt;
begin
  Result := FCount;
end;

function TSkipList.IsEmpty: Boolean;
begin
  Result := FCount = 0;
end;

end.
