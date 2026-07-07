program test_lockfree_hazard;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.atomic,
  nextpas.core.lockfree.hazard,
  nextpas.core.platform.thread;
const
  HAZARD_STRESS_THREADS = 4;
  HAZARD_STRESS_OPS = 1000;
var
  T: TTestSuite;
  GReclaimCount: Int32;
  GMultiDomain: THazardDomain;
  GMultiReaderId: PtrUInt;
  GMultiReaderReady: Int32;
  GMultiRetireDone: Int32;
  GMultiReaderDone: Int32;
  GStressDomain: THazardDomain;
procedure HazardReclaimProc(const AData: Pointer; const AUserData: Pointer);
begin
  AtomicFetchAdd32(GReclaimCount, 1, moSeqCst);
end;
function StartThread(out AHandle: TPlatformThreadHandle; AProc: TPlatformThreadProc;
  AArg: Pointer; const AMessage: string): Int32;
begin
  Result := platform_thread_create(AHandle, AProc, AArg);
  CheckEqual(Int64(0), Int64(Result), AMessage + ': platform_thread_create must succeed');
end;
procedure JoinThread(const AHandle: TPlatformThreadHandle; out ARetVal: Pointer;
  const AMessage: string);
var
  LResult: Int32;
begin
  LResult := platform_thread_join(AHandle, ARetVal);
  CheckEqual(Int64(0), Int64(LResult), AMessage + ': platform_thread_join must succeed');
end;
procedure TestCreateZeroHPCount;
var
  LDomain: THazardDomain;
  LGot: Boolean;
begin
  LGot := False;
  try
    LDomain := THazardDomain.Create(0);
    LDomain.Free;
  except
    on E: EArgumentError do
      LGot := True;
  end;
  Check(LGot, 'THazardDomain.Create(0) must raise EArgumentError');
end;
procedure TestRegisterUnregister;
var
  LDomain: THazardDomain;
  LId: PtrUInt;
begin
  LDomain := THazardDomain.Create(2);
  try
    CheckEqual(Int64(0), Int64(LDomain.ActiveThreads), 'initial active threads = 0');
    LId := LDomain.RegisterThread;
    Check(LId <> 0, 'RegisterThread returns non-zero ID');
    CheckEqual(Int64(1), Int64(LDomain.ActiveThreads), 'active threads = 1 after register');
    LDomain.UnregisterThread(LId);
    CheckEqual(Int64(0), Int64(LDomain.ActiveThreads), 'active threads = 0 after unregister');
  finally
    LDomain.Free;
  end;
end;
procedure TestMultipleThreads;
var
  LDomain: THazardDomain;
  LId1, LId2, LId3: PtrUInt;
begin
  LDomain := THazardDomain.Create(2);
  try
    LId1 := LDomain.RegisterThread;
    LId2 := LDomain.RegisterThread;
    LId3 := LDomain.RegisterThread;
    CheckEqual(Int64(3), Int64(LDomain.ActiveThreads), '3 active threads');
    LDomain.UnregisterThread(LId2);
    CheckEqual(Int64(2), Int64(LDomain.ActiveThreads), '2 active after unregister middle');
    LDomain.UnregisterThread(LId1);
    LDomain.UnregisterThread(LId3);
    CheckEqual(Int64(0), Int64(LDomain.ActiveThreads), '0 active after all unregistered');
  finally
    LDomain.Free;
  end;
end;
procedure TestProtectClear;
var
  LDomain: THazardDomain;
  LId: PtrUInt;
  LResult: Pointer;
begin
  LDomain := THazardDomain.Create(2);
  try
    LId := LDomain.RegisterThread;
    LResult := LDomain.Protect(LId, 0, Pointer($DEAD));
    Check(Pointer($DEAD) = LResult, 'Protect returns the pointer');
    LDomain.Clear(LId, 0);
    LDomain.Clear(LId, 0);
    LDomain.UnregisterThread(LId);
  finally
    LDomain.Free;
  end;
end;
procedure TestProtectOutOfBounds;
var
  LDomain: THazardDomain;
  LId: PtrUInt;
  LResult: Pointer;
begin
  LDomain := THazardDomain.Create(2);
  try
    LId := LDomain.RegisterThread;
    LResult := LDomain.Protect(LId, 5, Pointer($BEEF));
    Check(Pointer($BEEF) = LResult, 'Protect with out-of-bounds index returns APtr');
    LDomain.Clear(LId, 5);
    LDomain.UnregisterThread(LId);
  finally
    LDomain.Free;
  end;
end;
procedure TestProtectNilThread;
var
  LDomain: THazardDomain;
  LResult: Pointer;
begin
  LDomain := THazardDomain.Create(2);
  try
    LResult := LDomain.Protect(0, 0, Pointer($CAFE));
    Check(Pointer($CAFE) = LResult, 'Protect with nil thread ID returns APtr');
    LDomain.Clear(0, 0);
  finally
    LDomain.Free;
  end;
end;
procedure TestRetireCollect;
var
  LDomain: THazardDomain;
  LId: PtrUInt;
begin
  LDomain := THazardDomain.Create(2);
  try
    GReclaimCount := 0;
    LDomain.Retire(Pointer(1), @HazardReclaimProc);
    LDomain.Retire(Pointer(2), @HazardReclaimProc);
    CheckEqual(Int64(2), Int64(LDomain.RetiredCount), 'retired count = 2');
    LId := LDomain.RegisterThread;
    LDomain.Collect(LId);
    LDomain.UnregisterThread(LId);
    CheckEqual(Int64(2), Int64(GReclaimCount), 'both items reclaimed');
    CheckEqual(Int64(0), Int64(LDomain.RetiredCount), 'retired count = 0 after collect');
  finally
    LDomain.Free;
  end;
end;
procedure TestRetireNilIgnored;
var
  LDomain: THazardDomain;
begin
  LDomain := THazardDomain.Create(2);
  try
    GReclaimCount := 0;
    LDomain.Retire(nil, @HazardReclaimProc);
    CheckEqual(Int64(0), Int64(LDomain.RetiredCount), 'nil retire ignored');
    CheckEqual(Int64(0), Int64(GReclaimCount), 'nil retire no reclaim');
  finally
    LDomain.Free;
  end;
end;
procedure TestCollectDefersProtected;
var
  LDomain: THazardDomain;
  LId: PtrUInt;
begin
  LDomain := THazardDomain.Create(1);
  try
    GReclaimCount := 0;
    LId := LDomain.RegisterThread;
    LDomain.Protect(LId, 0, Pointer(1));
    LDomain.Retire(Pointer(1), @HazardReclaimProc);
    LDomain.Retire(Pointer(2), @HazardReclaimProc);
    LDomain.Collect(LId);
    CheckEqual(Int64(1), Int64(GReclaimCount), 'only unprotected item reclaimed');
    CheckEqual(Int64(1), Int64(LDomain.RetiredCount), 'protected item stays retired');
    LDomain.Clear(LId, 0);
    LDomain.Collect(LId);
    CheckEqual(Int64(2), Int64(GReclaimCount), 'both items reclaimed after clear');
    CheckEqual(Int64(0), Int64(LDomain.RetiredCount), 'retired count = 0');
    LDomain.UnregisterThread(LId);
  finally
    LDomain.Free;
  end;
end;
procedure TestDestroyReclaimsAll;
var
  LDomain: THazardDomain;
begin
  GReclaimCount := 0;
  LDomain := THazardDomain.Create(2);
  LDomain.Retire(Pointer(10), @HazardReclaimProc);
  LDomain.Retire(Pointer(20), @HazardReclaimProc);
  LDomain.Retire(Pointer(30), @HazardReclaimProc);
  LDomain.Free;
  CheckEqual(Int64(3), Int64(GReclaimCount), 'Destroy reclaims all retired items');
end;
function MultiThreadReader(AArg: Pointer): Pointer; cdecl;
var
  LId: PtrUInt;
  LReads: Integer;
begin
  Result := nil;
  LId := GMultiDomain.RegisterThread;
  GMultiReaderId := LId;
  AtomicStore32(GMultiReaderReady, 1, moRelease);
  LReads := 0;
  while AtomicLoad32(GMultiRetireDone, moAcquire) = 0 do
  begin
    GMultiDomain.Protect(LId, 0, Pointer(1));
    CpuPause;
    GMultiDomain.Clear(LId, 0);
    Inc(LReads);
    if LReads and $FF = 0 then
      CpuPause;
  end;
  GMultiDomain.UnregisterThread(LId);
  AtomicStore32(GMultiReaderDone, 1, moRelease);
end;
procedure TestMultiThreadProtectRetire;
var
  LReader: TPlatformThreadHandle;
  LId: PtrUInt;
  LI: Integer;
  LSpin: Integer;
  LRetVal: Pointer;
begin
  GMultiDomain := THazardDomain.Create(1);
  try
    GReclaimCount := 0;
    GMultiReaderReady := 0;
    GMultiRetireDone := 0;
    GMultiReaderDone := 0;
    StartThread(LReader, @MultiThreadReader, nil, 'hazard reader thread');
    for LSpin := 1 to 1000 do
    begin
      if AtomicLoad32(GMultiReaderReady, moAcquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(AtomicLoad32(GMultiReaderReady, moAcquire)),
      'reader thread must register before retire');
    for LI := 1 to 1000 do
      GMultiDomain.Retire(Pointer(PtrUInt(LI)), @HazardReclaimProc);
    AtomicStore32(GMultiRetireDone, 1, moRelease);
    for LSpin := 1 to 1000 do
    begin
      if AtomicLoad32(GMultiReaderDone, moAcquire) <> 0 then
        Break;
      platform_thread_sleep_ns(1000000);
    end;
    CheckEqual(Int64(1), Int64(AtomicLoad32(GMultiReaderDone, moAcquire)),
      'reader thread must finish');
    JoinThread(LReader, LRetVal, 'hazard reader thread');
    LId := GMultiDomain.RegisterThread;
    GMultiDomain.Collect(LId);
    GMultiDomain.UnregisterThread(LId);
    Check(GReclaimCount > 0, 'some items reclaimed after reader exits');
    CheckEqual(Int64(1000), Int64(GReclaimCount), 'all 1000 items reclaimed');
  finally
    GMultiDomain.Free;
  end;
end;
procedure TestMultipleHPPerThread;
var
  LDomain: THazardDomain;
  LId: PtrUInt;
begin
  LDomain := THazardDomain.Create(4);
  try
    GReclaimCount := 0;
    LId := LDomain.RegisterThread;
    LDomain.Protect(LId, 0, Pointer(1));
    LDomain.Protect(LId, 1, Pointer(2));
    LDomain.Protect(LId, 2, Pointer(3));
    LDomain.Retire(Pointer(1), @HazardReclaimProc);
    LDomain.Retire(Pointer(2), @HazardReclaimProc);
    LDomain.Retire(Pointer(3), @HazardReclaimProc);
    LDomain.Retire(Pointer(4), @HazardReclaimProc);
    LDomain.Collect(LId);
    CheckEqual(Int64(1), Int64(GReclaimCount), 'only unprotected pointer 4 reclaimed');
    LDomain.Clear(LId, 0);
    LDomain.Clear(LId, 1);
    LDomain.Collect(LId);
    CheckEqual(Int64(3), Int64(GReclaimCount), 'pointers 1,2 reclaimed after clear');
    LDomain.Clear(LId, 2);
    LDomain.Collect(LId);
    CheckEqual(Int64(4), Int64(GReclaimCount), 'pointer 3 reclaimed after final clear');
    LDomain.UnregisterThread(LId);
  finally
    LDomain.Free;
  end;
end;
function StressRetirer(AArg: Pointer): Pointer; cdecl;
var
  LId: PtrUInt;
  LI: Integer;
begin
  Result := nil;
  LId := GStressDomain.RegisterThread;
  for LI := 1 to HAZARD_STRESS_OPS do
    GStressDomain.Retire(Pointer(PtrUInt(LI)), @HazardReclaimProc);
  GStressDomain.UnregisterThread(LId);
end;
procedure TestConcurrentRetireCollect;
var
  LHandles: array[0..HAZARD_STRESS_THREADS - 1] of TPlatformThreadHandle;
  LI: Integer;
  LRetVal: Pointer;
  LId: PtrUInt;
begin
  GStressDomain := THazardDomain.Create(2);
  try
    GReclaimCount := 0;
    for LI := 0 to HAZARD_STRESS_THREADS - 1 do
      StartThread(LHandles[LI], @StressRetirer, nil, 'hazard stress thread');
    for LI := 0 to HAZARD_STRESS_THREADS - 1 do
      JoinThread(LHandles[LI], LRetVal, 'hazard stress thread');
    LId := GStressDomain.RegisterThread;
    GStressDomain.Collect(LId);
    GStressDomain.UnregisterThread(LId);
    CheckEqual(Int64(HAZARD_STRESS_THREADS * HAZARD_STRESS_OPS),
      Int64(GReclaimCount), 'all retired items reclaimed');
  finally
    GStressDomain.Free;
  end;
end;
procedure TestHazardGuardBasic;
var
  LDomain: THazardDomain;
  LGuard: THazardGuard;
  LPtr: Pointer;
  LId: PtrUInt;
begin
  LDomain := THazardDomain.Create(2);
  try
    GReclaimCount := 0;
    LGuard := THazardGuard.Acquire(LDomain, 0);
    try
      LPtr := LGuard.Protect(Pointer($DEAD));
      Check(Pointer($DEAD) = LPtr, 'Protect returns the pointer');
      // Retire and collect - protected item should be deferred
      LDomain.Retire(Pointer($DEAD), @HazardReclaimProc);
      LDomain.Retire(Pointer($BEEF), @HazardReclaimProc);
      // Use a temp thread to Collect (Guard owns the registered thread)
      LId := LDomain.RegisterThread;
      LDomain.Collect(LId);
      LDomain.UnregisterThread(LId);
      CheckEqual(Int64(1), Int64(GReclaimCount), 'only unprotected item reclaimed');
    finally
      LGuard.Release;
    end;
    // After release, collect should reclaim the remaining item
    LId := LDomain.RegisterThread;
    LDomain.Collect(LId);
    LDomain.UnregisterThread(LId);
    CheckEqual(Int64(2), Int64(GReclaimCount), 'both items reclaimed after guard release');
  finally
    LDomain.Free;
  end;
end;
procedure TestDestroyWithActiveThreads;
var
  LDomain: THazardDomain;
  LId: PtrUInt;
begin
  GReclaimCount := 0;
  LDomain := THazardDomain.Create(2);
  LId := LDomain.RegisterThread;
  LDomain.Retire(Pointer(1), @HazardReclaimProc);
  LDomain.Retire(Pointer(2), @HazardReclaimProc);
  // Destroy with active thread - should not crash
  LDomain.Free;
  CheckEqual(Int64(2), Int64(GReclaimCount), 'Destroy reclaims all even with active thread');
end;
begin
  T := TTestSuite.Create('all13_v2');
  T.Test('Create(0) rejects', @TestCreateZeroHPCount);
  T.Test('Register/Unregister lifecycle', @TestRegisterUnregister);
  T.Test('Multiple threads register/unregister', @TestMultipleThreads);
  T.Test('Protect/Clear basic', @TestProtectClear);
  T.Test('Protect out-of-bounds index returns APtr', @TestProtectOutOfBounds);
  T.Test('Protect nil thread ID returns APtr', @TestProtectNilThread);
  T.Test('Retire + Collect basic', @TestRetireCollect);
  T.Test('Retire nil is ignored', @TestRetireNilIgnored);
  T.Test('Collect defers protected items', @TestCollectDefersProtected);
  T.Test('Destroy reclaims all retired', @TestDestroyReclaimsAll);
  T.Test('Multi-thread protect vs retire', @TestMultiThreadProtectRetire);
  T.Test('Multiple HPs per thread', @TestMultipleHPPerThread);
  T.Test('Concurrent retire+collect stress', @TestConcurrentRetireCollect);
  T.Test('THazardGuard RAII basic', @TestHazardGuardBasic);
  T.Test('Destroy with active threads', @TestDestroyWithActiveThreads);
  if not T.Run then Halt(1);
end.
