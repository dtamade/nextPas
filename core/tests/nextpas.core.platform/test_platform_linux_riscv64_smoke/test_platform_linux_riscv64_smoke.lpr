program test_platform_linux_riscv64_smoke;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.platform.time,
  nextpas.core.platform.memory,
  nextpas.core.platform.thread,
  nextpas.core.platform.sync;

var
  Passed, Failed: Integer;

  procedure Pass(const AName: string);
  begin
    Inc(Passed);
    WriteLn('  PASS: ', AName);
  end;

  procedure Fail(const AName, AMsg: string);
  begin
    Inc(Failed);
    WriteLn('  FAIL: ', AName, ' - ', AMsg);
  end;

  procedure Check(const AName: string; ACond: Boolean; const AMsg: string);
  begin
    if ACond then Pass(AName) else Fail(AName, AMsg);
  end;

  procedure BusyWaitNs(const ATargetNs: UInt64);
  var
    Start: TPlatformTimeNanoseconds;
  begin
    Start := platform_monotonic_ns;
    while platform_monotonic_ns - Start < ATargetNs do
      platform_thread_yield;
  end;

  { Time smoke tests }
  procedure TestTimeMonotonic;
  var
    T1, T2: TPlatformTimeNanoseconds;
  begin
    T1 := platform_monotonic_ns;
    T2 := platform_monotonic_ns;
    Check('platform_monotonic_ns non-decreasing', T2 >= T1,
      Format('T1=%d T2=%d', [T1, T2]));
  end;

  procedure TestTimeRealtime;
  var
    T: TPlatformTimeNanoseconds;
  begin
    T := platform_realtime_ns;
    Check('platform_realtime_ns returns value', T > 0,
      Format('T=%d', [T]));
  end;

  procedure TestTimeResolution;
  var
    R: TPlatformTimeNanoseconds;
  begin
    R := platform_monotonic_resolution_ns;
    Check('platform_monotonic_resolution_ns returns value', R > 0,
      Format('R=%d', [R]));
  end;

  { Memory smoke tests }
  procedure TestMemoryAlloc;
  var
    P: Pointer;
  begin
    P := platform_aligned_alloc(1024, 16);
    Check('platform_aligned_alloc(1024,16) non-nil', P <> nil, 'nil pointer');
    if P <> nil then
    begin
      platform_aligned_free(P);
      Pass('platform_aligned_free works');
    end;
  end;

  procedure TestMemoryZero;
  var
    Buf: array[0..15] of Byte;
    I: Integer;
    AllZero: Boolean;
  begin
    FillChar(Buf, SizeOf(Buf), $FF);
    platform_secure_zero_memory(@Buf[0], SizeOf(Buf));
    AllZero := True;
    for I := 0 to High(Buf) do
      if Buf[I] <> 0 then
      begin
        AllZero := False;
        Break;
      end;
    Check('platform_secure_zero_memory zeroes 16 bytes', AllZero, 'non-zero byte found');
  end;

  { Sync smoke tests }
  procedure TestMutexBasic;
  var
    M: TPlatformMutex;
  begin
    Check('platform_mutex_init succeeds', platform_mutex_init(M) = 0,
      'mutex init failed');
    Check('platform_mutex_lock succeeds', platform_mutex_lock(M) = 0,
      'lock failed');
    Check('platform_mutex_unlock succeeds', platform_mutex_unlock(M) = 0,
      'unlock failed');
    Check('platform_mutex_destroy succeeds', platform_mutex_destroy(M) = 0,
      'destroy failed');
  end;

  procedure TestRwlockBasic;
  var
    R: TPlatformRwLock;
  begin
    Check('platform_rwlock_init succeeds', platform_rwlock_init(R) = 0,
      'rwlock init failed');
    Check('platform_rwlock_rdlock succeeds', platform_rwlock_rdlock(R) = 0,
      'rdlock failed');
    Check('platform_rwlock_rdunlock succeeds', platform_rwlock_rdunlock(R) = 0,
      'rdunlock failed');
    Check('platform_rwlock_wrlock succeeds', platform_rwlock_wrlock(R) = 0,
      'wrlock failed');
    Check('platform_rwlock_wrunlock succeeds', platform_rwlock_wrunlock(R) = 0,
      'wrunlock failed');
    Check('platform_rwlock_destroy succeeds', platform_rwlock_destroy(R) = 0,
      'destroy failed');
  end;

  { Thread smoke tests }
  procedure TestThreadYield;
  begin
    platform_thread_yield;
    Pass('platform_thread_yield succeeds');
  end;

  procedure TestThreadSelf;
  begin
    Check('platform_thread_id returns value', platform_thread_id > 0,
      Format('id=%d', [platform_thread_id]));
  end;

begin
  Passed := 0;
  Failed := 0;

  WriteLn('=== platform.time smoke ===');
  TestTimeMonotonic;
  TestTimeRealtime;
  TestTimeResolution;

  WriteLn('=== platform.memory smoke ===');
  TestMemoryAlloc;
  TestMemoryZero;

  WriteLn('=== platform.sync smoke ===');
  TestMutexBasic;
  TestRwlockBasic;

  WriteLn('=== platform.thread smoke ===');
  TestThreadYield;
  TestThreadSelf;

  WriteLn;
  WriteLn('Results: ', Passed, ' passed, ', Failed, ' failed');
  if Failed > 0 then
    Halt(1);
end.
