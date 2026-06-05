program bench_fullchain;
{**
 * @desc Full-chain HTTP benchmark — measures complete request-response cycle:
 *       TCP accept, parse, route, handler, serialize, write, client read.
 *       Single connection, keep-alive, reports req/s per scenario.
 *}

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.router,
  nextpas.core.http.server,
  nextpas.core.http.middleware,
  nextpas.core.net,
  nextpas.core.net.intf,
  nextpas.core.io.intf,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.thread,
  nextpas.core.platform.time;

const
  ITERATIONS = 5000;

var
  GServer: THttpServer;
  GPort: UInt16;

function ServerThread(AParam: Pointer): Pointer; cdecl;
begin
  Result := nil;
  GServer.ListenAndServe('127.0.0.1', 0);
end;

procedure SetupServer;
var
  LRouter: THttpRouter;
  LHandle: TPlatformThreadHandle;
  LBody1K: string;
begin
  SetLength(LBody1K, 1024);
  FillChar(LBody1K[1], 1024, Ord('x'));

  LRouter := THttpRouter.Create;

  { Plaintext }
  LRouter.Get('/', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AW.GetHeaders.Set_('content-type', 'text/plain');
    AW.GetHeaders.Set_('content-length', '13');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(PAnsiChar('Hello, World!')^, 13);
  end);

  { JSON }
  LRouter.Get('/json', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  const BODY = '{"message":"Hello, World!"}';
  begin
    AW.GetHeaders.Set_('content-type', 'application/json');
    AW.GetHeaders.Set_('content-length', '27');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(PAnsiChar(BODY)^, 27);
  end);

  { Echo POST body }
  LRouter.Post('/echo', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBuf: array[0..4095] of Byte; LN: SizeUInt; LTotal: SizeUInt;
  begin
    LTotal := 0;
    if AReq.Body <> nil then
    begin
      repeat
        LN := AReq.Body.Read(LBuf[0], 4096);
        LTotal := LTotal + LN;
      until LN = 0;
    end;
    AW.GetHeaders.Set_('content-type', 'application/octet-stream');
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(LTotal)));
    AW.WriteHeader(HTTP_STATUS_OK);
    { Echo back same size — just write the buffer contents }
    if LTotal > 0 then
      AW.Write(LBuf[0], LTotal);
  end);

  { Drain POST body without echoing it back. }
  LRouter.Post('/sink', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBuf: array[0..4095] of Byte; LN: SizeUInt;
  begin
    if AReq.Body <> nil then
    begin
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeOf(LBuf));
      until LN = 0;
    end;
    AW.GetHeaders.Set_('content-length', '0');
    AW.WriteHeader(HTTP_STATUS_OK);
  end);

  { Router with params }
  LRouter.Get('/users/:id', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LBody: string;
  begin
    LBody := 'user:' + AReq.PathParam('id');
    AW.GetHeaders.Set_('content-type', 'text/plain');
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);

  GServer := THttpServer.Create(LRouter as IHttpHandler, THttpServerOptions.Default);
  platform_thread_create(LHandle, @ServerThread, nil);
  while not GServer.IsRunning do
    platform_thread_sleep_ns(1000000);
  GPort := GServer.LocalAddr.Port;
end;

{ Read one full HTTP response from a keep-alive connection }
function ReadResponse(const AConn: ITcpStream): SizeUInt;
var
  LBuf: array[0..4095] of Byte;
  LN, LTotal: SizeUInt;
  LHeaderEnd: Int32;
  LResp: string;
  LClPos, LClEnd: Int32;
  LContentLen, LBodyRead: Int32;
begin
  LResp := '';
  LTotal := 0;
  { Read until we see CRLFCRLF }
  repeat
    LN := AConn.Read(LBuf[0], 1);
    if LN = 0 then begin Result := LTotal; Exit; end;
    Inc(LTotal, LN);
    LResp := LResp + Chr(LBuf[0]);
    LHeaderEnd := Pos(#13#10#13#10, LResp);
  until LHeaderEnd > 0;

  { Parse content-length }
  LContentLen := 0;
  LClPos := Pos('content-length: ', LResp);
  if LClPos > 0 then
  begin
    LClPos := LClPos + 16;
    LClEnd := LClPos;
    while (LClEnd <= Length(LResp)) and (LResp[LClEnd] >= '0') and (LResp[LClEnd] <= '9') do
      Inc(LClEnd);
    LContentLen := Int32(StrToInt(Copy(LResp, LClPos, LClEnd - LClPos)));
  end;

  { Read body }
  LBodyRead := Length(LResp) - (LHeaderEnd + 3);
  while LBodyRead < LContentLen do
  begin
    LN := AConn.Read(LBuf[0], SizeUInt(LContentLen - LBodyRead));
    if LN = 0 then Break;
    Inc(LBodyRead, Int32(LN));
    Inc(LTotal, LN);
  end;
  Result := LTotal;
end;

procedure RunScenario(const AName, ARequest: string; AExpectMin: SizeUInt);
var
  LConn: ITcpStream;
  LStart, LEnd, LElapsedNs: UInt64;
  LI: Int32;
  LReqPerSec: Double;
begin
  LConn := TcpConnect('127.0.0.1', GPort);
  LConn.SetNoDelay(True);
  LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(30)));

  { Warmup }
  for LI := 1 to 10 do
  begin
    LConn.Write(ARequest[1], SizeUInt(Length(ARequest)));
    ReadResponse(LConn);
  end;

  LStart := platform_monotonic_ns;
  for LI := 1 to ITERATIONS do
  begin
    LConn.Write(ARequest[1], SizeUInt(Length(ARequest)));
    ReadResponse(LConn);
  end;
  LEnd := platform_monotonic_ns;
  LConn.Close;

  LElapsedNs := LEnd - LStart;
  LReqPerSec := (Double(ITERATIONS) / (Double(LElapsedNs) / 1000000000.0));
  WriteLn('  ', AName:25, '  ', ITERATIONS, ' reqs  ', LElapsedNs div 1000000, ' ms  ',
    Trunc(LReqPerSec):8, ' req/s');
end;

var
  LBody1K: string;
  LEchoReq: string;
  LBody16K: string;
  LSinkReq: string;

begin
  WriteLn('=== HTTP Full-Chain Benchmark ===');
  WriteLn('  Iterations per scenario: ', ITERATIONS);
  WriteLn;

  SetupServer;
  WriteLn('  Server listening on port ', GPort);
  WriteLn;

  { Scenario 1: Plaintext }
  RunScenario('Plaintext (GET /)',
    'GET / HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 0'#13#10#13#10, 50);

  { Scenario 2: JSON }
  RunScenario('JSON (GET /json)',
    'GET /json HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 0'#13#10#13#10, 60);

  { Scenario 3: Body echo 1KB }
  SetLength(LBody1K, 1024);
  FillChar(LBody1K[1], 1024, Ord('x'));
  LEchoReq := 'POST /echo HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 1024'#13#10#13#10 + LBody1K;
  RunScenario('Echo 1KB (POST /echo)', LEchoReq, 100);

  { Scenario 4: Body sink 16KB }
  SetLength(LBody16K, 16 * 1024);
  FillChar(LBody16K[1], Length(LBody16K), Ord('x'));
  LSinkReq := 'POST /sink HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: ' +
    IntToStr(Int64(Length(LBody16K))) + #13#10#13#10 + LBody16K;
  RunScenario('Sink 16KB (POST /sink)', LSinkReq, 100);

  { Scenario 5: Router with params }
  RunScenario('Param (GET /users/12345)',
    'GET /users/12345 HTTP/1.1'#13#10'Host: x'#13#10'Content-Length: 0'#13#10#13#10, 50);

  WriteLn;
  GServer.Shutdown;
  GServer.Free;
  WriteLn('Done.');
end.
