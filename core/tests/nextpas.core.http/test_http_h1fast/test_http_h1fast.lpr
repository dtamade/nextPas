program test_http_h1fast;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.impl.h1.fast,
  nextpas.core.http.impl.h1.parser;

var
  T: TTestRunner;

procedure TestSimpleGet;
var
  LReq: AnsiString;
  LR: TFastParseResult;
begin
  LReq := 'GET / HTTP/1.1'#13#10'Host: localhost'#13#10#13#10;
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(LR.Success, 'should succeed');
  Check(LR.Method = hmGet, 'method is GET');
  CheckEqual('/', LR.Path, 'path is /');
  Check(LR.Version = hvHttp11, 'version is HTTP/1.1');
end;

procedure TestPostWithContentLength;
var
  LReq: AnsiString;
  LR: TFastParseResult;
begin
  LReq := 'POST /data HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Content-Length: 5'#13#10#13#10 +
           'hello';
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(LR.Success, 'should succeed');
  Check(LR.Method = hmPost, 'method is POST');
  CheckEqual('/data', LR.Path, 'path');
  CheckEqual(Int64(5), LR.ContentLength, 'content-length');
  CheckEqual(Int64(Length(LReq)), Int64(LR.Consumed), 'consumed all');
end;

procedure TestMultipleHeaders;
var
  LReq: AnsiString;
  LR: TFastParseResult;
begin
  LReq := 'GET /api HTTP/1.1'#13#10 +
           'Host: example.com'#13#10 +
           'Accept: application/json'#13#10 +
           'X-Request-Id: abc123'#13#10#13#10;
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(LR.Success, 'should succeed');
  CheckEqual(Int64(3), Int64(LR.Headers.Count), 'header count');
  CheckEqual('example.com', LR.Headers.Get('Host'), 'host');
  CheckEqual('application/json', LR.Headers.Get('Accept'), 'accept');
  CheckEqual('abc123', LR.Headers.Get('X-Request-Id'), 'x-request-id');
end;

procedure TestHttp10Version;
var
  LReq: AnsiString;
  LR: TFastParseResult;
begin
  LReq := 'GET / HTTP/1.0'#13#10'Host: localhost'#13#10#13#10;
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(LR.Success, 'should succeed');
  Check(LR.Version = hvHttp10, 'version is HTTP/1.0');
end;

procedure TestIncompleteHeaders;
var
  LReq: AnsiString;
  LR: TFastParseResult;
begin
  LReq := 'GET / HTTP/1.1'#13#10'Host: local';
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(not LR.Success, 'should fail — incomplete');
end;

procedure TestMalformedRequestLine;
var
  LReq: AnsiString;
  LR: TFastParseResult;
begin
  LReq := 'INVALID'#13#10#13#10;
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(not LR.Success, 'should fail — malformed');
end;

procedure TestInvalidSameLengthMethodFallback;
var
  LReq: AnsiString;
  LR: TFastParseResult;
begin
  LReq := 'GUT / HTTP/1.1'#13#10'Host: localhost'#13#10#13#10;
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(not LR.Success, 'should fail — invalid same-length method fallback');
end;

procedure TestChunkedFallback;
var
  LReq: AnsiString;
  LR: TFastParseResult;
begin
  LReq := 'POST /data HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Transfer-Encoding: chunked'#13#10#13#10;
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(not LR.Success, 'should fail — chunked fallback');
end;

procedure TestUnsupportedTransferEncodingFallback;
var
  LReq: AnsiString;
  LR: TFastParseResult;
begin
  LReq := 'POST /data HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Transfer-Encoding: gzip'#13#10#13#10;
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(not LR.Success, 'should fail — transfer-encoding fallback');
end;

procedure TestDuplicateContentLengthFallback;
var
  LReq: AnsiString;
  LR: TFastParseResult;
begin
  LReq := 'POST /data HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Content-Length: 0'#13#10 +
           'Content-Length: 0'#13#10#13#10;
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(not LR.Success, 'should fail — duplicate content-length fallback');
end;

procedure TestInvalidContentLengthFallback;
var
  LReq: AnsiString;
  LR: TFastParseResult;
begin
  LReq := 'POST /data HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Content-Length: nope'#13#10#13#10;
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(not LR.Success, 'should fail — invalid content-length fallback');
end;

procedure TestInvalidHeaderNameFallback;
var
  LReq: AnsiString;
  LR: TFastParseResult;
begin
  LReq := 'GET / HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Bad Header: value'#13#10#13#10;
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(not LR.Success, 'should fail — invalid header name fallback');
end;

procedure TestInvalidHeaderValueFallback;
var
  LReq: AnsiString;
  LR: TFastParseResult;
begin
  LReq := 'GET / HTTP/1.1'#13#10 +
           'Host: local'#0'host'#13#10#13#10;
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(not LR.Success, 'should fail — invalid header value fallback');
end;

procedure TestIncompleteBodyFallback;
var
  LReq: AnsiString;
  LR: TFastParseResult;
begin
  LReq := 'POST /data HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Content-Length: 5'#13#10#13#10 +
           'he';
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(not LR.Success, 'should fail — incomplete body fallback');
end;

procedure TestLargeHeaders;
var
  LReq: AnsiString;
  LR: TFastParseResult;
  LI: Integer;
begin
  LReq := 'GET /big HTTP/1.1'#13#10;
  for LI := 1 to 20 do
    LReq := LReq + 'X-Header-' + IntToStr(Int64(LI)) + ': ' + StringOfChar('v', 50) + #13#10;
  LReq := LReq + #13#10;
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(LR.Success, 'should succeed with large headers');
  CheckEqual(Int64(20), Int64(LR.Headers.Count), '20 headers');
end;

procedure TestPathWithQuery;
var
  LReq: AnsiString;
  LR: TFastParseResult;
begin
  LReq := 'GET /search?q=hello&page=1 HTTP/1.1'#13#10'Host: localhost'#13#10#13#10;
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(LR.Success, 'should succeed');
  CheckEqual('/search?q=hello&page=1', LR.Path, 'path with query preserved');
end;

procedure TestHeaderValueLeadingSpaces;
var
  LReq: AnsiString;
  LR: TFastParseResult;
begin
  LReq := 'GET / HTTP/1.1'#13#10 +
           'Host:   localhost'#13#10 +
           'Accept:  */*'#13#10#13#10;
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(LR.Success, 'should succeed');
  CheckEqual('localhost', LR.Headers.Get('Host'), 'trimmed host');
  CheckEqual('*/*', LR.Headers.Get('Accept'), 'trimmed accept');
end;

procedure TestPolicyHeaderFlags;
var
  LReq: AnsiString;
  LR: TFastParseResult;
begin
  LReq := 'GET / HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Connection: keep-alive'#13#10 +
           'Expect: 100-continue'#13#10#13#10;
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(LR.Success, 'policy request should parse');
  Check(LR.HasHost, 'host flag');
  Check(LR.HasConnection, 'connection flag');
  Check(LR.HasExpect, 'expect flag');
  Check(not LR.HasTransferEncoding, 'transfer-encoding flag absent');

  LReq := 'POST /data HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Transfer-Encoding: chunked'#13#10#13#10;
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(not LR.Success, 'transfer-encoding still falls back');
  Check(LR.HasTransferEncoding, 'transfer-encoding flag');
end;

procedure TestEmptyPath;
var
  LReq: AnsiString;
  LR: TFastParseResult;
begin
  // Two consecutive spaces = empty path
  LReq := 'GET  HTTP/1.1'#13#10'Host: localhost'#13#10#13#10;
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(not LR.Success, 'should fail — empty path');
end;

procedure TestAllMethods;
var
  LR: TFastParseResult;

  function MakeReq(const AMethod: string): AnsiString;
  begin
    Result := AMethod + ' /test HTTP/1.1'#13#10'Host: localhost'#13#10#13#10;
  end;
var
  LReq: AnsiString;
begin
  LReq := MakeReq('GET');
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(LR.Success and (LR.Method = hmGet), 'GET');

  LReq := MakeReq('POST');
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(LR.Success and (LR.Method = hmPost), 'POST');

  LReq := MakeReq('PUT');
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(LR.Success and (LR.Method = hmPut), 'PUT');

  LReq := MakeReq('DELETE');
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(LR.Success and (LR.Method = hmDelete), 'DELETE');

  LReq := MakeReq('PATCH');
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(LR.Success and (LR.Method = hmPatch), 'PATCH');

  LReq := MakeReq('HEAD');
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(LR.Success and (LR.Method = hmHead), 'HEAD');

  LReq := MakeReq('OPTIONS');
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(LR.Success and (LR.Method = hmOptions), 'OPTIONS');

  LReq := MakeReq('CONNECT');
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(LR.Success and (LR.Method = hmConnect), 'CONNECT');
end;

procedure TestDifferential;
var
  LReq: AnsiString;
  LFast: TFastParseResult;
  LP: IH1Parser;
begin
  LReq := 'GET /api/v1/users?page=2 HTTP/1.1'#13#10 +
           'Host: example.com'#13#10 +
           'Accept: application/json'#13#10 +
           'Authorization: Bearer token123'#13#10 +
           'Content-Length: 0'#13#10#13#10;

  // Fast path
  LFast := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(LFast.Success, 'fast path succeeds');

  // llhttp path
  LP := NewH1RequestParser;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(LP.IsComplete, 'llhttp complete');

  // Compare results
  Check(LFast.Method = LP.GetMethod, 'method matches');
  CheckEqual(LP.GetUrl, LFast.Path, 'path matches');
  Check(LFast.Version = LP.GetHttpVersion, 'version matches');
  CheckEqual(LP.GetHeaders.Get('Host'), LFast.Headers.Get('Host'), 'host header matches');
  CheckEqual(LP.GetHeaders.Get('Accept'), LFast.Headers.Get('Accept'), 'accept header matches');
  CheckEqual(LP.GetHeaders.Get('Authorization'), LFast.Headers.Get('Authorization'), 'auth header matches');
end;

procedure TestBodyOffset;
var
  LReq: AnsiString;
  LR: TFastParseResult;
  LBody: string;
begin
  LReq := 'PUT /file HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Content-Length: 11'#13#10#13#10 +
           'hello world';
  LR := FastParseRequest(PAnsiChar(LReq), Length(LReq));
  Check(LR.Success, 'should succeed');
  CheckEqual(Int64(11), LR.ContentLength, 'CL=11');
  SetString(LBody, PAnsiChar(LReq) + LR.BodyStart, LR.ContentLength);
  CheckEqual('hello world', LBody, 'body content');
end;

begin
  T := TTestRunner.Create('nextpas.core.http.impl.h1.fast');
  T.Run('Simple GET', @TestSimpleGet);
  T.Run('POST with Content-Length', @TestPostWithContentLength);
  T.Run('Multiple headers', @TestMultipleHeaders);
  T.Run('HTTP/1.0 version', @TestHttp10Version);
  T.Run('Incomplete headers', @TestIncompleteHeaders);
  T.Run('Malformed request line', @TestMalformedRequestLine);
  T.Run('Invalid same-length method fallback', @TestInvalidSameLengthMethodFallback);
  T.Run('Chunked fallback', @TestChunkedFallback);
  T.Run('Unsupported transfer-encoding fallback', @TestUnsupportedTransferEncodingFallback);
  T.Run('Duplicate Content-Length fallback', @TestDuplicateContentLengthFallback);
  T.Run('Invalid Content-Length fallback', @TestInvalidContentLengthFallback);
  T.Run('Invalid header name fallback', @TestInvalidHeaderNameFallback);
  T.Run('Invalid header value fallback', @TestInvalidHeaderValueFallback);
  T.Run('Incomplete body fallback', @TestIncompleteBodyFallback);
  T.Run('Large headers (>1KB)', @TestLargeHeaders);
  T.Run('Path with query string', @TestPathWithQuery);
  T.Run('Header value leading spaces', @TestHeaderValueLeadingSpaces);
  T.Run('Policy header flags', @TestPolicyHeaderFlags);
  T.Run('Empty path', @TestEmptyPath);
  T.Run('All methods', @TestAllMethods);
  T.Run('Differential (vs llhttp)', @TestDifferential);
  T.Run('Body offset correctness', @TestBodyOffset);
  T.Summary;
end.
