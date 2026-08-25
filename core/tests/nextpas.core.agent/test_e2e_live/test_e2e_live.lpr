program test_e2e_live;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.json,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.provider.openai,
  nextpas.core.agent.provider.anthropic,
  { HTTPS：注册 OpenSSL 后端（initialization 副作用，同 test_http_tls_real）}
  nextpas.core.tls.openssl.backed,
  agent.testkit,
  nextpas.core.os.env,
  nextpas.core.test;

{ 真实端点 E2E（opt-in 门，TESTING §3）：默认跳过——仅当
  NEXTPAS_AGENT_E2E=1 时执行；凭据经既有 FromEnv 变量注入
  （NEXTPAS_AGENT_OPENAI_* / NEXTPAS_AGENT_ANTHROPIC_*），
  本门与仓库均不持有任何密钥。基准禁触公网的铁律不受影响：
  本目录是 test gate 且默认零网络。

  覆盖面（WIRE-MAPPINGS 实端验证）：
  - openai Complete/Stream 往返（usage、finish、Q-O2 reasoning_content）
  - W6 ResponseSchemaJson（网关兼容边界：参数被接受但内容未必受强制，
    断言只锁请求成功与可解析——§1.7 预判的兼容形态）
  - W7 ReasoningEffort=reLow 正常往返
  - anthropic messages Complete（thinking 块 + text + usage）
  - W7 ReadIdleTimeoutMs 负向验证：正常流不被空闲超时误杀 }

const
  CRequiredEnvNote =
    'set NEXTPAS_AGENT_E2E=1 and NEXTPAS_AGENT_{OPENAI,ANTHROPIC}_* to run';

function E2EEnabled: Boolean;
begin
  Result := GetEnv('NEXTPAS_AGENT_E2E') = '1';
end;

procedure TestSkipWhenNotEnabled;
begin
  { 占位用例：未启用时保证套件非空且可解释地绿 }
  Check(True, 'e2e disabled; ' + CRequiredEnvNote);
end;

procedure TestOpenAIComplete;
var
  P: IAgentProvider;
  M: TMessage;
begin
  P := NewOpenAIProviderFromEnv;
  Check(P <> nil,
    'openai provider from env (NEXTPAS_AGENT_OPENAI_*)');
  if P = nil then
    Exit;
  M := P.Complete(TCompletionRequest.New('').WithUserText(
    'Reply with exactly: OK'));
  Check(MessageText(M) <> '', 'openai complete returns text');
  Check(M.FinishReason = frStop, 'finish stop');
  Check(M.Usage.Known, 'usage known');
  Check(Pos('big-pickle', M.Model) > 0, 'model echoed');
  Check(MessageText(M) <> '', 'non-empty content');
  { Q-O2：端点返回 reasoning_content 时折叠为 pkThinking part；
    无该字段也不影响文本 }
  Check((MessageText(M) <> '') or (M.Parts <> nil), 'has payload parts');
end;

procedure TestOpenAIStream;
var
  P: IAgentProvider;
  C: IAgentCompletion;
  D: TStreamDelta;
  M: TMessage;
  LText: string;
  LHasFinish, LHasEnvelope: Boolean;
begin
  P := NewOpenAIProviderFromEnv;
  if P = nil then
    Exit;
  C := P.Stream(TCompletionRequest.New('').WithUserText(
    'Count from 1 to 5, digits only.'));
  LHasEnvelope := False;
  LHasFinish := False;
  LText := '';
  while C.NextDelta(D) do
  begin
    if D.Kind = sdkEnvelope then
      LHasEnvelope := True;
    if D.Kind = sdkTextDelta then
      LText := LText + D.TextDelta;
    if D.Kind = sdkFinish then
      LHasFinish := True;
  end;
  M := C.GetMessage;
  Check(LHasEnvelope, 'stream envelope first');
  Check(LHasFinish, 'stream finish present');
  Check(Length(LText) > 0, 'stream text accumulated');
  CheckEqual(LText, MessageText(M),
    'fold invariant: streamed text == GetMessage text');
  Check(M.Usage.Known,
    'usage known (endpoint sends usage on finish frame)');
end;

procedure TestOpenAIReasoningEffortW7;
var
  P: IAgentProvider;
  M: TMessage;
begin
  P := NewOpenAIProviderFromEnv;
  if P = nil then
    Exit;
  M := P.Complete(TCompletionRequest.New('').WithMaxTokens(400)
    .WithUserText('Reply with exactly: OK')
    .WithReasoningEffort(reLow));
  Check(M.FinishReason = frStop, 'reasoning_effort=low accepted upstream');
  Check(MessageText(M) <> '', 'reasoning_effort=low still answers');
  Check(M.Usage.Known, 'usage known with reasoning_effort');
end;

procedure TestOpenAIStructuredOutputW6;
var
  P: IAgentProvider;
  M: TMessage;
  Doc: IJsonDocument;
begin
  P := NewOpenAIProviderFromEnv;
  if P = nil then
    Exit;
  { §1.7 兼容边界实测：网关接受 json_schema 参数但不一定强制输出。
    断言只锁"请求成功且响应可解码"——不锁 content 是合法 JSON }
  M := P.Complete(TCompletionRequest.New('').WithMaxTokens(500)
    .WithUserText('Extract the person name from: "Ada wrote notes."')
    .WithResponseSchema(
      '{"type":"object","properties":{"name":{"type":"string"}},' +
      '"required":["name"],"additionalProperties":false}'));
  Check(M.FinishReason = frStop, 'structured request completes');
  Check(M.Usage.Known, 'usage known on structured request');
  Doc := JsonParse(MessageText(M));
  { 内容若恰为 JSON 则须能取出 name 字段；若网关未强制则跳过断言 }
  if (Doc <> nil) and (not Doc.HasError) then
    Check(Doc.Root.ObjectHas('name'),
      'when content is JSON it follows schema');
end;

procedure TestAnthropicComplete;
var
  P: IAgentProvider;
  M: TMessage;
  I: Integer;
  HasThinkOrText: Boolean;
begin
  P := NewAnthropicProviderFromEnv;
  Check(P <> nil,
    'anthropic provider from env (NEXTPAS_AGENT_ANTHROPIC_*)');
  if P = nil then
    Exit;
  M := P.Complete(TCompletionRequest.New('').WithMaxTokens(300)
    .WithUserText('Reply with exactly: OK'));
  Check(MessageText(M) <> '', 'anthropic complete returns text');
  Check(M.FinishReason = frStop, 'end_turn -> frStop');
  Check(M.Usage.Known, 'anthropic usage known');
  HasThinkOrText := False;
  for I := 0 to High(M.Parts) do
    if M.Parts[I].Kind in [pkText, pkThinking] then
      HasThinkOrText := True;
  Check(HasThinkOrText, 'text/thinking blocks decoded');
end;

procedure TestOpenAIIdleTimeoutNoFalseKill;
var
  Opts: TOpenAIOptions;
  P: IAgentProvider;
  M: TMessage;
  BaseUrl, Key, Model: string;
begin
  { W7 负向验证：真实流式全程块间隔远小于阈值——idle 不误杀。
    显式构造以便只注入 ReadIdleTimeoutMs（FromEnv 不含该字段）}
  BaseUrl := GetEnv('NEXTPAS_AGENT_OPENAI_BASE_URL');
  Key := GetEnv('NEXTPAS_AGENT_OPENAI_API_KEY');
  Model := GetEnv('NEXTPAS_AGENT_OPENAI_MODEL');
  if (BaseUrl = '') or (Key = '') then
    Exit;
  Opts := TOpenAIOptions.New(Model);
  Opts.Common.ApiKey := Key;
  Opts.Common.BaseUrl := BaseUrl;
  Opts.Common.ReadIdleTimeoutMs := 60000;
  P := NewOpenAIProvider(Opts);
  M := P.Complete(TCompletionRequest.New('').WithUserText(
    'Reply with exactly: OK'));
  Check(M.FinishReason = frStop, 'complete unaffected by idle watchdog');
  Check(MessageText(M) <> '', 'idle watchdog no false kill');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.e2e.live');
  if not E2EEnabled then
  begin
    WriteLn('e2e skipped: ', CRequiredEnvNote);
    T.Test('skip placeholder', @TestSkipWhenNotEnabled);
    if not T.Run then
      Halt(1);
    Halt(0);
  end;
  T.Test('openai complete', @TestOpenAIComplete);
  T.Test('openai stream', @TestOpenAIStream);
  T.Test('openai reasoning effort W7', @TestOpenAIReasoningEffortW7);
  T.Test('openai structured output W6', @TestOpenAIStructuredOutputW6);
  T.Test('anthropic complete', @TestAnthropicComplete);
  T.Test('openai idle timeout no false kill',
    @TestOpenAIIdleTimeoutNoFalseKill);
  if not T.Run then
    Halt(1);
end.
