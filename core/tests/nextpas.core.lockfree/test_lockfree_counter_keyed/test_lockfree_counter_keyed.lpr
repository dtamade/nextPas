program test_lockfree_counter_keyed;

{$mode objfpc}{$H+}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.lockfree.counter.keyed,
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.platform.thread,
  nextpas.core.test;

{ ==================== 并发 smoke（真实时钟） ==================== }

const
  CONC_THREADS = 4;
  CONC_PER_THREAD = 500;

var
  GCounter: TKeyedCounter;
  GConcStart: Int32 = 0;

function ConcWorker(AArg: Pointer): Pointer; cdecl;
var
  LIndex: PtrInt;
  LI: Integer;
begin
  Result := nil;
  LIndex := PtrInt(AArg);
  while atomic_load(GConcStart, mo_acquire) = 0 do
    CpuPause;
  { 每线程独占 key + 每线程 100 次共享 key：总增量 = 线程数 * 500 }
  for LI := 1 to CONC_PER_THREAD do
  begin
    GCounter.Increment('t' + IntToStr(LIndex));
    if LI <= 100 then
      GCounter.Increment('shared');
  end;
end;

procedure TestConcurrent;
var
  LHandles: array[0..CONC_THREADS - 1] of TPlatformThreadHandle;
  LIndex: Integer;
  LRet: Pointer;
begin
  GCounter := TKeyedCounter.Create(128);
  for LIndex := 0 to CONC_THREADS - 1 do
    platform_thread_create(LHandles[LIndex], @ConcWorker, Pointer(PtrInt(LIndex)));
  atomic_store(GConcStart, 1, mo_release);
  for LIndex := 0 to CONC_THREADS - 1 do
    platform_thread_join(LHandles[LIndex], LRet);
  CheckEqual(CONC_PER_THREAD, GCounter.Load('t0'), 'thread 0 count');
  CheckEqual(CONC_PER_THREAD, GCounter.Load('t3'), 'thread 3 count');
  CheckEqual(CONC_THREADS * 100, GCounter.Load('shared'), 'shared count');
  GCounter.Free;
end;

{ ==================== 语义 ==================== }

procedure TestBasic;
var
  C: TKeyedCounter;
begin
  C := TKeyedCounter.Create(16);
  CheckEqual(1, C.Increment('a@x'), 'first inc -> 1');
  CheckEqual(2, C.Increment('a@x'), 'second inc -> 2');
  CheckEqual(1, C.Decrement('a@x'), 'dec -> 1');
  CheckEqual(0, C.Decrement('a@x'), 'dec -> 0');
  CheckEqual(0, C.Decrement('a@x'), 'dec floor at 0 (repeat close)');
  CheckEqual(0, C.Decrement('missing@x'), 'dec missing key -> 0, no create');
  CheckEqual(0, C.Load('missing@x'), 'load missing key -> 0, no create');
  CheckEqual(1, C.KeyCount, 'only a@x exists (no phantom keys)');
  C.Increment('b@x');
  CheckEqual(2, C.KeyCount, 'two keys');
  C.Reset;
  CheckEqual(0, C.KeyCount, 'reset clears');
  CheckEqual(1, C.Increment('b@x'), 'inc after reset');
  C.Free;
end;

procedure TestMaxKeysEvict;
var
  C: TKeyedCounter;
begin
  C := TKeyedCounter.Create(2);
  CheckEqual(1, C.Increment('a'), 'a -> 1');
  CheckEqual(1, C.Increment('b'), 'b -> 1');
  { 表满且全活跃: 新 key 放行不计数(调用侧约定, 防误伤) }
  CheckEqual(-1, C.Increment('c'), 'full+all-active -> -1 (allow)');
  CheckEqual(2, C.KeyCount, 'table still 2 keys');
  { a 计数归零后, c 可驱逐 a 重建 }
  C.Decrement('a');
  CheckEqual(1, C.Increment('c'), 'evict zero-count key, c -> 1');
  CheckEqual(0, C.Load('a'), 'a evicted (count 0)');
  CheckEqual(1, C.Load('b'), 'active b survives');
  C.Free;
end;

var
  T: TTestSuite;

begin
  T := TTestSuite.Create('nextpas.core.lockfree.counter.keyed');
  T.Test('Concurrent', @TestConcurrent);
  T.Test('Basic', @TestBasic);
  T.Test('MaxKeysEvict', @TestMaxKeysEvict);
  if not T.Run then
    Halt(1);
end.
