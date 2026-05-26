unit nextpas.core.collections.linkedhashmap;

{$I nextpas.core.settings.inc}
// Suppress unused parameter hints - linked hash map uses node-based storage
{$WARN 5024 OFF}

interface

uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.mem.allocator,
  nextpas.core.collections.base,
  nextpas.core.collections.hashmap;

type
  {**
   * ILinkedHashMap<K,V>
   *
   * @desc Hash map that maintains insertion order
   * @param K Key type
   * @param V Value type
   * @note Combines O(1) hash lookups with predictable iteration order
   *}
  generic ILinkedHashMap<K,V> = interface(specialize IHashMap<K,V>)
  ['{8F9A2B3C-4D5E-6F7A-8B9C-0D1E2F3A4B5C}']
    {**
     * First
     *
     * @desc Returns the first inserted key-value pair
     * @return TPair<K,V> The first pair
     * @raises Exception if map is empty
     *}
    function First: specialize TPair<K,V>;

    {**
     * Last
     *
     * @desc Returns the last inserted key-value pair
     * @return TPair<K,V> The last pair
     * @raises Exception if map is empty
     *}
    function Last: specialize TPair<K,V>;

    {**
     * TryGetFirst
     *
     * @desc Safely attempts to get the first pair
     * @param aPair Output parameter for the first pair
     * @return Boolean True if map is not empty
     *}
    function TryGetFirst(out aPair: specialize TPair<K,V>): Boolean;

    {**
     * TryGetLast
     *
     * @desc Safely attempts to get the last pair
     * @param aPair Output parameter for the last pair
     * @return Boolean True if map is not empty
     *}
    function TryGetLast(out aPair: specialize TPair<K,V>): Boolean;
  end;

  {**
   * TLinkedNode<K,V>
   *
   * @desc Internal doubly-linked list node for maintaining order
   *       Stores the actual key/value pair for pointer iteration
   *}
  generic TLinkedNode<K,V> = record
    Pair: specialize TPair<K,V>;
    Prev: Pointer;  // Points to previous node
    Next: Pointer;  // Points to next node
  end;

  {**
   * TLinkedHashMap<K,V>
   *
   * @desc Implementation of ILinkedHashMap using HashMap + doubly-linked list
   * @param K Key type
   * @param V Value type
   *}
  generic TLinkedHashMap<K,V> = class(specialize TGenericCollection<specialize TMapEntry<K,V>>, specialize ILinkedHashMap<K,V>)
  private
    type
      TNode = specialize TLinkedNode<K,V>;
      PNode = ^TNode;
      TInternalMap = specialize THashMap<K,V>;
      TNodeMap = specialize THashMap<K, PNode>;
      TPairType = specialize TPair<K,V>;
      TEntryType = specialize TMapEntry<K,V>;
      TKeysArray = array of K;  // 定义键数组类型
      // Entry API types
      TValueSupplier = specialize TValueSupplierFunc<V>;
      TValueModifier = specialize TValueModifierProc<V>;

    var
      FMap: TInternalMap;        // Stores key -> value
      FNodeMap: TNodeMap;        // Stores key -> linked node pointer
      FHead: PNode;              // Head of doubly-linked list
      FTail: PNode;              // Tail of doubly-linked list

    procedure LinkNode(aNode: PNode);
    procedure UnlinkNode(aNode: PNode);
    function AllocateNode(const aKey: K; const aValue: V): PNode;
    procedure FreeNode(aNode: PNode);
    function DoIterGetCurrent(aIter: PPtrIter): Pointer;
    function DoIterMoveNext(aIter: PPtrIter): Boolean;

  public
    constructor Create; overload;
    constructor Create(aAllocator: IAllocator); overload;
    constructor Create(aCapacity: SizeUInt); overload;
    constructor Create(aCapacity: SizeUInt; aAllocator: IAllocator); overload;
    destructor Destroy; override;

    // IHashMap<K,V> interface
    function TryGetValue(const aKey: K; out aValue: V): Boolean;
    function ContainsKey(const aKey: K): Boolean;
    function Add(const aKey: K; const aValue: V): Boolean;
    function AddOrAssign(const aKey: K; const aValue: V): Boolean;
    function Remove(const aKey: K): Boolean;
    procedure Clear; override;
    function GetCapacity: SizeUInt;
    function GetLoadFactor: Single;
    procedure Reserve(aCapacity: SizeUInt);

    // API 一致性别名 (与 TreeMap 统一)
    function Put(const aKey: K; const aValue: V): Boolean; inline;
    function Get(const aKey: K; out aValue: V): Boolean; inline;

    // Entry API (Rust-style)
    function GetOrInsert(const aKey: K; const aDefaultValue: V): V;
    function GetOrInsertWith(const aKey: K; aSupplier: TValueSupplier): V;
    procedure ModifyOrInsert(const aKey: K; aModifier: TValueModifier; const aDefaultValue: V);

    // Retain API
    type
      TEntryPredicate = specialize TPredicateFunc<TEntryType>;
    procedure Retain(aPredicate: TEntryPredicate; aData: Pointer);

    // ICollection interface
    function GetCount: SizeUInt; override;
    function IsEmpty: Boolean;
    function PtrIter: TPtrIter; override;

    // ILinkedHashMap<K,V> specific
    function First: TPairType;
    function Last: TPairType;
    function TryGetFirst(out aPair: TPairType): Boolean;
    function TryGetLast(out aPair: TPairType): Boolean;

    {**
     * GetAllKeys
     * @desc 获取所有键（按插入顺序）
     * @return 键数组
     * @Complexity O(n)
     *}
    function GetAllKeys: TKeysArray;

    // Serialization (override from base)
    procedure SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt); override;

    // Abstract methods from base classes
    function IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean; override;
    procedure AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt); override;
    procedure AppendToUnChecked(const aDst: TCollection); override;
    procedure DoZero; override;
    procedure DoReverse; override;

    property Count: SizeUInt read GetCount;
    property Capacity: SizeUInt read GetCapacity;
    property LoadFactor: Single read GetLoadFactor;
  end;

implementation

{ TLinkedHashMap<K,V> }

constructor TLinkedHashMap.Create;
begin
  Create(0, nil);
end;

constructor TLinkedHashMap.Create(aAllocator: IAllocator);
begin
  Create(0, aAllocator);
end;

constructor TLinkedHashMap.Create(aCapacity: SizeUInt);
begin
  Create(aCapacity, nil);
end;

constructor TLinkedHashMap.Create(aCapacity: SizeUInt; aAllocator: IAllocator);
begin
  inherited Create(aAllocator);

  FMap := TInternalMap.Create(aCapacity, nil, nil, Self.FAllocator);
  FNodeMap := TNodeMap.Create(aCapacity, nil, nil, Self.FAllocator);
  FHead := nil;
  FTail := nil;
end;

destructor TLinkedHashMap.Destroy;
begin
  Clear;
  FMap.Free;
  FNodeMap.Free;
  inherited;
end;

function TLinkedHashMap.AllocateNode(const aKey: K; const aValue: V): PNode;
begin
  Result := PNode(Self.FAllocator.GetMem(SizeOf(TNode)));
  Initialize(Result^);  // Initialize managed fields
  Result^.Pair.Key := aKey;
  Result^.Pair.Value := aValue;
  Result^.Prev := nil;
  Result^.Next := nil;
end;

procedure TLinkedHashMap.FreeNode(aNode: PNode);
begin
  if aNode <> nil then
  begin
    Finalize(aNode^);  // Finalize managed fields
    Self.FAllocator.FreeMem(aNode);
  end;
end;

procedure TLinkedHashMap.LinkNode(aNode: PNode);
begin
  if FHead = nil then
  begin
    // First node
    FHead := aNode;
    FTail := aNode;
    aNode^.Prev := nil;
    aNode^.Next := nil;
  end
  else
  begin
    // Append to tail
    aNode^.Prev := FTail;
    aNode^.Next := nil;
    FTail^.Next := aNode;
    FTail := aNode;
  end;
end;

procedure TLinkedHashMap.UnlinkNode(aNode: PNode);
var
  LPrev, LNext: PNode;
begin
  LPrev := PNode(aNode^.Prev);
  LNext := PNode(aNode^.Next);

  if LPrev <> nil then
    LPrev^.Next := LNext
  else
    FHead := LNext;

  if LNext <> nil then
    LNext^.Prev := LPrev
  else
    FTail := LPrev;
end;

function TLinkedHashMap.TryGetValue(const aKey: K; out aValue: V): Boolean;
begin
  Result := FMap.TryGetValue(aKey, aValue);
end;

function TLinkedHashMap.ContainsKey(const aKey: K): Boolean;
begin
  Result := FMap.ContainsKey(aKey);
end;

function TLinkedHashMap.Add(const aKey: K; const aValue: V): Boolean;
var
  LNode: PNode;
begin
  // Only add if key doesn't exist
  if FMap.ContainsKey(aKey) then
    Exit(False);

  // Add to hash map
  FMap.Add(aKey, aValue);

  // Create and link node
  LNode := AllocateNode(aKey, aValue);
  LinkNode(LNode);
  FNodeMap.Add(aKey, LNode);

  Result := True;
end;

function TLinkedHashMap.AddOrAssign(const aKey: K; const aValue: V): Boolean;
var
  LNode: PNode;
begin
  // Check if key exists
  Result := not FMap.ContainsKey(aKey);

  if Result then
  begin
    // New key - add to hash map and create linked node
    FMap.Add(aKey, aValue);
    LNode := AllocateNode(aKey, aValue);
    LinkNode(LNode);
    FNodeMap.Add(aKey, LNode);
  end
  else
  begin
    // Existing key - just update value, don't change order
    FMap.AddOrAssign(aKey, aValue);
    if FNodeMap.TryGetValue(aKey, LNode) then
      LNode^.Pair.Value := aValue;
  end;
end;

function TLinkedHashMap.Remove(const aKey: K): Boolean;
var
  LNode: PNode;
begin
  Result := FNodeMap.TryGetValue(aKey, LNode);
  if not Result then
    Exit;

  // Remove from linked list
  UnlinkNode(LNode);

  // Remove from maps
  FNodeMap.Remove(aKey);
  FMap.Remove(aKey);

  // Free node
  FreeNode(LNode);
end;

procedure TLinkedHashMap.Clear;
var
  LCurrent, LNext: PNode;
begin
  // Free all nodes
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    LNext := PNode(LCurrent^.Next);
    FreeNode(LCurrent);
    LCurrent := LNext;
  end;

  FHead := nil;
  FTail := nil;
  FMap.Clear;
  FNodeMap.Clear;
end;

function TLinkedHashMap.GetCapacity: SizeUInt;
begin
  Result := FMap.GetCapacity;
end;

function TLinkedHashMap.GetLoadFactor: Single;
begin
  Result := FMap.GetLoadFactor;
end;

procedure TLinkedHashMap.Reserve(aCapacity: SizeUInt);
begin
  FMap.Reserve(aCapacity);
  FNodeMap.Reserve(aCapacity);
end;

function TLinkedHashMap.Put(const aKey: K; const aValue: V): Boolean;
begin
  // Put 是 AddOrAssign 的别名，与 TreeMap API 保持一致
  Result := AddOrAssign(aKey, aValue);
end;

function TLinkedHashMap.Get(const aKey: K; out aValue: V): Boolean;
begin
  // Get 是 TryGetValue 的别名，与 TreeMap API 保持一致
  Result := TryGetValue(aKey, aValue);
end;

function TLinkedHashMap.GetCount: SizeUInt;
begin
  Result := FMap.GetCount;
end;

function TLinkedHashMap.IsEmpty: Boolean;
begin
  Result := FMap.IsEmpty;
end;

function TLinkedHashMap.First: TPairType;
begin
  if FHead = nil then
    raise EEmptyCollection.Create('TLinkedHashMap.First: collection is empty');

  Result := FHead^.Pair;
end;

function TLinkedHashMap.Last: TPairType;
begin
  if FTail = nil then
    raise EEmptyCollection.Create('TLinkedHashMap.Last: collection is empty');

  Result := FTail^.Pair;
end;

function TLinkedHashMap.TryGetFirst(out aPair: TPairType): Boolean;
begin
  Result := FHead <> nil;
  if Result then
    aPair := FHead^.Pair;
end;

function TLinkedHashMap.TryGetLast(out aPair: TPairType): Boolean;
begin
  Result := FTail <> nil;
  if Result then
    aPair := FTail^.Pair;
end;

function TLinkedHashMap.PtrIter: TPtrIter;
begin
  Result.Init(Self, @DoIterGetCurrent, @DoIterMoveNext, nil);
end;

procedure TLinkedHashMap.SerializeToArrayBuffer(aDst: Pointer; aCount: SizeUInt);
var
  LCurrent: PNode;
  LEntries: ^TEntryType;
  i: SizeUInt;
begin
  if (aDst = nil) or (aCount = 0) then
    Exit;

  LEntries := aDst;
  i := 0;
  LCurrent := FHead;
  while (LCurrent <> nil) and (i < aCount) do
  begin
    // ✅ Fix: Manually copy fields from TPair to TMapEntry (type incompatibility)
    LEntries[i].Key := LCurrent^.Pair.Key;
    LEntries[i].Value := LCurrent^.Pair.Value;
    Inc(i);
    LCurrent := PNode(LCurrent^.Next);
  end;
end;

function TLinkedHashMap.IsOverlap(const aSrc: Pointer; aElementCount: SizeUInt): Boolean;
begin
  // LinkedHashMap doesn't use contiguous memory, so no overlap possible
  Result := False;
end;

procedure TLinkedHashMap.AppendUnChecked(const aSrc: Pointer; aElementCount: SizeUInt);
var
  i: SizeUInt;
  LEntry: ^TEntryType;
begin
  if (aSrc = nil) or (aElementCount = 0) then
    Exit;

  LEntry := aSrc;
  for i := 0 to aElementCount - 1 do
  begin
    AddOrAssign(LEntry^.Key, LEntry^.Value);
    Inc(LEntry);
  end;
end;

procedure TLinkedHashMap.AppendToUnChecked(const aDst: TCollection);
var
  LCurrent: PNode;
  LDstMap: TLinkedHashMap;
begin
  if aDst = nil then
    Exit;

  if aDst is TLinkedHashMap then
  begin
    LDstMap := TLinkedHashMap(aDst);
    LCurrent := FHead;
    while LCurrent <> nil do
    begin
      LDstMap.AddOrAssign(LCurrent^.Pair.Key, LCurrent^.Pair.Value);
      LCurrent := PNode(LCurrent^.Next);
    end;
  end
  else
  begin
    LCurrent := FHead;
    while LCurrent <> nil do
    begin
      aDst.AppendUnChecked(@LCurrent^.Pair, 1);
      LCurrent := PNode(LCurrent^.Next);
    end;
  end;
end;

function TLinkedHashMap.DoIterGetCurrent(aIter: PPtrIter): Pointer;
begin
  if (aIter = nil) or (aIter^.Data = nil) then
    Exit(nil);
  Result := @PNode(aIter^.Data)^.Pair;
end;

function TLinkedHashMap.DoIterMoveNext(aIter: PPtrIter): Boolean;
var
  LNode: PNode;
begin
  if not aIter^.Started then
  begin
    aIter^.Started := True;
    aIter^.Data := FHead;
  end
  else if aIter^.Data <> nil then
  begin
    LNode := PNode(aIter^.Data);
    aIter^.Data := PNode(LNode^.Next);
  end;
  Result := aIter^.Data <> nil;
end;

function TLinkedHashMap.GetAllKeys: TKeysArray;
var
  LCurrent: PNode;
  i: SizeUInt;
begin
  Result := nil;
  SetLength(Result, GetCount);

  i := 0;
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    Result[i] := LCurrent^.Pair.Key;
    Inc(i);
    LCurrent := PNode(LCurrent^.Next);
  end;
end;

procedure TLinkedHashMap.DoZero;
var
  LCurrent: PNode;
  LZeroValue: V;
begin
  // Zero all values while preserving keys and order
  FillChar(LZeroValue, SizeOf(V), 0);

  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    LCurrent^.Pair.Value := LZeroValue;
    FMap.AddOrAssign(LCurrent^.Pair.Key, LZeroValue);
    LCurrent := PNode(LCurrent^.Next);
  end;
end;

procedure TLinkedHashMap.DoReverse;
var
  LCurrent, LNext: PNode;
begin
  // Reverse the linked list order
  LCurrent := FHead;
  FHead := FTail;
  FTail := LCurrent;

  while LCurrent <> nil do
  begin
    LNext := PNode(LCurrent^.Next);
    LCurrent^.Next := LCurrent^.Prev;
    LCurrent^.Prev := LNext;
    LCurrent := LNext;
  end;
end;

{ Entry API implementation }

function TLinkedHashMap.GetOrInsert(const aKey: K; const aDefaultValue: V): V;
var
  LNode: PNode;
begin
  if FMap.TryGetValue(aKey, Result) then
    Exit;

  // Key doesn't exist - insert default
  FMap.Add(aKey, aDefaultValue);
  LNode := AllocateNode(aKey, aDefaultValue);
  LinkNode(LNode);
  FNodeMap.Add(aKey, LNode);
  Result := aDefaultValue;
end;

function TLinkedHashMap.GetOrInsertWith(const aKey: K; aSupplier: TValueSupplier): V;
var
  LNode: PNode;
begin
  if FMap.TryGetValue(aKey, Result) then
    Exit;

  // Key doesn't exist - call supplier
  Result := aSupplier();
  FMap.Add(aKey, Result);
  LNode := AllocateNode(aKey, Result);
  LinkNode(LNode);
  FNodeMap.Add(aKey, LNode);
end;

procedure TLinkedHashMap.ModifyOrInsert(const aKey: K; aModifier: TValueModifier; const aDefaultValue: V);
var
  LNode: PNode;
  LValue: V;
begin
  if FNodeMap.TryGetValue(aKey, LNode) then
  begin
    // Key exists - modify in place
    aModifier(LNode^.Pair.Value);
    FMap.AddOrAssign(aKey, LNode^.Pair.Value);
  end
  else
  begin
    // Key doesn't exist - insert default
    LValue := aDefaultValue;
    FMap.Add(aKey, LValue);
    LNode := AllocateNode(aKey, LValue);
    LinkNode(LNode);
    FNodeMap.Add(aKey, LNode);
  end;
end;

procedure TLinkedHashMap.Retain(aPredicate: TEntryPredicate; aData: Pointer);
var
  LCurrent, LNext: PNode;
  LEntry: TEntryType;
begin
  LCurrent := FHead;
  while LCurrent <> nil do
  begin
    LNext := PNode(LCurrent^.Next);

    // 构建 entry 用于谓词判断
    LEntry.Key := LCurrent^.Pair.Key;
    LEntry.Value := LCurrent^.Pair.Value;

    // 如果谓词返回 False，删除这个元素
    if not aPredicate(LEntry, aData) then
    begin
      UnlinkNode(LCurrent);
      FNodeMap.Remove(LCurrent^.Pair.Key);
      FMap.Remove(LCurrent^.Pair.Key);
      FreeNode(LCurrent);
    end;

    LCurrent := LNext;
  end;
end;

end.
