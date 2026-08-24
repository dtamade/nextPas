program example_tool_loop;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.async.cancellation,
  nextpas.core.thread.init,
  nextpas.core.thread.pool,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.provider.fake,
  nextpas.core.agent.loop,
  nextpas.core.json;

{ 03 工具循环：TAgentLoop 多轮编排（API.md §6）。
  模型第一轮请求调用天气工具 → loop 经线程池执行本地桩工具并回喂 →
  第二轮模型给出最终回答。事件钩子打印完整轨迹；预算/防打转/引导收尾
  见 docs/agent/LIFECYCLE.md。
  零网络：生产 fake provider 脚本回放两轮。

  运行：make -C core/examples/nextpas.core.agent/03_tool_loop run }

const
  CSCRIPT =
    '[{"deltas":[' +
    '{"kind":"tool_call_start","index":0,"id":"call_1","name":"weather"},' +
    '{"kind":"tool_call_delta","index":0,"args":"{\"city\":\"Shanghai\"}"},' +
    '{"kind":"tool_call_end","index":0},' +
    '{"kind":"finish","reason":"tool_calls"}]},' +
    '{"deltas":[' +
    '{"kind":"text_delta","text":"Shanghai: 22C, overcast."},' +
    '{"kind":"finish","reason":"stop"},' +
    '{"kind":"usage","in":40,"out":9}]}]';

type
  { 本地桩工具：生产中这里是任意本地能力（文件、检索、HTTP……），
    约定不抛异常、失败走 TToolResult.IsError=True }
  TWeatherTool = class(TInterfacedObject, IAgentTool)
  private
    FSpec: TToolSpec;
  public
    constructor Create;
    function Spec: TToolSpec;
    function Execute(const AArgumentsJson: TJsonText;
      const ACtx: IToolContext): TToolResult;
  end;

  { 事件轨迹打印器：loop 单线程编排，回调内无需加锁 }
  TTrace = class
  public
    procedure OnEvent(const AE: TLoopEvent);
  end;

constructor TWeatherTool.Create;
begin
  inherited Create;
  FSpec := Default(TToolSpec);
  FSpec.Name := 'weather';
  FSpec.Description := 'query current weather by city';
  FSpec.ParametersJson :=
    '{"type":"object","required":["city"],' +
    '"properties":{"city":{"type":"string"}}}';
end;

function TWeatherTool.Spec: TToolSpec;
begin
  Result := FSpec;
end;

function TWeatherTool.Execute(const AArgumentsJson: TJsonText;
  const ACtx: IToolContext): TToolResult;
begin
  Result := Default(TToolResult);
  Result.ContentJson := '{"temp_c":22,"sky":"overcast"}';
end;

procedure TTrace.OnEvent(const AE: TLoopEvent);
const
  CNames: array[TLoopEventKind] of string = (
    'runStart', 'roundStart', 'roundEnd',
    'toolCallStart', 'toolCallEnd', 'budgetWarning', 'runEnd');
begin
  WriteLn('[evt] ', CNames[AE.Kind], ' round=', AE.Round,
    ' tool=', AE.ToolName, ' id=', AE.ToolCallId);
end;

function TextOfParts(const AMsg: TMessage): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(AMsg.Parts) do
    if AMsg.Parts[I].Kind = pkText then
      Result := Result + AMsg.Parts[I].Text;
end;

var
  LProv: IAgentProvider;
  LLoop: TAgentLoop;
  LTrace: TTrace;
  LRun: IAgentLoopRun;
  LMsg: TMessage;
begin
  LProv := NewFakeProvider(CSCRIPT);
  LLoop := TAgentLoop.Create(LProv);   { 未注入池则构造自有池随实例释放 }
  LTrace := TTrace.Create;
  try
    LLoop.Options.RequestBase.Model := 'fake-model';
    LLoop.AddTool(TWeatherTool.Create);
    LLoop.SetEventHook(@LTrace.OnEvent);

    LRun := LLoop.Run('Weather in Shanghai?');

    WriteLn('---');
    case LRun.Outcome of
      roCompleted:
        begin
          if LRun.TryGetFinalMessage(LMsg) then
            WriteLn('final: ', TextOfParts(LMsg))
          else
            WriteLn('completed without final message');
        end;
      roCancelled:   WriteLn('cancelled');
      roFailed:      WriteLn('failed: ', LRun.LastError.Message);
    else
      WriteLn('guided finish, outcome=', Ord(LRun.Outcome));
    end;
    WriteLn('transcript messages: ', Length(LRun.Transcript));
    if LRun.TotalUsage.Known then
      WriteLn('usage: in=', LRun.TotalUsage.InputTokens,
        ' out=', LRun.TotalUsage.OutputTokens);
  finally
    LTrace.Free;
    LLoop.Free;
  end;
end.
