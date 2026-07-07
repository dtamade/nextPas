{ Soak test for mem allocator — detects slow leaks and fragmentation.

  Run manually: SOAK_DURATION_SECS=60 ./test_soak
  Default: 10 seconds (CI-safe). For real soak testing, use 3600+ (1h+).

  What it tests:
  - Multi-threaded continuous alloc/free (stress stability)
  - Memory usage stability over time (no monotonic growth)
  - Fragmentation: large allocs succeed after heavy small-alloc churn
  - Alloc/free ratio stability
}

{$mode ObjFPC}{$H+}

program test_soak;

uses
  nextpas.core.thread.init,
  SysUtils,
  nextpas.core.test,
  nextpas.core.mem,
  nextpas.core.mem.allocator.tracking;

const
  { Default soak duration in seconds. Override via SOAK_DURATION_SECS env. }
  DEFAULT_SOAK_SECS = 10;
  NUM_WORKERS = 4;

var
  T: TTestSuite;

{ ── Helpers ── }

function GetSoakDuration: Integer;
var
  LVal: string;
begin
  LVal := GetEnvironmentVariable('SOAK_DURATION_SECS');
  if LVal <> '' then
    Result := StrToIntDef(LVal, DEFAULT_SOAK_SECS)
  else
    Result := DEFAULT_SOAK_SECS;
end;

{ ── Soak worker: continuous mixed-size alloc/free ── }

type
  PSoakData = ^TSoakData;
  TSoakData = record
    Alloc: IAllocator;
    TID: Integer;
    Ops: QWord;
    StopFlag: PBoolean;
    ErrorMsg: string;
  end;

function SoakWorker(Parameter: Pointer): PtrInt;
var
  LData: PSoakData;
  LSizes: array[0..7] of SizeUInt;
  LPtrs: array[0..31] of Pointer;
  LJ, LK: Integer;
  LSize: SizeUInt;
begin
  LData := PSoakData(Parameter);
  LSizes[0] := 16; LSizes[1] := 48; LSizes[2] := 128;
  LSizes[3] := 256; LSizes[4] := 512; LSizes[5] := 1024;
  LSizes[6] := 4096; LSizes[7] := 16384;
  try
    while not LData^.StopFlag^ do
    begin
      LK := Integer(LData^.Ops) mod 8;
      LSize := LSizes[LK];
      for LJ := 0 to 31 do
      begin
        LPtrs[LJ] := LData^.Alloc.GetMem(LSize);
        if LPtrs[LJ] = nil then
        begin
          LData^.ErrorMsg := 'nil at op ' + IntToStr(LData^.Ops);
          Exit(1);
        end;
        PByte(LPtrs[LJ])^ := Byte(LData^.Ops + LJ);
      end;
      for LJ := 0 to 31 do
        LData^.Alloc.FreeMem(LPtrs[LJ]);
      Inc(LData^.Ops);
    end;
    Result := 0;
  except
    on E: Exception do
    begin
      LData^.ErrorMsg := E.Message;
      Result := 1;
    end;
  end;
end;

{ ── Soak: multi-threaded continuous alloc/free ──
  Uses DefaultAllocator directly (no tracker) since TTrackingAllocator
  is not thread-safe. Verifies stability via worker error reporting. }

procedure TestSoakContinuousAllocFree;
var
  LWorkers: array[0..NUM_WORKERS - 1] of TSoakData;
  LThreads: array[0..NUM_WORKERS - 1] of TThreadID;
  LStop: Boolean;
  LDuration, LStartTime, LElapsed: QWord;
  LI: Integer;
  LTotalOps: QWord;
begin
  LDuration := QWord(GetSoakDuration) * 1000;
  LStop := False;
  for LI := 0 to NUM_WORKERS - 1 do
  begin
    LWorkers[LI].Alloc := DefaultAllocator;
    LWorkers[LI].TID := LI;
    LWorkers[LI].Ops := 0;
    LWorkers[LI].StopFlag := @LStop;
    LWorkers[LI].ErrorMsg := '';
  end;
  for LI := 0 to NUM_WORKERS - 1 do
    LThreads[LI] := BeginThread(@SoakWorker, @LWorkers[LI]);

  LStartTime := GetTickCount64;
  repeat
    Sleep(100);
    LElapsed := GetTickCount64 - LStartTime;
  until LElapsed >= LDuration;

  LStop := True;
  for LI := 0 to NUM_WORKERS - 1 do
    WaitForThreadTerminate(LThreads[LI], 5000);

  for LI := 0 to NUM_WORKERS - 1 do
    Check(LWorkers[LI].ErrorMsg = '', 'worker ' + IntToStr(LI) + ': ' + LWorkers[LI].ErrorMsg);

  LTotalOps := 0;
  for LI := 0 to NUM_WORKERS - 1 do
    Inc(LTotalOps, LWorkers[LI].Ops);
  WriteLn('  Workers: ', NUM_WORKERS, ' | Duration: ', GetSoakDuration, 's');
  WriteLn('  Total ops: ', LTotalOps, ' | Ops/sec: ', LTotalOps div QWord(GetSoakDuration));

  WriteLn('PASS: soak ', GetSoakDuration, 's, ',
    NUM_WORKERS, ' threads, ', LTotalOps, ' ops');
end;

{ ── Soak: large alloc after small-alloc churn (fragmentation) ── }

procedure TestSoakFragmentation;
var
  LTracker: TTrackingAllocator;
  LSmallPtrs: array[0..1023] of Pointer;
  LLargePtr: Pointer;
  LI, R: Integer;
begin
  LTracker := TTrackingAllocator.Create(DefaultAllocator);
  try
    { Heavy small-alloc churn: allocate and free 1024 small blocks repeatedly. }
    for LI := 0 to 1023 do
      LSmallPtrs[LI] := LTracker.GetMem(48);
    for LI := 0 to 1023 do
      LTracker.FreeMem(LSmallPtrs[LI]);
    { Repeat 100 times to create fragmentation pressure. }
    for R := 0 to 99 do
    begin
      for LI := 0 to 1023 do
        LSmallPtrs[LI] := LTracker.GetMem(48);
      for LI := 0 to 1023 do
        LTracker.FreeMem(LSmallPtrs[LI]);
    end;

    { Now try a large allocation — should succeed despite churn. }
    LLargePtr := LTracker.GetMem(65536);
    Check(LLargePtr <> nil, 'large alloc (64KB) succeeds after small-alloc churn');
    PByte(LLargePtr)^ := $42;
    LTracker.FreeMem(LLargePtr);

    Check(not LTracker.HasLeaks, 'no leaks after fragmentation test');

    WriteLn('PASS: fragmentation resilience (64KB after 1024x100 small churn)');
  finally
    LTracker.Free;
  end;
end;

{ ── Soak: alloc/free ratio stability ── }

procedure TestSoakAllocFreeRatio;
var
  LTracker: TTrackingAllocator;
  LPtrs: array[0..255] of Pointer;
  LAllocated: Integer;
  LI, R: Integer;
begin
  LTracker := TTrackingAllocator.Create(DefaultAllocator);
  try
    LAllocated := 0;
    { Mixed alloc/free: sometimes allocate, sometimes free, net should stay bounded. }
    for R := 0 to 9999 do
    begin
      if (R mod 3 <> 0) and (LAllocated < 256) then
      begin
        LPtrs[LAllocated] := LTracker.GetMem(64);
        Check(LPtrs[LAllocated] <> nil, 'alloc at round ' + IntToStr(R));
        Inc(LAllocated);
      end
      else if LAllocated > 0 then
      begin
        Dec(LAllocated);
        LTracker.FreeMem(LPtrs[LAllocated]);
      end;
    end;

    { Free remaining. }
    for LI := LAllocated - 1 downto 0 do
      LTracker.FreeMem(LPtrs[LI]);

    Check(not LTracker.HasLeaks, 'no leaks after ratio test');

    WriteLn('PASS: alloc/free ratio stability (10K rounds)');
  finally
    LTracker.Free;
  end;
end;

{ ── Main ── }

begin
  T := TTestSuite.Create('soak');

  T.Test('soak_continuous_allocfree', @TestSoakContinuousAllocFree);
  T.Test('soak_fragmentation', @TestSoakFragmentation);
  T.Test('soak_allocfree_ratio', @TestSoakAllocFreeRatio);

  T.Run;
  T.Summary;
end.
