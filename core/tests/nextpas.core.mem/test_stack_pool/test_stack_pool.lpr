program test_stack_pool;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem.stack_pool;

var
  T: TTestRunner;

function AutoGrowPolicy: TStackPoolPolicy;
begin
  Result := TStackPoolPolicy.Default;
  Result.EnableAutoGrow := True;
  Result.GrowthFactor := 2.0;
  Result.MaxSize := 64;
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
  T.Run('auto-grow empty pool', @TestAutoGrowEmptyPool);
  T.Run('auto-grow rejects existing allocation', @TestAutoGrowRejectsExistingAllocation);
  T.Run('auto-grow rejects untracked scope allocation', @TestAutoGrowRejectsUntrackedScopeAllocation);
  T.Summary;
end.
