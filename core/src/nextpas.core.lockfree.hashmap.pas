unit nextpas.core.lockfree.hashmap;
{**
 * @desc Sharded concurrent hash map using per-shard spin locks.
 *
 * @note This is NOT a lock-free structure. It uses atomic spin locks per shard,
 *       which provides good performance under low-to-moderate contention.
 *       Placed in the lockfree namespace because it uses atomic primitives
 *       and follows the same concurrent data structure patterns.
 *
 * @see dashmap (Rust) — similar sharded-lock design
 * @see sync.Map (Go) — different approach but same concurrent map category
 *
 * Preferred atomics: atomic_* + mo_* (Go/Rust parity / Q2). NOT lock-free.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.base;

const
  HASHMAP_DEFAULT_SHARD_COUNT = 16;
  HASHMAP_DEFAULT_CAPACITY = 16;
  HASHMAP_LOAD_FACTOR_NUM = 3;
  HASHMAP_LOAD_FACTOR_DEN = 4;

type
  {**
   * 分片锁并发 HashMap。
   *
   * 使用分片自旋锁（per-shard spinlock via atomic_exchange）实现并发安全，
   * 不是 lock-free 结构。在高竞争场景下，自旋等待可能导致 CPU 浪费；
   * 适合竞争不激烈的快速路径。
   *
   * @constraints
   *   - TKey 和 TValue 必须是 unmanaged 类型
   *   - 所有公共方法（Insert/Find/Remove/Contains/Count）是线程安全的
   *   - Count 返回近似值（需要逐分片加锁）
   *   - Close 后：Insert/Reserve/GetOrUpdate 抛错；TryInsert/Replace 拒绝写；
   *     GetOrInsert* 仅允许已有键读取；Find/Remove/ForEach/Clear 仍可用。
   *   - 生命周期：Close → join accessors → Free（Destroy 会 Close，不替代 join）
   *
   * @see collections.hashmap.pas 中的 THashMap 用于单线程场景
   * @see charter-c-hashmap-close.md
   *}
  generic TShardedHashMapImpl<TKey, TValue> = class
  public type
    {** @desc ForEach 回调类型 }
    TForEachCallback = procedure(const AKey: TKey; const AValue: TValue);
    {** @desc ForEachCtx 带上下文的回调类型 }
    TForEachCtxCallback = procedure(const AKey: TKey; const AValue: TValue; AContext: Pointer);
    {** @desc GetOrInsert 返回结果 }
    TGetOrInsertResult = record
      Value: TValue;
      Existed: Boolean;
    end;
    {** @desc GetOrInsertFn 延迟计算回调类型 }
    TComputeCallback = function(const AKey: TKey): TValue;
    {** @desc GetOrUpdate 更新回调类型（接收旧值，返回新值） }
    TUpdateCallback = function(const AOldValue: TValue): TValue;
  private type
    TEntryState = (esEmpty, esOccupied, esDeleted);
    TEntry = record
      Key: TKey;
      Value: TValue;
      State: TEntryState;
    end;
    PShard = ^TShard;
    TShard = record
      {** 读写锁: 0=无锁, >0=读锁计数, -1=写锁 }
      Lock: Int32;
      {** 版本号: 用于无锁读路径，奇数表示正在写，偶数表示稳定状态 }
      Version: Int32;
      Entries: array of TEntry;
      Count: PtrUInt;
      Capacity: PtrUInt;
      Mask: PtrUInt;
    end;
  private
    FShards: array of TShard;
    FShardCount: PtrUInt;
    FClosed: Int32;
    function ShardIndex(const AKey: TKey): PtrUInt;
    procedure ShardLock(var AShard: TShard);
    procedure ShardUnlock(var AShard: TShard);
    procedure ShardReadLock(var AShard: TShard);
    procedure ShardReadUnlock(var AShard: TShard);
    procedure ShardWriteLock(var AShard: TShard);
    procedure ShardWriteUnlock(var AShard: TShard);
    procedure ShardInit(var AShard: TShard; const ACapacity: PtrUInt);
    procedure ShardResize(var AShard: TShard);
    function ShardFind(const AShard: TShard; const AKey: TKey; out AIdx: PtrUInt): Boolean;
    procedure EnsureWritable(const AOp: string);
  public
    {** @desc 计算键的哈希值 }
    function HashKey(const AKey: TKey): PtrUInt;
    {** @desc 创建分片锁 HashMap }
    constructor Create(const AInitialCapacity: PtrUInt = HASHMAP_DEFAULT_CAPACITY);
    destructor Destroy; override;

    {** @desc 拒绝新写入；幂等。Destroy 会先 Close。 }
    procedure Close;
    {** @desc 是否已 Close }
    function IsClosed: Boolean; inline;

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
    {** @desc 总元素数（逐 shard 加锁累加的快照，非线性化）
      @note 返回值是各 shard 计数之和。在并发 Insert/Remove 下，
            与 ForEach 看到的元素集合可能不一致（各自是独立快照）。 }
    function Count: PtrUInt;

    {** @desc 遍历所有元素（持锁，回调期间其他操作阻塞）
      @param ACallback 回调函数，接收 key 和 value
      @note 逐 shard 遍历，每个 shard 持锁期间回调。
            与 Count 各自是独立快照，在并发修改下可能不一致。
      @warning 不可在回调中调用本 HashMap 的其他方法（死锁） }
    procedure ForEach(const ACallback: TForEachCallback);

    {** @desc 遍历所有元素（带上下文指针）
      @param ACallback 回调函数，接收 key、value 和上下文指针
      @param AContext 透传给回调的上下文指针
      @note 同 ForEach，持锁期间调用，不可重入 }
    procedure ForEachCtx(const ACallback: TForEachCtxCallback; AContext: Pointer);

    {** @desc 获取指定键的值；不存在则插入默认值并返回
      @param AKey 要查找或插入的键
      @param ADefault 不存在时插入的默认值
      @return 结果记录：Value=找到的值或默认值，Existed=是否已存在
      @note 原子操作，仅加锁一次 }
    function GetOrInsert(const AKey: TKey; const ADefault: TValue): TGetOrInsertResult;

    {** @desc 获取指定键的值；不存在则通过回调延迟计算并插入
      @param AKey 要查找或插入的键
      @param ACompute 不存在时调用的计算函数（仅在需要时调用）
      @return 结果记录：Value=找到的值或计算值，Existed=是否已存在
      @note 原子操作，仅加锁一次；回调在持锁期间调用，应尽快返回 }
    function GetOrInsertFn(const AKey: TKey; const ACompute: TComputeCallback): TGetOrInsertResult;

    {** @desc 获取并更新：已存在则用回调更新，不存在则插入默认值
      @param AKey 要查找或插入的键
      @param ADefault 不存在时插入的默认值
      @param AUpdate 已存在时调用的更新函数（接收旧值，返回新值）
      @return 结果记录：Value=新值，Existed=更新前是否已存在
      @note 原子操作，仅加锁一次；回调在持锁期间调用
      @example 原子计数器: map.GetOrUpdate(key, 1, function(old) begin Result := old + 1 end) }
    function GetOrUpdate(const AKey: TKey; const ADefault: TValue; const AUpdate: TUpdateCallback): TGetOrInsertResult;

    {** @desc 清空所有元素 }
    procedure Clear;
    {** @desc 预分配容量，确保可容纳 ACount 个元素而不触发 resize
      @param ACount 预期元素数量
      @note 按分片均分容量，每个分片独立扩容 }
    procedure Reserve(const ACount: PtrUInt);
  end;

  generic TShardedHashMap<TKey, TValue> = class(specialize TShardedHashMapImpl<TKey, TValue>)
  end;

implementation

function TShardedHashMapImpl.HashKey(const AKey: TKey): PtrUInt;
var
  LPtr: PByte;
  LI: PtrUInt;
  LH: PtrUInt;
begin
  LPtr := @AKey;
  LH := 14695981039346656037;
  { Fast path for common small key sizes }
  case SizeOf(TKey) of
    1: begin
      LH := (LH xor PtrUInt(LPtr[0])) * 1099511628211;
    end;
    2: begin
      LH := (LH xor PtrUInt(LPtr[0])) * 1099511628211;
      LH := (LH xor PtrUInt(LPtr[1])) * 1099511628211;
    end;
    4: begin
      LH := (LH xor PtrUInt(LPtr[0])) * 1099511628211;
      LH := (LH xor PtrUInt(LPtr[1])) * 1099511628211;
      LH := (LH xor PtrUInt(LPtr[2])) * 1099511628211;
      LH := (LH xor PtrUInt(LPtr[3])) * 1099511628211;
    end;
    8: begin
      LH := (LH xor PtrUInt(LPtr[0])) * 1099511628211;
      LH := (LH xor PtrUInt(LPtr[1])) * 1099511628211;
      LH := (LH xor PtrUInt(LPtr[2])) * 1099511628211;
      LH := (LH xor PtrUInt(LPtr[3])) * 1099511628211;
      LH := (LH xor PtrUInt(LPtr[4])) * 1099511628211;
      LH := (LH xor PtrUInt(LPtr[5])) * 1099511628211;
      LH := (LH xor PtrUInt(LPtr[6])) * 1099511628211;
      LH := (LH xor PtrUInt(LPtr[7])) * 1099511628211;
    end;
  else
    { Generic path for other sizes }
    for LI := 0 to SizeOf(TKey) - 1 do
    begin
      LH := LH xor PtrUInt(LPtr[LI]);
      LH := LH * 1099511628211;
    end;
  end;
  Result := LH;
end;

function TShardedHashMapImpl.ShardIndex(const AKey: TKey): PtrUInt;
begin
  { Use bitmask instead of mod for power-of-2 shard count }
  Result := HashKey(AKey) and (FShardCount - 1);
end;

procedure TShardedHashMapImpl.ShardLock(var AShard: TShard);
var
  LSpins: Int32;
begin
  LSpins := 0;
  while atomic_exchange(AShard.Lock, 1, mo_acquire) <> 0 do
  begin
    Inc(LSpins);
    if LSpins < 64 then
      CpuPause
    else
    begin
      LSpins := 0;
      ThreadSwitch;
    end;
  end;
end;

procedure TShardedHashMapImpl.ShardUnlock(var AShard: TShard);
begin
  atomic_store(AShard.Lock, 0, mo_release);
end;

{** 获取读锁: 允许多个读者并发
  @note 使用 exponential backoff 减少 CAS 循环的 CPU 浪费 }
procedure TShardedHashMapImpl.ShardReadLock(var AShard: TShard);
var
  LLock: Int32;
  LExpected: Int32;
  LSpins: Int32;
  LBackoff: Int32;
begin
  LSpins := 0;
  LBackoff := 1;
  repeat
    LLock := atomic_load(AShard.Lock, mo_relaxed);
    if LLock >= 0 then
    begin
      { 尝试增加读锁计数 }
      LExpected := LLock;
      if atomic_compare_exchange_strong(AShard.Lock, LExpected, LLock + 1, mo_acquire, mo_relaxed) then
        Exit;
    end;
    { 有写锁，等待 }
    Inc(LSpins);
    if LSpins < 8 then
      CpuPause
    else if LSpins < 64 then
    begin
      { Exponential backoff: 减少 CAS 频率 }
      CpuPause;
      if LSpins mod LBackoff = 0 then
      begin
        LBackoff := LBackoff * 2;
        if LBackoff > 16 then
          LBackoff := 16;
      end;
    end
    else
    begin
      LSpins := 0;
      LBackoff := 1;
      ThreadSwitch;
    end;
  until False;
end;

{** 释放读锁 }
procedure TShardedHashMapImpl.ShardReadUnlock(var AShard: TShard);
begin
  atomic_fetch_sub(AShard.Lock, 1, mo_release);
end;

{** 获取写锁: 独占访问 }
procedure TShardedHashMapImpl.ShardWriteLock(var AShard: TShard);
var
  LSpins: Int32;
  LExpected: Int32;
begin
  LSpins := 0;
  repeat
    { 尝试从 0 变为 -1 (写锁) }
    LExpected := 0;
    if atomic_compare_exchange_strong(AShard.Lock, LExpected, -1, mo_acquire, mo_relaxed) then
      Exit;
    { 有读者或写者，等待 }
    Inc(LSpins);
    if LSpins < 64 then
      CpuPause
    else
    begin
      LSpins := 0;
      ThreadSwitch;
    end;
  until False;
end;

{** 释放写锁 }
procedure TShardedHashMapImpl.ShardWriteUnlock(var AShard: TShard);
begin
  atomic_store(AShard.Lock, 0, mo_release);
end;

procedure TShardedHashMapImpl.ShardInit(var AShard: TShard; const ACapacity: PtrUInt);
var
  LI: PtrUInt;
begin
  AShard.Lock := 0;
  AShard.Version := 0;  { 初始化版本号为 0 (偶数 = 稳定状态) }
  AShard.Capacity := ACapacity;
  AShard.Mask := ACapacity - 1;
  AShard.Count := 0;
  SetLength(AShard.Entries, ACapacity);
  for LI := 0 to ACapacity - 1 do
    AShard.Entries[LI].State := esEmpty;
end;

procedure TShardedHashMapImpl.ShardResize(var AShard: TShard);
var
  LOldEntries: array of TEntry;
  LOldCapacity: PtrUInt;
  LI: PtrUInt;
  LIdx: PtrUInt;
  LNewCapacity: PtrUInt;
begin
  LOldEntries := AShard.Entries;
  LOldCapacity := AShard.Capacity;
  LNewCapacity := LOldCapacity * 2;
  AShard.Capacity := LNewCapacity;
  AShard.Mask := LNewCapacity - 1;
  AShard.Count := 0;
  SetLength(AShard.Entries, LNewCapacity);
  for LI := 0 to LNewCapacity - 1 do
    AShard.Entries[LI].State := esEmpty;
  for LI := 0 to LOldCapacity - 1 do
  begin
    if LOldEntries[LI].State <> esOccupied then
      Continue;
    LIdx := PtrUInt(HashKey(LOldEntries[LI].Key)) and AShard.Mask;
    while AShard.Entries[LIdx].State = esOccupied do
      LIdx := (LIdx + 1) and AShard.Mask;
    AShard.Entries[LIdx] := LOldEntries[LI];
    Inc(AShard.Count);
  end;
end;

function TShardedHashMapImpl.ShardFind(const AShard: TShard; const AKey: TKey; out AIdx: PtrUInt): Boolean;
var
  LStart: PtrUInt;
begin
  LStart := PtrUInt(HashKey(AKey)) and AShard.Mask;
  AIdx := LStart;
  while AShard.Entries[AIdx].State <> esEmpty do
  begin
    if (AShard.Entries[AIdx].State = esOccupied) and (CompareByte(AShard.Entries[AIdx].Key, AKey, SizeOf(TKey)) = 0) then
      Exit(True);
    AIdx := (AIdx + 1) and AShard.Mask;
    if AIdx = LStart then
      Break;
  end;
  Result := False;
end;

constructor TShardedHashMapImpl.Create(const AInitialCapacity: PtrUInt);
var
  LI: PtrUInt;
  LCap: PtrUInt;
begin
  if IsManagedType(TKey) then
    raise EArgumentError.Create('TShardedHashMap: TKey must be unmanaged (no string/interface/dynarray)');
  if IsManagedType(TValue) then
    raise EArgumentError.Create('TShardedHashMap: TValue must be unmanaged (no string/interface/dynarray)');
  { SizeOf(TKey)=0 is not reachable for FPC specializations used here; omit to avoid
    Unreachable-code noise (audit F-007). Managed checks above remain the Create gate. }
  inherited Create;
  FClosed := 0;
  LCap := AInitialCapacity;
  if LCap < 4 then
    LCap := 4;
  LCap := LockFreeNextPow2(LCap);
  FShardCount := HASHMAP_DEFAULT_SHARD_COUNT;
  SetLength(FShards, FShardCount);
  for LI := 0 to FShardCount - 1 do
    ShardInit(FShards[LI], LCap);
end;

destructor TShardedHashMapImpl.Destroy;
var
  LI: PtrUInt;
begin
  { Failed construction leaves FShardCount=0; guard against PtrUInt underflow. }
  if FShardCount = 0 then
  begin
    inherited;
    Exit;
  end;
  Close;
  for LI := 0 to FShardCount - 1 do
    SetLength(FShards[LI].Entries, 0);
  inherited;
end;

procedure TShardedHashMapImpl.Close;
begin
  atomic_store(FClosed, 1, mo_release);
end;

function TShardedHashMapImpl.IsClosed: Boolean; inline;
begin
  Result := atomic_load(FClosed, mo_acquire) <> 0;
end;

procedure TShardedHashMapImpl.EnsureWritable(const AOp: string);
begin
  if atomic_load(FClosed, mo_acquire) <> 0 then
    raise EInvalidOperationError.Create(
      'TShardedHashMap.' + AOp + ': map is closed');
end;

procedure TShardedHashMapImpl.Insert(const AKey: TKey; const AValue: TValue);
var
  LIdx: PtrUInt;
  LShardIdx: PtrUInt;
  LFound: Boolean;
  LFoundIdx: PtrUInt;
begin
  EnsureWritable('Insert');
  LShardIdx := ShardIndex(AKey);
  ShardWriteLock(FShards[LShardIdx]);
  try
    { 标记写开始: 版本号+1 变为奇数 }
    atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
    if FShards[LShardIdx].Count * HASHMAP_LOAD_FACTOR_DEN >= FShards[LShardIdx].Capacity * HASHMAP_LOAD_FACTOR_NUM then
      ShardResize(FShards[LShardIdx]);
    LFound := ShardFind(FShards[LShardIdx], AKey, LFoundIdx);
    if LFound then
    begin
      FShards[LShardIdx].Entries[LFoundIdx].Value := AValue;
      { 标记写结束: 版本号+1 变回偶数 }
      atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
      Exit;
    end;
    LIdx := PtrUInt(HashKey(AKey)) and FShards[LShardIdx].Mask;
    while FShards[LShardIdx].Entries[LIdx].State = esOccupied do
      LIdx := (LIdx + 1) and FShards[LShardIdx].Mask;
    FShards[LShardIdx].Entries[LIdx].Key := AKey;
    FShards[LShardIdx].Entries[LIdx].Value := AValue;
    FShards[LShardIdx].Entries[LIdx].State := esOccupied;
    Inc(FShards[LShardIdx].Count);
    { 标记写结束: 版本号+1 变回偶数 }
    atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
  finally
    ShardWriteUnlock(FShards[LShardIdx]);
  end;
end;

function TShardedHashMapImpl.Find(const AKey: TKey; out AValue: TValue): Boolean;
var
  LShardIdx: PtrUInt;
  LIdx: PtrUInt;
begin
  LShardIdx := ShardIndex(AKey);
  ShardReadLock(FShards[LShardIdx]);
  try
    Result := ShardFind(FShards[LShardIdx], AKey, LIdx);
    if Result then
      AValue := FShards[LShardIdx].Entries[LIdx].Value;
  finally
    ShardReadUnlock(FShards[LShardIdx]);
  end;
end;

function TShardedHashMapImpl.Remove(const AKey: TKey): Boolean;
var
  LShardIdx: PtrUInt;
  LIdx: PtrUInt;
begin
  LShardIdx := ShardIndex(AKey);
  ShardWriteLock(FShards[LShardIdx]);
  try
    { 标记写开始: 版本号+1 变为奇数 }
    atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
    Result := ShardFind(FShards[LShardIdx], AKey, LIdx);
    if Result then
    begin
      FShards[LShardIdx].Entries[LIdx].State := esDeleted;
      FShards[LShardIdx].Entries[LIdx].Key := Default(TKey);
      FShards[LShardIdx].Entries[LIdx].Value := Default(TValue);
      Dec(FShards[LShardIdx].Count);
    end;
    { 标记写结束: 版本号+1 变回偶数 }
    atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
  finally
    ShardWriteUnlock(FShards[LShardIdx]);
  end;
end;

function TShardedHashMapImpl.Remove(const AKey: TKey; out AValue: TValue): Boolean;
var
  LShardIdx: PtrUInt;
  LIdx: PtrUInt;
begin
  LShardIdx := ShardIndex(AKey);
  ShardWriteLock(FShards[LShardIdx]);
  try
    { 标记写开始: 版本号+1 变为奇数 }
    atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
    Result := ShardFind(FShards[LShardIdx], AKey, LIdx);
    if Result then
    begin
      AValue := FShards[LShardIdx].Entries[LIdx].Value;
      FShards[LShardIdx].Entries[LIdx].State := esDeleted;
      FShards[LShardIdx].Entries[LIdx].Key := Default(TKey);
      FShards[LShardIdx].Entries[LIdx].Value := Default(TValue);
      Dec(FShards[LShardIdx].Count);
    end;
    { 标记写结束: 版本号+1 变回偶数 }
    atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
  finally
    ShardWriteUnlock(FShards[LShardIdx]);
  end;
end;

function TShardedHashMapImpl.TryInsert(const AKey: TKey; const AValue: TValue): Boolean;
var
  LShardIdx: PtrUInt;
  LIdx: PtrUInt;
  LFoundIdx: PtrUInt;
begin
  if IsClosed then
    Exit(False);
  LShardIdx := ShardIndex(AKey);
  ShardWriteLock(FShards[LShardIdx]);
  try
    { 标记写开始: 版本号+1 变为奇数 }
    atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
    if ShardFind(FShards[LShardIdx], AKey, LFoundIdx) then
    begin
      { 标记写结束: 版本号+1 变回偶数 }
      atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
      Exit(False);
    end;
    if FShards[LShardIdx].Count * HASHMAP_LOAD_FACTOR_DEN >= FShards[LShardIdx].Capacity * HASHMAP_LOAD_FACTOR_NUM then
      ShardResize(FShards[LShardIdx]);
    LIdx := PtrUInt(HashKey(AKey)) and FShards[LShardIdx].Mask;
    while FShards[LShardIdx].Entries[LIdx].State = esOccupied do
      LIdx := (LIdx + 1) and FShards[LShardIdx].Mask;
    FShards[LShardIdx].Entries[LIdx].Key := AKey;
    FShards[LShardIdx].Entries[LIdx].Value := AValue;
    FShards[LShardIdx].Entries[LIdx].State := esOccupied;
    Inc(FShards[LShardIdx].Count);
    Result := True;
    { 标记写结束: 版本号+1 变回偶数 }
    atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
  finally
    ShardWriteUnlock(FShards[LShardIdx]);
  end;
end;

function TShardedHashMapImpl.Replace(const AKey: TKey; const ANewValue: TValue; out AOldValue: TValue): Boolean;
var
  LShardIdx: PtrUInt;
  LIdx: PtrUInt;
begin
  if IsClosed then
    Exit(False);
  LShardIdx := ShardIndex(AKey);
  ShardWriteLock(FShards[LShardIdx]);
  try
    { 标记写开始: 版本号+1 变为奇数 }
    atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
    Result := ShardFind(FShards[LShardIdx], AKey, LIdx);
    if Result then
    begin
      AOldValue := FShards[LShardIdx].Entries[LIdx].Value;
      FShards[LShardIdx].Entries[LIdx].Value := ANewValue;
    end;
    { 标记写结束: 版本号+1 变回偶数 }
    atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
  finally
    ShardWriteUnlock(FShards[LShardIdx]);
  end;
end;

function TShardedHashMapImpl.Contains(const AKey: TKey): Boolean;
var
  LDummy: TValue;
begin
  Result := Find(AKey, LDummy);
end;

function TShardedHashMapImpl.Count: PtrUInt;
var
  LI: PtrUInt;
begin
  Result := 0;
  for LI := 0 to FShardCount - 1 do
  begin
    ShardReadLock(FShards[LI]);
    Inc(Result, FShards[LI].Count);
    ShardReadUnlock(FShards[LI]);
  end;
end;

procedure TShardedHashMapImpl.ForEach(const ACallback: TForEachCallback);
var
  LShardIdx: PtrUInt;
  LEntryIdx: PtrUInt;
  LKeys: array of TKey;
  LValues: array of TValue;
  LCount, LI: PtrUInt;
begin
  for LShardIdx := 0 to FShardCount - 1 do
  begin
    LCount := FShards[LShardIdx].Count;
    if LCount = 0 then
      Continue;
    SetLength(LKeys, LCount);
    SetLength(LValues, LCount);
    LCount := 0;
    ShardReadLock(FShards[LShardIdx]);
    try
      for LEntryIdx := 0 to FShards[LShardIdx].Capacity - 1 do
      begin
        if FShards[LShardIdx].Entries[LEntryIdx].State = esOccupied then
        begin
          LKeys[LCount] := FShards[LShardIdx].Entries[LEntryIdx].Key;
          LValues[LCount] := FShards[LShardIdx].Entries[LEntryIdx].Value;
          Inc(LCount);
        end;
      end;
    finally
      ShardReadUnlock(FShards[LShardIdx]);
    end;
    for LI := 0 to LCount - 1 do
      ACallback(LKeys[LI], LValues[LI]);
  end;
end;

procedure TShardedHashMapImpl.ForEachCtx(const ACallback: TForEachCtxCallback; AContext: Pointer);
var
  LShardIdx: PtrUInt;
  LEntryIdx: PtrUInt;
  LKeys: array of TKey;
  LValues: array of TValue;
  LCount, LI: PtrUInt;
begin
  for LShardIdx := 0 to FShardCount - 1 do
  begin
    LCount := FShards[LShardIdx].Count;
    if LCount = 0 then
      Continue;
    SetLength(LKeys, LCount);
    SetLength(LValues, LCount);
    LCount := 0;
    ShardReadLock(FShards[LShardIdx]);
    try
      for LEntryIdx := 0 to FShards[LShardIdx].Capacity - 1 do
      begin
        if FShards[LShardIdx].Entries[LEntryIdx].State = esOccupied then
        begin
          LKeys[LCount] := FShards[LShardIdx].Entries[LEntryIdx].Key;
          LValues[LCount] := FShards[LShardIdx].Entries[LEntryIdx].Value;
          Inc(LCount);
        end;
      end;
    finally
      ShardReadUnlock(FShards[LShardIdx]);
    end;
    for LI := 0 to LCount - 1 do
      ACallback(LKeys[LI], LValues[LI], AContext);
  end;
end;

function TShardedHashMapImpl.GetOrInsert(const AKey: TKey; const ADefault: TValue): TGetOrInsertResult;
var
  LShardIdx: PtrUInt;
  LIdx: PtrUInt;
  LFound: Boolean;
begin
  if IsClosed then
  begin
    if Find(AKey, Result.Value) then
    begin
      Result.Existed := True;
      Exit;
    end;
    raise EInvalidOperationError.Create(
      'TShardedHashMap.GetOrInsert: map is closed');
  end;
  LShardIdx := ShardIndex(AKey);
  ShardWriteLock(FShards[LShardIdx]);
  try
    { 标记写开始: 版本号+1 变为奇数 }
    atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
    LFound := ShardFind(FShards[LShardIdx], AKey, LIdx);
    if LFound then
    begin
      Result.Value := FShards[LShardIdx].Entries[LIdx].Value;
      Result.Existed := True;
      { 标记写结束: 版本号+1 变回偶数 }
      atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
      Exit;
    end;
    // Not found - insert default
    if FShards[LShardIdx].Count * HASHMAP_LOAD_FACTOR_DEN >= FShards[LShardIdx].Capacity * HASHMAP_LOAD_FACTOR_NUM then
      ShardResize(FShards[LShardIdx]);
    LIdx := PtrUInt(HashKey(AKey)) and FShards[LShardIdx].Mask;
    while FShards[LShardIdx].Entries[LIdx].State = esOccupied do
      LIdx := (LIdx + 1) and FShards[LShardIdx].Mask;
    FShards[LShardIdx].Entries[LIdx].Key := AKey;
    FShards[LShardIdx].Entries[LIdx].Value := ADefault;
    FShards[LShardIdx].Entries[LIdx].State := esOccupied;
    Inc(FShards[LShardIdx].Count);
    Result.Value := ADefault;
    Result.Existed := False;
    { 标记写结束: 版本号+1 变回偶数 }
    atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
  finally
    ShardWriteUnlock(FShards[LShardIdx]);
  end;
end;

function TShardedHashMapImpl.GetOrInsertFn(const AKey: TKey; const ACompute: TComputeCallback): TGetOrInsertResult;
var
  LShardIdx: PtrUInt;
  LIdx: PtrUInt;
  LFound: Boolean;
begin
  if IsClosed then
  begin
    if Find(AKey, Result.Value) then
    begin
      Result.Existed := True;
      Exit;
    end;
    raise EInvalidOperationError.Create(
      'TShardedHashMap.GetOrInsertFn: map is closed');
  end;
  LShardIdx := ShardIndex(AKey);
  ShardWriteLock(FShards[LShardIdx]);
  try
    { 标记写开始: 版本号+1 变为奇数 }
    atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
    LFound := ShardFind(FShards[LShardIdx], AKey, LIdx);
    if LFound then
    begin
      Result.Value := FShards[LShardIdx].Entries[LIdx].Value;
      Result.Existed := True;
      { 标记写结束: 版本号+1 变回偶数 }
      atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
      Exit;
    end;
    // Not found - compute value via callback
    if FShards[LShardIdx].Count * HASHMAP_LOAD_FACTOR_DEN >= FShards[LShardIdx].Capacity * HASHMAP_LOAD_FACTOR_NUM then
      ShardResize(FShards[LShardIdx]);
    LIdx := PtrUInt(HashKey(AKey)) and FShards[LShardIdx].Mask;
    while FShards[LShardIdx].Entries[LIdx].State = esOccupied do
      LIdx := (LIdx + 1) and FShards[LShardIdx].Mask;
    FShards[LShardIdx].Entries[LIdx].Key := AKey;
    FShards[LShardIdx].Entries[LIdx].Value := ACompute(AKey);
    FShards[LShardIdx].Entries[LIdx].State := esOccupied;
    Inc(FShards[LShardIdx].Count);
    Result.Value := FShards[LShardIdx].Entries[LIdx].Value;
    Result.Existed := False;
    { 标记写结束: 版本号+1 变回偶数 }
    atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
  finally
    ShardWriteUnlock(FShards[LShardIdx]);
  end;
end;

function TShardedHashMapImpl.GetOrUpdate(const AKey: TKey; const ADefault: TValue; const AUpdate: TUpdateCallback): TGetOrInsertResult;
var
  LShardIdx: PtrUInt;
  LIdx: PtrUInt;
  LFound: Boolean;
begin
  EnsureWritable('GetOrUpdate');
  LShardIdx := ShardIndex(AKey);
  ShardWriteLock(FShards[LShardIdx]);
  try
    { 标记写开始: 版本号+1 变为奇数 }
    atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
    LFound := ShardFind(FShards[LShardIdx], AKey, LIdx);
    if LFound then
    begin
      FShards[LShardIdx].Entries[LIdx].Value := AUpdate(FShards[LShardIdx].Entries[LIdx].Value);
      Result.Value := FShards[LShardIdx].Entries[LIdx].Value;
      Result.Existed := True;
      { 标记写结束: 版本号+1 变回偶数 }
      atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
      Exit;
    end;
    // Not found - insert default
    if FShards[LShardIdx].Count * HASHMAP_LOAD_FACTOR_DEN >= FShards[LShardIdx].Capacity * HASHMAP_LOAD_FACTOR_NUM then
      ShardResize(FShards[LShardIdx]);
    LIdx := PtrUInt(HashKey(AKey)) and FShards[LShardIdx].Mask;
    while FShards[LShardIdx].Entries[LIdx].State = esOccupied do
      LIdx := (LIdx + 1) and FShards[LShardIdx].Mask;
    FShards[LShardIdx].Entries[LIdx].Key := AKey;
    FShards[LShardIdx].Entries[LIdx].Value := ADefault;
    FShards[LShardIdx].Entries[LIdx].State := esOccupied;
    Inc(FShards[LShardIdx].Count);
    Result.Value := ADefault;
    Result.Existed := False;
    { 标记写结束: 版本号+1 变回偶数 }
    atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
  finally
    ShardWriteUnlock(FShards[LShardIdx]);
  end;
end;

procedure TShardedHashMapImpl.Clear;
var
  LShardIdx: PtrUInt;
  LEntryIdx: PtrUInt;
begin
  for LShardIdx := 0 to FShardCount - 1 do
  begin
    ShardWriteLock(FShards[LShardIdx]);
    try
      { 标记写开始: 版本号+1 变为奇数 }
      atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
      for LEntryIdx := 0 to FShards[LShardIdx].Capacity - 1 do
      begin
        FShards[LShardIdx].Entries[LEntryIdx].State := esEmpty;
        FShards[LShardIdx].Entries[LEntryIdx].Key := Default(TKey);
        FShards[LShardIdx].Entries[LEntryIdx].Value := Default(TValue);
      end;
      FShards[LShardIdx].Count := 0;
      { 标记写结束: 版本号+1 变回偶数 }
      atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
    finally
      ShardWriteUnlock(FShards[LShardIdx]);
    end;
  end;
end;

procedure TShardedHashMapImpl.Reserve(const ACount: PtrUInt);
var
  LShardIdx: PtrUInt;
  LPerShard: PtrUInt;
  LCap: PtrUInt;
  LI: PtrUInt;
  LOldEntries: array of TEntry;
  LOldCapacity: PtrUInt;
  LIdx: PtrUInt;
begin
  if ACount = 0 then
    Exit;
  EnsureWritable('Reserve');
  { 计算每个分片需要的容量: 按 load factor 反算 }
  LPerShard := (ACount + FShardCount - 1) div FShardCount;
  { 向上对齐到 2 的幂，至少 4 }
  LCap := 4;
  while LCap * HASHMAP_LOAD_FACTOR_NUM < LPerShard * HASHMAP_LOAD_FACTOR_DEN do
    LCap := LCap * 2;
  for LShardIdx := 0 to FShardCount - 1 do
  begin
    if FShards[LShardIdx].Capacity >= LCap then
      Continue; { 已经足够大 }
    ShardWriteLock(FShards[LShardIdx]);
    try
      { 标记写开始: 版本号+1 变为奇数 }
      atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
      { 二次检查: 可能已被其他线程扩容 }
      if FShards[LShardIdx].Capacity < LCap then
      begin
        { 保存旧表，重新分配 }
        LOldEntries := FShards[LShardIdx].Entries;
        LOldCapacity := FShards[LShardIdx].Capacity;
        FShards[LShardIdx].Capacity := LCap;
        FShards[LShardIdx].Mask := LCap - 1;
        SetLength(FShards[LShardIdx].Entries, LCap);
        for LI := 0 to LCap - 1 do
          FShards[LShardIdx].Entries[LI].State := esEmpty;
        { 迁移旧数据 }
        for LI := 0 to LOldCapacity - 1 do
        begin
          if LOldEntries[LI].State = esOccupied then
          begin
            LIdx := PtrUInt(HashKey(LOldEntries[LI].Key)) and FShards[LShardIdx].Mask;
            while FShards[LShardIdx].Entries[LIdx].State = esOccupied do
              LIdx := (LIdx + 1) and FShards[LShardIdx].Mask;
            FShards[LShardIdx].Entries[LIdx] := LOldEntries[LI];
          end;
        end;
      end;
      { 标记写结束: 版本号+1 变回偶数 }
      atomic_fetch_add(FShards[LShardIdx].Version, 1, mo_release);
    finally
      ShardWriteUnlock(FShards[LShardIdx]);
    end;
  end;
end;

end.
