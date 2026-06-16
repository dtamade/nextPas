program bench_platform;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.platform.time,
  nextpas.core.platform.sync,
  nextpas.core.platform.files,
  nextpas.core.platform.files.base;

const
  WARMUP_ITERS  = 1000;
  BENCH_ITERS   = 100000;

var
  GPassed, GFailed: Integer;

procedure Report(const AName: string; AIterations: Integer;
  AElapsedNs: TPlatformTimeNanoseconds);
var
  LOpsPerSec: Double;
  LNsPerOp: Double;
begin
  LNsPerOp := AElapsedNs / AIterations;
  LOpsPerSec := AIterations / (AElapsedNs / 1e9);
  WriteLn(Format('  %-40s %10.1f ns/op  %12.0f ops/s',
    [AName, LNsPerOp, LOpsPerSec]));
end;

{ --- Timer resolution benchmark --- }
procedure BenchTimerResolution;
var
  LStart, LEnd, LMin, LDiff: TPlatformTimeNanoseconds;
  I: Integer;
begin
  LMin := High(TPlatformTimeNanoseconds);
  for I := 0 to BENCH_ITERS - 1 do
  begin
    LStart := platform_monotonic_ns;
    LEnd := platform_monotonic_ns;
    LDiff := LEnd - LStart;
    if LDiff < LMin then
      LMin := LDiff;
  end;
  WriteLn('=== Timer Resolution ===');
  WriteLn(Format('  platform_monotonic_ns min delta: %d ns', [LMin]));
  WriteLn(Format('  platform_monotonic_resolution_ns: %d ns',
    [platform_monotonic_resolution_ns]));
  WriteLn;
end;

{ --- Mutex lock/unlock benchmark --- }
procedure BenchMutexThroughput;
var
  LMutex: TPlatformMutex;
  LStart, LEnd: TPlatformTimeNanoseconds;
  I: Integer;
begin
  if platform_mutex_init(LMutex, PLATFORM_MUTEX_NORMAL) <> 0 then
  begin
    WriteLn('  SKIP: mutex_init failed');
    Exit;
  end;

  { Warmup }
  for I := 0 to WARMUP_ITERS - 1 do
  begin
    platform_mutex_lock(LMutex);
    platform_mutex_unlock(LMutex);
  end;

  LStart := platform_monotonic_ns;
  for I := 0 to BENCH_ITERS - 1 do
  begin
    platform_mutex_lock(LMutex);
    platform_mutex_unlock(LMutex);
  end;
  LEnd := platform_monotonic_ns;

  WriteLn('=== Mutex Lock/Unlock ===');
  Report('pthread_mutex lock+unlock', BENCH_ITERS, LEnd - LStart);

  platform_mutex_destroy(LMutex);
  WriteLn;
end;

{ --- RwLock read benchmark --- }
procedure BenchRwLockThroughput;
var
  LRwLock: TPlatformRwLock;
  LStart, LEnd: TPlatformTimeNanoseconds;
  I: Integer;
begin
  if platform_rwlock_init(LRwLock) <> 0 then
  begin
    WriteLn('  SKIP: rwlock_init failed');
    Exit;
  end;

  { Warmup }
  for I := 0 to WARMUP_ITERS - 1 do
  begin
    platform_rwlock_rdlock(LRwLock);
    platform_rwlock_rdunlock(LRwLock);
  end;

  LStart := platform_monotonic_ns;
  for I := 0 to BENCH_ITERS - 1 do
  begin
    platform_rwlock_rdlock(LRwLock);
    platform_rwlock_rdunlock(LRwLock);
  end;
  LEnd := platform_monotonic_ns;

  WriteLn('=== RwLock Read ===');
  Report('pthread_rwlock rdlock+rdunlock', BENCH_ITERS, LEnd - LStart);

  platform_rwlock_destroy(LRwLock);
  WriteLn;
end;

{ --- File write/read benchmark --- }
procedure BenchFileIO;
const
  BUF_SIZE = 4096;
  IO_ITERS = 10000;
var
  LHandle: TPlatformFileHandle;
  LBuf: array[0..BUF_SIZE - 1] of Byte;
  LWritten, LRead: PtrUInt;
  LStart, LEnd: TPlatformTimeNanoseconds;
  I: Integer;
  LPath: AnsiString;
begin
  LPath := '/tmp/nextpas_bench_io_' + IntToStr(GetProcessId) + '.tmp';

  FillChar(LBuf, BUF_SIZE, $AA);

  { Write benchmark }
  if platform_file_open(PAnsiChar(LPath), fomWriteOnly, fcmCreateAlways, LHandle) <> 0 then
  begin
    WriteLn('  SKIP: cannot create temp file');
    Exit;
  end;

  LStart := platform_monotonic_ns;
  for I := 0 to IO_ITERS - 1 do
  begin
    platform_file_write(LHandle, @LBuf[0], BUF_SIZE, LWritten);
  end;
  LEnd := platform_monotonic_ns;

  WriteLn('=== File I/O ===');
  Report('file_write 4KB', IO_ITERS, LEnd - LStart);
  platform_file_close(LHandle);

  { Read benchmark }
  if platform_file_open(PAnsiChar(LPath), fomReadOnly, fcmOpenExisting, LHandle) <> 0 then
  begin
    WriteLn('  SKIP: cannot reopen temp file');
    Exit;
  end;

  LStart := platform_monotonic_ns;
  for I := 0 to IO_ITERS - 1 do
  begin
    platform_file_read(LHandle, @LBuf[0], BUF_SIZE, LRead);
  end;
  LEnd := platform_monotonic_ns;

  Report('file_read 4KB', IO_ITERS, LEnd - LStart);
  platform_file_close(LHandle);

  platform_file_unlink(PAnsiChar(LPath));
  WriteLn;
end;

{ --- Futex wait/wake benchmark --- }
procedure BenchFutexWaitWake;
var
  LVal: Int32;
  LStart, LEnd: TPlatformTimeNanoseconds;
  I: Integer;
  LFutexIters: Integer;
begin
  LFutexIters := 10000;

  LStart := platform_monotonic_ns;
  for I := 0 to LFutexIters - 1 do
  begin
    LVal := 0;
    platform_wake_address_one(@LVal);
  end;
  LEnd := platform_monotonic_ns;

  WriteLn('=== Futex Wake ===');
  Report('platform_wake_address_one', LFutexIters, LEnd - LStart);
  WriteLn;
end;

begin
  WriteLn('nextpas.core.platform benchmarks');
  WriteLn('================================');
  WriteLn;

  BenchTimerResolution;
  BenchMutexThroughput;
  BenchRwLockThroughput;
  BenchFileIO;
  BenchFutexWaitWake;

  WriteLn('Done.');
end.
