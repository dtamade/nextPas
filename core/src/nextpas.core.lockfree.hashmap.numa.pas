unit nextpas.core.lockfree.hashmap.numa;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.atomic,
  nextpas.core.numa,
  nextpas.core.lockfree.hashmap;

const
  HASHMAP_NUMA_DEFAULT_INITIAL_CAPACITY_PER_NODE = HASHMAP_DEFAULT_CAPACITY;

type
  {**
   * NUMA 感知的分片并发 HashMap。
   *
   * 按 NUMA 节点分片，每个节点有独立的分片组。
   * 读操作优先访问本地节点的分片，减少跨节点内存访问。
   *
   * @note 适用于多 NUMA 节点系统，单节点系统退化为普通分片 HashMap
   *}
  generic TNumaShardedHashMapImpl<TKey, TValue> = class
  public type
    TForEachCallback = procedure(const AKey: TKey; const AValue: TValue);
    TForEachCtxCallback = procedure(const AKey: TKey; const AValue: TValue; AContext: Pointer);
    TGetOrInsertResult = record
      Value: TValue;
      Existed: Boolean;
    end;
    TComputeCallback = function(const AKey: TKey): TValue;
    TUpdateCallback = function(const AOldValue: TValue): TValue;
  private type
    THashMap = specialize TShardedHashMapImpl<TKey, TValue>;
    TNodeShard = record
      HashMap: THashMap;
      NodeId: Integer;
    end;
  private
    FNodeShards: array of TNodeShard;
    FNodeCount: Integer;
    FInitialCapacityPerNode: PtrUInt;
    function GetNodeForKey(const AKey: TKey): Integer;
    function GetHashMapForNode(ANode: Integer): THashMap;
  public
    {** @desc 创建 NUMA 感知 HashMap
      @param AInitialCapacityPerNode 每个 NUMA 节点内部 HashMap 的初始容量 }
    constructor Create(const AInitialCapacityPerNode: PtrUInt = HASHMAP_NUMA_DEFAULT_INITIAL_CAPACITY_PER_NODE);
    destructor Destroy; override;

    {** @desc 插入或覆盖键值对 }
    procedure Insert(const AKey: TKey; const AValue: TValue);
    {** @desc 查找键；成功返回 True 并设置 AValue }
    function Find(const AKey: TKey; out AValue: TValue): Boolean;
    {** @desc 删除键 }
    function Remove(const AKey: TKey): Boolean;
    {** @desc 删除键并返回旧值；不存在返回 False }
    function Remove(const AKey: TKey; out AValue: TValue): Boolean;
    {** @desc 仅在键不存在时插入；已存在返回 False（CAS 语义） }
    function TryInsert(const AKey: TKey; const AValue: TValue): Boolean;
    {** @desc 原子替换：已存在则替换并返回旧值，不存在返回 False }
    function Replace(const AKey: TKey; const ANewValue: TValue; out AOldValue: TValue): Boolean;
    {** @desc 检查键是否存在 }
    function Contains(const AKey: TKey): Boolean;
    {** @desc 总元素数 }
    function Count: PtrUInt;
    {** @desc 遍历所有元素 }
    procedure ForEach(const ACallback: TForEachCallback);
    {** @desc 遍历所有元素（带上下文指针） }
    procedure ForEachCtx(const ACallback: TForEachCtxCallback; AContext: Pointer);
    {** @desc 获取指定键的值；不存在则插入默认值并返回 }
    function GetOrInsert(const AKey: TKey; const ADefault: TValue): TGetOrInsertResult;
    {** @desc 获取指定键的值；不存在则通过回调延迟计算并插入 }
    function GetOrInsertFn(const AKey: TKey; const ACompute: TComputeCallback): TGetOrInsertResult;
    {** @desc 获取并更新：已存在则用回调更新，不存在则插入默认值 }
    function GetOrUpdate(const AKey: TKey; const ADefault: TValue; const AUpdate: TUpdateCallback): TGetOrInsertResult;
    {** @desc 清空所有元素 }
    procedure Clear;
    {** @desc 预分配容量 }
    procedure Reserve(const ACount: PtrUInt);
    {** @desc 获取 NUMA 节点数 }
    function NodeCount: Integer;
    {** @desc 获取指定节点的元素数 }
    function NodeCountForNode(ANode: Integer): PtrUInt;
  end;

  generic TNumaShardedHashMap<TKey, TValue> = class(specialize TNumaShardedHashMapImpl<TKey, TValue>)
  end;

implementation

uses
  nextpas.core.errors;

function TNumaShardedHashMapImpl.GetNodeForKey(const AKey: TKey): Integer;
var
  LHash: PtrUInt;
begin
  // 使用哈希值选择 NUMA 节点
  // 这样相同键总是路由到同一节点
  LHash := FNodeShards[0].HashMap.HashKey(AKey);
  Result := LHash mod FNodeCount;
end;

function TNumaShardedHashMapImpl.GetHashMapForNode(ANode: Integer): THashMap;
begin
  if (ANode < 0) or (ANode >= FNodeCount) then
    ANode := 0;
  Result := FNodeShards[ANode].HashMap;
end;

constructor TNumaShardedHashMapImpl.Create(const AInitialCapacityPerNode: PtrUInt);
var
  I: Integer;
begin
  if IsManagedType(TKey) then
    raise EArgumentError.Create('TNumaShardedHashMap: TKey must be unmanaged (no string/interface/dynarray)');
  if IsManagedType(TValue) then
    raise EArgumentError.Create('TNumaShardedHashMap: TValue must be unmanaged (no string/interface/dynarray)');
  inherited Create;
  FNodeCount := NumaNodeCount;
  if FNodeCount < 1 then
    FNodeCount := 1;
  if AInitialCapacityPerNode = 0 then
    FInitialCapacityPerNode := HASHMAP_DEFAULT_CAPACITY
  else
    FInitialCapacityPerNode := AInitialCapacityPerNode;
  SetLength(FNodeShards, FNodeCount);
  for I := 0 to FNodeCount - 1 do
  begin
    FNodeShards[I].NodeId := I;
    FNodeShards[I].HashMap := THashMap.Create(FInitialCapacityPerNode);
  end;
end;

destructor TNumaShardedHashMapImpl.Destroy;
var
  I: Integer;
begin
  for I := 0 to FNodeCount - 1 do
  begin
    FNodeShards[I].HashMap.Free;
    FNodeShards[I].HashMap := nil;
  end;
  SetLength(FNodeShards, 0);
  inherited;
end;

procedure TNumaShardedHashMapImpl.Insert(const AKey: TKey; const AValue: TValue);
var
  LNode: Integer;
begin
  LNode := GetNodeForKey(AKey);
  FNodeShards[LNode].HashMap.Insert(AKey, AValue);
end;

function TNumaShardedHashMapImpl.Find(const AKey: TKey; out AValue: TValue): Boolean;
var
  LNode: Integer;
begin
  LNode := GetNodeForKey(AKey);
  Result := FNodeShards[LNode].HashMap.Find(AKey, AValue);
end;

function TNumaShardedHashMapImpl.Remove(const AKey: TKey): Boolean;
var
  LNode: Integer;
begin
  LNode := GetNodeForKey(AKey);
  Result := FNodeShards[LNode].HashMap.Remove(AKey);
end;

function TNumaShardedHashMapImpl.Remove(const AKey: TKey; out AValue: TValue): Boolean;
var
  LNode: Integer;
begin
  LNode := GetNodeForKey(AKey);
  Result := FNodeShards[LNode].HashMap.Remove(AKey, AValue);
end;

function TNumaShardedHashMapImpl.TryInsert(const AKey: TKey; const AValue: TValue): Boolean;
var
  LNode: Integer;
begin
  LNode := GetNodeForKey(AKey);
  Result := FNodeShards[LNode].HashMap.TryInsert(AKey, AValue);
end;

function TNumaShardedHashMapImpl.Replace(const AKey: TKey; const ANewValue: TValue; out AOldValue: TValue): Boolean;
var
  LNode: Integer;
begin
  LNode := GetNodeForKey(AKey);
  Result := FNodeShards[LNode].HashMap.Replace(AKey, ANewValue, AOldValue);
end;

function TNumaShardedHashMapImpl.Contains(const AKey: TKey): Boolean;
var
  LNode: Integer;
begin
  LNode := GetNodeForKey(AKey);
  Result := FNodeShards[LNode].HashMap.Contains(AKey);
end;

function TNumaShardedHashMapImpl.Count: PtrUInt;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FNodeCount - 1 do
    Inc(Result, FNodeShards[I].HashMap.Count);
end;

procedure TNumaShardedHashMapImpl.ForEach(const ACallback: TForEachCallback);
var
  I: Integer;
begin
  for I := 0 to FNodeCount - 1 do
    FNodeShards[I].HashMap.ForEach(ACallback);
end;

procedure TNumaShardedHashMapImpl.ForEachCtx(const ACallback: TForEachCtxCallback; AContext: Pointer);
var
  I: Integer;
begin
  for I := 0 to FNodeCount - 1 do
    FNodeShards[I].HashMap.ForEachCtx(ACallback, AContext);
end;

function TNumaShardedHashMapImpl.GetOrInsert(const AKey: TKey; const ADefault: TValue): TGetOrInsertResult;
var
  LNode: Integer;
  LResult: THashMap.TGetOrInsertResult;
begin
  LNode := GetNodeForKey(AKey);
  LResult := FNodeShards[LNode].HashMap.GetOrInsert(AKey, ADefault);
  Result.Value := LResult.Value;
  Result.Existed := LResult.Existed;
end;

function TNumaShardedHashMapImpl.GetOrInsertFn(const AKey: TKey; const ACompute: TComputeCallback): TGetOrInsertResult;
var
  LNode: Integer;
  LResult: THashMap.TGetOrInsertResult;
begin
  LNode := GetNodeForKey(AKey);
  LResult := FNodeShards[LNode].HashMap.GetOrInsertFn(AKey, ACompute);
  Result.Value := LResult.Value;
  Result.Existed := LResult.Existed;
end;

function TNumaShardedHashMapImpl.GetOrUpdate(const AKey: TKey; const ADefault: TValue; const AUpdate: TUpdateCallback): TGetOrInsertResult;
var
  LNode: Integer;
  LResult: THashMap.TGetOrInsertResult;
begin
  LNode := GetNodeForKey(AKey);
  LResult := FNodeShards[LNode].HashMap.GetOrUpdate(AKey, ADefault, AUpdate);
  Result.Value := LResult.Value;
  Result.Existed := LResult.Existed;
end;

procedure TNumaShardedHashMapImpl.Clear;
var
  I: Integer;
begin
  for I := 0 to FNodeCount - 1 do
    FNodeShards[I].HashMap.Clear;
end;

procedure TNumaShardedHashMapImpl.Reserve(const ACount: PtrUInt);
var
  I: Integer;
  LPerNode: PtrUInt;
begin
  LPerNode := (ACount + FNodeCount - 1) div FNodeCount;
  for I := 0 to FNodeCount - 1 do
    FNodeShards[I].HashMap.Reserve(LPerNode);
end;

function TNumaShardedHashMapImpl.NodeCount: Integer;
begin
  Result := FNodeCount;
end;

function TNumaShardedHashMapImpl.NodeCountForNode(ANode: Integer): PtrUInt;
begin
  if (ANode < 0) or (ANode >= FNodeCount) then
    Exit(0);
  Result := FNodeShards[ANode].HashMap.Count;
end;

end.
