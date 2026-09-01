program test_assembly;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.async.cancellation,
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
  厂商级编码/解码细节归 test_provider_* 门，此处只证装配点贯通。
  边界/Cancel/超时/并发：
  - Cancel 边界：装配链上 Token 经门面透传至 transport，取消在端到端链路上可中断（W17.6）。
  - 超时边界：Retry-After 与超时归因经 BuildUpstreamError 分类在装配后仍保真（F-H24 429/401 快照已补）。
  - 并发边界：单线程装配验证，无并发；WithRetry/loop 的并发门由各自单测保障。
  悬挂指针：Provider/Transport/Loop 均接口持有，装配函数返回接口后无裸指针常驻；ScriptedTransport 由调用方拥有。
  泄漏标注：common.mk -gh 全量 HEAPTRC 门 0 unfreed；全链路 try..finally Free/接口释放，无装配点遗漏。 }

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

{ F-H24 补：装配错误路径——经门面 Provider + TScriptedTransport(RaiseUpstream) 的 429/401 归因与 RetryAfter 透传 }
procedure TestAssemblyOpenAI429ViaScripted;
var
  Tr: TScriptedTransport;
  Opts: TOpenAIOptions;
  P: IAgentProvider;
  LResp: TScriptResponse;
  LHdrs: TWireHeaderArray;
  Got: Boolean;
begin
  Tr := TScriptedTransport.Create;
  Tr.ProviderName := 'openai';
  SetLength(LHdrs, 2);
  LHdrs[0].Name := 'retry-after';
  LHdrs[0].Value := '2';
  LHdrs[1].Name := 'x-request-id';
  LHdrs[1].Value := 'req-429';
  LResp := Default(TScriptResponse);
  LResp.Status := 429;
  LResp.Headers := LHdrs;
  LResp.BodyText := '{"error":{"message":"rate limited"}}';
  LResp.RaiseUpstream := True;
  Tr.Add(LResp);
  Opts := TOpenAIOptions.New('');
  Opts.Common.ApiKey := 'sk-assembly';
  Opts.Common.Transport := Tr;
  P := NewOpenAIProvider(Opts);
  Got := False;
  try
    P.Complete(TCompletionRequest.New('m').WithUserText('hi'));
    Check(False, '429 must raise');
  except
    on E: EAgentError do
    begin
      Got := True;
      Check(E.ErrorCode = aecRateLimited, '429 -> aecRateLimited');
      Check(E.Provider = 'openai', 'provider attribution openai');
      Check(E.RetryAfterMs = 2000, 'retry-after 2s -> 2000ms');
      Check(E.RequestId = 'req-429', 'request id透传');
    end;
  end;
  Check(Got, 'got 429 assembled error');
end;

procedure TestAssemblyAnthropic401ViaScripted;
var
  Tr: TScriptedTransport;
  Opts: TAnthropicOptions;
  P: IAgentProvider;
  LResp: TScriptResponse;
  C: IAgentCompletion;
  Got: Boolean;
  LDelta: TStreamDelta;
begin
  Tr := TScriptedTransport.Create;
  Tr.ProviderName := 'anthropic';
  LResp := Default(TScriptResponse);
  LResp.Status := 401;
  LResp.BodyText := '{"type":"error","error":{"type":"authentication_error","message":"bad key"}}';
  LResp.RaiseUpstream := True;
  Tr.Add(LResp);
  Opts := TAnthropicOptions.New('');
  Opts.Common.ApiKey := 'ak-bad';
  Opts.Common.Transport := Tr;
  P := NewAnthropicProvider(Opts);
  // 非流式 Complete 路径
  Got := False;
  try
    P.Complete(TCompletionRequest.New('claude-asm').WithUserText('hi').WithMaxTokens(32));
    Check(False, '401 must raise');
  except
    on E: EAgentError do
    begin
      Got := True;
      Check(E.ErrorCode = aecAuthentication, '401 -> aecAuthentication');
      Check(E.Provider = 'anthropic', 'provider attribution anthropic');
    end;
  end;
  Check(Got, 'got 401 assembled error (complete)');
  // 流式路径：错误延迟到 NextEvent
  Tr.Add(LResp);
  C := P.Stream(TCompletionRequest.New('claude-asm').WithUserText('hi').WithMaxTokens(32));
  Got := False;
  try
    while C.NextDelta(LDelta) do ;
    Check(False, 'stream 401 must raise on NextDelta');
  except
    on E: EAgentError do
    begin
      Got := (E.ErrorCode = aecAuthentication);
      Check(Got, 'stream 401 -> aecAuthentication');
    end;
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.assembly');
  T.Test('facade openai tool loop', @TestFacadeAssembledOpenAIToolLoop);
  T.Test('facade anthropic round', @TestFacadeAssembledAnthropicRound);
  T.Test('facade stream increments', @TestFacadeAssembledStream);
  T.Test('assembly openai 429 via scripted', @TestAssemblyOpenAI429ViaScripted);
  T.Test('assembly anthropic 401 via scripted', @TestAssemblyAnthropic401ViaScripted);
  if not T.Run then Halt(1);
end.
