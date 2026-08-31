program test_thread_single_writer;

{ nextpas.core.thread.single_writer 聚焦门禁：
  - 同步委托：ExecuteSync 阻塞至执行线程完成，值回传、异常所有权回传；
  - FIFO 顺序；有界背压（满则提交方阻塞，绝不丢委托）；
  - 自调用内联（写线程内 ExecuteSync 不入队，防自死锁）；启动钩子一次；
  - 停机排空（已入队委托仍执行完，之后拒绝新委托）；
  - 写者异常死亡：已入队等待者逐个回传失败异常（挂等永不发生）；
  - 并发提交线程安全。
  全程 heaptrc 0 unfreed（common.mk HEAPTRC_GATE=1）。 }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  SysUtils,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.thread.base,
  nextpas.core.platform.thread,
  nextpas.core.platform.time,
  nextpas.core.thread.single_writer;

type
  { 占住写线程的辅助提交者（背压窗口：写线程 busy + 队列满）。 }
  TBlocker = class(TWorkerThread)
  protected
    procedure Execute; override;
  end;

  { 背压提交者：B 入队（队列空），C 遇队列满（capacity=1, B 在队）→ 阻塞。 }
  TSub = class(TWorkerThread)
  private
    FWhich: Integer;
    FElapsedNs: UInt64;
    FFailures: Integer;
  protected
    procedure Execute; override;
  end;

var
  T: TTestSuite;
  { handler 共享上下文（匿名过程捕获外层局部变量在本 FPC/选项组合下
    解析不稳，统一走全局上下文）。 }
  GW: TSingleWriterThread;
  GMainToken: TPlatformThreadToken;
  GWrToken: TPlatformThreadToken;
  GVal: Int64 = 0;
  GSeq: array[0..127] of Integer;
  GSeqN: Integer = 0;
  GStartCount: Integer = 0;
  GIsSelf: Boolean = False;
  GDone: Int32 = 0;

procedure TBlocker.Execute;
var
  LErr: Exception;
begin
  LErr := GW.ExecuteSync(procedure
  begin
    GVal := 77;   { 写线程执行标记 }
    platform_thread_sleep_ns(80000000);   { 占住写线程 80ms }
  end);
  LErr.Free;
end;

procedure TSub.Execute;
var
  LStart: UInt64;
  LErr: Exception;
begin
  FFailures := 0;
  LStart := platform_monotonic_ns;
  if FWhich = 1 then
    LErr := GW.ExecuteSync(procedure
    begin
      GVal := 1;
    end)
  else
    LErr := GW.ExecuteSync(procedure
    begin
      GVal := 2;
    end);
  FElapsedNs := platform_monotonic_ns - LStart;
  if LErr <> nil then
  begin
    Inc(FFailures);
    LErr.Free;
  end;
end;

{ ==================== 基本同步委托 ==================== }

procedure TestBasicSyncExecute;
var
  LErr: Exception;
begin
  GVal := 0;
  GWrToken := 0;
  GMainToken := platform_thread_self;
  GW := TSingleWriterThread.Create(8, nil);
  try
    GW.Start;
    LErr := GW.ExecuteSync(procedure
    begin
      GWrToken := platform_thread_self;
      GVal := 42;
    end);
    try
      Check(LErr = nil, 'basic delegate returns nil error');
      CheckEqual(Int64(42), GVal, 'value written on writer thread');
      Check(GWrToken <> GMainToken, 'delegate ran on writer thread');
    finally
      LErr.Free;
    end;
  finally
    GW.Shutdown;
    GW.WaitFor;
    GW.Free;
  end;
end;

{ ==================== 异常所有权回传 ==================== }

procedure TestExceptionReturned;
var
  LErr: Exception;
begin
  GW := TSingleWriterThread.Create(8, nil);
  try
    GW.Start;
    LErr := GW.ExecuteSync(procedure
    begin
      raise EArgumentError.Create('boom from writer');
    end);
    try
      Check(LErr <> nil, 'exception returned to caller');
      Check(LErr is EArgumentError, 'exception type preserved');
      CheckEqual('boom from writer', LErr.Message, 'exception message preserved');
    finally
      LErr.Free;   { 所有权已转移给调用方 }
    end;
    { 写者仍健康：异常回传不杀死写线程。 }
    LErr := GW.ExecuteSync(procedure
    begin
      GVal := 99;
    end);
    try
      Check(LErr = nil, 'writer healthy after exception return');
      CheckEqual(Int64(99), GVal, 'subsequent delegate executes');
    finally
      LErr.Free;
    end;
  finally
    GW.Shutdown;
    GW.WaitFor;
    GW.Free;
  end;
end;

{ ==================== FIFO 顺序 ==================== }

procedure TestFifoOrder;
var
  LErr: Exception;
  LI: Integer;
begin
  GSeqN := 0;
  GW := TSingleWriterThread.Create(8, nil);
  try
    GW.Start;
    for LI := 1 to 16 do
    begin
      LErr := GW.ExecuteSync(procedure
      var
        LOrd: Integer;
      begin
        LOrd := GSeqN;
        Inc(GSeqN);
        GSeq[LOrd] := GSeqN;   { 执行时 GSeqN 已递增 = 提交序号 }
      end);
      try
        Check(LErr = nil, 'fifo delegate ok');
      finally
        LErr.Free;
      end;
    end;
    CheckEqual(Int64(16), GSeqN, 'all delegates executed');
    for LI := 0 to 15 do
      CheckEqual(Int64(LI + 1), GSeq[LI], 'FIFO order preserved');
  finally
    GW.Shutdown;
    GW.WaitFor;
    GW.Free;
  end;
end;

{ ==================== 自调用内联 ==================== }

procedure TestInlineFromWriter;
var
  LErr: Exception;
begin
  GVal := 0;
  GIsSelf := False;
  GW := TSingleWriterThread.Create(8, nil);
  try
    GW.Start;
    LErr := GW.ExecuteSync(procedure
    begin
      { 写线程内嵌委托：必须内联执行（不入队），否则自死锁。 }
      GIsSelf := GW.IsSelf;
      GVal := 7;
    end);
    try
      Check(LErr = nil, 'nested delegate ok');
      CheckEqual(Int64(7), GVal, 'nested delegate ran inline');
      Check(GIsSelf, 'nested delegate observed IsSelf=True');
    finally
      LErr.Free;
    end;
  finally
    GW.Shutdown;
    GW.WaitFor;
    GW.Free;
  end;
end;

{ ==================== 有界背压 ==================== }

procedure TestBackpressure;
var
  LBlocker: TBlocker;
  LB, LC: TSub;
begin
  GW := TSingleWriterThread.Create(1, nil);   { 容量 1：严格背压窗口 }
  try
    GW.Start;
    LBlocker := TBlocker.Create;
    LBlocker.Start;
    { 等写线程进入 sleep 委托（写线程 busy；辅助提交者阻塞等完成）。 }
    platform_thread_sleep_ns(20000000);
    { B：队列空 → 立即入队。C：队列满（B 在队）→ 阻塞至 B 被弹出。 }
    LB := TSub.Create;
    LB.FWhich := 1;
    LB.Start;
    LC := TSub.Create;
    LC.FWhich := 2;
    LC.Start;
    LB.WaitFor;
    LC.WaitFor;
    try
      CheckEqual(Int64(0), LB.FFailures, 'B submitted ok');
      CheckEqual(Int64(0), LC.FFailures, 'C submitted ok');
      Check(LC.FElapsedNs >= 40000000,
        'backpressure: C blocked while queue full (elapsed ' +
        IntToStr(LC.FElapsedNs) + ' ns)');
    finally
      LB.Free;
      LC.Free;
    end;
    LBlocker.WaitFor;
    LBlocker.Free;
  finally
    GW.Shutdown;
    GW.WaitFor;
    GW.Free;
  end;
end;

{ ==================== 启动钩子 ==================== }

procedure TestOnStartHook;
var
  LErr: Exception;
begin
  GStartCount := 0;
  GWrToken := 0;
  GW := TSingleWriterThread.Create(8, procedure
  begin
    Inc(GStartCount);
    GIsSelf := GW.IsSelf;   { 钩子在执行线程内：IsSelf 必为 True }
  end);
  try
    GW.Start;
    LErr := GW.ExecuteSync(procedure
    begin
      GVal := 5;
    end);
    try
      Check(LErr = nil, 'hook delegate ok');
      CheckEqual(Int64(1), GStartCount, 'on-start hook ran exactly once');
      Check(GIsSelf, 'on-start hook ran on writer thread');
    finally
      LErr.Free;
    end;
    LErr := GW.ExecuteSync(procedure
    begin
      GVal := 6;
    end);
    try
      Check(LErr = nil, 'second delegate ok');
      CheckEqual(Int64(1), GStartCount, 'hook did not re-run');
    finally
      LErr.Free;
    end;
  finally
    GW.Shutdown;
    GW.WaitFor;
    GW.Free;
  end;
end;

{ ==================== 停机排空 ==================== }

procedure TestShutdownDrains;
var
  LErr: Exception;
  LClosed: Boolean;
begin
  GSeqN := 0;
  GW := TSingleWriterThread.Create(8, nil);
  try
    GW.Start;
    LErr := GW.ExecuteSync(procedure
    begin
      GSeq[GSeqN] := 1;
      Inc(GSeqN);
    end);
    LErr.Free;
    LErr := GW.ExecuteSync(procedure
    begin
      GSeq[GSeqN] := 2;
      Inc(GSeqN);
    end);
    LErr.Free;
    GW.Shutdown;   { 已入队委托仍排空 }
    GW.WaitFor;    { 排空完成、线程退出 }
    CheckEqual(Int64(2), GSeqN, 'pending delegates drained after shutdown');
    CheckEqual(Int64(1), GSeq[0], 'drain order 1');
    CheckEqual(Int64(2), GSeq[1], 'drain order 2');
    LClosed := False;
    try
      LErr := GW.ExecuteSync(procedure
      begin
      end);
      LErr.Free;
    except
      on E: EDelegateQueueClosed do
        LClosed := True;
    end;
    Check(LClosed, 'ExecuteSync after shutdown raises EDelegateQueueClosed');
  finally
    GW.Free;
  end;
end;

{ ==================== 写者异常死亡不挂等 ==================== }

procedure TestWriterDeathFailsFast;
var
  LErr: Exception;
  LFailed: Boolean;
begin
  GW := TSingleWriterThread.Create(8, procedure
  begin
    platform_thread_sleep_ns(30000000);   { 留出入队窗口 }
    raise EArgumentError.Create('on-start hook failed');
  end);
  try
    GW.Start;
    { 立即提交：钩子抛异常前已入队 → FailPending 回传，绝不挂等。 }
    LErr := GW.ExecuteSync(procedure
    begin
      GVal := 1;
    end);
    LFailed := False;
    try
      if LErr <> nil then
        LFailed := LErr is EDelegateWriterFailed;
    finally
      LErr.Free;
    end;
    Check(LFailed, 'pending delegate failed fast with EDelegateWriterFailed');
    { 写者已死：后续提交立即失败。 }
    LFailed := False;
    try
      LErr := GW.ExecuteSync(procedure
      begin
      end);
      if LErr <> nil then
        LFailed := LErr is EDelegateWriterFailed;
      LErr.Free;
    except
      on E: EDelegateWriterFailed do
        LFailed := True;
    end;
    Check(LFailed, 'subsequent submit fails fast with EDelegateWriterFailed');
    GW.WaitFor;
    Check(GW.HasException, 'writer exception captured by TWorkerThread');
  finally
    GW.Free;
  end;
end;

{ ==================== 并发提交 ==================== }

type
  TSubmitter = class(TWorkerThread)
  private
    FCount: Integer;
    FFailures: Integer;
  protected
    procedure Execute; override;
  end;

procedure TSubmitter.Execute;
var
  LI: Integer;
  LErr: Exception;
begin
  FFailures := 0;
  for LI := 1 to FCount do
  begin
    LErr := GW.ExecuteSync(procedure
    begin
      InterlockedIncrement(GDone);
    end);
    if LErr <> nil then
    begin
      Inc(FFailures);
      LErr.Free;
    end;
  end;
end;

procedure TestConcurrentSubmitters;
var
  LSubs: array[0..2] of TSubmitter;
  LI: Integer;
begin
  GDone := 0;
  GW := TSingleWriterThread.Create(16, nil);
  try
    GW.Start;
    for LI := 0 to 2 do
    begin
      LSubs[LI] := TSubmitter.Create;
      LSubs[LI].FCount := 20;
      LSubs[LI].Start;
    end;
    for LI := 0 to 2 do
    begin
      LSubs[LI].WaitFor;
      CheckEqual(Int64(0), LSubs[LI].FFailures, 'submitter ' + IntToStr(LI) +
        ' had no failures');
      LSubs[LI].Free;
    end;
    CheckEqual(Int64(60), Int64(GDone), 'all 60 concurrent delegates executed');
  finally
    GW.Shutdown;
    GW.WaitFor;
    GW.Free;
  end;
end;

{ ==================== main ==================== }

begin
  T := TTestSuite.Create('core.thread.single_writer');
  T.Test('basic sync execute', @TestBasicSyncExecute);
  T.Test('exception returned', @TestExceptionReturned);
  T.Test('fifo order', @TestFifoOrder);
  T.Test('inline from writer', @TestInlineFromWriter);
  T.Test('backpressure', @TestBackpressure);
  T.Test('on-start hook', @TestOnStartHook);
  T.Test('shutdown drains', @TestShutdownDrains);
  T.Test('writer death fails fast', @TestWriterDeathFailsFast);
  T.Test('concurrent submitters', @TestConcurrentSubmitters);
  if not T.Run then
    Halt(1);
end.