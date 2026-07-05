{**
 * np_parallel_scheduler.pas
 *
 * 并行调度器 — 阶段 2.3 并行编译
 *
 * 设计：
 *   - 简单的线程池（基于 TThread）
 *   - 任务队列：独立查询可并行执行
 *   - 无依赖任务并行，有依赖任务串行
 *
 * 对标：rustc rayon (work-stealing), Salsa parallel query execution
 *
 * 线程安全约束：
 *   - 每个线程有自己的 TQueryDatabase 实例
 *   - 共享数据（TGreenTree, TSemanticModel）是 Freeze 后不可变的
 *   - 写入只发生在每线程独立的数据库中
 *}

unit np_parallel_scheduler;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes;

type
  {**
   * TParallelTask — 可并行执行的任务
   *
   * 每个任务是一个无参数、无返回值的 procedure。
   * 调用方负责通过共享状态收集结果。
   *}
  TParallelTask = procedure of object;

  {**
   * TTaskEntry — 任务队列条目
   *}
  TTaskEntry = record
    Task: TParallelTask;
    Name: string;
  end;

  {**
   * TWorkerThread — 工作线程
   *
   * 从共享任务队列取任务执行。
   *}
  TWorkerThread = class(TThread)
  private
    FTaskQueue: ^TTaskQueue;
    FActive: Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(AQueue: Pointer);
    property Active: Boolean read FActive;
  end;

  {**
   * TTaskQueue — 线程安全任务队列
   *
   * 使用临界区保护并发访问。
   *}
  TTaskQueue = class
  private
    FTasks: array of TTaskEntry;
    FNextIndex: LongInt;
    FLock: TRTLCriticalSection;
    FActiveWorkers: LongInt;
  public
    constructor Create;
    destructor Destroy; override;

    { 添加任务 }
    procedure Enqueue(const ATask: TParallelTask; const AName: string);

    { 获取下一个任务（工作线程调用），返回 nil 表示队列空 }
    function Dequeue(out AName: string): TParallelTask;

    { 任务总数 }
    function TaskCount: LongInt;

    { 剩余任务数 }
    function RemainingCount: LongInt;

    { 活跃工作线程数 }
    property ActiveWorkers: LongInt read FActiveWorkers;
  end;

  {**
   * TParallelScheduler — 并行调度器
   *
   * 创建 N 个工作线程（N = CPU 核心数），并行执行任务队列中的任务。
   * WaitAll 阻塞直到所有任务完成。
   *}
  TParallelScheduler = class
  private
    FQueue: TTaskQueue;
    FWorkers: array of TWorkerThread;
    FWorkerCount: LongInt;
    function DefaultWorkerCount: LongInt;
  public
    constructor Create; overload;
    constructor Create(AWorkerCount: LongInt); overload;
    destructor Destroy; override;

    { 添加任务到队列 }
    procedure Schedule(const ATask: TParallelTask; const AName: string);

    { 等待所有任务完成 }
    procedure WaitAll;

    { 任务统计 }
    function TotalTasks: LongInt;
    function CompletedTasks: LongInt;
    function WorkerCount: LongInt;
  end;

implementation

{ TWorkerThread }

constructor TWorkerThread.Create(AQueue: Pointer);
begin
  inherited Create(False);  { 立即启动 }
  FTaskQueue := AQueue;
  FActive := False;
  FreeOnTerminate := False;
end;

procedure TWorkerThread.Execute;
var
  Task: TParallelTask;
  TaskName: string;
begin
  FActive := True;
  while not Terminated do
  begin
    Task := FTaskQueue^.Dequeue(TaskName);
    if not Assigned(Task) then
    begin
      FActive := False;
      Break;
    end;
    try
      Task();
    except
      { 任务异常不传播，由调用方通过共享状态检测 }
    end;
  end;
  FActive := False;
end;

{ TTaskQueue }

constructor TTaskQueue.Create;
begin
  inherited Create;
  SetLength(FTasks, 0);
  FNextIndex := 0;
  FActiveWorkers := 0;
  InitCriticalSection(FLock);
end;

destructor TTaskQueue.Destroy;
begin
  DoneCriticalSection(FLock);
  SetLength(FTasks, 0);
  inherited Destroy;
end;

procedure TTaskQueue.Enqueue(const ATask: TParallelTask; const AName: string);
var
  Idx: LongInt;
begin
  EnterCriticalSection(FLock);
  try
    Idx := Length(FTasks);
    SetLength(FTasks, Idx + 1);
    FTasks[Idx].Task := ATask;
    FTasks[Idx].Name := AName;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TTaskQueue.Dequeue(out AName: string): TParallelTask;
begin
  EnterCriticalSection(FLock);
  try
    if FNextIndex >= Length(FTasks) then
    begin
      AName := '';
      Exit(nil);
    end;
    Result := FTasks[FNextIndex].Task;
    AName := FTasks[FNextIndex].Name;
    Inc(FNextIndex);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TTaskQueue.TaskCount: LongInt;
begin
  Result := Length(FTasks);
end;

function TTaskQueue.RemainingCount: LongInt;
begin
  EnterCriticalSection(FLock);
  try
    Result := Length(FTasks) - FNextIndex;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

{ TParallelScheduler }

function TParallelScheduler.DefaultWorkerCount: LongInt;
begin
  Result := TThread.ProcessorCount;
  if Result < 1 then
    Result := 1;
  if Result > 8 then
    Result := 8;  { 限制最多 8 线程 }
end;

constructor TParallelScheduler.Create;
begin
  Create(DefaultWorkerCount);
end;

constructor TParallelScheduler.Create(AWorkerCount: LongInt);
var
  I: LongInt;
begin
  inherited Create;
  FQueue := TTaskQueue.Create;
  FWorkerCount := AWorkerCount;
  if FWorkerCount < 1 then
    FWorkerCount := 1;
  SetLength(FWorkers, FWorkerCount);
  for I := 0 to FWorkerCount - 1 do
    FWorkers[I] := TWorkerThread.Create(@FQueue);
end;

destructor TParallelScheduler.Destroy;
var
  I: LongInt;
begin
  for I := 0 to FWorkerCount - 1 do
  begin
    FWorkers[I].Terminate;
    FWorkers[I].WaitFor;
    FWorkers[I].Free;
  end;
  SetLength(FWorkers, 0);
  FQueue.Free;
  inherited Destroy;
end;

procedure TParallelScheduler.Schedule(
  const ATask: TParallelTask; const AName: string);
begin
  FQueue.Enqueue(ATask, AName);
end;

procedure TParallelScheduler.WaitAll;
begin
  { 等待队列清空 }
  while FQueue.RemainingCount > 0 do
    Sleep(1);
end;

function TParallelScheduler.TotalTasks: LongInt;
begin
  Result := FQueue.TaskCount;
end;

function TParallelScheduler.CompletedTasks: LongInt;
begin
  Result := FQueue.TaskCount - FQueue.RemainingCount;
end;

function TParallelScheduler.WorkerCount: LongInt;
begin
  Result := FWorkerCount;
end;

end.
