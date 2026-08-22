unit nextpas.core.lockfree.hashmap.rtm;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.atomic,
  nextpas.core.lockfree.hashmap,
  nextpas.core.lockfree.rtm;

const
  HASHMAP_RTM_DEFAULT_SHARD_COUNT = 16;
  HASHMAP_RTM_MAX_RETRIES = 3;

type
  {**
   * 使用 Intel TSX 优化的分片并发 HashMap。
   *
   * 读操作使用 RTM 事务内存，减少锁竞争。
   * 写操作使用传统的分片锁。
   *
   * @note 需要支持 Intel TSX 的 CPU
   *       如果 CPU 不支持 TSX，自动退化为普通分片 HashMap
   *}
  generic TRtmHashMapImpl<TKey, TValue> = class
  public type
    THashMap = specialize TShardedHashMapImpl<TKey, TValue>;
    TForEachCallback = procedure(const AKey: TKey; const AValue: TValue);
    TForEachCtxCallback = procedure(const AKey: TKey; const AValue: TValue; AContext: Pointer);
    TGetOrInsertResult = record
      Value: TValue;
      Existed: Boolean;
    end;
    TComputeCallback = function(const AKey: TKey): TValue;
    TUpdateCallback = function(const AOldValue: TValue): TValue;
  private
    FHashMap: THashMap;
    FRtmSupported: Boolean;
  public
    {** @desc 创建 RTM 优化的 HashMap
      @param AInitialCapacity 初始容量 }
    constructor Create(const AInitialCapacity: PtrUInt = HASHMAP_DEFAULT_CAPACITY);
    destructor Destroy; override;

    {** @desc 插入或覆盖键值对 }
    procedure Insert(const AKey: TKey; const AValue: TValue);
    {** @desc 查找键；成功返回 True 并设置 AValue
      @note 使用 RTM 事务内存优化读路径 }
    function Find(const AKey: TKey; out AValue: TValue): Boolean;
    {** @desc 删除键 }
    function Remove(const AKey: TKey): Boolean;
    {** @desc 删除键并返回旧值；不存在返回 False }
    function Remove(const AKey: TKey; out AValue: TValue): Boolean;
    {** @desc 仅在键不存在时插入；已存在返回 False（CAS 语义） }
    function TryInsert(const AKey: TKey; const AValue: TValue): Boolean;
    {** @desc 原子替换：已存在则替换并返回旧值，不存在返回 False }
    function Replace(const AKey: TKey; const ANewValue: TValue; out AOldValue: TValue): Boolean;
    {** @desc 检查键是否存在
      @note 使用 RTM 事务内存优化读路径 }
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
    {** @desc 检测是否支持 RTM }
    function IsRtmSupported: Boolean;
  end;

  generic TRtmHashMap<TKey, TValue> = class(specialize TRtmHashMapImpl<TKey, TValue>)
  end;

implementation

uses
  nextpas.core.errors;

constructor TRtmHashMapImpl.Create(const AInitialCapacity: PtrUInt);
begin
  if IsManagedType(TKey) then
    raise EArgumentError.Create('TRtmHashMap: TKey must be unmanaged (no string/interface/dynarray)');
  if IsManagedType(TValue) then
    raise EArgumentError.Create('TRtmHashMap: TValue must be unmanaged (no string/interface/dynarray)');
  inherited Create;
  FHashMap := THashMap.Create(AInitialCapacity);
  FRtmSupported := RtmIsSupported;
end;

destructor TRtmHashMapImpl.Destroy;
begin
  FHashMap.Free;
  FHashMap := nil;
  inherited;
end;

procedure TRtmHashMapImpl.Insert(const AKey: TKey; const AValue: TValue);
begin
  // 写操作使用传统锁
  FHashMap.Insert(AKey, AValue);
end;

function TRtmHashMapImpl.Find(const AKey: TKey; out AValue: TValue): Boolean;
var
  LStatus: TRtmStatus;
  LRetry: Integer;
begin
  if not FRtmSupported then
  begin
    // 不支持 RTM，使用普通路径
    Exit(FHashMap.Find(AKey, AValue));
  end;

  // 使用 RTM 事务内存优化读路径
  for LRetry := 0 to HASHMAP_RTM_MAX_RETRIES - 1 do
  begin
    LStatus := RtmBegin;
    case LStatus of
      rtmStarted:
        begin
          // 事务开始，执行读操作
          Result := FHashMap.Find(AKey, AValue);
          RtmEnd;
          Exit;
        end;
      rtmRetry:
        begin
          // 可重试，继续循环
          Continue;
        end;
      rtmFallback:
        begin
          // 需要回退，使用普通路径
          Result := FHashMap.Find(AKey, AValue);
          Exit;
        end;
    else
      // 其他状态，使用普通路径
      Result := FHashMap.Find(AKey, AValue);
      Exit;
    end;
  end;

  // 重试次数用完，使用普通路径
  Result := FHashMap.Find(AKey, AValue);
end;

function TRtmHashMapImpl.Remove(const AKey: TKey): Boolean;
begin
  // 写操作使用传统锁
  Result := FHashMap.Remove(AKey);
end;

function TRtmHashMapImpl.Remove(const AKey: TKey; out AValue: TValue): Boolean;
begin
  // 写操作使用传统锁
  Result := FHashMap.Remove(AKey, AValue);
end;

function TRtmHashMapImpl.TryInsert(const AKey: TKey; const AValue: TValue): Boolean;
begin
  // 写操作使用传统锁
  Result := FHashMap.TryInsert(AKey, AValue);
end;

function TRtmHashMapImpl.Replace(const AKey: TKey; const ANewValue: TValue; out AOldValue: TValue): Boolean;
begin
  // 写操作使用传统锁
  Result := FHashMap.Replace(AKey, ANewValue, AOldValue);
end;

function TRtmHashMapImpl.Contains(const AKey: TKey): Boolean;
var
  LStatus: TRtmStatus;
  LRetry: Integer;
begin
  if not FRtmSupported then
  begin
    // 不支持 RTM，使用普通路径
    Exit(FHashMap.Contains(AKey));
  end;

  // 使用 RTM 事务内存优化读路径
  for LRetry := 0 to HASHMAP_RTM_MAX_RETRIES - 1 do
  begin
    LStatus := RtmBegin;
    case LStatus of
      rtmStarted:
        begin
          // 事务开始，执行读操作
          Result := FHashMap.Contains(AKey);
          RtmEnd;
          Exit;
        end;
      rtmRetry:
        begin
          // 可重试，继续循环
          Continue;
        end;
      rtmFallback:
        begin
          // 需要回退，使用普通路径
          Result := FHashMap.Contains(AKey);
          Exit;
        end;
    else
      // 其他状态，使用普通路径
      Result := FHashMap.Contains(AKey);
      Exit;
    end;
  end;

  // 重试次数用完，使用普通路径
  Result := FHashMap.Contains(AKey);
end;

function TRtmHashMapImpl.Count: PtrUInt;
begin
  Result := FHashMap.Count;
end;

procedure TRtmHashMapImpl.ForEach(const ACallback: TForEachCallback);
begin
  FHashMap.ForEach(ACallback);
end;

procedure TRtmHashMapImpl.ForEachCtx(const ACallback: TForEachCtxCallback; AContext: Pointer);
begin
  FHashMap.ForEachCtx(ACallback, AContext);
end;

function TRtmHashMapImpl.GetOrInsert(const AKey: TKey; const ADefault: TValue): TGetOrInsertResult;
var
  LResult: THashMap.TGetOrInsertResult;
begin
  // 写操作使用传统锁
  LResult := FHashMap.GetOrInsert(AKey, ADefault);
  Result.Value := LResult.Value;
  Result.Existed := LResult.Existed;
end;

function TRtmHashMapImpl.GetOrInsertFn(const AKey: TKey; const ACompute: TComputeCallback): TGetOrInsertResult;
var
  LResult: THashMap.TGetOrInsertResult;
begin
  // 写操作使用传统锁
  LResult := FHashMap.GetOrInsertFn(AKey, ACompute);
  Result.Value := LResult.Value;
  Result.Existed := LResult.Existed;
end;

function TRtmHashMapImpl.GetOrUpdate(const AKey: TKey; const ADefault: TValue; const AUpdate: TUpdateCallback): TGetOrInsertResult;
var
  LResult: THashMap.TGetOrInsertResult;
begin
  // 写操作使用传统锁
  LResult := FHashMap.GetOrUpdate(AKey, ADefault, AUpdate);
  Result.Value := LResult.Value;
  Result.Existed := LResult.Existed;
end;

procedure TRtmHashMapImpl.Clear;
begin
  FHashMap.Clear;
end;

procedure TRtmHashMapImpl.Reserve(const ACount: PtrUInt);
begin
  FHashMap.Reserve(ACount);
end;

function TRtmHashMapImpl.IsRtmSupported: Boolean;
begin
  Result := FRtmSupported;
end;

end.
