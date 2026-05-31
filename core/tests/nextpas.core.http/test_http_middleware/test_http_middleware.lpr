program test_http_middleware;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.middleware;

type
  TMockResponseWriter = class(TInterfacedObject, IHttpResponseWriter)
  private
    FStatus: THttpStatus;
    FBody: string;
    FHeaders: IHttpHeaders;
  public
    constructor Create;
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    property Status: THttpStatus read FStatus;
    property Body: string read FBody;
  end;

  TMockRequest = class(TInterfacedObject, IHttpRequest)
  private
    FMethod: THttpMethod;
    FUrl: TUrl;
    FHeaders: IHttpHeaders;
  public
    constructor Create(const AMethod: THttpMethod; const APath: string);
    function GetMethod: THttpMethod;
    function GetUrl: TUrl;
    function GetVersion: THttpVersion;
    function GetHeaders: IHttpHeaders;
    function GetBody: IReader;
    function GetContentLength: Int64;
    function PathParam(const AName: string): string;
  end;

{ TMockResponseWriter }

constructor TMockResponseWriter.Create;
begin
  inherited Create;
  FStatus := 0;
  FBody := '';
  FHeaders := NewHttpHeaders;
end;

procedure TMockResponseWriter.WriteHeader(const AStatus: THttpStatus);
begin
  FStatus := AStatus;
end;

function TMockResponseWriter.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function TMockResponseWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LStr: string;
begin
  SetLength(LStr, ACount);
  if ACount > 0 then
    Move(ABuf, LStr[1], ACount);
  FBody := FBody + LStr;
  Result := ACount;
end;

procedure TMockResponseWriter.Flush;
begin
end;

{ TMockRequest }

constructor TMockRequest.Create(const AMethod: THttpMethod; const APath: string);
begin
  inherited Create;
  FMethod := AMethod;
  FUrl := Default(TUrl);
  FUrl.Path := APath;
  FHeaders := NewHttpHeaders;
end;

function TMockRequest.GetMethod: THttpMethod;
begin
  Result := FMethod;
end;

function TMockRequest.GetUrl: TUrl;
begin
  Result := FUrl;
end;

function TMockRequest.GetVersion: THttpVersion;
begin
  Result := hvHttp11;
end;

function TMockRequest.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function TMockRequest.GetBody: IReader;
begin
  Result := nil;
end;

function TMockRequest.GetContentLength: Int64;
begin
  Result := 0;
end;

function TMockRequest.PathParam(const AName: string): string;
begin
  Result := '';
end;

{ Class-based test helpers }
type
  TTagHandler = class(TInterfacedObject, IHttpHandler)
  private
    FTag: string;
    FStatus: THttpStatus;
  public
    constructor Create(const ATag: string; const AStatus: THttpStatus = 0);
    procedure ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
  end;

  TWrapHandler = class(TInterfacedObject, IHttpHandler)
  private
    FTag: string;
    FNext: IHttpHandler;
  public
    constructor Create(const ATag: string; const ANext: IHttpHandler);
    destructor Destroy; override;
    procedure ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
  end;

  TTagMiddleware = class(TInterfacedObject, IHttpMiddleware)
  private
    FTag: string;
  public
    constructor Create(const ATag: string);
    function Wrap(const ANext: IHttpHandler): IHttpHandler;
  end;

  THeaderMiddleware = class(TInterfacedObject, IHttpMiddleware)
  private
    FName, FValue: string;
  public
    constructor Create(const AName, AValue: string);
    function Wrap(const ANext: IHttpHandler): IHttpHandler;
  end;

  THeaderWrapHandler = class(TInterfacedObject, IHttpHandler)
  private
    FName, FValue: string;
    FNext: IHttpHandler;
  public
    constructor Create(const AName, AValue: string; const ANext: IHttpHandler);
    destructor Destroy; override;
    procedure ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
  end;

  TBlockMiddleware = class(TInterfacedObject, IHttpMiddleware)
  private
    FTag: string;
    FStatus: THttpStatus;
  public
    constructor Create(const ATag: string; const AStatus: THttpStatus);
    function Wrap(const ANext: IHttpHandler): IHttpHandler;
  end;

  TBlockHandler = class(TInterfacedObject, IHttpHandler)
  private
    FTag: string;
    FStatus: THttpStatus;
  public
    constructor Create(const ATag: string; const AStatus: THttpStatus);
    procedure ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
  end;

  TPrefixMiddleware = class(TInterfacedObject, IHttpMiddleware)
  private
    FPrefix: string;
  public
    constructor Create(const APrefix: string);
    function Wrap(const ANext: IHttpHandler): IHttpHandler;
  end;

  TPrefixWrapHandler = class(TInterfacedObject, IHttpHandler)
  private
    FPrefix: string;
    FNext: IHttpHandler;
  public
    constructor Create(const APrefix: string; const ANext: IHttpHandler);
    destructor Destroy; override;
    procedure ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
  end;

  { Handler that writes body text }
  TBodyHandler = class(TInterfacedObject, IHttpHandler)
  private
    FBody: string;
    FStatus: THttpStatus;
  public
    constructor Create(const ABody: string; const AStatus: THttpStatus);
    procedure ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
  end;

var
  GLog: string;

procedure ResetLog;
begin
  GLog := '';
end;

{ TTagHandler }
constructor TTagHandler.Create(const ATag: string; const AStatus: THttpStatus);
begin inherited Create; FTag := ATag; FStatus := AStatus; end;
procedure TTagHandler.ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
begin
  GLog := GLog + FTag;
  if FStatus <> 0 then AW.WriteHeader(FStatus);
end;

{ TWrapHandler }
constructor TWrapHandler.Create(const ATag: string; const ANext: IHttpHandler);
begin inherited Create; FTag := ATag; FNext := ANext; end;
destructor TWrapHandler.Destroy;
begin FNext := nil; inherited Destroy; end;
procedure TWrapHandler.ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
begin
  GLog := GLog + FTag + '>';
  FNext.ServeHTTP(AReq, AW);
  GLog := GLog + '<' + FTag + ';';
end;

{ TTagMiddleware }
constructor TTagMiddleware.Create(const ATag: string);
begin inherited Create; FTag := ATag; end;
function TTagMiddleware.Wrap(const ANext: IHttpHandler): IHttpHandler;
begin Result := TWrapHandler.Create(FTag, ANext); end;

{ THeaderMiddleware }
constructor THeaderMiddleware.Create(const AName, AValue: string);
begin inherited Create; FName := AName; FValue := AValue; end;
function THeaderMiddleware.Wrap(const ANext: IHttpHandler): IHttpHandler;
begin Result := THeaderWrapHandler.Create(FName, FValue, ANext); end;

{ THeaderWrapHandler }
constructor THeaderWrapHandler.Create(const AName, AValue: string; const ANext: IHttpHandler);
begin inherited Create; FName := AName; FValue := AValue; FNext := ANext; end;
destructor THeaderWrapHandler.Destroy;
begin FNext := nil; inherited Destroy; end;
procedure THeaderWrapHandler.ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
begin
  AW.GetHeaders.Set_(FName, FValue);
  FNext.ServeHTTP(AReq, AW);
end;

{ TBlockMiddleware }
constructor TBlockMiddleware.Create(const ATag: string; const AStatus: THttpStatus);
begin inherited Create; FTag := ATag; FStatus := AStatus; end;
function TBlockMiddleware.Wrap(const ANext: IHttpHandler): IHttpHandler;
begin Result := TBlockHandler.Create(FTag, FStatus); end;

{ TBlockHandler }
constructor TBlockHandler.Create(const ATag: string; const AStatus: THttpStatus);
begin inherited Create; FTag := ATag; FStatus := AStatus; end;
procedure TBlockHandler.ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
begin
  GLog := GLog + FTag;
  AW.WriteHeader(FStatus);
end;

{ TPrefixMiddleware }
constructor TPrefixMiddleware.Create(const APrefix: string);
begin inherited Create; FPrefix := APrefix; end;
function TPrefixMiddleware.Wrap(const ANext: IHttpHandler): IHttpHandler;
begin Result := TPrefixWrapHandler.Create(FPrefix, ANext); end;

{ TPrefixWrapHandler }
constructor TPrefixWrapHandler.Create(const APrefix: string; const ANext: IHttpHandler);
begin inherited Create; FPrefix := APrefix; FNext := ANext; end;
destructor TPrefixWrapHandler.Destroy;
begin FNext := nil; inherited Destroy; end;
procedure TPrefixWrapHandler.ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
begin
  AW.Write(FPrefix[1], Length(FPrefix));
  FNext.ServeHTTP(AReq, AW);
end;

{ TBodyHandler }
constructor TBodyHandler.Create(const ABody: string; const AStatus: THttpStatus);
begin inherited Create; FBody := ABody; FStatus := AStatus; end;
procedure TBodyHandler.ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
begin
  if FBody <> '' then
    AW.Write(FBody[1], Length(FBody));
  AW.WriteHeader(FStatus);
end;

{ Tests }

procedure TestHandlerFuncWraps;
var
  LHandler: IHttpHandler;
  LReq: IHttpRequest;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
begin
  ResetLog;
  LHandler := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    GLog := GLog + 'handler;';
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LReq := TMockRequest.Create(hmGet, '/test');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LHandler.ServeHTTP(LReq, LW);
  CheckEqual('handler;', GLog, 'handler executed');
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status), 'status 200');
end;

procedure TestSingleMiddleware;
var
  LChainIntf: IHttpHandler;
  LChain: TMiddlewareChain;
  LReq: IHttpRequest;
  LW: IHttpResponseWriter;
begin
  ResetLog;
  LChain := TMiddlewareChain.Create(TTagHandler.Create('handler;', 0));
  LChain.Use(TTagMiddleware.Create('mw1'));
  LChainIntf := LChain;
  LReq := TMockRequest.Create(hmGet, '/');
  LW := TMockResponseWriter.Create;
  LChainIntf.ServeHTTP(LReq, LW);
  CheckEqual('mw1>handler;<mw1;', GLog, 'single middleware wraps');
end;

procedure TestMultipleMiddlewaresOrder;
var
  LChainIntf: IHttpHandler;
  LChain: TMiddlewareChain;
  LReq: IHttpRequest;
  LW: IHttpResponseWriter;
begin
  ResetLog;
  LChain := TMiddlewareChain.Create(TTagHandler.Create('core;', 0));
  LChain.Use(TTagMiddleware.Create('A'));
  LChain.Use(TTagMiddleware.Create('B'));
  LChain.Use(TTagMiddleware.Create('C'));
  LChainIntf := LChain;
  LReq := TMockRequest.Create(hmGet, '/');
  LW := TMockResponseWriter.Create;
  LChainIntf.ServeHTTP(LReq, LW);
  CheckEqual('A>B>C>core;<C;<B;<A;', GLog, 'execution order outer-first');
end;

procedure TestChainConvenience;
var
  LResult: IHttpHandler;
  LReq: IHttpRequest;
  LW: IHttpResponseWriter;
begin
  ResetLog;
  LResult := Chain(
    TTagHandler.Create('handler;', 0),
    [IHttpMiddleware(TTagMiddleware.Create('1')),
     IHttpMiddleware(TTagMiddleware.Create('2'))]
  );
  LReq := TMockRequest.Create(hmGet, '/');
  LW := TMockResponseWriter.Create;
  LResult.ServeHTTP(LReq, LW);
  CheckEqual('1>2>handler;<2;<1;', GLog, 'Chain convenience works');
end;

procedure TestMiddlewareFuncWraps;
var
  LMw: IHttpMiddleware;
  LInner, LWrapped: IHttpHandler;
  LReq: IHttpRequest;
  LW: IHttpResponseWriter;
begin
  ResetLog;
  LMw := TTagMiddleware.Create('wrap');
  LInner := TTagHandler.Create('inner;', 0);
  LWrapped := LMw.Wrap(LInner);
  LReq := TMockRequest.Create(hmGet, '/');
  LW := TMockResponseWriter.Create;
  LWrapped.ServeHTTP(LReq, LW);
  CheckEqual('wrap>inner;<wrap;', GLog, 'Wrap creates wrapping handler');
end;

procedure TestMiddlewareModifiesResponse;
var
  LResult: IHttpHandler;
  LReq: IHttpRequest;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
begin
  LResult := Chain(
    TTagHandler.Create('', HTTP_STATUS_OK),
    [IHttpMiddleware(THeaderMiddleware.Create('X-Custom', 'added'))]
  );
  LReq := TMockRequest.Create(hmGet, '/');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult.ServeHTTP(LReq, LW);
  CheckEqual('added', LWObj.GetHeaders.Get('X-Custom'), 'middleware added header');
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status), 'status passed through');
end;

procedure TestMiddlewareShortCircuit;
var
  LResult: IHttpHandler;
  LReq: IHttpRequest;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
begin
  ResetLog;
  LResult := Chain(
    TTagHandler.Create('handler;', HTTP_STATUS_OK),
    [IHttpMiddleware(TBlockMiddleware.Create('blocked;', HTTP_STATUS_FORBIDDEN))]
  );
  LReq := TMockRequest.Create(hmGet, '/admin');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult.ServeHTTP(LReq, LW);
  CheckEqual('blocked;', GLog, 'handler not called');
  CheckEqual(Int64(HTTP_STATUS_FORBIDDEN), Int64(LWObj.Status), 'short-circuit status');
end;

procedure TestEmptyChainPassthrough;
var
  LResult: IHttpHandler;
  LReq: IHttpRequest;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
begin
  ResetLog;
  LResult := Chain(TTagHandler.Create('direct;', HTTP_STATUS_OK), []);
  LReq := TMockRequest.Create(hmGet, '/');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult.ServeHTTP(LReq, LW);
  CheckEqual('direct;', GLog, 'no middlewares, handler called directly');
  CheckEqual(Int64(HTTP_STATUS_OK), Int64(LWObj.Status), 'status OK');
end;

procedure TestMiddlewareWritesBody;
var
  LResult: IHttpHandler;
  LReq: IHttpRequest;
  LWObj: TMockResponseWriter;
  LW: IHttpResponseWriter;
begin
  LResult := Chain(
    TBodyHandler.Create('hello', HTTP_STATUS_OK),
    [IHttpMiddleware(TPrefixMiddleware.Create('[wrapped]'))]
  );
  LReq := TMockRequest.Create(hmGet, '/');
  LWObj := TMockResponseWriter.Create;
  LW := LWObj;
  LResult.ServeHTTP(LReq, LW);
  CheckEqual('[wrapped]hello', LWObj.Body, 'body composed from middleware + handler');
end;

var
  T: TTestRunner;
begin
  T := TTestRunner.Create('nextpas.core.http.middleware');
  T.Run('HandlerFunc wraps function', @TestHandlerFuncWraps);
  T.Run('Single middleware wraps handler', @TestSingleMiddleware);
  T.Run('Multiple middlewares execute in order', @TestMultipleMiddlewaresOrder);
  T.Run('Chain convenience function', @TestChainConvenience);
  T.Run('MiddlewareFunc wraps function', @TestMiddlewareFuncWraps);
  T.Run('Middleware modifies response', @TestMiddlewareModifiesResponse);
  T.Run('Middleware short-circuits', @TestMiddlewareShortCircuit);
  T.Run('Empty chain passthrough', @TestEmptyChainPassthrough);
  T.Run('Middleware writes body', @TestMiddlewareWritesBody);
  T.Summary;
end.
