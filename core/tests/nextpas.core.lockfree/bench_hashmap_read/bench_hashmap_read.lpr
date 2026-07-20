program bench_hashmap_read;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.atomic,
  nextpas.core.lockfree,
  nextpas.core.platform.thread,
  nextpas.core.platform.time,
  nextpas.core.text.conv;

type
  TIntIntMap = specialize TShardedHashMap<Integer, Integer>;

const
  NUM_READERS = 4;
  NUM_KEYS = 10000;
  OPS_PER_READER = 1000000;

var
  GMap: TIntIntMap;
  GReady: Int32;
  GStart: UInt64;
  GResults: array[0..NUM_READERS-1] of UInt64;

function ReaderThread(AArg: Pointer): Pointer; cdecl;
var
  LIdx: Integer;
  LValue: Integer;
  LOps: Int64;
begin
  LIdx := Integer(PtrUInt(AArg));
  { 等待所有线程就绪 }
  atomic_fetch_add(GReady, 1, mo_release);
  while atomic_load(GReady, mo_acquire) < NUM_READERS do
    CpuPause;
  { 执行读操作 }
  LOps := 0;
  while LOps < OPS_PER_READER do
  begin
    GMap.Find(LOps mod NUM_KEYS, LValue);
    Inc(LOps);
  end;
  GResults[LIdx] := (platform_monotonic_ns - GStart) div 1000000;
  Result := nil;
end;

procedure BenchmarkReadLockFree;
var
  LHandles: array[0..NUM_READERS-1] of TPlatformThreadHandle;
  LI: Integer;
  LTotalOps: Int64;
  LTotalTimeMs: UInt64;
  LOpsPerSec: Double;
  LRetVal: Pointer;
begin
  { 初始化 }
  GMap := TIntIntMap.Create;
  try
    { 预填充数据 }
    for LI := 0 to NUM_KEYS - 1 do
      GMap.Insert(LI, LI * 10);
    { 启动读线程 }
    GReady := 0;
    for LI := 0 to NUM_READERS - 1 do
    begin
      if platform_thread_create(LHandles[LI], @ReaderThread, Pointer(PtrUInt(LI))) <> 0 then
      begin
        WriteLn('ERROR: Failed to create thread ', LI);
        Exit;
      end;
    end;
    { 记录开始时间 }
    GStart := platform_monotonic_ns;
    { 等待所有线程完成 }
    for LI := 0 to NUM_READERS - 1 do
      platform_thread_join(LHandles[LI], LRetVal);
    { 计算结果 }
    LTotalOps := Int64(NUM_READERS) * OPS_PER_READER;
    LTotalTimeMs := 0;
    for LI := 0 to NUM_READERS - 1 do
      if GResults[LI] > LTotalTimeMs then
        LTotalTimeMs := GResults[LI];
    LOpsPerSec := LTotalOps / (LTotalTimeMs / 1000.0);
    WriteLn('=== HashMap Read Benchmark ===');
    WriteLn('Readers: ', NUM_READERS);
    WriteLn('Keys: ', NUM_KEYS);
    WriteLn('Ops/reader: ', OPS_PER_READER);
    WriteLn('Total ops: ', LTotalOps);
    WriteLn('Time: ', LTotalTimeMs, ' ms');
    WriteLn('Throughput: ', LOpsPerSec:0:0, ' ops/sec');
    WriteLn('Latency: ', (LTotalTimeMs * 1000000.0 / LTotalOps):0:2, ' ns/op');
  finally
    GMap.Free;
  end;
end;

begin
  BenchmarkReadLockFree;
end.
