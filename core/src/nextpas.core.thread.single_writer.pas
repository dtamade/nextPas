unit nextpas.core.thread.single_writer;

{** @desc 单写线程同步委托队列（Single-Writer Sync Delegate Queue）
  @details 单执行线程 + 有界 FIFO 队列 + 同步委托：
    调用方 ExecuteSync 提交委托并阻塞等待完成，执行线程逐个执行；
    委托异常经 AcquireExceptionObject 所有权转移回传调用方（nil=成功）。
    队列满时提交方阻塞（有界背压，绝不丢委托）；停机后已入队委托仍排空。
  @design 与 lockfree.actor 互补：actor 是 MPSC 消息流（满返回 arMailboxFull，
    调用方丢弃）；本队列是「同步委托」——调用方阻塞等结果，满则背压阻塞，
    异常跨线程转移。典型用途：SQLite 单写者串行化、设备/文件写互斥执行体、
    任何「单线程持有资源 + 多线程同步请求」的串行化。
  @concurrency Thread-safe：ExecuteSync 多调用方可并发提交；执行线程自身
    调用 ExecuteSync 内联执行（不入队，防自死锁）；Shutdown 可任意线程调用。
    执行线程 Start 后 Execute 内先执行 AOnStart 钩子一次（连接级初始化）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.thread.base,     { TWorkerThread / TThreadTask }
  nextpas.core.sync,            { Mutex / CondVar / Semaphore }
  nextpas.core.errors,          { ENextPasError / EArgumentError }
  nextpas.core.exception,       { Exception 兼容面 }
  nextpas.core.platform.thread; { TPlatformThreadToken / platform_thread_self }

type
  { 同步委托被拒：队列已 Shutdown。 }
  EDelegateQueueClosed = class(ENextPasError);

  { 同步委托被拒：执行线程已异常死亡（启动钩子失败/Execute 崩溃）。 }
  EDelegateWriterFailed = class(ENextPasError);

  { 栈上请求记录：调用方在 ExecuteSync 返回前不得离开作用域
    （严格同步委托，回调不逃逸；Done 保证执行完成先于返回）。 }
  TDelegateRequest = record
    Proc: TThreadTask;
    Done: ISemaphore;
    Error: Exception;
  end;
  PDelegateRequest = ^TDelegateRequest;

  {** @desc 单写线程同步委托队列（线程安全）。 }
  TSingleWriterThread = class(TWorkerThread)
  private
    FCapacity: Integer;
    FQueueMutex: INativeMutex;
    FQueueCond: ICondVar;
    FProcs: array of PDelegateRequest;
    FShutdown: Boolean;
    FSelfToken: TPlatformThreadToken;
    FOnStart: TThreadTask;
    function PopOrWait: PDelegateRequest;
    { 写者异常死亡时排空队列：逐个回传失败异常并唤醒等待者
      （保证任何已入队 ExecuteSync 都能返回，挂等永不发生）。 }
    procedure FailPending;
  protected
    procedure Execute; override;
  public
    { ACapacity：有界队列上限（满则提交方阻塞背压）；AOnStart：执行线程
      启动钩子（Execute 首行执行一次；失败 ⇒ 写者死亡，后续 ExecuteSync
      立即抛 EDelegateWriterFailed）。 }
    constructor Create(const ACapacity: Integer;
      const AOnStart: TThreadTask = nil);
    destructor Destroy; override;
    { 同步委托：入队并阻塞至执行线程完成，返回委托异常（nil=成功；
      调用方负责 raise 重抛并释放）。执行线程自身调用时内联执行（不入队）。
      队列已 Shutdown ⇒ 抛 EDelegateQueueClosed；写者已异常死亡 ⇒ 抛
      EDelegateWriterFailed（不挂等；同步委托契约：写者健康是等待前提）。 }
    function ExecuteSync(const AProc: TThreadTask): Exception;
    { 当前调用线程即执行线程（内联判定）。 }
    function IsSelf: Boolean;
    { 停机：置标志并广播唤醒；已入队委托仍被排空（执行完）。 }
    procedure Shutdown;
  end;

implementation

constructor TSingleWriterThread.Create(const ACapacity: Integer;
  const AOnStart: TThreadTask);
begin
  if ACapacity < 1 then
    raise EArgumentError.Create('single writer: capacity must be >= 1');
  inherited Create;
  FCapacity := ACapacity;
  FQueueMutex := Mutex;
  FQueueCond := CondVar;
  FProcs := nil;
  FShutdown := False;
  FOnStart := AOnStart;
end;

destructor TSingleWriterThread.Destroy;
begin
  { 队列非空（未停机残留）时按接口契约不代行清理：请求记录在调用方栈上，
    归属调用方；此处只释放容器与同步原语。 }
  FProcs := nil;
  FOnStart := nil;
  FQueueCond := nil;
  FQueueMutex := nil;
  inherited Destroy;
end;

function TSingleWriterThread.IsSelf: Boolean;
begin
  Result := platform_thread_self = FSelfToken;
end;

function TSingleWriterThread.ExecuteSync(const AProc: TThreadTask): Exception;
var
  LReq: TDelegateRequest;
begin
  { 自调用（执行线程内嵌委托）：内联执行不入队——事务/资源由调用方
    助手计数式嵌套管理，防自死锁（等自己完成的信号量）。 }
  if IsSelf then
  begin
    Result := nil;
    try
      AProc;
    except
      on E: Exception do
        Result := Exception(AcquireExceptionObject);
    end;
    Exit;
  end;
  { 写者已异常死亡（启动钩子失败/Execute 崩溃）→ 立即失败，不挂等。
    同步委托契约：写者健康是等待前提。 }
  if HasException then
    raise EDelegateWriterFailed.Create(
      'single writer thread exited unexpectedly: ' + ExceptionMessage);
  LReq.Proc := AProc;
  LReq.Done := Semaphore(0);
  LReq.Error := nil;
  FQueueMutex.Acquire;
  try
    if FShutdown then
      raise EDelegateQueueClosed.Create(
        'single writer queue is closed; delegate rejected');
    { 背压：队列满则阻塞，绝不让委托无限堆积。 }
    while (Length(FProcs) >= FCapacity) and (not FShutdown) do
      FQueueCond.Wait(FQueueMutex);
    if FShutdown then
      raise EDelegateQueueClosed.Create(
        'single writer queue is closed; delegate rejected');
    SetLength(FProcs, Length(FProcs) + 1);
    FProcs[High(FProcs)] := @LReq;
    FQueueCond.Signal;
  finally
    FQueueMutex.Release;
  end;
  { 等待执行线程完成（Done 保证执行完成先于返回；栈上请求记录安全）。 }
  LReq.Done.Acquire;
  Result := LReq.Error;
end;

function TSingleWriterThread.PopOrWait: PDelegateRequest;
var
  I: Integer;
begin
  FQueueMutex.Acquire;
  try
    while (Length(FProcs) = 0) and (not FShutdown) do
      FQueueCond.Wait(FQueueMutex);
    if Length(FProcs) = 0 then
      Exit(nil);            { 关闭且队列空：线程退出 }
    Result := FProcs[0];
    for I := 0 to Length(FProcs) - 2 do
      FProcs[I] := FProcs[I + 1];
    SetLength(FProcs, Length(FProcs) - 1);
    FQueueCond.Signal;      { 唤醒被背压阻塞的提交方 }
  finally
    FQueueMutex.Release;
  end;
end;

procedure TSingleWriterThread.Shutdown;
begin
  FQueueMutex.Acquire;
  try
    FShutdown := True;
    FQueueCond.Broadcast;
  finally
    FQueueMutex.Release;
  end;
end;

procedure TSingleWriterThread.FailPending;
var
  I: Integer;
begin
  FQueueMutex.Acquire;
  try
    for I := 0 to Length(FProcs) - 1 do
    begin
      { 每个等待者独立异常实例（所有权各自转移，调用方各自释放）。 }
      FProcs[I]^.Error := EDelegateWriterFailed.Create(
        'single writer thread exited before executing pending delegate');
      FProcs[I]^.Done.Release;
    end;
    FProcs := nil;
  finally
    FQueueMutex.Release;
  end;
end;

procedure TSingleWriterThread.Execute;
var
  LReq: PDelegateRequest;
begin
  FSelfToken := platform_thread_self;
  try
    { 启动钩子：连接级初始化（如 SQLite PRAGMA）；失败 ⇒ 写者死亡，
      FailPending 排空队列后异常上抛（TWorkerThread 捕获 ⇒ HasException）。 }
    if FOnStart <> nil then
      FOnStart;
    while True do
    begin
      LReq := PopOrWait;
      if LReq = nil then
        Break;
      LReq^.Error := nil;
      try
        LReq^.Proc;
      except
        on E: Exception do
        begin
          { 接管所有权后跨线程转移；调用方 raise 时由调用方解旋释放。 }
          LReq^.Error := Exception(AcquireExceptionObject);
        end;
      end;
      LReq^.Done.Release;
    end;
  except
    on E: Exception do
    begin
      FailPending;
      raise;
    end;
  end;
end;

end.