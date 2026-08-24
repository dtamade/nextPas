program test_http_client_redirect;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.thread.init,
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.test,
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
  nextpas.core.http.impl.h1,
  nextpas.core.http.impl.tls.stream,
  nextpas.core.http.client,
  nextpas.core.http.form.base,
  nextpas.core.json,
  nextpas.core.json.value,
  nextpas.core.compress,
  nextpas.core.http,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.encoding,
  nextpas.core.tls.base,
  nextpas.core.tls.cert.builder,
  nextpas.core.tls.context.builder,
  nextpas.core.tls.openssl.backed,
  nextpas.core.platform.thread;

var
  T: TTestSuite;
  GRawListener: ITcpListener;
  GRawResponse1: string;
  GRawResponse2: string;
  GRawRequest1: string;
  GRawRequest2: string;
  GPoolRequest1: string;
  GPoolRequest2: string;
  GRawAcceptLimit: Int32;
  GRawAcceptCount: Int32;
  GAcceptCount: Int32;
  GAcceptCountAlt: Int32;
  GPoolListener: ITcpListener;
  GPoolListenerAlt: ITcpListener;
  GRetryListener: ITcpListener;
  GRetryAcceptCount: Int32;
  GRetryPooledMethod: string;
  GRetryPooledBody: string;
  GRetrySecondMethod: string;
  GRetrySecondBody: string;
  GRetryBodyTimeoutSecondAttemptSeen: Boolean;
  GPoisonListener: ITcpListener;
  GPoisonAcceptCount: Int32;
  GPoisonReusedMethod: string;
  GBodyLimitListener: ITcpListener;
  GBodyLimitDeclaredBody: string;
  GBodyLimitExtraBody: string;
  GBodyLimitReplyAfterRead: Boolean;
  GWriteFailureListener: ITcpListener;
  GWriteFailureAcceptCount: Int32;
  GWriteFailureFirstBody: string;
  GConnectProxyListener: ITcpListener;
  GConnectProxyServerCtx: ISSLContext;
  GConnectProxyMode: string;
  GConnectProxyConnectRequest: string;
  GConnectProxyHttpRequest: string;
  GConnectProxyHttpReply: string;
  GDirectHttpsListener: ITcpListener;
  GDirectHttpsServerCtx: ISSLContext;
  GDirectHttpsRequest: string;
  GDirectHttpsReply: string;

type
  TTrackedRequestBody = class;

  PServerCtx = ^TServerCtx;
  TServerCtx = record
    Server: THttpServer;
    Addr: string;
    Port: UInt16;
  end;

  TRedirectCaptureTransport = class(TInterfacedObject, IHttpTransport)
  private
    FCalls: Int32;
    FTrackedBody: TTrackedRequestBody;
    FRedirectLocation: string;
    FRedirectStatus: THttpStatus;
    FFirstBody: string;
    FSecondBody: string;
    FOriginalBodyClosedBeforeFollowup: Boolean;
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
    FSeenProxyAuthorizationHeader: string;
    FSeenWwwAuthenticateHeader: string;
    FSeenCookieHeader: string;
    FSeenCookie2Header: string;
  public
    constructor Create; overload;
    constructor Create(const ATrackedBody: TTrackedRequestBody); overload;
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
    property Calls: Int32 read FCalls;
    property RedirectLocation: string read FRedirectLocation write FRedirectLocation;
    property RedirectStatus: THttpStatus read FRedirectStatus write FRedirectStatus;
    property FirstBody: string read FFirstBody;
    property SecondBody: string read FSecondBody;
    property OriginalBodyClosedBeforeFollowup: Boolean
      read FOriginalBodyClosedBeforeFollowup;
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
    property SeenProxyAuthorizationHeader: string
      read FSeenProxyAuthorizationHeader;
    property SeenWwwAuthenticateHeader: string read FSeenWwwAuthenticateHeader;
    property SeenCookieHeader: string read FSeenCookieHeader;
    property SeenCookie2Header: string read FSeenCookie2Header;
  end;

  TNilResponseTransport = class(TInterfacedObject, IHttpTransport)
  public
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
  end;

  TNilHeadersRedirectTransport = class(TInterfacedObject, IHttpTransport)
  public
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
  end;

  TNilHeadersRequest = class(TInterfacedObject, IHttpRequest)
  private
    FUrl: TUrl;
  public
    constructor Create(const AUrl: string);
    function GetMethod: THttpMethod;
    function GetUrl: TUrl;
    function GetPath: string;
    function GetRawQuery: string;
    function GetVersion: THttpVersion;
    function GetHeaders: IHttpHeaders;
    function GetTrailers: IHttpHeaders;
    function GetBody: IReader;
    function GetContentLength: Int64;
    function GetRemoteAddr: string;
    function GetRemoteIp: string;
    function PathParam(const AName: string): string;
    function QueryParam(const AName: string): string;
  end;

  TUrlCaptureTransport = class(TInterfacedObject, IHttpTransport)
  private
    FCalls: Int32;
    FSeenScheme: string;
    FSeenHost: string;
    FSeenPath: string;
  public
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
    property Calls: Int32 read FCalls;
    property SeenScheme: string read FSeenScheme;
    property SeenHost: string read FSeenHost;
    property SeenPath: string read FSeenPath;
  end;

  TNilHeadersRedirectResponse = class(TInterfacedObject, IHttpResponse)
  public
    function GetStatusCode: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function GetBody: IReader;
    function GetFinalUrl: string;
    function GetVersion: THttpVersion;
    procedure Close;
  end;

  TCustomWireHeader = class(TInterfacedObject, IHttpHeaders)
  private
    FName: string;
    FValue: string;
  public
    constructor Create(const AName, AValue: string);
    procedure SetHeader(const AName, AValue: string);
    procedure Add(const AName, AValue: string);
    function Get(const AName: string): string;
    function GetAll(const AName: string): TStringArray;
    function Has(const AName: string): Boolean;
    procedure Remove(const AName: string);
    procedure Clear;
    function Count: Int32;
    procedure ForEach(const ACallback: THeaderIterator);
    function Clone: IHttpHeaders;
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

  TCloseFailingResponseBody = class(TInterfacedObject, IReader, IReadCloser)
  private
    FData: string;
    FPos: SizeInt;
    FClosed: Boolean;
    FCloseCount: Int32;
  public
    constructor Create(const AData: string = '');
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
    property Closed: Boolean read FClosed;
    property CloseCount: Int32 read FCloseCount;
  end;

  TReadAndCloseFailingResponseBody = class(TInterfacedObject, IReader, IReadCloser)
  private
    FClosed: Boolean;
    FCloseCount: Int32;
  public
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
    property Closed: Boolean read FClosed;
    property CloseCount: Int32 read FCloseCount;
  end;

  TReadAndCloseFailingRequestBody = class(TInterfacedObject, IReader, IReadCloser)
  private
    FClosed: Boolean;
    FCloseCount: Int32;
  public
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
    property Closed: Boolean read FClosed;
    property CloseCount: Int32 read FCloseCount;
  end;

  TPartialReadFailingRequestBody = class(TInterfacedObject, IReader, IReadCloser)
  private
    FData: string;
    FPos: SizeInt;
    FClosed: Boolean;
    FCloseCount: Int32;
  public
    constructor Create(const AData: string);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
    property Closed: Boolean read FClosed;
    property CloseCount: Int32 read FCloseCount;
  end;

  TTrackedRequestBody = class(TInterfacedObject, IReader, IReadCloser)
  private
    FData: string;
    FPos: SizeInt;
    FClosed: Boolean;
    FCloseCount: Int32;
    FRaiseOnClose: Boolean;
  public
    constructor Create(const AData: string; const ARaiseOnClose: Boolean = False);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
    property Closed: Boolean read FClosed;
    property CloseCount: Int32 read FCloseCount;
  end;

  TRequestBodyCaptureTransport = class(TInterfacedObject, IHttpTransport)
  private
    FTrackedBody: TTrackedRequestBody;
    FRaiseAfterRead: Boolean;
    FSeenBody: string;
    FSeenMethod: THttpMethod;
    FSeenContentType: string;
    FSeenContentTypeHeader: Boolean;
    FSeenContentLength: Int64;
    FTrackedBodyClosedAtEntry: Boolean;
    FTrackedBodyClosedBeforeReturn: Boolean;
    FResponseBody: IReader;
  public
    constructor Create(const ATrackedBody: TTrackedRequestBody;
      const ARaiseAfterRead: Boolean = False; const AResponseBody: IReader = nil);
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
    property SeenBody: string read FSeenBody;
    property SeenMethod: THttpMethod read FSeenMethod;
    property SeenContentType: string read FSeenContentType;
    property SeenContentTypeHeader: Boolean read FSeenContentTypeHeader;
    property SeenContentLength: Int64 read FSeenContentLength;
    property TrackedBodyClosedAtEntry: Boolean read FTrackedBodyClosedAtEntry;
    property TrackedBodyClosedBeforeReturn: Boolean
      read FTrackedBodyClosedBeforeReturn;
  end;

  { Mock transport that records the timeout used in RoundTrip }
  TTimeoutCaptureTransport = class(TInterfacedObject, IHttpTransport)
  private
    FCapturedTimeoutMs: Int64;
    FDefaultTimeoutMs: Int64;
  public
    constructor Create(const ADefaultTimeoutMs: Int64);
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
    property CapturedTimeoutMs: Int64 read FCapturedTimeoutMs;
  end;

  TRetryTestTransport = class(TInterfacedObject, IHttpTransport)
  private
    FFailCount: Int32;
    FCalls: Int32;
    FFailStatus: THttpStatus;
    FRaiseKind: THttpErrorKind;
    FRaiseOnFail: Boolean;
    FRetryAfter: string;
    FFailBody: string;
  public
    constructor Create(const AFailCount: Int32; const AFailStatus: THttpStatus);
    constructor CreateRaising(const AFailCount: Int32;
      const ARaiseKind: THttpErrorKind);
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
    property Calls: Int32 read FCalls;
    property RetryAfter: string read FRetryAfter write FRetryAfter;
    property FailBody: string read FFailBody write FFailBody;
  end;

  TJsonBodyTransport = class(TInterfacedObject, IHttpTransport)
  private
    FStatus: THttpStatus;
    FBody: string;
  public
    constructor Create(const AStatus: THttpStatus; const ABody: string);
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
  end;

  TRedirectBodyReleaseTransport = class(TInterfacedObject, IHttpTransport)
  private
    FCalls: Int32;
    FRedirectLocation: string;
    FDuplicateLocation: Boolean;
    FOmitLocation: Boolean;
    FFailBodyClose: Boolean;
    FBody: IReadCloser;
    FBodyRef: IReadCloser;
    FTrackedBody: TRedirectTrackedBody;
    FCloseFailingBody: TCloseFailingResponseBody;
    FBodyClosedBeforeFollowup: Boolean;
    function GetBodyClosed: Boolean;
    function GetBodyCloseCount: Int32;
  public
    constructor Create;
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
    property Calls: Int32 read FCalls;
    property RedirectLocation: string read FRedirectLocation write FRedirectLocation;
    property DuplicateLocation: Boolean read FDuplicateLocation write FDuplicateLocation;
    property OmitLocation: Boolean read FOmitLocation write FOmitLocation;
    property FailBodyClose: Boolean read FFailBodyClose write FFailBodyClose;
    property BodyClosed: Boolean read GetBodyClosed;
    property BodyCloseCount: Int32 read GetBodyCloseCount;
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
    function Send(const AReq: IHttpRequest): IHttpResponse;
    procedure CloseIdleConnections;
    function Get(const AUrl: string): IHttpResponse;
    function GetString(const AUrl: string): string;
    function GetBytes(const AUrl: string): TBytes;
    function GetJson(const AUrl: string): IJsonDocument;
    function PostString(const AUrl, AContentType, ABody: string): string;
    function PutString(const AUrl, AContentType, ABody: string): string;
    function PatchString(const AUrl, AContentType, ABody: string): string;
    function DeleteString(const AUrl: string): string;
    function Post(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload;
    function Post(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload;
    function Put(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload;
    function Put(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload;
    function Delete(const AUrl: string): IHttpResponse; overload;
    function Delete(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload;
    function Delete(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload;
    function Patch(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload;
    function Patch(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload;
    function Head(const AUrl: string): IHttpResponse;
    function Options(const AUrl: string): IHttpResponse;
    function PostForm(const AUrl: string; const AFields: TFormFieldArray): IHttpResponse;
    function PostMultipart(const AUrl: string; const AFields: TFormFieldArray;
      const AFiles: THttpFileArray): IHttpResponse;
    function PostJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
    function PutJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
    function PatchJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
    function DeleteJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
    function SendStreaming(const AMethod: THttpMethod; const AUrl: string;
      const AContentType: string; const ABody: IReader;
      const AContentLength: Int64): IHttpResponse;
    function WithBasicAuth(const AUsername, APassword: string): IHttpClient;
    function WithBearerAuth(const AToken: string): IHttpClient;
    function WithHeader(const AName, AValue: string): IHttpClient;
    function WithTimeout(const ATimeoutMs: Int64): IHttpClient;
    function WithConnectTimeout(const ATimeoutMs: Int64): IHttpClient;
    function WithMaxRedirects(const AMaxRedirects: Int32): IHttpClient;
    function WithFollowRedirects(const AFollow: Boolean): IHttpClient;
    function WithRetry(const AMaxRetries: Int32): IHttpClient;
    function WithCookieJar(const AJar: IHttpCookieJar): IHttpClient;
    function WithProxyUrl(const AProxyUrl: string): IHttpClient;
    function WithDialFunc(const ADial: THttpDialFunc): IHttpClient;
    function WithTLSContext(const ATLSContext: ISSLContext): IHttpClient;
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
function PoolAcceptThreadAlt(AArg: Pointer): Pointer; cdecl; forward;
function PoolAuthorityCaseThread(AArg: Pointer): Pointer; cdecl; forward;

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
    InterlockedIncrement(GRawAcceptCount);
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
        GRawRequest1 := LAccum
      else
        GRawRequest2 := LAccum;

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

function ConnectProxyThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LTlsConn: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LAccum: string;
  LReply: string;
  LP: SizeInt;
begin
  Result := nil;
  try
    LConn := GConnectProxyListener.Accept;
  except
    Exit;
  end;
  if LConn = nil then
    Exit;
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
    GConnectProxyConnectRequest := LAccum;

    if GConnectProxyMode = 'deny' then
    begin
      LReply := 'HTTP/1.1 403 Forbidden'#13#10 +
                'Content-Length: 0'#13#10 +
                #13#10;
      LConn.Write(LReply[1], SizeUInt(Length(LReply)));
      Exit;
    end;

    if GConnectProxyMode = 'auth-required' then
    begin
      LReply := 'HTTP/1.1 407 Proxy Authentication Required'#13#10 +
                'Proxy-Authenticate: Basic realm="proxy"'#13#10 +
                'Content-Length: 0'#13#10 +
                #13#10;
      LConn.Write(LReply[1], SizeUInt(Length(LReply)));
      Exit;
    end;

    LReply := 'HTTP/1.1 200 Connection Established'#13#10 +
              #13#10;
    LConn.Write(LReply[1], SizeUInt(Length(LReply)));

    if GConnectProxyServerCtx = nil then
      Exit;
    LTlsConn := NewTlsServerTcpStream(LConn, GConnectProxyServerCtx);
    try
      LAccum := '';
      repeat
        LN := LTlsConn.Read(LBuf[0], 4096);
        if LN = 0 then
          Break;
        SetLength(LAccum, Length(LAccum) + Int32(LN));
        Move(LBuf[0], LAccum[Length(LAccum) - Int32(LN) + 1], LN);
        LP := Pos(#13#10#13#10, LAccum);
      until LP > 0;
      GConnectProxyHttpRequest := LAccum;
      if GConnectProxyHttpReply <> '' then
        LTlsConn.Write(GConnectProxyHttpReply[1],
          SizeUInt(Length(GConnectProxyHttpReply)));
    finally
      LTlsConn.Close;
    end;
  except
  end;
  LConn.Close;
end;

function DirectHttpsThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LTlsConn: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LAccum: string;
  LP: SizeInt;
begin
  Result := nil;
  try
    LConn := GDirectHttpsListener.Accept;
  except
    Exit;
  end;
  if LConn = nil then
    Exit;
  try
    if GDirectHttpsServerCtx = nil then
      Exit;
    LTlsConn := NewTlsServerTcpStream(LConn, GDirectHttpsServerCtx);
    try
      LAccum := '';
      repeat
        LN := LTlsConn.Read(LBuf[0], 4096);
        if LN = 0 then
          Break;
        SetLength(LAccum, Length(LAccum) + Int32(LN));
        Move(LBuf[0], LAccum[Length(LAccum) - Int32(LN) + 1], LN);
        LP := Pos(#13#10#13#10, LAccum);
      until LP > 0;
      GDirectHttpsRequest := LAccum;
      if GDirectHttpsReply <> '' then
        LTlsConn.Write(GDirectHttpsReply[1], SizeUInt(Length(GDirectHttpsReply)));
    finally
      LTlsConn.Close;
    end;
  except
  end;
  LConn.Close;
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

function RawHeaderValue(const ARawRequest, AHeaderName: string): string;
var
  LLowerRequest: string;
  LNeedle: string;
  LHeaderPos: SizeInt;
  LValueStart: SizeInt;
  LValueEnd: SizeInt;
begin
  Result := '';
  LLowerRequest := LowerCase(ARawRequest);
  LNeedle := #13#10 + LowerCase(AHeaderName) + ':';
  LHeaderPos := Pos(LNeedle, LLowerRequest);
  if LHeaderPos = 0 then
    Exit;

  LValueStart := LHeaderPos + Length(#13#10) + Length(AHeaderName) + 1;
  while (LValueStart <= Length(ARawRequest)) and
    (ARawRequest[LValueStart] in [' ', #9]) do
    Inc(LValueStart);

  LValueEnd := LValueStart;
  while (LValueEnd <= Length(ARawRequest)) and
    (ARawRequest[LValueEnd] <> #13) do
    Inc(LValueEnd);
  Result := System.Copy(ARawRequest, LValueStart, LValueEnd - LValueStart);
end;

function ReadRawHttpRequest(const AConn: ITcpStream): string;
var
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
begin
  Result := '';
  AConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(500)));
  repeat
    try
      LN := AConn.Read(LBuf[0], 4096);
    except
      Break;
    end;
    if LN = 0 then
      Break;
    SetLength(Result, Length(Result) + Int32(LN));
    Move(LBuf[0], Result[Length(Result) - Int32(LN) + 1], LN);
  until Pos(#13#10#13#10, Result) > 0;
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

function PooledBodyTimeoutThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LReply: string;
  LMethod: string;
  LBody: string;
begin
  Result := nil;
  try
    LConn := GRetryListener.Accept;
  except
    Exit;
  end;
  if LConn = nil then
    Exit;

  InterlockedIncrement(GRetryAcceptCount);
  try
    ReadRetryRawRequest(LConn, LMethod, LBody);
    LReply := 'HTTP/1.1 200 OK'#13#10 +
              'Content-Length: 2'#13#10 +
              #13#10 +
              'ok';
    LConn.Write(LReply[1], SizeUInt(Length(LReply)));

    ReadRetryRawRequest(LConn, LMethod, LBody);
    LReply := 'HTTP/1.1 200 OK'#13#10 +
              'Content-Length: 10'#13#10 +
              #13#10 +
              'hello';
    LConn.Write(LReply[1], SizeUInt(Length(LReply)));
    platform_thread_sleep_ns(250000000);
  except
  end;
  LConn.Close;

  try
    LConn := GRetryListener.Accept;
  except
    Exit;
  end;
  if LConn = nil then
    Exit;

  InterlockedIncrement(GRetryAcceptCount);
  GRetryBodyTimeoutSecondAttemptSeen := True;
  try
    ReadRetryRawRequest(LConn, LMethod, LBody);
    LReply := 'HTTP/1.1 200 OK'#13#10 +
              'Content-Length: 23'#13#10 +
              #13#10 +
              'retry-should-not-happen';
    LConn.Write(LReply[1], SizeUInt(Length(LReply)));
  except
  end;
  LConn.Close;
end;

function PostWritePooledRetryThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LReply: string;
  LMethod: string;
  LBody: string;
begin
  Result := nil;
  try
    LConn := GRetryListener.Accept;
  except
    Exit;
  end;
  if LConn = nil then
    Exit;

  InterlockedIncrement(GRetryAcceptCount);
  try
    ReadRetryRawRequest(LConn, LMethod, LBody);
    LReply := 'HTTP/1.1 200 OK'#13#10 +
              'Content-Length: 2'#13#10 +
              'Connection: keep-alive'#13#10 +
              #13#10 +
              'ok';
    LConn.Write(LReply[1], SizeUInt(Length(LReply)));

    ReadRetryRawRequest(LConn, GRetryPooledMethod, GRetryPooledBody);
  except
  end;
  LConn.Close;

  try
    LConn := GRetryListener.Accept;
  except
    Exit;
  end;
  if LConn = nil then
    Exit;

  InterlockedIncrement(GRetryAcceptCount);
  try
    ReadRetryRawRequest(LConn, GRetrySecondMethod, GRetrySecondBody);
    if GRetrySecondBody = 'payload' then
      LReply := 'HTTP/1.1 200 OK'#13#10 +
                'Content-Length: 8'#13#10 +
                #13#10 +
                'retry-ok'
    else
      LReply := 'HTTP/1.1 400 Bad Request'#13#10 +
                'Content-Length: 3'#13#10 +
                #13#10 +
                'bad';
    LConn.Write(LReply[1], SizeUInt(Length(LReply)));
  except
  end;
  LConn.Close;
end;

function PooledRetrySingleTimeoutBudgetThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LReply: string;
  LMethod: string;
  LBody: string;
begin
  Result := nil;
  try
    LConn := GRetryListener.Accept;
  except
    Exit;
  end;
  if LConn = nil then
    Exit;

  InterlockedIncrement(GRetryAcceptCount);
  try
    ReadRetryRawRequest(LConn, LMethod, LBody);
    LReply := 'HTTP/1.1 200 OK'#13#10 +
              'Content-Length: 2'#13#10 +
              'Connection: keep-alive'#13#10 +
              #13#10 +
              'ok';
    LConn.Write(LReply[1], SizeUInt(Length(LReply)));

    ReadRetryRawRequest(LConn, GRetryPooledMethod, GRetryPooledBody);
    platform_thread_sleep_ns(300000000);
  except
  end;
  LConn.Close;

  try
    LConn := GRetryListener.Accept;
  except
    Exit;
  end;
  if LConn = nil then
    Exit;

  InterlockedIncrement(GRetryAcceptCount);
  try
    ReadRetryRawRequest(LConn, GRetrySecondMethod, GRetrySecondBody);
    platform_thread_sleep_ns(200000000);
    LReply := 'HTTP/1.1 200 OK'#13#10 +
              'Content-Length: 8'#13#10 +
              #13#10 +
              'retry-ok';
    LConn.Write(LReply[1], SizeUInt(Length(LReply)));
  except
  end;
  LConn.Close;
end;

function PooledResponseTailThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LReply: string;
  LMethod: string;
  LBody: string;
  LI: Int32;
begin
  Result := nil;
  for LI := 1 to 2 do
  begin
    try
      LConn := GPoisonListener.Accept;
    except
      Break;
    end;
    if LConn = nil then
      Break;

    InterlockedIncrement(GPoisonAcceptCount);
    try
      ReadRetryRawRequest(LConn, LMethod, LBody);
      if LI = 1 then
      begin
        LReply := 'HTTP/1.1 200 OK'#13#10 +
                  'Content-Length: 2'#13#10 +
                  #13#10 +
                  'ok';
        LConn.Write(LReply[1], SizeUInt(Length(LReply)));
        platform_thread_sleep_ns(50000000);
        LReply := 'HTTP/1.1 599 Poisoned'#13#10 +
                  'Content-Length: 6'#13#10 +
                  #13#10 +
                  'poison';
        LConn.Write(LReply[1], SizeUInt(Length(LReply)));
        platform_thread_sleep_ns(250000000);
      end
      else
      begin
        LReply := 'HTTP/1.1 200 OK'#13#10 +
                  'Content-Length: 8'#13#10 +
                  #13#10 +
                  'fresh-ok';
        LConn.Write(LReply[1], SizeUInt(Length(LReply)));
      end;
    except
    end;
    LConn.Close;
  end;
end;

function SameReadResponseTailThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LReply: string;
  LMethod: string;
  LBody: string;
  LI: Int32;
begin
  Result := nil;
  for LI := 1 to 2 do
  begin
    try
      LConn := GPoisonListener.Accept;
    except
      Break;
    end;
    if LConn = nil then
      Break;

    InterlockedIncrement(GPoisonAcceptCount);
    try
      ReadRetryRawRequest(LConn, LMethod, LBody);
      if LI = 1 then
      begin
        LReply := 'HTTP/1.1 200 OK'#13#10 +
                  'Content-Length: 2'#13#10 +
                  #13#10 +
                  'ok' +
                  'HTTP/1.1 599 Poisoned'#13#10 +
                  'Content-Length: 6'#13#10 +
                  #13#10 +
                  'poison';
        LConn.Write(LReply[1], SizeUInt(Length(LReply)));
        platform_thread_sleep_ns(250000000);
      end
      else
      begin
        LReply := 'HTTP/1.1 200 OK'#13#10 +
                  'Content-Length: 8'#13#10 +
                  #13#10 +
                  'fresh-ok';
        LConn.Write(LReply[1], SizeUInt(Length(LReply)));
      end;
    except
    end;
    LConn.Close;
  end;
end;

function RequestConnectionClosePoolThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LReply: string;
  LMethod: string;
  LBody: string;
begin
  Result := nil;
  try
    LConn := GPoisonListener.Accept;
  except
    Exit;
  end;
  if LConn = nil then
    Exit;

  InterlockedIncrement(GPoisonAcceptCount);
  try
    ReadRetryRawRequest(LConn, LMethod, LBody);
    LReply := 'HTTP/1.1 200 OK'#13#10 +
              'Content-Length: 2'#13#10 +
              'Connection: keep-alive'#13#10 +
              #13#10 +
              'ok';
    LConn.Write(LReply[1], SizeUInt(Length(LReply)));

    LConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(150)));
    ReadRetryRawRequest(LConn, GPoisonReusedMethod, LBody);
    if GPoisonReusedMethod <> '' then
    begin
      LReply := 'HTTP/1.1 599 Poisoned'#13#10 +
                'Content-Length: 6'#13#10 +
                'Connection: close'#13#10 +
                #13#10 +
                'poison';
      LConn.Write(LReply[1], SizeUInt(Length(LReply)));
    end;
  except
  end;
  LConn.Close;

  try
    LConn := GPoisonListener.Accept;
  except
    Exit;
  end;
  if LConn = nil then
    Exit;

  InterlockedIncrement(GPoisonAcceptCount);
  try
    ReadRetryRawRequest(LConn, LMethod, LBody);
    if LMethod <> '' then
    begin
      LReply := 'HTTP/1.1 200 OK'#13#10 +
                'Content-Length: 8'#13#10 +
                'Connection: close'#13#10 +
                #13#10 +
                'fresh-ok';
      LConn.Write(LReply[1], SizeUInt(Length(LReply)));
    end;
  except
  end;
  LConn.Close;
end;

function MalformedPooledChunkedResponseThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LReply: string;
  LMethod: string;
  LBody: string;
begin
  Result := nil;
  try
    LConn := GPoisonListener.Accept;
  except
    Exit;
  end;
  if LConn = nil then
    Exit;

  InterlockedIncrement(GPoisonAcceptCount);
  try
    ReadRetryRawRequest(LConn, LMethod, LBody);
    LReply := 'HTTP/1.1 200 OK'#13#10 +
              'Content-Length: 2'#13#10 +
              #13#10 +
              'ok';
    LConn.Write(LReply[1], SizeUInt(Length(LReply)));

    ReadRetryRawRequest(LConn, LMethod, LBody);
    LReply := 'HTTP/1.1 200 OK'#13#10 +
              'Transfer-Encoding: chunked'#13#10 +
              #13#10 +
              'Z'#13#10 +
              'hello'#13#10;
    LConn.Write(LReply[1], SizeUInt(Length(LReply)));

    ReadRetryRawRequest(LConn, GPoisonReusedMethod, LBody);
    if GPoisonReusedMethod <> '' then
    begin
      LReply := 'HTTP/1.1 599 Poisoned'#13#10 +
                'Content-Length: 6'#13#10 +
                #13#10 +
                'poison';
      LConn.Write(LReply[1], SizeUInt(Length(LReply)));
    end;
  except
  end;
  LConn.Close;

  try
    LConn := GPoisonListener.Accept;
  except
    Exit;
  end;
  if LConn = nil then
    Exit;

  InterlockedIncrement(GPoisonAcceptCount);
  try
    ReadRetryRawRequest(LConn, LMethod, LBody);
    LReply := 'HTTP/1.1 200 OK'#13#10 +
              'Content-Length: 8'#13#10 +
              #13#10 +
              'fresh-ok';
    LConn.Write(LReply[1], SizeUInt(Length(LReply)));
  except
  end;
  LConn.Close;
end;

function SwitchingProtocolsPoolThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LReply: string;
  LMethod: string;
  LBody: string;
begin
  Result := nil;
  try
    LConn := GPoisonListener.Accept;
  except
    Exit;
  end;
  if LConn = nil then
    Exit;

  InterlockedIncrement(GPoisonAcceptCount);
  try
    ReadRetryRawRequest(LConn, LMethod, LBody);
    LReply := 'HTTP/1.1 101 Switching Protocols'#13#10 +
              'Upgrade: websocket'#13#10 +
              'Connection: Upgrade'#13#10 +
              #13#10;
    LConn.Write(LReply[1], SizeUInt(Length(LReply)));

    LMethod := '';
    LBody := '';
    ReadRetryRawRequest(LConn, LMethod, LBody);
    if LMethod <> '' then
    begin
      LReply := 'HTTP/1.1 599 Poisoned'#13#10 +
                'Content-Length: 6'#13#10 +
                'Connection: close'#13#10 +
                #13#10 +
                'poison';
      LConn.Write(LReply[1], SizeUInt(Length(LReply)));
    end;
  except
  end;
  LConn.Close;

  try
    LConn := GPoisonListener.Accept;
  except
    Exit;
  end;
  if LConn = nil then
    Exit;

  InterlockedIncrement(GPoisonAcceptCount);
  try
    ReadRetryRawRequest(LConn, LMethod, LBody);
    LReply := 'HTTP/1.1 200 OK'#13#10 +
              'Content-Length: 8'#13#10 +
              'Connection: close'#13#10 +
              #13#10 +
              'fresh-ok';
    LConn.Write(LReply[1], SizeUInt(Length(LReply)));
  except
  end;
  LConn.Close;
end;

function BodyLimitCaptureThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LAccum: string;
  LHeadersEnd: SizeInt;
  LExpectedBodyLen: Int64;
  LBodyStart: SizeInt;
  LReply: string;
begin
  Result := nil;
  try
    LConn := GBodyLimitListener.Accept;
  except
    Exit;
  end;
  if LConn = nil then
    Exit;

  try
    LAccum := '';
    LHeadersEnd := 0;
    repeat
      LN := LConn.Read(LBuf[0], SizeUInt(Length(LBuf)));
      if LN = 0 then
        Break;
      SetLength(LAccum, Length(LAccum) + Int32(LN));
      Move(LBuf[0], LAccum[Length(LAccum) - Int32(LN) + 1], LN);
      LHeadersEnd := Pos(#13#10#13#10, LAccum);
    until LHeadersEnd > 0;

    if LHeadersEnd > 0 then
    begin
      LExpectedBodyLen := RetryRequestContentLength(
        System.Copy(LAccum, 1, LHeadersEnd + 3));
      LBodyStart := LHeadersEnd + 4;
      while Int64(Length(LAccum) - LBodyStart + 1) < LExpectedBodyLen do
      begin
        LN := LConn.Read(LBuf[0], SizeUInt(Length(LBuf)));
        if LN = 0 then
          Break;
        SetLength(LAccum, Length(LAccum) + Int32(LN));
        Move(LBuf[0], LAccum[Length(LAccum) - Int32(LN) + 1], LN);
      end;

      GBodyLimitDeclaredBody := System.Copy(LAccum, LBodyStart,
        LExpectedBodyLen);
      GBodyLimitExtraBody := System.Copy(LAccum,
        LBodyStart + SizeInt(LExpectedBodyLen), MaxInt);

      if GBodyLimitExtraBody = '' then
      begin
        LConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(150)));
        try
          repeat
            LN := LConn.Read(LBuf[0], SizeUInt(Length(LBuf)));
            if LN = 0 then
              Break;
            SetLength(GBodyLimitExtraBody,
              Length(GBodyLimitExtraBody) + Int32(LN));
            Move(LBuf[0],
              GBodyLimitExtraBody[
                Length(GBodyLimitExtraBody) - Int32(LN) + 1],
              LN);
          until False;
        except
        end;
      end;
    end;

    if GBodyLimitReplyAfterRead then
    begin
      LReply := 'HTTP/1.1 200 OK'#13#10 +
                'Content-Length: 2'#13#10 +
                'Connection: close'#13#10 +
                #13#10 +
                'ok';
      LConn.Write(LReply[1], SizeUInt(Length(LReply)));
    end;
  except
  end;
  LConn.Close;
end;

function TimeoutReuseAcceptThread(AArg: Pointer): Pointer; cdecl; forward;
function RequestWriteFailureThread(AArg: Pointer): Pointer; cdecl; forward;

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

constructor TRedirectCaptureTransport.Create;
begin
  inherited Create;
end;

constructor TRedirectCaptureTransport.Create(const ATrackedBody: TTrackedRequestBody);
begin
  Create;
  FTrackedBody := ATrackedBody;
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
    LHeaders.SetHeader('location', LLocation);
    LHeaders.SetHeader('content-length', '0');
    LStatus := FRedirectStatus;
    if LStatus = 0 then
      LStatus := HTTP_STATUS_FOUND;
    Exit(NewResponse(LStatus, LHeaders, nil));
  end;

  FOriginalBodyClosedBeforeFollowup := (FTrackedBody <> nil) and
    FTrackedBody.Closed;
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
  FSeenProxyAuthorizationHeader := AReq.Headers.Get('proxy-authorization');
  FSeenWwwAuthenticateHeader := AReq.Headers.Get('www-authenticate');
  FSeenCookieHeader := AReq.Headers.Get('cookie');
  FSeenCookie2Header := AReq.Headers.Get('cookie2');
  LHeaders.SetHeader('content-length', '7');
  Result := NewResponse(HTTP_STATUS_OK, LHeaders, StringBodyReader('arrived'));
end;

function TNilResponseTransport.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
begin
  Result := nil;
end;

function TNilHeadersRedirectTransport.RoundTrip(
  const AReq: IHttpRequest): IHttpResponse;
begin
  Result := TNilHeadersRedirectResponse.Create as IHttpResponse;
end;

constructor TNilHeadersRequest.Create(const AUrl: string);
begin
  inherited Create;
  FUrl := TUrl.Parse(AUrl);
end;

function TNilHeadersRequest.GetMethod: THttpMethod;
begin
  Result := hmGet;
end;

function TNilHeadersRequest.GetUrl: TUrl;
begin
  Result := FUrl;
end;

function TNilHeadersRequest.GetPath: string;
begin
  Result := FUrl.Path;
end;

function TNilHeadersRequest.GetRawQuery: string;
begin
  Result := FUrl.RawQuery;
end;

function TNilHeadersRequest.GetVersion: THttpVersion;
begin
  Result := hvHttp11;
end;

function TNilHeadersRequest.GetHeaders: IHttpHeaders;
begin
  Result := nil;
end;

function TNilHeadersRequest.GetTrailers: IHttpHeaders;
begin
  Result := nil;
end;

function TNilHeadersRequest.GetBody: IReader;
begin
  Result := nil;
end;

function TNilHeadersRequest.GetContentLength: Int64;
begin
  Result := 0;
end;

function TNilHeadersRequest.GetRemoteIp: string;
begin
  Result := GetRemoteAddr;
end;

function TNilHeadersRequest.GetRemoteAddr: string;
begin
  Result := '';
end;

function TNilHeadersRequest.PathParam(const AName: string): string;
begin
  Result := '';
end;

function TNilHeadersRequest.QueryParam(const AName: string): string;
begin
  Result := '';
end;

function TUrlCaptureTransport.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
var
  LHeaders: IHttpHeaders;
  LUrl: TUrl;
begin
  Inc(FCalls);
  LUrl := AReq.Url;
  FSeenScheme := LUrl.Scheme;
  FSeenHost := LUrl.Host;
  FSeenPath := AReq.Path;

  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-length', '0');
  Result := NewResponse(HTTP_STATUS_OK, LHeaders, nil);
end;

function TNilHeadersRedirectResponse.GetStatusCode: THttpStatus;
begin
  Result := HTTP_STATUS_FOUND;
end;

function TNilHeadersRedirectResponse.GetHeaders: IHttpHeaders;
begin
  Result := nil;
end;

function TNilHeadersRedirectResponse.GetBody: IReader;
begin
  Result := nil;
end;

function TNilHeadersRedirectResponse.GetFinalUrl: string;
begin
  Result := '';
end;

function TNilHeadersRedirectResponse.GetVersion: THttpVersion;
begin
  Result := hvHttp11;
end;

procedure TNilHeadersRedirectResponse.Close;
begin
end;

constructor TCustomWireHeader.Create(const AName, AValue: string);
begin
  inherited Create;
  FName := AName;
  FValue := AValue;
end;

procedure TCustomWireHeader.SetHeader(const AName, AValue: string);
begin
  FName := AName;
  FValue := AValue;
end;

procedure TCustomWireHeader.Add(const AName, AValue: string);
begin
  FName := AName;
  FValue := AValue;
end;

function TCustomWireHeader.Get(const AName: string): string;
begin
  if LowerCase(AName) = LowerCase(FName) then
    Result := FValue
  else
    Result := '';
end;

function TCustomWireHeader.GetAll(const AName: string): TStringArray;
begin
  if LowerCase(AName) <> LowerCase(FName) then
    Exit(nil);
  SetLength(Result, 1);
  Result[0] := FValue;
end;

function TCustomWireHeader.Has(const AName: string): Boolean;
begin
  Result := LowerCase(AName) = LowerCase(FName);
end;

procedure TCustomWireHeader.Remove(const AName: string);
begin
  if LowerCase(AName) = LowerCase(FName) then
    Clear;
end;

procedure TCustomWireHeader.Clear;
begin
  FName := '';
  FValue := '';
end;

function TCustomWireHeader.Count: Int32;
begin
  if FName = '' then
    Result := 0
  else
    Result := 1;
end;

procedure TCustomWireHeader.ForEach(const ACallback: THeaderIterator);
begin
  if FName <> '' then
    ACallback(FName, FValue);
end;

function TCustomWireHeader.Clone: IHttpHeaders;
begin
  Result := TCustomWireHeader.Create(FName, FValue) as IHttpHeaders;
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

constructor TCloseFailingResponseBody.Create(const AData: string);
begin
  inherited Create;
  FData := AData;
  FPos := 1;
end;

function TCloseFailingResponseBody.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
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

procedure TCloseFailingResponseBody.Close;
begin
  FClosed := True;
  Inc(FCloseCount);
  raise EHttpError.Create('response body close failed');
end;

function TReadAndCloseFailingResponseBody.Read(var ABuf;
  const ACount: SizeUInt): SizeUInt;
begin
  Result := 0;
  raise EIOError.Create('response body read failed');
end;

procedure TReadAndCloseFailingResponseBody.Close;
begin
  FClosed := True;
  Inc(FCloseCount);
  raise EHttpError.Create('response body close failed');
end;

function TReadAndCloseFailingRequestBody.Read(var ABuf;
  const ACount: SizeUInt): SizeUInt;
begin
  Result := 0;
  raise EIOError.Create('request body read failed');
end;

procedure TReadAndCloseFailingRequestBody.Close;
begin
  FClosed := True;
  Inc(FCloseCount);
  raise EHttpError.Create('request body close failed');
end;

constructor TPartialReadFailingRequestBody.Create(const AData: string);
begin
  inherited Create;
  FData := AData;
  FPos := 1;
end;

function TPartialReadFailingRequestBody.Read(var ABuf;
  const ACount: SizeUInt): SizeUInt;
var
  LRemaining: SizeInt;
begin
  if FClosed or (ACount = 0) then
    Exit(0);
  if FPos > Length(FData) then
    raise EIOError.Create('request body read failed');

  LRemaining := Length(FData) - FPos + 1;
  if SizeUInt(LRemaining) > ACount then
    Result := ACount
  else
    Result := SizeUInt(LRemaining);
  Move(FData[FPos], ABuf, Result);
  Inc(FPos, SizeInt(Result));
end;

procedure TPartialReadFailingRequestBody.Close;
begin
  FClosed := True;
  Inc(FCloseCount);
end;

constructor TTrackedRequestBody.Create(const AData: string;
  const ARaiseOnClose: Boolean);
begin
  inherited Create;
  FData := AData;
  FPos := 1;
  FClosed := False;
  FCloseCount := 0;
  FRaiseOnClose := ARaiseOnClose;
end;

function TTrackedRequestBody.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
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

procedure TTrackedRequestBody.Close;
begin
  FClosed := True;
  Inc(FCloseCount);
  if FRaiseOnClose then
    raise EHttpError.Create('request body close failed');
end;

constructor TRequestBodyCaptureTransport.Create(
  const ATrackedBody: TTrackedRequestBody; const ARaiseAfterRead: Boolean;
  const AResponseBody: IReader);
begin
  inherited Create;
  FTrackedBody := ATrackedBody;
  FRaiseAfterRead := ARaiseAfterRead;
  FResponseBody := AResponseBody;
end;

function TRequestBodyCaptureTransport.RoundTrip(
  const AReq: IHttpRequest): IHttpResponse;
var
  LHeaders: IHttpHeaders;
begin
  FSeenMethod := AReq.Method;
  FSeenContentLength := AReq.ContentLength;
  FSeenContentTypeHeader := (AReq.Headers <> nil) and
    AReq.Headers.Has('content-type');
  if AReq.Headers <> nil then
    FSeenContentType := AReq.Headers.Get('content-type')
  else
    FSeenContentType := '';
  FTrackedBodyClosedAtEntry := (FTrackedBody <> nil) and FTrackedBody.Closed;
  FSeenBody := ReadReaderStr(AReq.Body);
  FTrackedBodyClosedBeforeReturn := (FTrackedBody <> nil) and FTrackedBody.Closed;
  if FRaiseAfterRead then
    raise EHttpError.Create('request body transport failed');

  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-length', '0');
  Result := NewResponse(HTTP_STATUS_OK, LHeaders, FResponseBody);
end;

{ TTimeoutCaptureTransport }

constructor TTimeoutCaptureTransport.Create(const ADefaultTimeoutMs: Int64);
begin
  inherited Create;
  FDefaultTimeoutMs := ADefaultTimeoutMs;
  FCapturedTimeoutMs := -1;
end;

function TTimeoutCaptureTransport.RoundTrip(
  const AReq: IHttpRequest): IHttpResponse;
var
  LHeaders: IHttpHeaders;
  LReqOpts: IHttpRequestWithOptions;
begin
  // Capture the timeout that would be used (same logic as TH1ClientTransport)
  FCapturedTimeoutMs := FDefaultTimeoutMs;
  if Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
    FCapturedTimeoutMs := LReqOpts.RequestOptions.EffectiveTimeout(FDefaultTimeoutMs);

  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-length', '0');
  Result := NewResponse(HTTP_STATUS_OK, LHeaders, nil);
end;

{ TRetryTestTransport }

constructor TRetryTestTransport.Create(const AFailCount: Int32;
  const AFailStatus: THttpStatus);
begin
  inherited Create;
  FFailCount := AFailCount;
  FFailStatus := AFailStatus;
  FCalls := 0;
  FRaiseKind := hekUnknown;
  FRaiseOnFail := False;
  FRetryAfter := '';
  FFailBody := '';
end;

constructor TRetryTestTransport.CreateRaising(const AFailCount: Int32;
  const ARaiseKind: THttpErrorKind);
begin
  inherited Create;
  FFailCount := AFailCount;
  FFailStatus := HTTP_STATUS_OK;
  FCalls := 0;
  FRaiseKind := ARaiseKind;
  FRaiseOnFail := True;
  FRetryAfter := '';
  FFailBody := '';
end;

function TRetryTestTransport.RoundTrip(
  const AReq: IHttpRequest): IHttpResponse;
var
  LHeaders: IHttpHeaders;
  LBody: IReader;
begin
  Inc(FCalls);
  if FRaiseOnFail and (FCalls <= FFailCount) then
    raise EHttpError.Create(FRaiseKind, 'retry transport fail kind');
  LHeaders := NewHttpHeaders;
  if FCalls <= FFailCount then
  begin
    if FRetryAfter <> '' then
      LHeaders.SetHeader('retry-after', FRetryAfter);
    if FFailBody <> '' then
    begin
      LHeaders.SetHeader('content-length', IntToStr(Length(FFailBody)));
      LBody := StringBodyReader(FFailBody);
      Result := NewResponse(FFailStatus, LHeaders, LBody);
    end
    else
    begin
      LHeaders.SetHeader('content-length', '0');
      Result := NewResponse(FFailStatus, LHeaders, nil);
    end;
  end
  else
  begin
    LHeaders.SetHeader('content-length', '0');
    Result := NewResponse(HTTP_STATUS_OK, LHeaders, nil);
  end;
end;

constructor TJsonBodyTransport.Create(const AStatus: THttpStatus;
  const ABody: string);
begin
  inherited Create;
  FStatus := AStatus;
  FBody := ABody;
end;

function TJsonBodyTransport.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
var
  LHeaders: IHttpHeaders;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-type', 'application/json');
  LHeaders.SetHeader('content-length', IntToStr(Length(FBody)));
  if FBody <> '' then
    Result := NewResponse(FStatus, LHeaders, StringBodyReader(FBody))
  else
    Result := NewResponse(FStatus, LHeaders, nil);
end;

constructor TRedirectBodyReleaseTransport.Create;
begin
  inherited Create;
  FRedirectLocation := '/final';
  FOmitLocation := False;
  FTrackedBody := TRedirectTrackedBody.Create('redirect-body');
  FBody := FTrackedBody as IReadCloser;
  FBodyRef := FBody;
end;

function TRedirectBodyReleaseTransport.GetBodyClosed: Boolean;
begin
  if FFailBodyClose then
    Result := (FCloseFailingBody <> nil) and FCloseFailingBody.Closed
  else
    Result := (FTrackedBody <> nil) and FTrackedBody.Closed;
end;

function TRedirectBodyReleaseTransport.GetBodyCloseCount: Int32;
begin
  if FFailBodyClose then
  begin
    if FCloseFailingBody <> nil then
      Exit(FCloseFailingBody.CloseCount);
    Exit(0);
  end;
  if FTrackedBody <> nil then
  begin
    if FTrackedBody.Closed then
      Exit(1);
    Exit(0);
  end;
  Result := 0;
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
    begin
      if FDuplicateLocation then
      begin
        LHeaders.Add('location', FRedirectLocation);
        LHeaders.Add('location', '/alternate');
      end
      else
        LHeaders.SetHeader('location', FRedirectLocation);
    end;
    LHeaders.SetHeader('content-length', '13');
    if FFailBodyClose then
    begin
      FCloseFailingBody := TCloseFailingResponseBody.Create('redirect-body');
      FBodyRef := FCloseFailingBody as IReadCloser;
    end;
    Exit(NewResponse(HTTP_STATUS_FOUND, LHeaders, FBodyRef as IReader));
  end;

  FBodyClosedBeforeFollowup := GetBodyClosed;
  LHeaders.SetHeader('content-length', '7');
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
    LHeaders.SetHeader('location', '/final');
    LHeaders.SetHeader('content-length', '13');
    Exit(NewResponse(HTTP_STATUS_FOUND, LHeaders, FBodyRef));
  end;

  FBodyDrainedBeforeFollowup := FBody.Drained;
  LHeaders.SetHeader('content-length', '7');
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

function TDownloadClient.Send(const AReq: IHttpRequest): IHttpResponse;
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

function TDownloadClient.GetString(const AUrl: string): string;
begin
  Result := HttpGetString(Self, AUrl);
end;

function TDownloadClient.GetBytes(const AUrl: string): TBytes;
begin
  Result := HttpGetBytes(Self, AUrl);
end;

function TDownloadClient.GetJson(const AUrl: string): IJsonDocument;
begin
  Result := HttpGetJson(Self, AUrl);
end;

function TDownloadClient.PostString(const AUrl, AContentType, ABody: string): string;
begin
  Result := HttpPostString(Self, AUrl, AContentType, ABody);
end;

function TDownloadClient.PutString(const AUrl, AContentType, ABody: string): string;
begin
  Result := HttpPutString(Self, AUrl, AContentType, ABody);
end;

function TDownloadClient.PatchString(const AUrl, AContentType, ABody: string): string;
begin
  Result := HttpPatchString(Self, AUrl, AContentType, ABody);
end;

function TDownloadClient.DeleteString(const AUrl: string): string;
begin
  Result := HttpDeleteString(Self, AUrl);
end;

function TDownloadClient.Post(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
begin
  Result := FResponse;
end;

function TDownloadClient.Post(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
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

function TDownloadClient.Delete(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
begin
  Result := FResponse;
end;

function TDownloadClient.Delete(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
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

function TDownloadClient.Options(const AUrl: string): IHttpResponse;
begin
  Result := FResponse;
end;

function TDownloadClient.PostForm(const AUrl: string;
  const AFields: TFormFieldArray): IHttpResponse;
begin
  Result := FResponse;
end;

function TDownloadClient.PostMultipart(const AUrl: string;
  const AFields: TFormFieldArray; const AFiles: THttpFileArray): IHttpResponse;
begin
  Result := FResponse;
end;

function TDownloadClient.PostJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := FResponse;
end;

function TDownloadClient.PutJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := FResponse;
end;

function TDownloadClient.PatchJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := FResponse;
end;

function TDownloadClient.DeleteJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := FResponse;
end;

function TDownloadClient.SendStreaming(const AMethod: THttpMethod;
  const AUrl: string; const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpResponse;
begin
  FSeenUrl := AUrl;
  Result := FResponse;
end;

function TDownloadClient.WithBasicAuth(const AUsername, APassword: string): IHttpClient;
begin
  Result := Self;
end;

function TDownloadClient.WithBearerAuth(const AToken: string): IHttpClient;
begin
  Result := Self;
end;

function TDownloadClient.WithHeader(const AName, AValue: string): IHttpClient;
begin
  Result := Self;
end;

function TDownloadClient.WithTimeout(const ATimeoutMs: Int64): IHttpClient;
begin
  Result := Self;
end;

function TDownloadClient.WithConnectTimeout(const ATimeoutMs: Int64): IHttpClient;
begin
  Result := Self;
end;

function TDownloadClient.WithMaxRedirects(const AMaxRedirects: Int32): IHttpClient;
begin
  Result := Self;
end;

function TDownloadClient.WithFollowRedirects(const AFollow: Boolean): IHttpClient;
begin
  Result := Self;
end;

function TDownloadClient.WithRetry(const AMaxRetries: Int32): IHttpClient;
begin
  Result := Self;
end;

function TDownloadClient.WithCookieJar(const AJar: IHttpCookieJar): IHttpClient;
begin
  Result := Self;
end;

function TDownloadClient.WithProxyUrl(const AProxyUrl: string): IHttpClient;
begin
  Result := Self;
end;

function TDownloadClient.WithDialFunc(const ADial: THttpDialFunc): IHttpClient;
begin
  Result := Self;
end;

function TDownloadClient.WithTLSContext(const ATLSContext: ISSLContext): IHttpClient;
begin
  Result := Self;
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
procedure TestClientSendRejectsRedirectWithNilHeaders;
var
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LRaised: Boolean;
begin
  LTransport := TNilHeadersRedirectTransport.Create as IHttpTransport;
  LClient := NewHttpClient(LTransport);
  LReq := NewRequest(hmGet, 'http://example.test/');

  LRaised := False;
  try
    LClient.Send(LReq);
  except
    on E: EHttpError do
      LRaised := True;
  end;

  Check(LRaised, 'Client.Send rejects redirect response with nil headers');
end;

{ Test 2: Client GET with custom headers }
{ Test 3: Client POST with body }
// PLACEHOLDER_TEST4

function TestStringToBytes(const AValue: string): TBytes;
begin
  SetLength(Result, Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[1], Result[0], Length(AValue));
end;

procedure CheckShortcutOmitsEmptyContentType(
  const ALabel: string; const ATransport: TRequestBodyCaptureTransport;
  const AExpectedMethod: THttpMethod; const AExpectedBody: string);
begin
  CheckEqual(Int64(Ord(AExpectedMethod)), Int64(Ord(ATransport.SeenMethod)),
    ALabel + ' method');
  Check(not ATransport.SeenContentTypeHeader,
    ALabel + ' does not publish empty content-type header');
  CheckEqual('', ATransport.SeenContentType,
    ALabel + ' exposes no content-type value');
  CheckEqual(Int64(Length(AExpectedBody)), ATransport.SeenContentLength,
    ALabel + ' content-length');
  CheckEqual(AExpectedBody, ATransport.SeenBody,
    ALabel + ' body');
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
  LBase: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/old', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AW.GetHeaders.SetHeader('location', '/new');
    AW.GetHeaders.SetHeader('content-length', '0');
    AW.WriteHeader(THttpStatus(301));
  end);
  LRouter.Get('/new', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LB: string;
  begin
    LB := 'arrived';
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LB))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], SizeUInt(Length(LB)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LBase := 'http://127.0.0.1:' + IntToStr(Int64(LPort));
    LResp := LClient.Get(LBase + '/old');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'followed redirect to 200');
    LBody := ReadBodyStr(LResp);
    CheckEqual('arrived', LBody, 'body from final destination');
    CheckEqual(LBase + '/new', LResp.FinalUrl,
      'FinalUrl is the post-redirect request URL');
    CheckEqual(Int64(Ord(hvHttp11)), Int64(Ord(LResp.Version)),
      'H1 live redirect response version is HTTP/1.1');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientClosesOriginalBodyBeforeGetStyleRedirectFollowup;
var
  LBody: TTrackedRequestBody;
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
begin
  LBody := TTrackedRequestBody.Create('payload');
  LTransportObj := TRedirectCaptureTransport.Create(LBody);
  LTransportObj.RedirectStatus := HTTP_STATUS_SEE_OTHER;
  LTransportObj.RedirectLocation := '/done';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LReq := THttpRequestBuilder.Create(hmPost, 'http://example.test/upload').Headers(NewHeaders).Body(LBody as IReader).ContentLength(Int64(7)).Build;

  LResp := LClient.Send(LReq);

  CheckEqual(Int64(2), Int64(LTransportObj.Calls),
    'get-style redirect performs follow-up round trip');
  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'get-style redirect final status');
  Check(LTransportObj.OriginalBodyClosedBeforeFollowup,
    'get-style redirect closes original request body before follow-up');
  Check(LBody.Closed,
    'get-style redirect leaves original request body closed after Send');
  CheckEqual(Int64(1), Int64(LBody.CloseCount),
    'get-style redirect closes original request body exactly once');
end;

procedure TestClientDoesNotRetryCloseWhenGetStyleRedirectBodyCloseFails;
var
  LBody: TTrackedRequestBody;
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LRaised: Boolean;
begin
  LBody := TTrackedRequestBody.Create('payload', True);
  LTransportObj := TRedirectCaptureTransport.Create(LBody);
  LTransportObj.RedirectStatus := HTTP_STATUS_SEE_OTHER;
  LTransportObj.RedirectLocation := '/done';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LReq := THttpRequestBuilder.Create(hmPost, 'http://example.test/upload').Headers(NewHeaders).Body(LBody as IReader).ContentLength(Int64(7)).Build;

  LRaised := False;
  try
    LClient.Send(LReq);
  except
    on E: EHttpError do
      LRaised := True;
  end;

  Check(LRaised,
    'get-style redirect propagates original request body close failure');
  CheckEqual(Int64(1), Int64(LBody.CloseCount),
    'get-style redirect failed close is not retried by Send finally');
  CheckEqual(Int64(1), Int64(LTransportObj.Calls),
    'get-style redirect does not issue follow-up after body close failure');
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
    AW.GetHeaders.SetHeader('location', '/complete');
    AW.GetHeaders.SetHeader('content-length', '0');
    AW.WriteHeader(HTTP_STATUS_SEE_OTHER);
  end);
  LRouter.Get('/complete', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LB: string;
  begin
    LGotFinalMethod := AReq.Method;
    LGotFinalBody := ReadReaderStr(AReq.Body);
    LB := 'done';
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LB))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], SizeUInt(Length(LB)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Post('http://127.0.0.1:' + IntToStr(Int64(LPort)) +
      '/submit', 'text/plain', 'payload');
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
    AW.GetHeaders.SetHeader('location', '/new?from=redirect');
    AW.GetHeaders.SetHeader('content-length', '0');
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
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LB))));
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

procedure TestClientPreservesHeadOnGetStyleRedirects;
var
  LStatuses: array[0..2] of THttpStatus;
  LI: SizeInt;
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LReq: IHttpRequest;
begin
  LStatuses[0] := HTTP_STATUS_MOVED_PERMANENTLY;
  LStatuses[1] := HTTP_STATUS_FOUND;
  LStatuses[2] := HTTP_STATUS_SEE_OTHER;

  for LI := Low(LStatuses) to High(LStatuses) do
  begin
    LTransportObj := TRedirectCaptureTransport.Create;
    LTransportObj.RedirectStatus := LStatuses[LI];
    LTransport := LTransportObj;
    LClient := NewHttpClient(LTransport);
    LReq := THttpRequestBuilder.Create(hmHead, 'http://example.test/old').Headers(NewHeaders).Build;
    LResp := LClient.Send(LReq);
    CheckEqual(Int64(2), Int64(LTransportObj.Calls),
      'HEAD redirect performs second round trip');
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'HEAD redirect reaches final response');
    Check(LTransportObj.SeenMethod = hmHead,
      '301/302/303 redirect preserves HEAD method');
    CheckEqual('', LTransportObj.SecondBody,
      'HEAD redirect follow-up has no request body');
    CheckEqual('arrived', ReadBodyStr(LResp), 'HEAD redirect final body');
  end;
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

procedure TestClientRedirectRejectsAbsoluteLocationWithEmptyHost;
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LRaised: Boolean;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransportObj.RedirectLocation := 'http:///final';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LRaised := False;
  try
    LClient.Get('http://example.test/old');
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, 'absolute redirect with empty host raises EHttpError');
  CheckEqual(Int64(1), Int64(LTransportObj.Calls),
    'absolute redirect with empty host does not perform second round trip');
end;

procedure TestClientRedirectRejectsAbsoluteLocationWithInvalidPort;
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LRaised: Boolean;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransportObj.RedirectLocation := 'http://redirect.test:bad/new';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LRaised := False;
  try
    LClient.Get('http://example.test/old');
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, 'absolute redirect with invalid port raises EHttpError');
  CheckEqual(Int64(1), Int64(LTransportObj.Calls),
    'absolute redirect with invalid port does not perform second round trip');
end;

procedure TestClientRedirectRejectsNetworkPathLocationWithEmptyHost;
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LRaised: Boolean;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransportObj.RedirectLocation := '///final';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LRaised := False;
  try
    LClient.Get('http://example.test/old');
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, 'network-path redirect with empty host raises EHttpError');
  CheckEqual(Int64(1), Int64(LTransportObj.Calls),
    'network-path redirect with empty host does not perform second round trip');
end;

procedure TestClientRedirectRejectsNetworkPathLocationWithInvalidPort;
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LRaised: Boolean;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransportObj.RedirectLocation := '//redirect.test:bad/new';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LRaised := False;
  try
    LClient.Get('http://example.test/old');
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, 'network-path redirect with invalid port raises EHttpError');
  CheckEqual(Int64(1), Int64(LTransportObj.Calls),
    'network-path redirect with invalid port does not perform second round trip');
end;

procedure CheckClientRedirectRejectsMalformedBracketedAuthority(
  const ALocation, ALabel: string);
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LRaised: Boolean;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransportObj.RedirectLocation := ALocation;
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LRaised := False;
  try
    LClient.Get('http://example.test/old');
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised, ALabel + ' raises EHttpError');
  CheckEqual(Int64(1), Int64(LTransportObj.Calls),
    ALabel + ' does not perform second round trip');
end;

procedure TestClientRedirectRejectsMalformedBracketedIpv6Authority;
begin
  CheckClientRedirectRejectsMalformedBracketedAuthority(
    'http://[::1]evil/new',
    'absolute redirect with malformed bracketed IPv6 authority');
  CheckClientRedirectRejectsMalformedBracketedAuthority(
    '//[::1]evil/new',
    'network-path redirect with malformed bracketed IPv6 authority');
end;

procedure TestClientRedirectTransportResolvesUserInfoLocationWithPort;
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransportObj.RedirectLocation := 'http://user:pass@redirect.test:80/new?from=userinfo';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LResp := LClient.Get('http://example.test/old');
  CheckEqual(Int64(2), Int64(LTransportObj.Calls),
    'userinfo absolute redirect with numeric port performs second round trip');
  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'userinfo absolute redirect transport final status');
  CheckEqual('redirect.test', LTransportObj.SeenHost,
    'userinfo absolute redirect keeps host separate from credentials');
  CheckEqual('/new', LTransportObj.SeenPath,
    'userinfo absolute redirect updates path');
  CheckEqual('userinfo', LTransportObj.SeenQueryParam,
    'userinfo absolute redirect query param is visible');
  CheckEqual('arrived', ReadBodyStr(LResp),
    'userinfo absolute redirect final body');
end;

procedure TestClientRedirectRejectsUnsupportedNonHierarchicalScheme;
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LRaised: Boolean;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransportObj.RedirectLocation := 'mailto:ops@example.test';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LRaised := False;
  try
    LClient.Get('http://example.test/old');
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised,
    'absolute redirect with non-hierarchical unsupported scheme raises EHttpError');
  CheckEqual(Int64(1), Int64(LTransportObj.Calls),
    'unsupported non-hierarchical redirect scheme does not perform second round trip');
end;

procedure TestClientRedirectRejectsUnsupportedSingleSlashScheme;
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LRaised: Boolean;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransportObj.RedirectLocation := 'ftp:/redirect.test/new';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LRaised := False;
  try
    LClient.Get('http://example.test/old');
  except
    on E: EHttpError do
      LRaised := True;
  end;
  Check(LRaised,
    'absolute redirect with single-slash unsupported scheme raises EHttpError');
  CheckEqual(Int64(1), Int64(LTransportObj.Calls),
    'unsupported single-slash redirect scheme does not perform second round trip');
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
  LHeaders.SetHeader('x-trace', 'trace-1');
  LHeaders.SetHeader('authorization', 'Bearer same-host');
  LHeaders.SetHeader('proxy-authorization', 'Basic same-proxy');
  LHeaders.SetHeader('www-authenticate', 'Basic realm="api"');
  LHeaders.SetHeader('cookie', 'session=abc');
  LHeaders.SetHeader('cookie2', 'legacy=1');
  LReq := THttpRequestBuilder.Create(hmGet, 'http://example.test/old').Headers(LHeaders).Build;
  LResp := LClient.Send(LReq);
  CheckEqual(Int64(2), Int64(LTransportObj.Calls),
    'same-authority redirect performs second round trip');
  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'same-authority redirect transport final status');
  CheckEqual('trace-1', LTransportObj.SeenTraceHeader,
    'same-authority redirect preserves ordinary header');
  CheckEqual('Bearer same-host', LTransportObj.SeenAuthorizationHeader,
    'same-authority redirect preserves authorization header');
  CheckEqual('Basic same-proxy', LTransportObj.SeenProxyAuthorizationHeader,
    'same-authority redirect preserves proxy-authorization header');
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
  LHeaders.SetHeader('x-trace', 'trace-2');
  LHeaders.SetHeader('authorization', 'Bearer cross-host');
  LHeaders.SetHeader('proxy-authorization', 'Basic cross-proxy');
  LHeaders.SetHeader('www-authenticate', 'Basic realm="api"');
  LHeaders.SetHeader('cookie', 'session=def');
  LHeaders.SetHeader('cookie2', 'legacy=2');
  LReq := THttpRequestBuilder.Create(hmGet, 'http://example.test/old').Headers(LHeaders).Build;
  LResp := LClient.Send(LReq);
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
  CheckEqual('', LTransportObj.SeenProxyAuthorizationHeader,
    'cross-authority redirect strips proxy-authorization header');
  CheckEqual('', LTransportObj.SeenWwwAuthenticateHeader,
    'cross-authority redirect strips www-authenticate header');
  CheckEqual('', LTransportObj.SeenCookieHeader,
    'cross-authority redirect strips cookie header');
  CheckEqual('', LTransportObj.SeenCookie2Header,
    'cross-authority redirect strips cookie2 header');
  CheckEqual('arrived', ReadBodyStr(LResp), 'cross-authority redirect final body');
end;

procedure TestClientRedirectStripsSensitiveHeadersAcrossScheme;
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LReq: IHttpRequest;
  LHeaders: IHttpHeaders;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransportObj.RedirectLocation := 'https://example.test/secure';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LHeaders := NewHeaders;
  LHeaders.SetHeader('x-trace', 'trace-scheme');
  LHeaders.SetHeader('authorization', 'Bearer scheme-change');
  LHeaders.SetHeader('proxy-authorization', 'Basic scheme-proxy');
  LHeaders.SetHeader('www-authenticate', 'Basic realm="api"');
  LHeaders.SetHeader('cookie', 'session=scheme');
  LHeaders.SetHeader('cookie2', 'legacy=scheme');
  LReq := THttpRequestBuilder.Create(hmGet, 'http://example.test:443/old').Headers(LHeaders).Build;
  LResp := LClient.Send(LReq);
  CheckEqual(Int64(2), Int64(LTransportObj.Calls),
    'scheme-change redirect performs second round trip');
  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'scheme-change redirect transport final status');
  CheckEqual('https', LTransportObj.SeenScheme,
    'scheme-change redirect updates scheme');
  CheckEqual('example.test', LTransportObj.SeenHost,
    'scheme-change redirect keeps host');
  CheckEqual('trace-scheme', LTransportObj.SeenTraceHeader,
    'scheme-change redirect preserves ordinary header');
  CheckEqual('', LTransportObj.SeenAuthorizationHeader,
    'scheme-change redirect strips authorization header');
  CheckEqual('', LTransportObj.SeenProxyAuthorizationHeader,
    'scheme-change redirect strips proxy-authorization header');
  CheckEqual('', LTransportObj.SeenWwwAuthenticateHeader,
    'scheme-change redirect strips www-authenticate header');
  CheckEqual('', LTransportObj.SeenCookieHeader,
    'scheme-change redirect strips cookie header');
  CheckEqual('', LTransportObj.SeenCookie2Header,
    'scheme-change redirect strips cookie2 header');
  CheckEqual('arrived', ReadBodyStr(LResp),
    'scheme-change redirect final body');
end;

procedure TestClientRedirectStripsSensitiveHeadersToSubdomainAuthority;
var
  LTransportObj: TRedirectCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LReq: IHttpRequest;
  LHeaders: IHttpHeaders;
begin
  LTransportObj := TRedirectCaptureTransport.Create;
  LTransportObj.RedirectLocation := '//api.example.test/next';
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LHeaders := NewHeaders;
  LHeaders.SetHeader('x-trace', 'trace-subdomain');
  LHeaders.SetHeader('authorization', 'Bearer subdomain');
  LHeaders.SetHeader('proxy-authorization', 'Basic subdomain-proxy');
  LHeaders.SetHeader('www-authenticate', 'Basic realm="api"');
  LHeaders.SetHeader('cookie', 'session=sub');
  LHeaders.SetHeader('cookie2', 'legacy=sub');
  LReq := THttpRequestBuilder.Create(hmGet, 'http://example.test/old').Headers(LHeaders).Build;
  LResp := LClient.Send(LReq);
  CheckEqual(Int64(2), Int64(LTransportObj.Calls),
    'subdomain redirect performs second round trip');
  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'subdomain redirect transport final status');
  CheckEqual('api.example.test', LTransportObj.SeenHost,
    'subdomain redirect updates host');
  CheckEqual('trace-subdomain', LTransportObj.SeenTraceHeader,
    'subdomain redirect preserves ordinary header');
  CheckEqual('', LTransportObj.SeenAuthorizationHeader,
    'subdomain redirect strips authorization header');
  CheckEqual('', LTransportObj.SeenProxyAuthorizationHeader,
    'subdomain redirect strips proxy-authorization header');
  CheckEqual('', LTransportObj.SeenWwwAuthenticateHeader,
    'subdomain redirect strips www-authenticate header');
  CheckEqual('', LTransportObj.SeenCookieHeader,
    'subdomain redirect strips cookie header');
  CheckEqual('', LTransportObj.SeenCookie2Header,
    'subdomain redirect strips cookie2 header');
  CheckEqual('arrived', ReadBodyStr(LResp), 'subdomain redirect final body');
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
  LHeaders.SetHeader('host', 'override.test');
  LReq := THttpRequestBuilder.Create(hmGet, 'http://example.test/old').Headers(LHeaders).Build;
  LResp := LClient.Send(LReq);
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
  LHeaders.SetHeader('host', 'override.test');
  LReq := THttpRequestBuilder.Create(hmGet, 'http://example.test/old').Headers(LHeaders).Build;
  LResp := LClient.Send(LReq);
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

procedure TestClientClosesRedirectResponseBodyOnDuplicateLocation;
var
  LTransportObj: TRedirectBodyReleaseTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LRaised: Boolean;
begin
  LTransportObj := TRedirectBodyReleaseTransport.Create;
  LTransportObj.DuplicateLocation := True;
  LTransport := LTransportObj as IHttpTransport;
  LClient := NewHttpClient(LTransport);

  LRaised := False;
  try
    LClient.Get('http://example.test/old');
  except
    on E: EHttpError do
      LRaised := Pos('redirect with duplicate Location headers', E.Message) > 0;
  end;

  Check(LRaised, 'duplicate redirect Location raises EHttpError');
  CheckEqual(Int64(1), Int64(LTransportObj.Calls),
    'duplicate redirect Location stops before follow-up round trip');
  Check(LTransportObj.BodyClosed,
    'duplicate redirect Location closes discarded redirect response body');
end;

procedure TestClientRedirectPolicyErrorKeepsPrimaryErrorWhenBodyCloseFails;
var
  LTransportObj: TRedirectBodyReleaseTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LRaised: Boolean;
  LMessage: string;
begin
  LTransportObj := TRedirectBodyReleaseTransport.Create;
  LTransportObj.DuplicateLocation := True;
  LTransportObj.FailBodyClose := True;
  LTransport := LTransportObj as IHttpTransport;
  LClient := NewHttpClient(LTransport);

  LRaised := False;
  LMessage := '';
  try
    LClient.Get('http://example.test/old');
  except
    on E: EHttpError do
    begin
      LRaised := True;
      LMessage := E.Message;
    end;
  end;

  Check(LRaised, 'redirect policy error raises EHttpError');
  Check(Pos('redirect with duplicate Location headers', LMessage) > 0,
    'redirect policy error is not masked by body close failure');
  CheckEqual(Int64(1), Int64(LTransportObj.Calls),
    'redirect policy error stops before follow-up round trip');
  CheckEqual(Int64(1), Int64(LTransportObj.BodyCloseCount),
    'redirect policy error still attempts discarded body close once');
  Check(LTransportObj.BodyClosed,
    'redirect policy error marks close-failing discarded body closed');
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
  LReq := THttpRequestBuilder.Create(hmPost, 'http://example.test/upload').Headers(NewHeaders).Body(StringBodyReader('payload')).ContentLength(Int64(7)).Build;
  LResp := LClient.Send(LReq);
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
  LReq := THttpRequestBuilder.Create(hmPost, 'http://example.test/upload').Headers(NewHeaders).Body(TOneShotReader.Create('payload') as IReader).ContentLength(Int64(7)).Build;
  LRaised := False;
  try
    LClient.Send(LReq);
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
    AW.GetHeaders.SetHeader('location', '/loop');
    AW.GetHeaders.SetHeader('content-length', '0');
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

{ Test 6: Client timeout on slow server }
{ Test 7: Client handles 404 response }
{ Test 8: Client sets Host header automatically }
procedure CheckClientRejectsUnsupportedDirectScheme(const AScheme: string);
var
  LClient: IHttpClient;
  LRaised: Boolean;
  LUnsupportedScheme: Boolean;
begin
  LClient := NewHttpClient;
  LRaised := False;
  LUnsupportedScheme := False;
  try
    LClient.Get(AScheme + '://127.0.0.1:1/not-http');
  except
    on E: EHttpError do
    begin
      LRaised := True;
      LUnsupportedScheme := Pos('unsupported', LowerCase(E.Message)) > 0;
    end;
    on E: Exception do
      LRaised := True;
  end;

  Check(LRaised, AScheme + ' direct URL scheme raises');
  Check(LUnsupportedScheme,
    AScheme + ' direct URL scheme reports unsupported scheme');
end;

procedure CheckClientRejectsCustomWireHeader(const AHeaderName, AHeaderValue,
  AInjectedMarker, AContext: string);
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
  LRaised: Boolean;
  LRejectedHeader: Boolean;
begin
  GRawRequest1 := '';
  GRawRequest2 := '';
  GRawResponse1 := 'HTTP/1.1 200 OK'#13#10 +
                   'Content-Length: 2'#13#10 +
                   #13#10 +
                   'ok';
  GRawResponse2 := '';
  GRawAcceptLimit := 1;
  GRawAcceptCount := 0;
  GRawListener := NetTcpListen('127.0.0.1', 0);
  LPort := GRawListener.LocalAddr.Port;
  platform_thread_create(LHandle, @RawResponseThread, nil);
  LResp := nil;

  try
    LClient := NewHttpClient;
    LReq := THttpRequestBuilder.Create(hmGet, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/wire-header').Headers(TCustomWireHeader.Create(AHeaderName, AHeaderValue) as IHttpHeaders).Build;

    LRaised := False;
    LRejectedHeader := False;
    try
      LResp := LClient.Send(LReq);
    except
      on E: EHttpError do
      begin
        LRaised := True;
        LRejectedHeader := Pos('invalid header', E.Message) > 0;
      end;
    end;

    Check(LRaised, AContext + ': invalid custom header raises EHttpError');
    Check(LRejectedHeader,
      AContext + ': invalid custom header fails before response parsing');
    Check(Pos(AInjectedMarker, GRawRequest1) = 0,
      AContext + ': injected header is not written to the wire');
    if LResp <> nil then
      HttpReleaseResponseBody(LResp);
  finally
    GRawListener.Close;
    platform_thread_join(LHandle, LRet);
    GRawListener := nil;
    GRawRequest1 := '';
    GRawRequest2 := '';
    GRawResponse1 := '';
    GRawResponse2 := '';
    GRawAcceptLimit := 0;
    GRawAcceptCount := 0;
  end;
end;

procedure CheckClientRejectsRequestTargetBeforeWireWrite(const APath,
  ARawQuery, AInjectedMarker, AContext: string);
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
  LUrl: TUrl;
  LRaised: Boolean;
  LRejectedTarget: Boolean;
begin
  GRawRequest1 := '';
  GRawRequest2 := '';
  GRawResponse1 := 'HTTP/1.1 200 OK'#13#10 +
                   'Content-Length: 2'#13#10 +
                   #13#10 +
                   'ok';
  GRawResponse2 := '';
  GRawAcceptLimit := 1;
  GRawAcceptCount := 0;
  GRawListener := NetTcpListen('127.0.0.1', 0);
  LPort := GRawListener.LocalAddr.Port;
  platform_thread_create(LHandle, @RawResponseThread, nil);
  LResp := nil;

  try
    LUrl := Default(TUrl);
    LUrl.Scheme := 'http';
    LUrl.Host := '127.0.0.1';
    LUrl.Port := LPort;
    LUrl.Path := APath;
    LUrl.RawQuery := ARawQuery;

    LClient := NewHttpClient;
    LReq := NewRequest(hmGet, LUrl);

    LRaised := False;
    LRejectedTarget := False;
    try
      LResp := LClient.Send(LReq);
    except
      on E: EHttpError do
      begin
        LRaised := True;
        LRejectedTarget := Pos('request target', LowerCase(E.Message)) > 0;
      end;
    end;

    Check(LRaised, AContext + ': invalid request target raises EHttpError');
    Check(LRejectedTarget,
      AContext + ': invalid request target reports target failure');
    Check(Pos(AInjectedMarker, GRawRequest1) = 0,
      AContext + ': injected request target is not written to the wire');
    if LResp <> nil then
      HttpReleaseResponseBody(LResp);
  finally
    GRawListener.Close;
    platform_thread_join(LHandle, LRet);
    GRawListener := nil;
    GRawRequest1 := '';
    GRawRequest2 := '';
    GRawResponse1 := '';
    GRawResponse2 := '';
    GRawAcceptLimit := 0;
    GRawAcceptCount := 0;
  end;
end;

function PoolAcceptThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LRuntime: ITcpListenerRuntime;
  LAccept: TTcpAcceptResult;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LReply: string;
  LAccum: string;
  LP: SizeInt;
begin
  Result := nil;
  { Non-blocking accept: closing the listener from the test thread does not
    reliably wake a blocked Accept on all hosts (suite hang after MaxPoolSize). }
  try
    if GPoolListener = nil then
      Exit;
    LRuntime := GPoolListener as ITcpListenerRuntime;
    LRuntime.SetBlocking(False);
  except
    Exit;
  end;
  while True do
  begin
    try
      if GPoolListener = nil then
        Break;
      LRuntime := GPoolListener as ITcpListenerRuntime;
      LAccept := LRuntime.TryAccept(LConn);
    except
      Break;
    end;
    if LAccept = tarWouldBlock then
    begin
      platform_thread_sleep_ms(10);
      Continue;
    end;
    if (LAccept <> tarAccepted) or (LConn = nil) then
      Break;
    InterlockedIncrement(GAcceptCount);
    { Bound idle keep-alive reads so a closed/expired client cannot leave this
      thread in an unbounded Read (suite hang after IdleTTL tests). }
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
    except
    end;
    { Serve multiple requests on this connection by detecting \r\n\r\n boundaries }
    try
      LAccum := '';
      while True do
      begin
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          Break;
        end;
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
    try
      LConn.Close;
    except
    end;
  end;
end;

function PoolAcceptThreadAlt(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LRuntime: ITcpListenerRuntime;
  LAccept: TTcpAcceptResult;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LReply: string;
  LAccum: string;
  LP: SizeInt;
begin
  Result := nil;
  try
    if GPoolListenerAlt = nil then
      Exit;
    LRuntime := GPoolListenerAlt as ITcpListenerRuntime;
    LRuntime.SetBlocking(False);
  except
    Exit;
  end;
  while True do
  begin
    try
      if GPoolListenerAlt = nil then
        Break;
      LRuntime := GPoolListenerAlt as ITcpListenerRuntime;
      LAccept := LRuntime.TryAccept(LConn);
    except
      Break;
    end;
    if LAccept = tarWouldBlock then
    begin
      platform_thread_sleep_ms(10);
      Continue;
    end;
    if (LAccept <> tarAccepted) or (LConn = nil) then
      Break;
    InterlockedIncrement(GAcceptCountAlt);
    try
      LConn.SetReadDeadline(TDeadline.After(TDuration.FromSeconds(5)));
    except
    end;
    try
      LAccum := '';
      while True do
      begin
        try
          LN := LConn.Read(LBuf[0], 4096);
        except
          Break;
        end;
        if LN = 0 then Break;
        SetLength(LAccum, Length(LAccum) + Int32(LN));
        Move(LBuf[0], LAccum[Length(LAccum) - Int32(LN) + 1], LN);
        while True do
        begin
          LP := Pos(#13#10#13#10, LAccum);
          if LP = 0 then Break;
          LReply := 'HTTP/1.1 200 OK'#13#10 +
                    'Content-Length: 2'#13#10 +
                    #13#10 +
                    'ok';
          LConn.Write(LReply[1], SizeUInt(Length(LReply)));
          System.Delete(LAccum, 1, LP + 3);
        end;
      end;
    except
    end;
    try
      LConn.Close;
    except
    end;
  end;
end;

procedure WritePoolOkResponse(const AConn: ITcpStream);
var
  LReply: string;
begin
  LReply := 'HTTP/1.1 200 OK'#13#10 +
            'Content-Length: 2'#13#10 +
            #13#10 +
            'ok';
  AConn.Write(LReply[1], SizeUInt(Length(LReply)));
end;

function TimeoutReuseAcceptThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LMethod: string;
  LBody: string;
begin
  Result := nil;
  try
    LConn := GPoolListener.Accept;
  except
    Exit;
  end;
  if LConn = nil then
    Exit;

  InterlockedIncrement(GAcceptCount);
  try
    ReadRetryRawRequest(LConn, LMethod, LBody);
    if LMethod <> '' then
      WritePoolOkResponse(LConn);

    LMethod := '';
    LBody := '';
    ReadRetryRawRequest(LConn, LMethod, LBody);
    if LMethod <> '' then
    begin
      WritePoolOkResponse(LConn);
      LConn.Close;
      Exit;
    end;
  except
  end;
  LConn.Close;

  try
    LConn := GPoolListener.Accept;
  except
    Exit;
  end;
  if LConn = nil then
    Exit;

  InterlockedIncrement(GAcceptCount);
  try
    ReadRetryRawRequest(LConn, LMethod, LBody);
    if LMethod <> '' then
      WritePoolOkResponse(LConn);
  except
  end;
  LConn.Close;
end;

function RequestWriteFailureThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LMethod: string;
  LBody: string;
begin
  Result := nil;
  try
    LConn := GWriteFailureListener.Accept;
  except
    Exit;
  end;
  if LConn = nil then
    Exit;

  InterlockedIncrement(GWriteFailureAcceptCount);
  try
    ReadRetryRawRequest(LConn, LMethod, LBody);
    GWriteFailureFirstBody := LBody;
  except
  end;
  LConn.Close;

  try
    LConn := GWriteFailureListener.Accept;
  except
    Exit;
  end;
  if LConn = nil then
    Exit;

  InterlockedIncrement(GWriteFailureAcceptCount);
  try
    ReadRetryRawRequest(LConn, LMethod, LBody);
    if LMethod <> '' then
      WritePoolOkResponse(LConn);
  except
  end;
  LConn.Close;
end;

function PoolAuthorityCaseThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LRaw: string;
begin
  Result := nil;
  try
    LConn := GPoolListener.Accept;
  except
    Exit;
  end;
  if LConn = nil then
    Exit;

  InterlockedIncrement(GAcceptCount);
  try
    GPoolRequest1 := ReadRawHttpRequest(LConn);
    if GPoolRequest1 <> '' then
      WritePoolOkResponse(LConn);

    LRaw := ReadRawHttpRequest(LConn);
    if LRaw <> '' then
    begin
      GPoolRequest2 := LRaw;
      WritePoolOkResponse(LConn);
      LConn.Close;
      Exit;
    end;
  except
  end;
  LConn.Close;

  try
    LConn := GPoolListener.Accept;
  except
    Exit;
  end;
  if LConn = nil then
    Exit;

  InterlockedIncrement(GAcceptCount);
  try
    GPoolRequest2 := ReadRawHttpRequest(LConn);
    if GPoolRequest2 <> '' then
      WritePoolOkResponse(LConn);
  except
  end;
  LConn.Close;
end;

{ Per-request options override tests }

procedure TestWithFollowRedirectsFalse;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LTransport.RedirectLocation := '/new';
  LTransport.RedirectStatus := HTTP_STATUS_FOUND;
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LResp := LClient.WithFollowRedirects(False).Get('http://localhost/orig');
  CheckEqual(Int64(HTTP_STATUS_FOUND), Int64(LResp.StatusCode),
    'WithFollowRedirects(false) returns 302 instead of following');
  HttpReleaseResponseBody(LResp);
end;

procedure TestWithMaxRedirectsZero;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LCaught: Boolean;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LTransport.RedirectLocation := '/new';
  LTransport.RedirectStatus := HTTP_STATUS_FOUND;
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LCaught := False;
  try
    LClient.WithMaxRedirects(0).Get('http://localhost/orig');
  except
    on E: EHttpError do
    begin
      LCaught := Pos('too many redirects', E.Message) > 0;
    end;
  end;
  Check(LCaught,
    'WithMaxRedirects(0) raises too many redirects');
end;

procedure TestRedirectErrorRedactsCredentials;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LMsg: string;
  LCaught: Boolean;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LTransport.RedirectLocation := '/new';
  LTransport.RedirectStatus := HTTP_STATUS_FOUND;
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LCaught := False;
  LMsg := '';
  try
    LClient.WithMaxRedirects(0).Get(
      'https://user:s3cret@sub.example.com:8443/clash?token=abcd1234#frag');
  except
    on E: EHttpError do
    begin
      LCaught := True;
      LMsg := E.Message;
    end;
  end;
  Check(LCaught, 'too many redirects raises');
  Check(Pos('too many redirects', LMsg) > 0, 'detail present');
  Check(Pos('s3cret', LMsg) = 0, 'userinfo secret not in error');
  Check(Pos('user:', LMsg) = 0, 'userinfo not in error');
  Check(Pos('token=', LMsg) = 0, 'query not in error');
  Check(Pos('#frag', LMsg) = 0, 'fragment not in error');
  Check(Pos('/clash', LMsg) = 0, 'path not in error');
  Check(Pos('https://sub.example.com:8443', LMsg) > 0, 'origin remains');
end;

procedure TestWithFollowRedirectsChain;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LTransport.RedirectLocation := '/new';
  LTransport.RedirectStatus := HTTP_STATUS_FOUND;
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LResp := LClient
    .WithHeader('x-test', 'phase17')
    .WithFollowRedirects(False)
    .Get('http://localhost/orig');
  CheckEqual(Int64(HTTP_STATUS_FOUND), Int64(LResp.StatusCode),
    'chained WithFollowRedirects(false) + WithHeader returns 302');
  HttpReleaseResponseBody(LResp);
end;

procedure TestWithFollowRedirectsOverrideClientDefault;
var
  LTransport: TRedirectCaptureTransport;
  LOptions: THttpClientOptions;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LTransport.RedirectLocation := '/new';
  LTransport.RedirectStatus := HTTP_STATUS_FOUND;
  LOptions := THttpClientOptions.Default;
  LOptions.FollowRedirects := True;
  LClient := NewHttpClient(LTransport, LOptions);
  LResp := LClient.WithFollowRedirects(False).Get('http://localhost/orig');
  CheckEqual(Int64(HTTP_STATUS_FOUND), Int64(LResp.StatusCode),
    'per-request WithFollowRedirects(false) overrides client FollowRedirects=True');
  HttpReleaseResponseBody(LResp);
end;

{ THttpRequestBuilder tests }

{ Streaming body tests }

procedure TestStreamingBodyOwnershipOnRedirect;
var
  LBody: TTrackedRequestBody;
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LCaught: Boolean;
begin
  LBody := TTrackedRequestBody.Create('redirect-body');
  LTransport := TRedirectCaptureTransport.Create(LBody);
  LTransport.RedirectLocation := '/new';
  LTransport.RedirectStatus := HTTP_STATUS_TEMPORARY_REDIRECT;
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LCaught := False;
  try
    LClient.SendStreaming(hmPost, 'http://localhost/orig',
      'text/plain', LBody as IReader, 14);
  except
    on E: EHttpError do
      LCaught := Pos('not replayable', E.Message) > 0;
  end;
  Check(LCaught, 'non-seekable streaming body raises on redirect replay');
  Check(LBody.Closed, 'streaming body closed even after redirect failure');
end;

{ HttpEnsureSuccess tests }

{ HttpGetString / HttpGetBytes tests }

{ WithRetry tests }

function NewConnectTestClientCtx: ISSLContext;
begin
  Result := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyNone
    .BuildClient;
end;

function NewConnectTestServerCtx(const ACommonName: string): ISSLContext;
var
  LKeyPair: IKeyPairWithCertificate;
  LCertPEM, LKeyPEM: string;
begin
  LKeyPair := TCertificateBuilder.Create
    .WithCommonName(ACommonName)
    .WithOrganization('nextpas-http-connect-test')
    .SelfSigned;
  LKeyPair.SaveToPEM(LCertPEM, LKeyPEM);
  Result := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithCertificatePEM(LCertPEM)
    .WithPrivateKeyPEM(LKeyPEM)
    .WithVerifyNone
    .BuildServer;
end;

{ Live H1 dial timeout through NewHttpClient (backlog-full peer; no blackhole IP). }
var
  GMidReadCancelPort: UInt16 = 0;
  GMidReadCancelToken: IHttpCancelToken = nil;

function MidReadCancelSignalThread(AArg: Pointer): Pointer; cdecl;
begin
  Result := nil;
  platform_thread_sleep_ns(80000000); { 80ms }
  if GMidReadCancelToken <> nil then
    GMidReadCancelToken.Cancel;
end;

function MidReadHoldServerThread(AArg: Pointer): Pointer; cdecl;
var
  LListener: ITcpListener;
  LConn: ITcpStream;
  LBuf: array[0..1023] of Byte;
begin
  Result := nil;
  LListener := TcpListen('127.0.0.1', 0);
  GMidReadCancelPort := LListener.LocalAddr.Port;
  try
    LConn := LListener.Accept;
    try
      { Drain request line/headers then hold without response body. }
      try
        LConn.Read(LBuf[0], SizeOf(LBuf));
      except
      end;
      platform_thread_sleep_ns(2000000000); { 2s hold if cancel fails }
    finally
      if LConn <> nil then
        LConn.Close;
    end;
  finally
    LListener.Close;
  end;
end;

{ Live mid-read cancel: server holds after accept; client cancel → hekCanceled. }
procedure TestClientRedirectCreateOpSourceContract;
var
  LClient, LHelpers: string;
begin
  { redirect/round_trip live on client; ensure moved to client.helpers (Era2). }
  LClient := ReadFileText('../../../src/nextpas.core.http.client.pas');
  LHelpers := ReadFileText('../../../src/nextpas.core.http.client.helpers.pas');
  Check(Pos('raise EHttpError.CreateOp(hekRedirect, ''redirect'',', LClient) > 0,
    'redirect failures use CreateOp with Op=redirect');
  Check(Pos('raise EHttpError.CreateOp(hekConnect, ''round_trip'',', LClient) > 0,
    'nil transport response uses CreateOp with Op=round_trip');
  Check(Pos('raise EHttpError.CreateOp(hekStatus, ''ensure'',', LHelpers) > 0,
    'HttpEnsureSuccess non-2xx uses CreateOp with Op=ensure');
end;

{ HttpPostString/PutString/PatchString/DeleteString tests }

{ Main }

begin
  T := TTestSuite.Create('nextpas.core.http.client.redirect');
  T.Test('Client Send rejects redirect with nil headers',
    @TestClientSendRejectsRedirectWithNilHeaders);
  T.Test('Client follows redirect (301 -> 200)', @TestClientFollowsRedirect);
  T.Test('Client closes original body before GET-style redirect follow-up',
    @TestClientClosesOriginalBodyBeforeGetStyleRedirectFollowup);
  T.Test('Client does not retry close when GET-style redirect body close fails',
    @TestClientDoesNotRetryCloseWhenGetStyleRedirectBodyCloseFails);
  T.Test('Client follows 303 redirect as GET', @TestClientFollowsSeeOtherAsGet);
  T.Test('Client preserves relative redirect query', @TestClientPreservesRelativeRedirectQuery);
  T.Test('Client redirect transport sees parsed relative query',
    @TestClientRedirectTransportSeesParsedRelativeQuery);
  T.Test('Client preserves HEAD on 301/302/303 redirects',
    @TestClientPreservesHeadOnGetStyleRedirects);
  T.Test('Client redirect transport resolves network-path Location',
    @TestClientRedirectTransportResolvesNetworkPathLocation);
  T.Test('Client redirect transport resolves uppercase absolute Location',
    @TestClientRedirectTransportResolvesUppercaseAbsoluteLocation);
  T.Test('Client redirect rejects unsupported absolute scheme',
    @TestClientRedirectRejectsUnsupportedAbsoluteScheme);
  T.Test('Client redirect rejects absolute Location with empty host',
    @TestClientRedirectRejectsAbsoluteLocationWithEmptyHost);
  T.Test('Client redirect rejects absolute Location with invalid port',
    @TestClientRedirectRejectsAbsoluteLocationWithInvalidPort);
  T.Test('Client redirect rejects network-path Location with empty host',
    @TestClientRedirectRejectsNetworkPathLocationWithEmptyHost);
  T.Test('Client redirect rejects network-path Location with invalid port',
    @TestClientRedirectRejectsNetworkPathLocationWithInvalidPort);
  T.Test('Client redirect rejects malformed bracketed IPv6 authority',
    @TestClientRedirectRejectsMalformedBracketedIpv6Authority);
  T.Test('Client redirect transport resolves userinfo Location with port',
    @TestClientRedirectTransportResolvesUserInfoLocationWithPort);
  T.Test('Client redirect rejects unsupported non-hierarchical scheme',
    @TestClientRedirectRejectsUnsupportedNonHierarchicalScheme);
  T.Test('Client redirect rejects unsupported single-slash scheme',
    @TestClientRedirectRejectsUnsupportedSingleSlashScheme);
  T.Test('Client redirect transport resolves path-relative Location',
    @TestClientRedirectTransportResolvesPathRelativeLocation);
  T.Test('Client redirect transport normalizes dot-segment Location',
    @TestClientRedirectTransportNormalizesDotSegmentLocation);
  T.Test('Client redirect transport preserves query on fragment-only Location',
    @TestClientRedirectTransportPreservesQueryOnFragmentOnlyLocation);
  T.Test('Client redirect preserves headers on same authority',
    @TestClientRedirectPreservesHeadersOnSameAuthority);
  T.Test('Client redirect strips sensitive headers across authority',
    @TestClientRedirectStripsSensitiveHeadersAcrossAuthority);
  T.Test('Client redirect strips sensitive headers across scheme',
    @TestClientRedirectStripsSensitiveHeadersAcrossScheme);
  T.Test('Client redirect strips sensitive headers to subdomain authority',
    @TestClientRedirectStripsSensitiveHeadersToSubdomainAuthority);
  T.Test('Client redirect preserves custom host header on relative Location',
    @TestClientRedirectPreservesCustomHostHeaderOnRelativeLocation);
  T.Test('Client redirect preserves custom host header on default-port authority',
    @TestClientRedirectPreservesCustomHostHeaderOnDefaultPortAuthority);
  T.Test('Client closes redirect response body before follow-up',
    @TestClientClosesRedirectResponseBodyBeforeFollowup);
  T.Test('Client drains redirect response body before follow-up',
    @TestClientDrainsRedirectResponseBodyBeforeFollowup);
  T.Test('Client closes redirect response body on too many redirects',
    @TestClientClosesRedirectResponseBodyOnTooManyRedirects);
  T.Test('Client closes redirect response body on missing Location',
    @TestClientClosesRedirectResponseBodyOnMissingLocation);
  T.Test('Client closes redirect response body on duplicate Location',
    @TestClientClosesRedirectResponseBodyOnDuplicateLocation);
  T.Test('Client redirect policy error keeps primary error when body close fails',
    @TestClientRedirectPolicyErrorKeepsPrimaryErrorWhenBodyCloseFails);
  T.Test('Client closes redirect response body on unsupported scheme',
    @TestClientClosesRedirectResponseBodyOnUnsupportedScheme);
  T.Test('Client replays seekable body on 307 redirect',
    @TestClientReplaysSeekableBodyOnTemporaryRedirect);
  T.Test('Client rejects non-replayable body on 307 redirect',
    @TestClientRejectsNonReplayableBodyOnTemporaryRedirect);
  T.Test('Client respects max redirects', @TestClientMaxRedirects);
  T.Test('WithFollowRedirects(false) prevents redirect',
    @TestWithFollowRedirectsFalse);
  T.Test('WithMaxRedirects(0) raises too many redirects',
    @TestWithMaxRedirectsZero);
  T.Test('Redirect error redacts userinfo/query',
    @TestRedirectErrorRedactsCredentials);
  T.Test('WithFollowRedirects chains with WithHeader',
    @TestWithFollowRedirectsChain);
  T.Test('WithFollowRedirects(false) overrides client default',
    @TestWithFollowRedirectsOverrideClientDefault);
  T.Test('Streaming body ownership on redirect',
    @TestStreamingBodyOwnershipOnRedirect);
  T.Test('Client redirect CreateOp source contract',
    @TestClientRedirectCreateOpSourceContract);
  if not T.Run then Halt(1);
end.
