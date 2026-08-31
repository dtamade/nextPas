unit nextpas.core.http.sse;
{**
 * @desc Server-Sent Events (SSE) write-side helper for HTTP/1.1.
 *       Spec: https://html.spec.whatwg.org/multipage/server-sent-events.html
 *
 *       Production contract (Q1-1): lifecycle, Kind/Op=`sse`, and explicit
 *       non-goals (not a bus, not EventSource client, not WS substitute).
 *
 *       Usage:
 *         var LWriter: ISSEEventWriter;
 *         LWriter := StartSSE(AW);
 *         LWriter.WriteEventSimple('message', 'hello', '');
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
    Event: string;   { event type (optional; empty omits event: line) }
    Data: string;    { event payload (required; may be empty) }
    Id: string;      { last event ID (optional) }
    Retry: Int64;    { reconnection time in ms (0 = don't set) }
  end;

  { Parsed SSE event stream (client side) }
  TSSEventArray = array of TSSEvent;

  { Incremental client-side SSE decoder (K61 feed-style).
    Feed arbitrary text chunks; a frame is emitted as soon as its blank
    line is seen. Finish flushes an EOF trailing frame (same deviation
    as ParseSSE). Line terminators: LF / CRLF / lone CR; a CR at a chunk
    edge stays pending until the next byte decides CRLF vs lone CR.
    ParseSSE delegates here, so both surfaces share one engine. }
  TSSEFeeder = class
  private
    FLine: string;         { 当前未终止行的跨块累积 }
    FHoldCR: Boolean;      { chunk 尾悬挂 CR：待下一字节判定 CRLF / lone CR }
    FEv: TSSEvent;         { 构筑中的帧 }
    FOut: TSSEventArray;   { 自上次取走后完成的帧 }
    FLastLineBlank: Boolean;
    procedure HandleLine(const ALine: string);
    procedure EmitFrame;
    procedure Drain(out AEvents: TSSEventArray);
  public
    constructor Create;
    { Feed one text chunk; AEvents carries frames completed by this chunk. }
    procedure Feed(const AChunk: string; out AEvents: TSSEventArray);
    { Signal EOF: flushes a trailing unterminated frame. Idempotent. }
    procedure Finish(out AEvents: TSSEventArray);
  end;

  { Writer for Server-Sent Events }
  ISSEEventWriter = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000010}']
    { Write a single SSE event (ends with blank line; then Flush). }
    procedure WriteEvent(const AEvent: TSSEvent);
    { Convenience: write event with type, data, and optional id }
    procedure WriteEventSimple(const AType, AData, AId: string);
    { Write a comment line (keeps connection alive); then Flush. }
    procedure WriteComment(const AComment: string);
    { Set the retry interval (ms) for the client; then Flush. }
    procedure WriteRetry(const AMs: Int64);
    { Close the SSE stream (idempotent). Does not close the HTTP connection. }
    procedure Close;
    { True after StartSSE until Close. }
    function IsOpen: Boolean;
  end;

{ Start an SSE response. Sets headers, commits 200, returns event writer. }
function StartSSE(const AW: IHttpResponseWriter): ISSEEventWriter;

{ Create an SSE event record }
function MakeSSEvent(const AType, AData, AId: string): TSSEvent;

{ Client-side parse: text/event-stream document → events.
  Spec-aligned: blank-line framed; multi-line data joined with \n;
  one leading space stripped per data line; event:/id:/retry: fields;
  comment lines (:) ignored. Deviation: frames whose data is empty are
  dropped (matches legacy consumers); missing event: defaults to
  'message' (per spec). }
function ParseSSE(const ABody: string): TSSEventArray;

implementation

uses
  nextpas.core.errors,
  nextpas.core.text.conv;

const
  SSE_OP = 'sse';

type
  TSSEEventWriter = class(TInterfacedObject, ISSEEventWriter)
  private
    FWriter: IHttpResponseWriter;
    FOpen: Boolean;
    procedure EnsureOpen;
    procedure WriteRaw(const ALine: string);
    procedure FlushWriter;
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
    raise EHttpError.CreateOp(hekArgument, SSE_OP,
      'StartSSE: response writer is nil');

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

procedure TSSEEventWriter.EnsureOpen;
begin
  if not FOpen then
    raise EHttpError.CreateOp(hekProtocol, SSE_OP,
      'SSE: stream already closed');
end;

procedure ValidateSSEFieldValue(const AFieldName, AValue: string;
  const ARejectNull: Boolean);
var
  LI: SizeInt;
begin
  for LI := 1 to Length(AValue) do
  begin
    if AValue[LI] in [#10, #13] then
      raise EHttpError.CreateOp(hekArgument, SSE_OP,
        'SSE ' + AFieldName + ' must not contain line breaks');
    if ARejectNull and (AValue[LI] = #0) then
      raise EHttpError.CreateOp(hekArgument, SSE_OP,
        'SSE ' + AFieldName + ' must not contain null bytes');
  end;
end;

function NormalizeSSELineEndings(const AValue: string): string;
var
  LI, LOut: SizeInt;
begin
  SetLength(Result, Length(AValue));
  LI := 1;
  LOut := 0;
  while LI <= Length(AValue) do
  begin
    Inc(LOut);
    if AValue[LI] = #13 then
    begin
      Result[LOut] := #10;
      if (LI < Length(AValue)) and (AValue[LI + 1] = #10) then
        Inc(LI);
    end
    else
      Result[LOut] := AValue[LI];
    Inc(LI);
  end;
  SetLength(Result, LOut);
end;

procedure TSSEEventWriter.WriteRaw(const ALine: string);
var
  LLine: string;
  LTotal, LWritten, LRemaining: SizeUInt;
begin
  EnsureOpen;
  LLine := ALine + #10;
  LTotal := 0;
  try
    while LTotal < SizeUInt(Length(LLine)) do
    begin
      LRemaining := SizeUInt(Length(LLine)) - LTotal;
      LWritten := FWriter.Write(LLine[LTotal + 1], LRemaining);
      if LWritten = 0 then
        raise EHttpError.CreateOp(hekProtocol, SSE_OP,
          'SSE: response writer made zero progress');
      if LWritten > LRemaining then
        raise EHttpError.CreateOp(hekProtocol, SSE_OP,
          'SSE: response writer over-reported progress');
      Inc(LTotal, LWritten);
    end;
  except
    on E: EHttpError do
      raise;
    on E: Exception do
      raise EHttpError.CreateOp(hekProtocol, SSE_OP,
        'SSE write failed: ' + E.Message);
  end;
end;

procedure TSSEEventWriter.FlushWriter;
begin
  EnsureOpen;
  try
    FWriter.Flush;
  except
    on E: EHttpError do
      raise;
    on E: Exception do
      raise EHttpError.CreateOp(hekProtocol, SSE_OP,
        'SSE flush failed: ' + E.Message);
  end;
end;

procedure TSSEEventWriter.WriteEvent(const AEvent: TSSEvent);
var
  LLines: string;
begin
  EnsureOpen;
  if AEvent.Retry < 0 then
    raise EHttpError.CreateOp(hekArgument, SSE_OP,
      'SSE retry must not be negative');
  ValidateSSEFieldValue('event name', AEvent.Event, False);
  ValidateSSEFieldValue('event id', AEvent.Id, True);

  if AEvent.Retry > 0 then
    WriteRaw('retry: ' + IntToStr(AEvent.Retry));

  if AEvent.Event <> '' then
    WriteRaw('event: ' + AEvent.Event);

  if AEvent.Id <> '' then
    WriteRaw('id: ' + AEvent.Id);

  LLines := NormalizeSSELineEndings(AEvent.Data);
  if LLines = '' then
    WriteRaw('data: ')
  else
  begin
    while True do
    begin
      if Pos(#10, LLines) > 0 then
      begin
        WriteRaw('data: ' + Copy(LLines, 1, Pos(#10, LLines) - 1));
        LLines := Copy(LLines, Pos(#10, LLines) + 1, MaxInt);
        if LLines = '' then
        begin
          WriteRaw('data: ');
          Break;
        end;
      end
      else
      begin
        WriteRaw('data: ' + LLines);
        Break;
      end;
    end;
  end;

  WriteRaw('');
  FlushWriter;
end;

procedure TSSEEventWriter.WriteEventSimple(const AType, AData, AId: string);
var
  LEvt: TSSEvent;
begin
  LEvt := MakeSSEvent(AType, AData, AId);
  WriteEvent(LEvt);
end;

procedure TSSEEventWriter.WriteComment(const AComment: string);
var
  LLines: string;
begin
  EnsureOpen;
  LLines := NormalizeSSELineEndings(AComment);
  while True do
  begin
    if Pos(#10, LLines) > 0 then
    begin
      WriteRaw(': ' + Copy(LLines, 1, Pos(#10, LLines) - 1));
      LLines := Copy(LLines, Pos(#10, LLines) + 1, MaxInt);
    end
    else
    begin
      WriteRaw(': ' + LLines);
      Break;
    end;
  end;
  FlushWriter;
end;

procedure TSSEEventWriter.WriteRetry(const AMs: Int64);
begin
  if AMs < 0 then
    raise EHttpError.CreateOp(hekArgument, SSE_OP,
      'SSE retry must not be negative');
  WriteRaw('retry: ' + IntToStr(AMs));
  FlushWriter;
end;

procedure TSSEEventWriter.Close;
begin
  { Idempotent: second Close is a no-op. }
  FOpen := False;
end;

function TSSEEventWriter.IsOpen: Boolean;
begin
  Result := FOpen;
end;

{ ── 客户端解析（client side）─────────────────────────────────────────── }

constructor TSSEFeeder.Create;
begin
  inherited Create;
  FLine := '';
  FHoldCR := False;
  FEv.Event := '';
  FEv.Data := '';
  FEv.Id := '';
  FEv.Retry := 0;
  FLastLineBlank := True;
end;

procedure TSSEFeeder.EmitFrame;
begin
  if FEv.Data <> '' then
  begin
    if FEv.Event = '' then
      FEv.Event := 'message';
    SetLength(FOut, Length(FOut) + 1);
    FOut[High(FOut)] := FEv;
  end;
  FEv.Event := '';
  FEv.Data := '';
  FEv.Id := '';
  FEv.Retry := 0;
end;

procedure TSSEFeeder.HandleLine(const ALine: string);
var
  J: SizeInt;
  Field, Value: string;
  Retry: Int64;
begin
  if ALine = '' then
  begin
    EmitFrame;
    FLastLineBlank := True;
    Exit;
  end;
  FLastLineBlank := False;
  { 字段解析：data:/event:/id:/retry:；: comment 与未知字段忽略（同 ParseSSE） }
  J := 1;
  while (J <= Length(ALine)) and (ALine[J] <> ':') do
    Inc(J);
  Field := Copy(ALine, 1, J - 1);
  if (J <= Length(ALine)) and (ALine[J] = ':') then
  begin
    Value := Copy(ALine, J + 1, Length(ALine) - J);
    { 规范：值去除一个前导空格 }
    if (Length(Value) > 0) and (Value[1] = ' ') then
      Value := Copy(Value, 2, Length(Value) - 1);
  end
  else
    Value := '';
  if Field = 'data' then
  begin
    if FEv.Data <> '' then
      FEv.Data := FEv.Data + #10;
    FEv.Data := FEv.Data + Value;
  end
  else if Field = 'event' then
    FEv.Event := Value
  else if Field = 'id' then
    FEv.Id := Value
  else if Field = 'retry' then
    if TryStrToInt64(Value, Retry) then
      FEv.Retry := Retry;
end;

procedure TSSEFeeder.Drain(out AEvents: TSSEventArray);
begin
  AEvents := FOut;
  FOut := nil;
end;

procedure TSSEFeeder.Feed(const AChunk: string; out AEvents: TSSEventArray);
var
  I, N, R: SizeInt;
begin
  N := Length(AChunk);
  I := 1;
  while I <= N do
  begin
    if FHoldCR then
    begin
      { 悬挂 CR 判定：LF → CRLF 合并终止；否则 CR 单独终止，当前字节重走 }
      FHoldCR := False;
      if AChunk[I] = #10 then
      begin
        Inc(I);
        HandleLine(FLine);
        FLine := '';
        Continue;
      end;
      HandleLine(FLine);
      FLine := '';
    end;
    if (AChunk[I] = #10) or (AChunk[I] = #13) then
    begin
      if AChunk[I] = #10 then
      begin
        Inc(I);
      end
      else if I < N then
      begin
        Inc(I);
        if AChunk[I] = #10 then
          Inc(I);
      end
      else
      begin
        { 悬挂 CR：行未决，不在此处理——留待下一字节判定 CRLF / lone CR }
        FHoldCR := True;
        Inc(I);
        Continue;
      end;
      HandleLine(FLine);
      FLine := '';
    end
    else
    begin
      { 连续普通字符成段拷贝，避免逐字符拼接 }
      R := I;
      while (R <= N) and (AChunk[R] <> #10) and (AChunk[R] <> #13) do
        Inc(R);
      FLine := FLine + Copy(AChunk, I, R - I);
      I := R;
    end;
  end;
  Drain(AEvents);
end;

procedure TSSEFeeder.Finish(out AEvents: TSSEventArray);
begin
  if FHoldCR then
  begin
    FHoldCR := False;
    HandleLine(FLine);
    FLine := '';
  end
  else if FLine <> '' then
  begin
    HandleLine(FLine);
    FLine := '';
  end;
  { EOF 残余帧：最后一行非空字段行且帧有 data → 发射（镜像 ParseSSE） }
  if (not FLastLineBlank) and (FEv.Data <> '') then
    EmitFrame;
  Drain(AEvents);
end;

function ParseSSE(const ABody: string): TSSEventArray;
var
  LFeed: TSSEFeeder;
  LPart: TSSEventArray;
  I: Integer;
begin
  { K61：委托增量引擎——单一解码实现，两个入口构造性等价 }
  Result := nil;
  LFeed := TSSEFeeder.Create;
  try
    LFeed.Feed(ABody, LPart);
    for I := 0 to High(LPart) do
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := LPart[I];
    end;
    LFeed.Finish(LPart);
    for I := 0 to High(LPart) do
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := LPart[I];
    end;
  finally
    LFeed.Free;
  end;
end;
end.
