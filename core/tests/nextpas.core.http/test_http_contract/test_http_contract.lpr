program test_http_contract;
{**
 * @desc Facade and public contract tests.
 *       Proves the public HTTP surface can be consumed through exported contracts.
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.http,
  nextpas.core.http.base,
  nextpas.core.http.middleware,
  nextpas.core.http.server,
  nextpas.core.http.client;

var
  T: TTestRunner;

type
  TMockHttpTransport = class(TInterfacedObject, IHttpTransport)
  private
    FRoundTripCalled: Boolean;
    FSeenMethod: THttpMethod;
    FSeenPath: string;
  public
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
    property RoundTripCalled: Boolean read FRoundTripCalled;
    property SeenMethod: THttpMethod read FSeenMethod;
    property SeenPath: string read FSeenPath;
  end;

  TMockServerTransport = class(TInterfacedObject, IHttpServerTransport)
  private
    FServeConnCalled: Boolean;
  public
    procedure ServeConn(const AConn: ITcpStream; const AHandler: IHttpHandler);
    property ServeConnCalled: Boolean read FServeConnCalled;
  end;

{ TMockHttpTransport }

function TMockHttpTransport.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
var
  LHeaders: IHttpHeaders;
begin
  FRoundTripCalled := True;
  FSeenMethod := AReq.Method;
  FSeenPath := AReq.Url.Path;
  LHeaders := NewHeaders;
  LHeaders.Set_('x-transport', 'mock');
  Result := NewResponse(HTTP_STATUS_CREATED, LHeaders, nil);
end;

{ TMockServerTransport }

procedure TMockServerTransport.ServeConn(const AConn: ITcpStream; const AHandler: IHttpHandler);
begin
  FServeConnCalled := True;
  if AHandler <> nil then
    AHandler.ServeHTTP(NewRequest(hmGet, TUrl.Parse('/transport')), nil);
end;

{ Test 1: NewHeaders — Set/Get/Has/Del/Count/Clone }
procedure TestNewHeaders;
var
  LH, LClone: IHttpHeaders;
begin
  LH := NewHeaders;
  Check(LH <> nil, 'NewHeaders returns non-nil');
  LH.Set_('x-foo', 'bar');
  CheckEqual('bar', LH.Get('x-foo'), 'Get after Set');
  Check(LH.Has('x-foo'), 'Has returns true');
  Check(not LH.Has('x-missing'), 'Has returns false for missing');
  CheckEqual(Int64(1), Int64(LH.Count), 'Count = 1');
  LH.Set_('x-baz', 'qux');
  CheckEqual(Int64(2), Int64(LH.Count), 'Count = 2');
  LClone := LH.Clone;
  CheckEqual('bar', LClone.Get('x-foo'), 'Clone preserves values');
  LH.Del('x-foo');
  Check(not LH.Has('x-foo'), 'Del removes header');
  CheckEqual(Int64(1), Int64(LH.Count), 'Count after Del');
  { Clone is independent }
  CheckEqual('bar', LClone.Get('x-foo'), 'Clone independent after Del');
end;

{ Test 2: NewRouter — Get route + FindRoute }
procedure TestNewRouter;
var
  LRouter: IHttpRouter;
  LCalled: Boolean;
begin
  LCalled := False;
  LRouter := NewRouter;
  Check(LRouter <> nil, 'NewRouter returns non-nil');
  LRouter.Handle(hmGet, '/test', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LCalled := True;
  end);
  { Verify via ServeHTTP with a mock request }
  LRouter.ServeHTTP(NewRequest(hmGet, TUrl.Parse('/test')), nil);
  Check(LCalled, 'Router dispatches handler');
end;

{ Test 3: NewRequest — Method/Url/Version accessible }
procedure TestNewRequest;
var
  LReq: IHttpRequest;
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('http://example.com/path?q=1');
  LReq := NewRequest(hmPost, LUrl);
  Check(LReq <> nil, 'NewRequest returns non-nil');
  Check(LReq.Method = hmPost, 'Method = POST');
  CheckEqual('/path', LReq.Url.Path, 'Url.Path');
  CheckEqual('q=1', LReq.Url.RawQuery, 'Url.RawQuery');
  Check(LReq.Version = hvHttp11, 'Version = HTTP/1.1');
end;

{ Test 4: NewResponse — StatusCode/Headers accessible }
procedure TestNewResponse;
var
  LResp: IHttpResponse;
  LH: IHttpHeaders;
begin
  LH := NewHeaders;
  LH.Set_('x-test', 'val');
  LResp := NewResponse(HTTP_STATUS_CREATED, LH, nil);
  Check(LResp <> nil, 'NewResponse returns non-nil');
  CheckEqual(Int64(201), Int64(LResp.StatusCode), 'StatusCode = 201');
  CheckEqual('val', LResp.Headers.Get('x-test'), 'Headers accessible');
  Check(LResp.Body = nil, 'Body is nil');
end;

{ Test 5: HandlerFunc wraps correctly }
procedure TestHandlerFuncWrap;
var
  LHandler: IHttpHandler;
  LCalled: Boolean;
begin
  LCalled := False;
  LHandler := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LCalled := True;
  end);
  Check(LHandler <> nil, 'HandlerFunc returns non-nil');
  LHandler.ServeHTTP(nil, nil);
  Check(LCalled, 'HandlerFunc handler was called');
end;

{ Test 6: Chain applies middleware }
procedure TestChainMiddleware;
var
  LHandler: IHttpHandler;
  LOrder: string;
  LMw: IHttpMiddleware;
begin
  LOrder := '';
  LHandler := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LOrder := LOrder + 'H';
  end);
  LMw := nextpas.core.http.middleware.MiddlewareFunc(function(const ANext: IHttpHandler): IHttpHandler
  begin
    Result := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
    begin
      LOrder := LOrder + 'M';
      ANext.ServeHTTP(AReq, AW);
    end);
  end);
  LHandler := Chain(LHandler, [LMw]);
  LHandler.ServeHTTP(nil, nil);
  CheckEqual('MH', LOrder, 'Chain: middleware then handler');
end;

{ Test 7: UrlEncode/UrlDecode round-trip }
procedure TestUrlEncodeDecodeRoundTrip;
var
  LOriginal, LEncoded, LDecoded: string;
begin
  LOriginal := 'hello world&foo=bar/baz';
  LEncoded := UrlEncode(LOriginal);
  Check(Pos(' ', LEncoded) = 0, 'Encoded has no spaces');
  Check(Pos('&', LEncoded) = 0, 'Encoded has no &');
  LDecoded := UrlDecode(LEncoded);
  CheckEqual(LOriginal, LDecoded, 'Round-trip preserves value');
end;

{ Test 8: ParseQueryString basic }
procedure TestParseQueryString;
var
  LParams: TQueryParams;
begin
  LParams := ParseQueryString('a=1&b=hello&c=');
  Check(Length(LParams) = 3, 'ParseQueryString: 3 params');
  CheckEqual('a', LParams[0].Name, 'param 0 name');
  CheckEqual('1', LParams[0].Value, 'param 0 value');
  CheckEqual('b', LParams[1].Name, 'param 1 name');
  CheckEqual('hello', LParams[1].Value, 'param 1 value');
  CheckEqual('c', LParams[2].Name, 'param 2 name');
  CheckEqual('', LParams[2].Value, 'param 2 value empty');
end;

{ Test 9: EncodeQueryString round-trip }
procedure TestEncodeQueryStringRoundTrip;
var
  LParams, LParsed: TQueryParams;
  LEncoded: string;
begin
  SetLength(LParams, 2);
  LParams[0].Name := 'key';
  LParams[0].Value := 'val ue';
  LParams[1].Name := 'x';
  LParams[1].Value := 'y&z';
  LEncoded := EncodeQueryString(LParams);
  LParsed := ParseQueryString(LEncoded);
  Check(Length(LParsed) = 2, 'round-trip: 2 params');
  CheckEqual('key', LParsed[0].Name, 'round-trip: name 0');
  CheckEqual('val ue', LParsed[0].Value, 'round-trip: value 0');
  CheckEqual('x', LParsed[1].Name, 'round-trip: name 1');
  CheckEqual('y&z', LParsed[1].Value, 'round-trip: value 1');
end;

{ Test 10: HttpMethodToStr all methods }
procedure TestHttpMethodToStr;
begin
  CheckEqual('GET', HttpMethodToStr(hmGet), 'GET');
  CheckEqual('HEAD', HttpMethodToStr(hmHead), 'HEAD');
  CheckEqual('POST', HttpMethodToStr(hmPost), 'POST');
  CheckEqual('PUT', HttpMethodToStr(hmPut), 'PUT');
  CheckEqual('DELETE', HttpMethodToStr(hmDelete), 'DELETE');
  CheckEqual('PATCH', HttpMethodToStr(hmPatch), 'PATCH');
  CheckEqual('OPTIONS', HttpMethodToStr(hmOptions), 'OPTIONS');
  CheckEqual('CONNECT', HttpMethodToStr(hmConnect), 'CONNECT');
  CheckEqual('TRACE', HttpMethodToStr(hmTrace), 'TRACE');
end;

{ Test 11: HttpStrToMethod all methods }
procedure TestHttpStrToMethod;
begin
  Check(HttpStrToMethod('GET') = hmGet, 'GET');
  Check(HttpStrToMethod('HEAD') = hmHead, 'HEAD');
  Check(HttpStrToMethod('POST') = hmPost, 'POST');
  Check(HttpStrToMethod('PUT') = hmPut, 'PUT');
  Check(HttpStrToMethod('DELETE') = hmDelete, 'DELETE');
  Check(HttpStrToMethod('PATCH') = hmPatch, 'PATCH');
  Check(HttpStrToMethod('OPTIONS') = hmOptions, 'OPTIONS');
  Check(HttpStrToMethod('CONNECT') = hmConnect, 'CONNECT');
  Check(HttpStrToMethod('TRACE') = hmTrace, 'TRACE');
end;

{ Test 12: HttpStatusText known codes }
procedure TestHttpStatusText;
begin
  CheckEqual('OK', HttpStatusText(HTTP_STATUS_OK), '200');
  CheckEqual('Created', HttpStatusText(HTTP_STATUS_CREATED), '201');
  CheckEqual('Not Found', HttpStatusText(HTTP_STATUS_NOT_FOUND), '404');
  CheckEqual('Internal Server Error', HttpStatusText(HTTP_STATUS_INTERNAL_SERVER_ERROR), '500');
  CheckEqual('Method Not Allowed', HttpStatusText(HTTP_STATUS_METHOD_NOT_ALLOWED), '405');
  CheckEqual('Bad Request', HttpStatusText(HTTP_STATUS_BAD_REQUEST), '400');
end;

{ Test 13: IHttpTransport public contract shape }
procedure TestHttpTransportRoundTripContract;
var
  LObj: TMockHttpTransport;
  LTransport: IHttpTransport;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
begin
  LObj := TMockHttpTransport.Create;
  LTransport := LObj;
  LReq := NewRequest(hmPost, TUrl.Parse('/transport?x=1'));
  LResp := LTransport.RoundTrip(LReq);
  Check(LObj.RoundTripCalled, 'RoundTrip was called');
  Check(LObj.SeenMethod = hmPost, 'RoundTrip receives request method');
  CheckEqual('/transport', LObj.SeenPath, 'RoundTrip receives request path');
  CheckEqual(Int64(201), Int64(LResp.StatusCode), 'RoundTrip returns response');
  CheckEqual('mock', LResp.Headers.Get('x-transport'), 'RoundTrip response headers');
end;

{ Test 14: IHttpServerTransport public contract shape }
procedure TestHttpServerTransportServeConnContract;
var
  LObj: TMockServerTransport;
  LTransport: IHttpServerTransport;
  LHandler: IHttpHandler;
  LHandlerCalled: Boolean;
begin
  LObj := TMockServerTransport.Create;
  LTransport := LObj;
  LHandlerCalled := False;
  LHandler := HandlerFunc(procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LHandlerCalled := True;
    Check(AReq.Method = hmGet, 'ServeConn passes request method');
    CheckEqual('/transport', AReq.Url.Path, 'ServeConn passes request path');
  end);
  LTransport.ServeConn(nil, LHandler);
  Check(LObj.ServeConnCalled, 'ServeConn was called');
  Check(LHandlerCalled, 'ServeConn can dispatch handler');
end;

{ Test 15: IHttpHijacker is exported by facade }
procedure TestHttpHijackerFacadeAlias;
var
  LHijacker: IHttpHijacker;
begin
  LHijacker := nil;
  Check(LHijacker = nil, 'IHttpHijacker type is available through facade');
end;

begin
  T := TTestRunner.Create('nextpas.core.http.contract');
  T.Run('NewHeaders: Set/Get/Has/Del/Count/Clone', @TestNewHeaders);
  T.Run('NewRouter: Get route + FindRoute', @TestNewRouter);
  T.Run('NewRequest: Method/Url/Version', @TestNewRequest);
  T.Run('NewResponse: StatusCode/Headers', @TestNewResponse);
  T.Run('HandlerFunc wraps correctly', @TestHandlerFuncWrap);
  T.Run('Chain applies middleware', @TestChainMiddleware);
  T.Run('UrlEncode/UrlDecode round-trip', @TestUrlEncodeDecodeRoundTrip);
  T.Run('ParseQueryString basic', @TestParseQueryString);
  T.Run('EncodeQueryString round-trip', @TestEncodeQueryStringRoundTrip);
  T.Run('HttpMethodToStr all methods', @TestHttpMethodToStr);
  T.Run('HttpStrToMethod all methods', @TestHttpStrToMethod);
  T.Run('HttpStatusText known codes', @TestHttpStatusText);
  T.Run('IHttpTransport RoundTrip contract shape', @TestHttpTransportRoundTripContract);
  T.Run('IHttpServerTransport ServeConn contract shape', @TestHttpServerTransportServeConnContract);
  T.Run('IHttpHijacker facade alias', @TestHttpHijackerFacadeAlias);
  T.Summary;
end.
