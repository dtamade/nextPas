program test_http_middlewares;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.log,
  nextpas.core.test,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.middleware,
  nextpas.core.http.message,
  nextpas.core.io.memory,
  nextpas.core.http.middleware.recovery,
  nextpas.core.http.middleware.logger,
  nextpas.core.http.middleware.cors,
  nextpas.core.http.middleware.responsetime,
  nextpas.core.http.middleware.bodylimit,
  nextpas.core.http.middleware.contenttype,
  nextpas.core.http.middleware.requestid,
  nextpas.core.http.middleware.cachecontrol,
  nextpas.core.http.middleware.ratelimit,
  nextpas.core.http.middleware.healthcheck,
  nextpas.core.http.middleware.metrics,
  nextpas.core.http.middleware.methodguard,
  nextpas.core.http.middleware.bodycache,
  nextpas.core.http.middleware.serverheader,
  nextpas.core.http.middleware.context,
  nextpas.core.http.middleware.compression,
  nextpas.core.http.middleware.decompress,
  nextpas.core.http.middleware.deadline,
  nextpas.core.compress,
  nextpas.core.text.conv,
  nextpas.core.time.base,
  nextpas.core.time.sleep,
  nextpas.core.fs;

var
  GTestSentinel: TObject;
  GTrackedWriterDestroyCount: Int32;

type
  TMockResponseWriter = class(TInterfacedObject, IHttpResponseWriter,
    IHttpResponseBodyBytes, IHttpResponseWriterCommitState)
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
    function HeadersCommitted: Boolean;
    property Status: THttpStatus read FStatus;
    property Body: string read FBody;
    property BodyBytes: TBytes read FBodyBytes;
    property WriteHeaderCount: Int32 read FWriteHeaderCount;
    property FlushCount: Int32 read FFlushCount;
  end;

  TTrackingResponseWriter = class(TMockResponseWriter)
  public
    destructor Destroy; override;
  end;

  TMockRequest = class(TInterfacedObject, IHttpRequest, IHttpRequestWithContext)
  private
    FMethod: THttpMethod;
    FUrl: TUrl;
    FHeaders: IHttpHeaders;
    FContentLength: Int64;
    FBodyReader: IReader;
    FContext: IHttpContext;
    FRemote: string;
  public
    constructor Create(const AMethod: THttpMethod; const APath: string);
    procedure SetContentLength(const AValue: Int64);
    procedure SetBodyReader(const ABody: IReader);
    procedure SetBodyBytes(const AData: TBytes);
    procedure SetHeader(const AName, AValue: string);
    procedure SetRemoteAddr(const AAddr: string);
    function GetMethod: THttpMethod;
    function GetUrl: TUrl;
    function GetPath: string;
    function GetRawQuery: string;
    function GetVersion: THttpVersion;
    function GetHeaders: IHttpHeaders;
    function GetBody: IReader;
    function GetContentLength: Int64;
    function GetTrailers: IHttpHeaders;
    function GetRemoteAddr: string;
    function GetRemoteIp: string;
    function PathParam(const AName: string): string;
    function QueryParam(const AName: string): string;
    function GetContext: IHttpContext;
    procedure SetContext(const ACtx: IHttpContext);
  end;

  TLogCaptureHandler = class(TInterfacedObject, ILogHandler)
  private
    FLast: TLogRecord;
    FCount: Int32;
  public
    function Enabled(const ALevel: TLogLevel): Boolean;
    procedure Handle(const ARecord: TLogRecord);
    procedure Flush;
    function WithAttrs(const AAttrs: array of TAttr): ILogHandler;
    function WithGroup(const AName: string): ILogHandler;
    property Last: TLogRecord read FLast;
    property Count: Int32 read FCount;
  end;

{ TMockResponseWriter }

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

destructor TTrackingResponseWriter.Destroy;
begin
  Inc(GTrackedWriterDestroyCount);
  inherited Destroy;
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
  { Also capture raw bytes for binary data verification }
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

function TMockResponseWriter.HeadersCommitted: Boolean;
begin
  Result := FWriteHeaderCount > 0;
end;

function MakeRateLimitOpts(AMax, AWindow: Int32): TRateLimitOptions;
begin
  Result := Default(TRateLimitOptions);
  Result.MaxRequests := AMax;
  Result.WindowSeconds := AWindow;
  Result.MaxKeys := 10000;
end;

{ TMockRequest }

constructor TMockRequest.Create(const AMethod: THttpMethod; const APath: string);
begin
  inherited Create;
  FMethod := AMethod;
  FUrl := Default(TUrl);
  FUrl.Path := APath;
  FHeaders := NewHttpHeaders;
  FContentLength := 0;
  FRemote := '127.0.0.1';
end;

procedure TMockRequest.SetRemoteAddr(const AAddr: string);
begin
  FRemote := AAddr;
end;

procedure TMockRequest.SetContentLength(const AValue: Int64);
begin
  FContentLength := AValue;
end;

procedure TMockRequest.SetBodyReader(const ABody: IReader);
begin
  FBodyReader := ABody;
end;

procedure TMockRequest.SetBodyBytes(const AData: TBytes);
begin
  FBodyReader := CreateBytesStreamFrom(AData) as IReader;
  FContentLength := Length(AData);
end;

procedure TMockRequest.SetHeader(const AName, AValue: string);
begin
  FHeaders.SetHeader(AName, AValue);
end;

function TMockRequest.GetMethod: THttpMethod;
begin Result := FMethod; end;

function TMockRequest.GetUrl: TUrl;
begin Result := FUrl; end;

function TMockRequest.GetPath: string;
begin Result := FUrl.Path; end;

function TMockRequest.GetRawQuery: string;
begin Result := FUrl.RawQuery; end;

function TMockRequest.GetVersion: THttpVersion;
begin Result := hvHttp11; end;

function TMockRequest.GetHeaders: IHttpHeaders;
begin Result := FHeaders; end;

function TMockRequest.GetBody: IReader;
begin Result := FBodyReader; end;

function TMockRequest.GetContentLength: Int64;
begin Result := FContentLength; end;

function TMockRequest.GetTrailers: IHttpHeaders;
begin Result := nil; end;

function TMockRequest.GetRemoteIp: string;
var
  LLast, I: SizeInt;
begin
  Result := FRemote;
  if Result = '' then
    Exit;
  if Result[1] = '[' then
  begin
    I := Pos(']', Result);
    if I > 2 then
      Result := Copy(Result, 2, I - 2);
    Exit;
  end;
  LLast := 0;
  for I := 1 to Length(Result) do
    if Result[I] = ':' then
      LLast := I;
  if LLast > 1 then
    Result := Copy(Result, 1, LLast - 1);
end;

function TMockRequest.GetRemoteAddr: string;
begin Result := FRemote; end;

function TMockRequest.PathParam(const AName: string): string;
begin Result := ''; end;

function TMockRequest.QueryParam(const AName: string): string;
begin Result := ''; end;

function TMockRequest.GetContext: IHttpContext;
begin Result := FContext; end;

procedure TMockRequest.SetContext(const ACtx: IHttpContext);
begin FContext := ACtx; end;

{ TLogCaptureHandler }

function TLogCaptureHandler.Enabled(const ALevel: TLogLevel): Boolean;
begin
  Result := True;
end;

procedure TLogCaptureHandler.Handle(const ARecord: TLogRecord);
begin
  FLast := ARecord;
  Inc(FCount);
end;

procedure TLogCaptureHandler.Flush;
begin
end;

function TLogCaptureHandler.WithAttrs(const AAttrs: array of TAttr): ILogHandler;
begin
  Result := Self;
end;

function TLogCaptureHandler.WithGroup(const AName: string): ILogHandler;
begin
  Result := Self;
end;

{ === Recovery Tests === }

procedure TestRecoveryHandlerRaises;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      raise Exception.Create('db password=secret');
    end),
    [RecoveryMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/crash');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(500), Int64(LWObj.Status), 'recovery returns 500');
  Check(Pos('"internal_error"', LWObj.Body) > 0, 'recovery returns JSON error code');
  Check(Pos('Internal Server Error', LWObj.Body) > 0, 'recovery returns generic message');
  Check(Pos('password', LWObj.Body) = 0, 'body does not expose field names');
  Check(Pos('secret', LWObj.Body) = 0, 'body does not expose secret values');
end;

procedure TestRecoveryHandlerSucceeds;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
  LBody: string;
begin
  LBody := 'ok';
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(LBody[1], Length(LBody));
    end),
    [RecoveryMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/ok');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'success passes through');
  CheckEqual('ok', LWObj.Body, 'body passes through');
end;

procedure TestRecoveryHidesExceptionDetails;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      raise Exception.Create('detailed error info');
    end),
    [RecoveryMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/err');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(500), Int64(LWObj.Status), 'recovery returns 500 for detailed error');
  Check(Pos('"internal_error"', LWObj.Body) > 0, 'recovery returns JSON error code');
  Check(Pos('detailed error info', LWObj.Body) = 0, 'body does not expose exception message');
end;

procedure TestRecoveryWithCallbackReceivesException;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
  LCaughtMsg: string;
  LCallbackCalled: Boolean;
begin
  LCaughtMsg := '';
  LCallbackCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      raise Exception.Create('boom');
    end),
    [RecoveryMiddlewareWith(procedure(E: Exception)
    begin
      LCaughtMsg := E.Message;
      LCallbackCalled := True;
    end)]
  );
  LReq := TMockRequest.Create(hmGet, '/err');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  Check(LCallbackCalled, 'callback was called');
  CheckEqual('boom', LCaughtMsg, 'callback received exception message');
  CheckEqual(Int64(500), Int64(LWObj.Status), 'still returns 500');
  Check(Pos('"internal_error"', LWObj.Body) > 0, 'body is JSON error');
end;

procedure TestRecoveryWithNilCallbackBehavesLikeSilent;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      raise Exception.Create('should be swallowed');
    end),
    [RecoveryMiddlewareWith(nil)]
  );
  LReq := TMockRequest.Create(hmGet, '/err');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(500), Int64(LWObj.Status), 'nil callback still returns 500');
  Check(Pos('"internal_error"', LWObj.Body) > 0, 'nil callback still returns JSON error');
end;

procedure TestRecoveryWithSuccessPassesThrough;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
  LCallbackCalled: Boolean;
begin
  LCallbackCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RecoveryMiddlewareWith(procedure(E: Exception)
    begin
      LCallbackCalled := True;
    end)]
  );
  LReq := TMockRequest.Create(hmGet, '/ok');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  Check(not LCallbackCalled, 'callback not called on success');
  CheckEqual(Int64(200), Int64(LWObj.Status), 'success passes through');
end;

{ === Logger Tests === }

procedure TestLoggerCallsNext;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
  LBody: string;
begin
  LBody := 'logged';
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(LBody[1], Length(LBody));
    end),
    [LoggerMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/log');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual('logged', LWObj.Body, 'logger passes response body');
end;

procedure TestLoggerPreservesStatus;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_CREATED);
    end),
    [LoggerMiddleware]
  );
  LReq := TMockRequest.Create(hmPost, '/create');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(201), Int64(LWObj.Status), 'logger preserves status');
end;

procedure TestLoggerNoCrash;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_NOT_FOUND);
    end),
    [LoggerMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/missing');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(404), Int64(LWObj.Status), 'logger handles 404 without crash');
end;

procedure TestLoggerExtras;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LCap: TLogCaptureHandler;
  LLog: TLogger;
  LProvider: TLogExtrasProvider;
  LI: Int32;
  LFoundRequestId: Boolean;
  LFoundStatusSeen: Boolean;
begin
  LCap := TLogCaptureHandler.Create;
  LLog := TLogger.New(LCap);
  LProvider := function(const AReq: IHttpRequest; const AW: IHttpResponseWriter): TLogFieldArray
  var
    LFields: TLogFieldArray;
  begin
    SetLength(LFields, 2);
    LFields[0].Key := 'request_id';
    LFields[0].Value := AReq.GetHeaders.Get('x-request-id');
    LFields[1].Key := 'status_seen';
    LFields[1].Value := IntToStr(Int64(AW.GetStatus));
    Result := LFields;
  end;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_CREATED);
    end),
    [LoggerMiddlewareWithExtrasAndLogger(LProvider, LLog)]
  );
  LReq := TMockRequest.Create(hmPost, '/with-extras');
  LReq.SetHeader('x-request-id', 'req-abc');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(201), Int64(LWObj.Status), 'extras logger preserves status');
  CheckEqual(Int64(1), Int64(LCap.Count), 'one log record produced');
  CheckEqual('http_request', LCap.Last.Message, 'record message is http_request');
  Check(LCap.Last.AttrCount >= 6, 'record carries base fields plus extras');
  LFoundRequestId := False;
  LFoundStatusSeen := False;
  for LI := 0 to LCap.Last.AttrCount - 1 do
  begin
    if LCap.Last.Attrs[LI].Key = 'request_id' then
    begin
      CheckEqual('req-abc', LCap.Last.Attrs[LI].SVal, 'request_id extra from request header');
      LFoundRequestId := True;
    end
    else if LCap.Last.Attrs[LI].Key = 'status_seen' then
    begin
      CheckEqual('201', LCap.Last.Attrs[LI].SVal, 'status_seen extra from response status');
      LFoundStatusSeen := True;
    end;
  end;
  Check(LFoundRequestId, 'extras provider could read request header');
  Check(LFoundStatusSeen, 'extras provider could read response status');
end;

procedure TestLoggerExtrasDefaultLogger;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
  LProvider: TLogExtrasProvider;
begin
  LProvider := function(const AReq: IHttpRequest; const AW: IHttpResponseWriter): TLogFieldArray
  begin
    Result := nil;
  end;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [LoggerMiddlewareWithExtras(LProvider)]
  );
  LReq := TMockRequest.Create(hmGet, '/default-logger');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'extras logger with default logger passes through');
end;

{ === CORS Tests === }

procedure TestCorsPreflight;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [CorsMiddleware(TCorsOptions.Default)]
  );
  LReq := TMockRequest.Create(hmOptions, '/api');
  LReq.GetHeaders.SetHeader('Origin', 'http://example.com');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(204), Int64(LWObj.Status), 'preflight returns 204');
  CheckEqual('*', LWObj.GetHeaders.Get('Access-Control-Allow-Origin'), 'ACAO header');
end;

procedure TestCorsNormalRequest;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LBody: string;
begin
  LBody := 'data';
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(LBody[1], Length(LBody));
    end),
    [CorsMiddleware(TCorsOptions.Default)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReq.GetHeaders.SetHeader('Origin', 'http://example.com');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'normal request passes');
  CheckEqual('*', LWObj.GetHeaders.Get('Access-Control-Allow-Origin'), 'ACAO on normal');
  CheckEqual('data', LWObj.Body, 'body passes through');
end;

procedure TestCorsNoOriginHeader;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [CorsMiddleware(TCorsOptions.Default)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'no origin passes through');
  CheckEqual('', LWObj.GetHeaders.Get('Access-Control-Allow-Origin'), 'no CORS headers');
end;

procedure TestCorsCredentials;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LOpts: TCorsOptions;
begin
  LOpts := TCorsOptions.Default;
  LOpts.AllowOrigins := 'http://example.com';
  LOpts.AllowCredentials := True;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [CorsMiddleware(LOpts)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReq.GetHeaders.SetHeader('Origin', 'http://example.com');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('true', LWObj.GetHeaders.Get('Access-Control-Allow-Credentials'), 'credentials header');
end;

procedure TestCorsSpecificOriginAllowed;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LOpts: TCorsOptions;
begin
  LOpts := TCorsOptions.Default;
  LOpts.AllowOrigins := 'https://trusted.com, https://other.com';
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [CorsMiddleware(LOpts)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReq.GetHeaders.SetHeader('Origin', 'https://trusted.com');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('https://trusted.com', LWObj.GetHeaders.Get('Access-Control-Allow-Origin'),
    'specific origin echoed');
  CheckEqual('Origin, Access-Control-Request-Method, Access-Control-Request-Headers',
    LWObj.GetHeaders.Get('Vary'), 'specific origin response varies by CORS request fields');
end;

procedure TestCorsSpecificOriginDenied;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LOpts: TCorsOptions;
begin
  LOpts := TCorsOptions.Default;
  LOpts.AllowOrigins := 'https://trusted.com';
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [CorsMiddleware(LOpts)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReq.GetHeaders.SetHeader('Origin', 'https://evil.com');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('', LWObj.GetHeaders.Get('Access-Control-Allow-Origin'),
    'disallowed origin gets no ACAO');
end;

procedure TestCorsCredentialsWildcardEchoesOrigin;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LOpts: TCorsOptions;
begin
  LOpts := TCorsOptions.Default;
  LOpts.AllowOrigins := '*';
  LOpts.AllowCredentials := True;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [CorsMiddleware(LOpts)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReq.GetHeaders.SetHeader('Origin', 'https://credentialed.example');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('https://credentialed.example',
    LWObj.GetHeaders.Get('Access-Control-Allow-Origin'),
    'credentialed wildcard echoes the concrete Origin');
  CheckEqual('true', LWObj.GetHeaders.Get('Access-Control-Allow-Credentials'),
    'credentialed wildcard emits credentials header');
  CheckEqual('Origin, Access-Control-Request-Method, Access-Control-Request-Headers',
    LWObj.GetHeaders.Get('Vary'),
    'credentialed wildcard response varies by CORS request fields');
end;

procedure TestCorsMaxAge;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LOpts: TCorsOptions;
begin
  LOpts := TCorsOptions.Default;
  LOpts.MaxAge := 3600;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [CorsMiddleware(LOpts)]
  );
  LReq := TMockRequest.Create(hmOptions, '/api');
  LReq.GetHeaders.SetHeader('Origin', 'http://example.com');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('3600', LWObj.GetHeaders.Get('Access-Control-Max-Age'), 'MaxAge header');
end;

procedure TestCorsCustomMethodsHeaders;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LOpts: TCorsOptions;
begin
  LOpts := TCorsOptions.Default;
  LOpts.AllowMethods := 'GET, POST, PATCH';
  LOpts.AllowHeaders := 'Content-Type, X-Custom';
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [CorsMiddleware(LOpts)]
  );
  LReq := TMockRequest.Create(hmOptions, '/api');
  LReq.GetHeaders.SetHeader('Origin', 'http://example.com');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('GET, POST, PATCH', LWObj.GetHeaders.Get('Access-Control-Allow-Methods'),
    'custom AllowMethods');
  CheckEqual('Content-Type, X-Custom', LWObj.GetHeaders.Get('Access-Control-Allow-Headers'),
    'custom AllowHeaders');
end;

procedure TestCorsWildcardEchoesRequestHeaders;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LOpts: TCorsOptions;
begin
  LOpts := TCorsOptions.Default;
  LOpts.AllowHeaders := '*';
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [CorsMiddleware(LOpts)]
  );
  LReq := TMockRequest.Create(hmOptions, '/api');
  LReq.GetHeaders.SetHeader('Origin', 'http://example.com');
  LReq.GetHeaders.SetHeader('Access-Control-Request-Headers', 'X-Custom, Authorization');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('X-Custom, Authorization', LWObj.GetHeaders.Get('Access-Control-Allow-Headers'),
    'wildcard echoes request headers');
end;

{ === Timeout Tests === }

procedure TestTimeoutFastHandler;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [ResponseTimeMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/fast');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'fast handler OK');
  Check(LWObj.GetHeaders.Has('X-Response-Time'), 'has X-Response-Time header');
end;

procedure TestTimeoutSlowHandler;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
  LVal: string;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      TSleep.ForDuration(TDuration.FromMilliseconds(50));
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [ResponseTimeMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/slow');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'slow handler still completes');
  LVal := LWObj.GetHeaders.Get('X-Response-Time');
  Check(LVal <> '', 'X-Response-Time present for slow handler');
end;

procedure TestTimeoutResponseTimeValue;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
  LVal: string;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [ResponseTimeMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/check');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  LVal := LWObj.GetHeaders.Get('X-Response-Time');
  Check(Pos('ms', LVal) > 0, 'X-Response-Time contains ms suffix');
end;

{ === BodyLimit Tests === }

procedure TestBodyLimitUnderLimitPasses;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [BodyLimitMiddleware(1024)]
  );
  LReq := TMockRequest.Create(hmPost, '/upload');
  LReq.SetContentLength(512);
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'under limit passes through');
end;

procedure TestBodyLimitOverLimitRejects;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [BodyLimitMiddleware(1024)]
  );
  LReq := TMockRequest.Create(hmPost, '/upload');
  LReq.SetContentLength(2048);
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(413), Int64(LWObj.Status), 'over limit returns 413');
  Check(Pos('too large', LWObj.Body) > 0, 'body contains error message');
end;

procedure TestBodyLimitExactLimitPasses;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [BodyLimitMiddleware(1024)]
  );
  LReq := TMockRequest.Create(hmPost, '/upload');
  LReq.SetContentLength(1024);
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'exact limit passes through');
end;

procedure TestBodyLimitNoContentLengthPasses;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [BodyLimitMiddleware(1024)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'no content-length passes through');
end;

procedure TestBodyLimitZeroContentLengthPasses;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [BodyLimitMiddleware(1024)]
  );
  LReq := TMockRequest.Create(hmPost, '/api');
  LReq.SetContentLength(0);
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'zero content-length passes through');
end;

procedure TestBodyLimitRejectsHandlerNotCalled;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [BodyLimitMiddleware(100)]
  );
  LReq := TMockRequest.Create(hmPost, '/upload');
  LReq.SetContentLength(999);
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(413), Int64(LWObj.Status), 'reject returns 413');
  Check(not LHandlerCalled, 'handler not called when rejected');
end;

{ ContentTypeMiddleware tests }

procedure TestContentTypeAcceptedPasses;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [ContentTypeMiddleware(['application/json'])]
  );
  LReq := TMockRequest.Create(hmPost, '/api');
  LReq.GetHeaders.SetHeader('content-type', 'application/json');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LHandlerCalled, 'handler called for accepted type');
  CheckEqual(Int64(200), Int64(LWObj.Status), 'status 200');
end;

procedure TestContentTypeRejectedReturns415;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [ContentTypeMiddleware(['application/json'])]
  );
  LReq := TMockRequest.Create(hmPost, '/api');
  LReq.GetHeaders.SetHeader('content-type', 'text/plain');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(not LHandlerCalled, 'handler not called for rejected type');
  CheckEqual(Int64(415), Int64(LWObj.Status), 'status 415');
end;

procedure TestContentTypeIgnoresParams;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [ContentTypeMiddleware(['application/json'])]
  );
  LReq := TMockRequest.Create(hmPost, '/api');
  LReq.GetHeaders.SetHeader('content-type', 'application/json; charset=utf-8');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LHandlerCalled, 'handler called when params match');
end;

procedure TestContentTypeGetSkipsCheck;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [ContentTypeMiddleware(['application/json'])]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReq.GetHeaders.SetHeader('content-type', 'text/plain');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LHandlerCalled, 'handler called for GET even with wrong type');
  CheckEqual(Int64(200), Int64(LWObj.Status), 'status 200');
end;

procedure TestContentTypeEmptyAllowsAny;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [ContentTypeMiddleware([])]
  );
  LReq := TMockRequest.Create(hmPost, '/api');
  LReq.GetHeaders.SetHeader('content-type', 'anything/at-all');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LHandlerCalled, 'handler called when accepted list empty');
end;

procedure TestContentTypeMissingPasses;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [ContentTypeMiddleware(['application/json'])]
  );
  LReq := TMockRequest.Create(hmPost, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LHandlerCalled, 'handler called when no content-type');
end;

{ RequestIdMiddleware tests }

procedure TestRequestIdGeneratesId;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LRequestId: string;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RequestIdMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  LRequestId := LWObj.GetHeaders.Get('x-request-id');
  Check(LRequestId <> '', 'request id is set');
  Check(Length(LRequestId) = 36, 'request id is UUID format');
end;

procedure TestRequestIdPreservesExisting;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RequestIdMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReq.GetHeaders.SetHeader('x-request-id', 'my-trace-123');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('my-trace-123', LWObj.GetHeaders.Get('x-request-id'), 'preserves existing id');
end;

procedure TestRequestIdCustomHeader;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LRequestId: string;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RequestIdMiddlewareWith('x-correlation-id')]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  LRequestId := LWObj.GetHeaders.Get('x-correlation-id');
  Check(LRequestId <> '', 'custom header is set');
  CheckEqual('', LWObj.GetHeaders.Get('x-request-id'), 'default header not set');
end;

procedure TestRequestIdUniquePerRequest;
var
  LHandler: IHttpHandler;
  LW1, LW2: TMockResponseWriter;
  LWIntf1, LWIntf2: IHttpResponseWriter;
  LReq1, LReq2: TMockRequest;
  LReqIntf1, LReqIntf2: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RequestIdMiddleware]
  );
  LReq1 := TMockRequest.Create(hmGet, '/a');
  LReqIntf1 := LReq1;
  LW1 := TMockResponseWriter.Create;
  LWIntf1 := LW1;
  LHandler.ServeHTTP(LReqIntf1, LWIntf1);
  LReq2 := TMockRequest.Create(hmGet, '/b');
  LReqIntf2 := LReq2;
  LW2 := TMockResponseWriter.Create;
  LWIntf2 := LW2;
  LHandler.ServeHTTP(LReqIntf2, LWIntf2);
  Check(LW1.GetHeaders.Get('x-request-id') <> LW2.GetHeaders.Get('x-request-id'),
    'different requests get different ids');
end;

procedure TestRequestIdWithGeneratorUsesCustom;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LCallCount: Int32;
begin
  LCallCount := 0;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RequestIdMiddlewareWithGenerator('x-request-id', function: string
    begin
      Inc(LCallCount);
      Result := 'custom-id-' + IntToStr(LCallCount);
    end)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('custom-id-1', LWObj.GetHeaders.Get('x-request-id'), 'uses custom generator');
  CheckEqual(1, LCallCount, 'generator called once');
end;

procedure TestRequestIdWithGeneratorPreservesExisting;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LGeneratorCalled: Boolean;
begin
  LGeneratorCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RequestIdMiddlewareWithGenerator('x-request-id', function: string
    begin
      LGeneratorCalled := True;
      Result := 'should-not-be-used';
    end)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReq.GetHeaders.SetHeader('x-request-id', 'existing-id');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('existing-id', LWObj.GetHeaders.Get('x-request-id'), 'preserves existing');
  Check(not LGeneratorCalled, 'generator not called when existing id present');
end;

procedure TestRequestIdWithGeneratorCustomHeader;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RequestIdMiddlewareWithGenerator('x-trace-id', function: string
    begin
      Result := 'trace-123';
    end)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('trace-123', LWObj.GetHeaders.Get('x-trace-id'), 'custom header with custom generator');
  CheckEqual('', LWObj.GetHeaders.Get('x-request-id'), 'default header not set');
end;

procedure TestRequestIdWithGeneratorUniquePerRequest;
var
  LHandler: IHttpHandler;
  LW1, LW2: TMockResponseWriter;
  LWIntf1, LWIntf2: IHttpResponseWriter;
  LReq1, LReq2: TMockRequest;
  LReqIntf1, LReqIntf2: IHttpRequest;
  LCounter: Int32;
begin
  LCounter := 0;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RequestIdMiddlewareWithGenerator('x-request-id', function: string
    begin
      Inc(LCounter);
      Result := 'req-' + IntToStr(LCounter);
    end)]
  );
  LReq1 := TMockRequest.Create(hmGet, '/a');
  LReqIntf1 := LReq1;
  LW1 := TMockResponseWriter.Create;
  LWIntf1 := LW1;
  LHandler.ServeHTTP(LReqIntf1, LWIntf1);
  LReq2 := TMockRequest.Create(hmGet, '/b');
  LReqIntf2 := LReq2;
  LW2 := TMockResponseWriter.Create;
  LWIntf2 := LW2;
  LHandler.ServeHTTP(LReqIntf2, LWIntf2);
  CheckEqual('req-1', LW1.GetHeaders.Get('x-request-id'), 'first request gets req-1');
  CheckEqual('req-2', LW2.GetHeaders.Get('x-request-id'), 'second request gets req-2');
end;

procedure TestRequestIdStashesIntoContext;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LSeenId: string;
begin
  LSeenId := '';
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LSeenId := HttpContextGetString(HttpContextOf(AReq), CONTEXT_REQUEST_ID);
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [ContextMiddleware, RequestIdMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/ctx');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LWObj.GetHeaders.Get('x-request-id') <> '', 'response header id present');
  CheckEqual(LWObj.GetHeaders.Get('x-request-id'), LSeenId,
    'generated id stashed into context bag');

  { 入站已有 id：袋中必须是透传值而非新值。 }
  LSeenId := '';
  LReq := TMockRequest.Create(hmGet, '/ctx');
  LReq.GetHeaders.SetHeader('x-request-id', 'proxy-req-9');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('proxy-req-9', LSeenId, 'preserved id stashed into context bag');
end;

{ 端到端组合：context + requestid + logger(extras 读袋) —— http_request
  日志事件必须携带与响应头一致的 request_id 字段。 }
procedure TestRequestIdFeedsLoggerExtras;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LCap: TLogCaptureHandler;
  LLog: TLogger;
  LProvider: TLogExtrasProvider;
  LI: Int32;
  LFound: Boolean;
begin
  LCap := TLogCaptureHandler.Create;
  LLog := TLogger.New(LCap);
  LProvider := function(const AReq: IHttpRequest; const AW: IHttpResponseWriter): TLogFieldArray
  var
    LFields: TLogFieldArray;
  begin
    SetLength(LFields, 1);
    LFields[0].Key := 'request_id';
    LFields[0].Value := HttpContextGetString(HttpContextOf(AReq), CONTEXT_REQUEST_ID);
    Result := LFields;
  end;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_CREATED);
    end),
    [ContextMiddleware, RequestIdMiddleware,
     LoggerMiddlewareWithExtrasAndLogger(LProvider, LLog)]
  );
  LReq := TMockRequest.Create(hmPost, '/logged');
  LReq.GetHeaders.SetHeader('x-request-id', 'log-corr-1');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(1), Int64(LCap.Count), 'one log record produced');
  LFound := False;
  for LI := 0 to LCap.Last.AttrCount - 1 do
    if LCap.Last.Attrs[LI].Key = 'request_id' then
    begin
      CheckEqual('log-corr-1', LCap.Last.Attrs[LI].SVal,
        'http_request log carries context request_id');
      LFound := True;
    end;
  Check(LFound, 'request_id attribute present in log record');
end;

{ CacheControlMiddleware tests }

procedure TestCacheControlSetsHeader;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [CacheControlMiddleware('public, max-age=3600')]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('public, max-age=3600', LWObj.GetHeaders.Get('cache-control'), 'cache-control header');
end;

procedure TestNoCacheMiddlewareSetsHeader;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [NoCacheMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('no-cache, no-store, must-revalidate', LWObj.GetHeaders.Get('cache-control'), 'no-cache header');
end;

procedure TestMaxAgeMiddlewareSetsHeader;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [MaxAgeMiddleware(86400)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('public, max-age=86400', LWObj.GetHeaders.Get('cache-control'), 'max-age header');
end;

procedure TestMaxAgeNegativeRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    MaxAgeMiddleware(-1);
  except
    on E: EHttpError do
      LRaised := E.Kind = hekArgument;
  end;
  CheckTrue(LRaised, 'raises hekArgument on negative max-age');
end;

procedure TestCacheControlHandlerStillCalled;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [CacheControlMiddleware('no-cache')]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LHandlerCalled, 'handler still called');
  CheckEqual('no-cache', LWObj.GetHeaders.Get('cache-control'), 'header set');
end;

{ RateLimit tests }

procedure TestRateLimitAllowsUnderLimit;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RateLimitMiddlewareWith(MakeRateLimitOpts(10, 60))]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LHandlerCalled, 'handler called under limit');
  CheckEqual(Int64(200), Int64(LWObj.Status), 'status 200');
end;

{ The fallback limit key is the peer IP without its port: two connections
  from the same host on different ephemeral ports share one bucket. Keying
  on RemoteAddr ('ip:port') would make every connection its own bucket and
  the limiter never trigger. }
procedure TestRateLimitRemoteIpFallback;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RateLimitMiddlewareWith(MakeRateLimitOpts(1, 60))]
  );

  LReq := TMockRequest.Create(hmGet, '/api');
  LReq.SetRemoteAddr('10.0.0.7:11111');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'first connection allowed');

  LReq := TMockRequest.Create(hmGet, '/api');
  LReq.SetRemoteAddr('10.0.0.7:22222');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(429), Int64(LWObj.Status),
    'same bare IP shares the bucket regardless of port');
end;

procedure TestRateLimitSetsHeaders;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RateLimitMiddlewareWith(MakeRateLimitOpts(5, 60))]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('5', LWObj.GetHeaders.Get('x-ratelimit-limit'), 'limit header');
  Check(LWObj.GetHeaders.Get('x-ratelimit-remaining') <> '', 'remaining header set');
  Check(LWObj.GetHeaders.Get('x-ratelimit-reset') <> '', 'reset header set');
end;

procedure TestRateLimitBlocksAfterLimit;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LI: Int32;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RateLimitMiddlewareWith(MakeRateLimitOpts(3, 60))]
  );
  for LI := 1 to 5 do
  begin
    LReq := TMockRequest.Create(hmGet, '/api');
    LReqIntf := LReq;
    LWObj := TMockResponseWriter.Create;
    LW := LWObj;
    LHandler.ServeHTTP(LReqIntf, LW);
  end;
  CheckEqual(Int64(429), Int64(LWObj.Status), 'returns 429 after limit');
  Check(Pos('too_many_requests', LWObj.Body) > 0, 'body has error code');
end;

procedure TestRateLimitDefaultOptions;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RateLimitMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('100', LWObj.GetHeaders.Get('x-ratelimit-limit'), 'default limit 100');
  CheckEqual(Int64(200), Int64(LWObj.Status), 'default allows request');
end;

procedure TestRateLimitNegativeMaxRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    RateLimitMiddlewareWith(MakeRateLimitOpts(-1, 60));
  except
    on E: EHttpError do
      LRaised := E.Kind = hekArgument;
  end;
  Check(LRaised, 'raises hekArgument on negative max requests');
end;

procedure TestRateLimitZeroWindowRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    RateLimitMiddlewareWith(MakeRateLimitOpts(10, 0));
  except
    on E: EHttpError do
      LRaised := E.Kind = hekArgument;
  end;
  Check(LRaised, 'raises hekArgument on zero window');
end;

procedure TestRateLimitMaxKeysRejectsNewKey;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LOpts: TRateLimitOptions;
  LHandlerCalled: Boolean;
begin
  LOpts := MakeRateLimitOpts(100, 60);
  LOpts.MaxKeys := 1;
  LOpts.TrustProxyHeaders := True;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RateLimitMiddlewareWith(LOpts)]
  );

  LReq := TMockRequest.Create(hmGet, '/api');
  LReq.SetHeader('x-forwarded-for', '10.0.0.1');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandlerCalled := False;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LHandlerCalled, 'first key allowed');
  CheckEqual(Int64(200), Int64(LWObj.Status), 'first key 200');

  LReq := TMockRequest.Create(hmGet, '/api');
  LReq.SetHeader('x-forwarded-for', '10.0.0.2');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandlerCalled := False;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(not LHandlerCalled, 'second distinct key rejected when MaxKeys=1');
  CheckEqual(Int64(429), Int64(LWObj.Status), 'MaxKeys full returns 429');
end;

procedure TestRateLimitMaxKeysZeroUnlimitedKeys;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LOpts: TRateLimitOptions;
  LI: Int32;
  LOk: Int32;
begin
  LOpts := MakeRateLimitOpts(100, 60);
  LOpts.MaxKeys := 0; { unlimited keys, tests-only }
  LOpts.TrustProxyHeaders := True;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RateLimitMiddlewareWith(LOpts)]
  );
  LOk := 0;
  for LI := 1 to 5 do
  begin
    LReq := TMockRequest.Create(hmGet, '/api');
    LReq.SetHeader('x-forwarded-for', '10.0.0.' + IntToStr(LI));
    LReqIntf := LReq;
    LWObj := TMockResponseWriter.Create;
    LW := LWObj;
    LHandler.ServeHTTP(LReqIntf, LW);
    if LWObj.Status = HTTP_STATUS_OK then
      Inc(LOk);
  end;
  CheckEqual(Int64(5), Int64(LOk), 'MaxKeys=0 allows many distinct keys');
end;

procedure TestRecoveryDoesNotRewriteAfterCommitted;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
      raise Exception.Create('after commit');
    end),
    [RecoveryMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/partial');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'keeps committed status');
  CheckEqual(Int64(1), Int64(LWObj.WriteHeaderCount), 'no second WriteHeader for 500');
  Check(Pos('internal_error', LWObj.Body) = 0, 'no 500 JSON after commit');
end;

{ WhenMiddleware tests }

procedure TestWhenMiddlewareAppliesWhenTrue;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [WhenMiddleware(
      function(const AReq: IHttpRequest): Boolean
      begin
        Result := True;
      end,
      CacheControlMiddleware('no-cache')
    )]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('no-cache', LWObj.GetHeaders.Get('cache-control'), 'middleware applied when predicate true');
end;

procedure TestWhenMiddlewareSkipsWhenFalse;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [WhenMiddleware(
      function(const AReq: IHttpRequest): Boolean
      begin
        Result := False;
      end,
      CacheControlMiddleware('no-cache')
    )]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('', LWObj.GetHeaders.Get('cache-control'), 'middleware skipped when predicate false');
  CheckEqual(Int64(200), Int64(LWObj.Status), 'handler still called');
end;

procedure TestWhenMiddlewarePathBased;
var
  LHandler: IHttpHandler;
  LW1Obj, LW2Obj: TMockResponseWriter;
  LW1, LW2: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [WhenMiddleware(
      function(const AReq: IHttpRequest): Boolean
      begin
        Result := Pos('/api/', AReq.Path) = 1;
      end,
      CacheControlMiddleware('public, max-age=3600')
    )]
  );
  { /api/ path — should apply }
  LReq := TMockRequest.Create(hmGet, '/api/users');
  LReqIntf := LReq;
  LW1Obj := TMockResponseWriter.Create;
  LW1 := LW1Obj;
  LHandler.ServeHTTP(LReqIntf, LW1);
  CheckEqual('public, max-age=3600', LW1Obj.GetHeaders.Get('cache-control'), 'applied for /api/ path');
  { /healthz path — should skip }
  LReq := TMockRequest.Create(hmGet, '/healthz');
  LReqIntf := LReq;
  LW2Obj := TMockResponseWriter.Create;
  LW2 := LW2Obj;
  LHandler.ServeHTTP(LReqIntf, LW2);
  CheckEqual('', LW2Obj.GetHeaders.Get('cache-control'), 'skipped for /healthz path');
end;

procedure TestWhenMiddlewareNilPredicateRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    WhenMiddleware(nil, CacheControlMiddleware('no-cache'));
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, 'raises on nil predicate');
end;

procedure TestWhenMiddlewareNilMiddlewareRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    WhenMiddleware(
      function(const AReq: IHttpRequest): Boolean
      begin
        Result := True;
      end,
      nil
    );
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, 'raises on nil middleware');
end;

{ HealthCheck tests }

procedure TestHealthCheckDefaultPath;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_NOT_FOUND);
    end),
    [HealthCheckMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/healthz');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'returns 200');
  Check(Pos('"status":"ok"', LWObj.Body) > 0, 'body has status ok');
  Check(Pos('application/json', LWObj.GetHeaders.Get('content-type')) > 0, 'content-type is json');
end;

procedure TestHealthCheckNonHealthPathPassesThrough;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_NOT_FOUND);
    end),
    [HealthCheckMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/api/users');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LHandlerCalled, 'handler called for non-health path');
  CheckEqual(Int64(404), Int64(LWObj.Status), 'status from handler');
end;

procedure TestHealthCheckPostMethodPassesThrough;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_METHOD_NOT_ALLOWED);
    end),
    [HealthCheckMiddleware]
  );
  LReq := TMockRequest.Create(hmPost, '/healthz');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LHandlerCalled, 'handler called for POST /healthz');
  CheckEqual(Int64(405), Int64(LWObj.Status), 'status from handler');
end;

procedure TestHealthCheckCustomPath;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_NOT_FOUND);
    end),
    [HealthCheckMiddlewareAt('/ready')]
  );
  LReq := TMockRequest.Create(hmGet, '/ready');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'returns 200 for custom path');
  Check(Pos('"status":"ok"', LWObj.Body) > 0, 'body has status ok');
end;

procedure TestHealthCheckCustomPathDefaultPathPasses;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_NOT_FOUND);
    end),
    [HealthCheckMiddlewareAt('/ready')]
  );
  LReq := TMockRequest.Create(hmGet, '/healthz');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LHandlerCalled, 'handler called for /healthz when custom path is /ready');
end;

procedure TestHealthCheckEmptyPathDefaults;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_NOT_FOUND);
    end),
    [HealthCheckMiddlewareAt('')]
  );
  LReq := TMockRequest.Create(hmGet, '/healthz');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'empty path defaults to /healthz');
end;

{ Metrics tests }

procedure TestMetricsCountsRequests;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LCollector: IHttpMetricsCollector;
  LMetrics: THttpMetrics;
begin
  LCollector := NewHttpMetricsCollector;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [MetricsMiddleware(LCollector)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  LMetrics := LCollector.Snapshot;
  CheckEqual(1, LMetrics.TotalRequests, 'one request counted');
  CheckEqual(1, LMetrics.Status2xx, 'one 2xx');
  CheckEqual(0, LMetrics.Status4xx, 'zero 4xx');
end;

procedure TestMetricsCountsMultipleRequests;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LCollector: IHttpMetricsCollector;
  LMetrics: THttpMetrics;
  LI: Int32;
begin
  LCollector := NewHttpMetricsCollector;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [MetricsMiddleware(LCollector)]
  );
  for LI := 1 to 5 do
  begin
    LReq := TMockRequest.Create(hmGet, '/api');
    LReqIntf := LReq;
    LWObj := TMockResponseWriter.Create;
    LW := LWObj;
    LHandler.ServeHTTP(LReqIntf, LW);
  end;
  LMetrics := LCollector.Snapshot;
  CheckEqual(5, LMetrics.TotalRequests, 'five requests counted');
  CheckEqual(5, LMetrics.Status2xx, 'five 2xx');
end;

procedure TestMetricsCountsByStatusClass;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LCollector: IHttpMetricsCollector;
  LMetrics: THttpMetrics;
  LStatusCode: Int32;
begin
  LCollector := NewHttpMetricsCollector;
  LStatusCode := 404;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(THttpStatus(LStatusCode));
    end),
    [MetricsMiddleware(LCollector)]
  );
  { 200 }
  LStatusCode := 200;
  LReq := TMockRequest.Create(hmGet, '/ok');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  { 404 }
  LStatusCode := 404;
  LReq := TMockRequest.Create(hmGet, '/not-found');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  { 500 }
  LStatusCode := 500;
  LReq := TMockRequest.Create(hmGet, '/error');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  LMetrics := LCollector.Snapshot;
  CheckEqual(3, LMetrics.TotalRequests, 'three requests');
  CheckEqual(1, LMetrics.Status2xx, 'one 2xx');
  CheckEqual(0, LMetrics.Status3xx, 'zero 3xx');
  CheckEqual(1, LMetrics.Status4xx, 'one 4xx');
  CheckEqual(1, LMetrics.Status5xx, 'one 5xx');
end;

procedure TestMetricsReset;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LCollector: IHttpMetricsCollector;
  LMetrics: THttpMetrics;
begin
  LCollector := NewHttpMetricsCollector;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [MetricsMiddleware(LCollector)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  LMetrics := LCollector.Snapshot;
  CheckEqual(1, LMetrics.TotalRequests, 'before reset');
  LCollector.Reset;
  LMetrics := LCollector.Snapshot;
  CheckEqual(0, LMetrics.TotalRequests, 'after reset');
  CheckEqual(0, LMetrics.Status2xx, '2xx reset');
end;

procedure TestMetricsTracksDuration;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LCollector: IHttpMetricsCollector;
  LMetrics: THttpMetrics;
begin
  LCollector := NewHttpMetricsCollector;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      TSleep.ForDuration(TDuration.FromMilliseconds(10));
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [MetricsMiddleware(LCollector)]
  );
  LReq := TMockRequest.Create(hmGet, '/slow');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  LMetrics := LCollector.Snapshot;
  Check(LMetrics.TotalDurationUs > 0, 'duration tracked');
end;

procedure TestMetricsNilCollectorRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    MetricsMiddleware(nil);
  except
    on E: EHttpError do
      LRaised := (E.Kind = hekArgument) and (E.Op = 'metrics');
  end;
  Check(LRaised, 'raises hekArgument Op=metrics on nil collector');
end;

procedure TestMetricsWithCallbackInvoked;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LCalled: Boolean;
  LStatus: Int64;
begin
  LCalled := False;
  LStatus := 0;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [MetricsMiddlewareWith(procedure(const AStatus: Int64; const ADurationUs: Int64)
    begin
      LCalled := True;
      LStatus := AStatus;
    end)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LCalled, 'callback invoked');
  CheckEqual(200, LStatus, 'status passed to callback');
end;

procedure TestMetricsWithCallbackMultiple;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LCount: Int32;
  LI: Int32;
begin
  LCount := 0;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [MetricsMiddlewareWith(procedure(const AStatus: Int64; const ADurationUs: Int64)
    begin
      Inc(LCount);
    end)]
  );
  for LI := 1 to 5 do
  begin
    LReq := TMockRequest.Create(hmGet, '/api');
    LReqIntf := LReq;
    LWObj := TMockResponseWriter.Create;
    LW := LWObj;
    LHandler.ServeHTTP(LReqIntf, LW);
  end;
  CheckEqual(5, LCount, 'callback called 5 times');
end;

procedure TestMetricsWithCallbackDuration;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LDuration: Int64;
begin
  LDuration := 0;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [MetricsMiddlewareWith(procedure(const AStatus: Int64; const ADurationUs: Int64)
    begin
      LDuration := ADurationUs;
    end)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LDuration >= 0, 'duration is non-negative');
end;

procedure TestMetricsWithNilCallbackRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    MetricsMiddlewareWith(nil);
  except
    on E: EHttpError do
      LRaised := (E.Kind = hekArgument) and (E.Op = 'metrics');
  end;
  Check(LRaised, 'raises hekArgument Op=metrics on nil callback');
end;

procedure TestMethodGuardAllowsGetMethod;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LCalled: Boolean;
begin
  LCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [MethodGuardMiddleware([hmGet])]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LCalled, 'handler called for allowed method');
  CheckEqual(200, LWObj.FStatus, 'status 200');
end;

procedure TestMethodGuardRejectsPostMethod;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LCalled: Boolean;
begin
  LCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [MethodGuardMiddleware([hmGet])]
  );
  LReq := TMockRequest.Create(hmPost, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(not LCalled, 'handler not called for disallowed method');
  CheckEqual(405, LWObj.FStatus, 'status 405');
end;

procedure TestMethodGuardSetsAllowHeader;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [MethodGuardMiddleware([hmGet, hmPost, hmPut])]
  );
  LReq := TMockRequest.Create(hmDelete, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(405, LWObj.FStatus, 'status 405');
  Check(LWObj.FHeaders.Get('allow') <> '', 'Allow header set');
  Check(Pos('GET', LWObj.FHeaders.Get('allow')) > 0, 'Allow contains GET');
  Check(Pos('POST', LWObj.FHeaders.Get('allow')) > 0, 'Allow contains POST');
  Check(Pos('PUT', LWObj.FHeaders.Get('allow')) > 0, 'Allow contains PUT');
end;

procedure TestMethodGuardMultipleMethodsAllowed;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LCalled: Boolean;
begin
  LCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [MethodGuardMiddleware([hmGet, hmPost])]
  );
  LReq := TMockRequest.Create(hmPost, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LCalled, 'handler called for second allowed method');
  CheckEqual(200, LWObj.FStatus, 'status 200');
end;

procedure TestMethodGuardOptionsMethodRejected;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [MethodGuardMiddleware([hmGet])]
  );
  LReq := TMockRequest.Create(hmOptions, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(405, LWObj.FStatus, 'OPTIONS rejected with 405');
end;

procedure TestBodyCacheMiddlewareCachesBody;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LReadBody: string;
  LBodyBytes: TBytes;
begin
  LBodyBytes := TBytes.Create(Ord('h'), Ord('e'), Ord('l'), Ord('l'), Ord('o'));
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      // Read body twice — should work because BodyCacheMiddleware cached it
      LReadBody := HttpReadRequestBodyString(AReq);
      // Second read should also succeed
      LReadBody := HttpReadRequestBodyString(AReq);
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [BodyCacheMiddleware]
  );
  LReq := TMockRequest.Create(hmPost, '/api');
  LReq.SetBodyReader(CreateBytesStreamFrom(LBodyBytes) as IReader);
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('hello', LReadBody, 'body cached and readable');
  CheckEqual(200, LWObj.FStatus, 'status 200');
end;

procedure TestBodyCacheMiddlewareNilBody;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LCalled: Boolean;
begin
  LCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [BodyCacheMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LCalled, 'handler called with nil body');
  CheckEqual(200, LWObj.FStatus, 'status 200');
end;

procedure TestBodyCacheMiddlewareOversizeReturns413;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LBodyBytes: TBytes;
  LCalled: Boolean;
  LI: SizeInt;
begin
  LCalled := False;
  SetLength(LBodyBytes, 64);
  for LI := 0 to High(LBodyBytes) do
    LBodyBytes[LI] := Ord('z');
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [BodyCacheMiddlewareWith(16)]
  );
  LReq := TMockRequest.Create(hmPost, '/api');
  LReq.SetBodyReader(CreateBytesStreamFrom(LBodyBytes) as IReader);
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(not LCalled, 'handler not entered on oversize');
  CheckEqual(413, LWObj.FStatus, 'status 413');
end;

procedure TestMetricsWithFieldsCallbackInvoked;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LCalled: Boolean;
  LMethod: string;
  LPath: string;
  LStatus: Int64;
begin
  LCalled := False;
  LMethod := '';
  LPath := '';
  LStatus := 0;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [MetricsMiddlewareWithFields(procedure(const AMethod: string; const APath: string;
      const AStatus: Int64; const ADurationUs: Int64)
    begin
      LCalled := True;
      LMethod := AMethod;
      LPath := APath;
      LStatus := AStatus;
    end)]
  );
  LReq := TMockRequest.Create(hmGet, '/api/users');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(LCalled, 'callback invoked');
  CheckEqual('GET', LMethod, 'method passed');
  CheckEqual('/api/users', LPath, 'path passed');
  CheckEqual(200, LStatus, 'status passed');
end;

procedure TestMetricsWithFieldsNilCallbackRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    MetricsMiddlewareWithFields(nil);
  except
    on E: EHttpError do
      LRaised := E.Kind = hekArgument;
  end;
  Check(LRaised, 'raises hekArgument on nil callback');
end;

procedure TestMetricsTracksRequestBytes;
var
  LCollector: IHttpMetricsCollector;
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LMetrics: THttpMetrics;
begin
  LCollector := NewHttpMetricsCollector;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [MetricsMiddleware(LCollector)]
  );
  LReq := TMockRequest.Create(hmPost, '/api');
  LReq.SetContentLength(1234);
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  LMetrics := LCollector.Snapshot;
  CheckEqual(1, LMetrics.TotalRequests, 'one request');
  CheckEqual(1234, LMetrics.RequestBytes, 'request bytes tracked');
end;

procedure TestMetricsTracksResponseBytes;
var
  LCollector: IHttpMetricsCollector;
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LMetrics: THttpMetrics;
begin
  LCollector := NewHttpMetricsCollector;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write('hello world'[1], 11);
    end),
    [MetricsMiddleware(LCollector)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  LMetrics := LCollector.Snapshot;
  CheckEqual(1, LMetrics.TotalRequests, 'one request');
  CheckEqual(11, LMetrics.ResponseBytes, 'response bytes tracked');
end;

procedure TestMetricsRecordsOnHandlerException;
var
  LCollector: IHttpMetricsCollector;
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LMetrics: THttpMetrics;
  LRaised: Boolean;
begin
  LCollector := NewHttpMetricsCollector;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      raise Exception.Create('handler boom');
    end),
    [MetricsMiddleware(LCollector)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LRaised := False;
  try
    LHandler.ServeHTTP(LReqIntf, LW);
  except
    LRaised := True;
  end;
  Check(LRaised, 'handler exception propagates');
  LMetrics := LCollector.Snapshot;
  CheckEqual(1, LMetrics.TotalRequests, 'exception path still counted');
  CheckEqual(1, LMetrics.Status5xx, 'uncommitted failure counts as 5xx');
end;

procedure TestMetricsCallbackExceptionDoesNotBreakRequest;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write('ok'[1], 2);
    end),
    [MetricsMiddlewareWith(procedure(const AStatus: Int64; const ADurationUs: Int64)
    begin
      raise Exception.Create('callback boom');
    end)]
  );
  LReq := TMockRequest.Create(hmGet, '/api');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status), 'response still OK');
  Check(Pos('ok', LWObj.Body) > 0, 'body still written');
end;

procedure TestMetricsNilArgsUseOpMetrics;
var
  LSrc: string;
begin
  LSrc := ReadFileText('../../../src/nextpas.core.http.middleware.metrics.pas');
  Check(Pos('METRICS_OP = ''metrics''', LSrc) > 0, 'metrics Op constant');
  Check(Pos('CreateOp(hekArgument, METRICS_OP', LSrc) > 0,
    'nil args use CreateOp Op=metrics');
  Check(Pos('MetricsStatusAfterHandler', LSrc) > 0,
    'exception path uses MetricsStatusAfterHandler');
end;

procedure TestDecompressGzipBody;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LGotBody: string;
  LCompressed: TBytes;
  LPlain: TBytes;
  I: Integer;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LBody: IReader;
      LBuf: array[0..255] of Byte;
      LN: SizeUInt;
    begin
      LBody := AReq.Body;
      if LBody <> nil then
      begin
        LN := LBody.Read(LBuf[0], SizeOf(LBuf));
        SetLength(LGotBody, LN);
        Move(LBuf[0], LGotBody[1], LN);
      end;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [DecompressMiddleware]
  );
  { Create gzip-compressed body }
  SetLength(LPlain, 11);
  for I := 0 to 10 do
    LPlain[I] := Byte('hello world'[I + 1]);
  LCompressed := GzipCompress(LPlain);
  LReq := TMockRequest.Create(hmPost, '/api');
  LReq.SetContentLength(Length(LCompressed));
  LReq.GetHeaders.SetHeader('content-encoding', 'gzip');
  LReq.SetBodyBytes(LCompressed);
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('hello world', LGotBody, 'gzip body decompressed');
  CheckEqual(200, LWObj.GetStatus, 'decompress succeeds');
end;

procedure TestDecompressPassesThroughPlain;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LGotBody: string;
  LBody: TBytes;
  I: Integer;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LBody: IReader;
      LBuf: array[0..255] of Byte;
      LN: SizeUInt;
    begin
      LBody := AReq.Body;
      if LBody <> nil then
      begin
        LN := LBody.Read(LBuf[0], SizeOf(LBuf));
        SetLength(LGotBody, LN);
        Move(LBuf[0], LGotBody[1], LN);
      end;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [DecompressMiddleware]
  );
  LReq := TMockRequest.Create(hmPost, '/api');
  LReq.SetContentLength(5);
  SetLength(LBody, 5);
  for I := 0 to 4 do
    LBody[I] := Byte('hello'[I + 1]);
  LReq.SetBodyBytes(LBody);
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('hello', LGotBody, 'plain body passes through');
  CheckEqual(200, LWObj.GetStatus, 'plain request succeeds');
end;

procedure TestDecompressEnforcesOutputLimit;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LCompressed: TBytes;
  LPlain: TBytes;
  LHandlerCalled: Boolean;
  I: Integer;
begin
  LHandlerCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [DecompressMiddleware(32)]
  );
  SetLength(LPlain, 256);
  for I := 0 to High(LPlain) do
    LPlain[I] := Ord('A');
  LCompressed := GzipCompress(LPlain);
  LReq := TMockRequest.Create(hmPost, '/api');
  LReq.SetContentLength(Length(LCompressed));
  LReq.GetHeaders.SetHeader('content-encoding', 'gzip');
  LReq.SetBodyBytes(LCompressed);
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(not LHandlerCalled, 'oversize decompressed body must not reach handler');
  CheckEqual(Int64(400), Int64(LWObj.GetStatus), 'oversize decompressed body rejected');
  Check(Pos('decompressed size exceeds limit', LWObj.Body) = 0,
    'compression internals are not exposed');
end;

procedure TestDecompressRejectsNegativeLimit;
begin
  try
    DecompressMiddleware(-1);
    Check(False, 'negative decompression limit must raise');
  except
    on E: EHttpError do
      Check(E.Kind = hekArgument, 'negative decompression limit rejected as hekArgument');
  end;
end;

procedure TestDecompressPreservesDuplicateHeaders;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LCompressed: TBytes;
  LPlain: TBytes;
  LValues: TStringArray;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LValues := AReq.Headers.GetAll('x-duplicate');
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [DecompressMiddleware(1024)]
  );
  SetLength(LPlain, 1);
  LPlain[0] := Ord('x');
  LCompressed := GzipCompress(LPlain);
  LReq := TMockRequest.Create(hmPost, '/api');
  LReq.SetContentLength(Length(LCompressed));
  LReq.GetHeaders.SetHeader('content-encoding', 'gzip');
  LReq.GetHeaders.Add('x-duplicate', 'one');
  LReq.GetHeaders.Add('x-duplicate', 'two');
  LReq.SetBodyBytes(LCompressed);
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(2), Int64(Length(LValues)), 'duplicate headers preserved');
  CheckEqual('one', LValues[0], 'first duplicate value preserved');
  CheckEqual('two', LValues[1], 'second duplicate value preserved');
end;

procedure TestDecompressDefaultBoundRejectsOversize;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LCompressed: TBytes;
  LPlain: TBytes;
  LHandlerCalled: Boolean;
begin
  LHandlerCalled := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [DecompressMiddleware]
  );
  SetLength(LPlain, HTTP_DEFAULT_BODY_READ_MAX + 1);
  FillChar(LPlain[0], Length(LPlain), Ord('A'));
  LCompressed := GzipCompress(LPlain);
  LReq := TMockRequest.Create(hmPost, '/api');
  LReq.SetContentLength(Length(LCompressed));
  LReq.GetHeaders.SetHeader('content-encoding', 'gzip');
  LReq.SetBodyBytes(LCompressed);
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  Check(not LHandlerCalled, 'default max must reject oversize decompress');
  CheckEqual(Int64(400), Int64(LWObj.GetStatus),
    'default oversize decompress returns 400');
end;

procedure TestDecompressExplicitZeroAllowsOverDefault;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LCompressed: TBytes;
  LPlain: TBytes;
  LGotLen: Int64;
begin
  LGotLen := -1;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LGotLen := AReq.ContentLength;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [DecompressMiddleware(0)]
  );
  SetLength(LPlain, HTTP_DEFAULT_BODY_READ_MAX + 1);
  FillChar(LPlain[0], Length(LPlain), Ord('B'));
  LCompressed := GzipCompress(LPlain);
  LReq := TMockRequest.Create(hmPost, '/api');
  LReq.SetContentLength(Length(LCompressed));
  LReq.GetHeaders.SetHeader('content-encoding', 'gzip');
  LReq.SetBodyBytes(LCompressed);
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(200), Int64(LWObj.GetStatus),
    'explicit 0 allows over-default decompress');
  CheckEqual(HTTP_DEFAULT_BODY_READ_MAX + 1, LGotLen,
    'explicit 0 yields full decompressed length');
end;

{ ServerHeader middleware tests }

procedure TestServerHeaderDefault;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [ServerHeaderMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/test');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual('nextpas', LWObj.FHeaders.Get('server'), 'default server header');
end;

procedure TestServerHeaderCustom;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [ServerHeaderMiddlewareWith('myapp/1.0')]
  );
  LReq := TMockRequest.Create(hmGet, '/test');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual('myapp/1.0', LWObj.FHeaders.Get('server'), 'custom server header');
end;

{ Context middleware tests }

procedure TestContextMiddlewareCreatesContext;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
  LCtxFound: Boolean;
begin
  LCtxFound := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LCtx: IHttpContext;
    begin
      LCtx := HttpContextOf(AReq);
      LCtxFound := LCtx <> nil;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [ContextMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/test');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  Check(LCtxFound, 'context was created');
end;

procedure TestContextMiddlewareSetGetValue;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
  LGotHas: Boolean;
begin
  LGotHas := False;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    var
      LCtx: IHttpContext;
    begin
      LCtx := HttpContextOf(AReq);
      if LCtx <> nil then
      begin
        LCtx.SetValue('test_key', GTestSentinel);
        LGotHas := LCtx.Has('test_key') and (LCtx.GetValue('test_key') = GTestSentinel);
        LCtx.Remove('test_key');
        LGotHas := LGotHas and (not LCtx.Has('test_key'));
      end;
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [ContextMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/test');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  Check(LGotHas, 'set/has/remove works');
end;

procedure TestContextMiddlewareSetOwnedValue;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
  LOwnedSeen: Boolean;
  LOwned: TObject;
begin
  LOwnedSeen := False;
  LOwned := TObject.Create;
  try
    LHandler := Chain(
      HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
      var
        LCtx: IHttpContext;
      begin
        LCtx := HttpContextOf(AReq);
        if LCtx <> nil then
        begin
          LCtx.SetOwnedValue('owned', LOwned);
          LOwnedSeen := LCtx.Has('owned') and (LCtx.GetValue('owned') = LOwned);
          LCtx.Remove('owned');
          LOwnedSeen := LOwnedSeen and (not LCtx.Has('owned'));
          LOwned := nil; { ownership transferred then freed by Remove }
        end;
        AW.WriteHeader(HTTP_STATUS_OK);
      end),
      [ContextMiddleware]
    );
    LReq := TMockRequest.Create(hmGet, '/test');
    LWObj := TMockResponseWriter.Create;
    LW := LWObj;
    LHandler.ServeHTTP(LReq, LW);
    Check(LOwnedSeen, 'SetOwnedValue has/remove frees owned object');
  finally
    LOwned.Free;
  end;
end;

procedure TestContextMiddlewareNilWithoutContext;
var
  LReq: IHttpRequest;
begin
  LReq := TMockRequest.Create(hmGet, '/test');
  Check(HttpContextOf(LReq) = nil, 'returns nil without context middleware');
end;

procedure TestContextMiddlewareCleansUp;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [ContextMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/test');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  Check(HttpContextOf(LReq) = nil, 'context cleaned up after handler');
end;

{ RateLimit Retry-After test }

procedure TestRateLimitRetryAfterHeader;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LI: Int32;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [RateLimitMiddlewareWith(MakeRateLimitOpts(2, 60))]
  );
  for LI := 1 to 4 do
  begin
    LReq := TMockRequest.Create(hmGet, '/api');
    LReqIntf := LReq;
    LWObj := TMockResponseWriter.Create;
    LW := LWObj;
    LHandler.ServeHTTP(LReqIntf, LW);
  end;
  CheckEqual(Int64(429), Int64(LWObj.Status), 'returns 429');
  Check(LWObj.FHeaders.Has('retry-after'), 'has Retry-After header');
  Check(LWObj.FHeaders.Get('retry-after') <> '', 'Retry-After is non-empty');
end;

{ JSON escaping test — uses HttpWriteErrorResponse directly }

procedure TestErrorResponseJsonEscaping;
var
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LWritten: SizeUInt;
begin
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LWritten := HttpWriteErrorResponse(LW, HTTP_STATUS_BAD_REQUEST,
    'test', 'line1'#10'line2 "quoted" \backslash');
  Check(LWritten > 0, 'wrote response');
  Check(Pos('\n', LWObj.Body) > 0, 'newline is escaped');
  Check(Pos('\"quoted\"', LWObj.Body) > 0, 'quotes are escaped');
  Check(Pos('\\backslash', LWObj.Body) > 0, 'backslash is escaped');
  Check(Pos('line1', LWObj.Body) > 0, 'original text preserved');
end;

{ BodyLimit JSON response test }

procedure TestBodyLimitReturnsJson;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [BodyLimitMiddleware(100)]
  );
  LReq := TMockRequest.Create(hmPost, '/upload');
  LReq.SetContentLength(200);
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(413), Int64(LWObj.Status), 'returns 413');
  CheckEqual('application/problem+json', LWObj.GetHeaders.Get('content-type'),
    'content-type is RFC 7807 problem+json');
  Check(Pos('"title":"payload_too_large"', LWObj.Body) > 0, 'has problem title');
end;

{ Compression middleware tests }

procedure TestCompressionGzipCompressesLargeBody;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LBigBody: string;
  I: Int32;
begin
  { Build a large compressible body (> 1024 bytes) }
  LBigBody := '';
  for I := 1 to 200 do
    LBigBody := LBigBody + 'Hello World 1234567890 ';

  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.GetHeaders.SetHeader('content-type', 'application/json');
      AW.WriteHeader(HTTP_STATUS_OK);
      if Length(LBigBody) > 0 then
        AW.Write(LBigBody[1], Length(LBigBody));
    end),
    [CompressionMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/api/data');
  LReq.SetHeader('accept-encoding', 'gzip');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'status 200');
  CheckEqual('gzip', LWObj.FHeaders.Get('content-encoding'), 'has gzip encoding');
  Check(Length(LWObj.BodyBytes) < Length(LBigBody), 'compressed body smaller');
end;

procedure TestCompressionSkipsSmallBody;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.GetHeaders.SetHeader('content-type', 'application/json');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(PAnsiChar('small')^, 5);
    end),
    [CompressionMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/api/data');
  LReq.SetHeader('accept-encoding', 'gzip');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('', LWObj.FHeaders.Get('content-encoding'), 'no encoding for small body');
end;

procedure TestCompressionSkipsWithoutAcceptEncoding;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LBigBody: string;
  I: Int32;
begin
  LBigBody := '';
  for I := 1 to 200 do
    LBigBody := LBigBody + 'Hello World 1234567890 ';

  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.GetHeaders.SetHeader('content-type', 'application/json');
      AW.WriteHeader(HTTP_STATUS_OK);
      if Length(LBigBody) > 0 then
        AW.Write(LBigBody[1], Length(LBigBody));
    end),
    [CompressionMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/api/data');
  { No Accept-Encoding header }
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('', LWObj.FHeaders.Get('content-encoding'), 'no encoding without Accept-Encoding');
  CheckEqual(Length(LBigBody), Length(LWObj.BodyBytes), 'body uncompressed');
end;

procedure TestCompressionSkipsNonCompressibleType;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LBigBody: string;
  I: Int32;
begin
  LBigBody := '';
  for I := 1 to 200 do
    LBigBody := LBigBody + 'binary data here!!! ';

  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.GetHeaders.SetHeader('content-type', 'image/png');
      AW.WriteHeader(HTTP_STATUS_OK);
      if Length(LBigBody) > 0 then
        AW.Write(LBigBody[1], Length(LBigBody));
    end),
    [CompressionMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/image.png');
  LReq.SetHeader('accept-encoding', 'gzip');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('', LWObj.FHeaders.Get('content-encoding'), 'no encoding for image/png');
end;

procedure TestCompressionDeflateSupported;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LBigBody: string;
  I: Int32;
begin
  LBigBody := '';
  for I := 1 to 200 do
    LBigBody := LBigBody + 'Hello World 1234567890 ';

  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.GetHeaders.SetHeader('content-type', 'text/html');
      AW.WriteHeader(HTTP_STATUS_OK);
      if Length(LBigBody) > 0 then
        AW.Write(LBigBody[1], Length(LBigBody));
    end),
    [CompressionMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/page');
  LReq.SetHeader('accept-encoding', 'deflate');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('deflate', LWObj.FHeaders.Get('content-encoding'), 'deflate encoding');
  Check(Length(LWObj.BodyBytes) < Length(LBigBody), 'deflate body smaller');
end;

procedure TestCompressionHonorsQZero;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LBigBody: string;
begin
  LBigBody := StringOfChar('A', 4096);
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.GetHeaders.SetHeader('content-type', 'text/plain');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(LBigBody[1], Length(LBigBody));
    end),
    [CompressionMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/data');
  LReq.SetHeader('accept-encoding', 'gzip;q=0, deflate;q=0');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('', LWObj.GetHeaders.Get('content-encoding'),
    'q=0 encodings are not selected');
  CheckEqual(Int64(Length(LBigBody)), Int64(Length(LWObj.BodyBytes)),
    'q=0 response remains uncompressed');
end;

procedure TestCompressionChoosesHighestQuality;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LBigBody: string;
begin
  LBigBody := StringOfChar('B', 4096);
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.GetHeaders.SetHeader('content-type', 'text/plain');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(LBigBody[1], Length(LBigBody));
    end),
    [CompressionMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/data');
  LReq.SetHeader('accept-encoding', 'gzip;q=0.2, deflate;q=0.8');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('deflate', LWObj.GetHeaders.Get('content-encoding'),
    'highest quality supported encoding selected');
end;

procedure TestCompressionPreservesExistingVary;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LBigBody: string;
begin
  LBigBody := StringOfChar('C', 4096);
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.GetHeaders.SetHeader('content-type', 'text/plain');
      AW.GetHeaders.SetHeader('vary', 'Origin');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(LBigBody[1], Length(LBigBody));
    end),
    [CompressionMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/data');
  LReq.SetHeader('accept-encoding', 'gzip');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual('Origin, Accept-Encoding', LWObj.GetHeaders.Get('vary'),
    'compression appends to Vary');
end;

procedure TestCompressionDoesNotRetryCommittedWriteFailure;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
  LBigBody: string;
begin
  LBigBody := StringOfChar('D', 4096);
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.GetHeaders.SetHeader('content-type', 'text/plain');
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(LBigBody[1], Length(LBigBody));
    end),
    [CompressionMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/data');
  LReq.SetHeader('accept-encoding', 'gzip');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LWObj.SetRaiseOnWrite(True);
  LW := LWObj;
  try
    LHandler.ServeHTTP(LReqIntf, LW);
    Check(False, 'downstream write failure must propagate');
  except
    on E: EIOError do
      Check(True, 'downstream write failure propagated');
  end;
  CheckEqual(Int64(1), Int64(LWObj.WriteHeaderCount),
    'committed response is not written a second time');
end;

procedure TestCompressionOmitsContentLengthForNoContent;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_NO_CONTENT);
    end),
    [CompressionMiddleware]
  );
  LReq := TMockRequest.Create(hmGet, '/empty');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(204), Int64(LWObj.Status), 'status remains 204');
  Check(not LWObj.GetHeaders.Has('content-length'),
    '204 response does not gain content-length');
end;

procedure TestContentTypeReturnsJson415;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
    end),
    [ContentTypeMiddleware(['application/json'])]
  );
  LReq := TMockRequest.Create(hmPost, '/api/data');
  LReq.SetHeader('content-type', 'text/plain');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(415), Int64(LWObj.Status), 'returns 415');
  CheckEqual('application/problem+json', LWObj.GetHeaders.Get('content-type'),
    'content-type is RFC 7807 problem+json');
  Check(Pos('"title":"unsupported_media_type"', LWObj.Body) > 0, 'has problem title');
end;

{ Deadline middleware tests }

procedure TestDeadlineFastHandlerPasses;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(PAnsiChar('fast')^, 4);
    end),
    [DeadlineMiddleware(5000)]
  );
  LReq := TMockRequest.Create(hmGet, '/fast');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(200), Int64(LWObj.Status), 'fast handler returns 200');
  CheckEqual('fast', LWObj.Body, 'fast handler body preserved');
end;

procedure TestDeadlineSlowHandlerTimesOut;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: TMockRequest;
  LReqIntf: IHttpRequest;
begin
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      { Simulate slow handler }
      TSleep.ForDuration(TDuration.FromMilliseconds(200));
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(PAnsiChar('slow response')^, 13);
    end),
    [DeadlineMiddleware(50)]
  );
  LReq := TMockRequest.Create(hmGet, '/slow');
  LReqIntf := LReq;
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReqIntf, LW);
  CheckEqual(Int64(504), Int64(LWObj.Status), 'slow handler returns 504');
  Check(Pos('gateway_timeout', LWObj.Body) > 0, 'has timeout error code');
end;

procedure TestDeadlineZeroRaises;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    DeadlineMiddleware(0);
  except
    on E: EHttpError do
      LCaught := E.Kind = hekArgument;
  end;
  Check(LCaught, 'zero timeout raises hekArgument');
end;

procedure TestDeadlineReleasesBufferedWriter;
var
  LHandler: IHttpHandler;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
  LDestroyCountBefore: Int32;
begin
  LDestroyCountBefore := GTrackedWriterDestroyCount;
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(PAnsiChar('done')^, 4);
    end),
    [DeadlineMiddleware(5000)]
  );
  LReq := TMockRequest.Create(hmGet, '/lifetime');
  LW := TTrackingResponseWriter.Create;
  LHandler.ServeHTTP(LReq, LW);
  LW := nil;
  LReq := nil;
  LHandler := nil;
  CheckEqual(Int64(LDestroyCountBefore + 1), Int64(GTrackedWriterDestroyCount),
    'deadline releases its buffered writer and real writer');
end;

procedure TestDeadlineBufferLimitRejectsOversize;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
  LHandlerCalled: Boolean;
  LPayload: TBytes;
  I: Integer;
begin
  LHandlerCalled := False;
  SetLength(LPayload, 64);
  for I := 0 to High(LPayload) do
    LPayload[I] := Ord('X');
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LHandlerCalled := True;
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(LPayload[0], Length(LPayload));
    end),
    [DeadlineMiddlewareWith(5000, 32)]
  );
  LReq := TMockRequest.Create(hmGet, '/big');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  Check(LHandlerCalled, 'handler still runs (post-hoc buffer)');
  CheckEqual(Int64(413), Int64(LWObj.GetStatus), 'oversize deadline buffer → 413');
  Check(Pos('payload_too_large', LWObj.Body) > 0, '413 error code');
  Check(Pos('X', LWObj.Body) = 0, 'buffered body discarded');
end;

procedure TestDeadlineWithUnlimitedBufferAllowsLarge;
var
  LHandler: IHttpHandler;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
  LReq: IHttpRequest;
  LPayload: TBytes;
  I: Integer;
begin
  SetLength(LPayload, 128);
  for I := 0 to High(LPayload) do
    LPayload[I] := Ord('Y');
  LHandler := Chain(
    HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      AW.WriteHeader(HTTP_STATUS_OK);
      AW.Write(LPayload[0], Length(LPayload));
    end),
    [DeadlineMiddlewareWith(5000, 0)]
  );
  LReq := TMockRequest.Create(hmGet, '/unbounded');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual(Int64(200), Int64(LWObj.GetStatus), 'explicit 0 buffer allows large body');
  CheckEqual(Int64(Length(LPayload)), Int64(Length(LWObj.Body)), 'full body flushed');
end;


var
  T: TTestSuite;
begin
  GTestSentinel := TObject.Create;
  T := TTestSuite.Create('nextpas.core.http.middlewares');
  { Recovery }
  T.Test('Recovery: handler raises → 500', @TestRecoveryHandlerRaises);
  T.Test('Recovery: handler succeeds → passthrough', @TestRecoveryHandlerSucceeds);
  T.Test('Recovery: exception details hidden', @TestRecoveryHidesExceptionDetails);
  T.Test('RecoveryWith: callback receives exception', @TestRecoveryWithCallbackReceivesException);
  T.Test('RecoveryWith: nil callback behaves like silent', @TestRecoveryWithNilCallbackBehavesLikeSilent);
  T.Test('RecoveryWith: success passes through', @TestRecoveryWithSuccessPassesThrough);
  T.Test('Recovery: no rewrite after headers committed', @TestRecoveryDoesNotRewriteAfterCommitted);
  { Logger }
  T.Test('Logger: calls next handler', @TestLoggerCallsNext);
  T.Test('Logger: preserves status', @TestLoggerPreservesStatus);
  T.Test('Logger: no crash on 404', @TestLoggerNoCrash);
  T.Test('Logger: extras provider appends fields', @TestLoggerExtras);
  T.Test('Logger: extras with default logger', @TestLoggerExtrasDefaultLogger);
  { CORS }
  T.Test('CORS: preflight → 204 + headers', @TestCorsPreflight);
  T.Test('CORS: normal GET with Origin', @TestCorsNormalRequest);
  T.Test('CORS: no Origin → no CORS headers', @TestCorsNoOriginHeader);
  T.Test('CORS: AllowCredentials header', @TestCorsCredentials);
  T.Test('CORS: specific origin allowed + Vary', @TestCorsSpecificOriginAllowed);
  T.Test('CORS: specific origin denied', @TestCorsSpecificOriginDenied);
  T.Test('CORS: credentials+wildcard echoes Origin', @TestCorsCredentialsWildcardEchoesOrigin);
  T.Test('CORS: MaxAge header', @TestCorsMaxAge);
  T.Test('CORS: custom AllowMethods/AllowHeaders', @TestCorsCustomMethodsHeaders);
  T.Test('CORS: wildcard echoes request headers', @TestCorsWildcardEchoesRequestHeaders);
  { Timeout }
  T.Test('Timeout: fast handler has X-Response-Time', @TestTimeoutFastHandler);
  T.Test('Timeout: slow handler still works', @TestTimeoutSlowHandler);
  T.Test('Timeout: X-Response-Time has ms suffix', @TestTimeoutResponseTimeValue);
  { BodyLimit }
  T.Test('BodyLimit: under limit passes through', @TestBodyLimitUnderLimitPasses);
  T.Test('BodyLimit: over limit returns 413', @TestBodyLimitOverLimitRejects);
  T.Test('BodyLimit: exact limit passes through', @TestBodyLimitExactLimitPasses);
  T.Test('BodyLimit: no content-length passes through', @TestBodyLimitNoContentLengthPasses);
  T.Test('BodyLimit: zero content-length passes through', @TestBodyLimitZeroContentLengthPasses);
  T.Test('BodyLimit: handler not called on reject', @TestBodyLimitRejectsHandlerNotCalled);
  { ContentType }
  T.Test('ContentType: accepted type passes through', @TestContentTypeAcceptedPasses);
  T.Test('ContentType: rejected type returns 415', @TestContentTypeRejectedReturns415);
  T.Test('ContentType: ignores charset parameters', @TestContentTypeIgnoresParams);
  T.Test('ContentType: GET request skips check', @TestContentTypeGetSkipsCheck);
  T.Test('ContentType: empty accepted allows any', @TestContentTypeEmptyAllowsAny);
  T.Test('ContentType: missing content-type passes', @TestContentTypeMissingPasses);
  { RequestId }
  T.Test('RequestId: generates UUID id', @TestRequestIdGeneratesId);
  T.Test('RequestId: preserves existing id', @TestRequestIdPreservesExisting);
  T.Test('RequestId: custom header name', @TestRequestIdCustomHeader);
  T.Test('RequestId: unique per request', @TestRequestIdUniquePerRequest);
  T.Test('RequestIdWithGenerator: uses custom generator', @TestRequestIdWithGeneratorUsesCustom);
  T.Test('RequestIdWithGenerator: preserves existing', @TestRequestIdWithGeneratorPreservesExisting);
  T.Test('RequestIdWithGenerator: custom header', @TestRequestIdWithGeneratorCustomHeader);
  T.Test('RequestIdWithGenerator: unique per request', @TestRequestIdWithGeneratorUniquePerRequest);
  T.Test('RequestId: stashes id into context bag', @TestRequestIdStashesIntoContext);
  T.Test('RequestId: feeds logger extras via context', @TestRequestIdFeedsLoggerExtras);
  { CacheControl }
  T.Test('CacheControl: sets header on response', @TestCacheControlSetsHeader);
  T.Test('CacheControl: NoCache convenience', @TestNoCacheMiddlewareSetsHeader);
  T.Test('CacheControl: MaxAge convenience', @TestMaxAgeMiddlewareSetsHeader);
  T.Test('CacheControl: negative MaxAge raises', @TestMaxAgeNegativeRaises);
  T.Test('CacheControl: handler still called', @TestCacheControlHandlerStillCalled);
  { RateLimit }
  T.Test('RateLimit: allows under limit', @TestRateLimitAllowsUnderLimit);
  T.Test('RateLimit: key uses bare IP (port stripped)', @TestRateLimitRemoteIpFallback);
  T.Test('RateLimit: sets rate limit headers', @TestRateLimitSetsHeaders);
  T.Test('RateLimit: blocks after limit exceeded', @TestRateLimitBlocksAfterLimit);
  T.Test('RateLimit: default 100/60s', @TestRateLimitDefaultOptions);
  T.Test('RateLimit: negative max raises', @TestRateLimitNegativeMaxRaises);
  T.Test('RateLimit: zero window raises', @TestRateLimitZeroWindowRaises);
  T.Test('RateLimit: MaxKeys rejects new key', @TestRateLimitMaxKeysRejectsNewKey);
  T.Test('RateLimit: MaxKeys=0 unlimited keys', @TestRateLimitMaxKeysZeroUnlimitedKeys);
  { WhenMiddleware }
  T.Test('When: applies when predicate true', @TestWhenMiddlewareAppliesWhenTrue);
  T.Test('When: skips when predicate false', @TestWhenMiddlewareSkipsWhenFalse);
  T.Test('When: path-based conditional', @TestWhenMiddlewarePathBased);
  T.Test('When: nil predicate raises', @TestWhenMiddlewareNilPredicateRaises);
  T.Test('When: nil middleware raises', @TestWhenMiddlewareNilMiddlewareRaises);
  { HealthCheck }
  T.Test('HealthCheck: default /healthz returns 200', @TestHealthCheckDefaultPath);
  T.Test('HealthCheck: non-health path passes through', @TestHealthCheckNonHealthPathPassesThrough);
  T.Test('HealthCheck: POST method passes through', @TestHealthCheckPostMethodPassesThrough);
  T.Test('HealthCheck: custom path', @TestHealthCheckCustomPath);
  T.Test('HealthCheck: custom path ignores /healthz', @TestHealthCheckCustomPathDefaultPathPasses);
  T.Test('HealthCheck: empty path defaults to /healthz', @TestHealthCheckEmptyPathDefaults);
  { Metrics }
  T.Test('Metrics: counts requests', @TestMetricsCountsRequests);
  T.Test('Metrics: counts multiple requests', @TestMetricsCountsMultipleRequests);
  T.Test('Metrics: counts by status class', @TestMetricsCountsByStatusClass);
  T.Test('Metrics: reset clears counters', @TestMetricsReset);
  T.Test('Metrics: tracks duration', @TestMetricsTracksDuration);
  T.Test('Metrics: nil collector raises', @TestMetricsNilCollectorRaises);
  T.Test('MetricsWith: callback invoked', @TestMetricsWithCallbackInvoked);
  T.Test('MetricsWith: callback called multiple times', @TestMetricsWithCallbackMultiple);
  T.Test('MetricsWith: callback receives duration', @TestMetricsWithCallbackDuration);
  T.Test('MetricsWith: nil callback raises', @TestMetricsWithNilCallbackRaises);
  { MethodGuard }
  T.Test('MethodGuard: allows GET method', @TestMethodGuardAllowsGetMethod);
  T.Test('MethodGuard: rejects POST method', @TestMethodGuardRejectsPostMethod);
  T.Test('MethodGuard: sets Allow header on 405', @TestMethodGuardSetsAllowHeader);
  T.Test('MethodGuard: multiple methods allowed', @TestMethodGuardMultipleMethodsAllowed);
  T.Test('MethodGuard: OPTIONS rejected', @TestMethodGuardOptionsMethodRejected);
  { BodyCache }
  T.Test('BodyCache: caches body for re-reading', @TestBodyCacheMiddlewareCachesBody);
  T.Test('BodyCache: nil body passes through', @TestBodyCacheMiddlewareNilBody);
  T.Test('BodyCache: oversize returns 413', @TestBodyCacheMiddlewareOversizeReturns413);
  { MetricsWithFields }
  T.Test('MetricsWithFields: callback receives method+path+status', @TestMetricsWithFieldsCallbackInvoked);
  T.Test('MetricsWithFields: nil callback raises', @TestMetricsWithFieldsNilCallbackRaises);
  T.Test('Metrics: tracks request bytes', @TestMetricsTracksRequestBytes);
  T.Test('Metrics: tracks response bytes', @TestMetricsTracksResponseBytes);
  T.Test('Metrics: records on handler exception', @TestMetricsRecordsOnHandlerException);
  T.Test('Metrics: callback exception does not break request',
    @TestMetricsCallbackExceptionDoesNotBreakRequest);
  T.Test('Metrics: nil args use Op=metrics', @TestMetricsNilArgsUseOpMetrics);
  T.Test('Decompress: gzip body', @TestDecompressGzipBody);
  T.Test('Decompress: passes through plain', @TestDecompressPassesThroughPlain);
  T.Test('Decompress: enforces output limit', @TestDecompressEnforcesOutputLimit);
  T.Test('Decompress: rejects negative limit', @TestDecompressRejectsNegativeLimit);
  T.Test('Decompress: preserves duplicate headers', @TestDecompressPreservesDuplicateHeaders);
  T.Test('Decompress: default bound rejects oversize',
    @TestDecompressDefaultBoundRejectsOversize);
  T.Test('Decompress: explicit 0 allows over-default',
    @TestDecompressExplicitZeroAllowsOverDefault);
  { ServerHeader }
  T.Test('ServerHeader: default nextpas', @TestServerHeaderDefault);
  T.Test('ServerHeader: custom name', @TestServerHeaderCustom);
  { Context }
  T.Test('Context: creates context', @TestContextMiddlewareCreatesContext);
  T.Test('Context: set and get value', @TestContextMiddlewareSetGetValue);
  T.Test('Context: SetOwnedValue', @TestContextMiddlewareSetOwnedValue);
  T.Test('Context: nil without middleware', @TestContextMiddlewareNilWithoutContext);
  T.Test('Context: cleans up after handler', @TestContextMiddlewareCleansUp);
  { RateLimit Retry-After }
  T.Test('RateLimit: 429 includes Retry-After', @TestRateLimitRetryAfterHeader);
  { JSON escaping }
  T.Test('ErrorResponse: JSON escaping', @TestErrorResponseJsonEscaping);
  { BodyLimit JSON }
  T.Test('BodyLimit: returns JSON error', @TestBodyLimitReturnsJson);
  { Compression }
  T.Test('Compression: gzip compresses large body', @TestCompressionGzipCompressesLargeBody);
  T.Test('Compression: skips small body', @TestCompressionSkipsSmallBody);
  T.Test('Compression: skips without Accept-Encoding', @TestCompressionSkipsWithoutAcceptEncoding);
  T.Test('Compression: skips non-compressible type', @TestCompressionSkipsNonCompressibleType);
  T.Test('Compression: deflate supported', @TestCompressionDeflateSupported);
  T.Test('Compression: honors q=0', @TestCompressionHonorsQZero);
  T.Test('Compression: chooses highest quality', @TestCompressionChoosesHighestQuality);
  T.Test('Compression: preserves Vary', @TestCompressionPreservesExistingVary);
  T.Test('Compression: committed write failure is not retried', @TestCompressionDoesNotRetryCommittedWriteFailure);
  T.Test('Compression: 204 omits content-length', @TestCompressionOmitsContentLengthForNoContent);
  { ContentType JSON }
  T.Test('ContentType: returns JSON 415', @TestContentTypeReturnsJson415);
  { Deadline }
  T.Test('Deadline: fast handler passes', @TestDeadlineFastHandlerPasses);
  T.Test('Deadline: slow handler times out', @TestDeadlineSlowHandlerTimesOut);
  T.Test('Deadline: zero timeout raises', @TestDeadlineZeroRaises);
  T.Test('Deadline: releases buffered writer', @TestDeadlineReleasesBufferedWriter);
  T.Test('Deadline: buffer limit rejects oversize',
    @TestDeadlineBufferLimitRejectsOversize);
  T.Test('Deadline: unlimited buffer allows large',
    @TestDeadlineWithUnlimitedBufferAllowsLarge);
  if not T.Run then Halt(1);
  GTestSentinel.Free;
end.
