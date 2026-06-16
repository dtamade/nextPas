program test_http_message;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.net.base,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http,
  nextpas.core.http.message;

var
  T: TTestRunner;

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

  LReq := NewRequest(hmPost, LUrl, LHeaders, LBody as IReader, 11);

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

  LReq := NewRequest(hmPost, 'http://example.com/api/users',
    LHeaders, LBody as IReader, 5);

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

  LReq := NewRequest(hmGet, LUrl, LHeaders);

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

  LReq := NewRequest(hmHead, 'http://example.com/ping?x=1', LHeaders);

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

  LReq := NewRequest(hmPost, LUrl, nil);

  CheckEqual(Int64(Ord(hmPost)), Int64(Ord(LReq.Method)),
    'nil third argument helper method');
  Check(LReq.Headers <> nil, 'nil third argument helper creates headers');
  CheckEqual('0', LReq.Headers.Get('content-length'),
    'nil third argument helper preserves bytes helper content-length');
  CheckEqual(Int64(0), LReq.ContentLength,
    'nil third argument helper stores zero content-length');
  Check(LReq.Body <> nil, 'nil third argument helper preserves bytes helper body');

  LReq := NewRequest(hmPut, 'http://example.com/upload?x=1', nil);

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

  LReq := NewRequest(hmPost, LUrl, LHeaders, 'hello');

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

  LReq := NewRequest(hmPost, LUrl, LHeaders, LBody);

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

  LReq := NewRequest(hmPut, 'http://example.com/upload?x=1', LHeaders, LBody);

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

  LReq := NewRequest(hmPost, LUrl, 'hello');

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

  LReq := NewRequest(hmPatch, LUrl, LBody);

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

  LReq := NewRequest(hmPut, LUrl, LBody as IReader, 4);

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

  LReq := NewRequest(hmPost, LUrl, 'text/plain; charset=utf-8', 'hello');

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

  LReq := NewRequest(hmPatch, 'http://example.com/upload',
    'application/octet-stream', LBody);

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

  LReq := NewRequest(hmPut, LUrl, 'application/custom',
    LBody as IReader, 4);

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
  LReq := NewRequest(hmGet, LUrl, nil, nil, 0);

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
    NewRequest(hmPost, LUrl, NewHttpHeaders, nil, -1);
  except
    on E: EArgumentError do
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
    NewRequest(hmPost, LUrl, LHeaders, 'hello');
  except
    on E: EArgumentError do
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

  LReq := NewRequest(hmPost, LUrl, LHeaders, 'hello');

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
    NewRequest(hmPost, LUrl, LHeaders, 'hello');
  except
    on E: EArgumentError do
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
    NewRequest(hmPost, LUrl, LHeaders, 'hello');
  except
    on E: EArgumentError do
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
    NewRequest(hmPost, LUrl, LHeaders);
  except
    on E: EArgumentError do
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

  LReq := NewRequest(hmPost, LUrl, LHeaders);

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
    NewRequest(hmPost, LUrl, LHeaders, nil, 5);
  except
    on E: EArgumentError do
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
    NewRequest(hmPost, LUrl, LHeaders, 'hello');
  except
    on E: EArgumentError do
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
    NewRequest(hmPost, LUrl, LHeaders);
  except
    on E: EArgumentError do
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
    on E: EArgumentError do
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
    on E: EArgumentError do
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

begin
  T := TTestRunner.Create('nextpas.core.http.message');
  T.Run('NewRequest creates with correct method/url', @TestNewRequestMethodAndUrl);
  T.Run('NewRequest parses string URL', @TestNewRequestParsesStringUrl);
  T.Run('NewRequest accepts headers, body, and content length',
    @TestNewRequestWithHeadersBodyAndContentLength);
  T.Run('NewRequest accepts string URL with headers, body, and content length',
    @TestNewRequestStringUrlWithHeadersBodyAndContentLength);
  T.Run('NewRequest accepts headers without body',
    @TestNewRequestWithHeadersWithoutBody);
  T.Run('NewRequest accepts string URL with headers without body',
    @TestNewRequestStringUrlWithHeadersWithoutBody);
  T.Run('NewRequest nil third argument keeps bytes helper semantics',
    @TestNewRequestNilThirdArgumentKeepsBytesHelper);
  T.Run('NewRequest accepts string body helper',
    @TestNewRequestWithStringBody);
  T.Run('NewRequest accepts bytes body helper',
    @TestNewRequestWithBytesBody);
  T.Run('NewRequest accepts string URL bytes body helper',
    @TestNewRequestStringUrlWithBytesBody);
  T.Run('NewRequest accepts string body helper without headers',
    @TestNewRequestWithStringBodyWithoutHeaders);
  T.Run('NewRequest accepts bytes body helper without headers',
    @TestNewRequestWithBytesBodyWithoutHeaders);
  T.Run('NewRequest accepts reader body helper without headers',
    @TestNewRequestWithReaderBodyWithoutHeaders);
  T.Run('NewRequest accepts string body and content-type helper without headers',
    @TestNewRequestWithStringBodyAndContentTypeWithoutHeaders);
  T.Run('NewRequest accepts bytes body and content-type helper without headers',
    @TestNewRequestWithBytesBodyAndContentTypeWithoutHeaders);
  T.Run('NewRequest accepts reader body and content-type helper without headers',
    @TestNewRequestWithReaderBodyAndContentTypeWithoutHeaders);
  T.Run('NewRequest creates headers when headers argument is nil',
    @TestNewRequestWithNilHeadersCreatesHeaders);
  T.Run('Request constructors create headers when headers argument is nil',
    @TestRequestConstructorsWithNilHeadersCreateHeaders);
  T.Run('NewRequest rejects negative content length',
    @TestNewRequestRejectsNegativeContentLength);
  T.Run('NewRequest rejects conflicting content-length header',
    @TestNewRequestRejectsConflictingContentLengthHeader);
  T.Run('NewRequest accepts matching content-length header',
    @TestNewRequestAcceptsMatchingContentLengthHeader);
  T.Run('NewRequest rejects duplicate content-length header',
    @TestNewRequestRejectsDuplicateContentLengthHeader);
  T.Run('NewRequest rejects invalid content-length header',
    @TestNewRequestRejectsInvalidContentLengthHeader);
  T.Run('NewRequest rejects headers-only positive content-length',
    @TestNewRequestRejectsHeadersOnlyPositiveContentLength);
  T.Run('NewRequest accepts headers-only zero content-length',
    @TestNewRequestAcceptsHeadersOnlyZeroContentLength);
  T.Run('NewRequest rejects nil body with positive content-length',
    @TestNewRequestRejectsNilBodyWithPositiveContentLength);
  T.Run('NewRequest rejects transfer-encoding with content-length',
    @TestNewRequestRejectsTransferEncodingWithContentLength);
  T.Run('NewRequest rejects transfer-encoding without content-length',
    @TestNewRequestRejectsTransferEncodingWithoutContentLength);
  T.Run('Request headers accessible', @TestRequestHeadersAccessible);
  T.Run('Request body nil is ok', @TestRequestBodyNilIsOk);
  T.Run('PathParam set and get', @TestPathParamSetAndGet);
  T.Run('PathParam not found returns empty', @TestPathParamNotFoundReturnsEmpty);
  T.Run('RemoteAddr default and set', @TestRemoteAddrDefaultAndSet);
  T.Run('RemoteAddr from TNetAddress', @TestRemoteAddrFromNetAddress);
  T.Run('NewGetRequest convenience', @TestNewGetRequestConvenience);
  T.Run('NewResponse creates with status', @TestNewResponseCreatesWithStatus);
  T.Run('NewResponse with nil headers creates headers',
    @TestNewResponseWithNilHeadersCreatesHeaders);
  T.Run('Response headers accessible', @TestResponseHeadersAccessible);
  T.Run('Response body accessible', @TestResponseBodyAccessible);
  T.Run('NewResponse accepts string body helper',
    @TestNewResponseStringBodyHelper);
  T.Run('Facade NewResponse accepts string body helper',
    @TestFacadeNewResponseStringBodyHelper);
  T.Run('NewResponse accepts bytes body helper',
    @TestNewResponseBytesBodyHelper);
  T.Run('NewResponse nil third argument keeps nil body',
    @TestNewResponseNilThirdArgumentKeepsNilBody);
  T.Run('NewResponse explicit nil reader keeps nil body',
    @TestNewResponseExplicitNilReaderKeepsNilBody);
  T.Run('NewResponse rejects conflicting content-length header',
    @TestNewResponseRejectsConflictingContentLengthHeader);
  T.Run('NewResponse rejects transfer-encoding with fixed body',
    @TestNewResponseRejectsTransferEncodingWithFixedBody);
  T.Run('NewResponse rejects no-body status with non-empty string body',
    @TestNewResponseRejectsNoBodyStatusStringBody);
  T.Run('NewResponse rejects no-body status with non-empty bytes body',
    @TestNewResponseRejectsNoBodyStatusBytesBody);
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
