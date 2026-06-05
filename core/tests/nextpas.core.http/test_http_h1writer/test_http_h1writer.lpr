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
  nextpas.core.http.impl.h1.outbound,
  nextpas.core.http.impl.h1.writer;

type
  TBytesWriter = class(TInterfacedObject, IWriter)
  private
    FBuf: string;
  public
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function GetOutput: string;
  end;

  TShortWriter = class(TInterfacedObject, IWriter)
  private
    FBuf: string;
    FMaxPerCall: SizeUInt;
  public
    constructor Create(const AMaxPerCall: SizeUInt);
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function GetOutput: string;
  end;

  TCountingWriter = class(TInterfacedObject, IWriter)
  private
    FBuf: string;
    FWriteCalls: Int32;
  public
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function GetOutput: string;
    function WriteCalls: Int32;
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

  TMockDrainStreamRuntime = class(TInterfacedObject, ITcpStreamRuntime)
  private
    FOutput: string;
    FMaxPerWrite: SizeUInt;
    FWouldBlockCall: Int32;
    FWriteCalls: Int32;
  public
    constructor Create(const AMaxPerWrite: SizeUInt;
      const AWouldBlockCall: Int32);
    function NativeSocketHandle: PtrUInt;
    procedure SetBlocking(const ABlocking: Boolean);
    function TryRead(var ABuf; const ACount: SizeUInt;
      out ARead: SizeUInt): TTcpStreamIOResult;
    function TryWrite(const ABuf; const ACount: SizeUInt;
      out AWritten: SizeUInt): TTcpStreamIOResult;
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

constructor TShortWriter.Create(const AMaxPerCall: SizeUInt);
begin
  inherited Create;
  FMaxPerCall := AMaxPerCall;
end;

function TShortWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LOld: SizeUInt;
begin
  if (ACount = 0) or (FMaxPerCall = 0) then
    Exit(0);
  Result := ACount;
  if Result > FMaxPerCall then
    Result := FMaxPerCall;
  LOld := SizeUInt(Length(FBuf));
  SetLength(FBuf, LOld + Result);
  Move(ABuf, FBuf[LOld + 1], Result);
end;

function TShortWriter.GetOutput: string;
begin
  Result := FBuf;
end;

function TCountingWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  LOld: SizeUInt;
begin
  Inc(FWriteCalls);
  if ACount = 0 then
    Exit(0);
  LOld := SizeUInt(Length(FBuf));
  SetLength(FBuf, LOld + ACount);
  Move(ABuf, FBuf[LOld + 1], ACount);
  Result := ACount;
end;

function TCountingWriter.GetOutput: string;
begin
  Result := FBuf;
end;

function TCountingWriter.WriteCalls: Int32;
begin
  Result := FWriteCalls;
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

constructor TMockDrainStreamRuntime.Create(const AMaxPerWrite: SizeUInt;
  const AWouldBlockCall: Int32);
begin
  inherited Create;
  FMaxPerWrite := AMaxPerWrite;
  FWouldBlockCall := AWouldBlockCall;
  FWriteCalls := 0;
end;

function TMockDrainStreamRuntime.NativeSocketHandle: PtrUInt;
begin
  Result := 0;
end;

procedure TMockDrainStreamRuntime.SetBlocking(const ABlocking: Boolean);
begin
end;

function TMockDrainStreamRuntime.TryRead(var ABuf; const ACount: SizeUInt;
  out ARead: SizeUInt): TTcpStreamIOResult;
begin
  ARead := 0;
  Result := tsiorClosed;
end;

function TMockDrainStreamRuntime.TryWrite(const ABuf; const ACount: SizeUInt;
  out AWritten: SizeUInt): TTcpStreamIOResult;
var
  LOld: SizeUInt;
begin
  Inc(FWriteCalls);
  if FWriteCalls = FWouldBlockCall then
  begin
    AWritten := 0;
    Exit(tsiorWouldBlock);
  end;

  AWritten := ACount;
  if (FMaxPerWrite > 0) and (AWritten > FMaxPerWrite) then
    AWritten := FMaxPerWrite;
  if AWritten > 0 then
  begin
    LOld := SizeUInt(Length(FOutput));
    SetLength(FOutput, LOld + AWritten);
    Move(ABuf, FOutput[LOld + 1], AWritten);
  end;
  Result := tsiorOk;
end;

function TMockDrainStreamRuntime.GetOutput: string;
begin
  Result := FOutput;
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

procedure TestPresetTransferEncodingPreserved;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LOut: string;
  LBody: string;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LRW.GetHeaders.Set_('Transfer-Encoding', 'gzip');
  LRW.WriteHeader(HTTP_STATUS_OK);
  LBody := 'hello';
  LRW.Write(LBody[1], SizeUInt(Length(LBody)));
  LRW.Flush;
  LOut := LW.GetOutput;
  Check(Pos('transfer-encoding: gzip'#13#10, LOut) > 0, 'preset transfer-encoding preserved');
  Check(Pos('transfer-encoding: chunked', LOut) = 0, 'chunked header not injected');
  Check(Pos('0'#13#10#13#10, LOut) = 0, 'non-chunked flush does not write final chunk');
  LRW.Free;
end;

procedure TestFlushWithContentLengthDoesNotWriteFinalChunk;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LOut: string;
  LBody: string;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LRW.GetHeaders.Set_('Content-Length', '5');
  LRW.WriteHeader(HTTP_STATUS_OK);
  LBody := 'hello';
  LRW.Write(LBody[1], SizeUInt(Length(LBody)));
  LRW.Flush;
  LOut := LW.GetOutput;
  Check(Pos('content-length: 5'#13#10, LOut) > 0, 'content-length preserved');
  Check(Pos('transfer-encoding: chunked', LOut) = 0, 'chunked header not injected');
  Check(Pos('0'#13#10#13#10, LOut) = 0, 'content-length path does not write final chunk');
  LRW.Free;
end;

procedure TestNoContentResponseDoesNotInjectChunkedEncoding;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LOut: string;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LRW.WriteHeader(HTTP_STATUS_NO_CONTENT);
  LRW.Flush;
  LOut := LW.GetOutput;
  Check(Pos('HTTP/1.1 204 No Content'#13#10, LOut) = 1, 'status 204 written');
  Check(Pos('transfer-encoding: chunked', LOut) = 0,
    '204 does not inject chunked header');
  Check(Pos('content-length:', LOut) = 0,
    '204 does not force content-length');
  Check(Pos('0'#13#10#13#10, LOut) = 0,
    '204 does not write final chunk');
  LRW.Free;
end;

procedure TestNotModifiedResponseDoesNotInjectChunkedEncoding;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LOut: string;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LRW.WriteHeader(HTTP_STATUS_NOT_MODIFIED);
  LRW.Flush;
  LOut := LW.GetOutput;
  Check(Pos('HTTP/1.1 304 Not Modified'#13#10, LOut) = 1, 'status 304 written');
  Check(Pos('transfer-encoding: chunked', LOut) = 0,
    '304 does not inject chunked header');
  Check(Pos('content-length:', LOut) = 0,
    '304 does not force content-length');
  Check(Pos('0'#13#10#13#10, LOut) = 0,
    '304 does not write final chunk');
  LRW.Free;
end;

procedure TestInformationalResponseDoesNotInjectChunkedEncoding;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LOut: string;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LRW.WriteHeader(HTTP_STATUS_CONTINUE);
  LRW.Flush;
  LOut := LW.GetOutput;
  Check(Pos('HTTP/1.1 100 Continue'#13#10, LOut) = 1, 'status 100 written');
  Check(Pos('transfer-encoding: chunked', LOut) = 0,
    '100 does not inject chunked header');
  Check(Pos('content-length:', LOut) = 0,
    '100 does not force content-length');
  Check(Pos('0'#13#10#13#10, LOut) = 0,
    '100 does not write final chunk');
  LRW.Free;
end;

procedure TestNonSwitchingInformationalAllowsFinalResponse;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LOut: string;
  LBody: string;
  LInfoPos: SizeInt;
  LFinalPos: SizeInt;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LRW.GetHeaders.Set_('Link', '</style.css>; rel=preload');
  LRW.WriteHeader(HTTP_STATUS_EARLY_HINTS);
  LRW.WriteHeader(HTTP_STATUS_OK);
  LBody := 'ok';
  LRW.Write(LBody[1], SizeUInt(Length(LBody)));
  LRW.Flush;
  LOut := LW.GetOutput;
  LInfoPos := Pos('HTTP/1.1 103 Early Hints'#13#10, LOut);
  LFinalPos := Pos('HTTP/1.1 200 OK'#13#10, LOut);
  Check(LInfoPos = 1, '103 informational status written first');
  Check(LFinalPos > LInfoPos, 'final 200 follows informational response');
  Check(Pos('transfer-encoding: chunked', LOut) > LFinalPos,
    'final response gets chunked header');
  Check(Pos('ok', LOut) > LFinalPos, 'final response body written');
  LRW.Free;
end;

procedure TestSwitchingProtocolsResponseDoesNotInjectChunkedEncoding;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LOut: string;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LRW.WriteHeader(HTTP_STATUS_SWITCHING_PROTOCOLS);
  LRW.Flush;
  LOut := LW.GetOutput;
  Check(Pos('HTTP/1.1 101 Switching Protocols'#13#10, LOut) = 1,
    'status 101 written');
  Check(Pos('transfer-encoding: chunked', LOut) = 0,
    '101 does not inject chunked header');
  Check(Pos('content-length:', LOut) = 0,
    '101 does not force content-length');
  Check(Pos('0'#13#10#13#10, LOut) = 0,
    '101 does not write final chunk');
  LRW.Free;
end;

procedure TestSwitchingProtocolsResponseRejectsBodyWrite;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LBody: string;
  LBefore: string;
  LRaised: Boolean;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LRW.WriteHeader(HTTP_STATUS_SWITCHING_PROTOCOLS);
  LBefore := LW.GetOutput;
  LBody := 'hello';
  LRaised := False;
  try
    LRW.Write(LBody[1], SizeUInt(Length(LBody)));
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, '101 response rejects body write');
  CheckEqual(LBefore, LW.GetOutput, '101 body write does not append bytes');
  LRW.Free;
end;

procedure TestNoContentResponseRejectsBodyWrite;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LBody: string;
  LBefore: string;
  LRaised: Boolean;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LRW.WriteHeader(HTTP_STATUS_NO_CONTENT);
  LBefore := LW.GetOutput;
  LBody := 'hello';
  LRaised := False;
  try
    LRW.Write(LBody[1], SizeUInt(Length(LBody)));
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, '204 response rejects body write');
  CheckEqual(LBefore, LW.GetOutput, '204 body write does not append bytes');
  LRW.Free;
end;

procedure TestSuppressBodyWriteDoesNotEmitBodyOrChunkedEncoding;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LOut: string;
  LBody: string;
  LWritten: SizeUInt;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter, nil, True);
  LBody := 'hello';
  LWritten := LRW.Write(LBody[1], SizeUInt(Length(LBody)));
  LRW.Flush;
  LOut := LW.GetOutput;
  CheckEqual(Int64(Length(LBody)), Int64(LWritten),
    'suppressed-body write reports consumed bytes');
  Check(Pos('HTTP/1.1 200 OK'#13#10, LOut) = 1, 'suppressed-body status 200 written');
  Check(Pos('transfer-encoding: chunked', LOut) = 0,
    'suppressed-body path does not inject chunked header');
  Check(Pos('0'#13#10#13#10, LOut) = 0,
    'suppressed-body path does not write final chunk');
  Check(Pos('hello', LOut) = 0,
    'suppressed-body path does not emit body bytes');
  LRW.Free;
end;

procedure TestSuppressBodyPreservesExplicitContentLength;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LOut: string;
  LBody: string;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter, nil, True);
  LRW.GetHeaders.Set_('content-length', '5');
  LRW.WriteHeader(HTTP_STATUS_OK);
  LBody := 'hello';
  LRW.Write(LBody[1], SizeUInt(Length(LBody)));
  LRW.Flush;
  LOut := LW.GetOutput;
  Check(Pos('content-length: 5'#13#10, LOut) > 0,
    'suppressed-body path preserves explicit content-length');
  Check(Pos('transfer-encoding: chunked', LOut) = 0,
    'suppressed-body content-length path does not inject chunked header');
  Check(Pos('hello', LOut) = 0,
    'suppressed-body content-length path does not emit body bytes');
  Check(Pos('0'#13#10#13#10, LOut) = 0,
    'suppressed-body content-length path does not write final chunk');
  LRW.Free;
end;

procedure TestWriteAfterChunkedFlushRaises;
var
  LW: TBytesWriter;
  LRW: TH1ResponseWriter;
  LBody: string;
  LBefore: string;
  LRaised: Boolean;
begin
  LW := TBytesWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LBody := 'hello';
  LRW.Write(LBody[1], SizeUInt(Length(LBody)));
  LRW.Flush;
  LBefore := LW.GetOutput;
  LRaised := False;
  try
    LRW.Write(LBody[1], SizeUInt(Length(LBody)));
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, 'write after chunked flush raises EHttpError');
  CheckEqual(LBefore, LW.GetOutput, 'write after flush does not append bytes');
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

procedure TestWriteHeaderWithShortWriterStillWritesFullHeaders;
var
  LW: TShortWriter;
  LRW: TH1ResponseWriter;
  LOut: string;
begin
  LW := TShortWriter.Create(1);
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LRW.GetHeaders.Set_('Content-Length', '0');
  LRW.GetHeaders.Set_('X-Test', 'ok');
  LRW.WriteHeader(HTTP_STATUS_OK);
  LOut := LW.GetOutput;
  CheckEqual('HTTP/1.1 200 OK'#13#10 +
    'content-length: 0'#13#10 +
    'x-test: ok'#13#10 +
    #13#10, LOut,
    'short writer still receives full status/header framing');
  LRW.Free;
end;

procedure TestSmallHeaderBlockUsesSingleWriterCall;
var
  LW: TCountingWriter;
  LRW: TH1ResponseWriter;
  LOut: string;
begin
  LW := TCountingWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  try
    LRW.GetHeaders.Set_('Content-Length', '0');
    LRW.GetHeaders.Set_('X-Test', 'ok');
    LRW.WriteHeader(HTTP_STATUS_OK);
    LOut := LW.GetOutput;
    CheckEqual('HTTP/1.1 200 OK'#13#10 +
      'content-length: 0'#13#10 +
      'x-test: ok'#13#10 +
      #13#10, LOut,
      'combined header-line writes preserve exact wire bytes');
    CheckEqual(Int64(2), Int64(LW.WriteCalls),
      'status line and compact header block are single writes');
  finally
    LRW.Free;
  end;
end;

procedure TestCommonStatusLinesUseSingleWriterCall;

  procedure CheckStatusLine(const AStatus: THttpStatus;
    const AExpected: string; const AWithContentLength: Boolean);
  var
    LW: TCountingWriter;
    LRW: TH1ResponseWriter;
  begin
    LW := TCountingWriter.Create;
    LRW := TH1ResponseWriter.Create(LW as IWriter);
    try
      if AWithContentLength then
        LRW.GetHeaders.Set_('Content-Length', '0');
      LRW.WriteHeader(AStatus);
      if AWithContentLength then
        CheckEqual(AExpected + 'content-length: 0'#13#10#13#10,
          LW.GetOutput, 'common status line preserves header wire bytes')
      else
        CheckEqual(AExpected + #13#10, LW.GetOutput,
          'common no-body status line preserves wire bytes');
      CheckEqual(Int64(2), Int64(LW.WriteCalls),
        'common status line and header block are single writes');
    finally
      LRW.Free;
    end;
  end;

begin
  CheckStatusLine(HTTP_STATUS_CONTINUE, 'HTTP/1.1 100 Continue'#13#10, False);
  CheckStatusLine(HTTP_STATUS_EARLY_HINTS, 'HTTP/1.1 103 Early Hints'#13#10, False);
  CheckStatusLine(HTTP_STATUS_SWITCHING_PROTOCOLS,
    'HTTP/1.1 101 Switching Protocols'#13#10, False);
  CheckStatusLine(HTTP_STATUS_NO_CONTENT, 'HTTP/1.1 204 No Content'#13#10, False);
  CheckStatusLine(HTTP_STATUS_NOT_MODIFIED, 'HTTP/1.1 304 Not Modified'#13#10, False);
  CheckStatusLine(HTTP_STATUS_BAD_REQUEST, 'HTTP/1.1 400 Bad Request'#13#10, True);
  CheckStatusLine(HTTP_STATUS_NOT_FOUND, 'HTTP/1.1 404 Not Found'#13#10, True);
  CheckStatusLine(HTTP_STATUS_PAYLOAD_TOO_LARGE,
    'HTTP/1.1 413 Payload Too Large'#13#10, True);
  CheckStatusLine(HTTP_STATUS_EXPECTATION_FAILED,
    'HTTP/1.1 417 Expectation Failed'#13#10, True);
  CheckStatusLine(HTTP_STATUS_HEADER_TOO_LARGE,
    'HTTP/1.1 431 Request Header Fields Too Large'#13#10, True);
  CheckStatusLine(HTTP_STATUS_INTERNAL_SERVER_ERROR,
    'HTTP/1.1 500 Internal Server Error'#13#10, True);
  CheckStatusLine(HTTP_STATUS_NOT_IMPLEMENTED,
    'HTTP/1.1 501 Not Implemented'#13#10, True);
end;

procedure TestUnknownStatusLineKeepsFallbackReason;
var
  LW: TCountingWriter;
  LRW: TH1ResponseWriter;
begin
  LW := TCountingWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  try
    LRW.GetHeaders.Set_('Content-Length', '0');
    LRW.WriteHeader(THttpStatus(599));
    CheckEqual('HTTP/1.1 599 Unknown'#13#10 +
      'content-length: 0'#13#10 +
      #13#10, LW.GetOutput,
      'unknown status falls back to numeric status and Unknown reason');
    Check(LW.WriteCalls > 2,
      'unknown status keeps generic multi-part fallback path');
  finally
    LRW.Free;
  end;
end;

procedure TestKnownStatusLineWithShortWriterStillWritesFullHeaders;
var
  LW: TShortWriter;
  LRW: TH1ResponseWriter;
begin
  LW := TShortWriter.Create(1);
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  try
    LRW.GetHeaders.Set_('Content-Length', '0');
    LRW.WriteHeader(HTTP_STATUS_HEADER_TOO_LARGE);
    CheckEqual('HTTP/1.1 431 Request Header Fields Too Large'#13#10 +
      'content-length: 0'#13#10 +
      #13#10, LW.GetOutput,
      'known status fast path still retries short writes to full framing');
  finally
    LRW.Free;
  end;
end;

procedure TestLargeHeaderBlockFallsBackAndPreservesWireBytes;
var
  LW: TCountingWriter;
  LRW: TH1ResponseWriter;
  LOut: string;
  LValue: string;
begin
  SetLength(LValue, 2100);
  FillChar(LValue[1], Length(LValue), Ord('a'));

  LW := TCountingWriter.Create;
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  try
    LRW.GetHeaders.Set_('Content-Length', '0');
    LRW.GetHeaders.Set_('X-Large', LValue);
    LRW.WriteHeader(HTTP_STATUS_OK);
    LOut := LW.GetOutput;
    CheckEqual('HTTP/1.1 200 OK'#13#10 +
      'content-length: 0'#13#10 +
      'x-large: ' + LValue + #13#10 +
      #13#10, LOut,
      'large header block fallback preserves exact wire bytes');
    CheckEqual(Int64(4), Int64(LW.WriteCalls),
      'large header block falls back before writing partial compact bytes');
  finally
    LRW.Free;
  end;
end;

procedure TestContentLengthBodyWithShortWriterWritesAllBytes;
var
  LW: TShortWriter;
  LRW: TH1ResponseWriter;
  LBody: string;
  LOut: string;
  LWritten: SizeUInt;
begin
  LW := TShortWriter.Create(1);
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LRW.GetHeaders.Set_('Content-Length', '5');
  LRW.WriteHeader(HTTP_STATUS_OK);
  LBody := 'hello';
  LWritten := LRW.Write(LBody[1], SizeUInt(Length(LBody)));
  LOut := LW.GetOutput;
  CheckEqual(Int64(5), Int64(LWritten), 'content-length body reports full bytes');
  CheckEqual('HTTP/1.1 200 OK'#13#10 +
    'content-length: 5'#13#10 +
    #13#10 +
    'hello', LOut,
    'short writer still receives full content-length response body');
  LRW.Free;
end;

procedure TestChunkedBodyWithShortWriterWritesCompleteChunk;
var
  LW: TShortWriter;
  LRW: TH1ResponseWriter;
  LBody: string;
  LOut: string;
  LWritten: SizeUInt;
begin
  LW := TShortWriter.Create(1);
  LRW := TH1ResponseWriter.Create(LW as IWriter);
  LBody := 'hello';
  LWritten := LRW.Write(LBody[1], SizeUInt(Length(LBody)));
  LRW.Flush;
  LOut := LW.GetOutput;
  CheckEqual(Int64(5), Int64(LWritten), 'chunked body reports full bytes');
  CheckEqual('HTTP/1.1 200 OK'#13#10 +
    'transfer-encoding: chunked'#13#10 +
    #13#10 +
    '5'#13#10 +
    'hello'#13#10 +
    '0'#13#10#13#10, LOut,
    'short writer still receives full chunked response');
  LRW.Free;
end;

procedure TestOutboundBufferDrainAllHandlesShortWriter;
var
  LBuffer: IH1OutboundBuffer;
  LW: TShortWriter;
  LIW: IWriter;
  LData: string;
begin
  LBuffer := NewH1OutboundBuffer;
  LData := 'hello';
  CheckEqual(Int64(Length(LData)),
    Int64(LBuffer.Write(LData[1], SizeUInt(Length(LData)))),
    'outbound buffer accepts full write');
  CheckEqual(Int64(Length(LData)), Int64(LBuffer.PendingBytes),
    'outbound buffer tracks pending bytes');

  LW := TShortWriter.Create(1);
  LIW := LW as IWriter;
  try
    CheckEqual(Int64(Length(LData)),
      Int64(LBuffer.DrainAllTo(LIW)),
      'outbound buffer drains all bytes through short writer');
    CheckEqual('hello', LW.GetOutput,
      'outbound buffer preserves bytes across short writes');
    Check(LBuffer.IsEmpty, 'outbound buffer empties after drain');
  finally
    LIW := nil;
  end;
end;

procedure TestOutboundBufferTryDrainResumesAfterWouldBlock;
var
  LBuffer: IH1OutboundBuffer;
  LRuntime: TMockDrainStreamRuntime;
  LRuntimeIntf: ITcpStreamRuntime;
  LData: string;
  LWritten: SizeUInt;
  LResult: TTcpStreamIOResult;
begin
  LBuffer := NewH1OutboundBuffer;
  LData := 'hello';
  LBuffer.Write(LData[1], SizeUInt(Length(LData)));

  LRuntime := TMockDrainStreamRuntime.Create(2, 2);
  LRuntimeIntf := LRuntime as ITcpStreamRuntime;
  try
    LResult := LBuffer.TryDrainTo(LRuntimeIntf, LWritten);
    Check(LResult = tsiorOk, 'first drain writes available bytes');
    CheckEqual(Int64(2), Int64(LWritten), 'first drain writes short slice');
    CheckEqual(Int64(3), Int64(LBuffer.PendingBytes),
      'pending bytes shrink after first drain');
    CheckEqual('he', LRuntime.GetOutput, 'first drain preserves prefix');

    LResult := LBuffer.TryDrainTo(LRuntimeIntf, LWritten);
    Check(LResult = tsiorWouldBlock, 'second drain reports would-block');
    CheckEqual(Int64(0), Int64(LWritten), 'would-block reports zero progress');
    CheckEqual(Int64(3), Int64(LBuffer.PendingBytes),
      'would-block keeps remaining bytes queued');

    LResult := LBuffer.TryDrainTo(LRuntimeIntf, LWritten);
    Check(LResult = tsiorOk, 'third drain resumes after would-block');
    CheckEqual(Int64(2), Int64(LWritten), 'third drain writes next slice');
    CheckEqual(Int64(1), Int64(LBuffer.PendingBytes),
      'pending bytes continue shrinking after resume');

    LResult := LBuffer.TryDrainTo(LRuntimeIntf, LWritten);
    Check(LResult = tsiorOk, 'final drain completes buffer');
    CheckEqual(Int64(1), Int64(LWritten), 'final drain writes last byte');
    Check(LBuffer.IsEmpty, 'outbound buffer empty after resumable drains');
    CheckEqual('hello', LRuntime.GetOutput,
      'resumable drain preserves full byte stream');
  finally
    LRuntimeIntf := nil;
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
  T.Run('Preset Transfer-Encoding is preserved', @TestPresetTransferEncodingPreserved);
  T.Run('Flush with Content-Length does not write final chunk',
    @TestFlushWithContentLengthDoesNotWriteFinalChunk);
  T.Run('204 response does not inject chunked encoding',
    @TestNoContentResponseDoesNotInjectChunkedEncoding);
  T.Run('304 response does not inject chunked encoding',
    @TestNotModifiedResponseDoesNotInjectChunkedEncoding);
  T.Run('100 response does not inject chunked encoding',
    @TestInformationalResponseDoesNotInjectChunkedEncoding);
  T.Run('non-101 informational response allows later final response',
    @TestNonSwitchingInformationalAllowsFinalResponse);
  T.Run('101 response does not inject chunked encoding',
    @TestSwitchingProtocolsResponseDoesNotInjectChunkedEncoding);
  T.Run('101 response rejects body write',
    @TestSwitchingProtocolsResponseRejectsBodyWrite);
  T.Run('204 response rejects body write',
    @TestNoContentResponseRejectsBodyWrite);
  T.Run('Suppressed-body write does not emit body or chunked encoding',
    @TestSuppressBodyWriteDoesNotEmitBodyOrChunkedEncoding);
  T.Run('Suppressed-body preserves explicit content-length',
    @TestSuppressBodyPreservesExplicitContentLength);
  T.Run('Write after chunked flush raises', @TestWriteAfterChunkedFlushRaises);
  T.Run('Flush no-op without IFlusher', @TestFlushNoOpWithoutFlusher);
  T.Run('Hijack without connection raises', @TestHijackWithoutConnectionRaises);
  T.Run('Hijack returns connection and marks writer', @TestHijackReturnsConnectionAndMarksWriter);
  T.Run('WriteHeader with short writer still writes full headers',
    @TestWriteHeaderWithShortWriterStillWritesFullHeaders);
  T.Run('Small header block uses a single writer call',
    @TestSmallHeaderBlockUsesSingleWriterCall);
  T.Run('Common status lines use a single writer call',
    @TestCommonStatusLinesUseSingleWriterCall);
  T.Run('Unknown status line keeps fallback reason',
    @TestUnknownStatusLineKeepsFallbackReason);
  T.Run('Known status line with short writer still writes full headers',
    @TestKnownStatusLineWithShortWriterStillWritesFullHeaders);
  T.Run('Large header block falls back and preserves wire bytes',
    @TestLargeHeaderBlockFallsBackAndPreservesWireBytes);
  T.Run('Content-Length body with short writer writes all bytes',
    @TestContentLengthBodyWithShortWriterWritesAllBytes);
  T.Run('Chunked body with short writer writes complete chunk',
    @TestChunkedBodyWithShortWriterWritesCompleteChunk);
  T.Run('Outbound buffer drains all bytes through short writer',
    @TestOutboundBufferDrainAllHandlesShortWriter);
  T.Run('Outbound buffer resumable drain survives would-block',
    @TestOutboundBufferTryDrainResumesAfterWouldBlock);
  T.Summary;
end.
