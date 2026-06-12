program test_concurrent_wrappers;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes,
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem.error,
  nextpas.core.mem.layout,
  nextpas.core.mem.blockpool.concurrent,
  nextpas.core.mem.pool.fixed.concurrent,
  nextpas.core.mem.pool.slab.concurrent;

const
  THREAD_COUNT = 8;
  ITERATION_COUNT = 32;
  NEGATIVE_ITERATION_COUNT = 256;

type
  TPoolWorker = class(TThread)
  private
    FPool: TFixedPoolConcurrent;
    FStartFlag: PLongInt;
    FFailure: string;
  protected
    procedure Execute; override;
  public
    constructor Create(APool: TFixedPoolConcurrent; AStartFlag: PLongInt);
    property Failure: string read FFailure;
  end;

  TSlabWorker = class(TThread)
  private
    FPool: TSlabPoolConcurrent;
    FStartFlag: PLongInt;
    FFailure: string;
  protected
    procedure Execute; override;
  public
    constructor Create(APool: TSlabPoolConcurrent; AStartFlag: PLongInt);
    property Failure: string read FFailure;
  end;

  TFixedPoolNegativeWorker = class(TThread)
  private
    FPool: TFixedPoolConcurrent;
    FStartFlag: PLongInt;
    FFailure: string;
  protected
    procedure Execute; override;
  public
    constructor Create(APool: TFixedPoolConcurrent; AStartFlag: PLongInt);
    property Failure: string read FFailure;
  end;

var
  T: TTestRunner;

constructor TPoolWorker.Create(APool: TFixedPoolConcurrent; AStartFlag: PLongInt);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FPool := APool;
  FStartFlag := AStartFlag;
end;

procedure TPoolWorker.Execute;
var
  LIndex: Integer;
  LPtr: Pointer;
begin
  while FStartFlag^ = 0 do
    Sleep(0);

  try
    for LIndex := 0 to ITERATION_COUNT - 1 do
    begin
      if not FPool.Acquire(LPtr) then
        raise Exception.Create('TFixedPoolConcurrent.Acquire returned false');
      if LPtr = nil then
        raise Exception.Create('TFixedPoolConcurrent.Acquire returned nil');
      PByte(LPtr)^ := Byte(LIndex);
      FPool.Release(LPtr);
    end;
  except
    on E: Exception do
      FFailure := E.Message;
  end;
end;

constructor TSlabWorker.Create(APool: TSlabPoolConcurrent; AStartFlag: PLongInt);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FPool := APool;
  FStartFlag := AStartFlag;
end;

procedure TSlabWorker.Execute;
var
  LIndex: Integer;
  LPtr: Pointer;
begin
  while FStartFlag^ = 0 do
    Sleep(0);

  try
    for LIndex := 1 to ITERATION_COUNT do
    begin
      LPtr := FPool.GetMem(16 + (LIndex mod 32));
      if LPtr = nil then
        raise Exception.Create('TSlabPoolConcurrent.GetMem returned nil');
      PByte(LPtr)^ := Byte(LIndex);
      FPool.FreeMem(LPtr);
    end;
  except
    on E: Exception do
      FFailure := E.Message;
  end;
end;

constructor TFixedPoolNegativeWorker.Create(APool: TFixedPoolConcurrent; AStartFlag: PLongInt);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FPool := APool;
  FStartFlag := AStartFlag;
end;

procedure TFixedPoolNegativeWorker.Execute;
var
  LIndex: Integer;
  LPtr: Pointer;
  LLocal: Byte;
begin
  while FStartFlag^ = 0 do
    Sleep(0);

  try
    for LIndex := 0 to NEGATIVE_ITERATION_COUNT - 1 do
    begin
      if not FPool.Acquire(LPtr) then
        raise Exception.Create('negative worker Acquire returned false');
      if LPtr = nil then
        raise Exception.Create('negative worker Acquire returned nil');
      PByte(LPtr)^ := Byte(LIndex);
      FPool.Release(LPtr);

      try
        FPool.Release(@LLocal);
        raise Exception.Create('external pointer Release should fail');
      except
        on E: EAllocError do
        begin
          if E.Error <> aeInvalidPointer then
            raise Exception.Create('external pointer Release returned wrong error');
        end;
      end;
    end;
  except
    on E: Exception do
      FFailure := E.Message;
  end;
end;

procedure TestBlockPoolConcurrentWrapper;
var
  LPool: TBlockPoolConcurrent;
  LPtr: Pointer;
begin
  LPool := TBlockPoolConcurrent.Create(32, 4);
  try
    LPtr := LPool.Acquire;
    Check(LPtr <> nil, 'Acquire should return a block');
    Check(LPool.BlockSize = 32, 'block size stays visible');
    Check(LPool.InUse = 1, 'in-use count increments');
    LPool.Release(LPtr);
    Check(LPool.InUse = 0, 'release decrements in-use count');
  finally
    TObject(LPool).Free;
  end;
end;

procedure TestArenaConcurrentWrapper;
var
  LArena: TArenaConcurrent;
  LResult: TAllocResult;
begin
  LArena := TArenaConcurrent.Create(256);
  try
    LResult := LArena.Alloc(TMemLayout.Create(32, 8));
    Check(LResult.IsOk, 'Alloc should succeed');
    Check(LArena.UsedSize >= 32, 'arena usage should grow');
    LArena.Reset;
    Check(LArena.UsedSize = 0, 'reset should rewind usage');
  finally
    LArena.Free;
  end;
end;

procedure TestFixedPoolConcurrentContention;
var
  LPool: TFixedPoolConcurrent;
  LThreads: array[0..THREAD_COUNT - 1] of TPoolWorker;
  LStartFlag: LongInt;
  LIndex: Integer;
begin
  LPool := TFixedPoolConcurrent.Create(64, THREAD_COUNT);
  try
    LStartFlag := 0;
    for LIndex := 0 to High(LThreads) do
    begin
      LThreads[LIndex] := TPoolWorker.Create(LPool, @LStartFlag);
      LThreads[LIndex].Start;
    end;

    LStartFlag := 1;
    for LIndex := 0 to High(LThreads) do
      LThreads[LIndex].WaitFor;

    for LIndex := 0 to High(LThreads) do
    begin
      Check(LThreads[LIndex].Failure = '', 'fixed-pool worker should not fail');
      LThreads[LIndex].Free;
    end;
    Check(LPool.AllocatedCount = 0, 'all blocks should be released');
  finally
    TObject(LPool).Free;
  end;
end;

procedure TestFixedPoolConcurrentRejectsInvalidReleaseAfterContention;
var
  LPool: TFixedPoolConcurrent;
  LThreads: array[0..THREAD_COUNT - 1] of TFixedPoolNegativeWorker;
  LStartFlag: LongInt;
  LIndex: Integer;
  LPtr: Pointer;
  LFailure: string;
begin
  LPool := TFixedPoolConcurrent.Create(64, THREAD_COUNT);
  try
    LStartFlag := 0;
    for LIndex := 0 to High(LThreads) do
    begin
      LThreads[LIndex] := TFixedPoolNegativeWorker.Create(LPool, @LStartFlag);
      LThreads[LIndex].Start;
    end;

    LStartFlag := 1;
    for LIndex := 0 to High(LThreads) do
      LThreads[LIndex].WaitFor;

    LFailure := '';
    for LIndex := 0 to High(LThreads) do
    begin
      if (LFailure = '') and (LThreads[LIndex].Failure <> '') then
        LFailure := LThreads[LIndex].Failure;
      LThreads[LIndex].Free;
    end;

    Check(LFailure = '', 'fixed-pool negative worker should not fail: ' + LFailure);
    Check(LPool.AllocatedCount = 0, 'negative stress should release all blocks');
    Check(LPool.Acquire(LPtr), 'pool should remain usable after invalid release exceptions');
    LPool.Release(LPtr);
    try
      LPool.Release(LPtr);
      Fail('fixed-pool double Release should fail after contention');
    except
      on E: EAllocError do
        CheckEqual(Int64(Ord(aeDoubleFree)), Int64(Ord(E.Error)),
          'fixed-pool double Release error code after contention');
    end;
    Check(LPool.AllocatedCount = 0, 'post-exception release should leave pool empty');
  finally
    TObject(LPool).Free;
  end;
end;

procedure TestSlabPoolConcurrentContention;
var
  LPool: TSlabPoolConcurrent;
  LThreads: array[0..THREAD_COUNT - 1] of TSlabWorker;
  LStartFlag: LongInt;
  LIndex: Integer;
begin
  LPool := TSlabPoolConcurrent.Create(4096);
  try
    LStartFlag := 0;
    for LIndex := 0 to High(LThreads) do
    begin
      LThreads[LIndex] := TSlabWorker.Create(LPool, @LStartFlag);
      LThreads[LIndex].Start;
    end;

    LStartFlag := 1;
    for LIndex := 0 to High(LThreads) do
      LThreads[LIndex].WaitFor;

    for LIndex := 0 to High(LThreads) do
    begin
      Check(LThreads[LIndex].Failure = '', 'slab worker should not fail');
      LThreads[LIndex].Free;
    end;
    Check(LPool.Stats.FallbackAllocCount = 0, 'small contention path should stay in slab fast path');
  finally
    TObject(LPool).Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.concurrent_wrappers');
  T.Run('blockpool wrapper basics', @TestBlockPoolConcurrentWrapper);
  T.Run('arena wrapper basics', @TestArenaConcurrentWrapper);
  T.Run('fixed-pool wrapper contention', @TestFixedPoolConcurrentContention);
  T.Run('fixed-pool wrapper rejects invalid release after contention', @TestFixedPoolConcurrentRejectsInvalidReleaseAfterContention);
  T.Run('slab wrapper contention', @TestSlabPoolConcurrentContention);
  T.Summary;
end.
