unit nextpas.core.lockfree.counter.keyed;

{** @desc 按 key 隔离的有界活跃计数表（Keyed Active Counter）
  @details 每个 string key（如客户端地址/会话标识/租户）持有独立 Int64 计数，
    典型消费：per-address 并发连接数、keep-alive 会话数、租户配额占用。
    key 惰性创建，表有界（满时驱逐计数为 0 的 key——活跃 key 不受影响，
    防 key 风暴；全活跃时返回 -1，调用侧放行优先于误伤，同
    TKeyedTokenBucketLimiter 的 FindOrCreate 约定）。
    Decrement 下限 0：防御关闭通知重复/乱序（不进入负数）。
  @concurrency Thread-safe：互斥锁保护表 + 桶内算术（μs 级临界区，
    与 TKeyedTokenBucketLimiter 同构）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync;

type
  {** @desc 按 key 隔离的有界活跃计数表（线程安全）。 }
  TKeyedCounter = class
  private
    FMaxKeys: Integer;
    FLock: INativeMutex;
    FCount: Integer;
    FKeys: array of string;
    FValues: array of Int64;
    { 哈希索引：FHashes 平行于 FKeys；FBuckets 为头指针表（power-of-two, -1=空），
      FNext 为链指针（平行于 FKeys），FBucketMask = Length(FBuckets)-1。
      查找 O(1) 平均，满表 4096 时避免线性扫描 string 比对退化。 }
    FHashes: array of UInt32;
    FBuckets: array of Integer;
    FNext: array of Integer;
    FBucketMask: Integer;
    { perf: inline 零拷贝 HashString (base.FNV-1a PByte+Len 视图, 单源) }
    function HashKey(const AKey: string): UInt32; inline;
    function FindIndex(const AKey: string; const AHash: UInt32): Integer;
    procedure InsertHash(const AHash: UInt32; const AIdx: Integer); inline;
    procedure RemoveHash(const AHash: UInt32; const AIdx: Integer);
    { 线性查找已被哈希索引替代；miss 时新建（满则驱逐任一计数为 0 的 key，活跃 key 常驻；
      全活跃返回 -1，调用侧放行优先于误伤）。 }
    function FindOrCreate(const AKey: string): Integer;
  public
    { AMaxKeys：表容量上限（防 key 风暴；计数为 0 的 key 可被驱逐重建）。 }
    constructor Create(const AMaxKeys: Integer = 4096);
    destructor Destroy; override;
    { 计数 +1 并返回新值；表满且全活跃（理论难达）返回 -1（调用侧放行）。 }
    function Increment(const AKey: string): Int64;
    { 计数 -1（下限 0）并返回新值；key 不存在返回 0（防御重复关闭）。 }
    function Decrement(const AKey: string): Int64;
    { 当前计数；key 不存在返回 0（观测/测试）。 }
    function Load(const AKey: string): Int64;
    { 清空全部 key（测试/热重载）。 }
    procedure Reset;
    { 当前 key 数（观测/测试）。 }
    function KeyCount: Integer; inline;
  end;

implementation

uses
  nextpas.core.base,
  nextpas.core.bytes.ops,
  nextpas.core.errors,
  nextpas.core.lockfree.base;

{ perf: inline 零拷贝视图 HashString -> HashBytes PByte+Len, 无分配；单源 base.FNV-1a
  bytes.ops.FNV1a32 薄转发同源，不重复实现哈希逻辑。 }
function TKeyedCounter.HashKey(const AKey: string): UInt32; inline;
begin
  Result := UInt32(HashString(AKey));
end;

function TKeyedCounter.FindIndex(const AKey: string; const AHash: UInt32): Integer;
var
  LBucket, LCur: Integer;
begin
  Result := -1;
  if FCount = 0 then
    Exit;
  { bucket = hash & mask (power-of-two), O(1) 链遍历，负载因子 <=0.5 时均摊 1~2 步 }
  LBucket := Integer(AHash and UInt32(FBucketMask));
  LCur := FBuckets[LBucket];
  while LCur <> -1 do
  begin
    if (FHashes[LCur] = AHash) and (FKeys[LCur] = AKey) then
      Exit(LCur);
    LCur := FNext[LCur];
  end;
end;

procedure TKeyedCounter.InsertHash(const AHash: UInt32; const AIdx: Integer); inline;
var
  LBucket: Integer;
begin
  LBucket := Integer(AHash and UInt32(FBucketMask));
  FNext[AIdx] := FBuckets[LBucket];
  FBuckets[LBucket] := AIdx;
end;

procedure TKeyedCounter.RemoveHash(const AHash: UInt32; const AIdx: Integer);
var
  LBucket, LCur, LPrev: Integer;
begin
  LBucket := Integer(AHash and UInt32(FBucketMask));
  LCur := FBuckets[LBucket];
  LPrev := -1;
  while LCur <> -1 do
  begin
    if LCur = AIdx then
    begin
      if LPrev < 0 then
        FBuckets[LBucket] := FNext[LCur]
      else
        FNext[LPrev] := FNext[LCur];
      FNext[LCur] := -1;
      Exit;
    end;
    LPrev := LCur;
    LCur := FNext[LCur];
  end;
end;

constructor TKeyedCounter.Create(const AMaxKeys: Integer);
var
  LCap: PtrUInt;
  LI: Integer;
begin
  inherited Create;
  if AMaxKeys < 1 then
    raise EArgumentError.Create('keyed counter: max keys must be >= 1');
  FMaxKeys := AMaxKeys;
  FCount := 0;
  FLock := Mutex;
  { 哈希表容量：nextPow2(MaxKeys*2)，保证负载因子 <=0.5，O(1) 平均查找 }
  LCap := LockFreeNextPow2(PtrUInt(FMaxKeys) * 2);
  if LCap < 16 then
    LCap := 16;
  SetLength(FBuckets, Integer(LCap));
  for LI := 0 to High(FBuckets) do
    FBuckets[LI] := -1;
  FBucketMask := Integer(LCap) - 1;
end;

destructor TKeyedCounter.Destroy;
var
  LI: Integer;
begin
  { stability: 先清空哈希链再释放字符串，避免悬垂 FNext 指向已释放槽 }
  for LI := 0 to High(FBuckets) do
    FBuckets[LI] := -1;
  FKeys := nil;
  FValues := nil;
  FHashes := nil;
  FNext := nil;
  FBuckets := nil;
  FCount := 0;
  FLock := nil;
  inherited Destroy;
end;

function TKeyedCounter.FindOrCreate(const AKey: string): Integer;
var
  LEvict: Integer;
  LHash: UInt32;
  LIdx: Integer;
  LI: Integer;
  LCap: Integer;
begin
  Result := -1;
  LHash := HashKey(AKey);
  LIdx := FindIndex(AKey, LHash);
  if LIdx >= 0 then
    Exit(LIdx);
  { miss：满表时需驱逐计数为 0 的 key，活跃 key 常驻 }
  if FCount >= FMaxKeys then
  begin
    LEvict := -1;
    for LI := 0 to FCount - 1 do
      if FValues[LI] = 0 then
      begin
        LEvict := LI;
        Break;
      end;
    if LEvict < 0 then
      Exit; { 全活跃：调用侧放行优先于误伤 }
    { 驱逐旧 key：先从哈希链摘除，再复用槽位 }
    RemoveHash(FHashes[LEvict], LEvict);
    FKeys[LEvict] := AKey;
    FValues[LEvict] := 0;
    FHashes[LEvict] := LHash;
    InsertHash(LHash, LEvict);
    Result := LEvict;
  end
  else
  begin
    { perf: 指数预分配 via bytes.ops.BytesGrowCapacityInt 单源 amortized O(1),
      批量 SetLength 至容量（非 +1 线性），热点锁内少重分配；not inline per red-line 2 }
    if FCount >= Length(FKeys) then
    begin
      LCap := BytesGrowCapacityInt(Length(FKeys), FCount + 1);
      SetLength(FKeys, LCap);
      SetLength(FValues, LCap);
      SetLength(FHashes, LCap);
      SetLength(FNext, LCap);
    end;
    Result := FCount;
    FKeys[Result] := AKey;
    FValues[Result] := 0;
    FHashes[Result] := LHash;
    FNext[Result] := -1;
    InsertHash(LHash, Result);
    Inc(FCount);
  end;
end;

function TKeyedCounter.Increment(const AKey: string): Int64;
var
  LIdx: Integer;
begin
  Result := -1;
  if AKey = '' then
    Exit;
  FLock.Acquire;
  try
    LIdx := FindOrCreate(AKey);
    if LIdx < 0 then
      Exit;
    FValues[LIdx] := FValues[LIdx] + 1;
    Result := FValues[LIdx];
  finally
    FLock.Release;
  end;
end;

function TKeyedCounter.Decrement(const AKey: string): Int64;
var
  LHash: UInt32;
  LIdx: Integer;
begin
  Result := 0;
  if AKey = '' then
    Exit;
  FLock.Acquire;
  try
    { 哈希索引 O(1) 查找：key 不存在（无对应 Increment，防御重复关闭）返回 0 不创建 }
    LHash := HashKey(AKey);
    LIdx := FindIndex(AKey, LHash);
    if LIdx >= 0 then
    begin
      if FValues[LIdx] > 0 then
        FValues[LIdx] := FValues[LIdx] - 1;
      Result := FValues[LIdx];
    end;
  finally
    FLock.Release;
  end;
end;

function TKeyedCounter.Load(const AKey: string): Int64;
var
  LHash: UInt32;
  LIdx: Integer;
begin
  Result := 0;
  if AKey = '' then
    Exit;
  FLock.Acquire;
  try
    { 只读不创建：哈希索引 O(1) 观测，不得膨胀表（0 计数 key 由驱逐/Reset 回收） }
    LHash := HashKey(AKey);
    LIdx := FindIndex(AKey, LHash);
    if LIdx >= 0 then
      Result := FValues[LIdx];
  finally
    FLock.Release;
  end;
end;

procedure TKeyedCounter.Reset;
var
  LI: Integer;
begin
  FLock.Acquire;
  try
    { stability: finalize strings via nil, reset count before bucket wipe }
    FKeys := nil;
    FValues := nil;
    FHashes := nil;
    FNext := nil;
    FCount := 0;
    for LI := 0 to High(FBuckets) do
      FBuckets[LI] := -1;
  finally
    FLock.Release;
  end;
end;

function TKeyedCounter.KeyCount: Integer;
begin
  FLock.Acquire;
  try
    Result := FCount;
  finally
    FLock.Release;
  end;
end;

end.
