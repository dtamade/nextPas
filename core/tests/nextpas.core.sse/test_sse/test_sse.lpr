program test_sse;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.sse.base,
  nextpas.core.sse.parser,
  nextpas.core.sse;

var
  T: TTestRunner;

procedure TestSimpleEvent;
var
  LEvents: TSseEventArray;
begin
  LEvents := SseParseAll('data: hello' + #10 + #10);
  CheckEqual(Int64(1), Int64(Length(LEvents)), 'count');
  CheckEqual('message', LEvents[0].EventType, 'default type');
  CheckEqual('hello', LEvents[0].Data, 'data');
end;

procedure TestNamedEvent;
var
  LEvents: TSseEventArray;
begin
  LEvents := SseParseAll('event: update' + #10 + 'data: {}' + #10 + #10);
  CheckEqual(Int64(1), Int64(Length(LEvents)), 'count');
  CheckEqual('update', LEvents[0].EventType, 'event type');
  CheckEqual('{}', LEvents[0].Data, 'data');
end;

procedure TestMultiLineData;
var
  LEvents: TSseEventArray;
begin
  LEvents := SseParseAll('data: line1' + #10 + 'data: line2' + #10 + #10);
  CheckEqual(Int64(1), Int64(Length(LEvents)), 'count');
  CheckEqual('line1' + #10 + 'line2', LEvents[0].Data, 'joined data');
end;

procedure TestIdField;
var
  LEvents: TSseEventArray;
begin
  LEvents := SseParseAll('id: 123' + #10 + 'data: x' + #10 + #10);
  CheckEqual(Int64(1), Int64(Length(LEvents)), 'count');
  CheckEqual('123', LEvents[0].Id, 'id');
  CheckEqual('x', LEvents[0].Data, 'data');
end;

procedure TestRetryField;
var
  LEvents: TSseEventArray;
begin
  LEvents := SseParseAll('retry: 5000' + #10 + 'data: x' + #10 + #10);
  CheckEqual(Int64(1), Int64(Length(LEvents)), 'count');
  CheckEqual(True, LEvents[0].HasRetry, 'has retry');
  CheckEqual(Int64(5000), Int64(LEvents[0].RetryMs), 'retry ms');
end;

procedure TestCommentIgnored;
var
  LEvents: TSseEventArray;
begin
  LEvents := SseParseAll(': comment' + #10 + 'data: x' + #10 + #10);
  CheckEqual(Int64(1), Int64(Length(LEvents)), 'count');
  CheckEqual('x', LEvents[0].Data, 'data after comment');
end;

procedure TestCRLFLineEndings;
var
  LEvents: TSseEventArray;
begin
  LEvents := SseParseAll('event: ping' + #13#10 + 'data: pong' + #13#10 + #13#10);
  CheckEqual(Int64(1), Int64(Length(LEvents)), 'count');
  CheckEqual('ping', LEvents[0].EventType, 'type');
  CheckEqual('pong', LEvents[0].Data, 'data');
end;

procedure TestCROnlyLineEndings;
var
  LEvents: TSseEventArray;
begin
  LEvents := SseParseAll('event: cr' + #13 + 'data: test' + #13 + #13);
  CheckEqual(Int64(1), Int64(Length(LEvents)), 'count');
  CheckEqual('cr', LEvents[0].EventType, 'type');
  CheckEqual('test', LEvents[0].Data, 'data');
end;

procedure TestIncrementalFeed;
var
  LParser: TSseParser;
  LEvent: TSseEvent;
begin
  LParser := TSseParser.Create;
  LParser.Feed('data: hel');
  Check(not LParser.TryReadEvent(LEvent), 'no event yet');
  LParser.Feed('lo' + #10 + #10);
  Check(LParser.TryReadEvent(LEvent), 'event available');
  CheckEqual('hello', LEvent.Data, 'data');
  LParser.Free;
end;

procedure TestMultipleEvents;
var
  LEvents: TSseEventArray;
begin
  LEvents := SseParseAll('data: first' + #10 + #10 + 'data: second' + #10 + #10);
  CheckEqual(Int64(2), Int64(Length(LEvents)), 'count');
  CheckEqual('first', LEvents[0].Data, 'first data');
  CheckEqual('second', LEvents[1].Data, 'second data');
end;

procedure TestIdWithNulIgnored;
var
  LParser: TSseParser;
  LEvent: TSseEvent;
begin
  LParser := TSseParser.Create;
  LParser.Feed('id: good' + #10 + 'data: a' + #10 + #10);
  LParser.TryReadEvent(LEvent);
  CheckEqual('good', LParser.GetLastEventId, 'good id set');
  { Now feed id with NUL - should be ignored }
  LParser.Feed('id: bad' + #0 + 'id' + #10 + 'data: b' + #10 + #10);
  LParser.TryReadEvent(LEvent);
  CheckEqual('good', LParser.GetLastEventId, 'nul id ignored');
  LParser.Free;
end;

procedure TestNonNumericRetryIgnored;
var
  LEvents: TSseEventArray;
begin
  LEvents := SseParseAll('retry: abc' + #10 + 'data: x' + #10 + #10);
  CheckEqual(Int64(1), Int64(Length(LEvents)), 'count');
  CheckEqual(False, LEvents[0].HasRetry, 'non-numeric retry ignored');
end;

procedure TestParserLastEventId;
var
  LParser: TSseParser;
  LEvent: TSseEvent;
begin
  LParser := TSseParser.Create;
  LParser.Feed('id: 42' + #10 + 'data: a' + #10 + #10);
  LParser.TryReadEvent(LEvent);
  CheckEqual('42', LParser.GetLastEventId, 'last id persists');
  { Next event without id still has last id }
  LParser.Feed('data: b' + #10 + #10);
  LParser.TryReadEvent(LEvent);
  CheckEqual('42', LEvent.Id, 'id carried forward');
  LParser.Free;
end;

procedure TestFinishWithoutBlankLineNoDispatch;
var
  LParser: TSseParser;
  LEvent: TSseEvent;
begin
  { Feed data without trailing blank line, then Finish - should NOT dispatch }
  LParser := TSseParser.Create;
  LParser.Feed('data: incomplete');
  LParser.Finish;
  Check(not LParser.TryReadEvent(LEvent), 'no dispatch without blank line');
  LParser.Free;
end;

procedure TestFinishWithBlankLineDispatches;
var
  LParser: TSseParser;
  LEvent: TSseEvent;
begin
  { Feed data with trailing blank line, then Finish - should dispatch }
  LParser := TSseParser.Create;
  LParser.Feed('data: complete' + #10 + #10);
  LParser.Finish;
  Check(LParser.TryReadEvent(LEvent), 'dispatch with blank line');
  CheckEqual('complete', LEvent.Data, 'data');
  LParser.Free;
end;

procedure TestEmptyDataField;
var
  LEvents: TSseEventArray;
begin
  { "data:" with empty value still counts as having data }
  LEvents := SseParseAll('data:' + #10 + #10);
  CheckEqual(Int64(1), Int64(Length(LEvents)), 'empty data dispatches');
  CheckEqual('', LEvents[0].Data, 'data is empty string');
end;

procedure TestBufferOverflow;
var
  LParser: TSseParser;
  LEvent: TSseEvent;
  LHuge: string;
begin
  LParser := TSseParser.Create;
  { Feed more than 1MB without a newline }
  SetLength(LHuge, 1024 * 1024 + 100);
  FillChar(LHuge[1], Length(LHuge), Ord('x'));
  LParser.Feed(LHuge);
  Check(LParser.HasError, 'error state set');
  Check(not LParser.TryReadEvent(LEvent), 'no events after overflow');
  LParser.Free;
end;

begin
  T := TTestRunner.Create('nextpas.core.sse');
  T.Run('Simple event', @TestSimpleEvent);
  T.Run('Named event', @TestNamedEvent);
  T.Run('Multi-line data', @TestMultiLineData);
  T.Run('ID field', @TestIdField);
  T.Run('Retry field', @TestRetryField);
  T.Run('Comment ignored', @TestCommentIgnored);
  T.Run('CRLF line endings', @TestCRLFLineEndings);
  T.Run('CR-only line endings', @TestCROnlyLineEndings);
  T.Run('Incremental feed', @TestIncrementalFeed);
  T.Run('Multiple events', @TestMultipleEvents);
  T.Run('ID with NUL ignored', @TestIdWithNulIgnored);
  T.Run('Non-numeric retry ignored', @TestNonNumericRetryIgnored);
  T.Run('Parser last event id', @TestParserLastEventId);
  T.Run('Finish without blank line', @TestFinishWithoutBlankLineNoDispatch);
  T.Run('Finish with blank line', @TestFinishWithBlankLineDispatches);
  T.Run('Empty data field', @TestEmptyDataField);
  T.Run('Buffer overflow', @TestBufferOverflow);
  T.Summary;
end.
