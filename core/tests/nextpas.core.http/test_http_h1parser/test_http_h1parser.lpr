program test_http_h1parser;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.impl.h1.parser;

var
  T: TTestRunner;

procedure TestSimpleGet;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'GET / HTTP/1.1'#13#10'Host: localhost'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(LP.IsComplete, 'should be complete');
  Check(not LP.HasError, 'no error');
  Check(LP.GetMethod = hmGet, 'method is GET');
  CheckEqual('/', LP.GetUrl, 'url is /');
  Check(LP.GetHttpVersion = hvHttp11, 'version is HTTP/1.1');
end;

procedure TestGetWithPath;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'GET /index.html HTTP/1.1'#13#10'Host: localhost'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(LP.IsComplete, 'complete');
  CheckEqual('/index.html', LP.GetUrl, 'url is /index.html');
end;

procedure TestPostWithBody;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /data HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Content-Length: 5'#13#10#13#10 +
           'hello';
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(LP.IsComplete, 'complete');
  Check(LP.GetMethod = hmPost, 'method is POST');
  CheckEqual('hello', LP.GetBody, 'body is hello');
end;

procedure TestMultipleHeaders;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'GET / HTTP/1.1'#13#10 +
           'Host: example.com'#13#10 +
           'Content-Type: text/plain'#13#10 +
           'Accept: */*'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(LP.IsComplete, 'complete');
  CheckEqual('example.com', LP.GetHeaders.Get('Host'), 'host header');
  CheckEqual('text/plain', LP.GetHeaders.Get('Content-Type'), 'content-type');
  CheckEqual('*/*', LP.GetHeaders.Get('Accept'), 'accept');
end;

procedure TestHttp10Version;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'GET / HTTP/1.0'#13#10'Host: localhost'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(LP.IsComplete, 'complete');
  Check(LP.GetHttpVersion = hvHttp10, 'version is HTTP/1.0');
end;

procedure TestResponse200;
var
  LP: IH1Parser;
  LResp: string;
begin
  LP := NewH1ResponseParser;
  LResp := 'HTTP/1.1 200 OK'#13#10 +
            'Content-Length: 5'#13#10#13#10 +
            'hello';
  LP.Execute(PAnsiChar(LResp), Length(LResp));
  Check(LP.IsComplete, 'complete');
  CheckEqual(Int64(200), Int64(LP.GetStatusCode), 'status 200');
  CheckEqual('hello', LP.GetBody, 'body');
end;

procedure TestResponse404;
var
  LP: IH1Parser;
  LResp: string;
begin
  LP := NewH1ResponseParser;
  LResp := 'HTTP/1.1 404 Not Found'#13#10 +
            'Content-Length: 9'#13#10#13#10 +
            'not found';
  LP.Execute(PAnsiChar(LResp), Length(LResp));
  Check(LP.IsComplete, 'complete');
  CheckEqual(Int64(404), Int64(LP.GetStatusCode), 'status 404');
end;

procedure TestResponse204NoBody;
var
  LP: IH1Parser;
  LResp: string;
begin
  LP := NewH1ResponseParser;
  LResp := 'HTTP/1.1 204 No Content'#13#10#13#10;
  LP.Execute(PAnsiChar(LResp), Length(LResp));
  Check(LP.IsComplete, 'complete');
  CheckEqual(Int64(204), Int64(LP.GetStatusCode), 'status 204');
  CheckEqual('', LP.GetBody, 'empty body');
end;

procedure TestResponseCloseDelimitedNeedsConnectionClose;
var
  LP: IH1Parser;
  LResp: string;
begin
  LP := NewH1ResponseParser;
  LResp := 'HTTP/1.1 200 OK'#13#10 +
           'Content-Type: text/plain'#13#10#13#10 +
           'hello';
  LP.Execute(PAnsiChar(LResp), Length(LResp));
  Check(not LP.IsComplete, 'close-delimited body waits for EOF');
  Check(not LP.ShouldKeepAlive, 'close-delimited response is not reusable');
  LP.Finish;
  Check(LP.IsComplete, 'finish marks close-delimited response complete');
  CheckEqual('hello', LP.GetBody, 'body after eof completion');
end;

procedure TestResponseContentLengthKeepsAlive;
var
  LP: IH1Parser;
  LResp: string;
begin
  LP := NewH1ResponseParser;
  LResp := 'HTTP/1.1 200 OK'#13#10 +
           'Content-Length: 5'#13#10#13#10 +
           'hello';
  LP.Execute(PAnsiChar(LResp), Length(LResp));
  Check(LP.IsComplete, 'complete');
  Check(LP.ShouldKeepAlive, 'content-length response is reusable');
end;

procedure TestResponseContentLengthTruncatedAtEof;
var
  LP: IH1Parser;
  LResp: string;
begin
  LP := NewH1ResponseParser;
  LResp := 'HTTP/1.1 200 OK'#13#10 +
           'Content-Length: 10'#13#10#13#10 +
           'hello';
  LP.Execute(PAnsiChar(LResp), Length(LResp));
  Check(not LP.IsComplete, 'truncated content-length response is not complete');
  LP.Finish;
  Check(LP.HasError, 'finish reports truncated content-length as error');
  Check(not LP.IsComplete, 'truncated content-length response stays incomplete');
end;

procedure TestResponseHttp10WithoutKeepAliveDoesNotReuse;
var
  LP: IH1Parser;
  LResp: string;
begin
  LP := NewH1ResponseParser;
  LResp := 'HTTP/1.0 200 OK'#13#10 +
           'Content-Length: 2'#13#10#13#10 +
           'ok';
  LP.Execute(PAnsiChar(LResp), Length(LResp));
  Check(LP.IsComplete, 'complete');
  Check(not LP.ShouldKeepAlive, 'http/1.0 response without keep-alive is not reusable');
end;

procedure TestContentLengthBody;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Content-Length: 11'#13#10#13#10 +
           'hello world';
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(LP.IsComplete, 'complete');
  CheckEqual('hello world', LP.GetBody, 'exact body');
end;

procedure TestChunkedRequestBody;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '6'#13#10' world'#13#10 +
          '0'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(LP.IsComplete, 'chunked request complete');
  Check(LP.GetMethod = hmPost, 'chunked request method POST');
  CheckEqual('hello world', LP.GetBody, 'chunked request body decoded');
end;

procedure TestChunkedRequestInvalidChunkSize;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10#13#10 +
          'Z'#13#10'hello'#13#10 +
          '0'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(LP.HasError, 'invalid chunk size raises parser error');
  Check(not LP.IsComplete, 'invalid chunk size is not complete');
end;

procedure TestChunkedRequestTruncatedAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10#13#10 +
          '5'#13#10'hel';
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated chunked request is not complete');
  LP.Finish;
  Check(LP.HasError, 'truncated chunked request reports error on finish');
  Check(not LP.IsComplete, 'truncated chunked request stays incomplete');
end;

procedure TestChunkedRequestMissingChunkDataCrLf;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10#13#10 +
          '5'#13#10'hello0'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'missing chunk-data CRLF reports parser error');
  Check(not LP.IsComplete, 'missing chunk-data CRLF is not complete');
end;

procedure TestChunkedRequestContentLengthConflict;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Content-Length: 5'#13#10 +
          'Transfer-Encoding: chunked'#13#10#13#10 +
          '0'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'content-length then chunked reports parser error');
  Check(not LP.IsComplete, 'content-length then chunked is not complete');
  Check((Pos('Content-Length', LP.ErrorMessage) > 0) and
        (Pos('Transfer-Encoding', LP.ErrorMessage) > 0),
    'content-length then chunked mentions conflicting framing');
end;

procedure TestChunkedRequestContentLengthConflictReverseOrder;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10 +
          'Content-Length: 5'#13#10#13#10 +
          '0'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'chunked then content-length reports parser error');
  Check(not LP.IsComplete, 'chunked then content-length is not complete');
  Check((Pos('Content-Length', LP.ErrorMessage) > 0) and
        (Pos('Transfer-Encoding', LP.ErrorMessage) > 0),
    'chunked then content-length mentions conflicting framing');
end;

procedure TestChunkedRequestTrailerDoesNotPolluteHeaders;
var
  LP: IH1Parser;
  LReq: string;
  LAll: TStringArray;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10 +
          'Trailer: X-Auth-Context'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0'#13#10 +
          'X-Auth-Context: admin'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.IsComplete, 'chunked trailer request complete');
  Check(not LP.HasError, 'chunked trailer request has no parser error');
  CheckEqual('hello', LP.GetBody, 'chunked trailer request body decoded');
  CheckEqual('X-Auth-Context', LP.GetHeaders.Get('Trailer'),
    'trailer declaration header preserved');
  CheckEqual('', LP.GetHeaders.Get('X-Auth-Context'),
    'trailer field does not appear as regular header');
  LAll := LP.GetHeaders.GetAll('X-Auth-Context');
  CheckEqual(Int64(0), Int64(Length(LAll)),
    'trailer field has no regular header entries');
end;

procedure TestHeadRequest;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'HEAD /status HTTP/1.1'#13#10 +
           'Host: localhost'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(LP.IsComplete, 'complete');
  Check(LP.GetMethod = hmHead, 'method is HEAD');
  CheckEqual('', LP.GetBody, 'no body for HEAD');
end;

procedure TestInvalidRequest;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'INVALID DATA HERE'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(LP.HasError, 'should have error');
  Check(LP.ErrorMessage <> '', 'error message not empty');
end;

procedure TestIncompleteInput;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'GET / HTTP/1.1'#13#10'Host: local';
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'should not be complete');
  Check(not LP.HasError, 'no error on partial');
end;

procedure TestResetAndReparse;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'GET /first HTTP/1.1'#13#10'Host: localhost'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(LP.IsComplete, 'first complete');
  CheckEqual('/first', LP.GetUrl, 'first url');

  LP.Reset;
  LReq := 'POST /second HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Content-Length: 3'#13#10#13#10 +
           'abc';
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(LP.IsComplete, 'second complete');
  Check(LP.GetMethod = hmPost, 'second method POST');
  CheckEqual('/second', LP.GetUrl, 'second url');
  CheckEqual('abc', LP.GetBody, 'second body');
end;

procedure TestRequestWithQuery;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'GET /search?q=test HTTP/1.1'#13#10'Host: localhost'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(LP.IsComplete, 'complete');
  CheckEqual('/search?q=test', LP.GetUrl, 'url with query');
end;

procedure TestMultipleHeadersSameName;
var
  LP: IH1Parser;
  LReq: string;
  LAll: TStringArray;
begin
  LP := NewH1RequestParser;
  LReq := 'GET / HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'X-Custom: value1'#13#10 +
           'X-Custom: value2'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(LP.IsComplete, 'complete');
  LAll := LP.GetHeaders.GetAll('X-Custom');
  CheckEqual(Int64(2), Int64(Length(LAll)), 'two values');
  CheckEqual('value1', LAll[0], 'first value');
  CheckEqual('value2', LAll[1], 'second value');
end;

begin
  T := TTestRunner.Create('nextpas.core.http.impl.h1.parser');
  T.Run('Simple GET', @TestSimpleGet);
  T.Run('GET with path', @TestGetWithPath);
  T.Run('POST with body', @TestPostWithBody);
  T.Run('Multiple headers', @TestMultipleHeaders);
  T.Run('HTTP/1.0 version', @TestHttp10Version);
  T.Run('Response 200', @TestResponse200);
  T.Run('Response 404', @TestResponse404);
  T.Run('Response 204 no body', @TestResponse204NoBody);
  T.Run('Response close-delimited needs connection close', @TestResponseCloseDelimitedNeedsConnectionClose);
  T.Run('Response content-length keeps alive', @TestResponseContentLengthKeepsAlive);
  T.Run('Response content-length truncated at EOF', @TestResponseContentLengthTruncatedAtEof);
  T.Run('Response HTTP/1.0 without keep-alive does not reuse', @TestResponseHttp10WithoutKeepAliveDoesNotReuse);
  T.Run('Content-Length body', @TestContentLengthBody);
  T.Run('Chunked request body', @TestChunkedRequestBody);
  T.Run('Chunked request invalid chunk size', @TestChunkedRequestInvalidChunkSize);
  T.Run('Chunked request truncated at EOF', @TestChunkedRequestTruncatedAtEof);
  T.Run('Chunked request missing chunk-data CRLF', @TestChunkedRequestMissingChunkDataCrLf);
  T.Run('Chunked request content-length conflict', @TestChunkedRequestContentLengthConflict);
  T.Run('Chunked request content-length conflict reverse order', @TestChunkedRequestContentLengthConflictReverseOrder);
  T.Run('Chunked request trailer does not pollute headers', @TestChunkedRequestTrailerDoesNotPolluteHeaders);
  T.Run('HEAD request', @TestHeadRequest);
  T.Run('Invalid request', @TestInvalidRequest);
  T.Run('Incomplete input', @TestIncompleteInput);
  T.Run('Reset and reparse', @TestResetAndReparse);
  T.Run('Request with query', @TestRequestWithQuery);
  T.Run('Multiple headers same name', @TestMultipleHeadersSameName);
  T.Summary;
end.
