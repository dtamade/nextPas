program test_http_sse;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.test,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.sse,
  nextpas.core.fs;


type
  TMockResponseWriter = class(TInterfacedObject, IHttpResponseWriter, IHttpResponseBodyBytes)
  private
    FStatus: THttpStatus;
    FBody: string;
    FBodyBytes: TBytes;
    FHeaders: IHttpHeaders;
    FBodyBytesWritten: Int64;
    FMaxWriteSize: SizeUInt;
    FRaiseOnWrite: Boolean;
    FWriteHeaderCount: Int32;
    FFlushCount: Int32;
  public
    constructor Create;
    procedure SetMaxWriteSize(const AValue: SizeUInt);
    procedure SetRaiseOnWrite(const AValue: Boolean);
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    function GetBodyBytesWritten: Int64;
    property Status: THttpStatus read FStatus;
    property Body: string read FBody;
    property BodyBytes: TBytes read FBodyBytes;
    property WriteHeaderCount: Int32 read FWriteHeaderCount;
    property FlushCount: Int32 read FFlushCount;
  end;

constructor TMockResponseWriter.Create;
begin
  inherited Create;
  FStatus := 0;
  FBody := '';
  FBodyBytes := nil;
  FHeaders := NewHttpHeaders;
  FBodyBytesWritten := 0;
  FMaxWriteSize := High(SizeUInt);
  FRaiseOnWrite := False;
  FWriteHeaderCount := 0;
  FFlushCount := 0;
end;

procedure TMockResponseWriter.SetMaxWriteSize(const AValue: SizeUInt);
begin
  FMaxWriteSize := AValue;
end;

procedure TMockResponseWriter.SetRaiseOnWrite(const AValue: Boolean);
begin
  FRaiseOnWrite := AValue;
end;

procedure TMockResponseWriter.WriteHeader(const AStatus: THttpStatus);
begin
  Inc(FWriteHeaderCount);
  FStatus := AStatus;
end;

function TMockResponseWriter.GetStatus: THttpStatus;
begin
  Result := FStatus;
end;

function TMockResponseWriter.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function TMockResponseWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LStr: string;
  LOldLen: SizeUInt;
  LWriteCount: SizeUInt;
begin
  if FRaiseOnWrite then
    raise EIOError.Create('mock response write failed');
  LWriteCount := ACount;
  if LWriteCount > FMaxWriteSize then
    LWriteCount := FMaxWriteSize;
  SetLength(LStr, LWriteCount);
  if LWriteCount > 0 then
    Move(ABuf, LStr[1], LWriteCount);
  FBody := FBody + LStr;
  LOldLen := SizeUInt(Length(FBodyBytes));
  SetLength(FBodyBytes, LOldLen + LWriteCount);
  if LWriteCount > 0 then
    Move(ABuf, FBodyBytes[LOldLen], LWriteCount);
  Inc(FBodyBytesWritten, Int64(LWriteCount));
  Result := LWriteCount;
end;

procedure TMockResponseWriter.Flush;
begin
  Inc(FFlushCount);
end;

function TMockResponseWriter.GetBodyBytesWritten: Int64;
begin
  Result := FBodyBytesWritten;
end;


{ SSE tests }
procedure TestSSEEventWriterWritesEvents;
var
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LWriter: ISSEEventWriter;
begin
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LWriter := StartSSE(LW);
  Check(LWriter.IsOpen, 'SSE writer is open');
  LWriter.WriteEventSimple('message', 'hello', '');
  Check(Pos('data: hello', LWObj.Body) > 0, 'SSE writes data line');
  LWriter.Close;
  Check(not LWriter.IsOpen, 'SSE writer is closed after Close');
end;

procedure TestSSEEventWriterWritesEventType;
var
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LWriter: ISSEEventWriter;
begin
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LWriter := StartSSE(LW);
  LWriter.WriteEventSimple('update', '{"x":1}', 'evt-1');
  Check(Pos('event: update', LWObj.Body) > 0, 'SSE writes event type');
  Check(Pos('id: evt-1', LWObj.Body) > 0, 'SSE writes event id');
  Check(Pos('data: {"x":1}', LWObj.Body) > 0, 'SSE writes event data');
  LWriter.Close;
end;

procedure TestSSEEventWriterWritesComment;
var
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LWriter: ISSEEventWriter;
begin
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LWriter := StartSSE(LW);
  LWriter.WriteComment('heartbeat');
  Check(Pos(': heartbeat', LWObj.Body) > 0, 'SSE writes comment');
  LWriter.Close;
end;

procedure TestSSEEventWriterSetsHeaders;
var
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LWriter: ISSEEventWriter;
begin
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LWriter := StartSSE(LW);
  CheckEqual('text/event-stream', LWObj.GetHeaders.Get('content-type'),
    'SSE sets content-type');
  CheckEqual('no-cache', LWObj.GetHeaders.Get('cache-control'),
    'SSE sets cache-control');
  LWriter.Close;
end;

procedure TestSSEEventWriterMultilineData;
var
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LWriter: ISSEEventWriter;
begin
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LWriter := StartSSE(LW);
  LWriter.WriteEventSimple('message', 'line1'#10'line2', '');
  Check(Pos('data: line1', LWObj.Body) > 0, 'SSE writes first data line');
  Check(Pos('data: line2', LWObj.Body) > 0, 'SSE writes second data line');
  LWriter.Close;
end;

procedure TestSSEEventWriterHandlesShortWrites;
var
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LWriter: ISSEEventWriter;
begin
  LWObj := TMockResponseWriter.Create;
  LWObj.SetMaxWriteSize(2);
  LW := LWObj;
  LWriter := StartSSE(LW);
  LWriter.WriteEventSimple('message', 'hello', '');
  Check(Pos('event: message'#10, LWObj.Body) > 0,
    'SSE event line survives short writes');
  Check(Pos('data: hello'#10#10, LWObj.Body) > 0,
    'SSE data and terminator survive short writes');
end;

procedure TestSSEEventWriterSplitsCarriageReturnData;
var
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LWriter: ISSEEventWriter;
begin
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LWriter := StartSSE(LW);
  LWriter.WriteEventSimple('message', 'line1'#13'line2', '');
  Check(Pos('data: line1'#10, LWObj.Body) > 0,
    'SSE writes first CR-delimited data line');
  Check(Pos('data: line2'#10, LWObj.Body) > 0,
    'SSE writes second CR-delimited data line');
end;

procedure TestSSEEventWriterRejectsFieldInjection;
var
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LWriter: ISSEEventWriter;
  LCaught: Boolean;
begin
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LWriter := StartSSE(LW);
  LCaught := False;
  try
    LWriter.WriteEventSimple('message'#10'id: injected', 'body', '');
    Check(False, 'SSE event name newline must raise');
  except
    on E: EHttpError do
      LCaught := E.Kind = hekArgument;
  end;
  Check(LCaught, 'SSE event name injection rejected as hekArgument');
  LCaught := False;
  try
    LWriter.WriteEventSimple('message', 'body', 'ok'#13#10'retry: 1');
    Check(False, 'SSE id newline must raise');
  except
    on E: EHttpError do
      LCaught := E.Kind = hekArgument;
  end;
  Check(LCaught, 'SSE id injection rejected as hekArgument');
end;

procedure TestSSEStartNilWriterRaisesHekArgument;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    StartSSE(nil);
    Check(False, 'StartSSE(nil) must raise');
  except
    on E: EHttpError do
      LCaught := (E.Kind = hekArgument) and (Pos('nil', E.Message) > 0);
  end;
  Check(LCaught, 'StartSSE(nil) raises hekArgument');
end;

procedure TestSSEWriteRetryNegativeRaisesHekArgument;
var
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LWriter: ISSEEventWriter;
  LEvt: TSSEvent;
  LCaught: Boolean;
begin
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LWriter := StartSSE(LW);
  LCaught := False;
  try
    LWriter.WriteRetry(-1);
    Check(False, 'WriteRetry(-1) must raise');
  except
    on E: EHttpError do
      LCaught := (E.Kind = hekArgument) and (Pos('negative', E.Message) > 0);
  end;
  Check(LCaught, 'WriteRetry(-1) raises hekArgument');
  LEvt := MakeSSEvent('message', 'body', '');
  LEvt.Retry := -5;
  LCaught := False;
  try
    LWriter.WriteEvent(LEvt);
    Check(False, 'WriteEvent negative retry must raise');
  except
    on E: EHttpError do
      LCaught := (E.Kind = hekArgument) and (Pos('negative', E.Message) > 0);
  end;
  Check(LCaught, 'WriteEvent negative retry raises hekArgument');
end;

procedure TestSSEWriteAfterCloseIsHekProtocol;
var
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LWriter: ISSEEventWriter;
  LCaught: Boolean;
begin
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LWriter := StartSSE(LW);
  LWriter.Close;
  LCaught := False;
  try
    LWriter.WriteEventSimple('message', 'late', '');
    Check(False, 'write after Close must raise');
  except
    on E: EHttpError do
      LCaught := (E.Kind = hekProtocol) and (E.Op = 'sse');
  end;
  Check(LCaught, 'write after Close is hekProtocol Op=sse');
end;

procedure TestSSECloseIsIdempotent;
var
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LWriter: ISSEEventWriter;
begin
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LWriter := StartSSE(LW);
  LWriter.Close;
  Check(not LWriter.IsOpen, 'closed after first Close');
  LWriter.Close;
  Check(not LWriter.IsOpen, 'still closed after second Close');
end;

procedure TestSSEFlushesAfterEvent;
var
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LWriter: ISSEEventWriter;
  LFlushBefore: Int32;
begin
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LWriter := StartSSE(LW);
  LFlushBefore := LWObj.FlushCount;
  LWriter.WriteEventSimple('message', 'hello', '');
  Check(LWObj.FlushCount > LFlushBefore, 'WriteEvent flushes writer');
  LFlushBefore := LWObj.FlushCount;
  LWriter.WriteComment('ping');
  Check(LWObj.FlushCount > LFlushBefore, 'WriteComment flushes writer');
  LWriter.Close;
end;

procedure TestSSEWriteFailureIsHekProtocolOpSse;
var
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LWriter: ISSEEventWriter;
  LCaught: Boolean;
begin
  LWObj := TMockResponseWriter.Create;
  LWObj.SetRaiseOnWrite(True);
  LW := LWObj;
  LWriter := StartSSE(LW);
  LCaught := False;
  try
    LWriter.WriteEventSimple('message', 'x', '');
    Check(False, 'write failure must raise');
  except
    on E: EHttpError do
      LCaught := (E.Kind = hekProtocol) and (E.Op = 'sse');
  end;
  Check(LCaught, 'write failure is hekProtocol Op=sse');
end;

procedure TestSSEErrorsUseOpSse;
var
  LSrc: string;
begin
  LSrc := ReadFileText('../../../src/nextpas.core.http.sse.pas');
  Check(Pos('SSE_OP = ''sse''', LSrc) > 0, 'SSE Op constant is sse');
  Check(Pos('CreateOp(hekArgument, SSE_OP', LSrc) > 0,
    'SSE argument failures use CreateOp');
  Check(Pos('CreateOp(hekProtocol, SSE_OP', LSrc) > 0,
    'SSE protocol failures use CreateOp');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('nextpas.core.http.sse');
  T.Test('SSE: writes events', @TestSSEEventWriterWritesEvents);
  T.Test('SSE: writes event type and id', @TestSSEEventWriterWritesEventType);
  T.Test('SSE: writes comment', @TestSSEEventWriterWritesComment);
  T.Test('SSE: sets headers', @TestSSEEventWriterSetsHeaders);
  T.Test('SSE: multiline data', @TestSSEEventWriterMultilineData);
  T.Test('SSE: handles short writes', @TestSSEEventWriterHandlesShortWrites);
  T.Test('SSE: splits CR data lines', @TestSSEEventWriterSplitsCarriageReturnData);
  T.Test('SSE: rejects field injection', @TestSSEEventWriterRejectsFieldInjection);
  T.Test('SSE: StartSSE(nil) is hekArgument', @TestSSEStartNilWriterRaisesHekArgument);
  T.Test('SSE: negative retry is hekArgument', @TestSSEWriteRetryNegativeRaisesHekArgument);
  T.Test('SSE: write after Close is hekProtocol Op=sse', @TestSSEWriteAfterCloseIsHekProtocol);
  T.Test('SSE: Close is idempotent', @TestSSECloseIsIdempotent);
  T.Test('SSE: flushes after event/comment', @TestSSEFlushesAfterEvent);
  T.Test('SSE: write failure is hekProtocol Op=sse', @TestSSEWriteFailureIsHekProtocolOpSse);
  T.Test('SSE: errors use CreateOp Op=sse', @TestSSEErrorsUseOpSse);
  if not T.Run then Halt(1);
end.
