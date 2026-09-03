{**
 * nextpas.compiler.frontend.parallel_scheduler.pas — Parallel Build Scheduler
 *
 * 并行编译调度器。按拓扑序分层，同层并行编译。
 *
 * 设计：
 *   - 使用 TUnitGraph.TopologicalInitOrder 获取编译顺序
 *   - 分层：无依赖的单元在同一层
 *   - 同层单元可并行编译
 *
 * 对标 Go 的 go build -p 并行编译
 *}

unit nextpas.compiler.frontend.parallel_scheduler;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  SysUtils,
  nextpas.core.sync.mutex,
  nextpas.core.text.strings,
  nextpas.core.collections.vec,
  nextpas.compiler.frontend.unit_graph;

type
  {** 编译任务状态 }
  TTaskStatus = (
    tsPending,    { 等待编译 }
    tsRunning,    { 正在编译 }
    tsSuccess,    { 编译成功 }
    tsFailed      { 编译失败 }
  );

  {** 编译任务 }
  TCompileTask = record
    UnitId: string;
    Status: TTaskStatus;
    ErrorMessage: string;
  end;

  TCompileTaskVec = specialize TVec<TCompileTask>;
  TCompileOrderVec = specialize TVec<string>;

  {** 并行编译调度器 }
  TParallelScheduler = class
  private
    FLock: TMutex;
    FTasks: TCompileTaskVec;
    FCompileOrder: TCompileOrderVec;
    FMaxParallel: LongInt;
    function FindTaskIndex(const AUnitId: string): LongInt;
    function GetTaskCount: LongInt;
  public
    constructor Create;
    destructor Destroy; override;

    {** 从单元图构建调度计划 }
    procedure BuildSchedule(const AGraph: TUnitGraph);

    {** 获取下一批可并行编译的单元 }
    function GetNextBatch: TStringArray;

    {** 标记单元编译完成 }
    procedure MarkCompleted(const AUnitId: string; ASuccess: Boolean;
      const AError: string = '');

    {** 检查是否全部完成 }
    function AllDone: Boolean;

    {** 获取状态统计 }
    procedure GetStats(out APending, ARunning, ASuccess, AFailed: LongInt);

    {** 最大并行数 }
    property MaxParallel: LongInt read FMaxParallel write FMaxParallel;

    {** 任务数 }
    property TaskCount: LongInt read GetTaskCount;
  end;

implementation

constructor TParallelScheduler.Create;
begin
  inherited Create;
  FLock := TMutex.Create;
  FTasks := TCompileTaskVec.Create;
  FTasks.EnsureCapacity(64);
  FCompileOrder := TCompileOrderVec.Create;
  FCompileOrder.EnsureCapacity(64);
  FMaxParallel := 4;  { 默认 4 并行 }
end;

destructor TParallelScheduler.Destroy;
begin
  FTasks.Free;
  FTasks := nil;
  FCompileOrder.Free;
  FCompileOrder := nil;
  FLock.Free;
  FLock := nil;
  inherited Destroy;
end;

function TParallelScheduler.GetTaskCount: LongInt;
begin
  if FLock <> nil then FLock.Acquire;
  try
    if FTasks = nil then
      Exit(0);
    Result := LongInt(FTasks.Count);
  finally
    if FLock <> nil then FLock.Release;
  end;
end;

function TParallelScheduler.FindTaskIndex(const AUnitId: string): LongInt;
var
  I: LongInt;
begin
  if FTasks = nil then
    Exit(-1);
  for I := 0 to LongInt(FTasks.Count) - 1 do
    if SameText(FTasks[SizeUInt(I)].UnitId, AUnitId) then
      Exit(I);
  Result := -1;
end;

procedure TParallelScheduler.BuildSchedule(const AGraph: TUnitGraph);
var
  I: LongInt;
  Order: TStringArray;
  Task: TCompileTask;
  Unit_: TResolvedUnit;
begin
  if FLock <> nil then FLock.Acquire;
  try
    if FTasks = nil then
      FTasks := TCompileTaskVec.Create;
    FTasks.Clear;
    if FCompileOrder = nil then
      FCompileOrder := TCompileOrderVec.Create;
    FCompileOrder.Clear;

    { 为每个已解析的单元创建任务 }
    for I := 0 to AGraph.ResolvedUnitCount - 1 do
    begin
      Unit_ := AGraph.ResolvedUnitAt(I);
      Task := Default(TCompileTask);
      Task.UnitId := Unit_.UnitId;
      Task.Status := tsPending;
      Task.ErrorMessage := '';
      FTasks.Push(Task);
    end;

    { 获取拓扑排序（图 API 仍返回 dynarray；session 表落 TVec 默认堆） }
    Order := AGraph.TopologicalInitOrder;
    for I := 0 to Length(Order) - 1 do
      FCompileOrder.Push(Order[I]);
  finally
    if FLock <> nil then FLock.Release;
  end;
end;

function TParallelScheduler.GetNextBatch: TStringArray;
var
  I, BatchCount: LongInt;
  Idx: LongInt;
  Task: TCompileTask;
  LMax: LongInt;
begin
  if FLock <> nil then FLock.Acquire;
  try
    LMax := FMaxParallel;
    SetLength(Result, LMax);
    BatchCount := 0;

    if FCompileOrder = nil then
    begin
      SetLength(Result, 0);
      Exit;
    end;

    { 按拓扑序获取 pending 任务 — 全程持锁防止 lost-update/越界 }
    for I := 0 to LongInt(FCompileOrder.Count) - 1 do
    begin
      if BatchCount >= LMax then
        Break;

      Idx := FindTaskIndex(FCompileOrder[SizeUInt(I)]);
      if (Idx >= 0) and (FTasks[SizeUInt(Idx)].Status = tsPending) then
      begin
        Task := FTasks[SizeUInt(Idx)];
        Task.Status := tsRunning;
        FTasks[SizeUInt(Idx)] := Task;
        Result[BatchCount] := Task.UnitId;
        Inc(BatchCount);
      end;
    end;

    SetLength(Result, BatchCount);
  finally
    if FLock <> nil then FLock.Release;
  end;
end;

procedure TParallelScheduler.MarkCompleted(const AUnitId: string;
  ASuccess: Boolean; const AError: string);
var
  Idx: LongInt;
  Task: TCompileTask;
begin
  if FLock <> nil then FLock.Acquire;
  try
    Idx := FindTaskIndex(AUnitId);
    if Idx < 0 then Exit;

    Task := FTasks[SizeUInt(Idx)];
    if ASuccess then
      Task.Status := tsSuccess
    else
    begin
      Task.Status := tsFailed;
      Task.ErrorMessage := AError;
    end;
    FTasks[SizeUInt(Idx)] := Task;
  finally
    if FLock <> nil then FLock.Release;
  end;
end;

function TParallelScheduler.AllDone: Boolean;
var
  I: LongInt;
begin
  if FLock <> nil then FLock.Acquire;
  try
    if FTasks = nil then
      Exit(True);
    for I := 0 to LongInt(FTasks.Count) - 1 do
      if FTasks[SizeUInt(I)].Status in [tsPending, tsRunning] then
        Exit(False);
    Result := True;
  finally
    if FLock <> nil then FLock.Release;
  end;
end;

procedure TParallelScheduler.GetStats(out APending, ARunning, ASuccess, AFailed: LongInt);
var
  I: LongInt;
begin
  APending := 0;
  ARunning := 0;
  ASuccess := 0;
  AFailed := 0;

  if FLock <> nil then FLock.Acquire;
  try
    if FTasks = nil then
      Exit;
    for I := 0 to LongInt(FTasks.Count) - 1 do
      case FTasks[SizeUInt(I)].Status of
        tsPending: Inc(APending);
        tsRunning: Inc(ARunning);
        tsSuccess: Inc(ASuccess);
        tsFailed: Inc(AFailed);
      end;
  finally
    if FLock <> nil then FLock.Release;
  end;
end;

end.
