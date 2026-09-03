program test_slab_thread_safety;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.test,
  nextpas.core.mem.error,
  nextpas.core.mem.pool.slab,
  nextpas.core.platform.thread;

type
  TWorkerData = record
    Pool: TSlabPool;
    ViolationDetected: Boolean;
    StartFlag: PLongInt;
  end;

var
  T: TTestSuite;
  LRunPassed: Boolean;

function CrossThreadWorker(AArg: Pointer): Pointer; cdecl;
var
  LData: ^TWorkerData;
  LP: Pointer;
begin
  LData := AArg;
  // Spin-wait for start signal
  while LData^.StartFlag^ = 0 do
    platform_thread_yield;
  LP := nil;
  try
    LP := LData^.Pool.GetMem(64);
    // If we get here, no cross-thread detection (non-DEBUG or same-thread)
    LData^.ViolationDetected := False;
    if LP <> nil then
      LData^.Pool.FreeMem(LP);
  except
    on E: EAllocError do
    begin
      LData^.ViolationDetected := True;
      // Don't FreeMem — the pool rejected us
    end;
  end;
  Result := nil;
end;

{ CS-017: TSlabPool 在 DEBUG 模式下拒绝跨线程访问 }
procedure TestCrossThreadDetection;
var
  LThread: TPlatformThreadRecord;
  LData: TWorkerData;
  LPool: TSlabPool;
  LP: Pointer;
  LStartFlag: LongInt;
begin
  LPool := TSlabPool.Create(4096);
  try
    // Verify owner-thread access works
    LP := LPool.GetMem(64);
    Check(LP <> nil, 'owner thread GetMem succeeds');
    LPool.FreeMem(LP);

    // Spawn worker thread
    LStartFlag := 0;
    LData.Pool := LPool;
    LData.ViolationDetected := False;
    LData.StartFlag := @LStartFlag;
    platform_thread_spawn(LThread, @CrossThreadWorker, @LData);
    LStartFlag := 1;  // signal worker to start
    platform_thread_wait(LThread);

    {$IFDEF DEBUG}
    Check(LData.ViolationDetected, 'DEBUG: cross-thread access detected by CS-017');
    {$ELSE}
    Check(not LData.ViolationDetected, 'non-DEBUG: no cross-thread detection (expected)');
    {$ENDIF}
  finally
    LPool.Free;
  end;
end;

{ Same-thread access should always succeed }
procedure TestSameThreadOK;
var
  LPool: TSlabPool;
  LP: Pointer;
begin
  LPool := TSlabPool.Create(4096);
  try
    LP := LPool.GetMem(64);
    Check(LP <> nil, 'same-thread GetMem succeeds');
    LPool.FreeMem(LP);
    LP := LPool.GetMem(256);
    Check(LP <> nil, 'same-thread GetMem 256 succeeds');
    LPool.FreeMem(LP);
  finally
    LPool.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.mem.slab_thread_safety');
  T.Test('cross-thread detection (CS-017)', @TestCrossThreadDetection);
  T.Test('same-thread access OK', @TestSameThreadOK);
  LRunPassed := T.Run;

  T.Summary;
  if not LRunPassed then
    Halt(1);
end.
