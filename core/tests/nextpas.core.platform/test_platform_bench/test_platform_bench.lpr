program test_platform_bench;

{$I nextpas.core.settings.inc}

uses nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.time.base,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.bench.runner,
  nextpas.core.platform.time,
  nextpas.core.platform.sync,
  nextpas.core.platform.memory,
  nextpas.core.platform.thread,
  nextpas.core.platform.random,
  nextpas.core.platform.path,
  nextpas.core.platform.mmap,
  nextpas.core.platform.files.base,
  nextpas.core.platform.files,
  nextpas.core.platform.fs,
  nextpas.core.platform.sync.base;

var
  T: TTestSuite;

{ Configure runner for fast benchmarks }
procedure ConfigureRunner(ARunner: TBenchRunner);
var
  LConfig: TBenchConfig;
begin
  LConfig := ARunner.GetConfig;
  LConfig.MinDurationNs := 10000000; { 10ms min }
  LConfig.MaxIterations := 100000;
  LConfig.MinSamples := 3;
  LConfig.WarmupIterations := 1;
  LConfig.EnableMemoryTracking := False;
  ARunner.SetConfig(LConfig);
end;

{ ─── Time: monotonic clock query ─── }
procedure BenchMonotonicNs(const ACtx: IBenchContext);
begin
  platform_monotonic_ns;
end;

{ ─── Sync: mutex lock/unlock ─── }
var
  GLockMutex: TPlatformMutex;

procedure BenchMutexLockUnlock(const ACtx: IBenchContext);
begin
  platform_mutex_lock(GLockMutex);
  platform_mutex_unlock(GLockMutex);
end;

{ ─── Sync: rwlock read lock/unlock ─── }
var
  GLockRwLock: TPlatformRwLock;

procedure BenchRwLockRead(const ACtx: IBenchContext);
begin
  platform_rwlock_rdlock(GLockRwLock);
  platform_rwlock_rdunlock(GLockRwLock);
end;

{ ─── Memory: aligned_alloc/free 64B ─── }
procedure BenchMemAllocFree64(const ACtx: IBenchContext);
var
  LPtr: Pointer;
begin
  LPtr := platform_aligned_alloc(64, 16);
  platform_aligned_free(LPtr);
end;

{ ─── Memory: aligned_alloc/free 4KB ─── }
procedure BenchMemAllocFree4K(const ACtx: IBenchContext);
var
  LPtr: Pointer;
begin
  LPtr := platform_aligned_alloc(4096, 4096);
  platform_aligned_free(LPtr);
end;

{ ─── Memory: secure_zero_memory 4KB ─── }
var
  GZeroBuf: array[0..4095] of Byte;

procedure BenchSecureZero4K(const ACtx: IBenchContext);
begin
  platform_secure_zero_memory(@GZeroBuf[0], 4096);
end;

{ ─── Thread: create/join ─── }
function NoopThreadProc(AArg: Pointer): Pointer; cdecl;
begin
  Result := nil;
end;

procedure BenchThreadCreateJoin(const ACtx: IBenchContext);
var
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
begin
  platform_thread_create(LHandle, @NoopThreadProc, nil);
  platform_thread_join(LHandle, LRet);
end;

{ ─── Thread: TLS get/set ─── }
var
  GTlsKey: TPlatformTLSKey;
  GTlsInited: Boolean = False;

procedure BenchTLSGetSet(const ACtx: IBenchContext);
begin
  if not GTlsInited then
  begin
    platform_tls_create(GTlsKey);
    GTlsInited := True;
  end;
  platform_tls_set(GTlsKey, Pointer(42));
  platform_tls_get(GTlsKey);
end;

{ ─── Random: 64 bytes ─── }
var
  GRandBuf: array[0..1023] of Byte;

procedure BenchRandom64(const ACtx: IBenchContext);
begin
  platform_random_bytes(@GRandBuf[0], 64);
end;

{ ─── Random: 1KB ─── }
procedure BenchRandom1K(const ACtx: IBenchContext);
begin
  platform_random_bytes(@GRandBuf[0], 1024);
end;

{ ─── Path: normalize ─── }
var
  GPathBuf: array[0..511] of AnsiChar;

procedure BenchPathNormalize(const ACtx: IBenchContext);
begin
  platform_path_normalize('/usr/local/bin/../../lib/test.so', @GPathBuf[0], 512);
end;

{ ─── Path: join ─── }
procedure BenchPathJoin(const ACtx: IBenchContext);
begin
  platform_path_join('/usr/local', 'bin/test', @GPathBuf[0], 512);
end;

{ ─── Files: open/close /dev/null ─── }
procedure BenchFileOpenClose(const ACtx: IBenchContext);
var
  LHandle: TPlatformFileHandle;
begin
  platform_file_open('/dev/null', fomReadOnly, fcmOpenExisting, LHandle);
  platform_file_close(LHandle);
end;

{ ─── Files: stat on /dev/null ─── }
var
  GStatPath: array[0..8] of AnsiChar = '/dev/null';

procedure BenchFileStat(const ACtx: IBenchContext);
var
  LStat: TPlatformFileStat;
begin
  platform_file_stat(@GStatPath[0], LStat);
end;

{ ─── Sync: condvar timedwait (zero timeout) ─── }
var
  GBenchMutex: TPlatformMutex;
  GBenchCondVar: TPlatformCondVar;

procedure BenchCondVarTimedWait(const ACtx: IBenchContext);
begin
  platform_mutex_lock(GBenchMutex);
  platform_condvar_timedwait(GBenchCondVar, GBenchMutex, 0);
  platform_mutex_unlock(GBenchMutex);
end;

{ ─── Sync: barrier wait (2 threads) ─── }
var
  GBenchBarrier: TPlatformBarrier;

function BarrierThreadProc(AArg: Pointer): Pointer; cdecl;
begin
  platform_barrier_wait(GBenchBarrier);
  Result := nil;
end;

procedure BenchBarrierWait(const ACtx: IBenchContext);
var
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
begin
  platform_thread_create(LHandle, @BarrierThreadProc, nil);
  platform_barrier_wait(GBenchBarrier);
  platform_thread_join(LHandle, LRet);
end;

{ ─── Mmap: anonymous 4KB map/unmap ─── }
procedure BenchMmapAnon4K(const ACtx: IBenchContext);
var
  LMap: TPlatformMappedFile;
begin
  if platform_mmap_create_anonymous(4096, pmaReadWrite, [pmfPrivate, pmfAnonymous], LMap) = 0 then
    platform_mmap_close(LMap);
end;

{ ─── Time: realtime clock query ─── }
procedure BenchRealtimeNs(const ACtx: IBenchContext);
begin
  platform_realtime_ns;
end;

{ ─── Individual bench tests ─── }
procedure TestBenchTime;
var
  LRunner: TBenchRunner;
  LResult: TBenchResult;
begin
  LRunner := TBenchRunner.Create;
  try
    ConfigureRunner(LRunner);
    LResult := LRunner.RunOne('time.monotonic_ns', @BenchMonotonicNs);
    Check(LResult.NsPerOp > 0, 'monotonic_ns NsPerOp > 0');
    WriteLn(Format('  %-36s %10.1f ns/op  %12.0f ops/s',
      [LResult.Name, LResult.NsPerOp, LResult.OpsPerSec]));

    LResult := LRunner.RunOne('time.realtime_ns', @BenchRealtimeNs);
    Check(LResult.NsPerOp > 0, 'realtime_ns NsPerOp > 0');
    WriteLn(Format('  %-36s %10.1f ns/op  %12.0f ops/s',
      [LResult.Name, LResult.NsPerOp, LResult.OpsPerSec]));
  finally
    LRunner.Free;
  end;
end;

procedure TestBenchSync;
var
  LRunner: TBenchRunner;
  LResult: TBenchResult;
begin
  platform_mutex_init(GLockMutex, PLATFORM_MUTEX_NORMAL);
  platform_rwlock_init(GLockRwLock);
  LRunner := TBenchRunner.Create;
  try
    ConfigureRunner(LRunner);
    LResult := LRunner.RunOne('sync.mutex_lock_unlock', @BenchMutexLockUnlock);
    Check(LResult.NsPerOp > 0, 'mutex NsPerOp > 0');
    WriteLn(Format('  %-36s %10.1f ns/op  %12.0f ops/s',
      [LResult.Name, LResult.NsPerOp, LResult.OpsPerSec]));

    LResult := LRunner.RunOne('sync.rwlock_read', @BenchRwLockRead);
    Check(LResult.NsPerOp > 0, 'rwlock NsPerOp > 0');
    WriteLn(Format('  %-36s %10.1f ns/op  %12.0f ops/s',
      [LResult.Name, LResult.NsPerOp, LResult.OpsPerSec]));
  finally
    LRunner.Free;
    platform_rwlock_destroy(GLockRwLock);
    platform_mutex_destroy(GLockMutex);
  end;
end;

procedure TestBenchMemory;
var
  LRunner: TBenchRunner;
  LResult: TBenchResult;
begin
  LRunner := TBenchRunner.Create;
  try
    ConfigureRunner(LRunner);
    LResult := LRunner.RunOne('memory.alloc_free_64B', @BenchMemAllocFree64);
    Check(LResult.NsPerOp > 0, 'alloc_64B NsPerOp > 0');
    WriteLn(Format('  %-36s %10.1f ns/op  %12.0f ops/s',
      [LResult.Name, LResult.NsPerOp, LResult.OpsPerSec]));

    LResult := LRunner.RunOne('memory.alloc_free_4KB', @BenchMemAllocFree4K);
    Check(LResult.NsPerOp > 0, 'alloc_4KB NsPerOp > 0');
    WriteLn(Format('  %-36s %10.1f ns/op  %12.0f ops/s',
      [LResult.Name, LResult.NsPerOp, LResult.OpsPerSec]));

    LResult := LRunner.RunOne('memory.secure_zero_4KB', @BenchSecureZero4K);
    Check(LResult.NsPerOp > 0, 'secure_zero NsPerOp > 0');
    WriteLn(Format('  %-36s %10.1f ns/op  %12.0f ops/s',
      [LResult.Name, LResult.NsPerOp, LResult.OpsPerSec]));
  finally
    LRunner.Free;
  end;
end;

procedure TestBenchThread;
var
  LRunner: TBenchRunner;
  LResult: TBenchResult;
begin
  LRunner := TBenchRunner.Create;
  try
    ConfigureRunner(LRunner);
    LResult := LRunner.RunOne('thread.create_join', @BenchThreadCreateJoin);
    Check(LResult.NsPerOp > 0, 'thread_create NsPerOp > 0');
    WriteLn(Format('  %-36s %10.1f ns/op  %12.0f ops/s',
      [LResult.Name, LResult.NsPerOp, LResult.OpsPerSec]));

    LResult := LRunner.RunOne('thread.tls_get_set', @BenchTLSGetSet);
    Check(LResult.NsPerOp > 0, 'tls NsPerOp > 0');
    WriteLn(Format('  %-36s %10.1f ns/op  %12.0f ops/s',
      [LResult.Name, LResult.NsPerOp, LResult.OpsPerSec]));
  finally
    LRunner.Free;
    if GTlsInited then
      platform_tls_destroy(GTlsKey);
  end;
end;

procedure TestBenchRandom;
var
  LRunner: TBenchRunner;
  LResult: TBenchResult;
begin
  LRunner := TBenchRunner.Create;
  try
    ConfigureRunner(LRunner);
    LResult := LRunner.RunOne('random.bytes_64', @BenchRandom64);
    Check(LResult.NsPerOp > 0, 'random_64 NsPerOp > 0');
    WriteLn(Format('  %-36s %10.1f ns/op  %12.0f ops/s',
      [LResult.Name, LResult.NsPerOp, LResult.OpsPerSec]));

    LResult := LRunner.RunOne('random.bytes_1KB', @BenchRandom1K);
    Check(LResult.NsPerOp > 0, 'random_1K NsPerOp > 0');
    WriteLn(Format('  %-36s %10.1f ns/op  %12.0f ops/s',
      [LResult.Name, LResult.NsPerOp, LResult.OpsPerSec]));
  finally
    LRunner.Free;
  end;
end;

procedure TestBenchPath;
var
  LRunner: TBenchRunner;
  LResult: TBenchResult;
begin
  LRunner := TBenchRunner.Create;
  try
    ConfigureRunner(LRunner);
    LResult := LRunner.RunOne('path.normalize', @BenchPathNormalize);
    Check(LResult.NsPerOp > 0, 'path_normalize NsPerOp > 0');
    WriteLn(Format('  %-36s %10.1f ns/op  %12.0f ops/s',
      [LResult.Name, LResult.NsPerOp, LResult.OpsPerSec]));

    LResult := LRunner.RunOne('path.join', @BenchPathJoin);
    Check(LResult.NsPerOp > 0, 'path_join NsPerOp > 0');
    WriteLn(Format('  %-36s %10.1f ns/op  %12.0f ops/s',
      [LResult.Name, LResult.NsPerOp, LResult.OpsPerSec]));
  finally
    LRunner.Free;
  end;
end;

procedure TestBenchMmap;
var
  LRunner: TBenchRunner;
  LResult: TBenchResult;
begin
  LRunner := TBenchRunner.Create;
  try
    ConfigureRunner(LRunner);
    LResult := LRunner.RunOne('mmap.anon_4KB', @BenchMmapAnon4K);
    Check(LResult.NsPerOp > 0, 'mmap_anon NsPerOp > 0');
    WriteLn(Format('  %-36s %10.1f ns/op  %12.0f ops/s',
      [LResult.Name, LResult.NsPerOp, LResult.OpsPerSec]));
  finally
    LRunner.Free;
  end;
end;

procedure TestBenchFiles;
var
  LRunner: TBenchRunner;
  LResult: TBenchResult;
begin
  LRunner := TBenchRunner.Create;
  try
    ConfigureRunner(LRunner);
    LResult := LRunner.RunOne('files.open_close', @BenchFileOpenClose);
    Check(LResult.NsPerOp > 0, 'files_open_close NsPerOp > 0');
    WriteLn(Format('  %-36s %10.1f ns/op  %12.0f ops/s',
      [LResult.Name, LResult.NsPerOp, LResult.OpsPerSec]));

    LResult := LRunner.RunOne('files.stat', @BenchFileStat);
    Check(LResult.NsPerOp > 0, 'files_stat NsPerOp > 0');
    WriteLn(Format('  %-36s %10.1f ns/op  %12.0f ops/s',
      [LResult.Name, LResult.NsPerOp, LResult.OpsPerSec]));
  finally
    LRunner.Free;
  end;
end;

procedure TestBenchSyncExtra;
var
  LRunner: TBenchRunner;
  LResult: TBenchResult;
begin
  platform_mutex_init(GBenchMutex, PLATFORM_MUTEX_NORMAL);
  platform_condvar_init(GBenchCondVar);
  platform_barrier_init(GBenchBarrier, 2);
  LRunner := TBenchRunner.Create;
  try
    ConfigureRunner(LRunner);
    LResult := LRunner.RunOne('sync.condvar_timedwait', @BenchCondVarTimedWait);
    Check(LResult.NsPerOp > 0, 'condvar_timedwait NsPerOp > 0');
    WriteLn(Format('  %-36s %10.1f ns/op  %12.0f ops/s',
      [LResult.Name, LResult.NsPerOp, LResult.OpsPerSec]));

    LResult := LRunner.RunOne('sync.barrier_wait', @BenchBarrierWait);
    Check(LResult.NsPerOp > 0, 'barrier_wait NsPerOp > 0');
    WriteLn(Format('  %-36s %10.1f ns/op  %12.0f ops/s',
      [LResult.Name, LResult.NsPerOp, LResult.OpsPerSec]));
  finally
    LRunner.Free;
    platform_barrier_destroy(GBenchBarrier);
    platform_condvar_destroy(GBenchCondVar);
    platform_mutex_destroy(GBenchMutex);
  end;
end;

begin
  T := TTestSuite.Create('platform_bench');
  WriteLn('=== Platform Module Benchmarks ===');
  WriteLn;
  T.Test('time', @TestBenchTime);
  T.Test('sync', @TestBenchSync);
  T.Test('memory', @TestBenchMemory);
  T.Test('thread', @TestBenchThread);
  T.Test('random', @TestBenchRandom);
  T.Test('path', @TestBenchPath);
  T.Test('mmap', @TestBenchMmap);
  T.Test('files', @TestBenchFiles);
  T.Test('sync_extra', @TestBenchSyncExtra);
  if not T.Run then
    Halt(1);
  WriteLn;
  WriteLn('=== All benchmarks completed ===');
end.
