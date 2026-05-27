unit nextpas.core.collections.hashset;

{$I nextpas.core.settings.inc}
// Suppress unused parameter hints - hash set uses non-contiguous hash-map storage
{$WARN 5024 OFF}

interface

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.mem.allocator,
  nextpas.core.collections.base,
  nextpas.core.collections.hashmap.base,
  nextpas.core.collections.hashset.intf,
  nextpas.core.collections.hashmap;

type
  {**
   * THashSet<K>
   *
   * @desc 哈希集合实现，内部基于 THashMap<K, Byte>
   *
   * @param K 元素类型（必须可哈希、可比较）
   *
   * @note
   *   - 轻量包装 THashMap，Value 使用 Byte 占位
   *   - 性能特征与 THashMap 相同
   *   - 适用于快速成员资格测试场景
   *
   * @threadsafety 非线程安全
   *
   * @example
   *   var Visited: specialize THashSet<Integer>;
   *   Visited := specialize THashSet<Integer>.Create;
   *   try
   *     Visited.Add(1);
   *     Visited.Add(2);
   *     if Visited.Contains(1) then
   *       WriteLn('Already visited');
   *   finally
   *     Visited.Free;
   *   end;
   *
   * @see IHashSet 接口定义
   * @see TTreeSet 有序集合替代方案
   *}
  generic THashSet<K> = class(specialize TGenericCollection<K>, specialize IHashSet<K>)
  private
    type
      {** 内部映射类型：K -> Byte（Byte 仅作占位） *}
      TInternalMap = specialize THashMap<K, Byte>;
      PK = ^K;
    var
      FMap: TInternalMap;
  protected
    // TCollection 抽象方法实现
    function IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;
    // TGenericCollection 抽象方法实现
    procedure DoZero(); override;
    procedure DoReverse; override;
  public
    // TCollection overrides (public in base)
    procedure SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt); override;
    procedure AppendUnchecked(const aSrc: Pointer; aElementCount: SizeUInt); override;
    procedure AppendToUnchecked(const aDst: TCollection); override;

    function PtrIter: TPtrIter; override;

    {**
     * Create
     *
     * @desc 创建哈希集合实例
     *
     * @params
     *   aCapacity   初始容量（可选）
     *   aHash       自定义哈希函数（可选）
     *   aEquals     自定义相等比较函数（可选）
     *   aAllocator  自定义内存分配器（可选）
     *}
    constructor Create(aCapacity: SizeUInt = 0; aHash: specialize TKeyHashFunc<K> = nil; aEquals: specialize TKeyEqualsFunc<K> = nil; aAllocator: IAllocator = nil);

    {**
     * Destroy
     *
     * @desc 销毁哈希集合
     *}
    destructor Destroy; override;
    procedure Clear; override;
    function GetCount: SizeUInt; override;
    function GetCapacity: SizeUInt;
    procedure Reserve(aCapacity: SizeUInt);

    // IGenericCollection
    function GetEnumerator: specialize TIter<K>;
    function Iter: specialize TIter<K>;
    function GetElementSize: SizeUInt; inline;

    // 基本操作
    function Add(const AKey: K): Boolean;
    function Contains(const AKey: K): Boolean; overload;
    function Contains(const AKey: K; aEquals: specialize TEqualsFunc<K>; aData: Pointer): Boolean; overload;
    function Contains(const AKey: K; aEquals: specialize TEqualsMethod<K>; aData: Pointer): Boolean; overload;
    {$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
    function Contains(const AKey: K; aEquals: specialize TEqualsRefFunc<K>): Boolean; overload;
    {$ENDIF}
    function Remove(const AKey: K): Boolean;

    // Set operations - 集合运算
    {**
     * Union - 并集
     * @desc 返回包含两个集合所有元素的新集合
     * @param Other 另一个集合
     * @return THashSet 新的并集集合（调用者负责释放）
     *}
    function Union(const Other: specialize THashSet<K>): specialize THashSet<K>;

    {**
     * Intersection - 交集
     * @desc 返回同时存在于两个集合中的元素
     * @param Other 另一个集合
     * @return THashSet 新的交集集合（调用者负责释放）
     *}
    function Intersection(const Other: specialize THashSet<K>): specialize THashSet<K>;

    {**
     * Difference - 差集
     * @desc 返回存在于当前集合但不存在于 Other 中的元素
     * @param Other 另一个集合
     * @return THashSet 新的差集集合（调用者负责释放）
     *}
    function Difference(const Other: specialize THashSet<K>): specialize THashSet<K>;

    {**
     * SymmetricDifference - 对称差集
     * @desc 返回存在于任一集合但不同时存在于两个集合中的元素
     * @param Other 另一个集合
     * @return THashSet 新的对称差集集合（调用者负责释放）
     *}
    function SymmetricDifference(const Other: specialize THashSet<K>): specialize THashSet<K>;

    {**
     * IsSubsetOf - 子集判断
     * @desc 判断当前集合是否是 Other 的子集
     * @param Other 另一个集合
     * @return Boolean 如果当前集合的所有元素都存在于 Other 中返回 True
     *}
    function IsSubsetOf(const Other: specialize THashSet<K>): Boolean;

    {**
     * IsSupersetOf - 超集判断
     * @desc 判断当前集合是否是 Other 的超集
     * @param Other 另一个集合
     * @return Boolean 如果 Other 的所有元素都存在于当前集合中返回 True
     *}
    function IsSupersetOf(const Other: specialize THashSet<K>): Boolean;

    {**
     * IsDisjoint - 不相交判断
     * @desc 判断两个集合是否没有共同元素
     * @param Other 另一个集合
     * @return Boolean 如果两个集合没有共同元素返回 True
     *}
    function IsDisjoint(const Other: specialize THashSet<K>): Boolean;
  end;

implementation

{ THashSet<K> }

constructor THashSet.Create(aCapacity: SizeUInt; aHash: specialize TKeyHashFunc<K>; aEquals: specialize TKeyEqualsFunc<K>; aAllocator: IAllocator);
begin
  inherited Create(aAllocator);
  FMap := TInternalMap.Create(aCapacity, aHash, aEquals, aAllocator);
end;

destructor THashSet.Destroy;
begin
  FMap.Free;
  inherited;
end;

procedure THashSet.Clear;
begin
  FMap.Clear;
end;

function THashSet.GetCount: SizeUInt;
begin
  Result := FMap.GetCount;
end;

function THashSet.GetCapacity: SizeUInt;
begin
  Result := FMap.GetCapacity;
end;

procedure THashSet.Reserve(aCapacity: SizeUInt);
begin
  FMap.Reserve(aCapacity);
end;

function THashSet.GetEnumerator: specialize TIter<K>;
begin
  Result := inherited GetEnumerator;
end;

function THashSet.Iter: specialize TIter<K>;
begin
  Result := inherited Iter;
end;

function THashSet.GetElementSize: SizeUInt;
begin
  Result := SizeOf(K);
end;

procedure THashSet.DoZero();
begin
  // HashSet 的 Byte 占位值无外部语义，保持键集合不变。
end;

procedure THashSet.DoReverse;
begin
  // HashSet 没有固定顺序，Reverse 操作无实际意义。
end;

function THashSet.IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
begin
  // HashSet 不使用外部可见的连续存储。
  Result := False;
end;

function THashSet.PtrIter: TPtrIter;
begin
  Result := FMap.PtrIter;
end;

procedure THashSet.SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt);
var
  LCopied: SizeUInt;
  LIter: TPtrIter;
  PDst: PK;
begin
  if (aDst = nil) or (aCount = 0) or (GetCount = 0) then Exit;

  PDst := aDst;
  LCopied := 0;
  LIter := PtrIter();

  // PtrIter 返回指向 TMapEntry<K, Byte> 的指针；Key 是第一字段。
  while LIter.MoveNext and (LCopied < aCount) do
  begin
    PDst^ := PK(LIter.GetCurrent)^;
    Inc(PDst);
    Inc(LCopied);
  end;
end;

procedure THashSet.AppendUnchecked(const aSrc: Pointer; aElementCount: SizeUInt);
var
  I: SizeUInt;
  PKey: ^K;
begin
  if (aSrc = nil) or (aElementCount = 0) then Exit;

  PKey := aSrc;
  for I := 0 to aElementCount - 1 do
  begin
    Add(PKey^);
    Inc(PKey);
  end;
end;

procedure THashSet.AppendToUnchecked(const aDst: TCollection);
var
  LDstSet: specialize THashSet<K>;
  LMapIter: specialize TIter<specialize TMapEntry<K, Byte>>;
  LEntry: specialize TMapEntry<K, Byte>;
begin
  if aDst = nil then Exit;

  if aDst is specialize THashSet<K> then
  begin
    LDstSet := specialize THashSet<K>(aDst);
    LMapIter := FMap.Iter;
    while LMapIter.MoveNext do
    begin
      LEntry := LMapIter.Current;
      LDstSet.Add(LEntry.Key);
    end;
  end
  else
    raise EInvalidOperation.Create('THashSet.AppendToUnchecked: cannot append to incompatible container type');
end;

function THashSet.Add(const AKey: K): Boolean;
begin
  Result := FMap.Add(AKey, 1);
end;

function THashSet.Contains(const AKey: K): Boolean;
begin
  Result := FMap.ContainsKey(AKey);
end;

function THashSet.Contains(const AKey: K; aEquals: specialize TEqualsFunc<K>; aData: Pointer): Boolean;
begin
  Result := inherited Contains(AKey, aEquals, aData);
end;

function THashSet.Contains(const AKey: K; aEquals: specialize TEqualsMethod<K>; aData: Pointer): Boolean;
begin
  Result := inherited Contains(AKey, aEquals, aData);
end;

{$IFDEF FAFAFA_CORE_ANONYMOUS_REFERENCES}
function THashSet.Contains(const AKey: K; aEquals: specialize TEqualsRefFunc<K>): Boolean;
begin
  Result := inherited Contains(AKey, aEquals);
end;
{$ENDIF}

function THashSet.Remove(const AKey: K): Boolean;
begin
  Result := FMap.Remove(AKey);
end;

function THashSet.Union(const Other: specialize THashSet<K>): specialize THashSet<K>;
var
  Element: K;
begin
  Result := specialize THashSet<K>.Create;

  for Element in Self do
    Result.Add(Element);

  for Element in Other do
    Result.Add(Element);
end;

function THashSet.Intersection(const Other: specialize THashSet<K>): specialize THashSet<K>;
var
  Element: K;
begin
  Result := specialize THashSet<K>.Create;

  for Element in Self do
    if Other.Contains(Element) then
      Result.Add(Element);
end;

function THashSet.Difference(const Other: specialize THashSet<K>): specialize THashSet<K>;
var
  Element: K;
begin
  Result := specialize THashSet<K>.Create;

  for Element in Self do
    if not Other.Contains(Element) then
      Result.Add(Element);
end;

function THashSet.SymmetricDifference(const Other: specialize THashSet<K>): specialize THashSet<K>;
var
  Element: K;
begin
  Result := specialize THashSet<K>.Create;

  for Element in Self do
    if not Other.Contains(Element) then
      Result.Add(Element);

  for Element in Other do
    if not Self.Contains(Element) then
      Result.Add(Element);
end;

function THashSet.IsSubsetOf(const Other: specialize THashSet<K>): Boolean;
var
  Element: K;
begin
  if GetCount = 0 then
    Exit(True);

  if GetCount > Other.GetCount then
    Exit(False);

  for Element in Self do
    if not Other.Contains(Element) then
      Exit(False);

  Result := True;
end;

function THashSet.IsSupersetOf(const Other: specialize THashSet<K>): Boolean;
begin
  Result := Other.IsSubsetOf(Self);
end;

function THashSet.IsDisjoint(const Other: specialize THashSet<K>): Boolean;
var
  Element: K;
  Smaller, Larger: specialize THashSet<K>;
begin
  if (GetCount = 0) or (Other.GetCount = 0) then
    Exit(True);

  if GetCount <= Other.GetCount then
  begin
    Smaller := Self;
    Larger := Other;
  end
  else
  begin
    Smaller := Other;
    Larger := Self;
  end;

  for Element in Smaller do
    if Larger.Contains(Element) then
      Exit(False);

  Result := True;
end;

end.
