program test_provider_common;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.provider.common,
  nextpas.core.test;

{ provider.common 错误分类器直接用例（ROADMAP Inbox 审计记录承诺的补齐）：
  ParseRetryAfterMs 三形态全集（ms 头/秒级头/date 拒绝/负值不信任）、
  MatchesOverflowPhrases 措辞全集（WIRE-MAPPINGS §0 六短语）、
  BuildUpstreamError 分类契约（ERRORS.md §3）}

{ 偶数个元素两两成对构造头数组：Name, Value, Name, Value, ... }
function Hdrs(const APairs: array of string): TWireHeaderArray;
var
  I: Integer;
begin
  SetLength(Result, Length(APairs) div 2);
  for I := 0 to High(Result) do
  begin
    Result[I].Name := APairs[I * 2];
    Result[I].Value := APairs[I * 2 + 1];
  end;
end;

procedure TestParseMsHeader;
begin
  Check(ParseRetryAfterMs(Hdrs(['retry-after-ms', '7500'])) = 7500, 'ms header parsed');
  Check(ParseRetryAfterMs(Hdrs(['retry-after-ms', ' 250 '])) = 250, 'ms header trimmed');
  Check(ParseRetryAfterMs(Hdrs(['RETRY-AFTER-MS', '90'])) = 90, 'header name case-insensitive');
end;

procedure TestParseSecondsHeader;
begin
  Check(ParseRetryAfterMs(Hdrs(['Retry-After', '120'])) = 120000, 'seconds scaled to ms');
  Check(ParseRetryAfterMs(Hdrs(['retry-after', '0'])) = 0, 'zero seconds is valid zero delay');
end;

procedure TestParsePrecedence;
begin
  Check(ParseRetryAfterMs(Hdrs(['retry-after-ms', '250', 'retry-after', '9'])) = 250,
    'ms header wins over seconds');
  Check(ParseRetryAfterMs(Hdrs(['retry-after-ms', 'abc', 'retry-after', '4'])) = 4000,
    'unparseable ms falls through to seconds');
end;

procedure TestParseRejectsNonNumeric;
begin
  Check(ParseRetryAfterMs(Hdrs(['retry-after', 'Wed, 21 Oct 2015 07:28:00 GMT']))
    = CRetryAfterUnknown, 'http-date not fabricated');
  Check(ParseRetryAfterMs(Hdrs(['retry-after', 'soon'])) = CRetryAfterUnknown,
    'garbage seconds rejected');
  Check(ParseRetryAfterMs(Hdrs([])) = CRetryAfterUnknown, 'absent headers unknown');
end;

procedure TestParseNegativeNotTrusted;
begin
  { 负值是外部输入的整数边界：不信任，落秒级/unknown——防恶意上游绕过重试总预算 }
  Check(ParseRetryAfterMs(Hdrs(['retry-after-ms', '-50', 'retry-after', '3'])) = 3000,
    'negative ms untrusted, falls to seconds');
  Check(ParseRetryAfterMs(Hdrs(['retry-after-ms', '-50'])) = CRetryAfterUnknown,
    'negative ms alone unknown');
  Check(ParseRetryAfterMs(Hdrs(['retry-after', '-2'])) = CRetryAfterUnknown,
    'negative seconds unknown');
end;

procedure TestOverflowPhraseFullSet;
const
  PHRASES: array[0..5] of string = (
    'context length', 'maximum context', 'token limit',
    'too many tokens', 'context_length_exceeded', 'prompt is too long');
var
  I: Integer;
begin
  for I := Low(PHRASES) to High(PHRASES) do
    Check(MatchesOverflowPhrases(PHRASES[I]), 'phrase recognized: ' + PHRASES[I]);
end;

procedure TestOverflowCaseAndPosition;
begin
  Check(MatchesOverflowPhrases('Your CONTEXT LENGTH exceeds the model limit'),
    'case-insensitive');
  Check(MatchesOverflowPhrases('Error: prompt is too long for model gpt-x'),
    'substring anywhere');
  Check(MatchesOverflowPhrases('This model''s maximum context length is 8192 tokens'),
    'natural upstream wording');
end;

procedure TestOverflowNoFalsePositive;
begin
  Check(not MatchesOverflowPhrases('rate limit exceeded, retry after 30s'),
    'rate limit is not context overflow');
  Check(not MatchesOverflowPhrases('context'), 'partial word does not match');
  Check(not MatchesOverflowPhrases(''), 'empty message no match');
end;

procedure TestBuildUpstreamClassifier;
var
  E: EAgentError;
begin
  E := BuildUpstreamError('openai',
    '{"error":{"message":"maximum context reached"}}', 400, Hdrs([]));
  try
    Check(E.ErrorCode = aecContextOverflow, '400 + overflow phrase -> contextOverflow');
    Check(not E.Retryable, 'context overflow final');
    Check(E.RetryAfterMs = CRetryAfterUnknown, 'non-429 has unknown retry-after');
  finally
    E.Free;
  end;

  E := BuildUpstreamError('openai',
    '{"error":{"message":"invalid api key"}}', 401, Hdrs([]));
  try
    Check(E.ErrorCode = aecAuthentication, '401 authentication');
  finally
    E.Free;
  end;

  E := BuildUpstreamError('anthropic',
    '{"error":{"message":"Number of requests too high"}}', 429,
    Hdrs(['retry-after-ms', '7500']));
  try
    Check(E.ErrorCode = aecRateLimited, '429 rate limited');
    Check(E.Retryable, 'rate limited retryable');
    Check(E.RetryAfterMs = 7500, '429 carries parsed retry-after');
  finally
    E.Free;
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.provider.common');
  T.Test('parse retry-after-ms header', @TestParseMsHeader);
  T.Test('parse seconds header', @TestParseSecondsHeader);
  T.Test('parse precedence ms over seconds', @TestParsePrecedence);
  T.Test('parse rejects non-numeric forms', @TestParseRejectsNonNumeric);
  T.Test('parse negative values not trusted', @TestParseNegativeNotTrusted);
  T.Test('overflow phrase full set', @TestOverflowPhraseFullSet);
  T.Test('overflow case and position', @TestOverflowCaseAndPosition);
  T.Test('overflow no false positive', @TestOverflowNoFalsePositive);
  T.Test('BuildUpstreamError classifier contract', @TestBuildUpstreamClassifier);
  if not T.Run then Halt(1);
end.
