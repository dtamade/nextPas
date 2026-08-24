program test_lockfree_ratelimit_keyed;

{$mode objfpc}{$H+}

uses
  nextpas.core.thread.init,
  nextpas.core.lockfree.ratelimit.keyed,
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.platform.thread,
  nextpas.core.test;

var
  GNow: UInt64 = 0;
  T: TTestSuite;

function FakeNowNs: UInt64;
begin
  Result := GNow;
end;

{ ==================== 并发 smoke（真实时钟） ==================== }

const
  CONC_THREADS = 4;
  CONC_PER_THREAD = 500;
  CONC_BURST = 8;

var
  GConcLimiter: TKeyedTokenBucketLimiter;
  GConcStart: Int32 = 0;
  GConcGranted: array[0..CONC_THREADS - 1] of Int64;

function ConcWorker(AArg: Pointer): Pointer; cdecl;
var
  LIndex: PtrInt;
  LI: Integer;
  LRetry: Int64;
begin
  Result := nil;
  LIndex := PtrInt(AArg);
  while atomic_load(GConcStart, mo_acquire) = 0 do
    CpuPause;
  for LI := 1 to CONC_PER_THREAD do
    if GConcLimiter.TryAcquire('shared@x', LRetry) then
      atomic_fetch_add(GConcGranted[LIndex], 1, mo_relaxed);
end;

{ 4 线程并发打同一共享桶：总量有上界（burst + 真实 refill 容差），
  互斥下无数据竞争（heaptrc + 断言兜底）。 }
procedure TestConcurrentAcquire;
var
  LHandles: array[0..CONC_THREADS - 1] of TPlatformThreadHandle;
  LLimiter: TKeyedTokenBucketLimiter;
  LIndex: Integer;
  LRet: Pointer;
  LTotal: Int64;
begin
  LLimiter := TKeyedTokenBucketLimiter.Create(1000.0, CONC_BURST);
  GConcLimiter := LLimiter;
  GConcStart := 0;
  for LIndex := 0 to CONC_THREADS - 1 do
  begin
    GConcGranted[LIndex] := 0;
    Check(platform_thread_create(LHandles[LIndex], @ConcWorker,
      Pointer(PtrInt(LIndex))) = 0, 'create concurrent worker');
  end;
  atomic_store(GConcStart, 1, mo_release);
  for LIndex := 0 to CONC_THREADS - 1 do
    Check(platform_thread_join(LHandles[LIndex], LRet) = 0,
      'join concurrent worker');
  LTotal := 0;
  for LIndex := 0 to CONC_THREADS - 1 do
    LTotal := LTotal + GConcGranted[LIndex];
  { burst=8 + 真实时钟下 2000 次调用的 μs 级补充（rate=1000/s）容差。 }
  Check(LTotal >= 1, 'concurrent grant happened');
  Check(LTotal <= CONC_BURST + CONC_THREADS, 'total bounded by burst + slack');
  GConcLimiter := nil;
  LLimiter.Free;
end;

{ burst=2/rate=60：静止时钟前 2 次放行、第 3 次拒绝且计数。 }
procedure TestBasicBurstAndRate;
var
  LLimiter: TKeyedTokenBucketLimiter;
  LRetry: Int64;
begin
  GNow := 0;
  LLimiter := TKeyedTokenBucketLimiter.Create(60.0, 2.0, 16, @FakeNowNs);
  try
    Check(LLimiter.TryAcquire('a@x', LRetry), 'first within burst');
    CheckEqual(0, LRetry, 'allowed implies retry 0');
    Check(LLimiter.TryAcquire('a@x', LRetry), 'second within burst');
    Check(not LLimiter.TryAcquire('a@x', LRetry), 'third exceeds burst');
    Check(LRetry >= 1, 'rejected implies retry-after >= 1');
    CheckEqual(1, LLimiter.KeyCount, 'single key buckets once');
  finally
    LLimiter.Free;
  end;
end;

{ 惰性 refill：静止时钟耗尽后，推进 1 秒按速率恢复（回满 burst）。 }
procedure TestLazyRefillRecovers;
var
  LLimiter: TKeyedTokenBucketLimiter;
  LRetry: Int64;
begin
  GNow := 0;
  LLimiter := TKeyedTokenBucketLimiter.Create(60.0, 2.0, 16, @FakeNowNs);
  try
    LLimiter.TryAcquire('a@x', LRetry);
    LLimiter.TryAcquire('a@x', LRetry);
    Check(not LLimiter.TryAcquire('a@x', LRetry), 'exhausted before time passes');
    GNow := 1000000000;            { +1s → 60 tokens，回满 burst=2 }
    Check(LLimiter.TryAcquire('a@x', LRetry), 'refilled after 1s');
    Check(LLimiter.TryAcquire('a@x', LRetry), 'refill restores full burst');
    Check(not LLimiter.TryAcquire('a@x', LRetry), 'burst cap holds after refill');
  finally
    LLimiter.Free;
  end;
end;

{ 时钟回拨：Now 不越过 lastRefill 时不做任何补充（锚点不变）；前进到锚点之后恢复。 }
procedure TestClockRollbackNoPenalty;
var
  LLimiter: TKeyedTokenBucketLimiter;
  LRetry: Int64;
begin
  GNow := 0;
  LLimiter := TKeyedTokenBucketLimiter.Create(60.0, 1.0, 16, @FakeNowNs);
  try
    LLimiter.TryAcquire('a@x', LRetry);           { lastRefill=0, tokens=0 }
    GNow := 3000000000;                            { +3s → 回满 1 个 }
    Check(LLimiter.TryAcquire('a@x', LRetry), 'forward grants one');
    Check(not LLimiter.TryAcquire('a@x', LRetry), 'exhausted again');
    GNow := 2000000000;                            { 回拨 1s：Now < lastRefill(3s) }
    Check(not LLimiter.TryAcquire('a@x', LRetry),
      'rollback must not grant tokens');
    GNow := 4000000000;                            { 前进到 4s：越过 3s 锚点 }
    Check(LLimiter.TryAcquire('a@x', LRetry),
      'refill anchors to last refill time, not rollback moment');
  finally
    LLimiter.Free;
  end;
end;

{ key 隔离：不同 key 独立桶，a 耗尽不影响 b。 }
procedure TestKeyIsolation;
var
  LLimiter: TKeyedTokenBucketLimiter;
  LRetry: Int64;
begin
  GNow := 0;
  LLimiter := TKeyedTokenBucketLimiter.Create(60.0, 2.0, 16, @FakeNowNs);
  try
    Check(LLimiter.TryAcquire('a@x', LRetry), 'a first');
    Check(LLimiter.TryAcquire('b@x', LRetry), 'b independent first');
    Check(LLimiter.TryAcquire('a@x', LRetry), 'a second within burst');
    Check(not LLimiter.TryAcquire('a@x', LRetry), 'a exhausted');
    Check(LLimiter.TryAcquire('b@x', LRetry), 'b unaffected by a');
    CheckEqual(2, LLimiter.KeyCount, 'two isolated buckets');
  finally
    LLimiter.Free;
  end;
end;

{ LRU 驱逐：表满驱逐最久未「放行」key（拒绝调用不刷新 lastUsed）；
  驱逐重建即满桶。 }
procedure TestLruEviction;
var
  LLimiter: TKeyedTokenBucketLimiter;
  LRetry: Int64;
begin
  GNow := 0;
  LLimiter := TKeyedTokenBucketLimiter.Create(60.0, 1.0, 2, @FakeNowNs);
  try
    LLimiter.TryAcquire('a@x', LRetry);           { a lastUsed=0 }
    LLimiter.TryAcquire('b@x', LRetry);           { b lastUsed=0 }
    GNow := 20000000;                              { +20ms：a 补充 1.2 → 放行刷新 a lastUsed=20ms }
    Check(LLimiter.TryAcquire('a@x', LRetry), 'a refreshed by grant');
    Check(LLimiter.TryAcquire('c@x', LRetry), 'evicted slot (b) grants full burst');
    CheckEqual(2, LLimiter.KeyCount, 'table stays bounded');
    Check(LLimiter.TryAcquire('b@x', LRetry), 'evicted key rebuilt as full bucket');
    Check(not LLimiter.TryAcquire('b@x', LRetry), 'rebuilt bucket still honors burst');
  finally
    LLimiter.Free;
  end;
end;

{ 空 key 恒放行且不建桶、不计费。 }
procedure TestEmptyKeyAlwaysAllowed;
var
  LLimiter: TKeyedTokenBucketLimiter;
  LRetry: Int64;
begin
  GNow := 0;
  LLimiter := TKeyedTokenBucketLimiter.Create(60.0, 1.0, 16, @FakeNowNs);
  try
    Check(LLimiter.TryAcquire('', LRetry), 'empty key allowed');
    Check(LLimiter.TryAcquire('', LRetry), 'empty key always allowed');
    CheckEqual(0, LLimiter.KeyCount, 'empty key never creates a bucket');
  finally
    LLimiter.Free;
  end;
end;

{ Retry-After 精度：rate=0.25/s 且桶空 → 等 1 令牌需 4 秒。 }
procedure TestRetryAfterSeconds;
var
  LLimiter: TKeyedTokenBucketLimiter;
  LRetry: Int64;
begin
  GNow := 0;
  LLimiter := TKeyedTokenBucketLimiter.Create(0.25, 1.0, 16, @FakeNowNs);
  try
    LLimiter.TryAcquire('a@x', LRetry);
    Check(not LLimiter.TryAcquire('a@x', LRetry), 'empty bucket rejects');
    CheckEqual(4, LRetry, 'retry-after = ceil(1/0.25)');
  finally
    LLimiter.Free;
  end;
end;

{ 构造校验：rate/burst 非正或 maxKeys<1 抛 EArgumentError。 }
procedure TestConstructorValidation;
var
  LLimiter: TKeyedTokenBucketLimiter;
begin
  LLimiter := nil;
  try
    try
      LLimiter := TKeyedTokenBucketLimiter.Create(0, 1.0);
      Check(False, 'rate=0 must raise');
    except
      on E: EArgumentError do ;
    end;
    try
      LLimiter := TKeyedTokenBucketLimiter.Create(1.0, -1.0);
      Check(False, 'burst<0 must raise');
    except
      on E: EArgumentError do ;
    end;
    try
      LLimiter := TKeyedTokenBucketLimiter.Create(1.0, 1.0, 0);
      Check(False, 'maxKeys<1 must raise');
    except
      on E: EArgumentError do ;
    end;
  finally
    LLimiter.Free;
  end;
end;

{ Reset 清空全部桶（计数归零、存量桶重建满）。 }
procedure TestReset;
var
  LLimiter: TKeyedTokenBucketLimiter;
  LRetry: Int64;
begin
  GNow := 0;
  LLimiter := TKeyedTokenBucketLimiter.Create(60.0, 1.0, 16, @FakeNowNs);
  try
    LLimiter.TryAcquire('a@x', LRetry);
    LLimiter.TryAcquire('b@x', LRetry);
    CheckEqual(2, LLimiter.KeyCount, 'two buckets before reset');
    LLimiter.Reset;
    CheckEqual(0, LLimiter.KeyCount, 'reset empties table');
    Check(LLimiter.TryAcquire('a@x', LRetry), 'rebuilt bucket grants full burst');
  finally
    LLimiter.Free;
  end;
end;

{ 冷却窗（F-11）：cooldown=3s——burst 耗尽拒绝后进入冷却；
  +1s（令牌本已恢复）仍拒且 Retry-After=剩余冷却；+3s 期满恢复放行。 }
procedure TestCooldownForcesFullWait;
var
  LLimiter: TKeyedTokenBucketLimiter;
  LRetry: Int64;
begin
  GNow := 0;
  LLimiter := TKeyedTokenBucketLimiter.Create(60.0, 1.0, 16, @FakeNowNs, 3);
  try
    Check(LLimiter.TryAcquire('a@x', LRetry), 'first granted');
    Check(not LLimiter.TryAcquire('a@x', LRetry), 'second denied (empty)');
    CheckEqual(3, LRetry, 'deny retry-after = cooldown');
    GNow := 1000000000;            { +1s：令牌已回满但冷却未满 }
    Check(not LLimiter.TryAcquire('a@x', LRetry),
      'cooldown blocks despite refilled tokens');
    CheckEqual(2, LRetry, 'retry-after = remaining cooldown');
    GNow := 3000000000;            { 恰好期满 }
    Check(LLimiter.TryAcquire('a@x', LRetry), 'granted after cooldown elapses');
    { 期满后令牌恢复照常：+1s 回满（rate=60 → burst 上限）。 }
    GNow := 4000000000;
    Check(LLimiter.TryAcquire('a@x', LRetry), 'refill continues after expiry');
  finally
    LLimiter.Free;
  end;
end;

{ 默认 cooldown=0 向后兼容：拒绝后令牌恢复即可再取，无冷却强制。 }
procedure TestNoCooldownByDefault;
var
  LLimiter: TKeyedTokenBucketLimiter;
  LRetry: Int64;
begin
  GNow := 0;
  LLimiter := TKeyedTokenBucketLimiter.Create(60.0, 1.0, 16, @FakeNowNs);
  try
    Check(LLimiter.TryAcquire('a@x', LRetry), 'first granted');
    Check(not LLimiter.TryAcquire('a@x', LRetry), 'denied when empty');
    GNow := 1000000000;            { +1s：令牌恢复即放行 }
    Check(LLimiter.TryAcquire('a@x', LRetry),
      'no forced wait without cooldown');
  finally
    LLimiter.Free;
  end;
end;

{ 冷却独立于 key 隔离：a 在冷却期不影响 b 的全新桶。 }
procedure TestCooldownPerKey;
var
  LLimiter: TKeyedTokenBucketLimiter;
  LRetry: Int64;
begin
  GNow := 0;
  LLimiter := TKeyedTokenBucketLimiter.Create(60.0, 1.0, 16, @FakeNowNs, 5);
  try
    Check(LLimiter.TryAcquire('a@x', LRetry), 'a first granted');
    Check(not LLimiter.TryAcquire('a@x', LRetry), 'a denied, cooling');
    Check(LLimiter.TryAcquire('b@x', LRetry), 'b unaffected by a cooldown');
  finally
    LLimiter.Free;
  end;
end;

{ 负冷却参数构造拒绝。 }
procedure TestNegativeCooldownRejected;
var
  LLimiter: TKeyedTokenBucketLimiter;
begin
  LLimiter := nil;
  try
    try
      LLimiter := TKeyedTokenBucketLimiter.Create(1.0, 1.0, 16, nil, -1);
      Check(False, 'cooldown<0 must raise');
    except
      on E: EArgumentError do ;
    end;
  finally
    LLimiter.Free;
  end;
end;

begin
  GNow := 0;
  T := TTestSuite.Create('keyed token bucket rate limiter');
  T.Test('burst then reject, retry-after', @TestBasicBurstAndRate);
  T.Test('lazy refill recovers by rate', @TestLazyRefillRecovers);
  T.Test('clock rollback grants nothing', @TestClockRollbackNoPenalty);
  T.Test('keys are isolated buckets', @TestKeyIsolation);
  T.Test('LRU eviction rebuilds full', @TestLruEviction);
  T.Test('empty key always allowed', @TestEmptyKeyAlwaysAllowed);
  T.Test('retry-after precision', @TestRetryAfterSeconds);
  T.Test('constructor validation', @TestConstructorValidation);
  T.Test('reset empties table', @TestReset);
  T.Test('cooldown forces full wait', @TestCooldownForcesFullWait);
  T.Test('no cooldown by default', @TestNoCooldownByDefault);
  T.Test('cooldown is per key', @TestCooldownPerKey);
  T.Test('negative cooldown rejected', @TestNegativeCooldownRejected);
  T.Test('concurrent acquire stays bounded', @TestConcurrentAcquire);
  if not T.Run then Halt(1);
end.