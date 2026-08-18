program test_http_message;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.test,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.net.base,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http,
  nextpas.core.http.message,
  nextpas.core.json;

type
  TMockResponseWriter = class(TInterfacedObject, IHttpResponseWriter)
  private
    FHeaders: IHttpHeaders;
    FStatus: THttpStatus;
    FBody: string;
    FBodyBytes: TBytes;
    FStatusWritten: Boolean;
  public
    constructor Create;
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    property Status: THttpStatus read FStatus;
    property Body: string read FBody;
    property BodyBytes: TBytes read FBodyBytes;
    property StatusWritten: Boolean read FStatusWritten;
  end;

var
  T: TTestSuite;

function ReadBodyStr(const AReader: IReader): string;
var
  LBuf: array[0..255] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  if AReader = nil then
    Exit;
  repeat
    LN := AReader.Read(LBuf[0], SizeUInt(Length(LBuf)));
    if LN > 0 then
    begin
      SetLength(Result, Length(Result) + Int32(LN));
      Move(LBuf[0], Result[Length(Result) - Int32(LN) + 1], LN);
    end;
  until LN = 0;
end;

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

procedure TestNewRequestParsesStringUrl;
var
  LReq: IHttpRequest;
begin
  LReq := NewRequest(hmGet, 'http://example.com:8080/api/users?page=1');
  CheckEqual(Int64(Ord(hmGet)), Int64(Ord(LReq.Method)),
    'string URL request helper method');
  CheckEqual('example.com', LReq.Url.Host, 'string URL request helper host');
  CheckEqual(Int64(8080), Int64(LReq.Url.Port),
    'string URL request helper port');
  CheckEqual('/api/users', LReq.Path, 'string URL request helper path');
  CheckEqual('page=1', LReq.RawQuery,
    'string URL request helper query');
end;

procedure TestNewRequestWithHeadersBodyAndContentLength;
var
  LUrl: TUrl;
  LHeaders: IHttpHeaders;
  LBody: IStream;
  LReq: IHttpRequest;
  LData: TBytes;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
begin
  LUrl := TUrl.Parse('http://example.com/api/users');
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('x-custom', 'client');
  LData := nil;
  SetLength(LData, 11);
  Move('hello-world'[1], LData[0], 11);
  LBody := CreateBytesStreamFrom(LData);

  LReq := THttpRequestBuilder.Create(hmPost, LUrl.ToString).Headers(LHeaders).Body(LBody).ContentLength(11).Build;

  CheckEqual(Int64(Ord(hmPost)), Int64(Ord(LReq.Method)),
    'request helper method');
  CheckEqual('/api/users', LReq.Path, 'request helper path');
  CheckEqual('client', LReq.Headers.Get('x-custom'),
    'request helper preserves custom headers');
  CheckEqual('11', LReq.Headers.Get('content-length'),
    'request helper sets content-length');
  CheckEqual(Int64(11), LReq.ContentLength,
    'request helper stores content-length');
  LN := LReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
  CheckEqual(Int64(11), Int64(LN), 'request helper body length');
  CheckEqual(Byte(Ord('h')), LBuf[0], 'request helper body first byte');
end;

procedure TestNewRequestStringUrlWithHeadersBodyAndContentLength;
var
  LHeaders: IHttpHeaders;
  LBody: IStream;
  LReq: IHttpRequest;
  LData: TBytes;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('x-custom', 'client');
  LData := nil;
  SetLength(LData, 5);
  Move('hello'[1], LData[0], 5);
  LBody := CreateBytesStreamFrom(LData);

  LReq := THttpRequestBuilder.Create(hmPost, 'http://example.com/api/users').Headers(LHeaders).Body(LBody).ContentLength(5).Build;

  CheckEqual(Int64(Ord(hmPost)), Int64(Ord(LReq.Method)),
    'string URL request helper with body method');
  CheckEqual('/api/users', LReq.Path,
    'string URL request helper with body path');
  CheckEqual('client', LReq.Headers.Get('x-custom'),
    'string URL request helper preserves custom headers');
  CheckEqual('5', LReq.Headers.Get('content-length'),
    'string URL request helper sets content-length');
  CheckEqual(Int64(5), LReq.ContentLength,
    'string URL request helper stores content-length');
end;

procedure TestNewRequestWithHeadersWithoutBody;
var
  LUrl: TUrl;
  LHeaders: IHttpHeaders;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse('http://example.com/api/users');
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('x-client', 'header-only');

  LReq := THttpRequestBuilder.Create(hmGet, LUrl.ToString).Headers(LHeaders).Build;

  CheckEqual(Int64(Ord(hmGet)), Int64(Ord(LReq.Method)),
    'headers-only request helper method');
  CheckEqual('/api/users', LReq.Path, 'headers-only request helper path');
  CheckEqual('header-only', LReq.Headers.Get('x-client'),
    'headers-only request helper preserves custom headers');
  CheckEqual('', LReq.Headers.Get('content-length'),
    'headers-only request helper does not add content-length');
  CheckEqual(Int64(0), LReq.ContentLength,
    'headers-only request helper stores zero content-length');
  Check(LReq.Body = nil, 'headers-only request helper keeps body nil');
end;

procedure TestNewRequestStringUrlWithHeadersWithoutBody;
var
  LHeaders: IHttpHeaders;
  LReq: IHttpRequest;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('x-client', 'header-only-url');

  LReq := THttpRequestBuilder.Create(hmHead, 'http://example.com/ping?x=1').Headers(LHeaders).Build;

  CheckEqual(Int64(Ord(hmHead)), Int64(Ord(LReq.Method)),
    'string URL headers-only helper method');
  CheckEqual('/ping', LReq.Path, 'string URL headers-only helper path');
  CheckEqual('x=1', LReq.RawQuery, 'string URL headers-only helper query');
  CheckEqual('header-only-url', LReq.Headers.Get('x-client'),
    'string URL headers-only helper preserves custom headers');
  CheckEqual('', LReq.Headers.Get('content-length'),
    'string URL headers-only helper does not add content-length');
  CheckEqual(Int64(0), LReq.ContentLength,
    'string URL headers-only helper stores zero content-length');
  Check(LReq.Body = nil, 'string URL headers-only helper keeps body nil');
end;

procedure TestNewRequestNilThirdArgumentKeepsBytesHelper;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse('http://example.com/api/users');

  LReq := THttpRequestBuilder.Create(hmPost, LUrl.ToString).Body('').Build;

  CheckEqual(Int64(Ord(hmPost)), Int64(Ord(LReq.Method)),
    'nil third argument helper method');
  Check(LReq.Headers <> nil, 'nil third argument helper creates headers');
  CheckEqual('0', LReq.Headers.Get('content-length'),
    'nil third argument helper preserves bytes helper content-length');
  CheckEqual(Int64(0), LReq.ContentLength,
    'nil third argument helper stores zero content-length');
  Check(LReq.Body <> nil, 'nil third argument helper preserves bytes helper body');

  LReq := THttpRequestBuilder.Create(hmPut, 'http://example.com/upload?x=1').Body('').Build;

  CheckEqual(Int64(Ord(hmPut)), Int64(Ord(LReq.Method)),
    'string URL nil third argument helper method');
  CheckEqual('/upload', LReq.Path, 'string URL nil third argument helper path');
  CheckEqual('x=1', LReq.RawQuery,
    'string URL nil third argument helper query');
  CheckEqual('0', LReq.Headers.Get('content-length'),
    'string URL nil third argument helper preserves bytes helper content-length');
  CheckEqual(Int64(0), LReq.ContentLength,
    'string URL nil third argument helper stores zero content-length');
  Check(LReq.Body <> nil,
    'string URL nil third argument helper preserves bytes helper body');
end;

procedure TestNewRequestWithStringBody;
var
  LUrl: TUrl;
  LHeaders: IHttpHeaders;
  LReq: IHttpRequest;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
begin
  LUrl := TUrl.Parse('http://example.com/api/users');
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('x-client', 'string-body');

  LReq := THttpRequestBuilder.Create(hmPost, LUrl.ToString).Headers(LHeaders).Body('hello').Build;

  CheckEqual(Int64(Ord(hmPost)), Int64(Ord(LReq.Method)),
    'string body request helper method');
  CheckEqual('string-body', LReq.Headers.Get('x-client'),
    'string body request helper preserves custom headers');
  CheckEqual('5', LReq.Headers.Get('content-length'),
    'string body request helper sets content-length');
  CheckEqual(Int64(5), LReq.ContentLength,
    'string body request helper stores content-length');
  Check(LReq.Body <> nil, 'string body request helper creates body reader');
  LN := LReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
  CheckEqual(Int64(5), Int64(LN), 'string body request helper body length');
  CheckEqual(Byte(Ord('h')), LBuf[0], 'string body request helper first byte');
end;

procedure TestNewRequestWithBytesBody;
var
  LUrl: TUrl;
  LHeaders: IHttpHeaders;
  LReq: IHttpRequest;
  LBody: TBytes;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
begin
  LUrl := TUrl.Parse('http://example.com/upload');
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('x-client', 'bytes-body');
  SetLength(LBody, 5);
  LBody[0] := Ord('b');
  LBody[1] := Ord('i');
  LBody[2] := Ord('n');
  LBody[3] := 0;
  LBody[4] := 255;

  LReq := THttpRequestBuilder.Create(hmPost, LUrl.ToString).Headers(LHeaders).Body(LBody).Build;

  CheckEqual(Int64(Ord(hmPost)), Int64(Ord(LReq.Method)),
    'bytes body request helper method');
  CheckEqual('bytes-body', LReq.Headers.Get('x-client'),
    'bytes body request helper preserves custom headers');
  CheckEqual('5', LReq.Headers.Get('content-length'),
    'bytes body request helper sets content-length');
  CheckEqual(Int64(5), LReq.ContentLength,
    'bytes body request helper stores content-length');
  Check(LReq.Body <> nil, 'bytes body request helper creates body reader');
  LN := LReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
  CheckEqual(Int64(5), Int64(LN), 'bytes body request helper body length');
  CheckEqual(Byte(0), LBuf[3], 'bytes body request helper preserves zero byte');
  CheckEqual(Byte(255), LBuf[4], 'bytes body request helper preserves high byte');
end;

procedure TestNewRequestStringUrlWithBytesBody;
var
  LHeaders: IHttpHeaders;
  LReq: IHttpRequest;
  LBody: TBytes;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('x-client', 'bytes-url');
  SetLength(LBody, 2);
  LBody[0] := Ord('o');
  LBody[1] := Ord('k');

  LReq := THttpRequestBuilder.Create(hmPut, 'http://example.com/upload?x=1').Headers(LHeaders).Body(LBody).Build;

  CheckEqual(Int64(Ord(hmPut)), Int64(Ord(LReq.Method)),
    'string URL bytes body helper method');
  CheckEqual('/upload', LReq.Path, 'string URL bytes body helper path');
  CheckEqual('x=1', LReq.RawQuery, 'string URL bytes body helper query');
  CheckEqual('bytes-url', LReq.Headers.Get('x-client'),
    'string URL bytes body helper preserves custom headers');
  CheckEqual('2', LReq.Headers.Get('content-length'),
    'string URL bytes body helper sets content-length');
  CheckEqual(Int64(2), LReq.ContentLength,
    'string URL bytes body helper stores content-length');
end;

procedure TestNewRequestWithStringBodyWithoutHeaders;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
begin
  LUrl := TUrl.Parse('http://example.com/api/users');

  LReq := THttpRequestBuilder.Create(hmPost, LUrl.ToString).Body('hello').Build;

  CheckEqual(Int64(Ord(hmPost)), Int64(Ord(LReq.Method)),
    'string body without headers helper method');
  Check(LReq.Headers <> nil,
    'string body without headers helper creates headers');
  CheckEqual(Int64(1), Int64(LReq.Headers.Count),
    'string body without headers helper only adds content-length header');
  CheckEqual('5', LReq.Headers.Get('content-length'),
    'string body without headers helper sets content-length');
  CheckEqual(Int64(5), LReq.ContentLength,
    'string body without headers helper stores content-length');
  LN := LReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
  CheckEqual(Int64(5), Int64(LN),
    'string body without headers helper body length');
  CheckEqual(Byte(Ord('h')), LBuf[0],
    'string body without headers helper first byte');
end;

procedure TestNewRequestWithBytesBodyWithoutHeaders;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
  LBody: TBytes;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
begin
  LUrl := TUrl.Parse('http://example.com/upload');
  SetLength(LBody, 3);
  LBody[0] := Ord('b');
  LBody[1] := 0;
  LBody[2] := 255;

  LReq := THttpRequestBuilder.Create(hmPatch, LUrl.ToString).Body(LBody).ContentLength(0).Build;

  CheckEqual(Int64(Ord(hmPatch)), Int64(Ord(LReq.Method)),
    'bytes body without headers helper method');
  Check(LReq.Headers <> nil,
    'bytes body without headers helper creates headers');
  CheckEqual(Int64(1), Int64(LReq.Headers.Count),
    'bytes body without headers helper only adds content-length header');
  CheckEqual('3', LReq.Headers.Get('content-length'),
    'bytes body without headers helper sets content-length');
  CheckEqual(Int64(3), LReq.ContentLength,
    'bytes body without headers helper stores content-length');
  LN := LReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
  CheckEqual(Int64(3), Int64(LN),
    'bytes body without headers helper body length');
  CheckEqual(Byte(0), LBuf[1],
    'bytes body without headers helper preserves zero byte');
  CheckEqual(Byte(255), LBuf[2],
    'bytes body without headers helper preserves high byte');
end;

procedure TestNewRequestWithReaderBodyWithoutHeaders;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
  LBody: IStream;
  LData: TBytes;
begin
  LUrl := TUrl.Parse('http://example.com/upload');
  SetLength(LData, 4);
  Move('data'[1], LData[0], 4);
  LBody := CreateBytesStreamFrom(LData);

  LReq := THttpRequestBuilder.Create(hmPut, LUrl.ToString).Body(LBody).ContentLength(4).Build;

  CheckEqual(Int64(Ord(hmPut)), Int64(Ord(LReq.Method)),
    'reader body without headers helper method');
  Check(LReq.Headers <> nil,
    'reader body without headers helper creates headers');
  CheckEqual(Int64(1), Int64(LReq.Headers.Count),
    'reader body without headers helper only adds content-length header');
  CheckEqual('4', LReq.Headers.Get('content-length'),
    'reader body without headers helper sets content-length');
  CheckEqual(Int64(4), LReq.ContentLength,
    'reader body without headers helper stores content-length');
end;

procedure TestNewRequestWithStringBodyAndContentTypeWithoutHeaders;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
begin
  LUrl := TUrl.Parse('http://example.com/submit');

  LReq := THttpRequestBuilder.Create(hmPost, LUrl.ToString).ContentType('text/plain; charset=utf-8').Body('hello').Build;

  CheckEqual(Int64(Ord(hmPost)), Int64(Ord(LReq.Method)),
    'string body with content-type helper method');
  Check(LReq.Headers <> nil,
    'string body with content-type helper creates headers');
  CheckEqual(Int64(2), Int64(LReq.Headers.Count),
    'string body with content-type helper publishes content-length and content-type');
  CheckEqual('5', LReq.Headers.Get('content-length'),
    'string body with content-type helper sets content-length');
  CheckEqual('text/plain; charset=utf-8', LReq.Headers.Get('content-type'),
    'string body with content-type helper sets content-type');
  CheckEqual(Int64(5), LReq.ContentLength,
    'string body with content-type helper stores content-length');
  LN := LReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
  CheckEqual(Int64(5), Int64(LN),
    'string body with content-type helper body length');
  CheckEqual(Byte(Ord('h')), LBuf[0],
    'string body with content-type helper first byte');
end;

procedure TestNewRequestWithBytesBodyAndContentTypeWithoutHeaders;
var
  LReq: IHttpRequest;
  LBody: TBytes;
  LBuf: array[0..31] of Byte;
  LN: SizeUInt;
begin
  SetLength(LBody, 3);
  LBody[0] := Ord('b');
  LBody[1] := 0;
  LBody[2] := 255;

  LReq := THttpRequestBuilder.Create(hmPatch, 'http://example.com/upload').ContentType('application/octet-stream').Body(LBody).Build;

  CheckEqual(Int64(Ord(hmPatch)), Int64(Ord(LReq.Method)),
    'bytes body with content-type helper method');
  Check(LReq.Headers <> nil,
    'bytes body with content-type helper creates headers');
  CheckEqual(Int64(2), Int64(LReq.Headers.Count),
    'bytes body with content-type helper publishes content-length and content-type');
  CheckEqual('3', LReq.Headers.Get('content-length'),
    'bytes body with content-type helper sets content-length');
  CheckEqual('application/octet-stream', LReq.Headers.Get('content-type'),
    'bytes body with content-type helper sets content-type');
  CheckEqual(Int64(3), LReq.ContentLength,
    'bytes body with content-type helper stores content-length');
  LN := LReq.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
  CheckEqual(Int64(3), Int64(LN),
    'bytes body with content-type helper body length');
  CheckEqual(Byte(0), LBuf[1],
    'bytes body with content-type helper preserves zero byte');
  CheckEqual(Byte(255), LBuf[2],
    'bytes body with content-type helper preserves high byte');
end;

procedure TestNewRequestWithReaderBodyAndContentTypeWithoutHeaders;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
  LBody: IStream;
  LData: TBytes;
begin
  LUrl := TUrl.Parse('http://example.com/upload');
  SetLength(LData, 4);
  Move('data'[1], LData[0], 4);
  LBody := CreateBytesStreamFrom(LData);

  LReq := THttpRequestBuilder.Create(hmPut, LUrl.ToString).ContentType('application/custom').Body(LBody).ContentLength(4).Build;

  CheckEqual(Int64(Ord(hmPut)), Int64(Ord(LReq.Method)),
    'reader body with content-type helper method');
  Check(LReq.Headers <> nil,
    'reader body with content-type helper creates headers');
  CheckEqual(Int64(2), Int64(LReq.Headers.Count),
    'reader body with content-type helper publishes content-length and content-type');
  CheckEqual('4', LReq.Headers.Get('content-length'),
    'reader body with content-type helper sets content-length');
  CheckEqual('application/custom', LReq.Headers.Get('content-type'),
    'reader body with content-type helper sets content-type');
  CheckEqual(Int64(4), LReq.ContentLength,
    'reader body with content-type helper stores content-length');
end;

procedure TestNewRequestWithNilHeadersCreatesHeaders;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse('http://example.com/health');
  LReq := THttpRequestBuilder.Create(hmGet, LUrl.ToString).Build;

  Check(LReq.Headers <> nil, 'request helper creates headers when nil');
  CheckEqual(Int64(0), Int64(LReq.Headers.Count),
    'request helper nil headers start empty');
end;

procedure TestRequestConstructorsWithNilHeadersCreateHeaders;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
begin
  LUrl := Default(TUrl);
  LUrl.Path := '/direct';
  LReq := THttpRequest.Create(hmGet, LUrl, hvHttp11, nil, nil, 0);

  Check(LReq.Headers <> nil, 'direct request constructor creates headers when nil');
  if LReq.Headers <> nil then
    CheckEqual(Int64(0), Int64(LReq.Headers.Count),
      'direct request constructor nil headers start empty');

  LReq := THttpRequest.CreateFromRequestTarget(hmGet, '/target', hvHttp11,
    nil, nil, 0);
  Check(LReq.Headers <> nil,
    'request-target constructor creates headers when nil');
  if LReq.Headers <> nil then
    CheckEqual(Int64(0), Int64(LReq.Headers.Count),
      'request-target constructor nil headers start empty');
end;

procedure TestNewRequestRejectsNegativeContentLength;
var
  LUrl: TUrl;
  LRaised: Boolean;
begin
  LUrl := TUrl.Parse('http://example.com/upload');
  LRaised := False;
  try
    THttpRequestBuilder.Create(hmPost, LUrl.ToString).Headers(NewHttpHeaders).Body(IReader(nil)).ContentLength(-1).Build;
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, 'request helper rejects negative content-length');
end;

procedure TestNewRequestRejectsConflictingContentLengthHeader;
var
  LUrl: TUrl;
  LHeaders: IHttpHeaders;
  LRaised: Boolean;
begin
  LUrl := TUrl.Parse('http://example.com/upload');
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-length', '999');

  LRaised := False;
  try
    THttpRequestBuilder.Create(hmPost, LUrl.ToString).Headers(LHeaders).Body('hello').Build;
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised,
    'request helper rejects content-length header that conflicts with body length');
end;

procedure TestNewRequestAcceptsMatchingContentLengthHeader;
var
  LUrl: TUrl;
  LHeaders: IHttpHeaders;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse('http://example.com/upload');
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-length', '5');

  LReq := THttpRequestBuilder.Create(hmPost, LUrl.ToString).Headers(LHeaders).Body('hello').Build;

  CheckEqual('5', LReq.Headers.Get('content-length'),
    'request helper preserves matching content-length');
  CheckEqual(Int64(5), LReq.ContentLength,
    'request helper stores matching content-length');
end;

procedure TestNewRequestRejectsDuplicateContentLengthHeader;
var
  LUrl: TUrl;
  LHeaders: IHttpHeaders;
  LRaised: Boolean;
begin
  LUrl := TUrl.Parse('http://example.com/upload');
  LHeaders := NewHttpHeaders;
  LHeaders.Add('content-length', '5');
  LHeaders.Add('content-length', '5');

  LRaised := False;
  try
    THttpRequestBuilder.Create(hmPost, LUrl.ToString).Headers(LHeaders).Body('hello').Build;
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, 'request helper rejects duplicate content-length headers');
end;

procedure TestNewRequestRejectsInvalidContentLengthHeader;
var
  LUrl: TUrl;
  LHeaders: IHttpHeaders;
  LRaised: Boolean;
begin
  LUrl := TUrl.Parse('http://example.com/upload');
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-length', 'five');

  LRaised := False;
  try
    THttpRequestBuilder.Create(hmPost, LUrl.ToString).Headers(LHeaders).Body('hello').Build;
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, 'request helper rejects invalid content-length header');
end;

procedure TestNewRequestRejectsHeadersOnlyPositiveContentLength;
var
  LUrl: TUrl;
  LHeaders: IHttpHeaders;
  LRaised: Boolean;
begin
  LUrl := TUrl.Parse('http://example.com/upload');
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-length', '5');

  LRaised := False;
  try
    THttpRequestBuilder.Create(hmPost, LUrl.ToString).Headers(LHeaders).Build;
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised,
    'headers-only request helper rejects positive content-length');
end;

procedure TestNewRequestAcceptsHeadersOnlyZeroContentLength;
var
  LUrl: TUrl;
  LHeaders: IHttpHeaders;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse('http://example.com/upload');
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-length', '0');

  LReq := THttpRequestBuilder.Create(hmPost, LUrl.ToString).Headers(LHeaders).Build;

  CheckEqual('0', LReq.Headers.Get('content-length'),
    'headers-only request helper preserves zero content-length');
  CheckEqual(Int64(0), LReq.ContentLength,
    'headers-only request helper stores zero content-length');
  Check(LReq.Body = nil, 'headers-only request helper keeps body nil');
end;

procedure TestNewRequestRejectsNilBodyWithPositiveContentLength;
var
  LUrl: TUrl;
  LHeaders: IHttpHeaders;
  LRaised: Boolean;
begin
  LUrl := TUrl.Parse('http://example.com/upload');
  LHeaders := NewHttpHeaders;

  LRaised := False;
  try
    THttpRequestBuilder.Create(hmPost, LUrl.ToString).Headers(LHeaders).Body(IReader(nil)).ContentLength(5).Build;
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised,
    'request helper rejects nil body with positive content-length');
end;

procedure TestNewRequestRejectsTransferEncodingWithContentLength;
var
  LUrl: TUrl;
  LHeaders: IHttpHeaders;
  LRaised: Boolean;
begin
  LUrl := TUrl.Parse('http://example.com/upload');
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('transfer-encoding', 'chunked');

  LRaised := False;
  try
    THttpRequestBuilder.Create(hmPost, LUrl.ToString).Headers(LHeaders).Body('hello').Build;
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised,
    'request helper rejects transfer-encoding with declared content-length');
end;

procedure TestNewRequestRejectsTransferEncodingWithoutContentLength;
var
  LUrl: TUrl;
  LHeaders: IHttpHeaders;
  LRaised: Boolean;
begin
  LUrl := TUrl.Parse('http://example.com/upload');
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('transfer-encoding', 'chunked');

  LRaised := False;
  try
    THttpRequestBuilder.Create(hmPost, LUrl.ToString).Headers(LHeaders).Build;
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised,
    'request helper rejects transfer-encoding without a request body framing implementation');
end;

procedure TestRequestHeadersAccessible;
var
  LReq: IHttpRequest;
  LUrl: TUrl;
begin
  LUrl := Default(TUrl);
  LUrl.Path := '/test';
  LReq := NewRequest(hmGet, LUrl);
  LReq.Headers.SetHeader('Content-Type', 'application/json');
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

procedure TestRemoteIpStripsPort;
var
  LReq: IHttpRequest;
  LObj: THttpRequest;
begin
  LReq := NewGetRequest('/remote');
  LObj := THttpRequest(LReq as TObject);
  LObj.SetRemoteAddr('127.0.0.1:54321');
  CheckEqual('127.0.0.1', LReq.RemoteIp, 'ipv4 port stripped');
  LObj.SetRemoteAddr('192.168.1.10');
  CheckEqual('192.168.1.10', LReq.RemoteIp, 'bare ipv4 kept as-is');
  LObj.SetRemoteAddr('');
  CheckEqual('', LReq.RemoteIp, 'empty addr yields empty ip');
end;

procedure TestRemoteIpIpv6Bracketed;
var
  LReq: IHttpRequest;
  LObj: THttpRequest;
begin
  LReq := NewGetRequest('/remote');
  LObj := THttpRequest(LReq as TObject);
  LObj.SetRemoteAddr('[::1]:8080');
  CheckEqual('::1', LReq.RemoteIp, 'bracketed ipv6 keeps address');
  LObj.SetRemoteAddr('[2001:db8::1]:443');
  CheckEqual('2001:db8::1', LReq.RemoteIp, 'bracketed ipv6 keeps address');
end;

procedure TestRemoteIpFromNetAddress;
var
  LReq: IHttpRequest;
  LObj: THttpRequest;
begin
  LReq := NewGetRequest('/remote');
  LObj := THttpRequest(LReq as TObject);
  LObj.SetRemoteNetAddr(TNetAddress.IPv6('::1', 65000));
  CheckEqual('::1', LReq.RemoteIp, 'ipv6 net addr exposes bare address');
  LObj.SetRemoteNetAddr(TNetAddress.Loopback(65000));
  CheckEqual('127.0.0.1', LReq.RemoteIp, 'ipv4 net addr exposes bare address');
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

procedure TestNewResponseMetadataDefaults;
var
  LResp: IHttpResponse;
begin
  LResp := NewResponse(HTTP_STATUS_OK, nil, 'body');
  CheckEqual('', LResp.FinalUrl,
    'synthetic NewResponse leaves FinalUrl empty');
  CheckEqual(Int64(Ord(hvHttp11)), Int64(Ord(LResp.Version)),
    'synthetic NewResponse defaults Version to HTTP/1.1');
end;

procedure TestTHttpResponseVersionOverride;
var
  LResp: IHttpResponse;
begin
  LResp := THttpResponse.Create(HTTP_STATUS_OK, nil, nil, hvHttp2);
  CheckEqual(Int64(Ord(hvHttp2)), Int64(Ord(LResp.Version)),
    'THttpResponse constructor accepts Version');
  CheckEqual('', LResp.FinalUrl, 'constructor FinalUrl starts empty');
  (LResp as THttpResponse).SetFinalUrl('https://example.test/path');
  CheckEqual('https://example.test/path', LResp.FinalUrl,
    'SetFinalUrl is visible on IHttpResponse');
end;

procedure TestNewResponseWithNilHeadersCreatesHeaders;
var
  LResp: IHttpResponse;
begin
  LResp := NewResponse(HTTP_STATUS_OK, nil, nil);

  Check(LResp.Headers <> nil, 'response helper creates headers when nil');
  if LResp.Headers <> nil then
    CheckEqual(Int64(0), Int64(LResp.Headers.Count),
      'response helper nil headers start empty');
end;

procedure TestResponseHeadersAccessible;
var
  LResp: IHttpResponse;
  LH: IHttpHeaders;
begin
  LH := NewHttpHeaders;
  LH.SetHeader('X-Custom', 'hello');
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

procedure TestNewResponseStringBodyHelper;
var
  LHeaders: IHttpHeaders;
  LResp: IHttpResponse;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-type', 'text/plain');

  LResp := NewResponse(HTTP_STATUS_OK, LHeaders, 'hello');

  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'response string helper status');
  CheckEqual('text/plain', LResp.Headers.Get('content-type'),
    'response string helper preserves caller headers');
  CheckEqual('5', LResp.Headers.Get('content-length'),
    'response string helper publishes content-length');
  CheckEqual('hello', ReadBodyStr(LResp.Body),
    'response string helper body reader');
end;

procedure TestFacadeNewResponseStringBodyHelper;
var
  LResp: IHttpResponse;
begin
  LResp := nextpas.core.http.NewResponse(HTTP_STATUS_CREATED, nil, 'created');

  CheckEqual(Int64(201), Int64(LResp.StatusCode),
    'facade response string helper status');
  Check(LResp.Headers <> nil,
    'facade response string helper creates headers');
  CheckEqual('7', LResp.Headers.Get('content-length'),
    'facade response string helper publishes content-length');
  CheckEqual('created', ReadBodyStr(LResp.Body),
    'facade response string helper body reader');
end;

procedure TestNewResponseBytesBodyHelper;
var
  LResp: IHttpResponse;
  LBody: TBytes;
  LBuf: array[0..7] of Byte;
  LN: SizeUInt;
begin
  SetLength(LBody, 4);
  LBody[0] := Ord('b');
  LBody[1] := 0;
  LBody[2] := 255;
  LBody[3] := Ord('z');

  LResp := NewResponse(HTTP_STATUS_OK, nil, LBody);

  CheckEqual('4', LResp.Headers.Get('content-length'),
    'response bytes helper publishes content-length');
  Check(LResp.Body <> nil, 'response bytes helper body reader');
  LN := LResp.Body.Read(LBuf[0], SizeUInt(Length(LBuf)));
  CheckEqual(Int64(4), Int64(LN),
    'response bytes helper body length');
  CheckEqual(Byte(0), LBuf[1],
    'response bytes helper preserves zero byte');
  CheckEqual(Byte(255), LBuf[2],
    'response bytes helper preserves high byte');
end;

procedure TestNewResponseNilThirdArgumentKeepsNilBody;
var
  LResp: IHttpResponse;
begin
  LResp := NewResponse(HTTP_STATUS_OK, nil, nil);

  Check(LResp.Headers <> nil,
    'response nil-body compatibility helper creates headers');
  CheckEqual('', LResp.Headers.Get('content-length'),
    'response nil-body compatibility helper does not publish content-length');
  Check(LResp.Body = nil,
    'response nil-body compatibility helper keeps body nil');
end;

procedure TestNewResponseExplicitNilReaderKeepsNilBody;
var
  LResp: IHttpResponse;
begin
  LResp := NewResponse(HTTP_STATUS_OK, nil, IReader(nil));

  Check(LResp.Headers <> nil,
    'response explicit nil reader creates headers');
  CheckEqual('', LResp.Headers.Get('content-length'),
    'response explicit nil reader does not publish content-length');
  Check(LResp.Body = nil,
    'response explicit nil reader keeps body nil');
end;

procedure TestNewResponseRejectsConflictingContentLengthHeader;
var
  LHeaders: IHttpHeaders;
  LRaised: Boolean;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-length', '4');

  LRaised := False;
  try
    NewResponse(HTTP_STATUS_OK, LHeaders, 'hello');
  except
    on E: EHttpError do
      LRaised := True;
  end;

  Check(LRaised,
    'response string helper rejects conflicting content-length');
end;

procedure TestNewResponseRejectsTransferEncodingWithFixedBody;
var
  LHeaders: IHttpHeaders;
  LRaised: Boolean;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('transfer-encoding', 'chunked');

  LRaised := False;
  try
    NewResponse(HTTP_STATUS_OK, LHeaders, 'hello');
  except
    on E: EHttpError do
      LRaised := True;
  end;

  Check(LRaised,
    'response fixed-body helper rejects transfer-encoding');
end;

procedure TestNewResponseRejectsNoBodyStatusStringBody;
var
  LHeaders: IHttpHeaders;
  LRaised: Boolean;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('x-client', 'no-body-string');

  LRaised := False;
  try
    NewResponse(HTTP_STATUS_NO_CONTENT, LHeaders, 'payload');
  except
    on E: EHttpError do
      LRaised := True;
  end;

  Check(LRaised,
    'response string helper rejects non-empty body for 204');
  CheckEqual('', LHeaders.Get('content-length'),
    'response string helper does not publish content-length after 204 rejection');
  CheckEqual('no-body-string', LHeaders.Get('x-client'),
    'response string helper preserves caller headers after 204 rejection');
end;

procedure TestNewResponseRejectsNoBodyStatusBytesBody;
var
  LHeaders: IHttpHeaders;
  LBody: TBytes;
  LRaised: Boolean;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('x-client', 'no-body-bytes');
  SetLength(LBody, 1);
  LBody[0] := Ord('x');

  LRaised := False;
  try
    NewResponse(HTTP_STATUS_NOT_MODIFIED, LHeaders, LBody);
  except
    on E: EHttpError do
      LRaised := True;
  end;

  Check(LRaised,
    'response bytes helper rejects non-empty body for 304');
  CheckEqual('', LHeaders.Get('content-length'),
    'response bytes helper does not publish content-length after 304 rejection');
  CheckEqual('no-body-bytes', LHeaders.Get('x-client'),
    'response bytes helper preserves caller headers after 304 rejection');
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

{ TMockResponseWriter }

constructor TMockResponseWriter.Create;
begin
  inherited Create;
  FHeaders := NewHttpHeaders;
  FStatus := HTTP_STATUS_OK;
  FStatusWritten := False;
  FBody := '';
  FBodyBytes := nil;
end;

procedure TMockResponseWriter.WriteHeader(const AStatus: THttpStatus);
begin
  FStatus := AStatus;
  FStatusWritten := True;
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
  LPrev: SizeInt;
  LPrevBytes: SizeUInt;
begin
  LPrev := SizeInt(Length(FBody));
  SetLength(FBody, LPrev + SizeInt(ACount));
  Move(ABuf, FBody[LPrev + 1], ACount);
  LPrevBytes := SizeUInt(Length(FBodyBytes));
  SetLength(FBodyBytes, LPrevBytes + ACount);
  Move(ABuf, FBodyBytes[LPrevBytes], ACount);
  Result := ACount;
end;

procedure TMockResponseWriter.Flush;
begin
end;

{ HttpWriteResponseJson tests }

procedure TestWriteResponseJsonSetsContentType;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
  LDoc: IJsonDocument;
  LWritten: SizeUInt;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  LDoc := JsonParse('{"key":"value"}');
  LWritten := HttpWriteResponseJson(LW, HTTP_STATUS_OK, LDoc.Root);
  Check(LM.StatusWritten, 'WriteResponseJson writes status');
  CheckEqual(200, Int32(LM.Status), 'WriteResponseJson status is 200');
  CheckEqual('application/json', LM.FHeaders.Get('content-type'),
    'WriteResponseJson sets application/json content-type');
  Check(LWritten > 0, 'WriteResponseJson returns non-zero bytes written');
  Check(Pos('"key"', LM.Body) > 0, 'WriteResponseJson body contains JSON key');
end;

procedure TestWriteResponseJsonSerializesValue;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
  LDoc: IJsonDocument;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  LDoc := JsonParse('[1,2,3]');
  HttpWriteResponseJson(LW, HTTP_STATUS_CREATED, LDoc.Root);
  CheckEqual(201, Int32(LM.Status), 'WriteResponseJson status is 201');
  Check(Pos('[1,2,3]', LM.Body) > 0, 'WriteResponseJson serializes array');
end;

procedure TestWriteResponseJsonEmptyObject;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
  LDoc: IJsonDocument;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  LDoc := JsonParse('{}');
  HttpWriteResponseJson(LW, HTTP_STATUS_OK, LDoc.Root);
  CheckEqual('{}', LM.Body, 'WriteResponseJson serializes empty object');
end;

{ HttpWriteResponseBytes tests }

procedure TestWriteResponseBytesSetsHeaders;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
  LData: TBytes;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  SetLength(LData, 3);
  LData[0] := $DE; LData[1] := $AD; LData[2] := $BE;
  HttpWriteResponseBytes(LW, HTTP_STATUS_OK, 'application/octet-stream', LData);
  CheckEqual(HTTP_STATUS_OK, LM.Status, 'status');
  CheckEqual('application/octet-stream', LM.GetHeaders.Get('content-type'), 'content-type');
  CheckEqual('3', LM.GetHeaders.Get('content-length'), 'content-length');
  CheckTrue(LM.StatusWritten, 'header written');
end;

procedure TestWriteResponseBytesWritesBody;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
  LData: TBytes;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  SetLength(LData, 4);
  LData[0] := $01; LData[1] := $02; LData[2] := $03; LData[3] := $04;
  HttpWriteResponseBytes(LW, HTTP_STATUS_OK, 'application/octet-stream', LData);
  CheckEqual(4, Length(LM.BodyBytes), 'body length');
  CheckEqual($01, LM.BodyBytes[0], 'byte 0');
  CheckEqual($02, LM.BodyBytes[1], 'byte 1');
  CheckEqual($03, LM.BodyBytes[2], 'byte 2');
  CheckEqual($04, LM.BodyBytes[3], 'byte 3');
end;

procedure TestWriteResponseBytesEmptyBody;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteResponseBytes(LW, HTTP_STATUS_OK, 'application/octet-stream', nil);
  CheckEqual('0', LM.GetHeaders.Get('content-length'), 'content-length');
  CheckEqual(0, Length(LM.BodyBytes), 'empty body');
end;

procedure TestWriteResponseBytesNoBodyStatus;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteResponseBytes(LW, HTTP_STATUS_NO_CONTENT, '', nil);
  CheckEqual(HTTP_STATUS_NO_CONTENT, LM.Status, 'status');
  CheckEqual('', LM.GetHeaders.Get('content-length'), 'no content-length');
end;

procedure TestWriteResponseBytesNoBodyStatusWithBodyRaises;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
  LData: TBytes;
  LRaised: Boolean;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  SetLength(LData, 1);
  LData[0] := $FF;
  LRaised := False;
  try
    HttpWriteResponseBytes(LW, HTTP_STATUS_NO_CONTENT, '', LData);
  except
    on E: EHttpError do
      LRaised := True;
  end;
  CheckTrue(LRaised, 'raises on no-body status with body');
end;

procedure TestWriteResponseBytesNilWriterRaises;
var
  LData: TBytes;
  LRaised: Boolean;
begin
  SetLength(LData, 1);
  LData[0] := $00;
  LRaised := False;
  try
    HttpWriteResponseBytes(nil, HTTP_STATUS_OK, 'application/octet-stream', LData);
  except
    on E: EHttpError do
      LRaised := True;
  end;
  CheckTrue(LRaised, 'raises on nil writer');
end;

{ HttpReadRequestBody* tests }

procedure TestReadRequestBodyBytesReadsBody;
var
  LReq: IHttpRequest;
  LBody: TBytes;
  LData: TBytes;
begin
  SetLength(LData, 5);
  Move('hello'[1], LData[0], 5);
  LReq := THttpRequestBuilder.Create(hmPost, 'http://example.com/api').ContentType('application/octet-stream').Body(LData).Build;
  LBody := HttpReadRequestBodyBytes(LReq);
  CheckEqual(Int64(5), Int64(Length(LBody)), 'ReadRequestBodyBytes length');
  CheckEqual(Byte(Ord('h')), LBody[0], 'ReadRequestBodyBytes first byte');
  CheckEqual(Byte(Ord('o')), LBody[4], 'ReadRequestBodyBytes last byte');
end;

procedure TestReadRequestBodyStringReadsBody;
var
  LReq: IHttpRequest;
  LBody: string;
begin
  LReq := THttpRequestBuilder.Create(hmPost, 'http://example.com/api').ContentType('text/plain').Body('hello world').Build;
  LBody := HttpReadRequestBodyString(LReq);
  CheckEqual('hello world', LBody, 'ReadRequestBodyString content');
end;

procedure TestReadRequestBodyJsonParsesObject;
var
  LReq: IHttpRequest;
  LDoc: IJsonDocument;
begin
  LReq := THttpRequestBuilder.Create(hmPost, 'http://example.com/api').ContentType('application/json').Body('{"key":"value"}').Build;
  LDoc := HttpReadRequestBodyJson(LReq);
  Check(LDoc <> nil, 'ReadRequestBodyJson returns document');
  Check(LDoc.Root.IsValid, 'ReadRequestBodyJson returns valid root');
  CheckEqual('value', LDoc.Root.ObjectGet('key').AsStr.ToString,
    'ReadRequestBodyJson parses key');
end;

procedure TestReadRequestBodyJsonParsesArray;
var
  LReq: IHttpRequest;
  LDoc: IJsonDocument;
begin
  LReq := THttpRequestBuilder.Create(hmPost, 'http://example.com/api').ContentType('application/json').Body('[1,2,3]').Build;
  LDoc := HttpReadRequestBodyJson(LReq);
  Check(LDoc <> nil, 'ReadRequestBodyJson array returns document');
  Check(LDoc.Root.IsArray, 'ReadRequestBodyJson root is array');
  CheckEqual(Int64(3), Int64(LDoc.Root.ArrayLen), 'ReadRequestBodyJson array length');
end;

procedure TestReadRequestBodyBytesNilBodyReturnsNil;
var
  LReq: IHttpRequest;
  LBody: TBytes;
begin
  LReq := NewGetRequest('/no-body');
  LBody := HttpReadRequestBodyBytes(LReq);
  Check(LBody = nil, 'ReadRequestBodyBytes nil body returns nil');
end;

procedure TestReadRequestBodyStringNilBodyReturnsEmpty;
var
  LReq: IHttpRequest;
  LBody: string;
begin
  LReq := NewGetRequest('/no-body');
  LBody := HttpReadRequestBodyString(LReq);
  CheckEqual('', LBody, 'ReadRequestBodyString nil body returns empty');
end;

procedure TestReadRequestBodyBytesNilRequestRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    HttpReadRequestBodyBytes(nil);
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, 'ReadRequestBodyBytes nil request raises');
end;

procedure TestReadRequestBodyStringNilRequestRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    HttpReadRequestBodyString(nil);
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, 'ReadRequestBodyString nil request raises');
end;

procedure TestReadRequestBodyJsonInvalidJsonRaises;
var
  LReq: IHttpRequest;
  LRaised: Boolean;
begin
  LReq := THttpRequestBuilder.Create(hmPost, 'http://example.com/api').ContentType('application/json').Body('{invalid').Build;
  LRaised := False;
  try
    HttpReadRequestBodyJson(LReq);
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'ReadRequestBodyJson invalid JSON raises');
end;

procedure TestReadRequestBodyBytesEmptyBodyReturnsNil;
var
  LReq: IHttpRequest;
  LBody: TBytes;
begin
  LReq := THttpRequestBuilder.Create(hmPost, 'http://example.com/api').ContentType('application/octet-stream').Body('').Build;
  LBody := HttpReadRequestBodyBytes(LReq);
  Check(LBody = nil, 'ReadRequestBodyBytes empty body returns nil');
end;

procedure TestReadRequestBodyBytesMaxUnlimited;
var
  LReq: IHttpRequest;
  LData: TBytes;
  LBody: TBytes;
  LI: SizeInt;
begin
  SetLength(LData, 64);
  for LI := 0 to High(LData) do
    LData[LI] := Byte(LI and $FF);
  LReq := THttpRequestBuilder.Create(hmPost, 'http://example.com/api')
    .ContentType('application/octet-stream').Body(LData).Build;
  LBody := HttpReadRequestBodyBytesMax(LReq, 0);
  CheckEqual(Int64(Length(LData)), Int64(Length(LBody)), 'Max(0) unlimited length');
end;

procedure TestReadRequestBodyBytesExceedsDefaultMaxRaises;
var
  LReq: IHttpRequest;
  LData: TBytes;
  LRaised: Boolean;
  LKind: THttpErrorKind;
  LOp: string;
begin
  { Build a body larger than a tiny Max via Max overload; default path covered by Max. }
  SetLength(LData, 32);
  FillChar(LData[0], Length(LData), Ord('x'));
  LReq := THttpRequestBuilder.Create(hmPost, 'http://example.com/api')
    .ContentType('application/octet-stream').Body(LData).Build;
  LRaised := False;
  LKind := hekUnknown;
  LOp := '';
  try
    HttpReadRequestBodyBytesMax(LReq, 16);
  except
    on E: EHttpError do
    begin
      LRaised := True;
      LKind := E.Kind;
      LOp := E.Op;
    end;
  end;
  Check(LRaised, 'oversize body raises');
  Check(LKind = hekBody, 'Kind=hekBody');
  CheckEqual('body', LOp, 'Op=body');
end;

{ HttpRedirect tests }

procedure TestRedirectSetsLocationAndStatus;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpRedirect(LW, HTTP_STATUS_FOUND, '/new-page');
  CheckEqual(Int64(302), Int64(LM.Status), 'status 302');
  CheckEqual('/new-page', LM.GetHeaders.Get('location'), 'location header');
  Check(Pos('/new-page', LM.Body) > 0, 'body contains location');
end;

procedure TestRedirect301Permanent;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpRedirect(LW, HTTP_STATUS_MOVED_PERMANENTLY, 'https://example.com');
  CheckEqual(Int64(301), Int64(LM.Status), 'status 301');
  CheckEqual('https://example.com', LM.GetHeaders.Get('location'), 'location');
end;

procedure TestRedirectNonRedirectStatusRaises;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
  LRaised: Boolean;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  LRaised := False;
  try
    HttpRedirect(LW, HTTP_STATUS_OK, '/page');
  except
    on E: EHttpError do
      LRaised := True;
  end;
  CheckTrue(LRaised, 'raises on non-redirect status');
end;

procedure TestRedirectEmptyLocationRaises;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
  LRaised: Boolean;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  LRaised := False;
  try
    HttpRedirect(LW, HTTP_STATUS_FOUND, '');
  except
    on E: EHttpError do
      LRaised := True;
  end;
  CheckTrue(LRaised, 'raises on empty location');
end;

procedure TestRedirectNilWriterRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    HttpRedirect(nil, HTTP_STATUS_FOUND, '/page');
  except
    on E: EHttpError do
      LRaised := True;
  end;
  CheckTrue(LRaised, 'raises on nil writer');
end;

procedure TestRedirectMovedPermanently;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpRedirectMovedPermanently(LW, 'https://example.com/new');
  CheckEqual(Int64(301), Int64(LM.Status), 'status 301');
  CheckEqual('https://example.com/new', LM.GetHeaders.Get('location'), 'location header');
  Check(Pos('Redirecting', LM.Body) > 0, 'body contains redirect html');
end;

procedure TestRedirectFound;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpRedirectFound(LW, '/other');
  CheckEqual(Int64(302), Int64(LM.Status), 'status 302');
  CheckEqual('/other', LM.GetHeaders.Get('location'), 'location header');
end;

procedure TestRedirectSeeOther;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpRedirectSeeOther(LW, '/result');
  CheckEqual(Int64(303), Int64(LM.Status), 'status 303');
  CheckEqual('/result', LM.GetHeaders.Get('location'), 'location header');
end;

procedure TestRedirectTemporaryRedirect;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpRedirectTemporaryRedirect(LW, '/temp');
  CheckEqual(Int64(307), Int64(LM.Status), 'status 307');
  CheckEqual('/temp', LM.GetHeaders.Get('location'), 'location header');
end;

procedure TestRedirectPermanentRedirect;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpRedirectPermanentRedirect(LW, '/perm');
  CheckEqual(Int64(308), Int64(LM.Status), 'status 308');
  CheckEqual('/perm', LM.GetHeaders.Get('location'), 'location header');
end;

procedure TestRedirectHtmlEscapesXssPayload;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpRedirect(LW, HTTP_STATUS_FOUND, '/page?q="><script>alert(1)</script>');
  { Verify the HTML body does NOT contain raw <script> tag }
  Check(Pos('<script>', LM.Body) = 0, 'XSS payload must be HTML-escaped');
  { Verify the escaped form is present }
  Check(Pos('&lt;script&gt;', LM.Body) > 0, 'script tags are escaped');
  Check(Pos('&quot;', LM.Body) > 0, 'double quotes are escaped');
end;

procedure TestRedirectRejectsProtocolRelativeUrl;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    HttpRedirect(nil, HTTP_STATUS_FOUND, '//evil.com/steal');
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, 'Protocol-relative URL must be rejected to prevent open redirect');
end;

{ HttpWriteErrorResponse tests }

procedure TestErrorResponseSetsJsonContentType;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteErrorResponse(LW, HTTP_STATUS_BAD_REQUEST, 'invalid_input', 'Missing field');
  CheckEqual('application/problem+json', LM.GetHeaders.Get('content-type'),
    'content-type is RFC 7807 problem+json');
  CheckEqual(Int64(400), Int64(LM.Status), 'status 400');
end;

procedure TestErrorResponseBodyFormat;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteErrorResponse(LW, HTTP_STATUS_NOT_FOUND, 'not_found', 'Item not found');
  Check(Pos('"title":"not_found"', LM.Body) > 0, 'body contains title');
  Check(Pos('"detail":"Item not found"', LM.Body) > 0, 'body contains detail');
  Check(Pos('"status":404', LM.Body) > 0, 'body contains status');
end;

procedure TestErrorBadRequest;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteErrorBadRequest(LW, 'Invalid JSON');
  CheckEqual(Int64(400), Int64(LM.Status), 'status 400');
  Check(Pos('"title":"bad_request"', LM.Body) > 0, 'title is bad_request');
end;

procedure TestErrorUnauthorized;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteErrorUnauthorized(LW, 'Token expired');
  CheckEqual(Int64(401), Int64(LM.Status), 'status 401');
  Check(Pos('"title":"unauthorized"', LM.Body) > 0, 'title is unauthorized');
end;

procedure TestErrorForbidden;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteErrorForbidden(LW, 'Access denied');
  CheckEqual(Int64(403), Int64(LM.Status), 'status 403');
  Check(Pos('"title":"forbidden"', LM.Body) > 0, 'title is forbidden');
end;

procedure TestErrorNotFound;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteErrorNotFound(LW, 'User not found');
  CheckEqual(Int64(404), Int64(LM.Status), 'status 404');
  Check(Pos('"title":"not_found"', LM.Body) > 0, 'title is not_found');
end;

procedure TestErrorInternal;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteErrorInternal(LW, 'Something broke');
  CheckEqual(Int64(500), Int64(LM.Status), 'status 500');
  Check(Pos('"title":"internal_error"', LM.Body) > 0, 'title is internal_error');
end;

procedure TestNoContentSets204;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteResponseNoContent(LW);
  CheckEqual(Int64(204), Int64(LM.Status), 'status 204');
  CheckEqual('', LM.Body, 'no body written');
  Check(LM.StatusWritten, 'WriteHeader was called');
end;

procedure TestNoContentNilWriterRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    HttpWriteResponseNoContent(nil);
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, 'raises on nil writer');
end;

procedure TestHtmlSetsContentType;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteResponseHtml(LW, HTTP_STATUS_OK, '<h1>Hello</h1>');
  CheckEqual(Int64(200), Int64(LM.Status), 'status 200');
  CheckEqual('text/html; charset=utf-8', LM.GetHeaders.Get('content-type'), 'content-type is text/html');
  CheckEqual('<h1>Hello</h1>', LM.Body, 'body is HTML');
end;

procedure TestHtmlWritesStatus;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteResponseHtml(LW, HTTP_STATUS_NOT_FOUND, '<p>Not Found</p>');
  CheckEqual(Int64(404), Int64(LM.Status), 'status 404');
  Check(Pos('text/html', LM.GetHeaders.Get('content-type')) > 0, 'content-type has text/html');
end;

procedure TestHtmlEmptyBody;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteResponseHtml(LW, HTTP_STATUS_OK, '');
  CheckEqual(Int64(200), Int64(LM.Status), 'status 200');
  CheckEqual('', LM.Body, 'empty body');
  CheckEqual('0', LM.GetHeaders.Get('content-length'), 'content-length 0');
end;

procedure TestHtmlNoBodyStatus;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteResponseHtml(LW, HTTP_STATUS_NO_CONTENT, '');
  CheckEqual(Int64(204), Int64(LM.Status), 'status 204');
end;

procedure TestHtmlNoBodyStatusWithBodyRaises;
var
  LRaised: Boolean;
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LRaised := False;
  LM := TMockResponseWriter.Create;
  LW := LM;
  try
    HttpWriteResponseHtml(LW, HTTP_STATUS_NO_CONTENT, '<p>oops</p>');
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, 'raises on no-body status with body');
end;

procedure TestErrorTooManyRequests;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteErrorTooManyRequests(LW, 'Slow down');
  CheckEqual(Int64(429), Int64(LM.Status), 'status 429');
  Check(Pos('"title":"too_many_requests"', LM.Body) > 0, 'title is too_many_requests');
  Check(Pos('Slow down', LM.Body) > 0, 'detail preserved');
end;

procedure TestErrorConflict;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteErrorConflict(LW, 'Resource already exists');
  CheckEqual(Int64(409), Int64(LM.Status), 'status 409');
  Check(Pos('"title":"conflict"', LM.Body) > 0, 'title is conflict');
  Check(Pos('Resource already exists', LM.Body) > 0, 'detail preserved');
end;

procedure TestErrorUnprocessableEntity;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteErrorUnprocessableEntity(LW, 'Validation failed');
  CheckEqual(Int64(422), Int64(LM.Status), 'status 422');
  Check(Pos('"title":"unprocessable_entity"', LM.Body) > 0, 'title is unprocessable_entity');
  Check(Pos('Validation failed', LM.Body) > 0, 'detail preserved');
end;

procedure TestOkSets200;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteResponseOk(LW);
  CheckEqual(Int64(200), Int64(LM.Status), 'status 200');
  CheckEqual('', LM.Body, 'no body');
end;

procedure TestOkNilWriterRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    HttpWriteResponseOk(nil);
  except
    LRaised := True;
  end;
  Check(LRaised, 'raises on nil writer');
end;

procedure TestCreatedSets201;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteResponseCreated(LW);
  CheckEqual(Int64(201), Int64(LM.Status), 'status 201');
  CheckEqual('', LM.Body, 'no body');
end;

procedure TestCreatedNilWriterRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    HttpWriteResponseCreated(nil);
  except
    LRaised := True;
  end;
  Check(LRaised, 'raises on nil writer');
end;

procedure TestAcceptedSets202;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteResponseAccepted(LW);
  CheckEqual(Int64(202), Int64(LM.Status), 'status 202');
  CheckEqual('', LM.Body, 'no body');
end;

procedure TestAcceptedNilWriterRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    HttpWriteResponseAccepted(nil);
  except
    LRaised := True;
  end;
  Check(LRaised, 'raises on nil writer');
end;

procedure TestNotModifiedSets304;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteResponseNotModified(LW);
  CheckEqual(Int64(304), Int64(LM.Status), 'status 304');
  CheckEqual('', LM.Body, 'no body');
end;

procedure TestNotModifiedNilWriterRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    HttpWriteResponseNotModified(nil);
  except
    LRaised := True;
  end;
  Check(LRaised, 'raises on nil writer');
end;

procedure TestResetContentSets205;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteResponseResetContent(LW);
  CheckEqual(Int64(205), Int64(LM.Status), 'status 205');
  CheckEqual('', LM.Body, 'no body');
end;

procedure TestResetContentNilWriterRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    HttpWriteResponseResetContent(nil);
  except
    LRaised := True;
  end;
  Check(LRaised, 'raises on nil writer');
end;

procedure TestGoneSets410;
var
  LW: IHttpResponseWriter;
  LM: TMockResponseWriter;
begin
  LM := TMockResponseWriter.Create;
  LW := LM;
  HttpWriteResponseGone(LW);
  CheckEqual(Int64(410), Int64(LM.Status), 'status 410');
  CheckEqual('', LM.Body, 'no body');
end;

procedure TestGoneNilWriterRaises;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    HttpWriteResponseGone(nil);
  except
    LRaised := True;
  end;
  Check(LRaised, 'raises on nil writer');
end;

begin
  T := TTestSuite.Create('nextpas.core.http.message');
  T.Test('NewRequest creates with correct method/url', @TestNewRequestMethodAndUrl);
  T.Test('NewRequest parses string URL', @TestNewRequestParsesStringUrl);
  T.Test('NewRequest accepts headers, body, and content length',
    @TestNewRequestWithHeadersBodyAndContentLength);
  T.Test('NewRequest accepts string URL with headers, body, and content length',
    @TestNewRequestStringUrlWithHeadersBodyAndContentLength);
  T.Test('NewRequest accepts headers without body',
    @TestNewRequestWithHeadersWithoutBody);
  T.Test('NewRequest accepts string URL with headers without body',
    @TestNewRequestStringUrlWithHeadersWithoutBody);
  T.Test('NewRequest nil third argument keeps bytes helper semantics',
    @TestNewRequestNilThirdArgumentKeepsBytesHelper);
  T.Test('NewRequest accepts string body helper',
    @TestNewRequestWithStringBody);
  T.Test('NewRequest accepts bytes body helper',
    @TestNewRequestWithBytesBody);
  T.Test('NewRequest accepts string URL bytes body helper',
    @TestNewRequestStringUrlWithBytesBody);
  T.Test('NewRequest accepts string body helper without headers',
    @TestNewRequestWithStringBodyWithoutHeaders);
  T.Test('NewRequest accepts bytes body helper without headers',
    @TestNewRequestWithBytesBodyWithoutHeaders);
  T.Test('NewRequest accepts reader body helper without headers',
    @TestNewRequestWithReaderBodyWithoutHeaders);
  T.Test('NewRequest accepts string body and content-type helper without headers',
    @TestNewRequestWithStringBodyAndContentTypeWithoutHeaders);
  T.Test('NewRequest accepts bytes body and content-type helper without headers',
    @TestNewRequestWithBytesBodyAndContentTypeWithoutHeaders);
  T.Test('NewRequest accepts reader body and content-type helper without headers',
    @TestNewRequestWithReaderBodyAndContentTypeWithoutHeaders);
  T.Test('NewRequest creates headers when headers argument is nil',
    @TestNewRequestWithNilHeadersCreatesHeaders);
  T.Test('Request constructors create headers when headers argument is nil',
    @TestRequestConstructorsWithNilHeadersCreateHeaders);
  T.Test('NewRequest rejects negative content length',
    @TestNewRequestRejectsNegativeContentLength);
  T.Test('NewRequest rejects conflicting content-length header',
    @TestNewRequestRejectsConflictingContentLengthHeader);
  T.Test('NewRequest accepts matching content-length header',
    @TestNewRequestAcceptsMatchingContentLengthHeader);
  T.Test('NewRequest rejects duplicate content-length header',
    @TestNewRequestRejectsDuplicateContentLengthHeader);
  T.Test('NewRequest rejects invalid content-length header',
    @TestNewRequestRejectsInvalidContentLengthHeader);
  T.Test('NewRequest rejects headers-only positive content-length',
    @TestNewRequestRejectsHeadersOnlyPositiveContentLength);
  T.Test('NewRequest accepts headers-only zero content-length',
    @TestNewRequestAcceptsHeadersOnlyZeroContentLength);
  T.Test('NewRequest rejects nil body with positive content-length',
    @TestNewRequestRejectsNilBodyWithPositiveContentLength);
  T.Test('NewRequest rejects transfer-encoding with content-length',
    @TestNewRequestRejectsTransferEncodingWithContentLength);
  T.Test('NewRequest rejects transfer-encoding without content-length',
    @TestNewRequestRejectsTransferEncodingWithoutContentLength);
  T.Test('Request headers accessible', @TestRequestHeadersAccessible);
  T.Test('Request body nil is ok', @TestRequestBodyNilIsOk);
  T.Test('PathParam set and get', @TestPathParamSetAndGet);
  T.Test('PathParam not found returns empty', @TestPathParamNotFoundReturnsEmpty);
  T.Test('RemoteAddr default and set', @TestRemoteAddrDefaultAndSet);
  T.Test('RemoteAddr from TNetAddress', @TestRemoteAddrFromNetAddress);
  T.Test('RemoteIp strips port', @TestRemoteIpStripsPort);
  T.Test('RemoteIp ipv6 bracketed', @TestRemoteIpIpv6Bracketed);
  T.Test('RemoteIp from TNetAddress', @TestRemoteIpFromNetAddress);
  T.Test('NewGetRequest convenience', @TestNewGetRequestConvenience);
  T.Test('NewResponse creates with status', @TestNewResponseCreatesWithStatus);
  T.Test('NewResponse metadata defaults', @TestNewResponseMetadataDefaults);
  T.Test('THttpResponse Version and FinalUrl', @TestTHttpResponseVersionOverride);
  T.Test('NewResponse with nil headers creates headers',
    @TestNewResponseWithNilHeadersCreatesHeaders);
  T.Test('Response headers accessible', @TestResponseHeadersAccessible);
  T.Test('Response body accessible', @TestResponseBodyAccessible);
  T.Test('NewResponse accepts string body helper',
    @TestNewResponseStringBodyHelper);
  T.Test('Facade NewResponse accepts string body helper',
    @TestFacadeNewResponseStringBodyHelper);
  T.Test('NewResponse accepts bytes body helper',
    @TestNewResponseBytesBodyHelper);
  T.Test('NewResponse nil third argument keeps nil body',
    @TestNewResponseNilThirdArgumentKeepsNilBody);
  T.Test('NewResponse explicit nil reader keeps nil body',
    @TestNewResponseExplicitNilReaderKeepsNilBody);
  T.Test('NewResponse rejects conflicting content-length header',
    @TestNewResponseRejectsConflictingContentLengthHeader);
  T.Test('NewResponse rejects transfer-encoding with fixed body',
    @TestNewResponseRejectsTransferEncodingWithFixedBody);
  T.Test('NewResponse rejects no-body status with non-empty string body',
    @TestNewResponseRejectsNoBodyStatusStringBody);
  T.Test('NewResponse rejects no-body status with non-empty bytes body',
    @TestNewResponseRejectsNoBodyStatusBytesBody);
  T.Test('Request version defaults to HTTP/1.1', @TestRequestVersionDefaultsHttp11);
  T.Test('Multiple path params', @TestMultiplePathParams);
  T.Test('Request content-length stored', @TestRequestContentLengthStored);
  T.Test('Request from request-target parses URL on demand',
    @TestRequestFromRequestTargetParsesOnDemand);
  T.Test('Request direct path/raw-query accessors',
    @TestRequestDirectPathAndRawQueryAccessors);
  T.Test('Request direct path/raw-query absolute target',
    @TestRequestDirectPathAccessorsPreserveAbsoluteTarget);
  T.Test('Request direct path/raw-query target forms',
    @TestRequestDirectPathAccessorTargetForms);
  T.Test('Request direct path/raw-query invalid absolute target raises',
    @TestRequestDirectPathAccessorInvalidAbsoluteTargetRaises);
  T.Test('WriteResponseJson sets content-type and status',
    @TestWriteResponseJsonSetsContentType);
  T.Test('WriteResponseJson serializes value',
    @TestWriteResponseJsonSerializesValue);
  T.Test('WriteResponseJson empty object',
    @TestWriteResponseJsonEmptyObject);
  T.Test('WriteResponseBytes sets headers',
    @TestWriteResponseBytesSetsHeaders);
  T.Test('WriteResponseBytes writes body',
    @TestWriteResponseBytesWritesBody);
  T.Test('WriteResponseBytes empty body',
    @TestWriteResponseBytesEmptyBody);
  T.Test('WriteResponseBytes no-body status',
    @TestWriteResponseBytesNoBodyStatus);
  T.Test('WriteResponseBytes no-body status with body raises',
    @TestWriteResponseBytesNoBodyStatusWithBodyRaises);
  T.Test('WriteResponseBytes nil writer raises',
    @TestWriteResponseBytesNilWriterRaises);
  T.Test('ReadRequestBodyBytes reads body',
    @TestReadRequestBodyBytesReadsBody);
  T.Test('ReadRequestBodyString reads body',
    @TestReadRequestBodyStringReadsBody);
  T.Test('ReadRequestBodyJson parses object',
    @TestReadRequestBodyJsonParsesObject);
  T.Test('ReadRequestBodyJson parses array',
    @TestReadRequestBodyJsonParsesArray);
  T.Test('ReadRequestBodyBytes nil body returns nil',
    @TestReadRequestBodyBytesNilBodyReturnsNil);
  T.Test('ReadRequestBodyString nil body returns empty',
    @TestReadRequestBodyStringNilBodyReturnsEmpty);
  T.Test('ReadRequestBodyBytes nil request raises',
    @TestReadRequestBodyBytesNilRequestRaises);
  T.Test('ReadRequestBodyString nil request raises',
    @TestReadRequestBodyStringNilRequestRaises);
  T.Test('ReadRequestBodyJson invalid JSON raises',
    @TestReadRequestBodyJsonInvalidJsonRaises);
  T.Test('ReadRequestBodyBytes empty body returns nil',
    @TestReadRequestBodyBytesEmptyBodyReturnsNil);
  T.Test('ReadRequestBodyBytesMax(0) unlimited',
    @TestReadRequestBodyBytesMaxUnlimited);
  T.Test('ReadRequestBodyBytesMax oversize raises hekBody',
    @TestReadRequestBodyBytesExceedsDefaultMaxRaises);
  T.Test('Redirect sets location and status',
    @TestRedirectSetsLocationAndStatus);
  T.Test('Redirect 301 permanent',
    @TestRedirect301Permanent);
  T.Test('Redirect non-redirect status raises',
    @TestRedirectNonRedirectStatusRaises);
  T.Test('Redirect empty location raises',
    @TestRedirectEmptyLocationRaises);
  T.Test('Redirect nil writer raises',
    @TestRedirectNilWriterRaises);
  T.Test('Redirect: MovedPermanently 301',
    @TestRedirectMovedPermanently);
  T.Test('Redirect: Found 302',
    @TestRedirectFound);
  T.Test('Redirect: SeeOther 303',
    @TestRedirectSeeOther);
  T.Test('Redirect: TemporaryRedirect 307',
    @TestRedirectTemporaryRedirect);
  T.Test('Redirect: PermanentRedirect 308',
    @TestRedirectPermanentRedirect);
  T.Test('Redirect: HTML escapes XSS payload',
    @TestRedirectHtmlEscapesXssPayload);
  T.Test('Redirect: rejects protocol-relative URL',
    @TestRedirectRejectsProtocolRelativeUrl);
  T.Test('ErrorResponse sets JSON content-type',
    @TestErrorResponseSetsJsonContentType);
  T.Test('ErrorResponse body has code and message',
    @TestErrorResponseBodyFormat);
  T.Test('ErrorResponse 400 Bad Request',
    @TestErrorBadRequest);
  T.Test('ErrorResponse 401 Unauthorized',
    @TestErrorUnauthorized);
  T.Test('ErrorResponse 403 Forbidden',
    @TestErrorForbidden);
  T.Test('ErrorResponse 404 Not Found',
    @TestErrorNotFound);
  T.Test('ErrorResponse 500 Internal',
    @TestErrorInternal);
  T.Test('NoContent: sets 204 status',
    @TestNoContentSets204);
  T.Test('NoContent: nil writer raises',
    @TestNoContentNilWriterRaises);
  T.Test('Ok: sets 200 status',
    @TestOkSets200);
  T.Test('Ok: nil writer raises',
    @TestOkNilWriterRaises);
  T.Test('Created: sets 201 status',
    @TestCreatedSets201);
  T.Test('Created: nil writer raises',
    @TestCreatedNilWriterRaises);
  T.Test('Accepted: sets 202 status',
    @TestAcceptedSets202);
  T.Test('Accepted: nil writer raises',
    @TestAcceptedNilWriterRaises);
  T.Test('NotModified: sets 304 status',
    @TestNotModifiedSets304);
  T.Test('NotModified: nil writer raises',
    @TestNotModifiedNilWriterRaises);
  T.Test('ResetContent: sets 205 status',
    @TestResetContentSets205);
  T.Test('ResetContent: nil writer raises',
    @TestResetContentNilWriterRaises);
  T.Test('Html: sets text/html content-type',
    @TestHtmlSetsContentType);
  T.Test('Html: writes status and body',
    @TestHtmlWritesStatus);
  T.Test('Html: empty body',
    @TestHtmlEmptyBody);
  T.Test('Html: no-body status',
    @TestHtmlNoBodyStatus);
  T.Test('Html: no-body status with body raises',
    @TestHtmlNoBodyStatusWithBodyRaises);
  T.Test('ErrorResponse 429 Too Many Requests',
    @TestErrorTooManyRequests);
  T.Test('ErrorResponse 409 Conflict',
    @TestErrorConflict);
  T.Test('ErrorResponse 422 Unprocessable Entity',
    @TestErrorUnprocessableEntity);
  T.Test('Gone: sets 410 status', @TestGoneSets410);
  T.Test('Gone: nil writer raises', @TestGoneNilWriterRaises);
  if not T.Run then Halt(1);
end.
