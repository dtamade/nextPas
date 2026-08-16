unit nextpas.core.http.middleware.deadline;
{**
 * @desc Post-hoc request deadline middleware (non-preemptive).
 *
 *       Semantics (honest contract):
 *       - Does NOT interrupt a blocking / spinning handler.
 *       - Buffers the entire response until the handler returns, then either
 *         flushes the buffer or writes 504 if elapsed >= timeout.
 *       - Response body buffer is bounded (default HTTP_DEFAULT_BODY_READ_MAX).
 *         Exceeding the buffer yields 413 and discards buffered output.
 *
 *       Production hard limits belong on server ReadTimeout/WriteTimeout and
 *       cancel tokens. Use Deadline only for short handlers with small bodies
 *       where a post-hoc 504 is acceptable.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.base,
  nextpas.core.http.intf;

{** @desc Post-hoc deadline middleware (default buffer = HTTP_DEFAULT_BODY_READ_MAX).
   After the handler returns: if elapsed >= ATimeoutMs → 504; else flush buffer.
   Non-preemptive. ATimeoutMs must be > 0. }
function DeadlineMiddleware(ATimeoutMs: Int64): IHttpMiddleware;

{** @desc Post-hoc deadline with explicit response buffer max (bytes).
   AMaxBufferBytes <= 0 means unlimited buffer (tests/tools only). }
function DeadlineMiddlewareWith(ATimeoutMs: Int64;
  const AMaxBufferBytes: Int64): IHttpMiddleware;

{** @desc Post-hoc deadline with unlimited response buffer (tests/tools only).
   Prefer DeadlineMiddleware / DeadlineMiddlewareWith(positive) in production. }
function DeadlineMiddlewareUnlimitedBuffer(ATimeoutMs: Int64): IHttpMiddleware;

implementation

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.time.base,
  nextpas.core.http.middleware,
  nextpas.core.http.message;

type
  { Response writer wrapper: buffers body until Finalize.
    Timed-out → 504; oversize buffer → 413; else flush status+body.
    Forwards CommitState of the real writer so Recovery can see wire commit. }
  TDeadlineResponseWriter = class(TInterfacedObject, IHttpResponseWriter,
    IHttpResponseWriterCommitState)
  private
    FReal: IHttpResponseWriter;
    FStart: TInstant;
    FTimeoutMs: Int64;
    FMaxBufferBytes: Int64;
    FStatus: THttpStatus;
    FBody: TBytes;
    FBodyLen: SizeUInt;
    FTimedOut: Boolean;
    FOversize: Boolean;
    FLocalCommitted: Boolean;
    procedure EnsureCapacity(AExtra: SizeUInt);
    function WouldExceedMax(AExtra: SizeUInt): Boolean;
  public
    constructor Create(const AReal: IHttpResponseWriter; ATimeoutMs: Int64;
      const AMaxBufferBytes: Int64);
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    function HeadersCommitted: Boolean;
    { Call after handler returns. Writes buffered output, 504, or 413. }
    procedure Finalize;
    property TimedOut: Boolean read FTimedOut;
    property Oversize: Boolean read FOversize;
  end;

{ TDeadlineResponseWriter }

constructor TDeadlineResponseWriter.Create(const AReal: IHttpResponseWriter;
  ATimeoutMs: Int64; const AMaxBufferBytes: Int64);
begin
  inherited Create;
  FReal := AReal;
  FTimeoutMs := ATimeoutMs;
  FMaxBufferBytes := AMaxBufferBytes;
  FStart := TInstant.Now;
  FStatus := HTTP_STATUS_OK;
  FBody := nil;
  FBodyLen := 0;
  FTimedOut := False;
  FOversize := False;
  FLocalCommitted := False;
end;

function TDeadlineResponseWriter.WouldExceedMax(AExtra: SizeUInt): Boolean;
begin
  if FMaxBufferBytes <= 0 then
    Exit(False);
  if AExtra > SizeUInt(High(Int64)) then
    Exit(True);
  Result := Int64(FBodyLen) + Int64(AExtra) > FMaxBufferBytes;
end;

procedure TDeadlineResponseWriter.EnsureCapacity(AExtra: SizeUInt);
var
  LNewCap: SizeUInt;
begin
  if FBodyLen + AExtra > SizeUInt(Length(FBody)) then
  begin
    LNewCap := SizeUInt(Length(FBody)) * 2;
    if LNewCap < 4096 then
      LNewCap := 4096;
    while LNewCap < FBodyLen + AExtra do
      LNewCap := LNewCap * 2;
    SetLength(FBody, LNewCap);
  end;
end;

procedure TDeadlineResponseWriter.WriteHeader(const AStatus: THttpStatus);
begin
  if FOversize then
    Exit;
  FStatus := AStatus;
  FLocalCommitted := True;
end;

function TDeadlineResponseWriter.GetStatus: THttpStatus;
begin
  Result := FStatus;
end;

function TDeadlineResponseWriter.GetHeaders: IHttpHeaders;
begin
  { Headers are not buffered separately — they go to the real writer.
    Body is buffered until Finalize. Callers must treat this as post-hoc
    deadline buffering, not a fully isolated response snapshot. }
  Result := FReal.GetHeaders;
end;

function TDeadlineResponseWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if ACount = 0 then
    Exit(0);
  if FOversize then
    Exit(ACount);
  if WouldExceedMax(ACount) then
  begin
    FOversize := True;
    FBodyLen := 0;
    SetLength(FBody, 0);
    Exit(ACount);
  end;
  EnsureCapacity(ACount);
  Move(ABuf, FBody[FBodyLen], ACount);
  Inc(FBodyLen, ACount);
  FLocalCommitted := True;
  Result := ACount;
end;

procedure TDeadlineResponseWriter.Flush;
begin
  { No-op — we flush in Finalize }
end;

function TDeadlineResponseWriter.HeadersCommitted: Boolean;
var
  LRealCommit: IHttpResponseWriterCommitState;
begin
  LRealCommit := nil;
  if Supports(FReal, IHttpResponseWriterCommitState, LRealCommit) and
     LRealCommit.HeadersCommitted then
    Exit(True);
  Result := FLocalCommitted;
end;

procedure TDeadlineResponseWriter.Finalize;
begin
  if FOversize then
  begin
    HttpWriteErrorPayloadTooLarge(FReal,
      'Deadline response buffer exceeded');
    Exit;
  end;
  if FStart.Elapsed.AsMilliseconds >= FTimeoutMs then
  begin
    FTimedOut := True;
    HttpWriteErrorGatewayTimeout(FReal, 'Request timeout');
  end
  else
  begin
    FReal.WriteHeader(FStatus);
    if FBodyLen > 0 then
      FReal.Write(FBody[0], FBodyLen);
  end;
end;

{ DeadlineMiddleware }

function DeadlineMiddleware(ATimeoutMs: Int64): IHttpMiddleware;
begin
  Result := DeadlineMiddlewareWith(ATimeoutMs, HTTP_DEFAULT_BODY_READ_MAX);
end;

function DeadlineMiddlewareWith(ATimeoutMs: Int64;
  const AMaxBufferBytes: Int64): IHttpMiddleware;
begin
  if ATimeoutMs <= 0 then
    raise EHttpError.Create(hekArgument,
      'deadline middleware timeout must be > 0');
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LBuf: TDeadlineResponseWriter;
      LBufWriter: IHttpResponseWriter;
    begin
      LBuf := TDeadlineResponseWriter.Create(AW, ATimeoutMs, AMaxBufferBytes);
      LBufWriter := LBuf;
      try
        ANext.ServeHTTP(AReq, LBufWriter);
        LBuf.Finalize;
      finally
        LBufWriter := nil;
      end;
    end);
  end);
end;

function DeadlineMiddlewareUnlimitedBuffer(ATimeoutMs: Int64): IHttpMiddleware;
begin
  Result := DeadlineMiddlewareWith(ATimeoutMs, 0);
end;

end.