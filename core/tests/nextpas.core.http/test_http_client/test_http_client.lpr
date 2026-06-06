program test_http_client;

{$I nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.text.conv,
  nextpas.core.errors,
  nextpas.core.fs,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.net,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.tcp,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.router,
  nextpas.core.http.server,
  nextpas.core.http.client,
  nextpas.core.http,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.platform.thread;

var
  T: TTestRunner;
  GRawListener: ITcpListener;
  GRawResponse1: string;
  GRawResponse2: string;
  GRawAcceptLimit: Int32;
  GAcceptCount: Int32;
  GPoolListener: ITcpListener;
  GRetryListener: ITcpListener;
  GRetryAcceptCount: Int32;
  GRetrySecondMethod: string;
  GRetrySecondBody: string;

type
  PServerCtx = ^TServerCtx;
  TServerCtx = record
    Server: THttpServer;
    Addr: string;
    Port: UInt16;
  end;

  TRedirectCaptureTransport = class(TInterfacedObject, IHttpTransport)
  private
    FCalls: Int32;
    FRedirectLocation: string;
    FRedirectStatus: THttpStatus;
    FFirstBody: string;
    FSecondBody: string;
    FSeenMethod: THttpMethod;
    FSeenScheme: string;
    FSeenHost: string;
    FSeenPath: string;
    FSeenRawQuery: string;
    FSeenQueryParam: string;
    FSeenFragment: string;
    FSeenHostHeader: string;
    FSeenTraceHeader: string;
    FSeenAuthorizationHeader: string;
    FSeenWwwAuthenticateHeader: string;
    FSeenCookieHeader: string;
    FSeenCookie2Header: string;
  public
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
    property Calls: Int32 read FCalls;
    property RedirectLocation: string read FRedirectLocation write FRedirectLocation;
    property RedirectStatus: THttpStatus read FRedirectStatus write FRedirectStatus;
    property FirstBody: string read FFirstBody;
    property SecondBody: string read FSecondBody;
    property SeenMethod: THttpMethod read FSeenMethod;
    property SeenScheme: string read FSeenScheme;
    property SeenHost: string read FSeenHost;
    property SeenPath: string read FSeenPath;
    property SeenRawQuery: string read FSeenRawQuery;
    property SeenQueryParam: string read FSeenQueryParam;
    property SeenFragment: string read FSeenFragment;
    property SeenHostHeader: string read FSeenHostHeader;
    property SeenTraceHeader: string read FSeenTraceHeader;
    property SeenAuthorizationHeader: string read FSeenAuthorizationHeader;
    property SeenWwwAuthenticateHeader: string read FSeenWwwAuthenticateHeader;
    property SeenCookieHeader: string read FSeenCookieHeader;
    property SeenCookie2Header: string read FSeenCookie2Header;
  end;

  TNilResponseTransport = class(TInterfacedObject, IHttpTransport)
  public
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
  end;

  TOneShotReader = class(TInterfacedObject, IReader)
  private
    FData: string;
    FPos: SizeInt;
  public
    constructor Create(const AData: string);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
  end;

  TRedirectTrackedBody = class(TInterfacedObject, IReader, IReadCloser)
  private
    FData: string;
    FPos: SizeInt;
    FClosed: Boolean;
  public
    constructor Create(const AData: string);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
    property Closed: Boolean read FClosed;
  end;

  TRedirectBodyReleaseTransport = class(TInterfacedObject, IHttpTransport)
  private
    FCalls: Int32;
    FRedirectLocation: string;
    FOmitLocation: Boolean;
    FBody: TRedirectTrackedBody;
    FBodyRef: IReadCloser;
    FBodyClosedBeforeFollowup: Boolean;
    function GetBodyClosed: Boolean;
  public
    constructor Create;
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
    property Calls: Int32 read FCalls;
    property RedirectLocation: string read FRedirectLocation write FRedirectLocation;
    property OmitLocation: Boolean read FOmitLocation write FOmitLocation;
    property BodyClosed: Boolean read GetBodyClosed;
    property BodyClosedBeforeFollowup: Boolean read FBodyClosedBeforeFollowup;
  end;

  TRedirectDrainingBody = class(TInterfacedObject, IReader)
  private
    FData: string;
    FPos: SizeInt;
    FDrained: Boolean;
  public
    constructor Create(const AData: string);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    property Drained: Boolean read FDrained;
  end;

  TRedirectBodyDrainTransport = class(TInterfacedObject, IHttpTransport)
  private
    FCalls: Int32;
    FBody: TRedirectDrainingBody;
    FBodyRef: IReader;
    FBodyDrainedBeforeFollowup: Boolean;
  public
    constructor Create;
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
    property Calls: Int32 read FCalls;
    property BodyDrainedBeforeFollowup: Boolean read FBodyDrainedBeforeFollowup;
  end;

  TDownloadClient = class(TInterfacedObject, IHttpClient)
  private
    FResponse: IHttpResponse;
    FSeenUrl: string;
  public
    constructor Create(const AResponse: IHttpResponse);
    function Do_(const AReq: IHttpRequest): IHttpResponse;
    procedure CloseIdleConnections;
    function Get(const AUrl: string): IHttpResponse;
    function Post(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse; overload;
    function Post(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload;
    function Post(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload;
    function Put(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse; overload;
    function Put(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload;
    function Put(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload;
    function Delete(const AUrl: string): IHttpResponse;
    function Patch(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse; overload;
    function Patch(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload;
    function Patch(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload;
    function Head(const AUrl: string): IHttpResponse;
    property SeenUrl: string read FSeenUrl;
  end;

  TZeroProgressWriter = class(TInterfacedObject, IWriter)
  public
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
  end;

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

function PoolAcceptThread(AArg: Pointer): Pointer; cdecl; forward;

function RawResponseThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LAccum: string;
  LReply: string;
  LI: Int32;
  LP: SizeInt;
begin
  Result := nil;
  for LI := 1 to GRawAcceptLimit do
  begin
    try
      LConn := GRawListener.Accept;
    except
      Break;
    end;
    if LConn = nil then
      Break;
    try
      LAccum := '';
      repeat
        LN := LConn.Read(LBuf[0], 4096);
        if LN = 0 then
          Break;
        SetLength(LAccum, Length(LAccum) + Int32(LN));
        Move(LBuf[0], LAccum[Length(LAccum) - Int32(LN) + 1], LN);
        LP := Pos(#13#10#13#10, LAccum);
      until LP > 0;

      if LI = 1 then
        LReply := GRawResponse1
      else
        LReply := GRawResponse2;

      if LReply <> '' then
        LConn.Write(LReply[1], SizeUInt(Length(LReply)));
    except
    end;
    LConn.Close;
  end;
end;

function RetryRequestMethod(const ARawRequest: string): string;
var
  LSpacePos: SizeInt;
begin
  Result := '';
  LSpacePos := Pos(' ', ARawRequest);
  if LSpacePos > 1 then
    Result := System.Copy(ARawRequest, 1, LSpacePos - 1);
end;

function RetryRequestContentLength(const ARawHeaders: string): Int64;
var
  LLowerHeaders: string;
  LHeaderPos: SizeInt;
  LValueStart: SizeInt;
  LValueEnd: SizeInt;
begin
  Result := 0;
  LLowerHeaders := LowerCase(ARawHeaders);
  LHeaderPos := Pos(#13#10 + 'content-length:', LLowerHeaders);
  if LHeaderPos = 0 then
    Exit;

  LValueStart := LHeaderPos + 2 + Length('content-length:');
  LValueEnd := LValueStart;
  while (LValueEnd <= Length(ARawHeaders)) and (ARawHeaders[LValueEnd] <> #13) do
    Inc(LValueEnd);
  Result := StrToInt64Def(Trim(System.Copy(ARawHeaders, LValueStart,
    LValueEnd - LValueStart)), 0);
end;

procedure ReadRetryRawRequest(const AConn: ITcpStream; out AMethod, ABody: string);
var
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LAccum: string;
  LHeadersEnd: SizeInt;
  LExpectedBodyLen: Int64;
begin
  AMethod := '';
  ABody := '';
  LAccum := '';
  AConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(500)));

  repeat
    try
      LN := AConn.Read(LBuf[0], 4096);
    except
      Break;
    end;
    if LN = 0 then
      Break;
    SetLength(LAccum, Length(LAccum) + Int32(LN));
    Move(LBuf[0], LAccum[Length(LAccum) - Int32(LN) + 1], LN);
    LHeadersEnd := Pos(#13#10#13#10, LAccum);
  until LHeadersEnd > 0;

  if LAccum = '' then
    Exit;

  AMethod := RetryRequestMethod(LAccum);
  LHeadersEnd := Pos(#13#10#13#10, LAccum);
  if LHeadersEnd = 0 then
    Exit;

  LExpectedBodyLen := RetryRequestContentLength(System.Copy(LAccum, 1, LHeadersEnd + 3));
  ABody := System.Copy(LAccum, LHeadersEnd + 4, MaxInt);
  while Int64(Length(ABody)) < LExpectedBodyLen do
  begin
    try
      LN := AConn.Read(LBuf[0], 4096);
    except
      Break;
    end;
    if LN = 0 then
      Break;
    SetLength(ABody, Length(ABody) + Int32(LN));
    Move(LBuf[0], ABody[Length(ABody) - Int32(LN) + 1], LN);
  end;

  if Int64(Length(ABody)) > LExpectedBodyLen then
    SetLength(ABody, LExpectedBodyLen);
end;

procedure WakeRetryAcceptThread(const APort: UInt16);
var
  LConn: ITcpStream;
begin
  try
    LConn := TcpConnect('127.0.0.1', APort);
    if LConn <> nil then
      LConn.Close;
  except
  end;
end;

function StaleRetryThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LReply: string;
  LI: Int32;
  LMethod: string;
  LBody: string;
begin
  Result := nil;
  for LI := 1 to 2 do
  begin
    try
      LConn := GRetryListener.Accept;
    except
      Break;
    end;
    if LConn = nil then
      Break;

    InterlockedIncrement(GRetryAcceptCount);
    try
      ReadRetryRawRequest(LConn, LMethod, LBody);
      if LI = 2 then
      begin
        GRetrySecondMethod := LMethod;
        GRetrySecondBody := LBody;
      end;

      if (LI = 2) and (LBody <> 'payload') then
        LReply := 'HTTP/1.1 400 Bad Request'#13#10 +
                  'Content-Length: 3'#13#10 +
                  #13#10 +
                  'bad'
      else if LI = 2 then
        LReply := 'HTTP/1.1 200 OK'#13#10 +
                  'Content-Length: 8'#13#10 +
                  #13#10 +
                  'retry-ok'
      else
        LReply := 'HTTP/1.1 200 OK'#13#10 +
                  'Content-Length: 2'#13#10 +
                  #13#10 +
                  'ok';
      LConn.Write(LReply[1], SizeUInt(Length(LReply)));
    except
    end;
    LConn.Close;
  end;
end;

function StartServer(const AHandler: IHttpHandler; out AServer: THttpServer; out APort: UInt16): TPlatformThreadHandle;
var
  LCtx: PServerCtx;
  LHandle: TPlatformThreadHandle;
  LWait: Int32;
begin
  AServer := THttpServer.Create(AHandler, THttpServerOptions.Default);
  New(LCtx);
  LCtx^.Server := AServer;
  LCtx^.Addr := '127.0.0.1';
  LCtx^.Port := 0; { OS picks a free port }
  platform_thread_create(LHandle, @ServerThreadFunc, LCtx);
  { Wait for server to start listening }
  LWait := 0;
  while (not AServer.IsRunning) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000); { 5ms }
    Inc(LWait);
  end;
  APort := AServer.LocalAddr.Port;
  Result := LHandle;
end;

procedure StopServer(var AServer: THttpServer; const AHandle: TPlatformThreadHandle);
var
  LRet: Pointer;
begin
  AServer.Shutdown;
  platform_thread_join(AHandle, LRet);
  AServer.Free;
  AServer := nil;
end;

function ReadReaderStr(const AReader: IReader): string;
var
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  if AReader = nil then Exit;
  repeat
    LN := AReader.Read(LBuf[0], 4096);
    if LN > 0 then
    begin
      SetLength(Result, Length(Result) + Int32(LN));
      Move(LBuf[0], Result[Length(Result) - Int32(LN) + 1], LN);
    end;
  until LN = 0;
end;

function BytesToTestString(const ABytes: TBytes): string;
begin
  Result := '';
  SetLength(Result, Length(ABytes));
  if Length(ABytes) > 0 then
    Move(ABytes[0], Result[1], Length(ABytes));
end;

function ReadBodyStr(const AResp: IHttpResponse): string;
begin
  if AResp.Body = nil then
    Exit('');
  Result := ReadReaderStr(AResp.Body);
end;

function StringBodyReader(const AValue: string): IReader;
var
  LData: TBytes;
begin
  SetLength(LData, Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[1], LData[0], Length(AValue));
  Result := CreateBytesStreamFrom(LData) as IReader;
end;

function TRedirectCaptureTransport.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
var
  LHeaders: IHttpHeaders;
  LLocation: string;
  LStatus: THttpStatus;
  LUrl: TUrl;
  LBody: string;
begin
  Inc(FCalls);
  LBody := ReadReaderStr(AReq.Body);
  LHeaders := NewHttpHeaders;
  if FCalls = 1 then
  begin
    FFirstBody := LBody;
    LLocation := FRedirectLocation;
    if LLocation = '' then
      LLocation := '/new?from=redirect';
    LHeaders.Set_('location', LLocation);
    LHeaders.Set_('content-length', '0');
    LStatus := FRedirectStatus;
    if LStatus = 0 then
      LStatus := HTTP_STATUS_FOUND;
    Exit(NewResponse(LStatus, LHeaders, nil));
  end;

  FSecondBody := LBody;
  LUrl := AReq.Url;
  FSeenMethod := AReq.Method;
  FSeenScheme := LUrl.Scheme;
  FSeenHost := LUrl.Host;
  FSeenPath := AReq.Path;
  FSeenRawQuery := AReq.RawQuery;
  FSeenQueryParam := AReq.QueryParam('from');
  FSeenFragment := LUrl.Fragment;
  FSeenHostHeader := AReq.Headers.Get('host');
  FSeenTraceHeader := AReq.Headers.Get('x-trace');
  FSeenAuthorizationHeader := AReq.Headers.Get('authorization');
  FSeenWwwAuthenticateHeader := AReq.Headers.Get('www-authenticate');
  FSeenCookieHeader := AReq.Headers.Get('cookie');
  FSeenCookie2Header := AReq.Headers.Get('cookie2');
  LHeaders.Set_('content-length', '7');
  Result := NewResponse(HTTP_STATUS_OK, LHeaders, StringBodyReader('arrived'));
end;

function TNilResponseTransport.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
begin
  Result := nil;
end;

constructor TOneShotReader.Create(const AData: string);
begin
  inherited Create;
  FData := AData;
  FPos := 1;
end;

function TOneShotReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LRemaining: SizeInt;
begin
  if (ACount = 0) or (FPos > Length(FData)) then
    Exit(0);
  LRemaining := Length(FData) - FPos + 1;
  if SizeUInt(LRemaining) > ACount then
    Result := ACount
  else
    Result := SizeUInt(LRemaining);
  Move(FData[FPos], ABuf, Result);
  Inc(FPos, SizeInt(Result));
end;

constructor TRedirectTrackedBody.Create(const AData: string);
begin
  inherited Create;
  FData := AData;
  FPos := 1;
  FClosed := False;
end;

function TRedirectTrackedBody.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LRemaining: SizeInt;
begin
  if FClosed or (ACount = 0) or (FPos > Length(FData)) then
    Exit(0);
  LRemaining := Length(FData) - FPos + 1;
  if SizeUInt(LRemaining) > ACount then
    Result := ACount
  else
    Result := SizeUInt(LRemaining);
  Move(FData[FPos], ABuf, Result);
  Inc(FPos, SizeInt(Result));
end;

procedure TRedirectTrackedBody.Close;
begin
  FClosed := True;
end;

constructor TRedirectBodyReleaseTransport.Create;
begin
  inherited Create;
  FRedirectLocation := '/final';
  FOmitLocation := False;
  FBody := TRedirectTrackedBody.Create('redirect-body');
  FBodyRef := FBody as IReadCloser;
end;

function TRedirectBodyReleaseTransport.GetBodyClosed: Boolean;
begin
  Result := FBody.Closed;
end;

function TRedirectBodyReleaseTransport.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
var
  LHeaders: IHttpHeaders;
begin
  Inc(FCalls);
  LHeaders := NewHttpHeaders;
  if FCalls = 1 then
  begin
    if not FOmitLocation then
      LHeaders.Set_('location', FRedirectLocation);
    LHeaders.Set_('content-length', '13');
    Exit(NewResponse(HTTP_STATUS_FOUND, LHeaders, FBodyRef as IReader));
  end;

  FBodyClosedBeforeFollowup := FBody.Closed;
  LHeaders.Set_('content-length', '7');
  if FBodyClosedBeforeFollowup then
    Result := NewResponse(HTTP_STATUS_OK, LHeaders, StringBodyReader('arrived'))
  else
    Result := NewResponse(THttpStatus(599), LHeaders, StringBodyReader('leaked!'));
end;

constructor TRedirectDrainingBody.Create(const AData: string);
begin
  inherited Create;
  FData := AData;
  FPos := 1;
  FDrained := False;
end;

function TRedirectDrainingBody.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LRemaining: SizeInt;
begin
  if (ACount = 0) or (FPos > Length(FData)) then
  begin
    FDrained := True;
    Exit(0);
  end;
  LRemaining := Length(FData) - FPos + 1;
  if SizeUInt(LRemaining) > ACount then
    Result := ACount
  else
    Result := SizeUInt(LRemaining);
  Move(FData[FPos], ABuf, Result);
  Inc(FPos, SizeInt(Result));
end;

constructor TRedirectBodyDrainTransport.Create;
begin
  inherited Create;
  FBody := TRedirectDrainingBody.Create('redirect-body');
  FBodyRef := FBody as IReader;
end;

function TRedirectBodyDrainTransport.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
var
  LHeaders: IHttpHeaders;
begin
  Inc(FCalls);
  LHeaders := NewHttpHeaders;
  if FCalls = 1 then
  begin
    LHeaders.Set_('location', '/final');
    LHeaders.Set_('content-length', '13');
    Exit(NewResponse(HTTP_STATUS_FOUND, LHeaders, FBodyRef));
  end;

  FBodyDrainedBeforeFollowup := FBody.Drained;
  LHeaders.Set_('content-length', '7');
  if FBodyDrainedBeforeFollowup then
    Result := NewResponse(HTTP_STATUS_OK, LHeaders, StringBodyReader('arrived'))
  else
    Result := NewResponse(THttpStatus(599), LHeaders, StringBodyReader('leaked!'));
end;

constructor TDownloadClient.Create(const AResponse: IHttpResponse);
begin
  inherited Create;
  FResponse := AResponse;
end;

function TDownloadClient.Do_(const AReq: IHttpRequest): IHttpResponse;
begin
  Result := FResponse;
end;

procedure TDownloadClient.CloseIdleConnections;
begin
end;

function TDownloadClient.Get(const AUrl: string): IHttpResponse;
begin
  FSeenUrl := AUrl;
  Result := FResponse;
end;

function TDownloadClient.Post(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
begin
  Result := FResponse;
end;

function TDownloadClient.Post(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
begin
  Result := FResponse;
end;

function TDownloadClient.Post(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
begin
  Result := FResponse;
end;

function TDownloadClient.Put(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
begin
  Result := FResponse;
end;

function TDownloadClient.Put(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
begin
  Result := FResponse;
end;

function TDownloadClient.Put(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
begin
  Result := FResponse;
end;

function TDownloadClient.Delete(const AUrl: string): IHttpResponse;
begin
  Result := FResponse;
end;

function TDownloadClient.Patch(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
begin
  Result := FResponse;
end;

function TDownloadClient.Patch(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
begin
  Result := FResponse;
end;

function TDownloadClient.Patch(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
begin
  Result := FResponse;
end;

function TDownloadClient.Head(const AUrl: string): IHttpResponse;
begin
  Result := FResponse;
end;

function TZeroProgressWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  Result := 0;
end;

function DownloadTempRoot: string;
begin
  Result := PathJoin([GetTempDir, 'nextpas-http-client-download']);
end;

procedure ResetDownloadTempRoot;
begin
  RemoveAll(DownloadTempRoot);
  MkdirAll(DownloadTempRoot);
end;

{ Test 1: Client GET returns 200 + body }
procedure TestClientGet200;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LBody: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/hello', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LB: string;
  begin
    LB := 'world';
    AW.GetHeaders.Set_('content-length', '5');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], 5);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/hello');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    LBody := ReadBodyStr(LResp);
    CheckEqual('world', LBody, 'body matches');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientDoRejectsNilRequest;
var
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LRaised: Boolean;
begin
  LClient := NewHttpClient;
  LReq := nil;
  LRaised := False;
  try
    LClient.Do_(LReq);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'Client.Do_ rejects nil request');
end;

procedure TestClientDoRejectsNilTransportResponse;
var
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LRaised: Boolean;
begin
  LTransport := TNilResponseTransport.Create as IHttpTransport;
  LClient := NewHttpClient(LTransport);
  LReq := NewRequest(hmGet, 'http://example.test/');

  LRaised := False;
  try
    LClient.Do_(LReq);
  except
    on E: EHttpError do
      LRaised := True;
  end;

  Check(LRaised, 'Client.Do_ rejects nil transport response');
end;

// PLACEHOLDER_TEST2

{ Test 2: Client GET with custom headers }
procedure TestClientGetCustomHeaders;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LReq: IHttpRequest;
  LUrl: TUrl;
  LGotHeader: string;
begin
  LGotHeader := '';
  LRouter := THttpRouter.Create;
  LRouter.Get('/echo-header', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LB: string;
  begin
    LGotHeader := AReq.Headers.Get('x-custom');
    LB := 'ok';
    AW.GetHeaders.Set_('content-length', '2');
    AW.GetHeaders.Set_('x-echo', LGotHeader);
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LUrl := TUrl.Parse('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/echo-header');
    LReq := THttpRequest.Create(hmGet, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
    LReq.Headers.Set_('x-custom', 'hello-from-client');
    LResp := LClient.Do_(LReq);
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    CheckEqual('hello-from-client', LResp.Headers.Get('x-echo'), 'custom header echoed');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 3: Client POST with body }
procedure TestClientPostBody;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LBody: string;
  LBodyStream: IStream;
  LPostData: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Post('/submit', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LB: string;
  begin
    LB := 'accepted';
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LB))));
    AW.WriteHeader(HTTP_STATUS_CREATED);
    AW.Write(LB[1], SizeUInt(Length(LB)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LPostData := 'key=value';
    LBodyStream := CreateBytesStreamFrom(nil);
    (LBodyStream as IWriter).Write(LPostData[1], SizeUInt(Length(LPostData)));
    LBodyStream.Position := 0;
    LResp := LClient.Post(
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/submit',
      'application/x-www-form-urlencoded',
      LBodyStream as IReader);
    CheckEqual(Int64(201), Int64(LResp.StatusCode), 'status 201');
    LBody := ReadBodyStr(LResp);
    CheckEqual('accepted', LBody, 'body matches');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientDoWithRequestHelperHeadersBody;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LReq: IHttpRequest;
  LHeaders: IHttpHeaders;
  LGotHeader: string;
  LGotContentLength: Int64;
  LGotBody: string;
begin
  LGotHeader := '';
  LGotContentLength := -1;
  LGotBody := '';
  LRouter := THttpRouter.Create;
  LRouter.Post('/builder', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LB: string;
  begin
    LGotHeader := AReq.Headers.Get('x-client');
    LGotContentLength := AReq.ContentLength;
    LGotBody := ReadReaderStr(AReq.Body);
    LB := 'ok';
    AW.GetHeaders.Set_('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LHeaders := NewHeaders;
    LHeaders.Set_('x-client', 'request-helper');
    LReq := nextpas.core.http.NewRequest(hmPost,
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/builder',
      LHeaders, 'payload');

    LResp := LClient.Do_(LReq);

    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    CheckEqual('request-helper', LGotHeader, 'custom header forwarded');
    CheckEqual(Int64(7), LGotContentLength, 'content-length forwarded');
    CheckEqual('payload', LGotBody, 'body forwarded');
    CheckEqual('ok', ReadBodyStr(LResp), 'response body');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientDoWithRequestHelperBytesBody;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LReq: IHttpRequest;
  LHeaders: IHttpHeaders;
  LBody: TBytes;
  LGotContentLength: Int64;
  LGotBody: string;
begin
  LGotContentLength := -1;
  LGotBody := '';
  LRouter := THttpRouter.Create;
  LRouter.Post('/bytes', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LB: string;
  begin
    LGotContentLength := AReq.ContentLength;
    LGotBody := ReadReaderStr(AReq.Body);
    LB := 'ok';
    AW.GetHeaders.Set_('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LHeaders := NewHeaders;
    LHeaders.Set_('x-client', 'bytes-helper');
    SetLength(LBody, 5);
    LBody[0] := Ord('b');
    LBody[1] := Ord('i');
    LBody[2] := Ord('n');
    LBody[3] := 0;
    LBody[4] := 255;
    LReq := nextpas.core.http.NewRequest(hmPost,
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/bytes',
      LHeaders, LBody);

    LResp := LClient.Do_(LReq);

    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    CheckEqual(Int64(5), LGotContentLength, 'bytes content-length forwarded');
    CheckEqual('bin' + #0 + #255, LGotBody, 'bytes body forwarded');
    CheckEqual('ok', ReadBodyStr(LResp), 'response body');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientDoWithRequestHelperStringBodyWithoutHeaders;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LReq: IHttpRequest;
  LGotContentLength: Int64;
  LGotHeaderCount: Int64;
  LGotBody: string;
begin
  LGotContentLength := -1;
  LGotHeaderCount := -1;
  LGotBody := '';
  LRouter := THttpRouter.Create;
  LRouter.Post('/no-headers-string', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LB: string;
  begin
    LGotContentLength := AReq.ContentLength;
    LGotHeaderCount := AReq.Headers.Count;
    LGotBody := ReadReaderStr(AReq.Body);
    LB := 'ok';
    AW.GetHeaders.Set_('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LReq := nextpas.core.http.NewRequest(hmPost,
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/no-headers-string',
      'payload');

    LResp := LClient.Do_(LReq);

    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    CheckEqual(Int64(7), LGotContentLength, 'content-length forwarded');
    CheckEqual('payload', LGotBody, 'body forwarded');
    Check(LGotHeaderCount >= 1,
      'request helper without headers still publishes content-length header');
    CheckEqual('ok', ReadBodyStr(LResp), 'response body');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientDoWithRequestHelperBytesBodyWithoutHeaders;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LReq: IHttpRequest;
  LBody: TBytes;
  LGotContentLength: Int64;
  LGotHeaderCount: Int64;
  LGotBody: string;
begin
  LGotContentLength := -1;
  LGotHeaderCount := -1;
  LGotBody := '';
  LRouter := THttpRouter.Create;
  LRouter.Post('/no-headers-bytes', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LB: string;
  begin
    LGotContentLength := AReq.ContentLength;
    LGotHeaderCount := AReq.Headers.Count;
    LGotBody := ReadReaderStr(AReq.Body);
    LB := 'ok';
    AW.GetHeaders.Set_('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    SetLength(LBody, 3);
    LBody[0] := Ord('b');
    LBody[1] := 0;
    LBody[2] := 255;
    LReq := nextpas.core.http.NewRequest(hmPost,
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/no-headers-bytes',
      LBody);

    LResp := LClient.Do_(LReq);

    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    CheckEqual(Int64(3), LGotContentLength, 'content-length forwarded');
    CheckEqual('b' + #0 + #255, LGotBody, 'bytes body forwarded');
    Check(LGotHeaderCount >= 1,
      'bytes helper without headers still publishes content-length header');
    CheckEqual('ok', ReadBodyStr(LResp), 'response body');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientDoWithRequestHelperStringBodyAndContentTypeWithoutHeaders;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LReq: IHttpRequest;
  LGotContentType: string;
  LGotContentLength: Int64;
  LGotHeaderCount: Int64;
  LGotBody: string;
begin
  LGotContentType := '';
  LGotContentLength := -1;
  LGotHeaderCount := -1;
  LGotBody := '';
  LRouter := THttpRouter.Create;
  LRouter.Post('/content-type-string', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LB: string;
  begin
    LGotContentType := AReq.Headers.Get('content-type');
    LGotContentLength := AReq.ContentLength;
    LGotHeaderCount := AReq.Headers.Count;
    LGotBody := ReadReaderStr(AReq.Body);
    LB := 'ok';
    AW.GetHeaders.Set_('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LReq := nextpas.core.http.NewRequest(hmPost,
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/content-type-string',
      'text/plain; charset=utf-8', 'payload');

    LResp := LClient.Do_(LReq);

    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    CheckEqual('text/plain; charset=utf-8', LGotContentType,
      'content-type forwarded');
    CheckEqual(Int64(7), LGotContentLength, 'content-length forwarded');
    CheckEqual('payload', LGotBody, 'body forwarded');
    Check(LGotHeaderCount >= 2,
      'string helper publishes content-length and content-type headers');
    CheckEqual('ok', ReadBodyStr(LResp), 'response body');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientDoWithRequestHelperBytesBodyAndContentTypeWithoutHeaders;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LReq: IHttpRequest;
  LBody: TBytes;
  LGotContentType: string;
  LGotContentLength: Int64;
  LGotHeaderCount: Int64;
  LGotBody: string;
begin
  LGotContentType := '';
  LGotContentLength := -1;
  LGotHeaderCount := -1;
  LGotBody := '';
  LRouter := THttpRouter.Create;
  LRouter.Post('/content-type-bytes', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LB: string;
  begin
    LGotContentType := AReq.Headers.Get('content-type');
    LGotContentLength := AReq.ContentLength;
    LGotHeaderCount := AReq.Headers.Count;
    LGotBody := ReadReaderStr(AReq.Body);
    LB := 'ok';
    AW.GetHeaders.Set_('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    SetLength(LBody, 3);
    LBody[0] := Ord('b');
    LBody[1] := 0;
    LBody[2] := 255;
    LReq := nextpas.core.http.NewRequest(hmPost,
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/content-type-bytes',
      'application/octet-stream', LBody);

    LResp := LClient.Do_(LReq);

    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    CheckEqual('application/octet-stream', LGotContentType,
      'content-type forwarded');
    CheckEqual(Int64(3), LGotContentLength, 'content-length forwarded');
    CheckEqual('b' + #0 + #255, LGotBody, 'bytes body forwarded');
    Check(LGotHeaderCount >= 2,
      'bytes helper publishes content-length and content-type headers');
    CheckEqual('ok', ReadBodyStr(LResp), 'response body');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientShortcutBodyImplementationUsesBytesBuffer;
var
  LSource: string;
begin
  LSource := ReadFileText('../../../src/nextpas.core.http.client.pas');
  Check(Pos('function BufferedBodyRequest(', LSource) > 0,
    'client shortcut body path uses one bytes-buffer request helper');
  Check(Pos('LBodyBuf: string;', LSource) = 0,
    'client shortcut body path does not materialize body through string');
  Check(Pos('CreateBytesStreamFrom(StrToBytes(LBodyBuf))', LSource) = 0,
    'client shortcut body path does not convert string buffer back to bytes');
end;

procedure TestClientPostStringBodyOverload;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LGotContentType: string;
  LGotContentLength: Int64;
  LGotBody: string;
begin
  LGotContentType := '';
  LGotContentLength := -1;
  LGotBody := '';
  LRouter := THttpRouter.Create;
  LRouter.Post('/submit', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LB: string;
  begin
    LGotContentType := AReq.Headers.Get('content-type');
    LGotContentLength := AReq.ContentLength;
    LGotBody := ReadReaderStr(AReq.Body);
    LB := 'accepted';
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LB))));
    AW.WriteHeader(HTTP_STATUS_CREATED);
    AW.Write(LB[1], SizeUInt(Length(LB)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Post(
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/submit',
      'application/x-www-form-urlencoded',
      'key=value');
    CheckEqual(Int64(201), Int64(LResp.StatusCode), 'status 201');
    CheckEqual('application/x-www-form-urlencoded', LGotContentType,
      'content-type forwarded');
    CheckEqual(Int64(9), LGotContentLength, 'content-length forwarded');
    CheckEqual('key=value', LGotBody, 'body forwarded');
    CheckEqual('accepted', ReadBodyStr(LResp), 'response body');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientPatchBytesBodyOverload;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LBody: TBytes;
  LGotContentType: string;
  LGotContentLength: Int64;
  LGotBody: string;
begin
  LGotContentType := '';
  LGotContentLength := -1;
  LGotBody := '';
  LRouter := THttpRouter.Create;
  LRouter.Handle(hmPatch, '/resource', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LB: string;
  begin
    LGotContentType := AReq.Headers.Get('content-type');
    LGotContentLength := AReq.ContentLength;
    LGotBody := ReadReaderStr(AReq.Body);
    LB := 'patched';
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LB))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], SizeUInt(Length(LB)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    SetLength(LBody, 4);
    LBody[0] := Ord('b');
    LBody[1] := Ord('i');
    LBody[2] := 0;
    LBody[3] := 255;
    LResp := LClient.Patch(
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/resource',
      'application/octet-stream',
      LBody);
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    CheckEqual('application/octet-stream', LGotContentType,
      'content-type forwarded');
    CheckEqual(Int64(4), LGotContentLength, 'content-length forwarded');
    CheckEqual('bi' + #0 + #255, LGotBody, 'bytes body forwarded');
    CheckEqual('patched', ReadBodyStr(LResp), 'response body');
  finally
    StopServer(LServer, LHandle);
  end;
end;

// PLACEHOLDER_TEST4

procedure TestClientPutBodyAndContentType;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LGotMethod: THttpMethod;
  LGotContentType: string;
  LGotContentLength: Int64;
  LGotBody: string;
begin
  LGotMethod := hmGet;
  LGotContentType := '';
  LGotContentLength := -1;
  LGotBody := '';
  LRouter := THttpRouter.Create;
  LRouter.Put('/resource', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LB: string;
  begin
    LGotMethod := AReq.Method;
    LGotContentType := AReq.Headers.Get('content-type');
    LGotContentLength := AReq.ContentLength;
    LGotBody := ReadReaderStr(AReq.Body);
    LB := 'put-ok';
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LB))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], SizeUInt(Length(LB)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Put(
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/resource',
      'application/json',
      StringBodyReader('{"name":"next"}'));
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    Check(LGotMethod = hmPut, 'server received PUT');
    CheckEqual('application/json', LGotContentType, 'content-type forwarded');
    CheckEqual(Int64(15), LGotContentLength, 'content-length forwarded');
    CheckEqual('{"name":"next"}', LGotBody, 'body forwarded');
    CheckEqual('put-ok', ReadBodyStr(LResp), 'response body');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientDeleteNoBody;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LGotMethod: THttpMethod;
  LGotContentLength: Int64;
  LGotBody: string;
begin
  LGotMethod := hmGet;
  LGotContentLength := -1;
  LGotBody := 'not-read';
  LRouter := THttpRouter.Create;
  LRouter.Delete('/resource', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LB: string;
  begin
    LGotMethod := AReq.Method;
    LGotContentLength := AReq.ContentLength;
    LGotBody := ReadReaderStr(AReq.Body);
    LB := 'deleted';
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LB))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], SizeUInt(Length(LB)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Delete('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/resource');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    Check(LGotMethod = hmDelete, 'server received DELETE');
    CheckEqual(Int64(0), LGotContentLength, 'delete content-length is zero');
    CheckEqual('', LGotBody, 'delete body is empty');
    CheckEqual('deleted', ReadBodyStr(LResp), 'response body');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientPatchBodyAndContentType;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LGotMethod: THttpMethod;
  LGotContentType: string;
  LGotContentLength: Int64;
  LGotBody: string;
begin
  LGotMethod := hmGet;
  LGotContentType := '';
  LGotContentLength := -1;
  LGotBody := '';
  LRouter := THttpRouter.Create;
  LRouter.Handle(hmPatch, '/resource', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LB: string;
  begin
    LGotMethod := AReq.Method;
    LGotContentType := AReq.Headers.Get('content-type');
    LGotContentLength := AReq.ContentLength;
    LGotBody := ReadReaderStr(AReq.Body);
    LB := 'patch-ok';
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LB))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], SizeUInt(Length(LB)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Patch(
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/resource',
      'application/merge-patch+json',
      StringBodyReader('{"enabled":true}'));
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    Check(LGotMethod = hmPatch, 'server received PATCH');
    CheckEqual('application/merge-patch+json', LGotContentType, 'content-type forwarded');
    CheckEqual(Int64(16), LGotContentLength, 'content-length forwarded');
    CheckEqual('{"enabled":true}', LGotBody, 'body forwarded');
    CheckEqual('patch-ok', ReadBodyStr(LResp), 'response body');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientHeadSendsHead;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LGotMethod: THttpMethod;
  LBody: string;
begin
  LGotMethod := hmGet;
  LRouter := THttpRouter.Create;
  LRouter.Handle(hmHead, '/resource', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LReply: string;
  begin
    LGotMethod := AReq.Method;
    LReply := 'hello';
    AW.GetHeaders.Set_('content-length', '5');
    AW.GetHeaders.Set_('x-head-ok', 'yes');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LReply[1], SizeUInt(Length(LReply)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Head('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/resource');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    Check(LGotMethod = hmHead, 'server received HEAD');
    CheckEqual('yes', LResp.Headers.Get('x-head-ok'), 'response headers are available');
    CheckEqual('5', LResp.Headers.Get('content-length'),
      'head response preserves content-length header');
    LBody := ReadBodyStr(LResp);
    CheckEqual('', LBody, 'head response body is empty');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientReadsChunkedResponse;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/chunked', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LPart1, LPart2: string;
  begin
    LPart1 := 'hello';
    LPart2 := ' world';
    AW.Write(LPart1[1], SizeUInt(Length(LPart1)));
    AW.Write(LPart2[1], SizeUInt(Length(LPart2)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/chunked');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    CheckEqual('chunked', LResp.Headers.Get('transfer-encoding'), 'chunked response header preserved');
    CheckEqual('hello world', ReadBodyStr(LResp), 'chunked response body decoded');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientReadsCloseDelimitedResponse;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  GRawResponse1 := 'HTTP/1.1 200 OK'#13#10 +
                   'Content-Type: text/plain'#13#10 +
                   #13#10 +
                   'close-body';
  GRawResponse2 := '';
  GRawAcceptLimit := 1;
  GRawListener := NetTcpListen('127.0.0.1', 0);
  LPort := GRawListener.LocalAddr.Port;
  platform_thread_create(LHandle, @RawResponseThread, nil);

  try
    LClient := NewHttpClient;
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/close-delimited');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    CheckEqual('close-body', ReadBodyStr(LResp), 'close-delimited body decoded');
  finally
    GRawListener.Close;
    platform_thread_join(LHandle, LRet);
    GRawListener := nil;
    GRawResponse1 := '';
    GRawResponse2 := '';
    GRawAcceptLimit := 0;
  end;
end;

procedure TestClientRejectsTruncatedContentLengthResponse;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LRaised: Boolean;
begin
  GRawResponse1 := 'HTTP/1.1 200 OK'#13#10 +
                   'Content-Length: 10'#13#10 +
                   'Content-Type: text/plain'#13#10 +
                   #13#10 +
                   'hello';
  GRawResponse2 := '';
  GRawAcceptLimit := 1;
  GRawListener := NetTcpListen('127.0.0.1', 0);
  LPort := GRawListener.LocalAddr.Port;
  platform_thread_create(LHandle, @RawResponseThread, nil);

  try
    LClient := NewHttpClient;
    LRaised := False;
    try
      LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/truncated');
    except
      on E: EHttpError do
        LRaised := True;
    end;
    Check(LRaised, 'truncated content-length response raises EHttpError');
  finally
    GRawListener.Close;
    platform_thread_join(LHandle, LRet);
    GRawListener := nil;
    GRawResponse1 := '';
    GRawResponse2 := '';
    GRawAcceptLimit := 0;
  end;
end;

procedure TestHttpGetToWriterCopiesResponseBody;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LBuffer: IStream;
  LCount: Int64;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/download', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LBody := 'toolchain';
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LBuffer := CreateBytesStreamFrom(nil);
    LCount := nextpas.core.http.HttpGetToWriter(
      LClient,
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/download',
      LBuffer as IWriter);
    CheckEqual(Int64(9), LCount, 'copied byte count');
    LBuffer.Position := 0;
    CheckEqual('toolchain', ReadReaderStr(LBuffer as IReader), 'writer receives response body');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHttpGetToWriterClosesBodyAfterSuccessfulCopy;
var
  LHeaders: IHttpHeaders;
  LBody: TRedirectTrackedBody;
  LBodyRef: IReadCloser;
  LClient: IHttpClient;
  LBuffer: IStream;
  LCount: Int64;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.Set_('content-length', '9');
  LBody := TRedirectTrackedBody.Create('toolchain');
  LBodyRef := LBody as IReadCloser;
  LClient := TDownloadClient.Create(NewResponse(HTTP_STATUS_OK, LHeaders,
    LBodyRef as IReader)) as IHttpClient;
  LBuffer := CreateBytesStreamFrom(nil);

  LCount := HttpGetToWriter(LClient, 'http://example.test/tool',
    LBuffer as IWriter);

  CheckEqual(Int64(9), LCount, 'download helper copied byte count');
  Check(LBody.Closed, 'download helper closes response body after copy');
end;

procedure TestHttpGetToWriterClosesBodyWhenCopyFails;
var
  LHeaders: IHttpHeaders;
  LBody: TRedirectTrackedBody;
  LBodyRef: IReadCloser;
  LClient: IHttpClient;
  LRaised: Boolean;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.Set_('content-length', '9');
  LBody := TRedirectTrackedBody.Create('toolchain');
  LBodyRef := LBody as IReadCloser;
  LClient := TDownloadClient.Create(NewResponse(HTTP_STATUS_OK, LHeaders,
    LBodyRef as IReader)) as IHttpClient;

  LRaised := False;
  try
    HttpGetToWriter(LClient, 'http://example.test/tool',
      TZeroProgressWriter.Create as IWriter);
  except
    on E: EIOError do
      LRaised := True;
  end;

  Check(LRaised, 'download helper propagates writer failure');
  Check(LBody.Closed, 'download helper closes response body when copy fails');
end;

procedure TestHttpGetToWriterClosesNon2xxBodyBeforeRaising;
var
  LHeaders: IHttpHeaders;
  LBody: TRedirectTrackedBody;
  LBodyRef: IReadCloser;
  LClient: IHttpClient;
  LRaised: Boolean;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.Set_('content-length', '9');
  LBody := TRedirectTrackedBody.Create('not-found');
  LBodyRef := LBody as IReadCloser;
  LClient := TDownloadClient.Create(NewResponse(HTTP_STATUS_NOT_FOUND, LHeaders,
    LBodyRef as IReader)) as IHttpClient;

  LRaised := False;
  try
    HttpGetToWriter(LClient, 'http://example.test/missing',
      CreateBytesStreamFrom(nil) as IWriter);
  except
    on E: EHttpError do
      LRaised := True;
  end;

  Check(LRaised, 'download helper rejects non-2xx response');
  Check(LBody.Closed, 'download helper closes non-2xx response body before raising');
end;

procedure TestHttpReadResponseBodyStringReadsLiveResponse;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LBody: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/body-text', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LResponseBody: string;
  begin
    LResponseBody := 'response text';
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LResponseBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LResponseBody[1], SizeUInt(Length(LResponseBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/body-text');
    LBody := nextpas.core.http.client.HttpReadResponseBodyString(LResp);
    CheckEqual('response text', LBody, 'response body helper reads full body');
    CheckEqual('', ReadBodyStr(LResp), 'response body helper consumes the reader');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHttpReadResponseBodyStringNilBodyReturnsEmpty;
var
  LResp: IHttpResponse;
begin
  LResp := NewResponse(HTTP_STATUS_NO_CONTENT, NewHttpHeaders, nil);
  CheckEqual('', nextpas.core.http.client.HttpReadResponseBodyString(LResp),
    'response body helper treats nil body as empty');
end;

procedure TestHttpReadResponseBodyStringRejectsNilResponse;
var
  LResp: IHttpResponse;
  LRaised: Boolean;
begin
  LResp := nil;
  LRaised := False;
  try
    nextpas.core.http.client.HttpReadResponseBodyString(LResp);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'response body helper rejects nil response');
end;

procedure TestHttpReadResponseBodyBytesReadsLiveResponse;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LBody: TBytes;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/body-bytes', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LResponseBody: string;
  begin
    LResponseBody := 'bin' + #0 + #255 + 'ary';
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LResponseBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LResponseBody[1], SizeUInt(Length(LResponseBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/body-bytes');
    LBody := nextpas.core.http.client.HttpReadResponseBodyBytes(LResp);
    CheckEqual('bin' + #0 + #255 + 'ary', BytesToTestString(LBody),
      'response body bytes helper preserves binary body bytes');
    CheckEqual('', ReadBodyStr(LResp), 'response body bytes helper consumes the reader');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHttpReadResponseBodyBytesNilBodyReturnsEmpty;
var
  LResp: IHttpResponse;
  LBody: TBytes;
begin
  LResp := NewResponse(HTTP_STATUS_NO_CONTENT, NewHttpHeaders, nil);
  LBody := nextpas.core.http.client.HttpReadResponseBodyBytes(LResp);
  CheckEqual(Int64(0), Int64(Length(LBody)),
    'response body bytes helper treats nil body as empty bytes');
end;

procedure TestHttpReadResponseBodyBytesRejectsNilResponse;
var
  LResp: IHttpResponse;
  LRaised: Boolean;
begin
  LResp := nil;
  LRaised := False;
  try
    nextpas.core.http.client.HttpReadResponseBodyBytes(LResp);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'response body bytes helper rejects nil response');
end;

procedure TestHttpReleaseResponseBodyClosesCloseCapableBody;
var
  LHeaders: IHttpHeaders;
  LBody: TRedirectTrackedBody;
  LBodyRef: IReadCloser;
  LResp: IHttpResponse;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.Set_('content-length', '7');
  LBody := TRedirectTrackedBody.Create('discard');
  LBodyRef := LBody as IReadCloser;
  LResp := NewResponse(HTTP_STATUS_OK, LHeaders, LBodyRef as IReader);

  HttpReleaseResponseBody(LResp);

  Check(LBody.Closed,
    'release helper closes close-capable response body');
end;

procedure TestHttpReleaseResponseBodyDrainsPlainReader;
var
  LHeaders: IHttpHeaders;
  LBody: TRedirectDrainingBody;
  LBodyRef: IReader;
  LResp: IHttpResponse;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.Set_('content-length', '7');
  LBody := TRedirectDrainingBody.Create('discard');
  LBodyRef := LBody as IReader;
  LResp := NewResponse(HTTP_STATUS_OK, LHeaders, LBodyRef);

  HttpReleaseResponseBody(LResp);

  Check(LBody.Drained,
    'release helper drains non-closeable response body');
end;

procedure TestHttpReleaseResponseBodyNilBodyNoop;
var
  LResp: IHttpResponse;
begin
  LResp := NewResponse(HTTP_STATUS_NO_CONTENT, NewHttpHeaders, nil);
  HttpReleaseResponseBody(LResp);
  Check(LResp.Body = nil, 'release helper accepts nil body');
end;

procedure TestHttpReleaseResponseBodyRejectsNilResponse;
var
  LResp: IHttpResponse;
  LRaised: Boolean;
begin
  LResp := nil;
  LRaised := False;
  try
    HttpReleaseResponseBody(LResp);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'release helper rejects nil response');
end;

procedure TestHttpGetToFileWritesFinalPathAtomically;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LDestPath: string;
  LCount: Int64;
begin
  ResetDownloadTempRoot;
  LDestPath := PathJoin([DownloadTempRoot, 'artifacts', 'bootstrap.txt']);
  LRouter := THttpRouter.Create;
  LRouter.Get('/bootstrap', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LBody := 'bootstrap-bits';
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LCount := HttpGetToFile(
      LClient,
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/bootstrap',
      LDestPath);
    CheckEqual(Int64(14), LCount, 'file byte count');
    Check(Exists(LDestPath), 'final file exists');
    CheckEqual('bootstrap-bits', ReadFileText(LDestPath), 'final file content');
  finally
    StopServer(LServer, LHandle);
    RemoveAll(DownloadTempRoot);
  end;
end;

procedure TestHttpGetToFileRejects404Responses;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LDestPath: string;
  LRaised: Boolean;
begin
  ResetDownloadTempRoot;
  LDestPath := PathJoin([DownloadTempRoot, 'missing', 'tool.txt']);
  LRouter := THttpRouter.Create;
  LRouter.Get('/missing', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LBody: string;
  begin
    LBody := 'not-found';
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    AW.WriteHeader(HTTP_STATUS_NOT_FOUND);
    AW.Write(LBody[1], SizeUInt(Length(LBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LRaised := False;
    try
      HttpGetToFile(
        LClient,
        'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/missing',
        LDestPath);
    except
      on E: EHttpError do
        LRaised := True;
    end;
    Check(LRaised, '404 download raises EHttpError');
    Check(not Exists(LDestPath), '404 download does not create final file');
  finally
    StopServer(LServer, LHandle);
    RemoveAll(DownloadTempRoot);
  end;
end;

procedure TestHttpGetToFileCleansTempFilesOnTruncatedBody;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LDestPath: string;
  LDestDir: string;
  LRaised: Boolean;
begin
  ResetDownloadTempRoot;
  LDestDir := PathJoin([DownloadTempRoot, 'partial']);
  LDestPath := PathJoin([LDestDir, 'tool.txt']);
  GRawResponse1 := 'HTTP/1.1 200 OK'#13#10 +
                   'Content-Length: 10'#13#10 +
                   'Content-Type: text/plain'#13#10 +
                   #13#10 +
                   'hello';
  GRawResponse2 := '';
  GRawAcceptLimit := 1;
  GRawListener := NetTcpListen('127.0.0.1', 0);
  LPort := GRawListener.LocalAddr.Port;
  platform_thread_create(LHandle, @RawResponseThread, nil);

  try
    LClient := NewHttpClient;
    LRaised := False;
    try
      HttpGetToFile(
        LClient,
        'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/truncated-download',
        LDestPath);
    except
      on E: EHttpError do
        LRaised := True;
    end;
    Check(LRaised, 'truncated download raises EHttpError');
    Check(not Exists(LDestPath), 'truncated download does not leave final file');
    if IsDir(LDestDir) then
      CheckEqual(Int64(0), Int64(Length(ReadDir(LDestDir))), 'truncated download cleans temp files');
  finally
    GRawListener.Close;
    platform_thread_join(LHandle, LRet);
    GRawListener := nil;
    GRawResponse1 := '';
    GRawResponse2 := '';
    GRawAcceptLimit := 0;
    RemoveAll(DownloadTempRoot);
  end;
end;

{ Test 4: Client follows redirect (301 -> 200) }
procedure TestClientFollowsRedirect;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LBody: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/old', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AW.GetHeaders.Set_('location', '/new');
    AW.GetHeaders.Set_('content-length', '0');
    AW.WriteHeader(THttpStatus(301));
  end);
  LRouter.Get('/new', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LB: string;
  begin
    LB := 'arrived';
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LB))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], SizeUInt(Length(LB)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/old');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'followed redirect to 200');
    LBody := ReadBodyStr(LResp);
    CheckEqual('arrived', LBody, 'body from final destination');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientFollowsSeeOtherAsGet;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LGotFinalMethod: THttpMethod;
  LGotFinalBody: string;
begin
  LGotFinalMethod := hmTrace;
  LGotFinalBody := 'not-hit';
  LRouter := THttpRouter.Create;
  LRouter.Post('/submit', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AW.GetHeaders.Set_('location', '/complete');
    AW.GetHeaders.Set_('content-length', '0');
    AW.WriteHeader(HTTP_STATUS_SEE_OTHER);
  end);
  LRouter.Get('/complete', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LB: string;
  begin
    LGotFinalMethod := AReq.Method;
    LGotFinalBody := ReadReaderStr(AReq.Body);
    LB := 'done';
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LB))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], SizeUInt(Length(LB)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Post('http://127.0.0.1:' + IntToStr(Int64(LPort)) +
      '/submit', 'text/plain', StringBodyReader('payload') as IReader);
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      '303 redirect followed to final response');
    Check(LGotFinalMethod = hmGet, '303 redirect changes POST to GET');
    CheckEqual('', LGotFinalBody, '303 redirect drops original request body');
    CheckEqual('done', ReadBodyStr(LResp), '303 final response body');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientPreservesRelativeRedirectQuery;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LGotPath: string;
  LGotRawQuery: string;
  LGotQueryParam: string;
begin
  LGotPath := 'not-hit';
  LGotRawQuery := 'not-hit';
  LGotQueryParam := 'not-hit';
  LRouter := THttpRouter.Create;
  LRouter.Get('/old', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AW.GetHeaders.Set_('location', '/new?from=redirect');
    AW.GetHeaders.Set_('content-length', '0');
    AW.WriteHeader(HTTP_STATUS_FOUND);
  end);
  LRouter.Get('/new', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LB: string;
  begin
    LGotPath := AReq.Path;
    LGotRawQuery := AReq.RawQuery;
    LGotQueryParam := AReq.QueryParam('from');
    LB := 'arrived';
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LB))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], SizeUInt(Length(LB)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/old');
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'relative redirect with query reaches final route');
    CheckEqual('/new', LGotPath, 'relative redirect preserves path without query');
    CheckEqual('from=redirect', LGotRawQuery, 'relative redirect preserves raw query');
    CheckEqual('redirect', LGotQueryParam, 'relative redirect query param is visible');
    CheckEqual('arrived', ReadBodyStr(LResp), 'relative redirect final body');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientRedirectTransportSeesParsedRelativeQuery;
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LResp := LClient.Get('http://example.test/old');
  CheckEqual(Int64(2), Int64(LTransportObj.Calls), 'redirect performs second round trip');
  CheckEqual(Int64(200), Int64(LResp.StatusCode), 'redirect transport final status');
  CheckEqual('/new', LTransportObj.SeenPath,
    'redirect follow-up request path excludes query');
  CheckEqual('from=redirect', LTransportObj.SeenRawQuery,
    'redirect follow-up request raw query is parsed');
  CheckEqual('redirect', LTransportObj.SeenQueryParam,
    'redirect follow-up request query param is visible');
  CheckEqual('arrived', ReadBodyStr(LResp), 'redirect transport final body');
end;

procedure TestClientRedirectTransportResolvesNetworkPathLocation;
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransportObj.RedirectLocation := '//redirect.test/new?from=network';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LResp := LClient.Get('http://example.test/old');
  CheckEqual(Int64(2), Int64(LTransportObj.Calls),
    'network-path redirect performs second round trip');
  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'network-path redirect transport final status');
  CheckEqual('http', LTransportObj.SeenScheme,
    'network-path redirect preserves original scheme');
  CheckEqual('redirect.test', LTransportObj.SeenHost,
    'network-path redirect updates host');
  CheckEqual('/new', LTransportObj.SeenPath,
    'network-path redirect path excludes authority and query');
  CheckEqual('from=network', LTransportObj.SeenRawQuery,
    'network-path redirect raw query is parsed');
  CheckEqual('network', LTransportObj.SeenQueryParam,
    'network-path redirect query param is visible');
  CheckEqual('arrived', ReadBodyStr(LResp), 'network-path redirect final body');
end;

procedure TestClientRedirectTransportResolvesUppercaseAbsoluteLocation;
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransportObj.RedirectLocation := 'HTTP://redirect.test/new?from=upper';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LResp := LClient.Get('http://example.test/old');
  CheckEqual(Int64(2), Int64(LTransportObj.Calls),
    'uppercase absolute redirect performs second round trip');
  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'uppercase absolute redirect transport final status');
  CheckEqual('http', LTransportObj.SeenScheme,
    'uppercase absolute redirect normalizes scheme');
  CheckEqual('redirect.test', LTransportObj.SeenHost,
    'uppercase absolute redirect updates host');
  CheckEqual('/new', LTransportObj.SeenPath,
    'uppercase absolute redirect updates path');
  CheckEqual('from=upper', LTransportObj.SeenRawQuery,
    'uppercase absolute redirect raw query is parsed');
  CheckEqual('upper', LTransportObj.SeenQueryParam,
    'uppercase absolute redirect query param is visible');
  CheckEqual('arrived', ReadBodyStr(LResp),
    'uppercase absolute redirect final body');
end;

procedure TestClientRedirectRejectsUnsupportedAbsoluteScheme;
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LRaised: Boolean;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransportObj.RedirectLocation := 'ftp://redirect.test/new';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LRaised := False;
  try
    LClient.Get('http://example.test/old');
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, 'absolute redirect with unsupported scheme raises EHttpError');
  CheckEqual(Int64(1), Int64(LTransportObj.Calls),
    'unsupported redirect scheme does not perform second round trip');
end;

procedure TestClientRedirectTransportResolvesPathRelativeLocation;
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransportObj.RedirectLocation := 'next?from=relative-path';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LResp := LClient.Get('http://example.test/dir/old');
  CheckEqual(Int64(2), Int64(LTransportObj.Calls),
    'path-relative redirect performs second round trip');
  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'path-relative redirect transport final status');
  CheckEqual('http', LTransportObj.SeenScheme,
    'path-relative redirect preserves original scheme');
  CheckEqual('example.test', LTransportObj.SeenHost,
    'path-relative redirect preserves host');
  CheckEqual('/dir/next', LTransportObj.SeenPath,
    'path-relative redirect merges with base directory');
  CheckEqual('from=relative-path', LTransportObj.SeenRawQuery,
    'path-relative redirect raw query is parsed');
  CheckEqual('relative-path', LTransportObj.SeenQueryParam,
    'path-relative redirect query param is visible');
  CheckEqual('arrived', ReadBodyStr(LResp), 'path-relative redirect final body');
end;

procedure TestClientRedirectTransportNormalizesDotSegmentLocation;
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransportObj.RedirectLocation := '../next?from=dot';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LResp := LClient.Get('http://example.test/dir/sub/old');
  CheckEqual(Int64(2), Int64(LTransportObj.Calls),
    'dot-segment redirect performs second round trip');
  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'dot-segment redirect transport final status');
  CheckEqual('http', LTransportObj.SeenScheme,
    'dot-segment redirect preserves original scheme');
  CheckEqual('example.test', LTransportObj.SeenHost,
    'dot-segment redirect preserves host');
  CheckEqual('/dir/next', LTransportObj.SeenPath,
    'dot-segment redirect normalizes merged path');
  CheckEqual('from=dot', LTransportObj.SeenRawQuery,
    'dot-segment redirect raw query is parsed');
  CheckEqual('dot', LTransportObj.SeenQueryParam,
    'dot-segment redirect query param is visible');
  CheckEqual('arrived', ReadBodyStr(LResp), 'dot-segment redirect final body');
end;

procedure TestClientRedirectTransportPreservesQueryOnFragmentOnlyLocation;
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransportObj.RedirectLocation := '#section';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LResp := LClient.Get('http://example.test/dir/old?from=base');
  CheckEqual(Int64(2), Int64(LTransportObj.Calls),
    'fragment-only redirect performs second round trip');
  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'fragment-only redirect transport final status');
  CheckEqual('http', LTransportObj.SeenScheme,
    'fragment-only redirect preserves original scheme');
  CheckEqual('example.test', LTransportObj.SeenHost,
    'fragment-only redirect preserves host');
  CheckEqual('/dir/old', LTransportObj.SeenPath,
    'fragment-only redirect preserves original path');
  CheckEqual('from=base', LTransportObj.SeenRawQuery,
    'fragment-only redirect preserves original raw query');
  CheckEqual('base', LTransportObj.SeenQueryParam,
    'fragment-only redirect keeps original query param visible');
  CheckEqual('section', LTransportObj.SeenFragment,
    'fragment-only redirect updates fragment');
  CheckEqual('arrived', ReadBodyStr(LResp), 'fragment-only redirect final body');
end;

procedure TestClientRedirectPreservesHeadersOnSameAuthority;
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LReq: IHttpRequest;
  LHeaders: IHttpHeaders;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransportObj.RedirectLocation := '/next';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LHeaders := NewHeaders;
  LHeaders.Set_('x-trace', 'trace-1');
  LHeaders.Set_('authorization', 'Bearer same-host');
  LHeaders.Set_('www-authenticate', 'Basic realm="api"');
  LHeaders.Set_('cookie', 'session=abc');
  LHeaders.Set_('cookie2', 'legacy=1');
  LReq := NewRequest(hmGet, 'http://example.test/old', LHeaders, nil, 0);
  LResp := LClient.Do_(LReq);
  CheckEqual(Int64(2), Int64(LTransportObj.Calls),
    'same-authority redirect performs second round trip');
  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'same-authority redirect transport final status');
  CheckEqual('trace-1', LTransportObj.SeenTraceHeader,
    'same-authority redirect preserves ordinary header');
  CheckEqual('Bearer same-host', LTransportObj.SeenAuthorizationHeader,
    'same-authority redirect preserves authorization header');
  CheckEqual('Basic realm="api"', LTransportObj.SeenWwwAuthenticateHeader,
    'same-authority redirect preserves www-authenticate header');
  CheckEqual('session=abc', LTransportObj.SeenCookieHeader,
    'same-authority redirect preserves cookie header');
  CheckEqual('legacy=1', LTransportObj.SeenCookie2Header,
    'same-authority redirect preserves cookie2 header');
  CheckEqual('arrived', ReadBodyStr(LResp), 'same-authority redirect final body');
end;

procedure TestClientRedirectStripsSensitiveHeadersAcrossAuthority;
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LReq: IHttpRequest;
  LHeaders: IHttpHeaders;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransportObj.RedirectLocation := '//redirect.test/next';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LHeaders := NewHeaders;
  LHeaders.Set_('x-trace', 'trace-2');
  LHeaders.Set_('authorization', 'Bearer cross-host');
  LHeaders.Set_('www-authenticate', 'Basic realm="api"');
  LHeaders.Set_('cookie', 'session=def');
  LHeaders.Set_('cookie2', 'legacy=2');
  LReq := NewRequest(hmGet, 'http://example.test/old', LHeaders, nil, 0);
  LResp := LClient.Do_(LReq);
  CheckEqual(Int64(2), Int64(LTransportObj.Calls),
    'cross-authority redirect performs second round trip');
  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'cross-authority redirect transport final status');
  CheckEqual('redirect.test', LTransportObj.SeenHost,
    'cross-authority redirect updates host');
  CheckEqual('trace-2', LTransportObj.SeenTraceHeader,
    'cross-authority redirect preserves ordinary header');
  CheckEqual('', LTransportObj.SeenAuthorizationHeader,
    'cross-authority redirect strips authorization header');
  CheckEqual('', LTransportObj.SeenWwwAuthenticateHeader,
    'cross-authority redirect strips www-authenticate header');
  CheckEqual('', LTransportObj.SeenCookieHeader,
    'cross-authority redirect strips cookie header');
  CheckEqual('', LTransportObj.SeenCookie2Header,
    'cross-authority redirect strips cookie2 header');
  CheckEqual('arrived', ReadBodyStr(LResp), 'cross-authority redirect final body');
end;

procedure TestClientRedirectPreservesCustomHostHeaderOnRelativeLocation;
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LReq: IHttpRequest;
  LHeaders: IHttpHeaders;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransportObj.RedirectLocation := '/next';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LHeaders := NewHeaders;
  LHeaders.Set_('host', 'override.test');
  LReq := NewRequest(hmGet, 'http://example.test/old', LHeaders, nil, 0);
  LResp := LClient.Do_(LReq);
  CheckEqual(Int64(2), Int64(LTransportObj.Calls),
    'relative redirect with custom host performs second round trip');
  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'relative redirect with custom host final status');
  CheckEqual('override.test', LTransportObj.SeenHostHeader,
    'relative redirect preserves caller host override');
  CheckEqual('/next', LTransportObj.SeenPath,
    'relative redirect still follows target path');
  CheckEqual('arrived', ReadBodyStr(LResp),
    'relative redirect with custom host final body');
end;

procedure TestClientRedirectPreservesCustomHostHeaderOnDefaultPortAuthority;
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LReq: IHttpRequest;
  LHeaders: IHttpHeaders;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransportObj.RedirectLocation := 'http://example.test:80/next';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LHeaders := NewHeaders;
  LHeaders.Set_('host', 'override.test');
  LReq := NewRequest(hmGet, 'http://example.test/old', LHeaders, nil, 0);
  LResp := LClient.Do_(LReq);
  CheckEqual(Int64(2), Int64(LTransportObj.Calls),
    'default-port redirect performs second round trip');
  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'default-port redirect final status');
  CheckEqual('override.test', LTransportObj.SeenHostHeader,
    'default-port redirect preserves caller host override');
  CheckEqual('example.test', LTransportObj.SeenHost,
    'default-port redirect keeps same URL host');
  CheckEqual('/next', LTransportObj.SeenPath,
    'default-port redirect follows target path');
  CheckEqual('arrived', ReadBodyStr(LResp),
    'default-port redirect final body');
end;

procedure TestClientClosesRedirectResponseBodyBeforeFollowup;
var
  LTransportObj: TRedirectBodyReleaseTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransportObj := TRedirectBodyReleaseTransport.Create;
  LTransport := LTransportObj as IHttpTransport;
  LClient := NewHttpClient(LTransport);

  LResp := LClient.Get('http://example.test/old');

  CheckEqual(Int64(2), Int64(LTransportObj.Calls),
    'redirect with body performs second round trip');
  Check(LTransportObj.BodyClosedBeforeFollowup,
    'redirect response body is closed before follow-up round trip');
  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'redirect body release final status');
  CheckEqual('arrived', ReadBodyStr(LResp),
    'redirect body release final body');
end;

procedure TestClientDrainsRedirectResponseBodyBeforeFollowup;
var
  LTransportObj: TRedirectBodyDrainTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransportObj := TRedirectBodyDrainTransport.Create;
  LTransport := LTransportObj as IHttpTransport;
  LClient := NewHttpClient(LTransport);

  LResp := LClient.Get('http://example.test/old');

  CheckEqual(Int64(2), Int64(LTransportObj.Calls),
    'redirect with non-closeable body performs second round trip');
  Check(LTransportObj.BodyDrainedBeforeFollowup,
    'non-closeable redirect response body is drained before follow-up round trip');
  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'redirect body drain final status');
  CheckEqual('arrived', ReadBodyStr(LResp),
    'redirect body drain final body');
end;

procedure TestClientClosesRedirectResponseBodyOnTooManyRedirects;
var
  LTransportObj: TRedirectBodyReleaseTransport;
  LTransport: IHttpTransport;
  LOptions: THttpClientOptions;
  LClient: IHttpClient;
  LRaised: Boolean;
begin
  LTransportObj := TRedirectBodyReleaseTransport.Create;
  LTransport := LTransportObj as IHttpTransport;
  LOptions := THttpClientOptions.Default;
  LOptions.MaxRedirects := 0;
  LClient := NewHttpClient(LTransport, LOptions);

  LRaised := False;
  try
    LClient.Get('http://example.test/old');
  except
    on E: EHttpError do
      LRaised := True;
  end;

  Check(LRaised, 'too many redirects raises EHttpError');
  CheckEqual(Int64(1), Int64(LTransportObj.Calls),
    'too many redirects stops before follow-up round trip');
  Check(LTransportObj.BodyClosed,
    'too many redirects closes discarded redirect response body');
end;

procedure TestClientClosesRedirectResponseBodyOnMissingLocation;
var
  LTransportObj: TRedirectBodyReleaseTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LRaised: Boolean;
begin
  LTransportObj := TRedirectBodyReleaseTransport.Create;
  LTransportObj.OmitLocation := True;
  LTransport := LTransportObj as IHttpTransport;
  LClient := NewHttpClient(LTransport);

  LRaised := False;
  try
    LClient.Get('http://example.test/old');
  except
    on E: EHttpError do
      LRaised := True;
  end;

  Check(LRaised, 'missing redirect Location raises EHttpError');
  CheckEqual(Int64(1), Int64(LTransportObj.Calls),
    'missing redirect Location stops before follow-up round trip');
  Check(LTransportObj.BodyClosed,
    'missing redirect Location closes discarded redirect response body');
end;

procedure TestClientClosesRedirectResponseBodyOnUnsupportedScheme;
var
  LTransportObj: TRedirectBodyReleaseTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LRaised: Boolean;
begin
  LTransportObj := TRedirectBodyReleaseTransport.Create;
  LTransportObj.RedirectLocation := 'ftp://redirect.test/final';
  LTransport := LTransportObj as IHttpTransport;
  LClient := NewHttpClient(LTransport);

  LRaised := False;
  try
    LClient.Get('http://example.test/old');
  except
    on E: EHttpError do
      LRaised := True;
  end;

  Check(LRaised, 'unsupported redirect scheme raises EHttpError');
  CheckEqual(Int64(1), Int64(LTransportObj.Calls),
    'unsupported redirect scheme stops before follow-up round trip');
  Check(LTransportObj.BodyClosed,
    'unsupported redirect scheme closes discarded redirect response body');
end;

procedure TestClientReplaysSeekableBodyOnTemporaryRedirect;
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LReq: IHttpRequest;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransportObj.RedirectStatus := THttpStatus(307);
  LTransportObj.RedirectLocation := '/upload-copy';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LReq := NewRequest(hmPost, 'http://example.test/upload', NewHeaders,
    StringBodyReader('payload'), Int64(7));
  LResp := LClient.Do_(LReq);
  CheckEqual(Int64(2), Int64(LTransportObj.Calls),
    'temporary redirect performs second round trip');
  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'temporary redirect transport final status');
  Check(LTransportObj.SeenMethod = hmPost,
    'temporary redirect preserves original method');
  CheckEqual('payload', LTransportObj.FirstBody,
    'temporary redirect first request sends original body');
  CheckEqual('payload', LTransportObj.SecondBody,
    'temporary redirect replays seekable body on follow-up');
  CheckEqual('/upload-copy', LTransportObj.SeenPath,
    'temporary redirect follows target path');
  CheckEqual('arrived', ReadBodyStr(LResp), 'temporary redirect final body');
end;

procedure TestClientRejectsNonReplayableBodyOnTemporaryRedirect;
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LRaised: Boolean;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransportObj.RedirectStatus := THttpStatus(307);
  LTransportObj.RedirectLocation := '/upload-copy';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LReq := NewRequest(hmPost, 'http://example.test/upload', NewHeaders,
    TOneShotReader.Create('payload') as IReader, Int64(7));
  LRaised := False;
  try
    LClient.Do_(LReq);
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, 'temporary redirect rejects non-replayable request body');
  CheckEqual('payload', LTransportObj.FirstBody,
    'temporary redirect still sent original body once before rejection');
  CheckEqual(Int64(1), Int64(LTransportObj.Calls),
    'temporary redirect rejects before second round trip');
end;

procedure TestClientOptionsRejectNegativeValues;
var
  LOptions: THttpClientOptions;
  LTransport: IHttpTransport;
  LCaught: Boolean;
begin
  LOptions := THttpClientOptions.Default;
  LOptions.Timeout := -1;
  LCaught := False;
  try
    NewHttpClient(LOptions);
  except
    on E: EArgumentError do
      LCaught := True;
  end;
  Check(LCaught, 'negative client timeout raises EArgumentError');

  LOptions := THttpClientOptions.Default;
  LOptions.MaxRedirects := -1;
  LTransport := TNilResponseTransport.Create as IHttpTransport;
  LCaught := False;
  try
    NewHttpClient(LTransport, LOptions);
  except
    on E: EArgumentError do
      LCaught := True;
  end;
  Check(LCaught, 'negative client max redirects raises EArgumentError');
end;

{ Test 5: Client respects max redirects (infinite loop -> error) }
procedure TestClientMaxRedirects;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LOptions: THttpClientOptions;
  LCaught: Boolean;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/loop', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AW.GetHeaders.Set_('location', '/loop');
    AW.GetHeaders.Set_('content-length', '0');
    AW.WriteHeader(THttpStatus(302));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LOptions := THttpClientOptions.Default;
    LOptions.MaxRedirects := 3;
    LClient := NewHttpClient(LOptions);
    LCaught := False;
    try
      LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/loop');
    except
      on E: EHttpError do
        LCaught := True;
    end;
    Check(LCaught, 'too many redirects raises EHttpError');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientCloseIdleConnectionsDropsPooledConnections;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LRet: Pointer;
begin
  GAcceptCount := 0;
  GPoolListener := NetTcpListen('127.0.0.1', 0);
  LPort := GPoolListener.LocalAddr.Port;
  platform_thread_create(LHandle, @PoolAcceptThread, nil);

  try
    LClient := NewHttpClient;

    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/ping');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'first request status 200');
    CheckEqual(Int64(1), Int64(GAcceptCount),
      'first request opens first connection');

    LClient.CloseIdleConnections;

    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/ping');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'second request status 200');
    CheckEqual(Int64(2), Int64(GAcceptCount),
      'second request opens new connection after CloseIdleConnections');

    LClient := nil;
  finally
    GPoolListener.Close;
    platform_thread_join(LHandle, LRet);
    GPoolListener := nil;
  end;
end;

procedure TestClientRetriesIdempotentReplayableBodyAfterStalePooledConnection;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
  LHeaders: IHttpHeaders;
  LRet: Pointer;
begin
  GRetryAcceptCount := 0;
  GRetrySecondMethod := '';
  GRetrySecondBody := '';
  GRetryListener := NetTcpListen('127.0.0.1', 0);
  LPort := GRetryListener.LocalAddr.Port;
  platform_thread_create(LHandle, @StaleRetryThread, nil);

  try
    LClient := NewHttpClient;

    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/prime');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'priming request status 200');
    CheckEqual(Int64(1), Int64(GRetryAcceptCount), 'priming request opened first connection');

    LHeaders := NewHeaders;
    LHeaders.Set_('idempotency-key', 'retry-safe');
    LReq := NewRequest(hmPost,
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/upload',
      LHeaders, StringBodyReader('payload'), Int64(7));
    LResp := LClient.Do_(LReq);

    CheckEqual(Int64(2), Int64(GRetryAcceptCount),
      'stale pooled connection retry opened a second connection');
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'idempotent replayable retry request succeeds');
    CheckEqual('POST', GRetrySecondMethod,
      'retry preserves original method on second connection');
    CheckEqual('payload', GRetrySecondBody,
      'retry replays full request body on second connection');
    CheckEqual('retry-ok', ReadBodyStr(LResp), 'retry response body');

    LClient := nil;
  finally
    if GRetryAcceptCount < 2 then
      WakeRetryAcceptThread(LPort);
    GRetryListener.Close;
    platform_thread_join(LHandle, LRet);
    GRetryListener := nil;
  end;
end;

procedure TestClientRejectsNonIdempotentReplayableBodyAfterStalePooledConnection;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LRaised: Boolean;
  LRet: Pointer;
begin
  GRetryAcceptCount := 0;
  GRetrySecondMethod := '';
  GRetrySecondBody := '';
  GRetryListener := NetTcpListen('127.0.0.1', 0);
  LPort := GRetryListener.LocalAddr.Port;
  platform_thread_create(LHandle, @StaleRetryThread, nil);

  try
    LClient := NewHttpClient;

    CheckEqual(Int64(200), Int64(LClient.Get(
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/prime').StatusCode),
      'priming request status 200');
    CheckEqual(Int64(1), Int64(GRetryAcceptCount), 'priming request opened first connection');

    LReq := NewRequest(hmPost,
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/upload',
      NewHeaders, StringBodyReader('payload'), Int64(7));
    LRaised := False;
    try
      LClient.Do_(LReq);
    except
      on E: Exception do
        LRaised := True;
    end;

    Check(LRaised, 'non-idempotent replayable retry request raises');
    CheckEqual(Int64(1), Int64(GRetryAcceptCount),
      'non-idempotent retry does not open a second connection');
    CheckEqual('', GRetrySecondMethod,
      'non-idempotent retry does not send follow-up request');
    CheckEqual('', GRetrySecondBody,
      'non-idempotent retry does not send follow-up body');

    LClient := nil;
  finally
    if GRetryAcceptCount < 2 then
      WakeRetryAcceptThread(LPort);
    GRetryListener.Close;
    platform_thread_join(LHandle, LRet);
    GRetryListener := nil;
  end;
end;

procedure TestClientRejectsNonReplayableIdempotentBodyAfterStalePooledConnection;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LHeaders: IHttpHeaders;
  LRaised: Boolean;
  LRet: Pointer;
begin
  GRetryAcceptCount := 0;
  GRetrySecondMethod := '';
  GRetrySecondBody := '';
  GRetryListener := NetTcpListen('127.0.0.1', 0);
  LPort := GRetryListener.LocalAddr.Port;
  platform_thread_create(LHandle, @StaleRetryThread, nil);

  try
    LClient := NewHttpClient;

    CheckEqual(Int64(200), Int64(LClient.Get(
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/prime').StatusCode),
      'priming request status 200');
    CheckEqual(Int64(1), Int64(GRetryAcceptCount), 'priming request opened first connection');

    LHeaders := NewHeaders;
    LHeaders.Set_('idempotency-key', 'retry-safe');
    LReq := NewRequest(hmPost,
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/upload',
      LHeaders, TOneShotReader.Create('payload') as IReader, Int64(7));
    LRaised := False;
    try
      LClient.Do_(LReq);
    except
      on E: EHttpError do
        LRaised := True;
    end;

    Check(LRaised, 'non-replayable idempotent retry body raises EHttpError');
    CheckEqual(Int64(1), Int64(GRetryAcceptCount),
      'non-replayable idempotent retry does not open a second connection');
    CheckEqual('', GRetrySecondMethod,
      'non-replayable idempotent retry does not send follow-up request');
    CheckEqual('', GRetrySecondBody,
      'non-replayable idempotent retry does not send follow-up body');

    LClient := nil;
  finally
    if GRetryAcceptCount < 2 then
      WakeRetryAcceptThread(LPort);
    GRetryListener.Close;
    platform_thread_join(LHandle, LRet);
    GRetryListener := nil;
  end;
end;

{ Test 6: Client timeout on slow server }
procedure TestClientTimeout;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LOptions: THttpClientOptions;
  LCaught: Boolean;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/slow', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    { Sleep 2 seconds — longer than client timeout }
    platform_thread_sleep_ns(2000000000);
    AW.GetHeaders.Set_('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(PAnsiChar('ok')^, 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LOptions := THttpClientOptions.Default;
    LOptions.Timeout := 500; { 500ms timeout }
    LClient := NewHttpClient(LOptions);
    LCaught := False;
    try
      LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/slow');
    except
      LCaught := True;
    end;
    Check(LCaught, 'timeout raises exception');
  finally
    StopServer(LServer, LHandle);
    { Wait for the slow handler thread to finish (it sleeps 2s) }
    platform_thread_sleep_ns(2500000000);
  end;
end;

{ Test 7: Client handles 404 response }
procedure TestClientHandles404;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/exists', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AW.GetHeaders.Set_('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(PAnsiChar('ok')^, 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/not-found');
    CheckEqual(Int64(404), Int64(LResp.StatusCode), 'status 404');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ Test 8: Client sets Host header automatically }
procedure TestClientSetsHostHeader;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LGotHost: string;
begin
  LGotHost := '';
  LRouter := THttpRouter.Create;
  LRouter.Get('/check-host', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LB: string;
  begin
    LGotHost := AReq.Headers.Get('host');
    LB := LGotHost;
    AW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LB))));
    AW.WriteHeader(HTTP_STATUS_OK);
    if Length(LB) > 0 then
      AW.Write(LB[1], SizeUInt(Length(LB)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/check-host');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    Check(LGotHost <> '', 'Host header was set');
    Check(Pos('127.0.0.1', LGotHost) > 0, 'Host contains IP');
  finally
    StopServer(LServer, LHandle);
  end;
end;

function PoolAcceptThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LReply: string;
  LAccum: string;
  LP: SizeInt;
begin
  Result := nil;
  while True do
  begin
    try
      LConn := GPoolListener.Accept;
    except
      Break;
    end;
    if LConn = nil then Break;
    InterlockedIncrement(GAcceptCount);
    { Serve multiple requests on this connection by detecting \r\n\r\n boundaries }
    try
      LAccum := '';
      while True do
      begin
        LN := LConn.Read(LBuf[0], 4096);
        if LN = 0 then Break;
        SetLength(LAccum, Length(LAccum) + Int32(LN));
        Move(LBuf[0], LAccum[Length(LAccum) - Int32(LN) + 1], LN);
        { Process all complete requests in the buffer }
        while True do
        begin
          LP := Pos(#13#10#13#10, LAccum);
          if LP = 0 then Break;
          { Found a complete request — send response }
          LReply := 'HTTP/1.1 200 OK'#13#10 +
                    'Content-Length: 2'#13#10 +
                    #13#10 +
                    'ok';
          LConn.Write(LReply[1], SizeUInt(Length(LReply)));
          { Remove processed request from buffer }
          System.Delete(LAccum, 1, LP + 3);
        end;
      end;
    except
    end;
    LConn.Close;
  end;
end;

procedure TestConnectionReuse;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LI: Int32;
  LRet: Pointer;
begin
  GAcceptCount := 0;
  GPoolListener := NetTcpListen('127.0.0.1', 0);
  LPort := GPoolListener.LocalAddr.Port;
  platform_thread_create(LHandle, @PoolAcceptThread, nil);

  try
    LClient := NewHttpClient;
    for LI := 1 to 3 do
    begin
      LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/ping');
      CheckEqual(Int64(200), Int64(LResp.StatusCode), 'request ' + IntToStr(Int64(LI)) + ' status 200');
    end;
    { All 3 requests should have reused 1 connection }
    CheckEqual(Int64(1), Int64(GAcceptCount), 'only 1 accept (connection reused)');
    { Release client to close pooled connections, unblocking server thread }
    LClient := nil;
  finally
    GPoolListener.Close;
    platform_thread_join(LHandle, LRet);
    GPoolListener := nil;
  end;
end;

{ Main }

begin
  T := TTestRunner.Create('nextpas.core.http.client');
  T.Run('Client GET returns 200 + body', @TestClientGet200);
  T.Run('Client Do rejects nil request', @TestClientDoRejectsNilRequest);
  T.Run('Client Do rejects nil transport response',
    @TestClientDoRejectsNilTransportResponse);
  T.Run('Client GET with custom headers', @TestClientGetCustomHeaders);
  T.Run('Client POST with body', @TestClientPostBody);
  T.Run('Client Do uses NewRequest headers/body helper',
    @TestClientDoWithRequestHelperHeadersBody);
  T.Run('Client Do uses NewRequest bytes body helper',
    @TestClientDoWithRequestHelperBytesBody);
  T.Run('Client Do uses NewRequest string body helper without headers',
    @TestClientDoWithRequestHelperStringBodyWithoutHeaders);
  T.Run('Client Do uses NewRequest bytes body helper without headers',
    @TestClientDoWithRequestHelperBytesBodyWithoutHeaders);
  T.Run('Client Do uses NewRequest string body helper with content-type without headers',
    @TestClientDoWithRequestHelperStringBodyAndContentTypeWithoutHeaders);
  T.Run('Client Do uses NewRequest bytes body helper with content-type without headers',
    @TestClientDoWithRequestHelperBytesBodyAndContentTypeWithoutHeaders);
  T.Run('Client shortcut bodies use bytes buffer',
    @TestClientShortcutBodyImplementationUsesBytesBuffer);
  T.Run('Client POST string body overload',
    @TestClientPostStringBodyOverload);
  T.Run('Client PUT sends body and content type', @TestClientPutBodyAndContentType);
  T.Run('Client DELETE sends no body', @TestClientDeleteNoBody);
  T.Run('Client PATCH bytes body overload',
    @TestClientPatchBytesBodyOverload);
  T.Run('Client PATCH sends body and content type', @TestClientPatchBodyAndContentType);
  T.Run('Client HEAD sends HEAD and exposes headers', @TestClientHeadSendsHead);
  T.Run('Client reads chunked response body', @TestClientReadsChunkedResponse);
  T.Run('Client reads close-delimited response body', @TestClientReadsCloseDelimitedResponse);
  T.Run('Client rejects truncated content-length response', @TestClientRejectsTruncatedContentLengthResponse);
  T.Run('HttpGetToWriter copies response body', @TestHttpGetToWriterCopiesResponseBody);
  T.Run('HttpGetToWriter closes body after successful copy',
    @TestHttpGetToWriterClosesBodyAfterSuccessfulCopy);
  T.Run('HttpGetToWriter closes body when copy fails',
    @TestHttpGetToWriterClosesBodyWhenCopyFails);
  T.Run('HttpGetToWriter closes non-2xx body before raising',
    @TestHttpGetToWriterClosesNon2xxBodyBeforeRaising);
  T.Run('HttpReadResponseBodyString reads live response body',
    @TestHttpReadResponseBodyStringReadsLiveResponse);
  T.Run('HttpReadResponseBodyString nil body returns empty',
    @TestHttpReadResponseBodyStringNilBodyReturnsEmpty);
  T.Run('HttpReadResponseBodyString rejects nil response',
    @TestHttpReadResponseBodyStringRejectsNilResponse);
  T.Run('HttpReadResponseBodyBytes reads live response body',
    @TestHttpReadResponseBodyBytesReadsLiveResponse);
  T.Run('HttpReadResponseBodyBytes nil body returns empty',
    @TestHttpReadResponseBodyBytesNilBodyReturnsEmpty);
  T.Run('HttpReadResponseBodyBytes rejects nil response',
    @TestHttpReadResponseBodyBytesRejectsNilResponse);
  T.Run('HttpReleaseResponseBody closes close-capable body',
    @TestHttpReleaseResponseBodyClosesCloseCapableBody);
  T.Run('HttpReleaseResponseBody drains plain reader',
    @TestHttpReleaseResponseBodyDrainsPlainReader);
  T.Run('HttpReleaseResponseBody nil body noop',
    @TestHttpReleaseResponseBodyNilBodyNoop);
  T.Run('HttpReleaseResponseBody rejects nil response',
    @TestHttpReleaseResponseBodyRejectsNilResponse);
  T.Run('HttpGetToFile writes final path atomically', @TestHttpGetToFileWritesFinalPathAtomically);
  T.Run('HttpGetToFile rejects 404 responses', @TestHttpGetToFileRejects404Responses);
  T.Run('HttpGetToFile cleans temp files on truncated body', @TestHttpGetToFileCleansTempFilesOnTruncatedBody);
  T.Run('Client follows redirect (301 -> 200)', @TestClientFollowsRedirect);
  T.Run('Client follows 303 redirect as GET', @TestClientFollowsSeeOtherAsGet);
  T.Run('Client preserves relative redirect query', @TestClientPreservesRelativeRedirectQuery);
  T.Run('Client redirect transport sees parsed relative query',
    @TestClientRedirectTransportSeesParsedRelativeQuery);
  T.Run('Client redirect transport resolves network-path Location',
    @TestClientRedirectTransportResolvesNetworkPathLocation);
  T.Run('Client redirect transport resolves uppercase absolute Location',
    @TestClientRedirectTransportResolvesUppercaseAbsoluteLocation);
  T.Run('Client redirect rejects unsupported absolute scheme',
    @TestClientRedirectRejectsUnsupportedAbsoluteScheme);
  T.Run('Client redirect transport resolves path-relative Location',
    @TestClientRedirectTransportResolvesPathRelativeLocation);
  T.Run('Client redirect transport normalizes dot-segment Location',
    @TestClientRedirectTransportNormalizesDotSegmentLocation);
  T.Run('Client redirect transport preserves query on fragment-only Location',
    @TestClientRedirectTransportPreservesQueryOnFragmentOnlyLocation);
  T.Run('Client redirect preserves headers on same authority',
    @TestClientRedirectPreservesHeadersOnSameAuthority);
  T.Run('Client redirect strips sensitive headers across authority',
    @TestClientRedirectStripsSensitiveHeadersAcrossAuthority);
  T.Run('Client redirect preserves custom host header on relative Location',
    @TestClientRedirectPreservesCustomHostHeaderOnRelativeLocation);
  T.Run('Client redirect preserves custom host header on default-port authority',
    @TestClientRedirectPreservesCustomHostHeaderOnDefaultPortAuthority);
  T.Run('Client closes redirect response body before follow-up',
    @TestClientClosesRedirectResponseBodyBeforeFollowup);
  T.Run('Client drains redirect response body before follow-up',
    @TestClientDrainsRedirectResponseBodyBeforeFollowup);
  T.Run('Client closes redirect response body on too many redirects',
    @TestClientClosesRedirectResponseBodyOnTooManyRedirects);
  T.Run('Client closes redirect response body on missing Location',
    @TestClientClosesRedirectResponseBodyOnMissingLocation);
  T.Run('Client closes redirect response body on unsupported scheme',
    @TestClientClosesRedirectResponseBodyOnUnsupportedScheme);
  T.Run('Client replays seekable body on 307 redirect',
    @TestClientReplaysSeekableBodyOnTemporaryRedirect);
  T.Run('Client rejects non-replayable body on 307 redirect',
    @TestClientRejectsNonReplayableBodyOnTemporaryRedirect);
  T.Run('Client options reject negative values',
    @TestClientOptionsRejectNegativeValues);
  T.Run('Client respects max redirects', @TestClientMaxRedirects);
  T.Run('Client CloseIdleConnections drops pooled connections',
    @TestClientCloseIdleConnectionsDropsPooledConnections);
  T.Run('Client retries idempotent replayable body after stale pooled connection',
    @TestClientRetriesIdempotentReplayableBodyAfterStalePooledConnection);
  T.Run('Client rejects non-idempotent replayable body after stale pooled connection',
    @TestClientRejectsNonIdempotentReplayableBodyAfterStalePooledConnection);
  T.Run('Client rejects non-replayable idempotent body after stale pooled connection',
    @TestClientRejectsNonReplayableIdempotentBodyAfterStalePooledConnection);
  T.Run('Client timeout on slow server', @TestClientTimeout);
  T.Run('Client handles 404 response', @TestClientHandles404);
  T.Run('Client sets Host header automatically', @TestClientSetsHostHeader);
  T.Run('Connection reuse', @TestConnectionReuse);
  T.Summary;
end.
