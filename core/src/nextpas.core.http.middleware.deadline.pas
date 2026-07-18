unit nextpas.core.http.middleware.deadline;
{**
 * @desc Request deadline middleware. Enforces a maximum handler execution time.
 *       If the handler does not complete within the specified timeout, the
 *       middleware writes a 504 Gateway Timeout response.
 *
 *       Note: this middleware cannot interrupt a blocking handler. It works by
 *       wrapping the response writer — if the handler exceeds the deadline,
 *       any subsequent writes are discarded and a 504 is emitted instead.
 *       Handlers that do cooperative checking (e.g. checking a cancellation
 *       token) get the best results.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.http.intf;

{** @desc Create deadline middleware with timeout in milliseconds.
   If the handler takes longer than ATimeoutMs, a 504 Gateway Timeout
   response is written instead of the handler's output.
   ATimeoutMs must be > 0. }
function DeadlineMiddleware(ATimeoutMs: Int64): IHttpMiddleware;

implementation

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.time.base,
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.http.message;

type
  { Response writer wrapper that enforces a deadline.
    Buffers all writes until the handler returns. If the deadline is exceeded,
    discards the buffered output and writes a 504 instead. }
  TDeadlineResponseWriter = class(TInterfacedObject, IHttpResponseWriter)
  private
    FReal: IHttpResponseWriter;
    FStart: TInstant;
    FTimeoutMs: Int64;
    FStatus: THttpStatus;
    FBody: TBytes;
    FBodyLen: SizeUInt;
    FTimedOut: Boolean;
    procedure EnsureCapacity(AExtra: SizeUInt);
  public
    constructor Create(const AReal: IHttpResponseWriter; ATimeoutMs: Int64);
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    { Call after handler returns. Writes buffered output or 504 if timed out. }
    procedure Finalize;
    property TimedOut: Boolean read FTimedOut;
  end;

{ TDeadlineResponseWriter }

constructor TDeadlineResponseWriter.Create(const AReal: IHttpResponseWriter;
  ATimeoutMs: Int64);
begin
  inherited Create;
  FReal := AReal;
  FTimeoutMs := ATimeoutMs;
  FStart := TInstant.Now;
  FStatus := HTTP_STATUS_OK;
  FBody := nil;
  FBodyLen := 0;
  FTimedOut := False;
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
  FStatus := AStatus;
end;

function TDeadlineResponseWriter.GetStatus: THttpStatus;
begin
  Result := FStatus;
end;

function TDeadlineResponseWriter.GetHeaders: IHttpHeaders;
begin
  Result := FReal.GetHeaders;
end;

function TDeadlineResponseWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  if ACount = 0 then
    Exit(0);
  EnsureCapacity(ACount);
  Move(ABuf, FBody[FBodyLen], ACount);
  Inc(FBodyLen, ACount);
  Result := ACount;
end;

procedure TDeadlineResponseWriter.Flush;
begin
  { No-op — we flush in Finalize }
end;

procedure TDeadlineResponseWriter.Finalize;
begin
  if FStart.Elapsed.AsMilliseconds >= FTimeoutMs then
  begin
    { Deadline exceeded — write 504 }
    FTimedOut := True;
    HttpWriteErrorGatewayTimeout(FReal, 'Request timeout');
  end
  else
  begin
    { Within deadline — write buffered output }
    FReal.WriteHeader(FStatus);
    if FBodyLen > 0 then
      FReal.Write(FBody[0], FBodyLen);
  end;
end;

{ DeadlineMiddleware }

function DeadlineMiddleware(ATimeoutMs: Int64): IHttpMiddleware;
begin
  if ATimeoutMs <= 0 then
    raise EHttpError.Create(hekArgument, 'deadline middleware timeout must be > 0');
  Result := MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LBuf: TDeadlineResponseWriter;
      LBufWriter: IHttpResponseWriter;
    begin
      LBuf := TDeadlineResponseWriter.Create(AW, ATimeoutMs);
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

end.
