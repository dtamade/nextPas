program test_http_message;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.net.base,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.message;

var
  T: TTestRunner;

procedure TestNewRequestMethodAndUrl;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse('http://example.com/api/users');
  LReq := NewRequest(hmPost, LUrl);
  CheckEqual(Int64(Ord(hmPost)), Int64(Ord(LReq.Method)), 'method is POST');
  CheckEqual('/api/users', LReq.Url.Path, 'url path');
  CheckEqual('example.com', LReq.Url.Host, 'url host');
end;

procedure TestRequestHeadersAccessible;
var
  LReq: IHttpRequest;
  LUrl: TUrl;
begin
  LUrl := Default(TUrl);
  LUrl.Path := '/test';
  LReq := NewRequest(hmGet, LUrl);
  LReq.Headers.Set_('Content-Type', 'application/json');
  CheckEqual('application/json', LReq.Headers.Get('Content-Type'), 'header set/get');
end;

procedure TestRequestBodyNilIsOk;
var
  LReq: IHttpRequest;
begin
  LReq := NewGetRequest('/no-body');
  Check(LReq.Body = nil, 'body is nil');
  CheckEqual(Int64(0), LReq.ContentLength, 'content-length is 0');
end;

procedure TestPathParamSetAndGet;
var
  LReq: IHttpRequest;
  LObj: THttpRequest;
begin
  LReq := NewGetRequest('/users/:id');
  LObj := THttpRequest(LReq as TObject);
  LObj.SetPathParam('id', '42');
  CheckEqual('42', LReq.PathParam('id'), 'path param id');
end;

procedure TestPathParamNotFoundReturnsEmpty;
var
  LReq: IHttpRequest;
begin
  LReq := NewGetRequest('/test');
  CheckEqual('', LReq.PathParam('missing'), 'missing param is empty');
end;

procedure TestRemoteAddrDefaultAndSet;
var
  LReq: IHttpRequest;
  LObj: THttpRequest;
begin
  LReq := NewGetRequest('/remote');
  CheckEqual('', LReq.RemoteAddr, 'default remote addr is empty');
  LObj := THttpRequest(LReq as TObject);
  LObj.SetRemoteAddr('127.0.0.1:54321');
  CheckEqual('127.0.0.1:54321', LReq.RemoteAddr, 'remote addr is stored');
end;

procedure TestRemoteAddrFromNetAddress;
var
  LReq: IHttpRequest;
  LObj: THttpRequest;
begin
  LReq := NewGetRequest('/remote');
  LObj := THttpRequest(LReq as TObject);
  LObj.SetRemoteNetAddr(TNetAddress.Loopback(65000));
  CheckEqual('127.0.0.1:65000', LReq.RemoteAddr, 'remote addr is rendered from net addr');
end;

procedure TestNewGetRequestConvenience;
var
  LReq: IHttpRequest;
begin
  LReq := NewGetRequest('/health');
  CheckEqual(Int64(Ord(hmGet)), Int64(Ord(LReq.Method)), 'method is GET');
  CheckEqual('/health', LReq.Url.Path, 'path is /health');
  CheckEqual('', LReq.Url.Host, 'host is empty');
end;

procedure TestNewResponseCreatesWithStatus;
var
  LResp: IHttpResponse;
  LH: IHttpHeaders;
begin
  LH := NewHttpHeaders;
  LResp := NewResponse(HTTP_STATUS_NOT_FOUND, LH, nil);
  CheckEqual(Int64(404), Int64(LResp.StatusCode), 'status 404');
end;

procedure TestResponseHeadersAccessible;
var
  LResp: IHttpResponse;
  LH: IHttpHeaders;
begin
  LH := NewHttpHeaders;
  LH.Set_('X-Custom', 'hello');
  LResp := NewResponse(HTTP_STATUS_OK, LH, nil);
  CheckEqual('hello', LResp.Headers.Get('X-Custom'), 'response header');
end;

procedure TestResponseBodyAccessible;
var
  LResp: IHttpResponse;
  LH: IHttpHeaders;
  LBody: IStream;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
  LData: TBytes;
begin
  LData := nil;
  SetLength(LData, 5);
  LData[0] := Ord('h');
  LData[1] := Ord('e');
  LData[2] := Ord('l');
  LData[3] := Ord('l');
  LData[4] := Ord('o');
  LBody := CreateBytesStreamFrom(LData);
  LH := NewHttpHeaders;
  LResp := NewResponse(HTTP_STATUS_OK, LH, LBody);
  Check(LResp.Body <> nil, 'body not nil');
  LN := LResp.Body.Read(LBuf, 5);
  CheckEqual(Int64(5), Int64(LN), 'read 5 bytes');
  Check(LBuf[0] = Ord('h'), 'first byte is h');
end;

procedure TestRequestVersionDefaultsHttp11;
var
  LReq: IHttpRequest;
begin
  LReq := NewGetRequest('/version-check');
  CheckEqual(Int64(Ord(hvHttp11)), Int64(Ord(LReq.Version)), 'version is HTTP/1.1');
end;

procedure TestMultiplePathParams;
var
  LReq: IHttpRequest;
  LObj: THttpRequest;
begin
  LReq := NewGetRequest('/users/:uid/posts/:pid');
  LObj := THttpRequest(LReq as TObject);
  LObj.SetPathParam('uid', '7');
  LObj.SetPathParam('pid', '99');
  CheckEqual('7', LReq.PathParam('uid'), 'uid param');
  CheckEqual('99', LReq.PathParam('pid'), 'pid param');
end;

procedure TestRequestContentLengthStored;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
  LH: IHttpHeaders;
begin
  LUrl := Default(TUrl);
  LUrl.Path := '/upload';
  LH := NewHttpHeaders;
  LReq := THttpRequest.Create(hmPost, LUrl, hvHttp11, LH, nil, 1024);
  CheckEqual(Int64(1024), LReq.ContentLength, 'content-length 1024');
end;

procedure TestRequestFromRequestTargetParsesOnDemand;
var
  LReq: IHttpRequest;
  LH: IHttpHeaders;
begin
  LH := NewHttpHeaders;
  LReq := THttpRequest.CreateFromRequestTarget(hmGet,
    '/api/v1/users?page=2&filter=active#top', hvHttp11, LH, nil, 0);

  CheckEqual('/api/v1/users', LReq.Url.Path, 'lazy request-target path');
  CheckEqual('page=2&filter=active', LReq.Url.RawQuery,
    'lazy request-target raw query');
  CheckEqual('top', LReq.Url.Fragment, 'lazy request-target fragment');
  CheckEqual('active', LReq.QueryParam('filter'), 'lazy query param');
end;

procedure TestRequestDirectPathAndRawQueryAccessors;
var
  LReq: IHttpRequest;
  LH: IHttpHeaders;
begin
  LH := NewHttpHeaders;
  LReq := THttpRequest.CreateFromRequestTarget(hmGet,
    '/api/v1/users?page=2&filter=active#top', hvHttp11, LH, nil, 0);

  CheckEqual('/api/v1/users', LReq.Path, 'direct request path');
  CheckEqual('page=2&filter=active', LReq.RawQuery,
    'direct request raw query');
  CheckEqual('/api/v1/users', LReq.Url.Path,
    'direct path accessor preserves Url materialization');
  CheckEqual('active', LReq.QueryParam('filter'),
    'direct raw query accessor preserves QueryParam');
end;

procedure TestRequestDirectPathAccessorsPreserveAbsoluteTarget;
var
  LReq: IHttpRequest;
  LH: IHttpHeaders;
begin
  LH := NewHttpHeaders;
  LReq := THttpRequest.CreateFromRequestTarget(hmGet,
    'http://example.com:8080/api/v1/users?page=2#top', hvHttp11, LH, nil, 0);

  CheckEqual('/api/v1/users', LReq.Path,
    'absolute request-target direct path');
  CheckEqual('page=2', LReq.RawQuery,
    'absolute request-target direct raw query');
  CheckEqual('example.com', LReq.Url.Host,
    'absolute request-target Url host remains available');
  CheckEqual(Int64(8080), Int64(LReq.Url.Port),
    'absolute request-target Url port remains available');
  CheckEqual('top', LReq.Url.Fragment,
    'absolute request-target Url fragment remains available');
end;

procedure CheckDirectRequestTarget(const ATarget, AExpectedPath,
  AExpectedRawQuery, AExpectedFragment: string);
var
  LReq: IHttpRequest;
  LH: IHttpHeaders;
begin
  LH := NewHttpHeaders;
  LReq := THttpRequest.CreateFromRequestTarget(hmGet, ATarget, hvHttp11, LH,
    nil, 0);

  CheckEqual(AExpectedPath, LReq.Path, ATarget + ' direct path');
  CheckEqual(AExpectedRawQuery, LReq.RawQuery, ATarget + ' direct raw query');
  CheckEqual(AExpectedPath, LReq.Url.Path, ATarget + ' Url path');
  CheckEqual(AExpectedRawQuery, LReq.Url.RawQuery, ATarget + ' Url raw query');
  CheckEqual(AExpectedFragment, LReq.Url.Fragment, ATarget + ' Url fragment');
end;

procedure TestRequestDirectPathAccessorTargetForms;
begin
  CheckDirectRequestTarget('/api/v1', '/api/v1', '', '');
  CheckDirectRequestTarget('/api/v1?', '/api/v1', '', '');
  CheckDirectRequestTarget('/?q=1', '/', 'q=1', '');
  CheckDirectRequestTarget('/p?q#f', '/p', 'q', 'f');
  CheckDirectRequestTarget('/p#f?q', '/p', '', 'f?q');
  CheckDirectRequestTarget('*', '*', '', '');
  CheckDirectRequestTarget('*?q=1#f', '*', 'q=1', 'f');
  CheckDirectRequestTarget('example.com:443', 'example.com:443', '', '');
  CheckDirectRequestTarget('relative/path?q=1#f', 'relative/path', 'q=1',
    'f');
end;

procedure TestRequestDirectPathAccessorInvalidAbsoluteTargetRaises;
var
  LReq: IHttpRequest;
  LH: IHttpHeaders;
  LRaised: Boolean;
begin
  LH := NewHttpHeaders;
  LReq := THttpRequest.CreateFromRequestTarget(hmGet,
    'http://example.com:70000/path', hvHttp11, LH, nil, 0);

  LRaised := False;
  try
    LReq.Path;
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, 'invalid absolute request-target direct path raises EHttpError');
end;

begin
  T := TTestRunner.Create('nextpas.core.http.message');
  T.Run('NewRequest creates with correct method/url', @TestNewRequestMethodAndUrl);
  T.Run('Request headers accessible', @TestRequestHeadersAccessible);
  T.Run('Request body nil is ok', @TestRequestBodyNilIsOk);
  T.Run('PathParam set and get', @TestPathParamSetAndGet);
  T.Run('PathParam not found returns empty', @TestPathParamNotFoundReturnsEmpty);
  T.Run('RemoteAddr default and set', @TestRemoteAddrDefaultAndSet);
  T.Run('RemoteAddr from TNetAddress', @TestRemoteAddrFromNetAddress);
  T.Run('NewGetRequest convenience', @TestNewGetRequestConvenience);
  T.Run('NewResponse creates with status', @TestNewResponseCreatesWithStatus);
  T.Run('Response headers accessible', @TestResponseHeadersAccessible);
  T.Run('Response body accessible', @TestResponseBodyAccessible);
  T.Run('Request version defaults to HTTP/1.1', @TestRequestVersionDefaultsHttp11);
  T.Run('Multiple path params', @TestMultiplePathParams);
  T.Run('Request content-length stored', @TestRequestContentLengthStored);
  T.Run('Request from request-target parses URL on demand',
    @TestRequestFromRequestTargetParsesOnDemand);
  T.Run('Request direct path/raw-query accessors',
    @TestRequestDirectPathAndRawQueryAccessors);
  T.Run('Request direct path/raw-query absolute target',
    @TestRequestDirectPathAccessorsPreserveAbsoluteTarget);
  T.Run('Request direct path/raw-query target forms',
    @TestRequestDirectPathAccessorTargetForms);
  T.Run('Request direct path/raw-query invalid absolute target raises',
    @TestRequestDirectPathAccessorInvalidAbsoluteTargetRaises);
  T.Summary;
end.
