program test_http_h1writer;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.impl.h1.writer;

type
  TBytesWriter = class(TInterfacedObject, IWriter)
  private
    FBuf: string;
  public
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function GetOutput: string;
  end;

function TBytesWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LOld: SizeUInt;
begin
  if ACount = 0 then
    Exit(0);
  LOld := SizeUInt(Length(FBuf));
  SetLength(FBuf, LOld + ACount);
  Move(ABuf, FBuf[LOld + 1], ACount);
  Result := ACount;
end;

function TBytesWriter.GetOutput: string;
begin
  Result := FBuf;
end;

var
  T: TTestRunner;

procedure TestWriteHeaderStatusLine;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LOut: string;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LRW.WriteHeader(HTTP_STATUS_OK);
  LOut := LW.GetOutput;
  Check(Pos('HTTP/1.1 200 OK'#13#10, LOut) = 1, 'status line at start');
  LRW.Free;
end;

procedure TestHeadersWrittenAfterStatusLine;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LOut: string;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LRW.GetHeaders.Set_('Content-Type', 'text/plain');
  LRW.WriteHeader(HTTP_STATUS_OK);
  LOut := LW.GetOutput;
  Check(Pos('content-type: text/plain'#13#10, LOut) > 0, 'header present');
  Check(Pos('content-type: text/plain'#13#10, LOut) > Pos('HTTP/1.1', LOut),
    'header after status line');
  LRW.Free;
end;

procedure TestCRLFSeparatesHeadersFromBody;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LOut: string;
  LBody: string;
  LPos: SizeInt;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LRW.GetHeaders.Set_('Content-Type', 'text/plain');
  LRW.WriteHeader(HTTP_STATUS_OK);
  LBody := 'hello';
  LRW.Write(LBody[1], SizeUInt(Length(LBody)));
  LOut := LW.GetOutput;
  LPos := Pos(#13#10#13#10, LOut);
  Check(LPos > 0, 'double CRLF present');
  Check(Pos('hello', LOut) > LPos, 'body after double CRLF');
  LRW.Free;
end;

procedure TestWriteAutoCallsWriteHeader200;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LOut: string;
  LBody: string;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LBody := 'auto';
  LRW.Write(LBody[1], SizeUInt(Length(LBody)));
  LOut := LW.GetOutput;
  Check(Pos('HTTP/1.1 200 OK'#13#10, LOut) = 1, 'auto status 200');
  Check(Pos('auto', LOut) > 0, 'body written');
  LRW.Free;
end;

procedure TestMultipleWriteAppendsBody;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LOut: string;
  LP1, LP2: string;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LRW.WriteHeader(HTTP_STATUS_OK);
  LP1 := 'hel';
  LP2 := 'lo';
  LRW.Write(LP1[1], SizeUInt(Length(LP1)));
  LRW.Write(LP2[1], SizeUInt(Length(LP2)));
  LOut := LW.GetOutput;
  Check(Pos('hello', LOut) > 0, 'body concatenated');
  LRW.Free;
end;

procedure TestCustomStatus404;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LOut: string;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LRW.WriteHeader(HTTP_STATUS_NOT_FOUND);
  LOut := LW.GetOutput;
  Check(Pos('HTTP/1.1 404 Not Found'#13#10, LOut) = 1, 'status 404');
  LRW.Free;
end;

procedure TestMultipleHeadersWritten;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LOut: string;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LRW.GetHeaders.Set_('Content-Type', 'text/html');
  LRW.GetHeaders.Set_('X-Custom', 'value1');
  LRW.GetHeaders.Add('X-Multi', 'a');
  LRW.GetHeaders.Add('X-Multi', 'b');
  LRW.WriteHeader(HTTP_STATUS_OK);
  LOut := LW.GetOutput;
  Check(Pos('content-type: text/html'#13#10, LOut) > 0, 'content-type header');
  Check(Pos('x-custom: value1'#13#10, LOut) > 0, 'x-custom header');
  Check(Pos('x-multi: a'#13#10, LOut) > 0, 'x-multi first');
  Check(Pos('x-multi: b'#13#10, LOut) > 0, 'x-multi second');
  LRW.Free;
end;

procedure TestWriteHeaderOnlyOnce;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LOut: string;
  LCount: SizeInt;
  LPos: SizeInt;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LRW.WriteHeader(HTTP_STATUS_OK);
  LRW.WriteHeader(HTTP_STATUS_NOT_FOUND);
  LOut := LW.GetOutput;
  { Count occurrences of HTTP/1.1 - should be exactly 1 }
  LCount := 0;
  LPos := 1;
  while LPos <= Length(LOut) do
  begin
    LPos := Pos('HTTP/1.1', LOut, LPos);
    if LPos = 0 then Break;
    Inc(LCount);
    Inc(LPos);
  end;
  CheckEqual(Int64(1), Int64(LCount), 'only one status line');
  { Should be 200, not 404 }
  Check(Pos('200 OK', LOut) > 0, 'first status preserved');
  LRW.Free;
end;

procedure TestFullResponse;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LOut: string;
  LBody: string;
  LExpected: string;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LRW.GetHeaders.Set_('Content-Type', 'text/plain');
  LRW.GetHeaders.Set_('Content-Length', '5');
  LRW.WriteHeader(HTTP_STATUS_OK);
  LBody := 'hello';
  LRW.Write(LBody[1], SizeUInt(Length(LBody)));
  LOut := LW.GetOutput;
  LExpected := 'HTTP/1.1 200 OK'#13#10 +
    'content-type: text/plain'#13#10 +
    'content-length: 5'#13#10 +
    #13#10 +
    'hello';
  CheckEqual(LExpected, LOut, 'full response');
  LRW.Free;
end;

procedure TestFlushNoOpWithoutFlusher;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LRW.Flush; { should not crash }
  Check(True, 'flush no-op ok');
  LRW.Free;
end;

begin
  T := TTestRunner.Create('nextpas.core.http.impl.h1.writer');
  T.Run('WriteHeader writes status line', @TestWriteHeaderStatusLine);
  T.Run('Headers written after status line', @TestHeadersWrittenAfterStatusLine);
  T.Run('CRLF separates headers from body', @TestCRLFSeparatesHeadersFromBody);
  T.Run('Write auto-calls WriteHeader(200)', @TestWriteAutoCallsWriteHeader200);
  T.Run('Multiple Write calls append body', @TestMultipleWriteAppendsBody);
  T.Run('Custom status 404', @TestCustomStatus404);
  T.Run('Multiple headers written correctly', @TestMultipleHeadersWritten);
  T.Run('WriteHeader only called once', @TestWriteHeaderOnlyOnce);
  T.Run('Full response format', @TestFullResponse);
  T.Run('Flush no-op without IFlusher', @TestFlushNoOpWithoutFlusher);
  T.Summary;
end.
