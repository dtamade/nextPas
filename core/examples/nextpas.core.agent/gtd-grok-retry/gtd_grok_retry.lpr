program gtd_grok_retry;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.clock,
  nextpas.core.agent.retry,
  nextpas.core.agent.throttle,
  nextpas.core.agent.provider.openai,
  nextpas.core.agent.provider.fake,
  nextpas.core.agent.loop,
  nextpas.core.os.env,
  nextpas.core.json;

{ GTD Grok Retry: NewGrokProvider→WithRetry→Throttled chain,
  Connect/Total/ReadIdle triple (AI_TOTAL_TIMEOUT_MS=60000),
  Stream→Fold + Loop Run + transcript. Fake fallback offline.
  Ref: task888/src/gtd888.tui.ai.pas }

const
  AI_TOTAL_TIMEOUT_MS = 60000;
  AI_CONNECT_TIMEOUT_MS = 10000;
  AI_READ_IDLE_TIMEOUT_MS = 60000;
  CSCRIPT = '[{"deltas":[{"kind":"text_delta","text":"GTD: capture → clarify → organize → reflect → engage."},{"kind":"finish","reason":"stop"},{"kind":"usage","in":12,"out":14}]}]';
  CSCRIPT_LOOP = '[{"deltas":[{"kind":"tool_call_start","index":0,"id":"call_1","name":"capture"},{"kind":"tool_call_delta","index":0,"args":"{\"idea\":\"buy milk\"}"},{"kind":"tool_call_end","index":0},{"kind":"finish","reason":"tool_calls"}]},{"deltas":[{"kind":"text_delta","text":"Captured: buy milk → inbox."},{"kind":"finish","reason":"stop"},{"kind":"usage","in":40,"out":9}]}]';

type
  TCaptureTool = class(TInterfacedObject, IAgentTool)
  private FSpec: TToolSpec;
  public
    constructor Create;
    function Spec: TToolSpec;
    function Execute(const AArgumentsJson: TJsonText; const ACtx: IToolContext): TToolResult;
  end;

constructor TCaptureTool.Create;
begin
  inherited Create;
  FSpec := Default(TToolSpec);
  FSpec.Name := 'capture';
  FSpec.Description := 'capture an idea into inbox';
  FSpec.ParametersJson := '{"type":"object","required":["idea"],"properties":{"idea":{"type":"string"}}}';
end;

function TCaptureTool.Spec: TToolSpec;
begin Result := FSpec; end;

function TCaptureTool.Execute(const AArgumentsJson: TJsonText; const ACtx: IToolContext): TToolResult;
begin Result := Default(TToolResult); Result.ContentJson := '{"stored":true}'; end;

function TextOfParts(const AMsg: TMessage): string;
var I: Integer;
begin Result := ''; for I := 0 to High(AMsg.Parts) do if AMsg.Parts[I].Kind = pkText then Result := Result + AMsg.Parts[I].Text; end;

procedure OnRetryAttempt(const AAttempt: Integer; const ADelayMs: Int64; const ALastError: EAgentError);
begin
  if ALastError = nil then WriteLn('[retry] attempt ', AAttempt, ' delay=', ADelayMs, 'ms')
  else WriteLn('[retry] attempt ', AAttempt, ' delay=', ADelayMs, 'ms last=', AgentErrorCodeName(ALastError.ErrorCode));
end;

function BuildProviderChain: IAgentProvider;
var LKey, LModel, LBaseUrl: string; LOpts: TGrokOptions; LInner: IAgentProvider; LPolicy: TRetryPolicy; LClock: IAgentClock; LGate: IAgentRateGate;
begin
  LKey := GetEnvironmentVariable('NEXTPAS_AGENT_GROK_API_KEY');
  LModel := GetEnvironmentVariable('NEXTPAS_AGENT_GROK_MODEL'); if LModel = '' then LModel := 'grok-4';
  LBaseUrl := GetEnvironmentVariable('NEXTPAS_AGENT_GROK_BASE_URL');
  if LKey <> '' then
  begin
    LOpts := TGrokOptions.New(LModel); LOpts.Common.ApiKey := LKey;
    if LBaseUrl <> '' then LOpts.Common.BaseUrl := LBaseUrl;
    LOpts.Common.ConnectTimeoutMs := AI_CONNECT_TIMEOUT_MS;
    LOpts.Common.TotalTimeoutMs := AI_TOTAL_TIMEOUT_MS;
    LOpts.Common.ReadIdleTimeoutMs := AI_READ_IDLE_TIMEOUT_MS;
    LInner := NewGrokProvider(LOpts);
    WriteLn('[provider] GrokProvider model=', LModel, ' url=', BuildGrokUrl(LOpts.Common.BaseUrl));
  end else begin WriteLn('[provider] no NEXTPAS_AGENT_GROK_API_KEY → FakeProvider'); LInner := NewFakeProvider(CSCRIPT); end;
  LClock := NewSystemClock; LPolicy := TRetryPolicy.Default.WithOnAttempt(@OnRetryAttempt);
  LInner := WithRetry(LInner, LPolicy, LClock);
  LGate := NewTokenBucketGate(5.0, 10.0);
  Result := NewThrottledProvider(LInner, LGate, LClock, TThrottlePolicy.Default);
  WriteLn('[chain] WithRetry → Throttled(TokenBucket 5/s burst 10) ready');
end;

procedure DemoStreamFold(const AProv: IAgentProvider);
var LReq: TCompletionRequest; LComp: IAgentCompletion; LDelta: TStreamDelta; LMsg: TMessage;
begin
  WriteLn('--- Stream→Fold (gtd888 pattern) ---');
  LReq := TCompletionRequest.New('grok-4').WithSystem('You are a GTD assistant. Be concise.').WithUserText('GTD next action for "buy milk"?');
  LComp := AProv.Stream(LReq);
  while LComp.NextDelta(LDelta) do if LDelta.Kind = sdkTextDelta then Write('[chunk] ', LDelta.TextDelta, LineEnding);
  LMsg := LComp.GetMessage; WriteLn('folded: ', TextOfParts(LMsg));
  if LMsg.Usage.Known then WriteLn('usage in=', LMsg.Usage.InputTokens, ' out=', LMsg.Usage.OutputTokens);
end;

procedure DemoLoop(const AProv: IAgentProvider);
var LLoop: TAgentLoop; LRun: IAgentLoopRun; LMsg: TMessage; LTranscript: TMessageArray; I: Integer;
begin
  WriteLn('--- Loop Run(userText) + transcript ---');
  if Pos('fake', AProv.GetName) = 0 then WriteLn('[loop] live provider → FakeProvider loop for determinism');
  LLoop := TAgentLoop.Create(NewFakeProvider(CSCRIPT_LOOP));
  try
    LLoop.Options.RequestBase.Model := 'grok-4'; LLoop.AddTool(TCaptureTool.Create);
    LRun := LLoop.Run('Capture idea: buy milk');
    WriteLn('outcome=', Ord(LRun.Outcome));
    if LRun.TryGetFinalMessage(LMsg) then WriteLn('final: ', TextOfParts(LMsg));
    LTranscript := LRun.Transcript; WriteLn('transcript messages=', Length(LTranscript));
    for I := 0 to High(LTranscript) do WriteLn('  [', I, '] role=', Ord(LTranscript[I].Role), ' text="', TextOfParts(LTranscript[I]), '"');
    if LRun.TotalUsage.Known then WriteLn('total usage out=', LRun.TotalUsage.OutputTokens);
  finally LLoop.Free; end;
end;

var LProv: IAgentProvider;
begin
  LProv := BuildProviderChain; WriteLn('provider chain: ', LProv.GetName);
  try DemoStreamFold(LProv); except on E: EAgentError do WriteLn('Stream failed: ', AgentErrorCodeName(E.ErrorCode), ' ', E.Message); end;
  DemoLoop(LProv); WriteLn('done');
end.
