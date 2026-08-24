program example_offline_test;

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

{ 04 离线测试范式（TESTING.md 铁律的消费者版）：
  仓库内任何 test/example/benchmark 禁止触公网 LLM API。测自己的
  agent 代码用同一套纪律——生产 fake/echo provider 脚本化回放，
  断言可观察行为（最终消息、transcript、outcome、用量），全程确定性。

  运行：make -C core/examples/nextpas.core.agent/04_offline_test_pattern run
  失败以退出码 1 暴露，可直接挂 CI。}

const
  CSCRIPT =
    '[{"deltas":[' +
    '{"kind":"tool_call_start","index":0,"id":"c1","name":"add"},' +
    '{"kind":"tool_call_delta","index":0,"args":"{\"a\":2,\"b\":3}"},' +
    '{"kind":"tool_call_end","index":0},' +
    '{"kind":"finish","reason":"tool_calls"}]},' +
    '{"deltas":[' +
    '{"kind":"text_delta","text":"2 + 3 = 5"},' +
    '{"kind":"finish","reason":"stop"},' +
    '{"kind":"usage","in":15,"out":6}]}]';

type
  TAddTool = class(TInterfacedObject, IAgentTool)
  private
    FSpec: TToolSpec;
  public
    constructor Create;
    function Spec: TToolSpec;
    function Execute(const AArgumentsJson: TJsonText;
      const ACtx: IToolContext): TToolResult;
  end;

constructor TAddTool.Create;
begin
  inherited Create;
  FSpec := Default(TToolSpec);
  FSpec.Name := 'add';
end;

function TAddTool.Spec: TToolSpec;
begin
  Result := FSpec;
end;

function TAddTool.Execute(const AArgumentsJson: TJsonText;
  const ACtx: IToolContext): TToolResult;
var
  LDoc: IJsonDocument;
begin
  Result := Default(TToolResult);
  LDoc := JsonParse(AArgumentsJson);
  Result.ContentJson := '{"sum":' +
    IntToStr(LDoc.Root.Get('a').AsInt + LDoc.Root.Get('b').AsInt) + '}';
end;

procedure Check(const AName: string; AOk: Boolean);
begin
  if AOk then
    WriteLn('PASS  ', AName)
  else
    WriteLn('FAIL  ', AName);
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

{ 范式一：echo provider 验证请求侧——回声即所见即所发 }
procedure DemoEcho;
var
  LProv: IAgentProvider;
  LReq: TCompletionRequest;
begin
  LProv := NewEchoProvider;
  LReq := Default(TCompletionRequest);
  LReq.Model := 'echo';
  SetLength(LReq.Messages, 1);
  LReq.Messages[0] := Default(TMessage);
  LReq.Messages[0].Role := mrUser;
  SetLength(LReq.Messages[0].Parts, 1);
  LReq.Messages[0].Parts[0] := Default(TPart);
  LReq.Messages[0].Parts[0].Kind := pkText;
  LReq.Messages[0].Parts[0].Text := 'ping-marker-42';
  Check('echo returns last user text',
    Pos('ping-marker-42', TextOfParts(LProv.Complete(LReq))) > 0);
end;

{ 范式二：脚本化工具循环——断言 outcome/final/transcript/usage }
procedure DemoLoop;
var
  LProv: IAgentProvider;
  LLoop: TAgentLoop;
  LRun: IAgentLoopRun;
  LMsg: TMessage;
begin
  LProv := NewFakeProvider(CSCRIPT);
  LLoop := TAgentLoop.Create(LProv);
  try
    LLoop.Options.RequestBase.Model := 'fake-model';
    LLoop.AddTool(TAddTool.Create);
    LRun := LLoop.Run('add 2 and 3');

    Check('outcome completed', LRun.Outcome = roCompleted);
    Check('final text present',
      LRun.TryGetFinalMessage(LMsg) and
      (TextOfParts(LMsg) = '2 + 3 = 5'));
    Check('transcript user/asst/tool/asst',
      Length(LRun.Transcript) = 4);
    Check('usage accumulated',
      LRun.TotalUsage.Known and (LRun.TotalUsage.OutputTokens = 6));
  finally
    LLoop.Free;
  end;
end;

{ 范式三：错误路径也是契约——脚本耗尽抛 aecProtocol }
procedure DemoErrorPath;
var
  LProv: IAgentProvider;
  LReq: TCompletionRequest;
  LRaised: Boolean;
  LCode: TAgentErrorCode;
begin
  LProv := NewFakeProvider('[{"deltas":[{"kind":"finish","reason":"stop"}]}]');
  LReq := Default(TCompletionRequest);
  LReq.Model := 'fake-model';
  LRaised := False;
  try
    LProv.Complete(LReq);              { 第一次：消费唯一脚本项 }
    LProv.Complete(LReq);              { 第二次：耗尽必须响亮报错 }
  except
    on Ex: EAgentError do
    begin
      LRaised := True;
      LCode := Ex.ErrorCode;
    end;
  end;
  Check('script exhaustion raises aecProtocol',
    LRaised and (LCode = aecProtocol));
end;

begin
  DemoEcho;
  DemoLoop;
  DemoErrorPath;
  WriteLn('done');
end.
