program test_compile_skeleton;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent,
  nextpas.core.test;

{ W0 骨架 gate：base/errors/门面可编译且词表基本语义成立
  （API.md §1/§2；TESTING §3 test_compile_skeleton 行）}

procedure TestSentinels;
var
  R: TCompletionRequest;
begin
  R := TCompletionRequest.New('gpt-test');
  Check(R.Model = 'gpt-test', 'factory keeps model');
  Check(R.MaxTokens = CMaxTokensUnset, 'max tokens unset');
  Check(R.Temperature = CTemperatureUnset, 'temperature unset');
  Check(R.TopP = CTopPUnset, 'top p unset');
  Check(R.Seed = CSeedUnset, 'seed unset');
  Check(Length(R.Messages) = 0, 'no messages');
  Check(Length(R.Tools) = 0, 'no tools');
  Check(R.ParallelToolCalls = tsUnset, 'parallel tool calls unset');
end;

procedure TestBuilders;
var
  R, R2: TCompletionRequest;
  Stops: TStringArray;
begin
  R := TCompletionRequest.New('m').WithSystem('sys');
  Check(R.System = 'sys', 'system set');
  R := R.WithMaxTokens(1024);
  Check(R.MaxTokens = 1024, 'max tokens set');
  R := R.WithTemperature(0.7);
  Check(Abs(R.Temperature - 0.7) < 1e-12, 'temperature set');
  Stops := TStringArray.Create('END');
  R := R.WithStop(Stops);
  Check(Length(R.StopSequences) = 1, 'stop copied');
  { 值语义：副本修改不回写旧值 }
  R2 := R;
  R2.Model := 'other';
  Check(R.Model = 'm', 'record copy is by value');
end;

procedure TestUserMessageBuilder;
var
  R: TCompletionRequest;
begin
  R := TCompletionRequest.New('m')
    .WithUserText('a').WithUserText('b');
  Check(Length(R.Messages) = 2, 'two user messages appended');
  Check(R.Messages[0].Role = mrUser, 'role user');
  Check(MessageText(R.Messages[1]) = 'b', 'message text of second');
  Check(Default(TMessage).IsEmpty, 'default message is empty');
  Check(not R.Messages[1].IsEmpty, 'message with part not empty');
end;

procedure TestUsageHelpers;
var
  U: TTokenUsage;
begin
  U.InputTokens := CUsageUnknown;
  U.OutputTokens := CUsageUnknown;
  U.CacheReadInputTokens := CUsageUnknown;
  U.CacheWriteInputTokens := CUsageUnknown;
  U.ReasoningTokens := CUsageUnknown;
  Check(not U.Known, 'all unknown usage not known');
  Check(U.TotalKnownTokens = 0, 'unknown usage total zero');
  U.InputTokens := 10;
  U.OutputTokens := 5;
  Check(U.Known, 'usage known after set');
  Check(U.TotalKnownTokens = 15, 'total known tokens');
end;

procedure TestErrorCodeForStatus;
begin
  Check(ErrorCodeForStatus(400) = aecInvalidRequest, '400 invalid request');
  Check(ErrorCodeForStatus(401) = aecAuthentication, '401 authentication');
  Check(ErrorCodeForStatus(403) = aecAuthentication, '403 authentication');
  Check(ErrorCodeForStatus(404) = aecNotFound, '404 not found');
  Check(ErrorCodeForStatus(408) = aecTimeout, '408 timeout');
  Check(ErrorCodeForStatus(422) = aecInvalidRequest, '422 invalid request');
  Check(ErrorCodeForStatus(429) = aecRateLimited, '429 rate limited');
  Check(ErrorCodeForStatus(500) = aecServer, '500 server');
  Check(ErrorCodeForStatus(503) = aecServer, '503 server');
  Check(ErrorCodeForStatus(200) = aecNone, '2xx none');
  Check(ErrorCodeForStatus(0) = aecTransport, '0 transport');
end;

procedure TestRetryableWhitelist;
begin
  Check(IsRetryable(aecRateLimited), 'rate limited retryable');
  Check(IsRetryable(aecTransport), 'transport retryable');
  Check(IsRetryable(aecTimeout), 'timeout retryable');
  Check(IsRetryable(aecServer), 'server retryable');
  Check(not IsRetryable(aecInvalidRequest), 'invalid request final');
  Check(not IsRetryable(aecProtocol), 'protocol final');
  Check(not IsRetryable(aecCancelled), 'cancelled final');
end;

procedure TestErrorEnvelope;
var
  E: EAgentError;
begin
  E := EAgentError.CreateUpstream(aecRateLimited, 'anthropic',
    'Number of requests too high', 'req-1', '{"error":{}}', 12000);
  try
    Check(E.Message = '[anthropic] rate_limited: Number of requests too high',
      'upstream message format');
    Check(E.ErrorCode = aecRateLimited, 'error code kept');
    Check(E.Retryable, 'retryable derived');
    Check(E.RetryAfterMs = 12000, 'retry after kept');
    Check(E.Provider = 'anthropic', 'provider kept');
    Check(E.RequestId = 'req-1', 'request id kept');
  finally
    E.Free;
  end;
  E := EAgentError.CreateLocal(aecConfig, 'missing api key');
  try
    Check(E.Message = 'missing api key', 'local message has no prefix');
    Check(E.Provider = '', 'local provider empty');
    Check(not E.Retryable, 'config not retryable');
    Check(E.RetryAfterMs = CRetryAfterUnknown, 'retry after unknown default');
  finally
    E.Free;
  end;
end;

procedure TestCancelledAndMisuse;
var
  E: EAgentError;
begin
  E := EAgentCancelled.Create;
  try
    Check(E.ErrorCode = aecCancelled, 'cancelled code fixed');
    Check(E.Message = 'operation cancelled', 'cancelled message fixed');
    Check(not E.Retryable, 'cancelled not retryable');
  finally
    E.Free;
  end;
  E := EAgentMisuse.Create('GetMessage while Active');
  try
    Check(E.ErrorCode = aecConfig, 'misuse maps to config');
    Check(E is EAgentError, 'misuse within family');
  finally
    E.Free;
  end;
end;

procedure TestFacadeForwarding;
var
  H: TWireHeaderArray;
  U: TTokenUsage;
  LTrunc: Boolean;
  S: string;
begin
  Check(nextpas.core.agent.ErrorCodeForStatus(429)
    = nextpas.core.agent.errors.ErrorCodeForStatus(429), 'facade status fwd');
  Check(nextpas.core.agent.IsRetryable(aecTransport)
    = nextpas.core.agent.errors.IsRetryable(aecTransport), 'facade retry fwd');
  Check(nextpas.core.agent.AgentErrorCodeName(aecContextOverflow)
    = 'context_overflow', 'facade name fwd');
  { W16.1 新增透出一站式（base/provider.common 真源，编译即通过，不触网） }
  Check(nextpas.core.agent.CAgentMaxRawBodySnippetBytes = 8*1024, 'facade const raw snippet 8KiB');
  Check(nextpas.core.agent.CAgentMaxWireHeaderValueBytes = 8*1024, 'facade const wire header 8KiB');
  Check(nextpas.core.agent.CAgentMaxWireTotalHeaderBytes = 64*1024, 'facade const wire total 64KiB');
  Check(nextpas.core.agent.CAgentMaxExtraKeys = 64, 'facade const extra 64');
  Check(nextpas.core.agent.CAgentMaxSlotMap = 256, 'facade const slot map 256');
  Check(nextpas.core.agent.CAgentMaxSuccessBodyBytes = 8*1024*1024, 'facade const success body 8MiB');
  SetLength(H, 1);
  H[0].Name := 'x-test';
  H[0].Value := 'v1';
  Check(nextpas.core.agent.WireHeaderValue(H, 'x-test') = 'v1', 'facade WireHeaderValue fwd');
  Check(nextpas.core.agent.MergeExtraJson(['{"a":1}', '{"a":2}']) = '{"a":2}', 'facade MergeExtraJson latter wins');
  Check(nextpas.core.agent.AgentUtf8SafeTruncate('hello', 4) = 'hell', 'facade Utf8SafeTruncate fwd');
  Check(nextpas.core.agent.AgentTruncateLines('a'#10'b'#10'c', 2) = 'a'#10'b', 'facade TruncateLines fwd');
  S := nextpas.core.agent.AgentTruncateEnvelope('a'#10'b', 10, 1, LTrunc);
  Check((S = 'a') and LTrunc, 'facade TruncateEnvelope fwd');
  nextpas.core.agent.AgentInitUsageUnknown(U);
  Check(U.InputTokens = CUsageUnknown, 'facade InitUsageUnknown fwd');
  Check(nextpas.core.agent.AgentJoinWireUrl('https://api.example.com/', 'https://fallback', '/chat') = 'https://api.example.com/v1/chat', 'facade JoinWireUrl fwd');
  Check(nextpas.core.agent.AgentJoinWireUrl('https://api.example.com/v1', 'https://fallback', '/chat') = 'https://api.example.com/v1/chat', 'facade JoinWireUrl keeps existing /v1');
  Check(nextpas.core.agent.AgentBuildSystemText('sys', nil) = 'sys', 'facade BuildSystemText fwd');
  SetLength(H, 1);
  H[0].Name := 'Authorization';
  H[0].Value := 'Bearer tok';
  nextpas.core.agent.AgentValidateWireHeaders(H);
  Check(True, 'facade ValidateWireHeaders fwd');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.skeleton');
  T.Test('request sentinels', @TestSentinels);
  T.Test('builder chain', @TestBuilders);
  T.Test('user message builder', @TestUserMessageBuilder);
  T.Test('usage helpers', @TestUsageHelpers);
  T.Test('status classifier', @TestErrorCodeForStatus);
  T.Test('retryable whitelist', @TestRetryableWhitelist);
  T.Test('error envelope', @TestErrorEnvelope);
  T.Test('cancelled and misuse', @TestCancelledAndMisuse);
  T.Test('facade forwarding', @TestFacadeForwarding);
  if not T.Run then Halt(1);
end.
