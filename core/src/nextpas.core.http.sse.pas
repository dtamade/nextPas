unit nextpas.core.http.sse;
{**
 * @desc Server-Sent Events (SSE) support for HTTP/1.1.
 *       Implements the W3C SSE specification:
 *       https://html.spec.whatwg.org/multipage/server-sent-events.html
 *
 *       Usage:
 *         var LWriter: ISSEEventWriter;
 *         LWriter := StartSSE(AW);
 *         LWriter.WriteEvent('message', 'hello', '');
 *         LWriter.WriteEvent('update', '{"x":1}', 'evt-1');
 *         LWriter.Close;
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  { A single SSE event }
  TSSEvent = record
    Event: string;   { event type (optional, default "message") }
    Data: string;    { event payload (required) }
    Id: string;      { last event ID (optional) }
    Retry: Int64;    { reconnection time in ms (0 = don't set) }
  end;

  { Writer for Server-Sent Events }
  ISSEEventWriter = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000010}']
    { Write a single SSE event }
    procedure WriteEvent(const AEvent: TSSEvent);
    { Convenience: write event with type, data, and optional id }
    procedure WriteEventSimple(const AType, AData, AId: string);
    { Write a comment line (keeps connection alive) }
    procedure WriteComment(const AComment: string);
    { Set the retry interval (ms) for the client }
    procedure WriteRetry(const AMs: Int64);
    { Close the SSE stream }
    procedure Close;
    { Check if the stream is still open }
    function IsOpen: Boolean;
  end;

{ Start an SSE response. Sets appropriate headers and returns an event writer.
  The caller should use the writer to send events, then call Close. }
function StartSSE(const AW: IHttpResponseWriter): ISSEEventWriter;

{ Create an SSE event record }
function MakeSSEvent(const AType, AData, AId: string): TSSEvent;

implementation

uses
  nextpas.core.errors,
  nextpas.core.text.conv;

type
  TSSEEventWriter = class(TInterfacedObject, ISSEEventWriter)
  private
    FWriter: IHttpResponseWriter;
    FOpen: Boolean;
    procedure WriteRaw(const ALine: string);
  public
    constructor Create(const AWriter: IHttpResponseWriter);
    procedure WriteEvent(const AEvent: TSSEvent);
    procedure WriteEventSimple(const AType, AData, AId: string);
    procedure WriteComment(const AComment: string);
    procedure WriteRetry(const AMs: Int64);
    procedure Close;
    function IsOpen: Boolean;
  end;

{ Helpers }

function MakeSSEvent(const AType, AData, AId: string): TSSEvent;
begin
  Result.Event := AType;
  Result.Data := AData;
  Result.Id := AId;
  Result.Retry := 0;
end;

function StartSSE(const AW: IHttpResponseWriter): ISSEEventWriter;
begin
  if AW = nil then
    raise EArgumentError.Create('StartSSE: response writer is nil');

  AW.GetHeaders.SetHeader('content-type', 'text/event-stream');
  AW.GetHeaders.SetHeader('cache-control', 'no-cache');
  AW.GetHeaders.SetHeader('connection', 'keep-alive');
  AW.WriteHeader(HTTP_STATUS_OK);

  Result := TSSEEventWriter.Create(AW);
end;

{ TSSEEventWriter }

constructor TSSEEventWriter.Create(const AWriter: IHttpResponseWriter);
begin
  inherited Create;
  FWriter := AWriter;
  FOpen := True;
end;

procedure TSSEEventWriter.WriteRaw(const ALine: string);
var
  LLine: string;
begin
  if not FOpen then
    raise EHttpError.Create('SSE: stream already closed');
  LLine := ALine + #10;
  if Length(LLine) > 0 then
    FWriter.Write(LLine[1], SizeUInt(Length(LLine)));
end;

procedure TSSEEventWriter.WriteEvent(const AEvent: TSSEvent);
var
  LLines: string;
begin
  if not FOpen then
    raise EHttpError.Create('SSE: stream already closed');

  { Retry }
  if AEvent.Retry > 0 then
    WriteRaw('retry: ' + IntToStr(AEvent.Retry));

  { Event type }
  if AEvent.Event <> '' then
    WriteRaw('event: ' + AEvent.Event);

  { Last event ID }
  if AEvent.Id <> '' then
    WriteRaw('id: ' + AEvent.Id);

  { Data — split on newlines per SSE spec }
  LLines := AEvent.Data;
  while LLines <> '' do
  begin
    if Pos(#10, LLines) > 0 then
    begin
      WriteRaw('data: ' + Copy(LLines, 1, Pos(#10, LLines) - 1));
      LLines := Copy(LLines, Pos(#10, LLines) + 1, MaxInt);
    end
    else
    begin
      WriteRaw('data: ' + LLines);
      LLines := '';
    end;
  end;

  { Empty line terminates the event }
  WriteRaw('');
end;

procedure TSSEEventWriter.WriteEventSimple(const AType, AData, AId: string);
var
  LEvt: TSSEvent;
begin
  LEvt := MakeSSEvent(AType, AData, AId);
  WriteEvent(LEvt);
end;

procedure TSSEEventWriter.WriteComment(const AComment: string);
begin
  WriteRaw(': ' + AComment);
end;

procedure TSSEEventWriter.WriteRetry(const AMs: Int64);
begin
  WriteRaw('retry: ' + IntToStr(AMs));
end;

procedure TSSEEventWriter.Close;
begin
  if FOpen then
    FOpen := False;
end;

function TSSEEventWriter.IsOpen: Boolean;
begin
  Result := FOpen;
end;

end.
