program test_stack_pool;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.testing,
  nextpas.core.base,
  nextpas.core.mem.stack_pool;

type
  TExceptionProc = procedure;

var
  T: TTestRunner;

procedure CheckPointerAligned(APtr: Pointer; AAlignment: SizeUInt; const AName: string);
begin
  Check(APtr <> nil, AName + ': pointer should not be nil');
  Check((PtrUInt(APtr) and (AAlignment - 1)) = 0, AName + ': pointer must honor requested alignment');
end;

procedure CheckZeroedMemory(APtr: Pointer; ASize: SizeUInt; const AName: string);
var
  LIndex: SizeUInt;
  LByte: PByte;
begin
  Check(APtr <> nil, AName + ': pointer should not be nil');
  LByte := PByte(APtr);
  for LIndex := 0 to ASize - 1 do
  begin
    CheckEqual(Int64(0), Int64(LByte^), AName + ': byte ' + IntToStr(LIndex));
    Inc(LByte);
  end;
end;

procedure CheckRaisesInvalidArgument(AProc: TExceptionProc; const AName: string);
begin
  try
    AProc;
    Fail(AName + ': expected EInvalidArgument');
  except
    on E: EInvalidArgument do
      Exit;
    on E: ECore do
      Fail(AName + ': expected EInvalidArgument, got ' + E.ClassName);
  end;
end;

function AutoGrowPolicy: TStackPoolPolicy;
begin
  Result := TStackPoolPolicy.Default;
  Result.EnableAutoGrow := True;
  Result.GrowthFactor := 2.0;
  Result.MaxSize := 64;
end;

procedure RaiseScopedAllocAlignedInvalidAlignment;
var
  LPool: TScopedStackPool;
begin
  LPool := TScopedStackPool.Create(64, TStackPoolPolicy.Default);
  try
    LPool.AllocAligned(8, 3);
  finally
    LPool.Free;
  end;
end;

procedure TestBasicAllocResetLoop;
var
  LPool: TStackPool;
  LExpectedBase: Pointer;
  LPtr: PByte;
  LRound: Integer;
begin
  LPool := TStackPool.Create(32);
  try
    Check(LPool.IsEmpty, 'new pool starts empty');
    CheckEqual(Int64(32), Int64(LPool.TotalSize), 'total size');

    LExpectedBase := nil;
    for LRound := 1 to 3 do
    begin
      LPtr := PByte(LPool.Alloc(16));
      Check(LPtr <> nil, 'alloc succeeds in reset loop');
      if LExpectedBase = nil then
        LExpectedBase := LPtr
      else
        Check(LPtr = LExpectedBase, 'reset should reuse the same first slot');

      LPtr^ := Byte($40 + LRound);
      CheckEqual(Int64($40 + LRound), Int64(LPtr^), 'allocation remains writable');
      CheckEqual(Int64(16), Int64(LPool.UsedSize), 'used size after allocation');
      CheckEqual(Int64(16), Int64(LPool.AvailableSize), 'available size after allocation');

      LPool.Reset;
      Check(LPool.IsEmpty, 'reset clears used size');
      CheckEqual(Int64(0), Int64(LPool.UsedSize), 'used size after reset');
      CheckEqual(Int64(32), Int64(LPool.AvailableSize), 'available size after reset');
    end;
  finally
    LPool.Free;
  end;
end;

procedure TestSaveRestoreNestedStates;
var
  LPool: TStackPool;
  LStateOuter: SizeUInt;
  LStateInner: SizeUInt;
  LSecond: Pointer;
  LThird: Pointer;
begin
  LPool := TStackPool.Create(64);
  try
    Check(LPool.Alloc(8) <> nil, 'prefix allocation');
    LStateOuter := LPool.SaveState;
    CheckEqual(Int64(8), Int64(LStateOuter), 'outer state matches used size');

    LSecond := LPool.Alloc(12);
    Check(LSecond <> nil, 'second allocation');
    CheckEqual(Int64(20), Int64(LPool.UsedSize), 'used size after second allocation');

    LStateInner := LPool.SaveState;
    CheckEqual(Int64(20), Int64(LStateInner), 'inner state matches used size');

    LThird := LPool.Alloc(8);
    Check(LThird <> nil, 'third allocation');
    CheckEqual(Int64(32), Int64(LPool.UsedSize), 'used size after third allocation');

    LPool.RestoreState(LStateInner);
    CheckEqual(Int64(20), Int64(LPool.UsedSize), 'restore inner state');
    Check(LPool.Alloc(8) = LThird, 'restored inner state should reuse the same aligned slot');

    LPool.RestoreState(LStateOuter);
    CheckEqual(Int64(8), Int64(LPool.UsedSize), 'restore outer state');
    Check(LPool.Alloc(12) = LSecond, 'restored outer state should reuse the same slot');
  finally
    LPool.Free;
  end;
end;

procedure TestScopedScopeLifecycle;
var
  LPool: TScopedStackPool;
  LOuterScope: TStackPoolScope;
  LInnerScope: TStackPoolScope;
begin
  LPool := TScopedStackPool.Create(64, TStackPoolPolicy.Default);
  LOuterScope := nil;
  LInnerScope := nil;
  try
    Check(LPool.ScopeManager <> nil, 'default policy should create scope manager');

    LOuterScope := LPool.CreateScope;
    Check(LOuterScope.Active, 'outer scope starts active');
    CheckEqual(Int64(1), Int64(LPool.ScopeManager.GetScopeDepth), 'outer scope depth');
    Check(LOuterScope.Alloc(16) <> nil, 'outer scope allocation');
    CheckEqual(Int64(16), Int64(LPool.UsedSize), 'used after outer alloc');

    LInnerScope := LPool.CreateScope;
    Check(LInnerScope.Active, 'inner scope starts active');
    CheckEqual(Int64(2), Int64(LPool.ScopeManager.GetScopeDepth), 'nested scope depth');
    Check(LInnerScope.Alloc(8) <> nil, 'inner scope allocation');
    CheckEqual(Int64(24), Int64(LPool.UsedSize), 'used after nested alloc');

    LInnerScope.Free;
    LInnerScope := nil;
    CheckEqual(Int64(16), Int64(LPool.UsedSize), 'freeing inner scope restores outer state');
    CheckEqual(Int64(1), Int64(LPool.ScopeManager.GetScopeDepth), 'inner scope removal updates depth');

    LOuterScope.Release;
    CheckEqual(False, LOuterScope.Active, 'manual release deactivates scope');
    CheckEqual(Int64(0), Int64(LPool.UsedSize), 'manual release restores pool state');

    LOuterScope.Free;
    LOuterScope := nil;
    CheckEqual(Int64(0), Int64(LPool.ScopeManager.GetScopeDepth), 'destroying released scope leaves manager empty');
  finally
    LInnerScope.Free;
    LOuterScope.Free;
    LPool.Free;
  end;
end;

procedure TestScopeManagerPopScopeRestoresState;
var
  LPool: TScopedStackPool;
begin
  LPool := TScopedStackPool.Create(64, TStackPoolPolicy.Default);
  try
    Check(LPool.CreateScope <> nil, 'create managed scope');
    CheckEqual(Int64(1), Int64(LPool.ScopeManager.GetScopeDepth), 'scope depth after push');
    Check(LPool.ScopeManager.GetCurrentScope <> nil, 'current scope available');
    Check(LPool.ScopeManager.GetCurrentScope.Alloc(12) <> nil, 'managed scope allocation');
    CheckEqual(Int64(12), Int64(LPool.UsedSize), 'used before pop');

    LPool.ScopeManager.PopScope;

    CheckEqual(Int64(0), Int64(LPool.ScopeManager.GetScopeDepth), 'pop should remove scope');
    CheckEqual(Int64(0), Int64(LPool.UsedSize), 'pop should restore saved state');
    Check(LPool.ScopeManager.GetCurrentScope = nil, 'no scope remains after pop');
  finally
    LPool.Free;
  end;
end;

procedure TestPushPopStateStack;
var
  LPool: TScopedStackPool;
  LSecond: Pointer;
begin
  LPool := TScopedStackPool.Create(64, TStackPoolPolicy.Default);
  try
    CheckEqual(True, LPool.PushState, 'push initial state');
    CheckEqual(Int64(1), Int64(LPool.GetStateStackDepth), 'state stack depth after first push');
    Check(LPool.Alloc(8) <> nil, 'allocation after first push');

    CheckEqual(True, LPool.PushState, 'push nested state');
    CheckEqual(Int64(2), Int64(LPool.GetStateStackDepth), 'state stack depth after second push');
    LSecond := LPool.Alloc(8);
    Check(LSecond <> nil, 'allocation after second push');
    CheckEqual(Int64(16), Int64(LPool.UsedSize), 'used size before pop');

    CheckEqual(True, LPool.PopState, 'pop nested state');
    CheckEqual(Int64(1), Int64(LPool.GetStateStackDepth), 'state stack depth after nested pop');
    CheckEqual(Int64(8), Int64(LPool.UsedSize), 'nested pop restores state');
    Check(LPool.Alloc(8) = LSecond, 'nested pop should reuse the same slot');

    CheckEqual(True, LPool.PopState, 'pop initial state');
    CheckEqual(Int64(0), Int64(LPool.GetStateStackDepth), 'state stack depth after final pop');
    CheckEqual(Int64(0), Int64(LPool.UsedSize), 'final pop restores empty state');
    CheckEqual(False, LPool.PopState, 'empty state stack returns false');
  finally
    LPool.Free;
  end;
end;

procedure TestAlignedAllocation;
var
  LPool: TStackPool;
  LPtr: Pointer;
begin
  LPool := TStackPool.Create(128);
  try
    Check(LPool.Alloc(1) <> nil, 'prefix allocation creates a misaligned offset');

    LPtr := LPool.AllocAligned(16, 16);
    CheckPointerAligned(LPtr, 16, 'AllocAligned(16)');

    CheckEqual(True, LPool.TryAllocAligned(8, LPtr, 32), 'TryAllocAligned(32) succeeds');
    CheckPointerAligned(LPtr, 32, 'TryAllocAligned(32)');

    CheckEqual(False, LPool.TryAllocAligned(8, LPtr, 3), 'TryAllocAligned rejects non power-of-two alignment');
    Check(LPtr = nil, 'invalid aligned allocation clears output pointer');
  finally
    LPool.Free;
  end;
end;

procedure TestScopedAllocAlignedRejectsInvalidAlignment;
begin
  CheckRaisesInvalidArgument(@RaiseScopedAllocAlignedInvalidAlignment,
    'TScopedStackPool.AllocAligned should reject invalid alignment');
end;

procedure TestZeroedAllocation;
var
  LPool: TScopedStackPool;
  LPtr: Pointer;
begin
  LPool := TScopedStackPool.Create(64, TStackPoolPolicy.Default);
  try
    LPtr := LPool.AllocZeroed(16);
    CheckZeroedMemory(LPtr, 16, 'first zeroed allocation');

    FillChar(LPtr^, 16, $FF);
    LPool.Reset;

    LPtr := LPool.AllocZeroed(16);
    CheckZeroedMemory(LPtr, 16, 'zeroed allocation after reset');
  finally
    LPool.Free;
  end;
end;

procedure TestCapacityFailureReturnsNil;
var
  LPool: TStackPool;
  LPtr: Pointer;
begin
  LPool := TStackPool.Create(16);
  try
    Check(LPool.Alloc(8) <> nil, 'initial allocation succeeds');

    LPtr := LPool.Alloc(9);
    Check(LPtr = nil, 'capacity exhaustion returns nil');
    CheckEqual(Int64(8), Int64(LPool.UsedSize), 'failed allocation does not advance offset');
    CheckEqual(Int64(8), Int64(LPool.AvailableSize), 'remaining capacity unchanged');
    CheckEqual(False, LPool.IsFull, 'pool is not full until an exact-fit allocation succeeds');

    CheckEqual(False, LPool.TryAlloc(9, LPtr), 'TryAlloc returns false when exhausted');
    Check(LPtr = nil, 'TryAlloc leaves output nil on failure');

    Check(LPool.Alloc(8) <> nil, 'exact-fit allocation still works after a failed request');
    Check(LPool.IsFull, 'exact-fit allocation fills the pool');
  finally
    LPool.Free;
  end;
end;

procedure TestOverflowProtection;
var
  LPool: TScopedStackPool;
  LStats: TStackPoolStatistics;
begin
  LPool := TScopedStackPool.Create(64, TStackPoolPolicy.Default);
  try
    Check(LPool.Alloc(High(SizeUInt)) = nil, 'oversized allocation returns nil');
    Check(LPool.AllocArray((High(SizeUInt) div 2) + 1, 2) = nil, 'array size overflow returns nil');
    CheckEqual(Int64(0), Int64(LPool.UsedSize), 'overflow checks must not advance offset');

    LStats := LPool.Statistics;
    CheckEqual(Int64(0), Int64(LStats.TotalAllocations), 'failed allocations do not update statistics');
    CheckEqual(Int64(0), Int64(LStats.TotalBytes), 'failed allocations do not add bytes');
  finally
    LPool.Free;
  end;
end;

procedure TestPolicyProfiles;
var
  LDefault: TStackPoolPolicy;
  LHighPerformance: TStackPoolPolicy;
  LDebug: TStackPoolPolicy;
begin
  LDefault := TStackPoolPolicy.Default;
  CheckEqual(True, LDefault.EnableStatistics, 'default policy enables statistics');
  CheckEqual(True, LDefault.EnableScopeTracking, 'default policy enables scope tracking');
  CheckEqual(False, LDefault.EnableAutoGrow, 'default policy leaves auto-grow disabled');
  CheckEqual(Int64(SizeOf(Pointer)), Int64(LDefault.DefaultAlignment), 'default policy alignment');
  CheckEqual(False, LDefault.EnableDebugMode, 'default policy debug flag');

  LHighPerformance := TStackPoolPolicy.HighPerformance;
  CheckEqual(False, LHighPerformance.EnableStatistics, 'high-performance policy disables statistics');
  CheckEqual(False, LHighPerformance.EnableScopeTracking, 'high-performance policy disables scope tracking');
  CheckEqual(False, LHighPerformance.EnableDebugMode, 'high-performance policy keeps debug disabled');

  LDebug := TStackPoolPolicy.Debug;
  CheckEqual(True, LDebug.EnableStatistics, 'debug policy keeps statistics enabled');
  CheckEqual(True, LDebug.EnableScopeTracking, 'debug policy keeps scope tracking enabled');
  CheckEqual(True, LDebug.EnableDebugMode, 'debug policy enables debug mode');
  Check(Abs(LDebug.GrowthFactor - 1.5) < 1e-6, 'debug policy uses conservative growth factor');
end;

procedure TestStatisticsCorrectness;
var
  LPool: TScopedStackPool;
  LOuterScope: TStackPoolScope;
  LInnerScope: TStackPoolScope;
  LStats: TStackPoolStatistics;
begin
  LPool := TScopedStackPool.Create(64, TStackPoolPolicy.Default);
  LOuterScope := nil;
  LInnerScope := nil;
  try
    LOuterScope := LPool.CreateScope;
    Check(LPool.Alloc(16) <> nil, 'top-level allocation');
    LInnerScope := LPool.CreateScope;
    Check(LInnerScope.Alloc(8) <> nil, 'nested scope allocation');

    LStats := LPool.Statistics;
    CheckEqual(Int64(2), Int64(LStats.TotalAllocations), 'total allocations');
    CheckEqual(Int64(24), Int64(LStats.TotalBytes), 'total bytes');
    CheckEqual(Int64(24), Int64(LStats.PeakUsage), 'peak usage');
    CheckEqual(Int64(24), Int64(LStats.CurrentUsage), 'current usage');
    CheckEqual(Int64(2), Int64(LStats.ScopeCreations), 'scope creations');
    CheckEqual(Int64(0), Int64(LStats.ScopeDestructions), 'scope destructions before teardown');
    CheckEqual(Int64(2), Int64(LStats.MaxScopeDepth), 'max scope depth');
    CheckEqual(Int64(2), Int64(LStats.CurrentScopeDepth), 'current scope depth');
    Check(Abs(LStats.FragmentationRatio - (1.0 - (24.0 / 64.0))) < 1e-9, 'fragmentation ratio reflects free space');

    LInnerScope.Free;
    LInnerScope := nil;
    LStats := LPool.Statistics;
    CheckEqual(Int64(1), Int64(LStats.ScopeDestructions), 'inner scope destruction tracked');
    CheckEqual(Int64(1), Int64(LStats.CurrentScopeDepth), 'current depth after inner free');
    CheckEqual(Int64(16), Int64(LStats.CurrentUsage), 'current usage after inner free');

    LOuterScope.Free;
    LOuterScope := nil;
    LStats := LPool.Statistics;
    CheckEqual(Int64(2), Int64(LStats.ScopeDestructions), 'outer scope destruction tracked');
    CheckEqual(Int64(0), Int64(LStats.CurrentScopeDepth), 'depth after all scopes freed');
    CheckEqual(Int64(0), Int64(LStats.CurrentUsage), 'usage after all scopes freed');

    LPool.ResetStatistics;
    LStats := LPool.Statistics;
    CheckEqual(Int64(0), Int64(LStats.TotalAllocations), 'reset statistics clears allocation count');
    CheckEqual(Int64(0), Int64(LStats.TotalBytes), 'reset statistics clears byte count');
    CheckEqual(Int64(0), Int64(LStats.PeakUsage), 'reset statistics clears peak usage');
    CheckEqual(Int64(0), Int64(LStats.ScopeCreations), 'reset statistics clears scope creations');
    CheckEqual(Int64(0), Int64(LStats.ScopeDestructions), 'reset statistics clears scope destructions');
    CheckEqual(Int64(0), Int64(LStats.MaxScopeDepth), 'reset statistics clears max scope depth');
    CheckEqual(Int64(0), Int64(LStats.CurrentScopeDepth), 'reset statistics clears current scope depth');
    CheckEqual(Int64(0), Int64(LStats.CurrentUsage), 'reset statistics clears current usage');
  finally
    LInnerScope.Free;
    LOuterScope.Free;
    LPool.Free;
  end;
end;

procedure TestAutoGrowEmptyPool;
var
  LPool: TScopedStackPool;
  LPtr: Pointer;
begin
  LPool := TScopedStackPool.Create(8, AutoGrowPolicy);
  try
    LPtr := LPool.Alloc(16);
    Check(LPtr <> nil, 'empty pool can grow for a first large allocation');
    Check(LPool.TotalSize >= 16, 'pool grew enough for the allocation');
    PByte(LPtr)^ := $A5;
    CheckEqual(Int64($A5), Int64(PByte(LPtr)^), 'grown allocation remains writable');
  finally
    LPool.Free;
  end;
end;

procedure TestAutoGrowRejectsExistingAllocation;
var
  LPool: TScopedStackPool;
  LFirst: PByte;
  LCaught: Boolean;
begin
  LPool := TScopedStackPool.Create(16, AutoGrowPolicy);
  try
    LFirst := PByte(LPool.Alloc(8));
    Check(LFirst <> nil, 'initial allocation');
    LFirst^ := $5A;

    LCaught := False;
    try
      LPool.Alloc(16);
    except
      on E: EStackPoolError do
        LCaught := True;
    end;

    Check(LCaught, 'auto-grow must reject growth while previous allocations may still be active');
    CheckEqual(Int64($5A), Int64(LFirst^), 'first allocation is still valid after rejected grow');
    CheckEqual(Int64(16), Int64(LPool.TotalSize), 'rejected grow keeps the original buffer');
  finally
    LPool.Free;
  end;
end;

procedure TestAutoGrowRejectsUntrackedScopeAllocation;
var
  LPolicy: TStackPoolPolicy;
  LPool: TScopedStackPool;
  LScope: TStackPoolScope;
  LFirst: PByte;
  LCaught: Boolean;
begin
  LPolicy := AutoGrowPolicy;
  LPolicy.EnableScopeTracking := False;
  LPool := TScopedStackPool.Create(16, LPolicy);
  LScope := nil;
  try
    LScope := LPool.CreateScope;
    LFirst := PByte(LScope.Alloc(8));
    Check(LFirst <> nil, 'scope allocation');
    LFirst^ := $C3;

    LCaught := False;
    try
      LPool.Alloc(16);
    except
      on E: EStackPoolError do
        LCaught := True;
    end;

    Check(LCaught, 'auto-grow must reject untracked active scope allocations');
    CheckEqual(Int64($C3), Int64(LFirst^), 'scope allocation is still valid after rejected grow');
    CheckEqual(Int64(16), Int64(LPool.TotalSize), 'untracked scope grow rejection keeps the original buffer');
  finally
    LScope.Free;
    LPool.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.stack_pool');
  T.Run('basic alloc + reset loop', @TestBasicAllocResetLoop);
  T.Run('save/restore nested states', @TestSaveRestoreNestedStates);
  T.Run('scoped lifecycle', @TestScopedScopeLifecycle);
  T.Run('scope manager pop scope restores state', @TestScopeManagerPopScopeRestoresState);
  T.Run('push/pop state stack', @TestPushPopStateStack);
  T.Run('aligned allocation', @TestAlignedAllocation);
  T.Run('scoped aligned allocation rejects invalid alignment', @TestScopedAllocAlignedRejectsInvalidAlignment);
  T.Run('zeroed allocation', @TestZeroedAllocation);
  T.Run('capacity failure returns nil', @TestCapacityFailureReturnsNil);
  T.Run('overflow protection', @TestOverflowProtection);
  T.Run('policy profiles', @TestPolicyProfiles);
  T.Run('statistics correctness', @TestStatisticsCorrectness);
  T.Run('auto-grow empty pool', @TestAutoGrowEmptyPool);
  T.Run('auto-grow rejects existing allocation', @TestAutoGrowRejectsExistingAllocation);
  T.Run('auto-grow rejects untracked scope allocation', @TestAutoGrowRejectsUntrackedScopeAllocation);
  T.Summary;
end.
