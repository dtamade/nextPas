program test_sse;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.sse,
  nextpas.core.test;

{ agent.sse 增量解析矩阵（TESTING §3 test_sse 行；WIRE-MAPPINGS §0）：
  帧跨 chunk 断裂、多行 data、CRLF/LF、BOM、event+data、半帧保持状态、
  UTF-8 多字节跨 Feed 断裂、EOF 收口、恶意超长行上限 }

procedure FeedStr(AP: TSSEParser; const S: string);
var
  Span: TByteSpan;
begin
  if S = '' then
    Exit;
  Span := TByteSpan.Create(@S[1], Length(S));
  AP.Feed(Span);
end;

function PopAll(AP: TSSEParser): TWireSSEEventArray;
var
  Ev: TWireSSEEvent;
  N: Integer;
begin
  Result := nil;
  while AP.PopEvent(Ev) do
  begin
    N := Length(Result);
    SetLength(Result, N + 1);
    Result[N] := Ev;
  end;
end;

procedure TestSingleFrameLF;
var
  P: TSSEParser;
  Events: TWireSSEEventArray;
begin
  P := TSSEParser.Create;
  try
    FeedStr(P, 'data: hello'#10#10);
    Events := PopAll(P);
    Check(Length(Events) = 1, 'one event');
    Check(Events[0].Event = '', 'no event field');
    Check(Events[0].Data = 'hello', 'data value');
  finally
    P.Free;
  end;
end;

procedure TestCRLFAndMultiFrame;
var
  P: TSSEParser;
  Events: TWireSSEEventArray;
begin
  P := TSSEParser.Create;
  try
    FeedStr(P, 'data: one'#13#10#13#10'data: two'#10#10);
    Events := PopAll(P);
    Check(Length(Events) = 2, 'two frames one feed');
    Check(Events[0].Data = 'one', 'crlf frame');
    Check(Events[1].Data = 'two', 'lf frame after crlf');
  finally
    P.Free;
  end;
end;

procedure TestEventDataCombo;
var
  P: TSSEParser;
  Events: TWireSSEEventArray;
begin
  P := TSSEParser.Create;
  try
    FeedStr(P, 'event: ping'#10'data: {"x":1}'#10#10);
    Events := PopAll(P);
    Check(Length(Events) = 1, 'combo event count');
    Check(Events[0].Event = 'ping', 'event name kept');
    Check(Events[0].Data = '{"x":1}', 'payload kept');
  finally
    P.Free;
  end;
end;

procedure TestMultilineData;
var
  P: TSSEParser;
  Events: TWireSSEEventArray;
begin
  P := TSSEParser.Create;
  try
    FeedStr(P, 'data: a'#10'data: b'#10#10);
    Events := PopAll(P);
    Check(Length(Events) = 1, 'multiline is one event');
    Check(Events[0].Data = 'a' + #10 + 'b', 'lines joined with lf');
  finally
    P.Free;
  end;
end;

procedure TestChunkSplit;
var
  P: TSSEParser;
  Events: TWireSSEEventArray;
begin
  P := TSSEParser.Create;
  try
    { 字节级断裂：字段名/值/终止行任意切 }
    FeedStr(P, 'da');
    Check(Length(PopAll(P)) = 0, 'nothing after field frag');
    FeedStr(P, 'ta: he');
    Check(Length(PopAll(P)) = 0, 'nothing mid value');
    FeedStr(P, 'llo'#10);
    Check(Length(PopAll(P)) = 0, 'half frame holds state');
    FeedStr(P, #10);
    Events := PopAll(P);
    Check(Length(Events) = 1, 'dispatched on blank line');
    Check(Events[0].Data = 'hello', 'split data intact');
  finally
    P.Free;
  end;
end;

procedure TestCommentsIgnored;
var
  P: TSSEParser;
  Events: TWireSSEEventArray;
begin
  P := TSSEParser.Create;
  try
    FeedStr(P, ': keep-alive'#10#10);
    Check(Length(PopAll(P)) = 0, 'pure comment no event');
    { 帧内注释不打断累积 }
    FeedStr(P, ': c'#10'data: v'#10#10);
    Events := PopAll(P);
    Check(Length(Events) = 1, 'comment inside frame ok');
    Check(Events[0].Data = 'v', 'data after comment');
    { event 无 data 的帧跳过 }
    FeedStr(P, 'event: foo'#10#10);
    Check(Length(PopAll(P)) = 0, 'event-only skipped');
    { id/retry v1 忽略 }
    FeedStr(P, 'id: 42'#10'retry: 100'#10'data: z'#10#10);
    Events := PopAll(P);
    Check((Length(Events) = 1) and (Events[0].Data = 'z'),
      'id retry ignored');
  finally
    P.Free;
  end;
end;

procedure TestBOM;
var
  P: TSSEParser;
  Events: TWireSSEEventArray;
begin
  P := TSSEParser.Create;
  try
    FeedStr(P, #$EF#$BB#$BF + 'data: x'#10#10);
    Events := PopAll(P);
    Check((Length(Events) = 1) and (Events[0].Data = 'x'),
      'bom skipped whole');
  finally
    P.Free;
  end;
  P := TSSEParser.Create;
  try
    { BOM 本身跨 Feed 断裂 }
    FeedStr(P, #$EF#$BB);
    FeedStr(P, #$BF'data: y'#10#10);
    Events := PopAll(P);
    Check((Length(Events) = 1) and (Events[0].Data = 'y'),
      'bom split across feeds');
  finally
    P.Free;
  end;
end;

procedure TestUtf8SplitAcrossFeeds;
var
  P: TSSEParser;
  Events: TWireSSEEventArray;
  LLine: string;
begin
  { "你好" 的 UTF-8 编码从中间切开喂入（WIRE-MAPPINGS §0 多字节边界）}
  LLine := 'data: 你好' + #10#10;
  P := TSSEParser.Create;
  try
    FeedStr(P, Copy(LLine, 1, 11));
    FeedStr(P, Copy(LLine, 12, MaxInt));
    Events := PopAll(P);
    Check(Length(Events) = 1, 'utf8 split one event');
    Check(Events[0].Data = '你好', 'multibyte intact');
  finally
    P.Free;
  end;
end;

procedure TestEofFinalize;
var
  P: TSSEParser;
  Events: TWireSSEEventArray;
  Ev: TWireSSEEvent;
begin
  P := TSSEParser.Create;
  try
    FeedStr(P, 'data: tail');
    Check(Length(PopAll(P)) = 0, 'nothing before finish');
    P.Finish;
    Events := PopAll(P);
    Check(Length(Events) = 1, 'trailing frame flushed at eof');
    Check(Events[0].Data = 'tail', 'tail data');
    P.Finish;                        { 幂等 }
    Check(Length(PopAll(P)) = 0, 'finish idempotent');
  finally
    P.Free;
  end;
  P := TSSEParser.Create;
  try
    P.Finish;
    Check(not P.PopEvent(Ev), 'finish without input clean');
    try
      FeedStr(P, 'data: '#10#10);
      Check(False, 'feed after finish must raise');
    except
      on E: EAgentMisuse do
        Check(True, 'misuse raised');
      on E: Exception do
        Check(False, 'wrong exception class');
    end;
  finally
    P.Free;
  end;
end;

procedure TestOverlongLineLimit;
var
  P: TSSEParser;
  Big: string;
begin
  P := TSSEParser.Create;
  try
    Big := StringOfChar('a', CSSEMaxLineBytes - 8);
    FeedStr(P, 'data: ');
    FeedStr(P, Big);
    Check(Length(PopAll(P)) = 0, 'just under limit accepted');
    FeedStr(P, StringOfChar('b', 16));
    Check(False, 'overlong line must raise');
  except
    on E: EAgentError do
      Check(E.ErrorCode = aecProtocol, 'overlong line is protocol error');
  end;
  P.Free;
end;

procedure TestSpaceStripAndEmptyData;
var
  P: TSSEParser;
  Events: TWireSSEEventArray;
begin
  P := TSSEParser.Create;
  try
    { 冒号后仅剥一个空格，其余保留 }
    FeedStr(P, 'data:   spaced'#10#10);
    Events := PopAll(P);
    Check(Events[0].Data = '  spaced', 'single space stripped');
  finally
    P.Free;
  end;
  P := TSSEParser.Create;
  try
    FeedStr(P, 'data:'#10'data:'#10#10);
    Events := PopAll(P);
    Check(Length(Events) = 1, 'empty data lines still dispatch');
    Check(Events[0].Data = #10, 'empty lines joined');
  finally
    P.Free;
  end;
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.agent.sse');
  T.Test('single frame lf', @TestSingleFrameLF);
  T.Test('crlf and multi frame', @TestCRLFAndMultiFrame);
  T.Test('event data combo', @TestEventDataCombo);
  T.Test('multiline data', @TestMultilineData);
  T.Test('chunk split', @TestChunkSplit);
  T.Test('comments ignored', @TestCommentsIgnored);
  T.Test('bom', @TestBOM);
  T.Test('utf8 split across feeds', @TestUtf8SplitAcrossFeeds);
  T.Test('eof finalize', @TestEofFinalize);
  T.Test('overlong line limit', @TestOverlongLineLimit);
  T.Test('space strip and empty data', @TestSpaceStripAndEmptyData);
  if not T.Run then Halt(1);
end.
