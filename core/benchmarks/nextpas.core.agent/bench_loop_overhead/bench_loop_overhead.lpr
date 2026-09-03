program bench_loop_overhead;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.time.base,
  nextpas.core.async.cancellation,
  nextpas.core.thread.intf,
  nextpas.core.thread.pool,
  nextpas.core.bench,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.provider.fake,
  nextpas.core.agent.loop,
  nextpas.core.fs;

{ bench_loop_overhead（TESTING.md §4）：生产 fake provider 下 10 轮
  （9 次工具调用 + 1 次终答）完整 run 的总开销，证明抽象零税——
  无 IO、无真实模型，纯进程内编排。
  口径：单次 op 含 provider 构造（脚本 JSON 解析）+ loop 实例构造
  （共享池注入，不含建池/Shutdown）+ Run 全程；脚本体积极小，
  provider 解析占比有限，读数时结合 BENCHMARKS.md 说明。 }

const
  { 9 轮工具调用 + 1 轮文本收尾 = 10 轮 }
  CCALL_ROUND =
    '{"deltas":[' +
    '{"kind":"tool_call_start","index":0,"id":"c","name":"noop"},' +
    '{"kind":"tool_call_delta","index":0,"args":"{}"},' +
    '{"kind":"tool_call_end","index":0},' +
    '{"kind":"finish","reason":"tool_calls"}]}';
  CFINAL_ROUND =
    '{"deltas":[' +
    '{"kind":"text_delta","text":"done"},' +
    '{"kind":"finish","reason":"stop"},' +
    '{"kind":"usage","in":1,"out":1}]}';

type
  TNoopTool = class(TInterfacedObject, IAgentTool)
  private
    FSpec: TToolSpec;
  public
    constructor Create;
    function Spec: TToolSpec;
    function Execute(const AArgumentsJson: TJsonText;
      const ACtx: IToolContext): TToolResult;
  end;

constructor TNoopTool.Create;
begin
  inherited Create;
  FSpec := Default(TToolSpec);
  FSpec.Name := 'noop';
end;

function TNoopTool.Spec: TToolSpec;
begin
  Result := FSpec;
end;

function TNoopTool.Execute(const AArgumentsJson: TJsonText;
  const ACtx: IToolContext): TToolResult;
begin
  Result := Default(TToolResult);
  Result.ContentJson := '{"ok":true}';
end;

var
  GScript: string;
  GPool: IThreadPool;
  GTool: IAgentTool;
  GSink: Integer;

procedure BuildScript;
var
  I: Integer;
begin
  GScript := '[';
  for I := 0 to 8 do
  begin
    if I > 0 then
      GScript := GScript + ',';
    GScript := GScript + CCALL_ROUND;
  end;
  GScript := GScript + ',' + CFINAL_ROUND + ']';
end;

procedure BenchRun10Rounds(const ACtx: IBenchContext);
var
  LProv: IAgentProvider;
  LLoop: TAgentLoop;
  LRun: IAgentLoopRun;
begin
  LProv := NewFakeProvider(GScript);
  LLoop := TAgentLoop.Create(LProv, GPool);
  try
    LLoop.Options.RequestBase.Model := 'fake-model';
    LLoop.AddTool(GTool);
    LRun := LLoop.Run('bench');
    GSink := GSink + Ord(LRun.Outcome);
  finally
    LLoop.Free;
  end;
end;

var
  LResults: IBenchResults;
begin
  BuildScript;
  GPool := CreateThreadPool(2);         { 共享池：op 外构造，摊销为零 }
  GTool := TNoopTool.Create;
  try
    LResults := TBenchSuite.Create('agent')
      .SetQuiet(True)
      .SetMinDuration(TDuration.FromMilliseconds(50))
      .SetMinSamples(5)
      .Add('loop/fake-provider-10-rounds', @BenchRun10Rounds)
      .Run;
    WriteLn('sink: ', GSink);
    WriteLn(LResults.PrintToConsole);
    ForceDirectories('build');
    LResults.SaveToJSON('build/bench-agent-loop-overhead.json');
  finally
    GPool.Shutdown;
  end;
end.
