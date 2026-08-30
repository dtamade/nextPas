program test_protocol;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.json,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.fold,
  nextpas.core.test;

{ fold 全词表矩阵（API.md §4；TESTING §3 test_protocol 行）：
  text/thinking 交错、tool 多槽并行、usage/finish 异序等价、
  信封事件、违例序列 aecProtocol }

function DText(const S: string): TStreamDelta;
begin
  Result := Default(TStreamDelta);
  Result.Kind := sdkTextDelta;
  Result.TextDelta := S;
end;

function DThink(const S: string): TStreamDelta;
begin
  Result := Default(TStreamDelta);
  Result.Kind := sdkThinkingDelta;
  Result.TextDelta := S;
end;

function DSig(const ASig: string): TStreamDelta;
begin
  Result := Default(TStreamDelta);
  Result.Kind := sdkThinkingDelta;
  Result.Signature := ASig;
end;

function DStart(AIdx: Integer; const AId, AName: string): TStreamDelta;
begin
  Result := Default(TStreamDelta);
  Result.Kind := sdkToolCallStart;
  Result.ToolIndex := AIdx;
  Result.ToolCallId := AId;
  Result.ToolName := AName;
end;

function DDelta(AIdx: Integer; const AFrag: string): TStreamDelta;
begin
  Result := Default(TStreamDelta);
  Result.Kind := sdkToolCallDelta;
  Result.ToolIndex := AIdx;
  Result.ArgumentsDelta := AFrag;
end;

function DEnd(AIdx: Integer): TStreamDelta;
begin
  Result := Default(TStreamDelta);
  Result.Kind := sdkToolCallEnd;
  Result.ToolIndex := AIdx;
end;

function DFinish(AR: TFinishReason): TStreamDelta;
begin
  Result := Default(TStreamDelta);
  Result.Kind := sdkFinish;
  Result.FinishReason := AR;
end;

function DUsage(AIn, AOut: Int64): TStreamDelta;
begin
  Result := Default(TStreamDelta);
  Result.Kind := sdkUsage;
  Result.Usage.InputTokens := AIn;
  Result.Usage.OutputTokens := AOut;
end;

function DError: TStreamDelta;
begin
  Result := Default(TStreamDelta);
  Result.Kind := sdkError;
  Result.Error.Message := 'mid-stream failure';
end;

function DEnvelope(const AId, AModel: string): TStreamDelta;
begin
  Result := Default(TStreamDelta);
  Result.Kind := sdkEnvelope;
  Result.MessageId := AId;
  Result.Model := AModel;
end;

{ 折叠并捕获协议错误；返回是否抛出，ACode 带回错误码 }
function TryFold(const ADeltas: array of TStreamDelta;
  out ACode: TAgentErrorCode): Boolean;
var
  Msg: TMessage;
begin
  Result := False;
  try
    FoldDeltas(ADeltas, Msg);
  except
    on E: EAgentError do
    begin
      ACode := E.ErrorCode;
      Result := True;
    end;
  end;
end;

procedure TestEmptyInput;
var
  M: TMessage;
begin
  FoldDeltas([], M);
  Check(M.Role = mrAssistant, 'empty folds to assistant');
  Check(M.IsEmpty, 'empty input is empty message');
  Check(M.FinishReason = frNone, 'empty finish none');
  Check(not M.Usage.Known, 'empty usage unknown');
  Check(Length(M.Parts) = 0, 'no parts');
end;

procedure TestSimpleText;
var
  M: TMessage;
  B: TAssistantBuild;
begin
  FoldDeltas([DText('He'), DText('llo')], M);
  Check(Length(M.Parts) = 1, 'single text part');
  Check(M.Parts[0].Kind = pkText, 'part kind text');
  Check(M.Parts[0].Text = 'Hello', 'text concatenated');
  Check(MessageText(M) = 'Hello', 'MessageText invariant');
  { 中途观测：已收段 + 当前累积 }
  B := TAssistantBuild.Create;
  try
    B.FoldDelta(DText('a'));
    B.FoldDelta(DText('b'));
    Check(B.PartialText = 'ab', 'partial before flush');
    B.FoldDelta(DThink('x'));
    Check(B.PartialText = 'ab', 'partial keeps flushed only');
  finally
    B.Free;
  end;
end;

procedure TestInterleave;
var
  M: TMessage;
begin
  FoldDeltas([DText('A'), DThink('B'), DText('C')], M);
  Check(Length(M.Parts) = 3, 'three parts on interleave');
  Check(M.Parts[0].Kind = pkText, 'part0 text');
  Check(M.Parts[1].Kind = pkThinking, 'part1 thinking');
  Check(M.Parts[2].Kind = pkText, 'part2 text new part');
  Check(M.Parts[0].Text = 'A', 'part0 content');
  Check(M.Parts[1].Text = 'B', 'part1 content');
  Check(M.Parts[2].Text = 'C', 'part2 content');
  Check(MessageText(M) = 'AC', 'thinking excluded from MessageText');
end;

procedure TestSignaturePassthrough;
var
  M: TMessage;
begin
  { anthropic 形态：thinking 内容先行，signature_delta 后到 }
  FoldDeltas([DThink('thought'), DSig('SIG'), DFinish(frStop)], M);
  Check(Length(M.Parts) = 1, 'one thinking part');
  Check(M.Parts[0].Kind = pkThinking, 'kind thinking');
  Check(M.Parts[0].Text = 'thought', 'thinking text');
  Check(M.Parts[0].Signature = 'SIG', 'signature kept on part');
  { 纯签名 delta（无内容）不产出空段，除非带签名 }
  FoldDeltas([DSig('S2'), DFinish(frStop)], M);
  Check(Length(M.Parts) = 1, 'signature-only part survives flush');
  Check(M.Parts[0].Signature = 'S2', 'signature-only content');
end;

procedure TestSingleToolCall;
var
  M: TMessage;
begin
  { 无 End 事件——OpenAI 形态，sdkFinish 隐式封槽 }
  FoldDeltas([DStart(0, 'call_1', 'get_weather'),
    DDelta(0, '{"city"'), DDelta(0, ':"SF"}'), DFinish(frToolCalls)], M);
  Check(Length(M.Parts) = 1, 'tool call folded to one part');
  Check(M.Parts[0].Kind = pkToolCall, 'kind toolcall');
  Check(M.Parts[0].ToolCallId = 'call_1', 'call id kept');
  Check(M.Parts[0].ToolName = 'get_weather', 'tool name kept');
  Check(M.Parts[0].ArgumentsJson = '{"city":"SF"}', 'arguments concatenated');
  Check(M.FinishReason = frToolCalls, 'finish tool calls');
  { 显式 End 的形态同样成立 }
  FoldDeltas([DStart(0, 'c2', 't2'), DDelta(0, '{}'), DEnd(0),
    DFinish(frStop)], M);
  Check(M.Parts[0].ArgumentsJson = '{}', 'explicit end closes slot');
end;

procedure TestParallelSlots;
var
  M: TMessage;
begin
  FoldDeltas([DStart(0, 'c0', 'alpha'), DStart(1, 'c1', 'beta'),
    DDelta(1, '{"k"'), DDelta(0, '{"a"'), DDelta(0, ':1}'),
    DDelta(1, ':2}'), DEnd(0), DEnd(1), DFinish(frToolCalls)], M);
  Check(Length(M.Parts) = 2, 'two slots two parts');
  Check(M.Parts[0].ToolName = 'alpha', 'slot0 name');
  Check(M.Parts[1].ToolName = 'beta', 'slot1 name');
  Check(M.Parts[0].ArgumentsJson = '{"a":1}', 'slot0 args intact');
  Check(M.Parts[1].ArgumentsJson = '{"k":2}', 'slot1 args intact');
  { 正文夹在并行工具之间时保持到达序 }
  FoldDeltas([DText('pre'), DStart(0, 'c', 'f'), DDelta(0, 'null'),
    DText('post')], M);
  Check(Length(M.Parts) = 3, 'interleaved text splits parts');
  Check(M.Parts[0].Text = 'pre', 'arrival order pre');
  Check(M.Parts[1].Kind = pkToolCall, 'tool in middle');
  Check(M.Parts[2].Kind = pkText, 'new text part after tool');
  Check(M.Parts[2].Text = 'post', 'arrival order post');
end;

procedure TestUsageFinishOrderEquivalence;
var
  M1, M2, M3: TMessage;
begin
  { usage/finish 三种到达顺序必须折叠出同一终态 }
  FoldDeltas([DText('x'), DUsage(11, 7), DFinish(frStop)], M1);
  FoldDeltas([DText('x'), DFinish(frStop), DUsage(11, 7)], M2);
  FoldDeltas([DUsage(11, 7), DText('x'), DFinish(frStop)], M3);
  Check(M1.Usage.InputTokens = 11, 'usage in seq1');
  Check(M1.Usage.OutputTokens = 7, 'usage out seq1');
  Check(M1.FinishReason = frStop, 'finish seq1');
  Check((M2.Usage.InputTokens = 11) and (M2.FinishReason = frStop),
    'seq2 equivalent');
  Check((M3.Usage.InputTokens = 11) and (M3.FinishReason = frStop),
    'seq3 equivalent');
  { usage 重入：最后一次生效 }
  FoldDeltas([DUsage(1, 1), DUsage(2, 3), DFinish(frStop)], M1);
  Check(M1.Usage.TotalKnownTokens = 5, 'later usage wins');
end;

procedure TestEnvelopeAndErrorSkip;
var
  M: TMessage;
begin
  FoldDeltas([DEnvelope('msg_9', 'gpt-x'), DText('hi'), DError,
    DText('!'), DFinish(frStop), DUsage(1, 1)], M);
  Check(M.Id = 'msg_9', 'message id from envelope');
  Check(M.Model = 'gpt-x', 'model from envelope');
  Check(MessageText(M) = 'hi!', 'error skipped not breaking stream');
  Check(M.FinishReason = frStop, 'normal finish after error skip');
end;

procedure TestViolations;
var
  Code: TAgentErrorCode;
  Bad: Boolean;
begin
  { 未 Start 先 Delta }
  Bad := TryFold([DDelta(0, '{}')], Code);
  Check(Bad and (Code = aecProtocol), 'delta before start is protocol');
  { 同 index 重复 Start }
  Bad := TryFold([DStart(0, 'c', 'f'), DStart(0, 'c2', 'g')], Code);
  Check(Bad and (Code = aecProtocol), 'duplicate start is protocol');
  { 负 index }
  Bad := TryFold([DStart(-1, 'c', 'f')], Code);
  Check(Bad and (Code = aecProtocol), 'negative start index is protocol');
  Bad := TryFold([DStart(0, 'c', 'f'), DDelta(-1, 'x')], Code);
  Check(Bad and (Code = aecProtocol), 'negative delta index is protocol');
  Bad := TryFold([DEnd(-1)], Code);
  Check(Bad and (Code = aecProtocol), 'negative end index is protocol');
  { End 之后 Delta }
  Bad := TryFold([DStart(0, 'c', 'f'), DEnd(0), DDelta(0, '{}')], Code);
  Check(Bad and (Code = aecProtocol), 'delta after end is protocol');
  { 未知槽位 End }
  Bad := TryFold([DEnd(4)], Code);
  Check(Bad and (Code = aecProtocol), 'unknown slot end is protocol');
  { 对照：跳过空隙的合法流不抛（index 不要求连续递增使用顺序）}
  Bad := TryFold([DStart(1, 'c', 'f'), DDelta(1, '{}'), DFinish(frStop)],
    Code);
  Check(not Bad, 'nonzero first index legal');
end;

{ F-M18 Extra 无损往返（TESTING §2）：fold 旁路 + MergeExtraJson 后者胜 }
procedure TestExtraRoundTrip;
var
  M: TMessage;
  D1, D2, D3: TStreamDelta;
  MJ: string;
  Doc: IJsonDocument;
  LE: TJsonText;
begin
  D1 := DText('hi');
  D1.UnmappedJson := '{"zz_a":1,"zz_b":2}';
  D2 := DText('!');
  D2.UnmappedJson := '{"zz_a":9,"zz_c":3}';
  // 同键后者胜：zz_a 应为 9
  FoldDeltas([D1, D2], M);
  Check(M.ExtraJson <> '', 'extra carried via fold UnmappedJson');
  Doc := JsonParse(M.ExtraJson);
  Check(not Doc.HasError, 'fold extra parses');
  Check(Doc.Root.ObjectHas('zz_a'), 'has zz_a');
  Check(Doc.Root.ObjectHas('zz_b'), 'has zz_b');
  Check(Doc.Root.ObjectHas('zz_c'), 'has zz_c');
  CheckEqual(Int64(9), Doc.Root.Get('zz_a').AsInt, 'after-wins zz_a=9');
  // MergeExtraJson 直接语义：后者覆盖
  LE := MergeExtraJson(['{"k":1,"x":10}', '{"k":2}']);
  Doc := JsonParse(LE);
  Check(not Doc.HasError, 'merge extra parses');
  CheckEqual(Int64(2), Doc.Root.Get('k').AsInt, 'MergeExtraJson after-wins');
  Check(Doc.Root.ObjectHas('x'), 'merge keeps non-conflicting key');
  // 空输入不伪造 extra
  D3 := DText('solo');
  FoldDeltas([D3], M);
  Check(M.ExtraJson = '', 'no unmapped => empty extra');
  // 信封 + 文本间 Extra 皆并入同一终态
  D1 := DEnvelope('mid','m');
  D1.UnmappedJson := '{"zz_env":5}';
  D2 := DText('body');
  D2.UnmappedJson := '{"zz_body":6}';
  FoldDeltas([D1, D2, DFinish(frStop)], M);
  Doc := JsonParse(M.ExtraJson);
  Check(Doc.Root.ObjectHas('zz_env') and Doc.Root.ObjectHas('zz_body'),
    'envelope+delta extras merged');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.fold');
  T.Test('empty input', @TestEmptyInput);
  T.Test('simple text', @TestSimpleText);
  T.Test('text thinking interleave', @TestInterleave);
  T.Test('signature passthrough', @TestSignaturePassthrough);
  T.Test('single tool call', @TestSingleToolCall);
  T.Test('parallel slots', @TestParallelSlots);
  T.Test('usage finish order equivalence', @TestUsageFinishOrderEquivalence);
  T.Test('envelope and error skip', @TestEnvelopeAndErrorSkip);
  T.Test('violations', @TestViolations);
  T.Test('extra roundtrip after-wins', @TestExtraRoundTrip);
  if not T.Run then Halt(1);
end.
