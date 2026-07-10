program test_blockpool;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.test,
  nextpas.core.mem.error,
  nextpas.core.mem.blockpool;

var
  T: TTestSuite;
  LRunPassed: Boolean;

procedure TestBasicAcquireRelease;
var Pool: TBlockPool; P1, P2, P3: Pointer;
begin
  Pool := TBlockPool.Create(64, 10);
  try
    Check(Pool.Available = 10, 'initial available=10');
    Check(Pool.InUse = 0, 'initial inuse=0');
    P1 := Pool.Acquire;
    Check(P1 <> nil, 'acquire 1');
    Check(Pool.InUse = 1, 'inuse=1');
    P2 := Pool.Acquire;
    Check(P2 <> nil, 'acquire 2');
    Check(P2 <> P1, 'different pointers');
    P3 := Pool.Acquire;
    Check(P3 <> nil, 'acquire 3');
    Pool.Release(P2);
    Check(Pool.InUse = 2, 'inuse=2 after release');
    Pool.Release(P1);
    Pool.Release(P3);
    Check(Pool.InUse = 0, 'inuse=0 after all released');
  finally
    Pool.Free;
  end;
end;

procedure TestExhaust;
var Pool: TBlockPool; I: Integer; P: Pointer; Ok: Boolean;
begin
  Pool := TBlockPool.Create(32, 5);
  try
    for I := 1 to 5 do
    begin
      P := Pool.Acquire;
      Check(P <> nil, 'acquire ' + IntToStr(I));
    end;
    Check(Pool.Available = 0, 'exhausted');
    Ok := Pool.TryAcquire(P);
    Check(not Ok, 'TryAcquire returns false when exhausted');
    Check(P = nil, 'ptr is nil when exhausted');
  finally
    Pool.Free;
  end;
end;

procedure TestDoubleFree;
var Pool: TBlockPool; P: Pointer; LCaught: Boolean;
begin
  Pool := TBlockPool.Create(64, 4);
  try
    P := Pool.Acquire;
    Pool.Release(P);
    LCaught := False;
    try
      Pool.Release(P);
    except
      LCaught := True;
    end;
    Check(LCaught, 'double free detected');
  finally
    Pool.Free;
  end;
end;

procedure TestReset;
var Pool: TBlockPool; I: Integer; P: Pointer;
begin
  Pool := TBlockPool.Create(64, 8);
  try
    for I := 1 to 8 do
      Pool.Acquire;
    Check(Pool.Available = 0, 'all acquired');
    Pool.Reset;
    Check(Pool.Available = 8, 'all available after reset');
    Check(Pool.InUse = 0, 'inuse=0 after reset');
    P := Pool.Acquire;
    Check(P <> nil, 'can acquire after reset');
  finally
    Pool.Free;
  end;
end;

procedure TestOwns;
var Pool: TBlockPool; P: Pointer; LStack: array[0..7] of Byte;
begin
  Pool := TBlockPool.Create(64, 4);
  try
    P := Pool.Acquire;
    Check(Pool.Owns(P), 'owns acquired pointer');
    Check(not Pool.Owns(@LStack[0]), 'does not own stack pointer');
    Check(not Pool.Owns(nil), 'does not own nil');
    Pool.Release(P);
  finally
    Pool.Free;
  end;
end;

procedure TestBatchAcquireRelease;
var Pool: TBlockPool; Ptrs: array[0..9] of Pointer; N: Integer;
begin
  Pool := TBlockPool.Create(32, 10);
  try
    N := Pool.AcquireN(Ptrs, 10);
    Check(N = 10, 'acquired 10');
    Check(Pool.Available = 0, 'all used');
    Pool.ReleaseN(Ptrs, 10);
    Check(Pool.Available = 10, 'all released');
  finally
    Pool.Free;
  end;
end;

procedure TestStats;
var Pool: TBlockPool; P1, P2: Pointer;
begin
  Pool := TBlockPool.Create(64, 8);
  try
    P1 := Pool.Acquire;
    P2 := Pool.Acquire;
    Pool.Release(P1);
    P1 := Pool.Acquire;
    Check(Pool.TotalAllocs = 3, 'total allocs=3');
    Check(Pool.TotalFrees = 1, 'total frees=1');
    Check(Pool.PeakAlloc = 2, 'peak=2');
    Pool.Release(P1);
    Pool.Release(P2);
  finally
    Pool.Free;
  end;
end;

procedure TestAlignment;
var Pool: TBlockPool; P: Pointer; I: Integer;
begin
  Pool := TBlockPool.Create(48, 16, 64);
  try
    for I := 1 to 16 do
    begin
      P := Pool.Acquire;
      Check(P <> nil, 'acquire aligned');
      Check((PtrUInt(P) mod 64) = 0, 'aligned to 64');
    end;
  finally
    Pool.Free;
  end;
end;

procedure TestInvalidRelease;
var Pool: TBlockPool; LCaught: Boolean; LFake: Pointer;
begin
  Pool := TBlockPool.Create(64, 4);
  try
    GetMem(LFake, 64);
    try
      LCaught := False;
      try
        Pool.Release(LFake);
      except
        LCaught := True;
      end;
      Check(LCaught, 'invalid pointer release detected');
    finally
      FreeMem(LFake);
    end;
  finally
    Pool.Free;
  end;
end;

procedure TestRejectsTotalSizeOverflowAsInvalidLayout;
var
  Pool: TBlockPool;
  LRaised: Boolean;
  LBlockSize: SizeUInt;
begin
  Pool := nil;
  LRaised := False;
  LBlockSize := High(SizeUInt) - (High(SizeUInt) mod 16);
  try
    try
      Pool := TBlockPool.Create(LBlockSize, 2, 16);
    except
      on E: EAllocError do
      begin
        LRaised := True;
        Check(Int64(Ord(aeInvalidLayout)) = Int64(Ord(E.Error)), 'total-size overflow error');
      end;
      on E: nextpas.core.mem.error.EOutOfMemory do
      begin
        LRaised := True;
        Check(Int64(Ord(aeInvalidLayout)) = Int64(Ord(E.Error)), 'total-size overflow error');
      end;
    end;
    Check(LRaised, 'total-size overflow must fail closed');
  finally
    Pool.Free;
  end;
end;

{ R-14 regression: AcquireUnchecked increments TotalAllocs }
procedure TestAcquireUncheckedStats;
var Pool: TBlockPool; P1, P2, P3: Pointer;
begin
  Pool := TBlockPool.Create(64, 8);
  try
    P1 := Pool.AcquireUnchecked;
    P2 := Pool.AcquireUnchecked;
    P3 := Pool.AcquireUnchecked;
    Check(P1 <> nil, 'unchecked acquire 1');
    Check(P2 <> nil, 'unchecked acquire 2');
    Check(P3 <> nil, 'unchecked acquire 3');
    Check(Pool.TotalAllocs = 3, 'total allocs=3 after unchecked');
    Check(Pool.PeakAlloc = 3, 'peak=3 after unchecked');
    Pool.Release(P1);
    Pool.Release(P2);
    Pool.Release(P3);
    Check(Pool.TotalFrees = 3, 'total frees=3 after release');
  finally
    Pool.Free;
  end;
end;

{ T-05: block_size=1 — smallest possible blocks }
procedure TestBlockSizeOne;
var Pool: TBlockPool; P1, P2: Pointer;
begin
  Pool := TBlockPool.Create(1, 4);
  try
    Check(Pool.Available = 4, 'available=4');
    P1 := Pool.Acquire;
    P2 := Pool.Acquire;
    Check(P1 <> nil, 'acquire 1-byte block 1');
    Check(P2 <> nil, 'acquire 1-byte block 2');
    Check(P1 <> P2, 'distinct 1-byte blocks');
    Check(Pool.Owns(P1), 'owns 1-byte block');
    Pool.Release(P1);
    Pool.Release(P2);
  finally
    Pool.Free;
  end;
end;

{ T-05: capacity=1 — single-block pool }
procedure TestCapacityOne;
var Pool: TBlockPool; P, PDummy: Pointer; LOk: Boolean;
begin
  Pool := TBlockPool.Create(64, 1);
  try
    Check(Pool.Available = 1, 'available=1');
    P := Pool.Acquire;
    Check(P <> nil, 'acquire single block');
    Check(Pool.Available = 0, 'available=0 after acquire');
    LOk := Pool.TryAcquire(PDummy);
    Check(not LOk, 'TryAcquire fails on capacity=1 pool');
    Pool.Release(P);
    Check(Pool.Available = 1, 'available=1 after release');
  finally
    Pool.Free;
  end;
end;

{ T-05: alignment=1 — natural alignment, no padding }
procedure TestAlignmentOne;
var Pool: TBlockPool; I: Integer; P: Pointer;
begin
  Pool := TBlockPool.Create(32, 8, 1);
  try
    for I := 1 to 8 do
    begin
      P := Pool.Acquire;
      Check(P <> nil, 'acquire with align=1 ' + IntToStr(I));
      { alignment=1 means any address is valid }
      Check((PtrUInt(P) mod 1) = 0, 'trivially aligned');
    end;
    Check(Pool.Available = 0, 'all acquired');
  finally
    Pool.Free;
  end;
end;

{ T-05: block_size=1 + capacity=1 — extreme minimal }
procedure TestMinimalPool;
var Pool: TBlockPool; P: Pointer;
begin
  Pool := TBlockPool.Create(1, 1);
  try
    Check(Pool.Available = 1, 'available=1');
    P := Pool.Acquire;
    Check(P <> nil, 'acquire from minimal pool');
    Check(Pool.InUse = 1, 'inuse=1');
    Pool.Release(P);
    Check(Pool.InUse = 0, 'inuse=0 after release');
    Pool.Reset;
    Check(Pool.Available = 1, 'available after reset');
  finally
    Pool.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.blockpool');
  T.Test('basic acquire/release', @TestBasicAcquireRelease);
  T.Test('exhaust pool', @TestExhaust);
  T.Test('double free detection', @TestDoubleFree);
  T.Test('reset', @TestReset);
  T.Test('owns', @TestOwns);
  T.Test('batch acquire/release', @TestBatchAcquireRelease);
  T.Test('statistics', @TestStats);
  T.Test('alignment', @TestAlignment);
  T.Test('invalid pointer release', @TestInvalidRelease);
  T.Test('rejects total-size overflow as invalid layout', @TestRejectsTotalSizeOverflowAsInvalidLayout);
  T.Test('AcquireUnchecked stats (R-14)', @TestAcquireUncheckedStats);
  T.Test('block_size=1 boundary', @TestBlockSizeOne);
  T.Test('capacity=1 boundary', @TestCapacityOne);
  T.Test('alignment=1 (natural)', @TestAlignmentOne);
  T.Test('minimal pool (size=1, cap=1)', @TestMinimalPool);
  LRunPassed := T.Run;

  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
