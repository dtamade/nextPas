program test_http_h1writer;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.testing,
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.time.deadline,
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

  TMockTcpStream = class(TInterfacedObject, ITcpStream)
  public
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
    function LocalAddr: TNetAddress;
    function RemoteAddr: TNetAddress;
    procedure Shutdown;
    procedure SetNoDelay(const AValue: Boolean);
    procedure SetKeepAlive(const AValue: Boolean);
    procedure SetReadDeadline(const ADeadline: TDeadline);
    procedure SetWriteDeadline(const ADeadline: TDeadline);
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

function TMockTcpStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := 0;
end;

function TMockTcpStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := ACount;
end;

function TMockTcpStream.Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
begin
  Result := 0;
end;

procedure TMockTcpStream.Close;
begin
end;

function TMockTcpStream.GetSize: Int64;
begin
  Result := -1;
end;

function TMockTcpStream.GetPosition: Int64;
begin
  Result := -1;
end;

procedure TMockTcpStream.SetPosition(const AValue: Int64);
begin
end;

function TMockTcpStream.LocalAddr: TNetAddress;
begin
  Result := TNetAddress.Loopback(8080);
end;

function TMockTcpStream.RemoteAddr: TNetAddress;
begin
  Result := TNetAddress.Loopback(65000);
end;

procedure TMockTcpStream.Shutdown;
begin
end;

procedure TMockTcpStream.SetNoDelay(const AValue: Boolean);
begin
end;

procedure TMockTcpStream.SetKeepAlive(const AValue: Boolean);
begin
end;

procedure TMockTcpStream.SetReadDeadline(const ADeadline: TDeadline);
begin
end;

procedure TMockTcpStream.SetWriteDeadline(const ADeadline: TDeadline);
begin
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

procedure TestMultipleWritePreservesBodyOrder;
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
  LRW.Flush;
  LOut := LW.GetOutput;
  Check(Pos('transfer-encoding: chunked', LOut) > 0, 'chunked header added');
  Check(Pos('hel', LOut) > 0, 'first payload present');
  Check(Pos('lo', LOut) > Pos('hel', LOut), 'second payload follows first');
  Check(Pos('0'#13#10#13#10, LOut) > 0, 'final chunk written');
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

procedure TestHijackWithoutConnectionRaises;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LRaised: Boolean;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  try
    LRaised := False;
    try
      LRW.Hijack;
    except
      on E: EHttpError do
        LRaised := True;
    end;
    Check(LRaised, 'Hijack without connection raises EHttpError');
    Check(not LRW.IsHijacked, 'failed hijack does not mark writer hijacked');
  finally
    LRW.Free;
  end;
end;

procedure TestHijackReturnsConnectionAndMarksWriter;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LConn: ITcpStream;
  LHijacked: ITcpStream;
begin
  LW := TBytesWriter.Create;
  LConn := TMockTcpStream.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter, LConn);
  try
    Check(not LRW.IsHijacked, 'new writer is not hijacked');
    LHijacked := LRW.Hijack;
    Check(LHijacked = LConn, 'Hijack returns the underlying connection');
    Check(LRW.IsHijacked, 'Hijack marks writer hijacked');
  finally
    LRW.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.http.impl.h1.writer');
  T.Run('WriteHeader writes status line', @TestWriteHeaderStatusLine);
  T.Run('Headers written after status line', @TestHeadersWrittenAfterStatusLine);
  T.Run('CRLF separates headers from body', @TestCRLFSeparatesHeadersFromBody);
  T.Run('Write auto-calls WriteHeader(200)', @TestWriteAutoCallsWriteHeader200);
  T.Run('Multiple Write preserves body order under chunked encoding',
    @TestMultipleWritePreservesBodyOrder);
  T.Run('Custom status 404', @TestCustomStatus404);
  T.Run('Multiple headers written correctly', @TestMultipleHeadersWritten);
  T.Run('WriteHeader only called once', @TestWriteHeaderOnlyOnce);
  T.Run('Full response format', @TestFullResponse);
  T.Run('Flush no-op without IFlusher', @TestFlushNoOpWithoutFlusher);
  T.Run('Hijack without connection raises', @TestHijackWithoutConnectionRaises);
  T.Run('Hijack returns connection and marks writer', @TestHijackReturnsConnectionAndMarksWriter);
  T.Summary;
end.
