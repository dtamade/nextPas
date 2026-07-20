program test_http_q3_matrix;
{**
 * @desc Q3-2 production matrix: timeout / cancel / 413 / 431 aligned with
 *       Go net/http semantic rows (Kind/Op/status line), not a full clone.
 *
 * Go mapping (honesty):
 *   - Client.Timeout / context deadline  → hekTimeout (Op transport when wrap)
 *   - context.Cancel                     → hekCanceled (Op cancel at checkpoint)
 *   - MaxBytesReader / body limit        → 413 Payload Too Large, no handler
 *   - Server.MaxHeaderBytes              → 431 Request Header Fields Too Large
 *}

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.test,
  nextpas.core.text.conv,
  nextpas.core.fs,
  nextpas.core.net,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.http,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.message,
  nextpas.core.http.router,
  nextpas.core.http.server,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.thread;

type
  PServerCtx = ^TServerCtx;
  TServerCtx = record
    Server: IHttpServer;
    Addr: string;
    Port: UInt16;
  end;

var
  T: TTestSuite;
  GHandlerHits: Int32;

function ServerThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PServerCtx;
begin
  Result := nil;
  LCtx := PServerCtx(AArg);
  try
    LCtx^.Server.ListenAndServe(LCtx^.Addr, LCtx^.Port);
  except
  end;
  Dispose(LCtx);
end;

function StartServer(const AHandler: IHttpHandler;
  const AOpts: THttpServerOptions; out AServer: IHttpServer;
  out APort: UInt16): TPlatformThreadHandle;
var
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
begin
  AServer := NewHttpServer(AHandler, AOpts);
  New(LCtx);
  LCtx^.Server := AServer;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0;
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);
  LWait := 0;
  while (not AServer.IsRunning) and (LWait < 400) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;
  Check(AServer.IsRunning, 'matrix server started');
  APort := AServer.LocalAddr.Port;
  Check(APort > 0, 'matrix server port');
  Result := LHandle;
end;

procedure StopServer(var AServer: IHttpServer;
  const AHandle: TPlatformThreadHandle);
var
  LRet: Pointer;
begin
  if AServer <> nil then
    AServer.Shutdown;
  platform_thread_join(AHandle, LRet);
  AServer := nil;
end;

function SendRaw(const APort: UInt16; const AReq: string): string;
var
  LConn: ITcpStream;
  LBuf: array[0..8191] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  LConn := TcpConnect('127.0.0.1', APort);
  try
    LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(3)));
    LConn.Write(AReq[1], SizeUInt(Length(AReq)));
    repeat
      try
        LN := LConn.Read(LBuf[0], SizeUInt(SizeOf(LBuf)));
      except
        LN := 0;
      end;
      if LN > 0 then
      begin
        SetLength(Result, Length(Result) + Int32(LN));
        Move(LBuf[0], Result[Length(Result) - Int32(LN) + 1], LN);
      end;
    until LN = 0;
  finally
    LConn.Close;
  end;
end;

function CountingHandler: IHttpHandler;
var
  LRouter: IHttpRouter;
begin
  LRouter := NewRouter;
  LRouter.Get('/', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
    InterlockedIncrement(GHandlerHits);
    HttpWriteResponseString(AW, HTTP_STATUS_OK, 'text/plain', 'ok');
  end);
  LRouter.Post('/', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
    InterlockedIncrement(GHandlerHits);
    HttpWriteResponseString(AW, HTTP_STATUS_OK, 'text/plain', 'ok');
  end);
  LRouter.Get('/slow', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
    InterlockedIncrement(GHandlerHits);
    { Keep under 1s so suite can join workers before process exit (heaptrc). }
    platform_thread_sleep_ns(800000000);
    HttpWriteResponseString(AW, HTTP_STATUS_OK, 'text/plain', 'ok');
  end);
  Result := LRouter as IHttpHandler;
end;

procedure TestGoAlignedStatusPhrases;
{ Go net/http StatusText(413/431) phrases. }
begin
  Checkequal('Payload Too Large',
    HttpStatusText(HTTP_STATUS_PAYLOAD_TOO_LARGE),
    '413 phrase matches Go StatusText');
  Checkequal('Request Header Fields Too Large',
    HttpStatusText(HTTP_STATUS_HEADER_TOO_LARGE),
    '431 phrase matches Go StatusText');
  Checkequal(Int64(413), Int64(HTTP_STATUS_PAYLOAD_TOO_LARGE), '413 code');
  Checkequal(Int64(431), Int64(HTTP_STATUS_HEADER_TOO_LARGE), '431 code');
end;

procedure TestClientTimeoutMapsLikeGoDeadline;
{ Go Client.Timeout / context deadline → timeout error family. }
var
  LServer: IHttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LOpts: THttpClientOptions;
  LCaught: Boolean;
  LOp: string;
begin
  LHandle := StartServer(CountingHandler, THttpServerOptions.Default,
    LServer, LPort);
  try
    LOpts := THttpClientOptions.Default;
    LOpts.Timeout := 200;
    LClient := NewHttpClient(LOpts);
    LCaught := False;
    LOp := '';
    try
      LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/slow');
    except
      on E: EHttpError do
      begin
        LCaught := True;
        Checkequal(Int64(Ord(hekTimeout)), Int64(Ord(E.Kind)),
          'timeout Kind=hekTimeout (~ Go deadline exceeded family)');
        Check(HttpErrorIsTimeout(E), 'HttpErrorIsTimeout');
        LOp := E.Op;
      end;
      on E: ETimeoutError do
        Check(False, 'bare ETimeoutError must not escape (Go wraps)');
    end;
    Check(LCaught, 'client timeout raised');
    { Wrap path uses Op=transport; acceptable Go-aligned boundary. }
    if LOp <> '' then
      Check((LOp = 'transport') or (LOp = 'round_trip'),
        'timeout Op is transport family, got=' + LOp);
    LClient := nil;
  finally
    StopServer(LServer, LHandle);
    { Drain slow handler worker (~800ms) before process exit heaptrc. }
    platform_thread_sleep_ns(1000000000);
  end;
end;

procedure TestClientCancelMapsLikeGoContextCancel;
{ Go context.Cancel → canceled; nextPas hekCanceled + Op=cancel at checkpoint. }
var
  LToken: IHttpCancelToken;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LCaught: Boolean;
begin
  LToken := NewHttpCancelToken;
  LToken.Cancel;
  LClient := NewHttpClient;
  LReq := THttpRequestBuilder.Create(hmGet, 'http://127.0.0.1:1/')
    .CancelToken(LToken)
    .Build;
  LCaught := False;
  try
    LClient.Send(LReq);
  except
    on E: EHttpError do
    begin
      LCaught := True;
      Checkequal(Int64(Ord(hekCanceled)), Int64(Ord(E.Kind)),
        'cancel Kind=hekCanceled (~ context.Canceled)');
      Checkequal('cancel', E.Op, 'cancel Op=cancel at checkpoint');
    end;
  end;
  Check(LCaught, 'pre-canceled token raises');
end;

procedure TestServer413LikeGoMaxBytesNoHandler;
{ Go MaxBytesReader / body limit → 413, handler not entered. }
var
  LServer: IHttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LOpts: THttpServerOptions;
  LBody, LReq, LResp: string;
begin
  GHandlerHits := 0;
  LOpts := THttpServerOptions.Default;
  LOpts.MaxBodySize := 64;
  LHandle := StartServer(CountingHandler, LOpts, LServer, LPort);
  try
    SetLength(LBody, 256);
    FillChar(LBody[1], 256, Ord('A'));
    LReq := 'POST / HTTP/1.1'#13#10 +
            'Host: x'#13#10 +
            'Content-Length: 256'#13#10 +
            'Connection: close'#13#10#13#10 +
            LBody;
    LResp := SendRaw(LPort, LReq);
    Check(Pos('HTTP/1.1 413 Payload Too Large', LResp) > 0,
      '413 status line + Go phrase');
    Check(Pos('HTTP/1.1 200', LResp) = 0, 'no 200 after oversize body');
    Checkequal(Int64(0), Int64(GHandlerHits), 'handler not entered on 413');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestServer431LikeGoMaxHeaderBytesNoHandler;
{ Go Server.MaxHeaderBytes → 431. }
var
  LServer: IHttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LOpts: THttpServerOptions;
  LLong, LReq, LResp: string;
begin
  GHandlerHits := 0;
  LOpts := THttpServerOptions.Default;
  LOpts.MaxHeaderSize := 128;
  LHandle := StartServer(CountingHandler, LOpts, LServer, LPort);
  try
    SetLength(LLong, 200);
    FillChar(LLong[1], 200, Ord('H'));
    LReq := 'GET / HTTP/1.1'#13#10 +
            'Host: x'#13#10 +
            'X-Long: ' + LLong + #13#10 +
            'Connection: close'#13#10#13#10;
    LResp := SendRaw(LPort, LReq);
    Check(Pos('HTTP/1.1 431 Request Header Fields Too Large', LResp) > 0,
      '431 status line + Go phrase');
    Check(Pos('HTTP/1.1 200', LResp) = 0, 'no 200 after oversize headers');
    Checkequal(Int64(0), Int64(GHandlerHits), 'handler not entered on 431');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestSourceContractOpAndPhraseLocks;
var
  LBase, LContract: string;
begin
  LBase := ReadFileText('../../../src/nextpas.core.http.base.pas');
  LContract := ReadFileText('../../../docs/http/CONTRACT.md');
  Check(Pos('raise EHttpError.CreateOp(hekCanceled, ''cancel'',', LBase) > 0,
    'cancel checkpoint Op=cancel');
  Check(Pos('Result := EHttpError.CreateOp(hekTimeout, ''transport'',', LBase) > 0,
    'timeout wrap Op=transport');
  Check(Pos('413: Result := ''Payload Too Large''', LBase) > 0,
    'base status text 413');
  Check(Pos('431: Result := ''Request Header Fields Too Large''', LBase) > 0,
    'base status text 431');
  Check(Pos('Q3-2', LContract) > 0,
    'CONTRACT documents Q3-2 matrix section');
  Check(Pos('hekTimeout', LContract) > 0, 'CONTRACT Kind table');
  Check(Pos('hekCanceled', LContract) > 0, 'CONTRACT cancel Kind');
end;

begin
  T := TTestSuite.Create('nextpas.core.http Q3-2 Go-aligned matrix');
  T.Test('Status phrases 413/431 match Go StatusText',
    @TestGoAlignedStatusPhrases);
  T.Test('Client timeout → hekTimeout (Go deadline family)',
    @TestClientTimeoutMapsLikeGoDeadline);
  T.Test('Client cancel → hekCanceled Op=cancel (Go context.Canceled)',
    @TestClientCancelMapsLikeGoContextCancel);
  T.Test('Server oversize body → 413 no handler (Go MaxBytes-like)',
    @TestServer413LikeGoMaxBytesNoHandler);
  T.Test('Server oversize headers → 431 no handler (Go MaxHeaderBytes)',
    @TestServer431LikeGoMaxHeaderBytesNoHandler);
  T.Test('Source-contract Op/phrase + CONTRACT Q3-2 section',
    @TestSourceContractOpAndPhraseLocks);
  if not T.Run then
    Halt(1);
end.
