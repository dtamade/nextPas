program bench_hashmap_comparison;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.atomic,
  nextpas.core.lockfree,
  nextpas.core.lockfree.rtm,
  nextpas.core.lockfree.hashmap.numa,
  nextpas.core.lockfree.hashmap.rtm,
  nextpas.core.platform.thread,
  nextpas.core.platform.thread.base,
  nextpas.core.platform.time,
  nextpas.core.text.conv;

type
  TStandardMap = specialize TShardedHashMap<Integer, Integer>;

const
  NUM_READERS = 4;
  NUM_KEYS = 10000;
  OPS_PER_READER = 1000000;

var
  GReady: Int32;
  GStart: UInt64;
  GResults: array[0..NUM_READERS-1] of UInt64;
  GStandardMap: TStandardMap;
  GNumaMap: specialize TNumaShardedHashMapImpl<Integer, Integer>;
  GRtmMap: specialize TRtmHashMapImpl<Integer, Integer>;

function StandardReaderThread(AArg: Pointer): Pointer; cdecl;
var
  LIdx: Integer;
  LValue: Integer;
  LOps: Int64;
begin
  LIdx := Integer(PtrUInt(AArg));
  AtomicFetchAdd32(GReady, 1, moRelease);
  while AtomicLoad32(GReady, moAcquire) < NUM_READERS do
    CpuPause;
  LOps := 0;
  while LOps < OPS_PER_READER do
  begin
    GStandardMap.Find(LOps mod NUM_KEYS, LValue);
    Inc(LOps);
  end;
  GResults[LIdx] := (platform_monotonic_ns - GStart) div 1000000;
  Result := nil;
end;

function NumaReaderThread(AArg: Pointer): Pointer; cdecl;
var
  LIdx: Integer;
  LValue: Integer;
  LOps: Int64;
begin
  LIdx := Integer(PtrUInt(AArg));
  AtomicFetchAdd32(GReady, 1, moRelease);
  while AtomicLoad32(GReady, moAcquire) < NUM_READERS do
    CpuPause;
  LOps := 0;
  while LOps < OPS_PER_READER do
  begin
    GNumaMap.Find(LOps mod NUM_KEYS, LValue);
    Inc(LOps);
  end;
  GResults[LIdx] := (platform_monotonic_ns - GStart) div 1000000;
  Result := nil;
end;

function RtmReaderThread(AArg: Pointer): Pointer; cdecl;
var
  LIdx: Integer;
  LValue: Integer;
  LOps: Int64;
begin
  LIdx := Integer(PtrUInt(AArg));
  AtomicFetchAdd32(GReady, 1, moRelease);
  while AtomicLoad32(GReady, moAcquire) < NUM_READERS do
    CpuPause;
  LOps := 0;
  while LOps < OPS_PER_READER do
  begin
    GRtmMap.Find(LOps mod NUM_KEYS, LValue);
    Inc(LOps);
  end;
  GResults[LIdx] := (platform_monotonic_ns - GStart) div 1000000;
  Result := nil;
end;

procedure RunBenchmark(const AName: string; AReaderThread: TPlatformThreadProc);
var
  LHandles: array[0..NUM_READERS-1] of TPlatformThreadHandle;
  LI: Integer;
  LTotalOps: Int64;
  LTotalTimeMs: UInt64;
  LOpsPerSec: Double;
  LRetVal: Pointer;
begin
  GReady := 0;
  for LI := 0 to NUM_READERS - 1 do
  begin
    if platform_thread_create(LHandles[LI], AReaderThread, Pointer(PtrUInt(LI))) <> 0 then
    begin
      WriteLn('ERROR: Failed to create thread ', LI);
      Exit;
    end;
  end;
  GStart := platform_monotonic_ns;
  for LI := 0 to NUM_READERS - 1 do
    platform_thread_join(LHandles[LI], LRetVal);
  LTotalOps := Int64(NUM_READERS) * OPS_PER_READER;
  LTotalTimeMs := 0;
  for LI := 0 to NUM_READERS - 1 do
    if GResults[LI] > LTotalTimeMs then
      LTotalTimeMs := GResults[LI];
  LOpsPerSec := LTotalOps / (LTotalTimeMs / 1000.0);
  WriteLn('=== ', AName, ' ===');
  WriteLn('Readers: ', NUM_READERS);
  WriteLn('Keys: ', NUM_KEYS);
  WriteLn('Ops/reader: ', OPS_PER_READER);
  WriteLn('Total ops: ', LTotalOps);
  WriteLn('Time: ', LTotalTimeMs, ' ms');
  WriteLn('Throughput: ', LOpsPerSec:0:0, ' ops/sec');
  WriteLn('Latency: ', (LTotalTimeMs * 1000000.0 / LTotalOps):0:2, ' ns/op');
  WriteLn;
end;

var
  LI: Integer;
begin
  WriteLn('HashMap Read Performance Comparison');
  WriteLn('==================================');
  WriteLn;

  // Standard HashMap
  GStandardMap := TStandardMap.Create;
  try
    for LI := 0 to NUM_KEYS - 1 do
      GStandardMap.Insert(LI, LI * 10);
    RunBenchmark('Standard TShardedHashMap', @StandardReaderThread);
  finally
    GStandardMap.Free;
  end;

  // NUMA HashMap
  GNumaMap := specialize TNumaShardedHashMapImpl<Integer, Integer>.Create;
  try
    for LI := 0 to NUM_KEYS - 1 do
      GNumaMap.Insert(LI, LI * 10);
    RunBenchmark('NUMA TNumaShardedHashMap', @NumaReaderThread);
  finally
    GNumaMap.Free;
  end;

  // RTM HashMap
  GRtmMap := specialize TRtmHashMapImpl<Integer, Integer>.Create;
  try
    for LI := 0 to NUM_KEYS - 1 do
      GRtmMap.Insert(LI, LI * 10);
    RunBenchmark('RTM TRtmHashMap', @RtmReaderThread);
  finally
    GRtmMap.Free;
  end;

  WriteLn('=== Summary ===');
  WriteLn('RTM Supported: ', RtmIsSupported);
end.
