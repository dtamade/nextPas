{**
 * np_parallel_scheduler.pas — Parallel Build Scheduler
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

unit np_parallel_scheduler;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  nextpas.core.text.strings,
  np_unit_graph;

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

  {** 并行编译调度器 }
  TParallelScheduler = class
  private
    FTasks: array of TCompileTask;
    FTaskCount: LongInt;
    FCompileOrder: TStringArray;
    FMaxParallel: LongInt;
    function FindTaskIndex(const AUnitId: string): LongInt;
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
    property TaskCount: LongInt read FTaskCount;
  end;

implementation

constructor TParallelScheduler.Create;
begin
  inherited Create;
  SetLength(FTasks, 64);
  FTaskCount := 0;
  FMaxParallel := 4;  { 默认 4 并行 }
end;

destructor TParallelScheduler.Destroy;
begin
  SetLength(FTasks, 0);
  SetLength(FCompileOrder, 0);
  inherited Destroy;
end;

function TParallelScheduler.FindTaskIndex(const AUnitId: string): LongInt;
var
  I: LongInt;
begin
  for I := 0 to FTaskCount - 1 do
    if SameText(FTasks[I].UnitId, AUnitId) then
      Exit(I);
  Result := -1;
end;

procedure TParallelScheduler.BuildSchedule(const AGraph: TUnitGraph);
var
  I: LongInt;
  Unit_: TResolvedUnit;
begin
  FTaskCount := 0;

  { 为每个已解析的单元创建任务 }
  for I := 0 to AGraph.ResolvedUnitCount - 1 do
  begin
    Unit_ := AGraph.ResolvedUnitAt(I);
    if FTaskCount >= Length(FTasks) then
      SetLength(FTasks, FTaskCount + 32);

    FTasks[FTaskCount].UnitId := Unit_.UnitId;
    FTasks[FTaskCount].Status := tsPending;
    FTasks[FTaskCount].ErrorMessage := '';
    Inc(FTaskCount);
  end;

  { 获取拓扑排序 }
  FCompileOrder := AGraph.TopologicalInitOrder;
end;

function TParallelScheduler.GetNextBatch: TStringArray;
var
  I, BatchCount: LongInt;
  Idx: LongInt;
begin
  SetLength(Result, FMaxParallel);
  BatchCount := 0;

  { 按拓扑序获取 pending 任务 }
  for I := 0 to Length(FCompileOrder) - 1 do
  begin
    if BatchCount >= FMaxParallel then
      Break;

    Idx := FindTaskIndex(FCompileOrder[I]);
    if (Idx >= 0) and (FTasks[Idx].Status = tsPending) then
    begin
      FTasks[Idx].Status := tsRunning;
      Result[BatchCount] := FTasks[Idx].UnitId;
      Inc(BatchCount);
    end;
  end;

  SetLength(Result, BatchCount);
end;

procedure TParallelScheduler.MarkCompleted(const AUnitId: string;
  ASuccess: Boolean; const AError: string);
var
  Idx: LongInt;
begin
  Idx := FindTaskIndex(AUnitId);
  if Idx < 0 then Exit;

  if ASuccess then
    FTasks[Idx].Status := tsSuccess
  else
  begin
    FTasks[Idx].Status := tsFailed;
    FTasks[Idx].ErrorMessage := AError;
  end;
end;

function TParallelScheduler.AllDone: Boolean;
var
  I: LongInt;
begin
  for I := 0 to FTaskCount - 1 do
    if FTasks[I].Status in [tsPending, tsRunning] then
      Exit(False);
  Result := True;
end;

procedure TParallelScheduler.GetStats(out APending, ARunning, ASuccess, AFailed: LongInt);
var
  I: LongInt;
begin
  APending := 0;
  ARunning := 0;
  ASuccess := 0;
  AFailed := 0;

  for I := 0 to FTaskCount - 1 do
    case FTasks[I].Status of
      tsPending: Inc(APending);
      tsRunning: Inc(ARunning);
      tsSuccess: Inc(ASuccess);
      tsFailed: Inc(AFailed);
    end;
end;

end.
