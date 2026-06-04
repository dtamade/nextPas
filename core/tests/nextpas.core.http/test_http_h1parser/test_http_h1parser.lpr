program test_http_h1parser;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.impl.h1.parser;

var
  T: TTestRunner;

function ReadReaderStr(const AReader: IReader): string;
var
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  if AReader = nil then
    Exit;
  repeat
    LN := AReader.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
    if LN > 0 then
    begin
      SetLength(Result, Length(Result) + Int32(LN));
      Move(LBuf[0], Result[Length(Result) - Int32(LN) + 1], LN);
    end;
  until LN = 0;
end;

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

procedure TestResponseHeadSkipBodyWithContentLength;
var
  LP: IH1Parser;
  LResp: string;
begin
  LP := NewH1ResponseParser(True);
  LResp := 'HTTP/1.1 200 OK'#13#10 +
           'Content-Length: 5'#13#10#13#10;
  LP.Execute(PAnsiChar(LResp), Length(LResp));
  Check(LP.IsComplete, 'head-like response completes without body bytes');
  Check(LP.ShouldKeepAlive, 'head-like content-length response is reusable');
  CheckEqual(Int64(200), Int64(LP.GetStatusCode), 'status 200');
  CheckEqual('', LP.GetBody, 'head-like response stores no body');
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

procedure TestContentLengthRequestTruncatedAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Content-Length: 10'#13#10#13#10 +
          'hello';
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated content-length request is not complete');
  LP.Finish;
  Check(LP.HasError, 'finish reports truncated content-length request as error');
  Check(not LP.IsComplete, 'truncated content-length request stays incomplete');
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

procedure TestRequestBodyReaderView;
var
  LP: IH1Parser;
  LReq: string;
  LReader1, LReader2: IReader;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Content-Length: 11'#13#10#13#10 +
          'hello world';
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(LP.IsComplete, 'request complete');
  CheckEqual(Int64(11), LP.GetBodySize, 'request body size');
  LReader1 := LP.NewBodyReader;
  Check(LReader1 <> nil, 'request body reader 1');
  CheckEqual('hello world', ReadReaderStr(LReader1), 'request body reader 1 contents');
  LReader2 := LP.NewBodyReader;
  Check(LReader2 <> nil, 'request body reader 2');
  CheckEqual('hello world', ReadReaderStr(LReader2), 'request body reader 2 contents');
end;

procedure TestResponseBodyReaderView;
var
  LP: IH1Parser;
  LResp: string;
  LReader: IReader;
begin
  LP := NewH1ResponseParser;
  LResp := 'HTTP/1.1 200 OK'#13#10 +
           'Content-Length: 5'#13#10#13#10 +
           'hello';
  LP.Execute(PAnsiChar(LResp), Length(LResp));
  Check(LP.IsComplete, 'response complete');
  CheckEqual(Int64(5), LP.GetBodySize, 'response body size');
  LReader := LP.NewBodyReader;
  Check(LReader <> nil, 'response body reader');
  CheckEqual('hello', ReadReaderStr(LReader), 'response body reader contents');
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

procedure TestChunkedRequestMalformedChunkExtension;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10#13#10 +
          '5;'#13#10'hello'#13#10 +
          '0'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'malformed chunk extension reports parser error');
  Check(not LP.IsComplete, 'malformed chunk extension is not complete');
end;

procedure TestChunkedRequestTruncatedChunkExtensionAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10#13#10 +
          '5;sig=abc';
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated chunk extension is not complete');
  LP.Finish;
  Check(LP.HasError, 'truncated chunk extension reports error on finish');
  Check(not LP.IsComplete, 'truncated chunk extension stays incomplete');
end;

procedure TestChunkedRequestTruncatedChunkExtensionCrAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10#13#10 +
          '5;sig=abc'#13;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated chunk extension CR is not complete');
  LP.Finish;
  Check(LP.HasError, 'truncated chunk extension CR reports error on finish');
  Check(not LP.IsComplete, 'truncated chunk extension CR stays incomplete');
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

procedure TestChunkedRequestTruncatedChunkSizeLineAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10#13#10 +
          '5';
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated chunk-size line is not complete');
  LP.Finish;
  Check(LP.HasError, 'truncated chunk-size line reports error on finish');
  Check(not LP.IsComplete, 'truncated chunk-size line stays incomplete');
end;

procedure TestChunkedRequestTruncatedTerminalChunkEndingAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0'#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated terminal chunk ending is not complete');
  LP.Finish;
  Check(LP.HasError, 'truncated terminal chunk ending reports error on finish');
  Check(not LP.IsComplete, 'truncated terminal chunk ending stays incomplete');
end;

procedure TestChunkedRequestTruncatedTerminalChunkEndingCrAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0'#13#10#13;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated terminal chunk ending CR is not complete');
  LP.Finish;
  Check(LP.HasError, 'truncated terminal chunk ending CR reports error on finish');
  Check(not LP.IsComplete, 'truncated terminal chunk ending CR stays incomplete');
end;

procedure TestChunkedRequestTruncatedTerminalChunkExtensionAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0;sig=abc';
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated terminal chunk extension is not complete');
  LP.Finish;
  Check(LP.HasError, 'truncated terminal chunk extension reports error on finish');
  Check(not LP.IsComplete, 'truncated terminal chunk extension stays incomplete');
end;

procedure TestChunkedRequestTruncatedTerminalChunkExtensionCrAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0;sig=abc'#13;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated terminal chunk extension CR is not complete');
  LP.Finish;
  Check(LP.HasError, 'truncated terminal chunk extension CR reports error on finish');
  Check(not LP.IsComplete, 'truncated terminal chunk extension CR stays incomplete');
end;

procedure TestChunkedRequestTruncatedTerminalChunkEndingAfterExtensionAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0;sig=abc'#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated terminal chunk ending after extension is not complete');
  LP.Finish;
  Check(LP.HasError, 'truncated terminal chunk ending after extension reports error on finish');
  Check(not LP.IsComplete, 'truncated terminal chunk ending after extension stays incomplete');
end;

procedure TestChunkedRequestTruncatedTerminalChunkEndingAfterExtensionCrAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0;sig=abc'#13#10#13;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated terminal chunk ending after extension CR is not complete');
  LP.Finish;
  Check(LP.HasError, 'truncated terminal chunk ending after extension CR reports error on finish');
  Check(not LP.IsComplete, 'truncated terminal chunk ending after extension CR stays incomplete');
end;

procedure TestChunkedRequestTruncatedChunkDataEndingAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10#13#10 +
          '5'#13#10'hello';
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated chunk-data ending is not complete');
  LP.Finish;
  Check(LP.HasError, 'truncated chunk-data ending reports error on finish');
  Check(not LP.IsComplete, 'truncated chunk-data ending stays incomplete');
end;

procedure TestChunkedRequestTruncatedChunkDataCrAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10#13#10 +
          '5'#13#10'hello'#13;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated chunk-data CR is not complete');
  LP.Finish;
  Check(LP.HasError, 'truncated chunk-data CR reports error on finish');
  Check(not LP.IsComplete, 'truncated chunk-data CR stays incomplete');
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

procedure TestChunkedRequestUnsupportedTransferCodingBeforeChunked;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: gzip, chunked'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'unsupported transfer coding before chunked reports parser error');
  Check(not LP.IsComplete,
    'unsupported transfer coding before chunked is not complete');
  Check(LP.ErrorKind = pekUnsupportedTransferCoding,
    'unsupported transfer coding before chunked reports unsupported coding kind');
end;

procedure TestChunkedRequestChunkedMustBeFinalTransferCoding;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked, gzip'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'chunked must be final transfer coding reports parser error');
  Check(not LP.IsComplete,
    'chunked must be final transfer coding is not complete');
  Check(LP.ErrorKind = pekMalformed,
    'chunked must be final transfer coding reports malformed kind');
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

procedure TestChunkedRequestTrailerBytesTrackLateTrailer;
var
  LP: IH1Parser;
  LPart1: string;
  LPart2: string;
begin
  LP := NewH1RequestParser;
  LPart1 := 'POST /upload HTTP/1.1'#13#10 +
            'Host: localhost'#13#10 +
            'Transfer-Encoding: chunked'#13#10 +
            'Trailer: X-Big'#13#10#13#10 +
            '5'#13#10'hello'#13#10;
  LPart2 := '0'#13#10 +
            'X-Big: value'#13#10#13#10;
  LP.Execute(PAnsiChar(LPart1), Length(LPart1));
  Check(not LP.IsComplete, 'late trailer part1 not complete');
  CheckEqual(Int64(0), LP.GetTrailerBytes,
    'late trailer part1 has no trailer bytes yet');
  LP.Execute(PAnsiChar(LPart2), Length(LPart2));
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.IsComplete, 'late trailer request complete');
  Check(not LP.HasError, 'late trailer request has no parser error');
  CheckEqual(Int64(14), LP.GetTrailerBytes,
    'late trailer bytes count field value and framing');
  LP.Reset;
  CheckEqual(Int64(0), LP.GetTrailerBytes,
    'reset clears trailer byte count');
end;

procedure TestChunkedRequestInvalidTrailerField;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10 +
          'Trailer: X-Bad'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0'#13#10 +
          'Bad Header: value'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'invalid trailer field reports parser error');
  Check(not LP.IsComplete, 'invalid trailer field is not complete');
end;

procedure TestChunkedRequestTruncatedTrailerAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10 +
          'Trailer: X-Test'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0'#13#10 +
          'X-Test: value'#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated trailer request is not complete');
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'truncated trailer request reports parser error');
  Check(not LP.IsComplete, 'truncated trailer request stays incomplete');
end;

procedure TestChunkedRequestTruncatedTrailerFieldNameAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10 +
          'Trailer: X-Test'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0'#13#10 +
          'X-Test';
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated trailer field-name request is not complete');
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'truncated trailer field-name request reports parser error');
  Check(not LP.IsComplete, 'truncated trailer field-name request stays incomplete');
end;

procedure TestChunkedRequestTruncatedTrailerSeparatorAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10 +
          'Trailer: X-Test'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0'#13#10 +
          'X-Test:';
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated trailer separator request is not complete');
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'truncated trailer separator request reports parser error');
  Check(not LP.IsComplete, 'truncated trailer separator request stays incomplete');
end;

procedure TestChunkedRequestTruncatedTrailerEmptyValueCrAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10 +
          'Trailer: X-Test'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0'#13#10 +
          'X-Test:'#13;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated trailer empty-value CR request is not complete');
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'truncated trailer empty-value CR request reports parser error');
  Check(not LP.IsComplete, 'truncated trailer empty-value CR request stays incomplete');
end;

procedure TestChunkedRequestTruncatedTrailerEmptyValueAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10 +
          'Trailer: X-Test'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0'#13#10 +
          'X-Test:'#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated trailer empty-value request is not complete');
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'truncated trailer empty-value request reports parser error');
  Check(not LP.IsComplete, 'truncated trailer empty-value request stays incomplete');
end;

procedure TestChunkedRequestTruncatedTrailerEmptyValueSectionCrAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10 +
          'Trailer: X-Test'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0'#13#10 +
          'X-Test:'#13#10#13;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated trailer empty-value section CR request is not complete');
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'truncated trailer empty-value section CR request reports parser error');
  Check(not LP.IsComplete, 'truncated trailer empty-value section CR request stays incomplete');
end;

procedure TestChunkedRequestTruncatedTrailerWhitespaceAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10 +
          'Trailer: X-Test'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0'#13#10 +
          'X-Test: ';
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated trailer whitespace request is not complete');
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'truncated trailer whitespace request reports parser error');
  Check(not LP.IsComplete, 'truncated trailer whitespace request stays incomplete');
end;

procedure TestChunkedRequestTruncatedTrailerWhitespaceCrAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10 +
          'Trailer: X-Test'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0'#13#10 +
          'X-Test: '#13;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated trailer whitespace CR request is not complete');
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'truncated trailer whitespace CR request reports parser error');
  Check(not LP.IsComplete, 'truncated trailer whitespace CR request stays incomplete');
end;

procedure TestChunkedRequestTruncatedTrailerWhitespaceSectionAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10 +
          'Trailer: X-Test'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0'#13#10 +
          'X-Test: '#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated trailer whitespace section request is not complete');
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'truncated trailer whitespace section request reports parser error');
  Check(not LP.IsComplete, 'truncated trailer whitespace section request stays incomplete');
end;

procedure TestChunkedRequestTruncatedTrailerWhitespaceSectionCrAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10 +
          'Trailer: X-Test'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0'#13#10 +
          'X-Test: '#13#10#13;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated trailer whitespace section CR request is not complete');
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'truncated trailer whitespace section CR request reports parser error');
  Check(not LP.IsComplete, 'truncated trailer whitespace section CR request stays incomplete');
end;

procedure TestChunkedRequestTruncatedTrailerFieldLineAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10 +
          'Trailer: X-Test'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0'#13#10 +
          'X-Test: value';
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated trailer field line request is not complete');
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'truncated trailer field line request reports parser error');
  Check(not LP.IsComplete, 'truncated trailer field line request stays incomplete');
end;

procedure TestChunkedRequestTruncatedTrailerFieldCrAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10 +
          'Trailer: X-Test'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0'#13#10 +
          'X-Test: value'#13;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated trailer field CR request is not complete');
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'truncated trailer field CR request reports parser error');
  Check(not LP.IsComplete, 'truncated trailer field CR request stays incomplete');
end;

procedure TestChunkedRequestTruncatedTrailerCrAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10 +
          'Trailer: X-Test'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0'#13#10 +
          'X-Test: value'#13#10#13;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated trailer CR request is not complete');
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'truncated trailer CR request reports parser error');
  Check(not LP.IsComplete, 'truncated trailer CR request stays incomplete');
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
  Check(LP.HasError, 'generic malformed request reports parser error');
  Check(not LP.IsComplete, 'generic malformed request is not complete');
  Check(LP.ErrorMessage <> '', 'generic malformed request has error message');
end;

procedure TestDuplicateContentLength;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Content-Length: 5'#13#10 +
          'Content-Length: 10'#13#10#13#10 +
          'hello';
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'duplicate content-length reports parser error');
  Check(not LP.IsComplete, 'duplicate content-length is not complete');
  Check(Pos('Content-Length', LP.ErrorMessage) > 0,
    'duplicate content-length error mentions content-length');
end;

procedure TestHeaderNullByte;
var
  LP: IH1Parser;
  LReq: array of Byte;
const
  PREFIX = 'GET / HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'X-Evil: foo';
  SUFFIX = 'bar'#13#10#13#10;
begin
  LP := NewH1RequestParser;
  SetLength(LReq, Length(PREFIX) + 1 + Length(SUFFIX));
  Move(PREFIX[1], LReq[0], Length(PREFIX));
  LReq[Length(PREFIX)] := 0;
  Move(SUFFIX[1], LReq[Length(PREFIX) + 1], Length(SUFFIX));
  LP.Execute(PAnsiChar(@LReq[0]), SizeUInt(Length(LReq)));
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'null byte in header reports parser error');
  Check(not LP.IsComplete, 'null byte in header is not complete');
  Check(LP.ErrorMessage <> '', 'null byte in header has error message');
end;

procedure TestHttp09RequestRejected;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'GET /'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'http09 request reports parser error');
  Check(not LP.IsComplete, 'http09 request is not complete');
  Check(LP.ErrorMessage <> '', 'http09 request has error message');
end;

procedure TestRequestLineSplittingRejected;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'GET /path'#13#10 +
          'Injected: header HTTP/1.1'#13#10 +
          'Host: localhost'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'request-line splitting reports parser error');
  Check(not LP.IsComplete, 'request-line splitting is not complete');
  Check(LP.ErrorMessage <> '', 'request-line splitting has error message');
end;

procedure TestNegativeContentLengthRejected;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Content-Length: -1'#13#10#13#10 +
          'hello';
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'negative content-length reports parser error');
  Check(not LP.IsComplete, 'negative content-length is not complete');
  Check(LP.ErrorMessage <> '', 'negative content-length has error message');
end;

procedure TestVeryLongMethodRejected;
var
  LP: IH1Parser;
  LReq: string;
  LMethod: string;
begin
  LP := NewH1RequestParser;
  SetLength(LMethod, 1000);
  FillChar(LMethod[1], 1000, Ord('X'));
  LReq := LMethod + ' / HTTP/1.1'#13#10 +
          'Host: localhost'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'very long method reports parser error');
  Check(not LP.IsComplete, 'very long method is not complete');
  Check(LP.ErrorMessage <> '', 'very long method has error message');
end;

procedure TestContentLengthRequestExtraBytesAfterCloseRejected;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Content-Length: 5'#13#10 +
          'Connection: close'#13#10#13#10 +
          'hello_extra_bytes_here';
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'extra bytes after content-length close reports parser error');
  Check(not LP.IsComplete, 'extra bytes after content-length close is not complete');
  Check(LP.ErrorMessage <> '', 'extra bytes after content-length close has error message');
end;

procedure TestContentLengthKeepAliveGarbageTailConsumesFirstRequestOnly;
var
  LP: IH1Parser;
  LReq1: string;
  LReq: string;
  LConsumed: SizeUInt;
begin
  LP := NewH1RequestParser;
  LReq1 := 'POST /upload HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Content-Length: 5'#13#10#13#10 +
           'hello';
  LReq := LReq1 + '_extra_bytes_here';
  LConsumed := LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.HasError, 'keep-alive content-length tail should not corrupt first request');
  Check(LP.IsComplete, 'keep-alive content-length first request should complete');
  CheckEqual(SizeUInt(Length(LReq1)), LConsumed, 'keep-alive content-length parser consumes only first request');
  Check(LP.GetMethod = hmPost, 'keep-alive content-length first request preserves POST method');
  CheckEqual('/upload', LP.GetUrl, 'keep-alive content-length first request preserves url');
  CheckEqual('hello', LP.GetBody, 'keep-alive content-length first request preserves body');
end;

procedure TestContentLengthKeepAliveTruncatedFollowUpRequestLineConsumesFirstRequestOnly;
var
  LP: IH1Parser;
  LReq1: string;
  LTail: string;
  LReq: string;
  LConsumed: SizeUInt;
begin
  LP := NewH1RequestParser;
  LReq1 := 'POST /upload HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Content-Length: 5'#13#10#13#10 +
           'hello';
  LTail := 'GET /next HTTP/1.1';
  LReq := LReq1 + LTail;
  LConsumed := LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.HasError, 'keep-alive content-length partial follow-up line should not corrupt first request');
  Check(LP.IsComplete, 'keep-alive content-length first request should complete before partial follow-up line');
  CheckEqual(SizeUInt(Length(LReq1)), LConsumed, 'keep-alive content-length parser consumes only first request before partial follow-up line');
  Check(LP.GetMethod = hmPost, 'keep-alive content-length partial follow-up line preserves POST method');
  CheckEqual('/upload', LP.GetUrl, 'keep-alive content-length partial follow-up line preserves url');
  CheckEqual('hello', LP.GetBody, 'keep-alive content-length partial follow-up line preserves body');

  LP.Reset;
  LP.Execute(PAnsiChar(LTail), Length(LTail));
  Check(not LP.IsComplete, 'partial follow-up request line alone is not complete');
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'partial follow-up request line reports parser error on finish');
end;

procedure TestContentLengthKeepAlivePartialFollowUpRequestLineCanCompleteLater;
var
  LP: IH1Parser;
  LReq1: string;
  LTail1: string;
  LTail2: string;
  LConsumed: SizeUInt;
begin
  LP := NewH1RequestParser;
  LReq1 := 'POST /upload HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Content-Length: 5'#13#10#13#10 +
           'hello';
  LTail1 := 'GET /next HTTP/1.1';
  LTail2 := #13#10 +
            'Host: localhost'#13#10#13#10;

  LConsumed := LP.Execute(PAnsiChar(LReq1 + LTail1), Length(LReq1 + LTail1));
  Check(not LP.HasError, 'partial follow-up line should not corrupt first content-length request');
  Check(LP.IsComplete, 'first content-length request should complete before follow-up line finishes');
  CheckEqual(SizeUInt(Length(LReq1)), LConsumed, 'parser should consume only the first content-length request before follow-up line completes');

  LP.Reset;
  LP.Execute(PAnsiChar(LTail1 + LTail2), Length(LTail1 + LTail2));
  Check(not LP.HasError, 'completed content-length follow-up line should parse cleanly');
  Check(LP.IsComplete, 'completed content-length follow-up line should finish as a valid second request');
  Check(LP.GetMethod = hmGet, 'completed content-length follow-up line preserves GET method');
  CheckEqual('/next', LP.GetUrl, 'completed content-length follow-up line preserves second request url');
  CheckEqual('', LP.GetBody, 'completed content-length follow-up line has no body');
end;

procedure TestContentLengthKeepAliveTruncatedFollowUpHeadersConsumesFirstRequestOnly;
var
  LP: IH1Parser;
  LReq1: string;
  LTail: string;
  LReq: string;
  LConsumed: SizeUInt;
begin
  LP := NewH1RequestParser;
  LReq1 := 'POST /upload HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Content-Length: 5'#13#10#13#10 +
           'hello';
  LTail := 'GET /next HTTP/1.1'#13#10 +
           'Host: localhost'#13#10;
  LReq := LReq1 + LTail;
  LConsumed := LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.HasError, 'keep-alive content-length partial follow-up headers should not corrupt first request');
  Check(LP.IsComplete, 'keep-alive content-length first request should complete before partial follow-up headers');
  CheckEqual(SizeUInt(Length(LReq1)), LConsumed, 'keep-alive content-length parser consumes only first request before partial follow-up headers');
  Check(LP.GetMethod = hmPost, 'keep-alive content-length partial follow-up headers preserves POST method');
  CheckEqual('/upload', LP.GetUrl, 'keep-alive content-length partial follow-up headers preserves url');
  CheckEqual('hello', LP.GetBody, 'keep-alive content-length partial follow-up headers preserves body');

  LP.Reset;
  LP.Execute(PAnsiChar(LTail), Length(LTail));
  Check(not LP.IsComplete, 'partial follow-up headers alone are not complete');
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'partial follow-up headers report parser error on finish');
end;

procedure TestContentLengthKeepAlivePartialFollowUpHeadersCanCompleteLater;
var
  LP: IH1Parser;
  LReq1: string;
  LTail1: string;
  LTail2: string;
  LConsumed: SizeUInt;
begin
  LP := NewH1RequestParser;
  LReq1 := 'POST /upload HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Content-Length: 5'#13#10#13#10 +
           'hello';
  LTail1 := 'GET /next HTTP/1.1'#13#10 +
            'Host: localhost'#13#10;
  LTail2 := 'Connection: close'#13#10#13#10;

  LConsumed := LP.Execute(PAnsiChar(LReq1 + LTail1), Length(LReq1 + LTail1));
  Check(not LP.HasError, 'partial follow-up headers should not corrupt first content-length request');
  Check(LP.IsComplete, 'first content-length request should complete before follow-up headers finish');
  CheckEqual(SizeUInt(Length(LReq1)), LConsumed, 'parser should consume only the first content-length request before follow-up headers complete');

  LP.Reset;
  LP.Execute(PAnsiChar(LTail1 + LTail2), Length(LTail1 + LTail2));
  Check(not LP.HasError, 'completed content-length follow-up headers should parse cleanly');
  Check(LP.IsComplete, 'completed content-length follow-up headers should finish as a valid second request');
  Check(LP.GetMethod = hmGet, 'completed content-length follow-up headers preserve GET method');
  CheckEqual('/next', LP.GetUrl, 'completed content-length follow-up headers preserve second request url');
  CheckEqual('', LP.GetBody, 'completed content-length follow-up headers have no body');
end;

procedure TestChunkedRequestExtraBytesAfterCloseRejected;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'POST /upload HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Transfer-Encoding: chunked'#13#10 +
          'Connection: close'#13#10#13#10 +
          '5'#13#10'hello'#13#10 +
          '0'#13#10#13#10 +
          'garbage';
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'extra bytes after chunked close reports parser error');
  Check(not LP.IsComplete, 'extra bytes after chunked close is not complete');
  Check(LP.ErrorMessage <> '', 'extra bytes after chunked close has error message');
end;

procedure TestChunkedKeepAliveGarbageTailConsumesFirstRequestOnly;
var
  LP: IH1Parser;
  LReq1: string;
  LReq: string;
  LConsumed: SizeUInt;
begin
  LP := NewH1RequestParser;
  LReq1 := 'POST /upload HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Transfer-Encoding: chunked'#13#10#13#10 +
           '5'#13#10'hello'#13#10 +
           '0'#13#10#13#10;
  LReq := LReq1 + 'garbage';
  LConsumed := LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.HasError, 'keep-alive chunked tail should not corrupt first request');
  Check(LP.IsComplete, 'keep-alive chunked first request should complete');
  CheckEqual(SizeUInt(Length(LReq1)), LConsumed, 'keep-alive chunked parser consumes only first request');
  Check(LP.GetMethod = hmPost, 'keep-alive chunked first request preserves POST method');
  CheckEqual('/upload', LP.GetUrl, 'keep-alive chunked first request preserves url');
  CheckEqual('hello', LP.GetBody, 'keep-alive chunked first request preserves body');
end;

procedure TestChunkedKeepAliveTruncatedFollowUpRequestLineConsumesFirstRequestOnly;
var
  LP: IH1Parser;
  LReq1: string;
  LTail: string;
  LReq: string;
  LConsumed: SizeUInt;
begin
  LP := NewH1RequestParser;
  LReq1 := 'POST /upload HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Transfer-Encoding: chunked'#13#10#13#10 +
           '5'#13#10'hello'#13#10 +
           '0'#13#10#13#10;
  LTail := 'GET /next HTTP/1.1';
  LReq := LReq1 + LTail;
  LConsumed := LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.HasError, 'keep-alive chunked partial follow-up line should not corrupt first request');
  Check(LP.IsComplete, 'keep-alive chunked first request should complete before partial follow-up line');
  CheckEqual(SizeUInt(Length(LReq1)), LConsumed, 'keep-alive chunked parser consumes only first request before partial follow-up line');
  Check(LP.GetMethod = hmPost, 'keep-alive chunked partial follow-up line preserves POST method');
  CheckEqual('/upload', LP.GetUrl, 'keep-alive chunked partial follow-up line preserves url');
  CheckEqual('hello', LP.GetBody, 'keep-alive chunked partial follow-up line preserves decoded body');

  LP.Reset;
  LP.Execute(PAnsiChar(LTail), Length(LTail));
  Check(not LP.IsComplete, 'chunked partial follow-up request line alone is not complete');
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'chunked partial follow-up request line reports parser error on finish');
end;

procedure TestChunkedKeepAlivePartialFollowUpRequestLineCanCompleteLater;
var
  LP: IH1Parser;
  LReq1: string;
  LTail1: string;
  LTail2: string;
  LConsumed: SizeUInt;
begin
  LP := NewH1RequestParser;
  LReq1 := 'POST /upload HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Transfer-Encoding: chunked'#13#10#13#10 +
           '5'#13#10'hello'#13#10 +
           '0'#13#10#13#10;
  LTail1 := 'GET /next HTTP/1.1';
  LTail2 := #13#10 +
            'Host: localhost'#13#10#13#10;

  LConsumed := LP.Execute(PAnsiChar(LReq1 + LTail1), Length(LReq1 + LTail1));
  Check(not LP.HasError, 'partial follow-up line should not corrupt first chunked request');
  Check(LP.IsComplete, 'first chunked request should complete before follow-up line finishes');
  CheckEqual(SizeUInt(Length(LReq1)), LConsumed, 'parser should consume only the first chunked request before follow-up line completes');

  LP.Reset;
  LP.Execute(PAnsiChar(LTail1 + LTail2), Length(LTail1 + LTail2));
  Check(not LP.HasError, 'completed chunked follow-up line should parse cleanly');
  Check(LP.IsComplete, 'completed chunked follow-up line should finish as a valid second request');
  Check(LP.GetMethod = hmGet, 'completed chunked follow-up line preserves GET method');
  CheckEqual('/next', LP.GetUrl, 'completed chunked follow-up line preserves second request url');
  CheckEqual('', LP.GetBody, 'completed chunked follow-up line has no body');
end;

procedure TestChunkedKeepAliveTruncatedFollowUpHeadersConsumesFirstRequestOnly;
var
  LP: IH1Parser;
  LReq1: string;
  LTail: string;
  LReq: string;
  LConsumed: SizeUInt;
begin
  LP := NewH1RequestParser;
  LReq1 := 'POST /upload HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Transfer-Encoding: chunked'#13#10#13#10 +
           '5'#13#10'hello'#13#10 +
           '0'#13#10#13#10;
  LTail := 'GET /next HTTP/1.1'#13#10 +
           'Host: localhost'#13#10;
  LReq := LReq1 + LTail;
  LConsumed := LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.HasError, 'keep-alive chunked partial follow-up headers should not corrupt first request');
  Check(LP.IsComplete, 'keep-alive chunked first request should complete before partial follow-up headers');
  CheckEqual(SizeUInt(Length(LReq1)), LConsumed, 'keep-alive chunked parser consumes only first request before partial follow-up headers');
  Check(LP.GetMethod = hmPost, 'keep-alive chunked partial follow-up headers preserves POST method');
  CheckEqual('/upload', LP.GetUrl, 'keep-alive chunked partial follow-up headers preserves url');
  CheckEqual('hello', LP.GetBody, 'keep-alive chunked partial follow-up headers preserves decoded body');

  LP.Reset;
  LP.Execute(PAnsiChar(LTail), Length(LTail));
  Check(not LP.IsComplete, 'chunked partial follow-up headers alone are not complete');
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'chunked partial follow-up headers report parser error on finish');
end;

procedure TestChunkedKeepAlivePartialFollowUpHeadersCanCompleteLater;
var
  LP: IH1Parser;
  LReq1: string;
  LTail1: string;
  LTail2: string;
  LConsumed: SizeUInt;
begin
  LP := NewH1RequestParser;
  LReq1 := 'POST /upload HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Transfer-Encoding: chunked'#13#10#13#10 +
           '5'#13#10'hello'#13#10 +
           '0'#13#10#13#10;
  LTail1 := 'GET /next HTTP/1.1'#13#10 +
            'Host: localhost'#13#10;
  LTail2 := 'Connection: close'#13#10#13#10;

  LConsumed := LP.Execute(PAnsiChar(LReq1 + LTail1), Length(LReq1 + LTail1));
  Check(not LP.HasError, 'partial follow-up headers should not corrupt first chunked request');
  Check(LP.IsComplete, 'first chunked request should complete before follow-up headers finish');
  CheckEqual(SizeUInt(Length(LReq1)), LConsumed, 'parser should consume only the first chunked request before follow-up headers complete');

  LP.Reset;
  LP.Execute(PAnsiChar(LTail1 + LTail2), Length(LTail1 + LTail2));
  Check(not LP.HasError, 'completed chunked follow-up headers should parse cleanly');
  Check(LP.IsComplete, 'completed chunked follow-up headers should finish as a valid second request');
  Check(LP.GetMethod = hmGet, 'completed chunked follow-up headers preserve GET method');
  CheckEqual('/next', LP.GetUrl, 'completed chunked follow-up headers preserve second request url');
  CheckEqual('', LP.GetBody, 'completed chunked follow-up headers have no body');
end;

procedure TestChunkedTrailerKeepAliveGarbageTailConsumesFirstRequestOnly;
var
  LP: IH1Parser;
  LReq1: string;
  LReq: string;
  LConsumed: SizeUInt;
begin
  LP := NewH1RequestParser;
  LReq1 := 'POST /upload HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Transfer-Encoding: chunked'#13#10 +
           'Trailer: X-Test'#13#10#13#10 +
           '5'#13#10'hello'#13#10 +
           '0'#13#10 +
           'X-Test: value'#13#10#13#10;
  LReq := LReq1 + 'garbage';
  LConsumed := LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.HasError, 'keep-alive chunked trailer tail should not corrupt first request');
  Check(LP.IsComplete, 'keep-alive chunked trailer first request should complete');
  CheckEqual(SizeUInt(Length(LReq1)), LConsumed, 'keep-alive chunked trailer parser consumes only first request');
  Check(LP.GetMethod = hmPost, 'keep-alive chunked trailer first request preserves POST method');
  CheckEqual('/upload', LP.GetUrl, 'keep-alive chunked trailer first request preserves url');
  CheckEqual('hello', LP.GetBody, 'keep-alive chunked trailer first request preserves decoded body');
  CheckEqual('X-Test', LP.GetHeaders.Get('Trailer'), 'keep-alive chunked trailer declaration header preserved');
  CheckEqual('', LP.GetHeaders.Get('X-Test'), 'keep-alive chunked trailer field stays out of regular headers');
end;

procedure TestChunkedTrailerKeepAliveTruncatedFollowUpRequestLineConsumesFirstRequestOnly;
var
  LP: IH1Parser;
  LReq1: string;
  LTail: string;
  LReq: string;
  LConsumed: SizeUInt;
begin
  LP := NewH1RequestParser;
  LReq1 := 'POST /upload HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Transfer-Encoding: chunked'#13#10 +
           'Trailer: X-Test'#13#10#13#10 +
           '5'#13#10'hello'#13#10 +
           '0'#13#10 +
           'X-Test: value'#13#10#13#10;
  LTail := 'GET /next HTTP/1.1';
  LReq := LReq1 + LTail;
  LConsumed := LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.HasError, 'keep-alive chunked trailer partial follow-up line should not corrupt first request');
  Check(LP.IsComplete, 'keep-alive chunked trailer first request should complete before partial follow-up line');
  CheckEqual(SizeUInt(Length(LReq1)), LConsumed, 'keep-alive chunked trailer parser consumes only first request before partial follow-up line');
  Check(LP.GetMethod = hmPost, 'keep-alive chunked trailer partial follow-up line preserves POST method');
  CheckEqual('/upload', LP.GetUrl, 'keep-alive chunked trailer partial follow-up line preserves url');
  CheckEqual('hello', LP.GetBody, 'keep-alive chunked trailer partial follow-up line preserves decoded body');
  CheckEqual('X-Test', LP.GetHeaders.Get('Trailer'), 'keep-alive chunked trailer partial follow-up line preserves trailer declaration');
  CheckEqual('', LP.GetHeaders.Get('X-Test'), 'keep-alive chunked trailer partial follow-up line keeps trailer field out of regular headers');

  LP.Reset;
  LP.Execute(PAnsiChar(LTail), Length(LTail));
  Check(not LP.IsComplete, 'chunked trailer partial follow-up request line alone is not complete');
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'chunked trailer partial follow-up request line reports parser error on finish');
end;

procedure TestChunkedTrailerKeepAliveTruncatedFollowUpHeadersConsumesFirstRequestOnly;
var
  LP: IH1Parser;
  LReq1: string;
  LTail: string;
  LReq: string;
  LConsumed: SizeUInt;
begin
  LP := NewH1RequestParser;
  LReq1 := 'POST /upload HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Transfer-Encoding: chunked'#13#10 +
           'Trailer: X-Test'#13#10#13#10 +
           '5'#13#10'hello'#13#10 +
           '0'#13#10 +
           'X-Test: value'#13#10#13#10;
  LTail := 'GET /next HTTP/1.1'#13#10 +
           'Host: localhost'#13#10;
  LReq := LReq1 + LTail;
  LConsumed := LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.HasError, 'keep-alive chunked trailer partial follow-up headers should not corrupt first request');
  Check(LP.IsComplete, 'keep-alive chunked trailer first request should complete before partial follow-up headers');
  CheckEqual(SizeUInt(Length(LReq1)), LConsumed, 'keep-alive chunked trailer parser consumes only first request before partial follow-up headers');
  Check(LP.GetMethod = hmPost, 'keep-alive chunked trailer partial follow-up headers preserves POST method');
  CheckEqual('/upload', LP.GetUrl, 'keep-alive chunked trailer partial follow-up headers preserves url');
  CheckEqual('hello', LP.GetBody, 'keep-alive chunked trailer partial follow-up headers preserves decoded body');
  CheckEqual('X-Test', LP.GetHeaders.Get('Trailer'), 'keep-alive chunked trailer partial follow-up headers preserves trailer declaration');
  CheckEqual('', LP.GetHeaders.Get('X-Test'), 'keep-alive chunked trailer partial follow-up headers keep trailer field out of regular headers');

  LP.Reset;
  LP.Execute(PAnsiChar(LTail), Length(LTail));
  Check(not LP.IsComplete, 'chunked trailer partial follow-up headers alone are not complete');
  if (not LP.HasError) and (not LP.IsComplete) then
    LP.Finish;
  Check(LP.HasError, 'chunked trailer partial follow-up headers report parser error on finish');
end;

procedure TestChunkedTrailerKeepAlivePartialFollowUpHeadersCanCompleteLater;
var
  LP: IH1Parser;
  LReq1: string;
  LTail1: string;
  LTail2: string;
  LConsumed: SizeUInt;
begin
  LP := NewH1RequestParser;
  LReq1 := 'POST /upload HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Transfer-Encoding: chunked'#13#10 +
           'Trailer: X-Test'#13#10#13#10 +
           '5'#13#10'hello'#13#10 +
           '0'#13#10 +
           'X-Test: value'#13#10#13#10;
  LTail1 := 'GET /next HTTP/1.1'#13#10 +
            'Host: localhost'#13#10;
  LTail2 := 'Connection: close'#13#10#13#10;

  LConsumed := LP.Execute(PAnsiChar(LReq1 + LTail1), Length(LReq1 + LTail1));
  Check(not LP.HasError, 'partial follow-up headers should not corrupt first chunked trailer request');
  Check(LP.IsComplete, 'first chunked trailer request should complete before follow-up headers finish');
  CheckEqual(SizeUInt(Length(LReq1)), LConsumed, 'parser should consume only the first chunked trailer request before follow-up headers complete');

  LP.Reset;
  LP.Execute(PAnsiChar(LTail1 + LTail2), Length(LTail1 + LTail2));
  Check(not LP.HasError, 'completed chunked trailer follow-up headers should parse cleanly');
  Check(LP.IsComplete, 'completed chunked trailer follow-up headers should finish as a valid second request');
  Check(LP.GetMethod = hmGet, 'completed chunked trailer follow-up headers preserve GET method');
  CheckEqual('/next', LP.GetUrl, 'completed chunked trailer follow-up headers preserve second request url');
  CheckEqual('', LP.GetBody, 'completed chunked trailer follow-up headers have no body');
end;

procedure TestChunkedTrailerPipelinedNextRequestDoesNotPolluteCurrentRequest;
var
  LP: IH1Parser;
  LReq1: string;
  LReq2: string;
  LReq: string;
  LConsumed: SizeUInt;
begin
  LP := NewH1RequestParser;
  LReq1 := 'POST /upload HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Transfer-Encoding: chunked'#13#10 +
           'Trailer: X-Test'#13#10#13#10 +
           '5'#13#10'hello'#13#10 +
           '0'#13#10 +
           'X-Test: value'#13#10#13#10;
  LReq2 := 'GET /next HTTP/1.1'#13#10 +
           'Host: localhost'#13#10#13#10;
  LReq := LReq1 + LReq2;
  LConsumed := LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.HasError, 'pipelined chunked trailer second request should not corrupt first request');
  Check(LP.IsComplete, 'first pipelined chunked trailer request should complete');
  CheckEqual(SizeUInt(Length(LReq1)), LConsumed, 'chunked trailer parser should consume only the first request');
  Check(LP.GetMethod = hmPost, 'first pipelined chunked trailer request preserves POST method');
  CheckEqual('/upload', LP.GetUrl, 'first pipelined chunked trailer request preserves url');
  CheckEqual('hello', LP.GetBody, 'first pipelined chunked trailer request preserves decoded body');
  CheckEqual('X-Test', LP.GetHeaders.Get('Trailer'), 'first pipelined chunked trailer request preserves trailer declaration');
  CheckEqual('', LP.GetHeaders.Get('X-Test'), 'first pipelined chunked trailer request keeps trailer field out of regular headers');
end;

procedure TestChunkedTrailerPartialFollowUpRequestLineCanCompleteLater;
var
  LP: IH1Parser;
  LReq1: string;
  LTail1: string;
  LTail2: string;
  LConsumed: SizeUInt;
begin
  LP := NewH1RequestParser;
  LReq1 := 'POST /upload HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Transfer-Encoding: chunked'#13#10 +
           'Trailer: X-Test'#13#10#13#10 +
           '5'#13#10'hello'#13#10 +
           '0'#13#10 +
           'X-Test: value'#13#10#13#10;
  LTail1 := 'GET /next HTTP/1.1';
  LTail2 := #13#10 +
            'Host: localhost'#13#10#13#10;

  LConsumed := LP.Execute(PAnsiChar(LReq1 + LTail1), Length(LReq1 + LTail1));
  Check(not LP.HasError, 'partial follow-up line should not corrupt first chunked trailer request');
  Check(LP.IsComplete, 'first chunked trailer request should complete before follow-up line finishes');
  CheckEqual(SizeUInt(Length(LReq1)), LConsumed, 'parser should consume only the first chunked trailer request before follow-up line completes');

  LP.Reset;
  LP.Execute(PAnsiChar(LTail1 + LTail2), Length(LTail1 + LTail2));
  Check(not LP.HasError, 'completed follow-up line should parse cleanly');
  Check(LP.IsComplete, 'completed follow-up line should finish as a valid second request');
  Check(LP.GetMethod = hmGet, 'completed follow-up line preserves GET method');
  CheckEqual('/next', LP.GetUrl, 'completed follow-up line preserves second request url');
  CheckEqual('', LP.GetBody, 'completed follow-up line has no body');
end;

procedure TestChunkedPipelinedNextRequestDoesNotPolluteCurrentRequest;
var
  LP: IH1Parser;
  LReq1: string;
  LReq2: string;
  LReq: string;
  LConsumed: SizeUInt;
begin
  LP := NewH1RequestParser;
  LReq1 := 'POST /upload HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Transfer-Encoding: chunked'#13#10#13#10 +
           '5'#13#10'hello'#13#10 +
           '0'#13#10#13#10;
  LReq2 := 'GET /next HTTP/1.1'#13#10 +
           'Host: localhost'#13#10#13#10;
  LReq := LReq1 + LReq2;
  LConsumed := LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.HasError, 'pipelined chunked second request should not corrupt first request');
  Check(LP.IsComplete, 'first pipelined chunked request should complete');
  CheckEqual(SizeUInt(Length(LReq1)), LConsumed, 'chunked parser should consume only the first request');
  Check(LP.GetMethod = hmPost, 'first pipelined chunked request preserves POST method');
  CheckEqual('/upload', LP.GetUrl, 'first pipelined chunked request preserves url');
  CheckEqual('hello', LP.GetBody, 'first pipelined chunked request preserves decoded body');
end;

procedure TestUpgradeRequestCompletesWithoutParserError;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'GET /ws HTTP/1.1'#13#10 +
          'Host: localhost'#13#10 +
          'Upgrade: websocket'#13#10 +
          'Connection: Upgrade'#13#10 +
          'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ=='#13#10 +
          'Sec-WebSocket-Version: 13'#13#10#13#10;
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.HasError, 'upgrade request should not report parser error');
  Check(LP.IsComplete, 'upgrade request should complete');
  CheckEqual('/ws', LP.GetUrl, 'upgrade request preserves url');
end;

procedure TestPipelinedNextRequestDoesNotPolluteCurrentRequest;
var
  LP: IH1Parser;
  LReq1, LReq2, LReq: string;
  LConsumed: SizeUInt;
begin
  LP := NewH1RequestParser;
  LReq1 := 'POST /upload HTTP/1.1'#13#10 +
           'Host: localhost'#13#10 +
           'Content-Length: 5'#13#10#13#10 +
           'hello';
  LReq2 := 'GET /next HTTP/1.1'#13#10 +
           'Host: localhost'#13#10#13#10;
  LReq := LReq1 + LReq2;
  LConsumed := LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.HasError, 'pipelined second request should not corrupt first request');
  Check(LP.IsComplete, 'first pipelined request should complete');
  CheckEqual(SizeUInt(Length(LReq1)), LConsumed, 'parser should consume only the first request');
  Check(LP.GetMethod = hmPost, 'first pipelined request preserves POST method');
  CheckEqual('/upload', LP.GetUrl, 'first pipelined request preserves url');
  CheckEqual('hello', LP.GetBody, 'first pipelined request preserves body');
end;

procedure TestRequestLineTruncatedAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'GET / HTTP/1.';
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated request line is not complete');
  LP.Finish;
  Check(LP.HasError, 'finish reports truncated request line as error');
  Check(not LP.IsComplete, 'truncated request line stays incomplete');
end;

procedure TestHeadersTruncatedAtEof;
var
  LP: IH1Parser;
  LReq: string;
begin
  LP := NewH1RequestParser;
  LReq := 'GET / HTTP/1.1'#13#10 +
          'Host: local';
  LP.Execute(PAnsiChar(LReq), Length(LReq));
  Check(not LP.IsComplete, 'truncated headers are not complete');
  LP.Finish;
  Check(LP.HasError, 'finish reports truncated headers as error');
  Check(not LP.IsComplete, 'truncated headers stay incomplete');
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
  T.Run('Response HEAD skip-body with content-length', @TestResponseHeadSkipBodyWithContentLength);
  T.Run('Response close-delimited needs connection close', @TestResponseCloseDelimitedNeedsConnectionClose);
  T.Run('Response content-length keeps alive', @TestResponseContentLengthKeepsAlive);
  T.Run('Response content-length truncated at EOF', @TestResponseContentLengthTruncatedAtEof);
  T.Run('Response HTTP/1.0 without keep-alive does not reuse', @TestResponseHttp10WithoutKeepAliveDoesNotReuse);
  T.Run('Content-Length body', @TestContentLengthBody);
  T.Run('Content-Length request truncated at EOF', @TestContentLengthRequestTruncatedAtEof);
  T.Run('Chunked request body', @TestChunkedRequestBody);
  T.Run('Request body reader view', @TestRequestBodyReaderView);
  T.Run('Response body reader view', @TestResponseBodyReaderView);
  T.Run('Chunked request invalid chunk size', @TestChunkedRequestInvalidChunkSize);
  T.Run('Chunked request malformed chunk extension', @TestChunkedRequestMalformedChunkExtension);
  T.Run('Chunked request truncated chunk extension at EOF', @TestChunkedRequestTruncatedChunkExtensionAtEof);
  T.Run('Chunked request truncated chunk extension CR at EOF', @TestChunkedRequestTruncatedChunkExtensionCrAtEof);
  T.Run('Chunked request truncated at EOF', @TestChunkedRequestTruncatedAtEof);
  T.Run('Chunked request truncated chunk-size line at EOF', @TestChunkedRequestTruncatedChunkSizeLineAtEof);
  T.Run('Chunked request truncated terminal chunk ending at EOF', @TestChunkedRequestTruncatedTerminalChunkEndingAtEof);
  T.Run('Chunked request truncated terminal chunk ending CR at EOF',
    @TestChunkedRequestTruncatedTerminalChunkEndingCrAtEof);
  T.Run('Chunked request truncated terminal chunk extension at EOF', @TestChunkedRequestTruncatedTerminalChunkExtensionAtEof);
  T.Run('Chunked request truncated terminal chunk extension CR at EOF', @TestChunkedRequestTruncatedTerminalChunkExtensionCrAtEof);
  T.Run('Chunked request truncated terminal chunk ending after extension at EOF',
    @TestChunkedRequestTruncatedTerminalChunkEndingAfterExtensionAtEof);
  T.Run('Chunked request truncated terminal chunk ending after extension CR at EOF',
    @TestChunkedRequestTruncatedTerminalChunkEndingAfterExtensionCrAtEof);
  T.Run('Chunked request truncated chunk-data ending at EOF', @TestChunkedRequestTruncatedChunkDataEndingAtEof);
  T.Run('Chunked request truncated chunk-data CR at EOF', @TestChunkedRequestTruncatedChunkDataCrAtEof);
  T.Run('Chunked request missing chunk-data CRLF', @TestChunkedRequestMissingChunkDataCrLf);
  T.Run('Chunked request content-length conflict', @TestChunkedRequestContentLengthConflict);
  T.Run('Chunked request content-length conflict reverse order', @TestChunkedRequestContentLengthConflictReverseOrder);
  T.Run('Chunked request unsupported transfer coding before chunked',
    @TestChunkedRequestUnsupportedTransferCodingBeforeChunked);
  T.Run('Chunked request chunked must be final transfer coding',
    @TestChunkedRequestChunkedMustBeFinalTransferCoding);
  T.Run('Chunked request trailer does not pollute headers', @TestChunkedRequestTrailerDoesNotPolluteHeaders);
  T.Run('Chunked request trailer bytes track late trailer', @TestChunkedRequestTrailerBytesTrackLateTrailer);
  T.Run('Chunked request invalid trailer field', @TestChunkedRequestInvalidTrailerField);
  T.Run('Chunked request truncated trailer at EOF', @TestChunkedRequestTruncatedTrailerAtEof);
  T.Run('Chunked request truncated trailer field-name at EOF', @TestChunkedRequestTruncatedTrailerFieldNameAtEof);
  T.Run('Chunked request truncated trailer separator at EOF', @TestChunkedRequestTruncatedTrailerSeparatorAtEof);
  T.Run('Chunked request truncated trailer empty-value CR at EOF', @TestChunkedRequestTruncatedTrailerEmptyValueCrAtEof);
  T.Run('Chunked request truncated trailer empty-value at EOF', @TestChunkedRequestTruncatedTrailerEmptyValueAtEof);
  T.Run('Chunked request truncated trailer empty-value section CR at EOF', @TestChunkedRequestTruncatedTrailerEmptyValueSectionCrAtEof);
  T.Run('Chunked request truncated trailer whitespace at EOF', @TestChunkedRequestTruncatedTrailerWhitespaceAtEof);
  T.Run('Chunked request truncated trailer whitespace CR at EOF', @TestChunkedRequestTruncatedTrailerWhitespaceCrAtEof);
  T.Run('Chunked request truncated trailer whitespace section at EOF', @TestChunkedRequestTruncatedTrailerWhitespaceSectionAtEof);
  T.Run('Chunked request truncated trailer whitespace section CR at EOF', @TestChunkedRequestTruncatedTrailerWhitespaceSectionCrAtEof);
  T.Run('Chunked request truncated trailer field line at EOF', @TestChunkedRequestTruncatedTrailerFieldLineAtEof);
  T.Run('Chunked request truncated trailer field CR at EOF', @TestChunkedRequestTruncatedTrailerFieldCrAtEof);
  T.Run('Chunked request truncated trailer CR at EOF', @TestChunkedRequestTruncatedTrailerCrAtEof);
  T.Run('HEAD request', @TestHeadRequest);
  T.Run('Generic malformed request', @TestInvalidRequest);
  T.Run('Duplicate Content-Length', @TestDuplicateContentLength);
  T.Run('Header with null byte', @TestHeaderNullByte);
  T.Run('HTTP/0.9 request rejected', @TestHttp09RequestRejected);
  T.Run('Request-line splitting rejected', @TestRequestLineSplittingRejected);
  T.Run('Negative Content-Length rejected', @TestNegativeContentLengthRejected);
  T.Run('Very long method rejected', @TestVeryLongMethodRejected);
  T.Run('Content-Length request extra bytes after close rejected', @TestContentLengthRequestExtraBytesAfterCloseRejected);
  T.Run('Content-Length keep-alive garbage tail consumes first request only', @TestContentLengthKeepAliveGarbageTailConsumesFirstRequestOnly);
  T.Run('Content-Length keep-alive truncated follow-up request line consumes first request only',
    @TestContentLengthKeepAliveTruncatedFollowUpRequestLineConsumesFirstRequestOnly);
  T.Run('Content-Length keep-alive partial follow-up request line can complete later',
    @TestContentLengthKeepAlivePartialFollowUpRequestLineCanCompleteLater);
  T.Run('Content-Length keep-alive truncated follow-up headers consumes first request only',
    @TestContentLengthKeepAliveTruncatedFollowUpHeadersConsumesFirstRequestOnly);
  T.Run('Content-Length keep-alive partial follow-up headers can complete later',
    @TestContentLengthKeepAlivePartialFollowUpHeadersCanCompleteLater);
  T.Run('Chunked request extra bytes after close rejected', @TestChunkedRequestExtraBytesAfterCloseRejected);
  T.Run('Chunked keep-alive garbage tail consumes first request only', @TestChunkedKeepAliveGarbageTailConsumesFirstRequestOnly);
  T.Run('Chunked keep-alive truncated follow-up request line consumes first request only',
    @TestChunkedKeepAliveTruncatedFollowUpRequestLineConsumesFirstRequestOnly);
  T.Run('Chunked keep-alive partial follow-up request line can complete later',
    @TestChunkedKeepAlivePartialFollowUpRequestLineCanCompleteLater);
  T.Run('Chunked keep-alive truncated follow-up headers consumes first request only',
    @TestChunkedKeepAliveTruncatedFollowUpHeadersConsumesFirstRequestOnly);
  T.Run('Chunked keep-alive partial follow-up headers can complete later',
    @TestChunkedKeepAlivePartialFollowUpHeadersCanCompleteLater);
  T.Run('Chunked trailer keep-alive garbage tail consumes first request only',
    @TestChunkedTrailerKeepAliveGarbageTailConsumesFirstRequestOnly);
  T.Run('Chunked trailer keep-alive truncated follow-up request line consumes first request only',
    @TestChunkedTrailerKeepAliveTruncatedFollowUpRequestLineConsumesFirstRequestOnly);
  T.Run('Chunked trailer keep-alive truncated follow-up headers consumes first request only',
    @TestChunkedTrailerKeepAliveTruncatedFollowUpHeadersConsumesFirstRequestOnly);
  T.Run('Chunked trailer keep-alive partial follow-up headers can complete later',
    @TestChunkedTrailerKeepAlivePartialFollowUpHeadersCanCompleteLater);
  T.Run('Chunked trailer pipelined next request does not pollute current request',
    @TestChunkedTrailerPipelinedNextRequestDoesNotPolluteCurrentRequest);
  T.Run('Chunked trailer partial follow-up request line can complete later',
    @TestChunkedTrailerPartialFollowUpRequestLineCanCompleteLater);
  T.Run('Chunked pipelined next request does not pollute current request', @TestChunkedPipelinedNextRequestDoesNotPolluteCurrentRequest);
  T.Run('Upgrade request completes without parser error', @TestUpgradeRequestCompletesWithoutParserError);
  T.Run('Pipelined next request does not pollute current request', @TestPipelinedNextRequestDoesNotPolluteCurrentRequest);
  T.Run('Request line truncated at EOF', @TestRequestLineTruncatedAtEof);
  T.Run('Headers truncated at EOF', @TestHeadersTruncatedAtEof);
  T.Run('Incomplete input', @TestIncompleteInput);
  T.Run('Reset and reparse', @TestResetAndReparse);
  T.Run('Request with query', @TestRequestWithQuery);
  T.Run('Multiple headers same name', @TestMultipleHeadersSameName);
  T.Summary;
end.
