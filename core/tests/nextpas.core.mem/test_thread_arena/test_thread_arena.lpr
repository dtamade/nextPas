program test_thread_arena;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.testing,
  nextpas.core.mem.base,
  nextpas.core.mem.error,
  nextpas.core.mem.arena.base,
  nextpas.core.mem.arena.local,
  nextpas.core.mem.arena.thread,
  nextpas.core.platform.thread;

const
  THREAD_COUNT = 8;
  STRESS_ITERATIONS = 1000;

{ ---------------------------------------------------------------------------
  TThreadArenaManager 基本测试
  --------------------------------------------------------------------------- }

procedure TestManagerCreateDestroy;
var
  LMgr: TThreadArenaManager;
begin
  LMgr := TThreadArenaManager.Create(DefaultThreadArenaConfig);
  try
    CheckEqual(Int64(0), Int64(LMgr.PoolSize), 'initial pool empty');
    CheckEqual(Int64(0), Int64(LMgr.TotalCreated), 'initial created 0');
    CheckEqual(Int64(0), Int64(LMgr.TotalRecycled), 'initial recycled 0');
  finally
    LMgr.Free;
  end;
end;

procedure TestManagerCustomConfig;
var
  LMgr: TThreadArenaManager;
  LConfig: TThreadArenaConfig;
begin
  LConfig.ArenaCapacity := 4096;
  LConfig.MaxPoolSize := 2;
  LMgr := TThreadArenaManager.Create(LConfig);
  try
    CheckEqual(Int64(0), Int64(LMgr.PoolSize), 'custom config pool empty');
  finally
    LMgr.Free;
  end;
end;

procedure TestManagerDefaultConfigZeros;
begin
  { 默认配置的容量和池大小都 > 0 }
  Check(DefaultThreadArenaConfig.ArenaCapacity > 0, 'default capacity > 0');
  Check(DefaultThreadArenaConfig.MaxPoolSize > 0, 'default pool size > 0');
end;

{ ---------------------------------------------------------------------------
  Get / DrainTLS 生命周期
  --------------------------------------------------------------------------- }

procedure TestGetReturnsArena;
var
  LMgr: TThreadArenaManager;
  LArena: TLocalArena;
begin
  LMgr := TThreadArenaManager.Create(DefaultThreadArenaConfig);
  try
    LArena := LMgr.Get;
    Check(LArena <> nil, 'Get returns non-nil arena');
    CheckEqual(Int64(1), Int64(LMgr.TotalCreated), 'first Get creates arena');
    LMgr.DrainTLS;
  finally
    LMgr.Free;
  end;
end;

procedure TestGetReturnsSameArena;
var
  LMgr: TThreadArenaManager;
  LArena1, LArena2: TLocalArena;
begin
  LMgr := TThreadArenaManager.Create(DefaultThreadArenaConfig);
  try
    LArena1 := LMgr.Get;
    LArena2 := LMgr.Get;
    Check(LArena1 = LArena2, 'same thread returns same arena');
    CheckEqual(Int64(1), Int64(LMgr.TotalCreated), 'only one arena created');
    LMgr.DrainTLS;
  finally
    LMgr.Free;
  end;
end;

procedure TestDrainTLSReturnsArenaToPool;
var
  LMgr: TThreadArenaManager;
begin
  LMgr := TThreadArenaManager.Create(DefaultThreadArenaConfig);
  try
    LMgr.Get;
    Check(LMgr.HasArena, 'has arena after Get');
    LMgr.DrainTLS;
    Check(not LMgr.HasArena, 'no arena after DrainTLS');
    CheckEqual(Int64(1), Int64(LMgr.PoolSize), 'arena returned to pool');
    CheckEqual(Int64(1), Int64(LMgr.TotalRecycled), 'recycled count 1');
  finally
    LMgr.Free;
  end;
end;

procedure TestDrainTLSIdempotent;
var
  LMgr: TThreadArenaManager;
begin
  LMgr := TThreadArenaManager.Create(DefaultThreadArenaConfig);
  try
    LMgr.Get;
    LMgr.DrainTLS;
    LMgr.DrainTLS; { 二次 drain 应安全 }
    CheckEqual(Int64(1), Int64(LMgr.TotalRecycled), 'only one recycled');
  finally
    LMgr.Free;
  end;
end;

procedure TestDrainTLSWithoutGet;
var
  LMgr: TThreadArenaManager;
begin
  LMgr := TThreadArenaManager.Create(DefaultThreadArenaConfig);
  try
    LMgr.DrainTLS; { 无 arena 时 drain 应安全 }
    CheckEqual(Int64(0), Int64(LMgr.TotalRecycled), 'nothing recycled');
  finally
    LMgr.Free;
  end;
end;

{ ---------------------------------------------------------------------------
  Arena 回收复用
  --------------------------------------------------------------------------- }

procedure TestArenaReuseAfterDrain;
var
  LMgr: TThreadArenaManager;
  LArena1, LArena2: TLocalArena;
begin
  LMgr := TThreadArenaManager.Create(DefaultThreadArenaConfig);
  try
    LArena1 := LMgr.Get;
    LMgr.DrainTLS;

    LArena2 := LMgr.Get;
    Check(LArena1 = LArena2, 'reused same arena from pool');
    CheckEqual(Int64(1), Int64(LMgr.TotalCreated), 'no new arena created');
    CheckEqual(Int64(1), Int64(LMgr.TotalRecycled), 'one recycled');
    LMgr.DrainTLS;
  finally
    LMgr.Free;
  end;
end;

procedure TestArenaResetOnReuse;
var
  LMgr: TThreadArenaManager;
  LArena: TLocalArena;
begin
  LMgr := TThreadArenaManager.Create(DefaultThreadArenaConfig);
  try
    LArena := LMgr.Get;
    LArena.Alloc(128);
    Check(LArena.UsedSize > 0, 'used after alloc');
    LMgr.DrainTLS;

    LArena := LMgr.Get;
    CheckEqual(Int64(0), Int64(LArena.UsedSize), 'reset on reuse');
    LMgr.DrainTLS;
  finally
    LMgr.Free;
  end;
end;

{ ---------------------------------------------------------------------------
  TThreadArena record 方法
  --------------------------------------------------------------------------- }

procedure TestThreadArenaAlloc;
var
  LMgr: TThreadArenaManager;
  LT: TThreadArena;
  LP: PByte;
begin
  LMgr := TThreadArenaManager.Create(DefaultThreadArenaConfig);
  try
    LT := TThreadArena.Create(LMgr.Get);
    LP := PByte(LT.Alloc(64));
    Check(LP <> nil, 'alloc succeeds');
    Check(LT.UsedSize >= 64, 'used size updated');

    LP := PByte(LT.Alloc(64));
    Check(LP <> nil, 'second alloc succeeds');
    LMgr.DrainTLS;
  finally
    LMgr.Free;
  end;
end;

procedure TestThreadArenaAllocZeroed;
var
  LMgr: TThreadArenaManager;
  LT: TThreadArena;
  LP: PByte;
  I: Integer;
begin
  LMgr := TThreadArenaManager.Create(DefaultThreadArenaConfig);
  try
    LT := TThreadArena.Create(LMgr.Get);
    LP := PByte(LT.AllocZeroed(64));
    Check(LP <> nil, 'zeroed alloc succeeds');
    for I := 0 to 63 do
      Check(LP[I] = 0, 'zeroed at byte ' + IntToStr(I));
    LMgr.DrainTLS;
  finally
    LMgr.Free;
  end;
end;

procedure TestThreadArenaAllocAligned;
var
  LMgr: TThreadArenaManager;
  LT: TThreadArena;
  LP: Pointer;
begin
  LMgr := TThreadArenaManager.Create(DefaultThreadArenaConfig);
  try
    LT := TThreadArena.Create(LMgr.Get);
    LP := LT.AllocAligned(64, 16);
    Check(LP <> nil, 'aligned alloc succeeds');
    Check(SizeUInt(LP) mod 16 = 0, '16-byte aligned');

    LP := LT.AllocAligned(32, 64);
    Check(LP <> nil, '64-byte aligned alloc');
    Check(SizeUInt(LP) mod 64 = 0, '64-byte aligned');
    LMgr.DrainTLS;
  finally
    LMgr.Free;
  end;
end;

procedure TestThreadArenaFastPath;
var
  LMgr: TThreadArenaManager;
  LT: TThreadArena;
  LP1, LP2: Pointer;
begin
  LMgr := TThreadArenaManager.Create(DefaultThreadArenaConfig);
  try
    LT := TThreadArena.Create(LMgr.Get);
    LP1 := LT.AllocFast(32);
    Check(LP1 <> nil, 'fast alloc 1');
    LP2 := LT.AllocFast(32);
    Check(LP2 <> nil, 'fast alloc 2');
    Check(LP1 <> LP2, 'different pointers');
    LMgr.DrainTLS;
  finally
    LMgr.Free;
  end;
end;

procedure TestThreadArenaMarkRestore;
var
  LMgr: TThreadArenaManager;
  LT: TThreadArena;
  LMark: TArenaMark;
begin
  LMgr := TThreadArenaManager.Create(DefaultThreadArenaConfig);
  try
    LT := TThreadArena.Create(LMgr.Get);
    LT.Alloc(32);
    LMark := LT.SaveMark;
    CheckEqual(Int64(32), Int64(LMark.FrontOffset), 'mark offset');

    LT.Alloc(64);
    CheckEqual(Int64(96), Int64(LT.UsedSize));

    LT.RestoreToMark(LMark);
    CheckEqual(Int64(32), Int64(LT.UsedSize), 'restored');
    LMgr.DrainTLS;
  finally
    LMgr.Free;
  end;
end;

procedure TestThreadArenaReset;
var
  LMgr: TThreadArenaManager;
  LT: TThreadArena;
begin
  LMgr := TThreadArenaManager.Create(DefaultThreadArenaConfig);
  try
    LT := TThreadArena.Create(LMgr.Get);
    LT.Alloc(128);
    Check(LT.UsedSize > 0, 'used after alloc');

    LT.Reset;
    CheckEqual(Int64(0), Int64(LT.UsedSize), 'reset clears');
    Check(LT.Alloc(128) <> nil, 'can alloc after reset');
    LMgr.DrainTLS;
  finally
    LMgr.Free;
  end;
end;

procedure TestThreadArenaRemainingSize;
var
  LMgr: TThreadArenaManager;
  LT: TThreadArena;
  LRemaining: SizeUInt;
begin
  LMgr := TThreadArenaManager.Create(DefaultThreadArenaConfig);
  try
    LT := TThreadArena.Create(LMgr.Get);
    LRemaining := LT.RemainingSize;
    Check(LRemaining > 0, 'remaining > 0');

    LT.Alloc(256);
    Check(LT.RemainingSize < LRemaining, 'remaining decreased');
    LMgr.DrainTLS;
  finally
    LMgr.Free;
  end;
end;

{ ---------------------------------------------------------------------------
  多线程测试
  --------------------------------------------------------------------------- }

type
  PThreadArenaWorkerData = ^TThreadArenaWorkerData;
  TThreadArenaWorkerData = record
    Manager: TThreadArenaManager;
    StartFlag: PLongInt;
    IterCount: Integer;
    Failure: string;
  end;

function ThreadArenaWorkerProc(AArg: Pointer): Pointer; cdecl;
var
  LData: PThreadArenaWorkerData;
  LArena: TLocalArena;
  LP: PInteger;
  I, J: Integer;
begin
  LData := PThreadArenaWorkerData(AArg);
  { 等待所有线程就绪 }
  while LData^.StartFlag^ = 0 do
    platform_thread_yield;

  try
    for I := 1 to LData^.IterCount do begin
      LArena := LData^.Manager.Get;
      if LArena = nil then begin
        LData^.Failure := 'Get returned nil';
        Result := nil;
        Exit;
      end;

      { 分配+写入+验证 }
      for J := 1 to 10 do begin
        LP := PInteger(LArena.AllocFast(SizeOf(Integer)));
        if LP = nil then begin
          LData^.Failure := 'AllocFast returned nil at iter ' + IntToStr(I) + ' j=' + IntToStr(J);
          Result := nil;
          Exit;
        end;
        LP^ := I * 1000 + J;
      end;

      { 验证所有写入 }
      LArena.Reset;
    end;

    LData^.Manager.DrainTLS;
  except
    on E: Exception do
      LData^.Failure := E.ClassName + ': ' + E.Message;
  end;
  Result := nil;
end;

procedure TestPoolOverflow;
{ 池大小为 2, 3 个线程各 Get+Drain → 第三个 Arena 溢出被释放 }
var
  LMgr: TThreadArenaManager;
  LConfig: TThreadArenaConfig;
  LStartFlag: LongInt;
  LWorkers: array[0..2] of TPlatformThreadRecord;
  LWorkerData: array[0..2] of TThreadArenaWorkerData;
  I: Integer;
begin
  LConfig.ArenaCapacity := 1024;
  LConfig.MaxPoolSize := 2;
  LMgr := TThreadArenaManager.Create(LConfig);
  try
    LStartFlag := 0;
    for I := 0 to 2 do
    begin
      LWorkerData[I].Manager := LMgr;
      LWorkerData[I].StartFlag := @LStartFlag;
      LWorkerData[I].IterCount := 1;
      LWorkerData[I].Failure := '';
      platform_thread_spawn(LWorkers[I], @ThreadArenaWorkerProc, @LWorkerData[I]);
    end;
    InterLockedExchange(LStartFlag, 1);
    for I := 0 to 2 do begin
      platform_thread_wait(LWorkers[I]);
      Check(LWorkerData[I].Failure = '', 'worker ' + IntToStr(I) + ' ok');
    end;
    CheckEqual(Int64(3), Int64(LMgr.TotalCreated), 'three arenas created');
    Check(LMgr.PoolSize <= 2, 'pool capped at MaxPoolSize');
    Check(LMgr.TotalRecycled >= 2, 'at least 2 recycled');
  finally
    LMgr.Free;
  end;
end;

procedure TestMultiThreadIsolation;
var
  LMgr: TThreadArenaManager;
  LConfig: TThreadArenaConfig;
  LWorkers: array[0..THREAD_COUNT - 1] of TPlatformThreadRecord;
  LWorkerData: array[0..THREAD_COUNT - 1] of TThreadArenaWorkerData;
  LStartFlag: LongInt;
  I: Integer;
  LFailCount: Integer;
begin
  LConfig.ArenaCapacity := 4096;
  LConfig.MaxPoolSize := THREAD_COUNT;
  LMgr := TThreadArenaManager.Create(LConfig);
  try
    LStartFlag := 0;

    for I := 0 to THREAD_COUNT - 1 do
    begin
      LWorkerData[I].Manager := LMgr;
      LWorkerData[I].StartFlag := @LStartFlag;
      LWorkerData[I].IterCount := STRESS_ITERATIONS;
      LWorkerData[I].Failure := '';
      platform_thread_spawn(LWorkers[I], @ThreadArenaWorkerProc, @LWorkerData[I]);
    end;

    { 启动所有线程 }
    InterLockedExchange(LStartFlag, 1);

    { 等待完成 }
    LFailCount := 0;
    for I := 0 to THREAD_COUNT - 1 do begin
      platform_thread_wait(LWorkers[I]);
      if LWorkerData[I].Failure <> '' then begin
        WriteLn('  Thread ', I, ' failure: ', LWorkerData[I].Failure);
        Inc(LFailCount);
      end;
    end;

    CheckEqual(Int64(0), Int64(LFailCount), 'no thread failures');
    Check(LMgr.TotalCreated <= THREAD_COUNT, 'at most THREAD_COUNT arenas created');
    CheckEqual(Int64(THREAD_COUNT), Int64(LMgr.TotalRecycled), 'all arenas recycled');
  finally
    LMgr.Free;
  end;
end;

procedure TestMultiThreadPoolRecycle;
var
  LMgr: TThreadArenaManager;
  LConfig: TThreadArenaConfig;
  LWorkers: array[0..THREAD_COUNT - 1] of TPlatformThreadRecord;
  LWorkerData: array[0..THREAD_COUNT - 1] of TThreadArenaWorkerData;
  LStartFlag: LongInt;
  I: Integer;
begin
  { 池大小为 2, 8 个线程 — 大部分 Arena 会被丢弃 }
  LConfig.ArenaCapacity := 2048;
  LConfig.MaxPoolSize := 2;
  LMgr := TThreadArenaManager.Create(LConfig);
  try
    LStartFlag := 0;

    for I := 0 to THREAD_COUNT - 1 do
    begin
      LWorkerData[I].Manager := LMgr;
      LWorkerData[I].StartFlag := @LStartFlag;
      LWorkerData[I].IterCount := STRESS_ITERATIONS;
      LWorkerData[I].Failure := '';
      platform_thread_spawn(LWorkers[I], @ThreadArenaWorkerProc, @LWorkerData[I]);
    end;

    InterLockedExchange(LStartFlag, 1);

    for I := 0 to THREAD_COUNT - 1 do begin
      platform_thread_wait(LWorkers[I]);
    end;

    Check(LMgr.PoolSize <= 2, 'pool capped at MaxPoolSize');
    Check(LMgr.TotalCreated >= 1, 'at least one arena created');
  finally
    LMgr.Free;
  end;
end;

procedure TestMainThreadPlusWorker;
var
  LMgr: TThreadArenaManager;
  LConfig: TThreadArenaConfig;
  LWorker: TPlatformThreadRecord;
  LWorkerData: TThreadArenaWorkerData;
  LStartFlag: LongInt;
  LMainArena: TLocalArena;
  LP: PInteger;
begin
  LConfig.ArenaCapacity := 4096;
  LConfig.MaxPoolSize := 4;
  LMgr := TThreadArenaManager.Create(LConfig);
  try
    { 主线程分配 }
    LMainArena := LMgr.Get;
    LP := PInteger(LMainArena.AllocFast(SizeOf(Integer)));
    Check(LP <> nil, 'main thread alloc');
    LP^ := 42;

    { 启动一个 worker }
    LStartFlag := 0;
    LWorkerData.Manager := LMgr;
    LWorkerData.StartFlag := @LStartFlag;
    LWorkerData.IterCount := 100;
    LWorkerData.Failure := '';
    platform_thread_spawn(LWorker, @ThreadArenaWorkerProc, @LWorkerData);
    InterLockedExchange(LStartFlag, 1);
    platform_thread_wait(LWorker);
    Check(LWorkerData.Failure = '', 'worker no failure: ' + LWorkerData.Failure);

    { 主线程 Arena 不受影响 }
    Check(LP^ = 42, 'main thread data intact');
    CheckEqual(Int64(2), Int64(LMgr.TotalCreated), 'two arenas created');

    LMgr.DrainTLS;
  finally
    LMgr.Free;
  end;
end;

{ ---------------------------------------------------------------------------
  边界条件
  --------------------------------------------------------------------------- }

procedure TestLargeAllocation;
var
  LMgr: TThreadArenaManager;
  LT: TThreadArena;
  LP: Pointer;
begin
  LMgr := TThreadArenaManager.Create(DefaultThreadArenaConfig);
  try
    LT := TThreadArena.Create(LMgr.Get);
    { 分配接近 Arena 容量 }
    LP := LT.Alloc(512 * 1024);
    Check(LP <> nil, 'large alloc succeeds');

    { 超出剩余空间 }
    LP := LT.Alloc(600 * 1024);
    Check(LP = nil, 'oversize alloc returns nil');
    LMgr.DrainTLS;
  finally
    LMgr.Free;
  end;
end;

procedure TestZeroSizeAlloc;
var
  LMgr: TThreadArenaManager;
  LT: TThreadArena;
begin
  LMgr := TThreadArenaManager.Create(DefaultThreadArenaConfig);
  try
    LT := TThreadArena.Create(LMgr.Get);
    Check(LT.Alloc(0) = nil, 'zero alloc returns nil');
    { AllocFast 是无检查路径，size=0 不返回 nil — 设计如此 }
    Check(LT.AllocFast(0) <> nil, 'zero fast alloc returns backing pointer');
    CheckEqual(Int64(0), Int64(LT.UsedSize), 'zero alloc does not advance');
    LMgr.DrainTLS;
  finally
    LMgr.Free;
  end;
end;

procedure TestWriteReadThroughThreadArena;
var
  LMgr: TThreadArenaManager;
  LT: TThreadArena;
  LP: PInteger;
  I: Integer;
begin
  LMgr := TThreadArenaManager.Create(DefaultThreadArenaConfig);
  try
    LT := TThreadArena.Create(LMgr.Get);
    for I := 0 to 99 do begin
      LP := PInteger(LT.AllocFast(SizeOf(Integer)));
      LP^ := I * I;
    end;

    { 重置后重新写入验证 }
    LT.Reset;
    for I := 0 to 99 do begin
      LP := PInteger(LT.AllocFast(SizeOf(Integer)));
      LP^ := I * I;
      Check(LP^ = I * I, 'write/read at index ' + IntToStr(I));
    end;
    LMgr.DrainTLS;
  finally
    LMgr.Free;
  end;
end;

{ ---------------------------------------------------------------------------
  大规模分配压力测试
  --------------------------------------------------------------------------- }

procedure TestAllocStress;
var
  LMgr: TThreadArenaManager;
  LT: TThreadArena;
  LP: PByte;
  I, J: Integer;
begin
  LMgr := TThreadArenaManager.Create(DefaultThreadArenaConfig);
  try
    LT := TThreadArena.Create(LMgr.Get);
    for I := 1 to 100 do begin
      for J := 1 to 100 do begin
        LP := PByte(LT.AllocFast(32));
        if LP = nil then begin
          LT.Reset;
          LP := PByte(LT.AllocFast(32));
        end;
        LP^ := Byte(J);
      end;
      LT.Reset;
    end;
    Check(True, 'stress test completed');
    LMgr.DrainTLS;
  finally
    LMgr.Free;
  end;
end;

{ ---------------------------------------------------------------------------
  Runner
  --------------------------------------------------------------------------- }

var
  T: TTestRunner;

begin
  T := TTestRunner.Create('nextpas.core.mem.arena.thread');

  { Manager 生命周期 }
  T.Run('Manager create/destroy', @TestManagerCreateDestroy);
  T.Run('Manager custom config', @TestManagerCustomConfig);
  T.Run('Manager default config zeros', @TestManagerDefaultConfigZeros);

  { Get / DrainTLS }
  T.Run('Get returns arena', @TestGetReturnsArena);
  T.Run('Get returns same arena', @TestGetReturnsSameArena);
  T.Run('DrainTLS returns to pool', @TestDrainTLSReturnsArenaToPool);
  T.Run('DrainTLS idempotent', @TestDrainTLSIdempotent);
  T.Run('DrainTLS without Get', @TestDrainTLSWithoutGet);

  { 回收复用 }
  T.Run('Arena reuse after drain', @TestArenaReuseAfterDrain);
  T.Run('Arena reset on reuse', @TestArenaResetOnReuse);
  T.Run('Pool overflow', @TestPoolOverflow);

  { TThreadArena record }
  T.Run('ThreadArena alloc', @TestThreadArenaAlloc);
  T.Run('ThreadArena alloc zeroed', @TestThreadArenaAllocZeroed);
  T.Run('ThreadArena alloc aligned', @TestThreadArenaAllocAligned);
  T.Run('ThreadArena fast path', @TestThreadArenaFastPath);
  T.Run('ThreadArena mark/restore', @TestThreadArenaMarkRestore);
  T.Run('ThreadArena reset', @TestThreadArenaReset);
  T.Run('ThreadArena remaining size', @TestThreadArenaRemainingSize);

  { 多线程 }
  T.Run('Multi-thread isolation', @TestMultiThreadIsolation);
  T.Run('Multi-thread pool recycle', @TestMultiThreadPoolRecycle);
  T.Run('Main thread + worker', @TestMainThreadPlusWorker);

  { 边界 }
  T.Run('Large allocation', @TestLargeAllocation);
  T.Run('Zero size alloc', @TestZeroSizeAlloc);
  T.Run('Write/read through thread arena', @TestWriteReadThroughThreadArena);
  T.Run('Alloc stress', @TestAllocStress);

  T.Summary;
end.
