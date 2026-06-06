program test_sharded_pools;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes,
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem.blockpool.sharded,
  nextpas.core.mem.pool.slab.sharded;

const
  THREAD_COUNT = 8;
  ITERATION_COUNT = 32;

type
  TBlockPoolWorker = class(TThread)
  private
    FPool: TShardedBlockPool;
    FStartFlag: PLongInt;
    FFailure: string;
  protected
    procedure Execute; override;
  public
    constructor Create(APool: TShardedBlockPool; AStartFlag: PLongInt);
    property Failure: string read FFailure;
  end;

  TSlabPoolWorker = class(TThread)
  private
    FPool: TSlabPoolSharded;
    FStartFlag: PLongInt;
    FFailure: string;
  protected
    procedure Execute; override;
  public
    constructor Create(APool: TSlabPoolSharded; AStartFlag: PLongInt);
    property Failure: string read FFailure;
  end;

var
  T: TTestRunner;

constructor TBlockPoolWorker.Create(APool: TShardedBlockPool; AStartFlag: PLongInt);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FPool := APool;
  FStartFlag := AStartFlag;
end;

procedure TBlockPoolWorker.Execute;
var
  LIndex: Integer;
  LPtr: Pointer;
begin
  while FStartFlag^ = 0 do
    Sleep(0);

  try
    for LIndex := 0 to ITERATION_COUNT - 1 do
    begin
      LPtr := FPool.Acquire;
      if LPtr = nil then
        raise Exception.Create('TShardedBlockPool.Acquire returned nil');
      PByte(LPtr)^ := Byte(LIndex);
      FPool.Release(LPtr);
    end;
  except
    on E: Exception do
      FFailure := E.Message;
  end;
end;

constructor TSlabPoolWorker.Create(APool: TSlabPoolSharded; AStartFlag: PLongInt);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FPool := APool;
  FStartFlag := AStartFlag;
end;

procedure TSlabPoolWorker.Execute;
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
        raise Exception.Create('TSlabPoolSharded.GetMem returned nil');
      PByte(LPtr)^ := Byte(LIndex);
      FPool.FreeMem(LPtr);
    end;
  except
    on E: Exception do
      FFailure := E.Message;
  end;
end;

procedure TestShardedBlockPoolContention;
var
  LPool: TShardedBlockPool;
  LThreads: array[0..THREAD_COUNT - 1] of TBlockPoolWorker;
  LStartFlag: LongInt;
  LIndex: Integer;
begin
  LPool := TShardedBlockPool.Create(64, THREAD_COUNT, 4);
  try
    LStartFlag := 0;
    for LIndex := 0 to High(LThreads) do
    begin
      LThreads[LIndex] := TBlockPoolWorker.Create(LPool, @LStartFlag);
      LThreads[LIndex].Start;
    end;

    LStartFlag := 1;
    for LIndex := 0 to High(LThreads) do
      LThreads[LIndex].WaitFor;

    for LIndex := 0 to High(LThreads) do
    begin
      Check(LThreads[LIndex].Failure = '', 'sharded blockpool worker should not fail');
      LThreads[LIndex].Free;
    end;
    Check(LPool.InUse = 0, 'all sharded blockpool blocks should be released');
    Check(LPool.BlockSize = 64, 'block size should stay visible');
  finally
    TObject(LPool).Free;
  end;
end;

procedure TestShardedSlabPoolContention;
var
  LPool: TSlabPoolSharded;
  LThreads: array[0..THREAD_COUNT - 1] of TSlabPoolWorker;
  LStartFlag: LongInt;
  LIndex: Integer;
begin
  LPool := TSlabPoolSharded.Create(4096, 4);
  try
    LStartFlag := 0;
    for LIndex := 0 to High(LThreads) do
    begin
      LThreads[LIndex] := TSlabPoolWorker.Create(LPool, @LStartFlag);
      LThreads[LIndex].Start;
    end;

    LStartFlag := 1;
    for LIndex := 0 to High(LThreads) do
      LThreads[LIndex].WaitFor;

    for LIndex := 0 to High(LThreads) do
    begin
      Check(LThreads[LIndex].Failure = '', 'sharded slab worker should not fail');
      LThreads[LIndex].Free;
    end;
    Check(LPool.Stats.FallbackAllocCount = 0, 'small contention path should stay in slab fast path');
    Check(LPool.ShardCount = 4, 'requested shard count should stay visible');
  finally
    TObject(LPool).Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.sharded_pools');
  T.Run('sharded blockpool contention', @TestShardedBlockPoolContention);
  T.Run('sharded slab contention', @TestShardedSlabPoolContention);
  T.Summary;
end.
