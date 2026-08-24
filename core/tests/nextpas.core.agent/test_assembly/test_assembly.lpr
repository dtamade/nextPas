program test_assembly;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.async.cancellation,
  nextpas.core.thread.init,
  nextpas.core.thread.pool,
  nextpas.core.json,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.clock,
  nextpas.core.agent.provider.openai,
  nextpas.core.agent.provider.anthropic,
  nextpas.core.agent.retry,
  nextpas.core.agent.loop,
  nextpas.core.agent,
  agent.testkit,
  nextpas.core.test;

{ 真实装配链（TESTING §3 test_assembly 行）：一律经门面单元
  nextpas.core.agent 的生产装配函数组装 provider（scripted transport
  注入 TProviderOptions.Transport），再接 WithRetry / TAgentLoop 跑通
  完整多轮——防"门测走 canned 绕过装配点"事故复发（code888 刀 56 教训）。
  厂商级编码/解码细节归 test_provider_* 门，此处只证装配点贯通。 }

function ScriptResp(AStatus: Integer; const ABody: string): TScriptResponse;
begin
  Result := Default(TScriptResponse);
  Result.Status := AStatus;
  Result.BodyText := ABody;
end;

function ScriptChunks(const AChunks: TStringArray): TScriptResponse;
begin
  Result := Default(TScriptResponse);
  Result.Status := 200;
  Result.Chunks := AChunks;
end;

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

{ 门面 + 重试装饰器 + 循环：openai 装配跑完整工具两轮 }
procedure TestFacadeAssembledOpenAIToolLoop;
var
  Ch1, Ch2: TStringArray;
  R1, R2: TScriptResponse;
  Tr: TScriptedTransport;
  Opts: TOpenAIOptions;
  P, Decorated: IAgentProvider;
  LLoop: TAgentLoop;
  Tool: IAgentTool;
  LRun: IAgentLoopRun;
  LMsg: TMessage;
  Doc: IJsonDocument;
begin
  { loop 恒走流路径：两轮都以 SSE 块脚本回放（命名局部持有，见下） }
  Ch1 := TStringArray.Create(
    'data: {"id":"r1","model":"srv","choices":[{"delta":{"role":' +
    '"assistant","tool_calls":[{"index":0,"id":"c1","type":"function",' +
    '"function":{"name":"noop","arguments":"{}"}}]}}]}'#10#10,
    'data: {"choices":[{"delta":{},"finish_reason":"tool_calls"}]}'#10#10);
  Ch2 := TStringArray.Create(
    'data: {"id":"r2","model":"srv","choices":[{"delta":{"content":' +
    '"assembled done"}}]}'#10#10,
    'data: {"choices":[{"delta":{},"finish_reason":"stop"}],' +
    '"usage":{"prompt_tokens":5,"completion_tokens":3}}'#10#10);
  R1 := ScriptChunks(Ch1);
  R2 := ScriptChunks(Ch2);
  Tr := TScriptedTransport.Create;
  Tr.Add(R1);
  Tr.Add(R2);

  Opts := TOpenAIOptions.New('');
  Opts.Common.ApiKey := 'sk-assembly';
  Opts.Common.Model := 'asm-m';
  Opts.Common.Transport := Tr;
  P := NewOpenAIProvider(Opts);          { 门面装配点 }
  Decorated := WithRetry(P, TRetryPolicy.Default, NewSystemClock);

  LLoop := TAgentLoop.Create(Decorated);
  Tool := TNoopTool.Create;
  try
    LLoop.Options.RequestBase.Model := 'asm-m';
    LLoop.AddTool(Tool);
    LRun := LLoop.Run('assemble me');

    Check(LRun.Outcome = roCompleted, 'assembled loop completes');
    CheckTrue(LRun.TryGetFinalMessage(LMsg), 'final message present');
    Check(Pos('assembled done', LMsg.Parts[0].Text) > 0,
      'decoded text flows through full chain');

    CheckEqual(2, Tr.ServedCount, 'two wire rounds served');
    Doc := JsonParse(Tr.LastRequest.BodyJson);
    Check(not Doc.HasError, 'last wire body parses');
    Check(Doc.Root.Get('tools').IsArray,
      'registered tools travel on assembled request');
  finally
    LLoop.Free;
  end;
end;

{ 门面 anthropic 装配：非流式一轮，usage 全字段贯通 }
procedure TestFacadeAssembledAnthropicRound;
var
  Tr: TScriptedTransport;
  Opts: TAnthropicOptions;
  P: IAgentProvider;
  M: TMessage;
  LReq: TWireRequest;
  FoundKey: Boolean;
  I: Integer;
begin
  Tr := TScriptedTransport.Create;
  Tr.Add(ScriptResp(200,
    '{"id":"msg_a","role":"assistant","content":[{"type":"text",' +
    '"text":"anthropic via facade"}],"stop_reason":"end_turn",' +
    '"usage":{"input_tokens":3,"output_tokens":4}}'));

  Opts := TAnthropicOptions.New('');
  Opts.Common.ApiKey := 'ak-assembly';
  Opts.Common.Model := 'claude-asm';
  Opts.Common.Transport := Tr;
  P := NewAnthropicProvider(Opts);

  M := P.Complete(
    TCompletionRequest.New('claude-asm').WithUserText('hi').WithMaxTokens(64));
  Check(Pos('anthropic via facade', M.Parts[0].Text) > 0,
    'anthropic roundtrip through facade assembly');
  Check(M.Usage.Known and (M.Usage.OutputTokens = 4),
    'usage decoded through assembled chain');

  LReq := Tr.LastRequest;
  FoundKey := False;
  for I := 0 to High(LReq.Headers) do
    if (LReq.Headers[I].Name = 'x-api-key') and
      (LReq.Headers[I].Value = 'ak-assembly') then
      FoundKey := True;
  Check(FoundKey, 'anthropic auth header assembled');
end;

{ 门面流式装配：真增量——delta 在 EOF 前逐个产出 }
procedure TestFacadeAssembledStream;
var
  Ch: TStringArray;
  Resp: TScriptResponse;
  Tr: TScriptedTransport;
  Opts: TOpenAIOptions;
  P: IAgentProvider;
  C: IAgentCompletion;
  D: TStreamDelta;
  NText: Integer;
begin
  { 命名局部持有脚本数组：内联临时经嵌套调用传参在部分 FPC 代码生成
    路径下生命周期不可靠（lane 提交记录有案），测试一律用显式变量 }
  Ch := TStringArray.Create(
    'data: {"choices":[{"delta":{"content":"one"}}]}'#10#10,
    'data: {"choices":[{"delta":{"content":"two"}}]}'#10#10,
    'data: {"choices":[{"delta":{"content":"three"},' +
    '"finish_reason":"stop"}]}'#10#10);
  Resp := ScriptChunks(Ch);
  Tr := TScriptedTransport.Create;
  Tr.Add(Resp);

  Opts := TOpenAIOptions.New('');
  Opts.Common.ApiKey := 'sk-stream';
  Opts.Common.Transport := Tr;
  P := NewOpenAIProvider(Opts);

  C := P.Stream(TCompletionRequest.New('m').WithUserText('go'));
  NText := 0;
  while C.NextDelta(D) do
    if D.Kind = sdkTextDelta then
      Inc(NText);
  CheckEqual(3, NText,
    'three text deltas produced before EOF (real incremental)');
  Check(Pos('three', C.GetMessage.Parts[0].Text) > 0,
    'folded message complete after drain');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.assembly');
  T.Test('facade openai tool loop', @TestFacadeAssembledOpenAIToolLoop);
  T.Test('facade anthropic round', @TestFacadeAssembledAnthropicRound);
  T.Test('facade stream increments', @TestFacadeAssembledStream);
  if not T.Run then Halt(1);
end.
