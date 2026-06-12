program test_sharded_pools;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes,
  SysUtils,
  nextpas.core.testing,
  nextpas.core.mem.error,
  nextpas.core.mem.blockpool.sharded,
  nextpas.core.mem.pool.slab.sharded,
  nextpas.core.platform.thread;

const
  THREAD_COUNT = 8;
  ITERATION_COUNT = 32;

type
  TExceptionProc = procedure;

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

  TBlockPoolAcquireWorker = class(TThread)
  private
    FPool: TShardedBlockPool;
    FStartFlag: PLongInt;
    FPtr: Pointer;
    FShard: Integer;
    FFailure: string;
  protected
    procedure Execute; override;
  public
    constructor Create(APool: TShardedBlockPool; AStartFlag: PLongInt);
    property Ptr: Pointer read FPtr;
    property Shard: Integer read FShard;
    property Failure: string read FFailure;
  end;

  TBlockPoolReleaseWorker = class(TThread)
  private
    FPool: TShardedBlockPool;
    FStartFlag: PLongInt;
    FPtr: Pointer;
    FGotAllocError: Boolean;
    FAllocError: TAllocError;
    FFailure: string;
  protected
    procedure Execute; override;
  public
    constructor Create(APool: TShardedBlockPool; AStartFlag: PLongInt; APtr: Pointer);
    property GotAllocError: Boolean read FGotAllocError;
    property AllocError: TAllocError read FAllocError;
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

  TSlabPoolAcquireWorker = class(TThread)
  private
    FPool: TSlabPoolSharded;
    FStartFlag: PLongInt;
    FPtr: Pointer;
    FShard: Integer;
    FFailure: string;
  protected
    procedure Execute; override;
  public
    constructor Create(APool: TSlabPoolSharded; AStartFlag: PLongInt);
    property Ptr: Pointer read FPtr;
    property Shard: Integer read FShard;
    property Failure: string read FFailure;
  end;

var
  T: TTestRunner;
  GBlockPool: TShardedBlockPool = nil;
  GBlockPtr: Pointer = nil;
  GSlabPool: TSlabPoolSharded = nil;
  GSlabPtr: PByte = nil;

{$PUSH}
{$Q-}
function TestShardIndex(AShardCount: Integer): Integer;
begin
  Result := Integer((QWord(platform_thread_id) * QWord(11400714819323198485)) and QWord(AShardCount - 1));
end;
{$POP}

procedure CheckRaisesAllocError(AProc: TExceptionProc; AExpected: TAllocError; const AName: string);
begin
  try
    AProc;
    Fail(AName + ': expected allocation error');
  except
    on E: EAllocError do
      CheckEqual(Int64(Ord(AExpected)), Int64(Ord(E.Error)), AName + ': error code');
  end;
end;

procedure ReleaseDuplicateRemoteShardedBlockPointer;
begin
  GBlockPool.Release(GBlockPtr);
end;

procedure FreeInteriorShardedSlabPointer;
begin
  GSlabPool.FreeMem(GSlabPtr + 1);
end;

procedure ReallocInteriorShardedSlabPointer;
var
  LNewPtr: Pointer;
begin
  LNewPtr := GSlabPool.ReallocMem(GSlabPtr + 1, 128);
  if LNewPtr <> nil then
    GSlabPool.FreeMem(LNewPtr);
end;

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

constructor TBlockPoolAcquireWorker.Create(APool: TShardedBlockPool; AStartFlag: PLongInt);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FPool := APool;
  FStartFlag := AStartFlag;
  FPtr := nil;
  FShard := -1;
end;

procedure TBlockPoolAcquireWorker.Execute;
begin
  while FStartFlag^ = 0 do
    Sleep(0);

  try
    FShard := TestShardIndex(FPool.ShardCount);
    FPtr := FPool.Acquire;
    if FPtr = nil then
      raise Exception.Create('TShardedBlockPool.Acquire returned nil');
  except
    on E: Exception do
      FFailure := E.Message;
  end;
end;

constructor TBlockPoolReleaseWorker.Create(APool: TShardedBlockPool; AStartFlag: PLongInt; APtr: Pointer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FPool := APool;
  FStartFlag := AStartFlag;
  FPtr := APtr;
  FGotAllocError := False;
  FAllocError := aeNone;
end;

procedure TBlockPoolReleaseWorker.Execute;
begin
  while FStartFlag^ = 0 do
    Sleep(0);

  try
    FPool.Release(FPtr);
  except
    on E: EAllocError do
    begin
      FGotAllocError := True;
      FAllocError := E.Error;
    end;
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

constructor TSlabPoolAcquireWorker.Create(APool: TSlabPoolSharded; AStartFlag: PLongInt);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FPool := APool;
  FStartFlag := AStartFlag;
  FPtr := nil;
  FShard := -1;
end;

procedure TSlabPoolAcquireWorker.Execute;
begin
  while FStartFlag^ = 0 do
    Sleep(0);

  try
    FShard := TestShardIndex(FPool.ShardCount);
    FPtr := FPool.GetMem(64);
    if FPtr = nil then
      raise Exception.Create('TSlabPoolSharded.GetMem returned nil');
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

procedure TestShardedBlockPoolRejectsDuplicateRemoteRelease;
var
  LThreads: array[0..THREAD_COUNT - 1] of TBlockPoolAcquireWorker;
  LStartFlag: LongInt;
  LIndex: Integer;
  LMainShard: Integer;
  LSelected: Integer;
begin
  GBlockPool := TShardedBlockPool.Create(64, THREAD_COUNT * 2, 4);
  LSelected := -1;
  try
    LMainShard := TestShardIndex(GBlockPool.ShardCount);
    LStartFlag := 0;
    for LIndex := 0 to High(LThreads) do
    begin
      LThreads[LIndex] := TBlockPoolAcquireWorker.Create(GBlockPool, @LStartFlag);
      LThreads[LIndex].Start;
    end;

    LStartFlag := 1;
    for LIndex := 0 to High(LThreads) do
      LThreads[LIndex].WaitFor;

    for LIndex := 0 to High(LThreads) do
    begin
      Check(LThreads[LIndex].Failure = '', 'remote-release setup worker should not fail');
      if (LSelected < 0) and (LThreads[LIndex].Ptr <> nil) and (LThreads[LIndex].Shard <> LMainShard) then
        LSelected := LIndex;
    end;

    Check(LSelected >= 0, 'test setup should find a worker on a non-local shard');
    GBlockPtr := LThreads[LSelected].Ptr;
    LThreads[LSelected].FPtr := nil;

    GBlockPool.Release(GBlockPtr);
    CheckRaisesAllocError(@ReleaseDuplicateRemoteShardedBlockPointer, aeDoubleFree,
      'duplicate remote sharded block release');
    CheckEqual(Int64(THREAD_COUNT - 1), Int64(GBlockPool.InUse),
      'duplicate release should not decrement in-use count');
  finally
    for LIndex := 0 to High(LThreads) do
    begin
      if LThreads[LIndex] <> nil then
      begin
        if LThreads[LIndex].Ptr <> nil then
          GBlockPool.Release(LThreads[LIndex].Ptr);
        LThreads[LIndex].Free;
      end;
    end;
    GBlockPtr := nil;
    TObject(GBlockPool).Free;
    GBlockPool := nil;
  end;
end;

procedure TestShardedBlockPoolThreadCacheConfigRejectsDuplicateRelease;
var
  LConfig: TShardedBlockPoolConfig;
  LPool: TShardedBlockPool;
  LWorker: TBlockPoolReleaseWorker;
  LStartFlag: LongInt;
  LPtr: Pointer;
begin
  LConfig := TShardedBlockPoolConfig.Default(64, 4, 1);
  LConfig.ThreadCacheCapacity := 8;
  LPool := TShardedBlockPool.Create(LConfig);
  LWorker := nil;
  try
    LPtr := LPool.Acquire;
    Check(LPtr <> nil, 'thread-cache test should allocate');
    LPool.Release(LPtr);

    LStartFlag := 0;
    LWorker := TBlockPoolReleaseWorker.Create(LPool, @LStartFlag, LPtr);
    LWorker.Start;
    LStartFlag := 1;
    LWorker.WaitFor;

    Check(LWorker.Failure = '', 'thread-cache duplicate-release worker should not raise non-allocation error');
    Check(LWorker.GotAllocError, 'thread-cache duplicate release should fail closed');
    CheckEqual(Int64(Ord(aeDoubleFree)), Int64(Ord(LWorker.AllocError)),
      'thread-cache duplicate release error code');
    CheckEqual(Int64(0), Int64(LPool.InUse),
      'thread-cache duplicate release should not decrement in-use count');
  finally
    LWorker.Free;
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

procedure TestShardedSlabOwnershipDiagnosticsRejectInteriorPointer;
var
  LPool: TSlabPoolSharded;
  LPtr: PByte;
begin
  LPool := TSlabPoolSharded.Create(4096, 4);
  try
    LPtr := PByte(LPool.GetMem(64));
    try
      Check(LPtr <> nil, 'GetMem should allocate');
      Check(LPool.Owns(LPtr), 'sharded pool should own exact allocation pointer');
      CheckEqual(Int64(64), Int64(LPool.MemSizeOf(LPtr)), 'exact pointer should report slab chunk size');
      Check(not LPool.Owns(LPtr + 1), 'sharded pool should not own interior pointer diagnostically');
      CheckEqual(Int64(0), Int64(LPool.MemSizeOf(LPtr + 1)), 'interior pointer should not report chunk size');
    finally
      LPool.FreeMem(LPtr);
    end;
  finally
    TObject(LPool).Free;
  end;
end;

procedure TestShardedSlabReleaseAndReallocRejectInteriorPointer;
begin
  GSlabPool := TSlabPoolSharded.Create(4096, 4);
  try
    GSlabPtr := PByte(GSlabPool.GetMem(64));
    Check(GSlabPtr <> nil, 'GetMem should allocate');

    CheckRaisesAllocError(@FreeInteriorShardedSlabPointer, aeInvalidPointer, 'interior FreeMem');
    Check(GSlabPool.Owns(GSlabPtr), 'invalid FreeMem should not release exact pointer');
    CheckEqual(Int64(64), Int64(GSlabPool.MemSizeOf(GSlabPtr)), 'invalid FreeMem should preserve exact pointer size');

    CheckRaisesAllocError(@ReallocInteriorShardedSlabPointer, aeInvalidPointer, 'interior ReallocMem');
    Check(GSlabPool.Owns(GSlabPtr), 'invalid ReallocMem should not release exact pointer');
    CheckEqual(Int64(64), Int64(GSlabPool.MemSizeOf(GSlabPtr)), 'invalid ReallocMem should preserve exact pointer size');

    GSlabPool.FreeMem(GSlabPtr);
  finally
    GSlabPtr := nil;
    TObject(GSlabPool).Free;
    GSlabPool := nil;
  end;
end;

procedure TestShardedSlabRemoteReleaseClearsDiagnostics;
var
  LPool: TSlabPoolSharded;
  LThreads: array[0..THREAD_COUNT - 1] of TSlabPoolAcquireWorker;
  LStartFlag: LongInt;
  LIndex: Integer;
  LMainShard: Integer;
  LSelected: Integer;
  LPtr: Pointer;
begin
  LPool := TSlabPoolSharded.Create(4096, 4);
  LSelected := -1;
  try
    LMainShard := TestShardIndex(LPool.ShardCount);
    LStartFlag := 0;
    for LIndex := 0 to High(LThreads) do
    begin
      LThreads[LIndex] := TSlabPoolAcquireWorker.Create(LPool, @LStartFlag);
      LThreads[LIndex].Start;
    end;

    LStartFlag := 1;
    for LIndex := 0 to High(LThreads) do
      LThreads[LIndex].WaitFor;

    for LIndex := 0 to High(LThreads) do
    begin
      Check(LThreads[LIndex].Failure = '', 'remote slab setup worker should not fail');
      if (LSelected < 0) and (LThreads[LIndex].Ptr <> nil) and (LThreads[LIndex].Shard <> LMainShard) then
        LSelected := LIndex;
    end;

    Check(LSelected >= 0, 'test setup should find a worker on a non-local slab shard');
    LPtr := LThreads[LSelected].Ptr;
    LThreads[LSelected].FPtr := nil;

    LPool.FreeMem(LPtr);
    Check(not LPool.Owns(LPtr), 'remote slab FreeMem should clear ownership diagnostics immediately');
    CheckEqual(Int64(0), Int64(LPool.MemSizeOf(LPtr)),
      'remote slab FreeMem should clear size diagnostics immediately');
  finally
    for LIndex := 0 to High(LThreads) do
    begin
      if LThreads[LIndex] <> nil then
      begin
        if LThreads[LIndex].Ptr <> nil then
          LPool.FreeMem(LThreads[LIndex].Ptr);
        LThreads[LIndex].Free;
      end;
    end;
    TObject(LPool).Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.mem.sharded_pools');
  T.Run('sharded blockpool contention', @TestShardedBlockPoolContention);
  T.Run('sharded blockpool rejects duplicate remote release', @TestShardedBlockPoolRejectsDuplicateRemoteRelease);
  T.Run('sharded blockpool thread-cache config rejects duplicate release', @TestShardedBlockPoolThreadCacheConfigRejectsDuplicateRelease);
  T.Run('sharded slab contention', @TestShardedSlabPoolContention);
  T.Run('sharded slab ownership diagnostics reject interior pointer', @TestShardedSlabOwnershipDiagnosticsRejectInteriorPointer);
  T.Run('sharded slab release and realloc reject interior pointer', @TestShardedSlabReleaseAndReallocRejectInteriorPointer);
  T.Run('sharded slab remote release clears diagnostics', @TestShardedSlabRemoteReleaseClearsDiagnostics);
  T.Summary;
end.
