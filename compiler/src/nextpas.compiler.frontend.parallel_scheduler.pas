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
  nextpas.core.text.strings,
  nextpas.core.collections.vec,
<<<<<<<< HEAD:compiler/frontend/np_parallel_scheduler.pas
  nextpas.core.collections.hashmap,
  np_unit_graph;
========
  nextpas.compiler.frontend.unit_graph;
>>>>>>>> codex/compiler-system:compiler/src/nextpas.compiler.frontend.parallel_scheduler.pas

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
  TTaskIndexMap = specialize THashMap<string, LongInt>;

  {** 并行编译调度器 }
  TParallelScheduler = class
  private
    FTasks: TCompileTaskVec;
    FCompileOrder: TCompileOrderVec;
    FMaxParallel: LongInt;
    FIndex: TTaskIndexMap;
    FGraph: TUnitGraph;
    function NormalizeKey(const AUnitId: string): string; inline;
    function FindTaskIndex(const AUnitId: string): LongInt;
    function AreDependenciesSatisfied(const AUnitId: string): Boolean;
    function GetTaskCount: LongInt;
    procedure RebuildIndex;
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
  FTasks := TCompileTaskVec.Create;
  FTasks.EnsureCapacity(64);
  FCompileOrder := TCompileOrderVec.Create;
  FCompileOrder.EnsureCapacity(64);
  FIndex := TTaskIndexMap.Create;
  FGraph := nil;
  FMaxParallel := 4;  { 默认 4 并行 }
end;

destructor TParallelScheduler.Destroy;
begin
  FIndex.Free;
  FIndex := nil;
  FGraph := nil;
  FTasks.Free;
  FTasks := nil;
  FCompileOrder.Free;
  FCompileOrder := nil;
  inherited Destroy;
end;

function TParallelScheduler.GetTaskCount: LongInt;
begin
  if FTasks = nil then
    Exit(0);
  Result := LongInt(FTasks.Count);
end;

function TParallelScheduler.NormalizeKey(const AUnitId: string): string;
begin
  Result := LowerCase(AUnitId);
end;

procedure TParallelScheduler.RebuildIndex;
var
  I: LongInt;
begin
  if FIndex = nil then
    FIndex := TTaskIndexMap.Create;
  FIndex.Clear;
  if FTasks = nil then Exit;
  if FTasks.Count > 0 then
    FIndex.Reserve(SizeUInt(FTasks.Count * 2));
  for I := 0 to LongInt(FTasks.Count) - 1 do
    FIndex.Put(NormalizeKey(FTasks[SizeUInt(I)].UnitId), I);
end;

function TParallelScheduler.FindTaskIndex(const AUnitId: string): LongInt;
var
  V: LongInt;
  I: LongInt;
begin
  if FTasks = nil then
    Exit(-1);
  if (FIndex <> nil) and (FIndex.Count > 0) then
  begin
    if FIndex.TryGetValue(NormalizeKey(AUnitId), V) then
      Exit(V);
  end;
  for I := 0 to LongInt(FTasks.Count) - 1 do
    if SameText(FTasks[SizeUInt(I)].UnitId, AUnitId) then
      Exit(I);
  Result := -1;
end;

function TParallelScheduler.AreDependenciesSatisfied(const AUnitId: string): Boolean;
var
  EIdx: LongInt;
  Edge: TUnitGraphEdge;
  DepIdx: LongInt;
begin
  Result := True;
  if FGraph = nil then
    Exit(True);
  for EIdx := 0 to FGraph.EdgeCount - 1 do
  begin
    Edge := FGraph.EdgeAt(EIdx);
    if (Edge.Kind <> ugeInterfaceUse) and (Edge.Kind <> ugeImplementationUse) then
      Continue;
    if not SameText(Edge.SourceUnitId, AUnitId) then
      Continue;
    DepIdx := FindTaskIndex(Edge.TargetUnitId);
    if DepIdx < 0 then
      Continue;
    if FTasks[SizeUInt(DepIdx)].Status <> tsSuccess then
      Exit(False);
  end;
end;

procedure TParallelScheduler.BuildSchedule(const AGraph: TUnitGraph);
var
  I: LongInt;
  Order: TStringArray;
  Task: TCompileTask;
  Unit_: TResolvedUnit;
begin
  if FTasks = nil then
    FTasks := TCompileTaskVec.Create;
  FTasks.Clear;
  if FCompileOrder = nil then
    FCompileOrder := TCompileOrderVec.Create;
  FCompileOrder.Clear;
  FGraph := AGraph;

  for I := 0 to AGraph.ResolvedUnitCount - 1 do
  begin
    Unit_ := AGraph.ResolvedUnitAt(I);
    Task := Default(TCompileTask);
    Task.UnitId := Unit_.UnitId;
    Task.Status := tsPending;
    Task.ErrorMessage := '';
    FTasks.Push(Task);
  end;

  RebuildIndex;

  Order := AGraph.TopologicalInitOrder;
  for I := 0 to Length(Order) - 1 do
    FCompileOrder.Push(Order[I]);
end;

function TParallelScheduler.GetNextBatch: TStringArray;
var
  I, BatchCount: LongInt;
  Idx: LongInt;
  Task: TCompileTask;
  CandidateId: string;
begin
  Result := nil;
  SetLength(Result, FMaxParallel);
  BatchCount := 0;

  if FCompileOrder = nil then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  for I := 0 to LongInt(FCompileOrder.Count) - 1 do
  begin
    if BatchCount >= FMaxParallel then
      Break;

    CandidateId := FCompileOrder[SizeUInt(I)];
    Idx := FindTaskIndex(CandidateId);
    if (Idx >= 0) and (FTasks[SizeUInt(Idx)].Status = tsPending) then
    begin
      if not AreDependenciesSatisfied(FTasks[SizeUInt(Idx)].UnitId) then
        Continue;
      Task := FTasks[SizeUInt(Idx)];
      Task.Status := tsRunning;
      FTasks[SizeUInt(Idx)] := Task;
      Result[BatchCount] := Task.UnitId;
      Inc(BatchCount);
    end;
  end;

  SetLength(Result, BatchCount);
end;

procedure TParallelScheduler.MarkCompleted(const AUnitId: string;
  ASuccess: Boolean; const AError: string);
var
  Idx: LongInt;
  Task: TCompileTask;
begin
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
end;

function TParallelScheduler.AllDone: Boolean;
var
  I: LongInt;
begin
  if FTasks = nil then
    Exit(True);
  for I := 0 to LongInt(FTasks.Count) - 1 do
    if FTasks[SizeUInt(I)].Status in [tsPending, tsRunning] then
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

  if FTasks = nil then
    Exit;
  for I := 0 to LongInt(FTasks.Count) - 1 do
    case FTasks[SizeUInt(I)].Status of
      tsPending: Inc(APending);
      tsRunning: Inc(ARunning);
      tsSuccess: Inc(ASuccess);
      tsFailed: Inc(AFailed);
    end;
end;

end.
