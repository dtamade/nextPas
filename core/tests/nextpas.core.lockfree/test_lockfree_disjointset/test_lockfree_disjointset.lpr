program test_lockfree_disjointset;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.platform.thread,
  nextpas.core.text.conv,
  nextpas.core.atomic,
  nextpas.core.lockfree.disjointset;

var
  GTests, GPassed: Integer;

type
  PUnionCtx = ^TUnionCtx;
  TUnionCtx = record
    DisjointSet: TLockFreeDisjointSet;
    PairCount: Int32;
    Reverse: Boolean;
    Ready, Start, Done: PInt32;
    Results: array of TLockFreeDisjointSetResult;
  end;

procedure InitUnionCtx(out ACtx: TUnionCtx; ASet: TLockFreeDisjointSet;
  APairCount: Int32; AReverse: Boolean; AReady, AStart, ADone: PInt32);
begin
  ACtx.DisjointSet := ASet;
  ACtx.PairCount := APairCount;
  ACtx.Reverse := AReverse;
  ACtx.Ready := AReady;
  ACtx.Start := AStart;
  ACtx.Done := ADone;
  SetLength(ACtx.Results, APairCount);
end;

function UnionProc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PUnionCtx;
  LI, LLeft, LRight: Int32;
begin
  LCtx := PUnionCtx(AArg);
  for LI := 0 to LCtx^.PairCount - 1 do
  begin
    atomic_fetch_add(LCtx^.Ready^, 1, mo_acq_rel);
    while atomic_load(LCtx^.Start^, mo_acquire) <= LI do
      CpuPause;
    LLeft := LI * 2;
    LRight := LLeft + 1;
    if LCtx^.Reverse then
      LCtx^.Results[LI] := LCtx^.DisjointSet.Union(LRight, LLeft)
    else
      LCtx^.Results[LI] := LCtx^.DisjointSet.Union(LLeft, LRight);
    atomic_fetch_add(LCtx^.Done^, 1, mo_acq_rel);
  end;
  Result := nil;
end;

procedure Check(ACond: Boolean; const AName: string);
begin
  Inc(GTests);
  if ACond then
    Inc(GPassed)
  else
    WriteLn('  FAIL: ', AName);
end;

procedure TestBasicMakeSet;
var
  DS: TLockFreeDisjointSet;
  I, J: Int32;
begin
  WriteLn('--- TestBasicMakeSet ---');
  DS := TLockFreeDisjointSet.Create;
  try
    Check(DS.Count = 0, 'count starts at 0');
    I := DS.MakeSet;
    J := DS.MakeSet;
    Check(I = 0, 'first set id is 0');
    Check(J = 1, 'second set id is 1');
    Check(I <> J, 'different IDs');
    Check(DS.Find(I) = I, 'find i = i');
    Check(DS.Find(J) = J, 'find j = j');
    Check(not DS.Connected(I, J), 'not connected initially');
    Check(DS.Count = 2, 'count tracks created sets');
  finally
    DS.Free;
  end;
end;

procedure TestUnion;
var
  DS: TLockFreeDisjointSet;
  A, B, C: Int32;
begin
  WriteLn('--- TestUnion ---');
  DS := TLockFreeDisjointSet.Create;
  try
    A := DS.MakeSet;
    B := DS.MakeSet;
    C := DS.MakeSet;
    Check(DS.Union(A, B) = dsOk, 'union a,b');
    Check(DS.Connected(A, B), 'a connected to b');
    Check(not DS.Connected(A, C), 'a not connected to c');
    Check(DS.Union(B, C) = dsOk, 'union b,c');
    Check(DS.Connected(A, C), 'a connected to c after transitive union');
  finally
    DS.Free;
  end;
end;

procedure TestSameSet;
var
  DS: TLockFreeDisjointSet;
  A, B: Int32;
begin
  WriteLn('--- TestSameSet ---');
  DS := TLockFreeDisjointSet.Create;
  try
    A := DS.MakeSet;
    B := DS.MakeSet;
    DS.Union(A, B);
    Check(DS.Union(A, B) = dsSameSet, 'union same set returns dsSameSet');
  finally
    DS.Free;
  end;
end;

procedure TestPathCompression;
var
  DS: TLockFreeDisjointSet;
  Nodes: array[0..9] of Int32;
  I: Int32;
begin
  WriteLn('--- TestPathCompression ---');
  DS := TLockFreeDisjointSet.Create;
  try
    // Create chain: 0-1-2-3-4-5-6-7-8-9
    for I := 0 to 9 do
      Nodes[I] := DS.MakeSet;
    for I := 0 to 8 do
      DS.Union(Nodes[I], Nodes[I + 1]);
    // All should be connected
    for I := 0 to 9 do
      Check(DS.Connected(Nodes[0], Nodes[I]), 'connected to ' + IntToStr(I));
    // After Find, path should be compressed
    DS.Find(Nodes[9]);
    // All should still have the same root
    Check(DS.Find(Nodes[0]) = DS.Find(Nodes[9]), 'same root after compression');
  finally
    DS.Free;
  end;
end;

procedure TestMultipleSets;
var
  DS: TLockFreeDisjointSet;
  A, B, C, D, E, F: Int32;
begin
  WriteLn('--- TestMultipleSets ---');
  DS := TLockFreeDisjointSet.Create;
  try
    // Set 1: {A, B, C}
    A := DS.MakeSet;
    B := DS.MakeSet;
    C := DS.MakeSet;
    DS.Union(A, B);
    DS.Union(B, C);
    // Set 2: {D, E, F}
    D := DS.MakeSet;
    E := DS.MakeSet;
    F := DS.MakeSet;
    DS.Union(D, E);
    DS.Union(E, F);
    // Within sets
    Check(DS.Connected(A, C), 'a-c connected');
    Check(DS.Connected(D, F), 'd-f connected');
    // Between sets
    Check(not DS.Connected(A, D), 'a-d not connected');
    Check(not DS.Connected(B, E), 'b-e not connected');
    // Merge sets
    DS.Union(C, D);
    Check(DS.Connected(A, F), 'a-f connected after merge');
  finally
    DS.Free;
  end;
end;

procedure TestLargeScale;
var
  DS: TLockFreeDisjointSet;
  Nodes: array of Int32;
  I, LN: Int32;
begin
  WriteLn('--- TestLargeScale ---');
  LN := 1000;
  DS := TLockFreeDisjointSet.Create(16);
  try
    SetLength(Nodes, LN);
    for I := 0 to LN - 1 do
      Nodes[I] := DS.MakeSet;
    // Union adjacent pairs
    for I := 0 to LN - 2 do
      DS.Union(Nodes[I], Nodes[I + 1]);
    // All should be in same set
    for I := 0 to LN - 1 do
      Check(DS.Connected(Nodes[0], Nodes[I]), 'connected');
    Check(DS.Count >= LN, 'count >= ' + IntToStr(LN));
  finally
    SetLength(Nodes, 0);
    DS.Free;
  end;
end;

procedure TestNotFound;
var
  DS: TLockFreeDisjointSet;
begin
  WriteLn('--- TestNotFound ---');
  DS := TLockFreeDisjointSet.Create;
  try
    Check(DS.Find(999) = -1, 'find nonexistent');
    Check(DS.Union(999, 0) = dsNotFound, 'union nonexistent');
    Check(DS.Union(0, 999) = dsNotFound, 'union nonexistent reverse');
    Check(not DS.Connected(999, 1000),
      'distinct missing elements are not connected');
    Check(not DS.Connected(-1, -2),
      'negative missing elements are not connected');
  finally
    DS.Free;
  end;
end;

procedure TestStress;
var
  DS: TLockFreeDisjointSet;
  I, LA, LB, LN: Int32;
begin
  WriteLn('--- TestStress ---');
  LN := 5000;
  DS := TLockFreeDisjointSet.Create(16);
  try
    for I := 0 to LN - 1 do
      DS.MakeSet;
    // Random-like unions
    for I := 0 to LN - 2 do
    begin
      LA := I mod LN;
      LB := (I * 7 + 13) mod LN;
      DS.Union(LA, LB);
    end;
    // Verify Find doesn't crash
    for I := 0 to LN - 1 do
      DS.Find(I);
  finally
    DS.Free;
  end;
end;

procedure TestConcurrentOppositeUnion;
const
  PAIR_COUNT = 2000;
var
  DS: TLockFreeDisjointSet;
  LForwardRec, LReverseRec: TPlatformThreadRecord;
  LForwardCtx, LReverseCtx: TUnionCtx;
  LReady, LStart, LDone, LI: Int32;
  LValid: Boolean;
begin
  WriteLn('--- TestConcurrentOppositeUnion ---');
  DS := TLockFreeDisjointSet.Create(16);
  try
    for LI := 1 to PAIR_COUNT * 2 do
      DS.MakeSet;
    LReady := 0;
    LStart := 0;
    LDone := 0;
    InitUnionCtx(LForwardCtx, DS, PAIR_COUNT, False,
      @LReady, @LStart, @LDone);
    InitUnionCtx(LReverseCtx, DS, PAIR_COUNT, True,
      @LReady, @LStart, @LDone);
    Check(platform_thread_spawn(LForwardRec, @UnionProc,
      @LForwardCtx) = 0, 'spawn forward union worker');
    Check(platform_thread_spawn(LReverseRec, @UnionProc,
      @LReverseCtx) = 0, 'spawn reverse union worker');
    for LI := 0 to PAIR_COUNT - 1 do
    begin
      while atomic_load(LReady, mo_acquire) < (LI + 1) * 2 do
        CpuPause;
      atomic_store(LStart, LI + 1, mo_release);
      while atomic_load(LDone, mo_acquire) < (LI + 1) * 2 do
        CpuPause;
    end;
    Check(platform_thread_wait(LForwardRec) = 0, 'join forward union worker');
    Check(platform_thread_wait(LReverseRec) = 0, 'join reverse union worker');

    LValid := True;
    for LI := 0 to PAIR_COUNT - 1 do
      if ((LForwardCtx.Results[LI] = dsOk) and
          (LReverseCtx.Results[LI] = dsOk)) or
         (not DS.Connected(LI * 2, LI * 2 + 1)) then
      begin
        LValid := False;
        Break;
      end;
    Check(LValid, 'Concurrent opposite unions preserve a rooted forest');
  finally
    DS.Free;
  end;
end;

begin
  GTests := 0;
  GPassed := 0;

  TestBasicMakeSet;
  TestUnion;
  TestSameSet;
  TestPathCompression;
  TestMultipleSets;
  TestLargeScale;
  TestNotFound;
  TestStress;
  TestConcurrentOppositeUnion;

  WriteLn;
  WriteLn(GPassed, '/', GTests, ' tests passed');
  if GPassed <> GTests then
    Halt(1);
end.
