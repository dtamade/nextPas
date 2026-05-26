unit nextpas.core.collections.lrucache;

{$I nextpas.core.settings.inc}

interface

uses
  SysUtils, Classes,
  nextpas.core.base,
  nextpas.core.math,
  nextpas.core.mem.utils,
  nextpas.core.mem.allocator,
  nextpas.core.collections.base,
  nextpas.core.collections.hashmap,
  nextpas.core.collections.vecdeque,
  nextpas.core.collections.element_manager;

threadvar
  GLruCacheActive: Pointer;

type
  {** THashFunc - 泛型哈希函数类型 }
  generic THashFunc<T> = function (const aValue: T; aData: Pointer): UInt64;

  {** TEqualsFunc - 泛型相等比较函数类型 }
  generic TEqualsFunc<T> = function (const aLeft, aRight: T; aData: Pointer): Boolean;

  {**
   * ILruCache<K,V>
   *
   * @desc 最近最少使用（LRU）缓存
   * @param K 键类型（必须支持哈希和比较）
   * @param V 值类型
   * @note
   *   - 当容量满时，自动淘汰最少使用的元素
   *   - 支持 Hit/Miss 统计
   *   - O(1) 查找、插入、更新
   *   - 纯数据管理，无并发安全（职责分离）
   *}
  generic ILruCache<K, V> = interface
    ['{C3D4E5F6-A7B8-4901-CDEF-345678901BCD}']

    {**
     * Get
     *
     * @desc 获取指定键的值（访问会将该键移到 MRU 位置）
     * @param aKey 要查找的键
     * @param aValue 返回的值
     * @return Boolean 是否找到（True=命中，False=未命中）
     *}
    function Get(const aKey: K; out aValue: V): Boolean;

    {**
     * Put
     *
     * @desc 插入或更新键值对
     * @param aKey 键
     * @param aValue 值
     * @note
     *   - 如果键已存在，会更新值并将该键移到 MRU 位置
     *   - 如果容量满，会淘汰 LRU 元素
     *}
    procedure Put(const aKey: K; const aValue: V);

    {**
     * SetMaxSize
     *
     * @desc 设置缓存的最大容量
     * @param aMaxSize 新的最大容量
     * @note 如果新容量小于当前大小，会淘汰多余元素
     *}
    procedure SetMaxSize(aMaxSize: SizeUInt);

    {**
     * GetMaxSize
     *
     * @desc 获取缓存的最大容量
     * @return SizeUInt 最大容量
     *}
    function GetMaxSize: SizeUInt;

    {**
     * GetSize
     *
     * @desc 获取当前缓存大小
     * @return SizeUInt 当前大小
     *}
    function GetSize: SizeUInt;

    {**
     * GetHitCount
     *
     * @desc 获取命中次数
     * @return UInt64 命中次数
     *}
    function GetHitCount: UInt64;

    {**
     * GetMissCount
     *
     * @desc 获取未命中次数
     * @return UInt64 未命中次数
     *}
    function GetMissCount: UInt64;

    {**
     * GetHitRate
     *
     * @desc 获取命中率
     * @return Double 命中率（0.0-1.0）
     *}
    function GetHitRate: Double;

    {**
     * Clear
     *
     * @desc 清空缓存
     *}
    procedure Clear;

    {**
     * Evict
     *
     * @desc 手动淘汰 LRU 元素
     * @return Boolean 是否成功淘汰
     *}
    function Evict: Boolean;

    {**
     * EvictLeastRecent
     *
     * @desc 淘汰指定数量的元素
     * @param aCount 要淘汰的数量
     * @return SizeUInt 实际淘汰的数量
     *}
    function EvictLeastRecent(aCount: SizeUInt): SizeUInt;

    {**
     * Peek
     *
     * @desc 查看指定键的值（不更新访问顺序）
     * @param aKey 要查找的键
     * @param aValue 返回的值
     * @return Boolean 是否找到
     *}
    function Peek(const aKey: K; out aValue: V): Boolean;

    {**
     * Remove
     *
     * @desc 移除指定键
     * @param aKey 要移除的键
     * @return Boolean 是否找到并移除
     *}
    function Remove(const aKey: K): Boolean;

    {**
     * Contains
     *
     * @desc 检查是否包含指定键
     * @param aKey 要查找的键
     * @return Boolean 是否包含
     *}
    function Contains(const aKey: K): Boolean;
  end;

  { TLruNode<K,V> LRU 缓存节点 }
  generic TLruNode<K, V> = record
    Key: K;
    Value: V;
    Prev: Pointer;
    Next: Pointer;
  end;

  {**
   * TLruCache<K,V>
   *
   * @desc 最近最少使用（LRU）缓存实现
   * @param K 键类型
   * @param V 值类型
   * @note
   *   - 使用哈希表 + 双向链表实现
   *   - O(1) 查找、插入、更新
   *   - MRU: Most Recently Used (最近最多使用)
   *   - LRU: Least Recently Used (最近最少使用)
   *}
  generic TLruCache<K, V> = class(TInterfacedObject, specialize ILruCache<K, V>)

  type
    PNode = ^specialize TLruNode<K, V>;
    TNodeType = specialize TLruNode<K, V>;
    THashMapNode = specialize THashMap<K, PNode>;

  private
    FMap: THashMapNode;
    FHead: PNode;  { 指向 MRU 端 }
    FTail: PNode;  { 指向 LRU 端 }
    FMaxSize: SizeUInt;
    FSize: SizeUInt;
    FHitCount: UInt64;
    FMissCount: UInt64;
    FAllocator: IAllocator;
    FHashFunc: specialize THashFunc<K>;
    FEqualsFunc: specialize TEqualsFunc<K>;
    FHashData: Pointer;
    FEqualsData: Pointer;
    FUseCustomLookup: Boolean;

    { 链表操作 }
    procedure AddToMRU(aNode: PNode);
    procedure MoveToMRU(aNode: PNode);
    function RemoveFromLRU: PNode;
    procedure RemoveNode(aNode: PNode);

    { 辅助方法 }
    function CreateNode(const aKey: K; const aValue: V): PNode;
    procedure DestroyNode(aNode: PNode);
    class function HashAdapter(const aKey: K): UInt32; static;
    class function EqualsAdapter(const aLeft, aRight: K): Boolean; static;

  public
    constructor Create(aMaxSize: SizeUInt; const aAllocator: IAllocator = nil;
      const aHash: specialize THashFunc<K> = nil; const aEquals: specialize TEqualsFunc<K> = nil;
      aHashData: Pointer = nil; aEqualsData: Pointer = nil);
    destructor Destroy; override;

    { ILruCache 接口实现 }
    function Get(const aKey: K; out aValue: V): Boolean;
    procedure Put(const aKey: K; const aValue: V);
    procedure SetMaxSize(aMaxSize: SizeUInt);
    function GetMaxSize: SizeUInt;
    function GetSize: SizeUInt;
    function GetHitCount: UInt64;
    function GetMissCount: UInt64;
    function GetHitRate: Double;
    procedure Clear;
    function Evict: Boolean;
    function EvictLeastRecent(aCount: SizeUInt): SizeUInt;
    function Peek(const aKey: K; out aValue: V): Boolean;
    function Remove(const aKey: K): Boolean;
    function Contains(const aKey: K): Boolean;
  end;

implementation

{ TLruCache }

constructor TLruCache.Create(aMaxSize: SizeUInt; const aAllocator: IAllocator;
  const aHash: specialize THashFunc<K>; const aEquals: specialize TEqualsFunc<K>;
  aHashData: Pointer; aEqualsData: Pointer);
var
  LHashAdapter: THashMapNode.THash;
  LEqualsAdapter: THashMapNode.TEquals;
begin
  inherited Create;

  if aMaxSize = 0 then
    aMaxSize := 100; { 默认容量 }

  FMaxSize := aMaxSize;
  FSize := 0;
  FHitCount := 0;
  FMissCount := 0;
  FAllocator := aAllocator;
  if FAllocator = nil then
    FAllocator := GetRtlAllocator;

  FHashFunc := aHash;
  FEqualsFunc := aEquals;
  FHashData := aHashData;
  FEqualsData := aEqualsData;
  FUseCustomLookup := Assigned(FHashFunc) or Assigned(FEqualsFunc);

  if Assigned(FHashFunc) then
    LHashAdapter := @HashAdapter
  else
    LHashAdapter := nil;

  if Assigned(FEqualsFunc) then
    LEqualsAdapter := @EqualsAdapter
  else
    LEqualsAdapter := nil;

  FMap := THashMapNode.Create(aMaxSize * 2, LHashAdapter, LEqualsAdapter, FAllocator);
  FHead := nil;
  FTail := nil;
end;

destructor TLruCache.Destroy;
begin
  Clear;
  FMap.Free;
  inherited Destroy;
end;

function TLruCache.CreateNode(const aKey: K; const aValue: V): PNode;
begin
  Result := PNode(FAllocator.AllocMem(SizeOf(TNodeType)));
  // 初始化接口引用
  Result^.Key := Default(K);
  Result^.Value := Default(V);
  Result^.Prev := nil;
  Result^.Next := nil;
  // 现在安全地赋值
  Result^.Key := aKey;
  Result^.Value := aValue;
end;

procedure TLruCache.DestroyNode(aNode: PNode);
begin
  if aNode <> nil then
  begin
    // 正确释放托管类型：赋值 Default 会触发编译器生成的释放代码
    // 对于接口类型，这会调用 _Release
    // 对于字符串类型，这会减少引用计数
    aNode^.Value := Default(V);
    aNode^.Key := Default(K);

    // 释放PNode内存
    FAllocator.FreeMem(aNode);
  end;
end;

class function TLruCache.HashAdapter(const aKey: K): UInt32;
var
  LOwner: specialize TLruCache<K, V>;
  LHash64: UInt64;
  p: Pointer;
begin
  if GLruCacheActive <> nil then
  begin
    LOwner := specialize TLruCache<K, V>(GLruCacheActive);
    if Assigned(LOwner.FHashFunc) then
    begin
      LHash64 := LOwner.FHashFunc(aKey, LOwner.FHashData);
      Result := HashMix32(UInt32(LHash64 xor (LHash64 shr 32)));
      Exit;
    end;
  end;

  // 默认哈希：与HashMap相同的逻辑
  p := @aKey;
  case SizeOf(K) of
    1: Exit(HashOfUInt32(PByte(p)^));
    2: Exit(HashOfUInt32(PWord(p)^));
    4: Exit(HashOfUInt32(PUInt32(p)^));
    8: Exit(HashOfUInt64(PQWord(p)^));
  else
    // 复杂类型，使用默认哈希（可能不完美但能工作）
    Result := HashOfUInt32(PUInt32(p)^);
  end;
end;

class function TLruCache.EqualsAdapter(const aLeft, aRight: K): Boolean;
var
  LOwner: specialize TLruCache<K, V>;
begin
  if GLruCacheActive <> nil then
  begin
    LOwner := specialize TLruCache<K, V>(GLruCacheActive);
    if Assigned(LOwner.FEqualsFunc) then
    begin
      Result := LOwner.FEqualsFunc(aLeft, aRight, LOwner.FEqualsData);
      Exit;
    end;
  end;

  // 默认比较：与HashMap相同的逻辑
  Result := aLeft = aRight;
end;

procedure TLruCache.AddToMRU(aNode: PNode);
begin
  if aNode = nil then Exit;

  { 添加到 MRU 端（头部） }
  aNode^.Next := FHead;
  aNode^.Prev := nil;

  if FHead <> nil then
    PNode(FHead)^.Prev := aNode;

  FHead := aNode;

  if FTail = nil then
    FTail := aNode;
end;

procedure TLruCache.MoveToMRU(aNode: PNode);
begin
  if aNode = nil then Exit;

  { 如果已在 MRU 端，不需要移动 }
  if aNode = FHead then Exit;

  { 从当前位置移除 }
  if aNode^.Prev <> nil then
    PNode(aNode^.Prev)^.Next := aNode^.Next;

  if aNode^.Next <> nil then
    PNode(aNode^.Next)^.Prev := aNode^.Prev;

  { 如果是 Tail，需要更新 Tail }
  if aNode = FTail then
  begin
    FTail := PNode(FTail)^.Prev;
    if FTail <> nil then
      PNode(FTail)^.Next := nil;
  end;

  { 添加到 MRU 端 }
  AddToMRU(aNode);
end;

function TLruCache.RemoveFromLRU: PNode;
begin
  { 从 LRU 端（尾部）移除 }
  if FTail = nil then
  begin
    Result := nil;
    Exit;
  end;

  Result := FTail;

  if FHead = FTail then
  begin
    { 只有一个节点 }
    FHead := nil;
    FTail := nil;
  end
  else
  begin
    FTail := PNode(FTail)^.Prev;
    PNode(FTail)^.Next := nil;
  end;

  Result^.Prev := nil;
  Result^.Next := nil;
end;

procedure TLruCache.RemoveNode(aNode: PNode);
begin
  if aNode = nil then Exit;

  { 从链表中移除 }
  if aNode^.Prev <> nil then
    PNode(aNode^.Prev)^.Next := aNode^.Next;

  if aNode^.Next <> nil then
    PNode(aNode^.Next)^.Prev := aNode^.Prev;

  { 更新 Head/Tail }
  if aNode = FHead then
    FHead := PNode(aNode^.Next);

  if aNode = FTail then
    FTail := PNode(aNode^.Prev);
end;

function TLruCache.Get(const aKey: K; out aValue: V): Boolean;
var
  LNode: PNode;
  LPrevCtx: Pointer;
  LFound: Boolean;
begin
  if FUseCustomLookup then
  begin
    LPrevCtx := GLruCacheActive;
    GLruCacheActive := Self;
    try
      LFound := FMap.TryGetValue(aKey, LNode);
    finally
      GLruCacheActive := LPrevCtx;
    end;
  end
  else
    LFound := FMap.TryGetValue(aKey, LNode);

  if LFound then
  begin
    { 命中 }
    aValue := LNode^.Value;
    Inc(FHitCount);

    { 移动到 MRU 端 }
    MoveToMRU(LNode);

    Result := True;
  end
  else
  begin
    { 未命中 }
    Inc(FMissCount);
    Result := False;
  end;
end;

procedure TLruCache.Put(const aKey: K; const aValue: V);
var
  LNode: PNode;
  LPrevCtx: Pointer;
  LFound: Boolean;
begin
  { 检查是否已存在 }
  if FUseCustomLookup then
  begin
    LPrevCtx := GLruCacheActive;
    GLruCacheActive := Self;
    try
      LFound := FMap.TryGetValue(aKey, LNode);
    finally
      GLruCacheActive := LPrevCtx;
    end;
  end
  else
    LFound := FMap.TryGetValue(aKey, LNode);

  if LFound then
  begin
    { 更新值并移动到 MRU 端 }
    LNode^.Value := aValue;
    MoveToMRU(LNode);
    Exit;
  end;

  { 创建新节点 }
  LNode := CreateNode(aKey, aValue);

  { 插入到哈希表 }
  if FUseCustomLookup then
  begin
    LPrevCtx := GLruCacheActive;
    GLruCacheActive := Self;
    try
      FMap.Add(aKey, LNode);
    finally
      GLruCacheActive := LPrevCtx;
    end;
  end
  else
    FMap.Add(aKey, LNode);

  { 添加到 MRU 端 }
  AddToMRU(LNode);
  Inc(FSize);

  { 检查是否需要淘汰 }
  if FSize > FMaxSize then
  begin
    { 淘汰 LRU 元素 }
    Evict;
  end;
end;

procedure TLruCache.SetMaxSize(aMaxSize: SizeUInt);
begin
  FMaxSize := aMaxSize;

  { 如果新容量小于当前大小，需要淘汰 }
  while FSize > FMaxSize do
    Evict;
end;

function TLruCache.GetMaxSize: SizeUInt;
begin
  Result := FMaxSize;
end;

function TLruCache.GetSize: SizeUInt;
begin
  Result := FSize;
end;

function TLruCache.GetHitCount: UInt64;
begin
  Result := FHitCount;
end;

function TLruCache.GetMissCount: UInt64;
begin
  Result := FMissCount;
end;

function TLruCache.GetHitRate: Double;
begin
  if FHitCount + FMissCount = 0 then
    Result := 0.0
  else
    Result := FHitCount / (FHitCount + FMissCount);
end;

procedure TLruCache.Clear;
var
  LKeys: array of K;
  LNode: PNode;
  i: SizeInt;
begin
  // 获取所有Keys的快照
  LKeys := FMap.GetKeys;

  // 逐个处理：从HashMap移除，然后释放PNode内存
  for i := 0 to High(LKeys) do
  begin
    if FMap.TryGetValue(LKeys[i], LNode) then
    begin
      // 从HashMap移除（会调用Finalize）
      FMap.Remove(LKeys[i]);

      // 使用DestroyNode来释放PNode内存
      DestroyNode(LNode);
    end;
  end;

  // 重置所有状态
  FHead := nil;
  FTail := nil;
  FSize := 0;
  FHitCount := 0;
  FMissCount := 0;
end;

function TLruCache.Evict: Boolean;
var
  LNode: PNode;
  LPrevCtx: Pointer;
begin
  LNode := RemoveFromLRU;
  if LNode <> nil then
  begin
    { 从哈希表中移除 }
    if FUseCustomLookup then
    begin
      LPrevCtx := GLruCacheActive;
      GLruCacheActive := Self;
      try
        FMap.Remove(LNode^.Key);
      finally
        GLruCacheActive := LPrevCtx;
      end;
    end
    else
      FMap.Remove(LNode^.Key);

    { 销毁节点 }
    DestroyNode(LNode);
    Dec(FSize);

    Result := True;
  end
  else
    Result := False;
end;

function TLruCache.EvictLeastRecent(aCount: SizeUInt): SizeUInt;
var
  i: SizeUInt;
begin
  Result := 0;
  for i := 1 to aCount do
  begin
    if Evict then
      Inc(Result)
    else
      Break;
  end;
end;

function TLruCache.Peek(const aKey: K; out aValue: V): Boolean;
var
  LNode: PNode;
  LPrevCtx: Pointer;
begin
  if FUseCustomLookup then
  begin
    LPrevCtx := GLruCacheActive;
    GLruCacheActive := Self;
    try
      Result := FMap.TryGetValue(aKey, LNode);
    finally
      GLruCacheActive := LPrevCtx;
    end;
  end
  else
    Result := FMap.TryGetValue(aKey, LNode);
  if Result then
  begin
    aValue := LNode^.Value;
    { 注意：Peek 不更新访问顺序 }
  end;
end;

function TLruCache.Remove(const aKey: K): Boolean;
var
  LNode: PNode;
  LPrevCtx: Pointer;
begin
  LPrevCtx := GLruCacheActive;
  GLruCacheActive := Self;
  try
    Result := FMap.TryGetValue(aKey, LNode);
    if Result then
    begin
      { 从链表中移除 }
      RemoveNode(LNode);

      { 从哈希表中移除 }
      FMap.Remove(aKey);

      { 销毁节点 - 使用 DestroyNode 正确释放托管类型 }
      DestroyNode(LNode);
      Dec(FSize);
    end;
  finally
    GLruCacheActive := LPrevCtx;
  end;
end;

function TLruCache.Contains(const aKey: K): Boolean;
var
  LPrevCtx: Pointer;
begin
  if FUseCustomLookup then
  begin
    LPrevCtx := GLruCacheActive;
    GLruCacheActive := Self;
    try
      Result := FMap.ContainsKey(aKey);
    finally
      GLruCacheActive := LPrevCtx;
    end;
  end
  else
    Result := FMap.ContainsKey(aKey);
end;

end.
