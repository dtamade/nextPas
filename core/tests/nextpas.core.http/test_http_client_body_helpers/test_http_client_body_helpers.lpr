program test_http_client_body_helpers;

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
{ Test 2: Client GET with custom headers }
{ Test 3: Client POST with body }
// PLACEHOLDER_TEST4

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
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
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
  LHeaders.SetHeader('content-length', '9');
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
  LHeaders.SetHeader('content-length', '9');
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

procedure TestHttpGetToWriterKeepsWriteErrorWhenCloseFails;
var
  LHeaders: IHttpHeaders;
  LBody: TCloseFailingResponseBody;
  LBodyRef: IReadCloser;
  LClient: IHttpClient;
  LRaisedWriteError: Boolean;
  LRaisedCloseError: Boolean;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-length', '1');
  LBody := TCloseFailingResponseBody.Create('x');
  LBodyRef := LBody as IReadCloser;
  LClient := TDownloadClient.Create(NewResponse(HTTP_STATUS_OK, LHeaders,
    LBodyRef as IReader)) as IHttpClient;

  LRaisedWriteError := False;
  LRaisedCloseError := False;
  try
    HttpGetToWriter(LClient, 'http://example.test/tool',
      TZeroProgressWriter.Create as IWriter);
  except
    on E: Exception do
    begin
      LRaisedWriteError := E.Message = 'IoCopy: write returned 0';
      LRaisedCloseError := E.Message = 'response body close failed';
    end;
  end;

  Check(LRaisedWriteError,
    'download helper preserves primary copy error');
  Check(not LRaisedCloseError,
    'download helper does not replace copy error with close error');
  CheckEqual(Int64(1), Int64(LBody.CloseCount),
    'download helper still attempts close after copy error');
  Check(LBody.Closed,
    'download helper marks close attempted after copy error');
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
  LHeaders.SetHeader('content-length', '9');
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
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LResponseBody))));
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

procedure TestHttpReadResponseBodyStringClosesBodyAfterRead;
var
  LHeaders: IHttpHeaders;
  LBody: TRedirectTrackedBody;
  LBodyRef: IReadCloser;
  LResp: IHttpResponse;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-length', '9');
  LBody := TRedirectTrackedBody.Create('toolchain');
  LBodyRef := LBody as IReadCloser;
  LResp := NewResponse(HTTP_STATUS_OK, LHeaders, LBodyRef as IReader);

  CheckEqual('toolchain', nextpas.core.http.client.HttpReadResponseBodyString(LResp),
    'response body string helper reads close-capable body');
  Check(LBody.Closed,
    'response body string helper closes close-capable body after read');
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
    on E: EHttpError do
      LRaised := E.Kind = hekArgument;
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
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LResponseBody))));
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

procedure TestHttpReadResponseBodyBytesClosesBodyAfterRead;
var
  LHeaders: IHttpHeaders;
  LBody: TRedirectTrackedBody;
  LBodyRef: IReadCloser;
  LResp: IHttpResponse;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-length', '9');
  LBody := TRedirectTrackedBody.Create('toolchain');
  LBodyRef := LBody as IReadCloser;
  LResp := NewResponse(HTTP_STATUS_OK, LHeaders, LBodyRef as IReader);

  CheckEqual('toolchain', BytesToTestString(
    nextpas.core.http.client.HttpReadResponseBodyBytes(LResp)),
    'response body bytes helper reads close-capable body');
  Check(LBody.Closed,
    'response body bytes helper closes close-capable body after read');
end;

procedure TestHttpReadResponseBodyBytesKeepsReadErrorWhenCloseFails;
var
  LHeaders: IHttpHeaders;
  LBody: TReadAndCloseFailingResponseBody;
  LBodyRef: IReadCloser;
  LResp: IHttpResponse;
  LRaisedReadError: Boolean;
  LRaisedCloseError: Boolean;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-length', '1');
  LBody := TReadAndCloseFailingResponseBody.Create;
  LBodyRef := LBody as IReadCloser;
  LResp := NewResponse(HTTP_STATUS_OK, LHeaders, LBodyRef as IReader);

  LRaisedReadError := False;
  LRaisedCloseError := False;
  try
    nextpas.core.http.client.HttpReadResponseBodyBytes(LResp);
  except
    on E: Exception do
    begin
      LRaisedReadError := E.Message = 'response body read failed';
      LRaisedCloseError := E.Message = 'response body close failed';
    end;
  end;

  Check(LRaisedReadError,
    'response body bytes helper preserves primary read error');
  Check(not LRaisedCloseError,
    'response body bytes helper does not replace read error with close error');
  CheckEqual(Int64(1), Int64(LBody.CloseCount),
    'response body bytes helper still attempts close after read error');
  Check(LBody.Closed,
    'response body bytes helper marks close attempted after read error');
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
    on E: EHttpError do
      LRaised := E.Kind = hekArgument;
  end;
  Check(LRaised, 'response body bytes helper rejects nil response');
end;

procedure TestExtractCharsetFromContentType;
begin
  CheckEqual('utf-8', ExtractCharsetFromContentType('text/html; charset=utf-8'),
    'basic charset');
  CheckEqual('UTF-8', ExtractCharsetFromContentType('text/html; charset=UTF-8'),
    'preserves case');
  CheckEqual('iso-8859-1', ExtractCharsetFromContentType('text/html; charset=iso-8859-1'),
    'latin1');
  CheckEqual('utf-8', ExtractCharsetFromContentType('application/json; charset=utf-8'),
    'json charset');
  CheckEqual('', ExtractCharsetFromContentType('text/html'),
    'no charset');
  CheckEqual('', ExtractCharsetFromContentType(''),
    'empty content-type');
  CheckEqual('utf-8', ExtractCharsetFromContentType('text/html; charset="utf-8"'),
    'quoted charset');
end;

procedure TestHttpReadResponseBodyStringAutoUtf8;
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
  LRouter.Get('/utf8', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LResponseBody: string;
  begin
    LResponseBody := 'héllo wörld';
    AW.GetHeaders.SetHeader('content-type', 'text/plain; charset=utf-8');
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LResponseBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LResponseBody[1], SizeUInt(Length(LResponseBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/utf8');
    LBody := nextpas.core.http.client.HttpReadResponseBodyStringAuto(LResp);
    CheckEqual('héllo wörld', LBody, 'utf-8 auto read');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHttpReadResponseBodyStringAutoLatin1;
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
  LRouter.Get('/latin1', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LResponseBody: string;
  begin
    { Send raw Latin-1 bytes: é = 0xE9, ö = 0xF6 }
    LResponseBody := 'h' + Chr($E9) + 'llo w' + Chr($F6) + 'rld';
    AW.GetHeaders.SetHeader('content-type', 'text/plain; charset=iso-8859-1');
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LResponseBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LResponseBody[1], SizeUInt(Length(LResponseBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/latin1');
    LBody := nextpas.core.http.client.HttpReadResponseBodyStringAuto(LResp);
    Check(Pos(Chr($E9), LBody) > 0, 'latin1 é preserved');
    Check(Pos(Chr($F6), LBody) > 0, 'latin1 ö preserved');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHttpReadResponseBodyStringAutoNoCharset;
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
  LRouter.Get('/nocharset', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LResponseBody: string;
  begin
    LResponseBody := 'hello world';
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LResponseBody))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LResponseBody[1], SizeUInt(Length(LResponseBody)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/nocharset');
    LBody := nextpas.core.http.client.HttpReadResponseBodyStringAuto(LResp);
    CheckEqual('hello world', LBody, 'no charset defaults to utf-8');
  finally
    StopServer(LServer, LHandle);
  end;
end;

function TestStringToBytes(const AValue: string): TBytes;
begin
  SetLength(Result, Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[1], Result[0], Length(AValue));
end;

procedure TestHttpDecodeContentEncodingGzip;
var
  LPlain, LCompressed, LDecoded: TBytes;
begin
  LPlain := TestStringToBytes('hello gzip world');
  LCompressed := GzipCompress(LPlain);
  LDecoded := HttpDecodeContentEncoding('gzip', LCompressed);
  CheckEqual('hello gzip world', BytesToTestString(LDecoded),
    'gzip Content-Encoding decodes');
end;

procedure TestHttpDecodeContentEncodingDeflate;
var
  LPlain, LCompressed, LDecoded: TBytes;
begin
  LPlain := TestStringToBytes('hello deflate world');
  LCompressed := DeflateCompress(LPlain);
  LDecoded := HttpDecodeContentEncoding('deflate', LCompressed);
  CheckEqual('hello deflate world', BytesToTestString(LDecoded),
    'deflate Content-Encoding decodes');
end;

procedure TestHttpDecodeContentEncodingIdentityAndEmpty;
var
  LPlain, LDecoded: TBytes;
begin
  LPlain := TestStringToBytes('plain');
  LDecoded := HttpDecodeContentEncoding('', LPlain);
  CheckEqual('plain', BytesToTestString(LDecoded), 'empty encoding is pass-through');
  LDecoded := HttpDecodeContentEncoding('identity', LPlain);
  CheckEqual('plain', BytesToTestString(LDecoded), 'identity encoding is pass-through');
end;

procedure TestHttpDecodeContentEncodingUnsupported;
var
  LRaised: Boolean;
  LOp: string;
  LKind: THttpErrorKind;
begin
  LRaised := False;
  LOp := '';
  LKind := hekUnknown;
  try
    HttpDecodeContentEncoding('br', TestStringToBytes('x'));
  except
    on E: EHttpError do
    begin
      LRaised := True;
      LKind := E.Kind;
      LOp := E.Op;
    end;
  end;
  Check(LRaised, 'unsupported Content-Encoding raises');
  Check(LKind = hekProtocol, 'unsupported encoding is hekProtocol');
  CheckEqual('content_encoding', LOp, 'unsupported encoding Op=content_encoding');
end;

procedure TestHttpDecodeContentEncodingMultiCodingRejected;
var
  LRaised: Boolean;
  LOp: string;
begin
  LRaised := False;
  LOp := '';
  try
    HttpDecodeContentEncoding('gzip, deflate', TestStringToBytes('x'));
  except
    on E: EHttpError do
    begin
      LRaised := True;
      LOp := E.Op;
      Check(E.Kind = hekProtocol, 'multi-coding is hekProtocol');
    end;
  end;
  Check(LRaised, 'multi Content-Encoding raises');
  CheckEqual('content_encoding', LOp, 'multi-coding Op=content_encoding');
end;

procedure TestHttpDecodeContentEncodingCorrupt;
var
  LRaised: Boolean;
  LOp: string;
  LKind: THttpErrorKind;
  LJunk: TBytes;
begin
  LJunk := TestStringToBytes('not-gzip-payload');
  LRaised := False;
  LOp := '';
  LKind := hekUnknown;
  try
    HttpDecodeContentEncoding('gzip', LJunk);
  except
    on E: EHttpError do
    begin
      LRaised := True;
      LKind := E.Kind;
      LOp := E.Op;
    end;
  end;
  Check(LRaised, 'corrupt gzip raises');
  Check(LKind = hekBody, 'corrupt payload is hekBody');
  CheckEqual('content_encoding', LOp, 'corrupt payload Op=content_encoding');
end;

procedure TestHttpDecodeContentEncodingMaxSize;
var
  LPlain, LCompressed: TBytes;
  LRaised: Boolean;
begin
  LPlain := TestStringToBytes('0123456789abcdefghij');
  LCompressed := GzipCompress(LPlain);
  LRaised := False;
  try
    HttpDecodeContentEncoding('gzip', LCompressed, 5);
  except
    on E: EHttpError do
    begin
      LRaised := True;
      CheckEqual('content_encoding', E.Op, 'max-size failure Op=content_encoding');
      Check(E.Kind = hekBody, 'max-size decode failure is hekBody');
    end;
  end;
  Check(LRaised, 'max decompressed size is enforced');
end;

procedure TestHttpReadResponseBodyBytesDecodedGzip;
var
  LHeaders: IHttpHeaders;
  LPlain, LCompressed, LDecoded: TBytes;
  LResp: IHttpResponse;
begin
  LPlain := TestStringToBytes('decoded-body');
  LCompressed := GzipCompress(LPlain);
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-encoding', 'gzip');
  LResp := NewResponse(HTTP_STATUS_OK, LHeaders, LCompressed);
  LDecoded := HttpReadResponseBodyBytesDecoded(LResp);
  CheckEqual('decoded-body', BytesToTestString(LDecoded),
    'response helper decodes Content-Encoding gzip');
end;

procedure TestHttpReadResponseBodyBytesDecodedNoEncodingIsRaw;
var
  LHeaders: IHttpHeaders;
  LResp: IHttpResponse;
  LDecoded: TBytes;
begin
  LHeaders := NewHttpHeaders;
  LResp := NewResponse(HTTP_STATUS_OK, LHeaders, TestStringToBytes('raw-body'));
  LDecoded := HttpReadResponseBodyBytesDecoded(LResp);
  CheckEqual('raw-body', BytesToTestString(LDecoded),
    'missing Content-Encoding returns raw body');
end;

procedure TestHttpReadResponseBodyStringDecodedGzip;
var
  LHeaders: IHttpHeaders;
  LPlain, LCompressed: TBytes;
  LResp: IHttpResponse;
  LText: string;
begin
  LPlain := TestStringToBytes('string-decoded');
  LCompressed := GzipCompress(LPlain);
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-encoding', 'gzip');
  LResp := NewResponse(HTTP_STATUS_OK, LHeaders, LCompressed);
  LText := HttpReadResponseBodyStringDecoded(LResp);
  CheckEqual('string-decoded', LText, 'string decoded helper');
end;

procedure TestHttpReadResponseBodyBytesDecodedLiveCompression;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
  LBody: string;
  LPlain: string;
  LHandler: IHttpHandler;
  I: Integer;
begin
  { Body large enough for default CompressionMiddleware min size (1024). }
  LPlain := '';
  for I := 1 to 1200 do
    LPlain := LPlain + 'a';
  LRouter := THttpRouter.Create;
  LRouter.Get('/gzip-body', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    AW.GetHeaders.SetHeader('content-type', 'text/plain');
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LPlain))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LPlain[1], SizeUInt(Length(LPlain)));
  end);
  LHandler := Chain(LRouter as IHttpHandler, [CompressionMiddleware]);
  LHandle := StartServer(LHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LReq := THttpRequestBuilder.Create(hmGet,
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/gzip-body')
      .Header('accept-encoding', 'gzip')
      .Build;
    LResp := LClient.Send(LReq);
    CheckEqual('gzip', LowerCase(LResp.Headers.Get('content-encoding')),
      'server compression sets Content-Encoding gzip');
    LBody := HttpReadResponseBodyStringDecoded(LResp);
    CheckEqual(LPlain, LBody, 'client decodes live gzip response');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestHttpReleaseResponseBodyClosesCloseCapableBody;
var
  LHeaders: IHttpHeaders;
  LBody: TRedirectTrackedBody;
  LBodyRef: IReadCloser;
  LResp: IHttpResponse;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-length', '7');
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
  LHeaders.SetHeader('content-length', '7');
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
    on E: EHttpError do
      LRaised := E.Kind = hekArgument;
  end;
  Check(LRaised, 'release helper rejects nil response');
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
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
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
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LBody))));
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

procedure TestHttpGetToFileKeepsReadErrorWhenCloseFails;
var
  LHeaders: IHttpHeaders;
  LBody: TReadAndCloseFailingResponseBody;
  LBodyRef: IReadCloser;
  LClient: IHttpClient;
  LDestPath: string;
  LRaisedReadError: Boolean;
  LRaisedCloseError: Boolean;
begin
  ResetDownloadTempRoot;
  LDestPath := PathJoin([DownloadTempRoot, 'read-fail', 'tool.bin']);
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-length', '1');
  LBody := TReadAndCloseFailingResponseBody.Create;
  LBodyRef := LBody as IReadCloser;
  LClient := TDownloadClient.Create(NewResponse(HTTP_STATUS_OK, LHeaders,
    LBodyRef as IReader)) as IHttpClient;

  LRaisedReadError := False;
  LRaisedCloseError := False;
  try
    try
      HttpGetToFile(LClient, 'http://example.test/tool', LDestPath);
    except
      on E: Exception do
      begin
        LRaisedReadError := E.Message = 'response body read failed';
        LRaisedCloseError := E.Message = 'response body close failed';
      end;
    end;

    Check(LRaisedReadError,
      'file download helper preserves primary read error');
    Check(not LRaisedCloseError,
      'file download helper does not replace read error with close error');
    CheckEqual(Int64(1), Int64(LBody.CloseCount),
      'file download helper still attempts close after read error');
    Check(LBody.Closed,
      'file download helper marks close attempted after read error');
    Check(not Exists(LDestPath),
      'file download helper does not leave final file after read error');
  finally
    RemoveAll(DownloadTempRoot);
  end;
end;

{ Test 4: Client follows redirect (301 -> 200) }
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

{ Test 5: Client respects max redirects (infinite loop -> error) }
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

{ THttpRequestBuilder tests }

{ Streaming body tests }

{ HttpEnsureSuccess tests }

procedure TestHttpEnsureSuccess200;
var
  LResp: IHttpResponse;
  LHeaders: IHttpHeaders;
  LResult: IHttpResponse;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-length', '0');
  LResp := NewResponse(HTTP_STATUS_OK, LHeaders, nil);
  LResult := HttpEnsureSuccess(LResp);
  Check(LResult = LResp, 'EnsureSuccess returns same response on 200');
end;

procedure TestHttpEnsureSuccess201;
var
  LResp: IHttpResponse;
  LHeaders: IHttpHeaders;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-length', '0');
  LResp := NewResponse(HTTP_STATUS_CREATED, LHeaders, nil);
  HttpEnsureSuccess(LResp);
  Check(True, 'EnsureSuccess passes on 201');
end;

procedure TestHttpEnsureSuccessRaisesOn404;
var
  LResp: IHttpResponse;
  LHeaders: IHttpHeaders;
  LCaught: Boolean;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-length', '0');
  LResp := NewResponse(HTTP_STATUS_NOT_FOUND, LHeaders, nil);
  LCaught := False;
  try
    HttpEnsureSuccess(LResp);
  except
    on E: EHttpError do
      LCaught := (Pos('404', E.Message) > 0) and (Pos('Not Found', E.Message) > 0);
  end;
  Check(LCaught, 'EnsureSuccess raises EHttpError on 404');
end;

procedure TestHttpEnsureSuccessRaisesOn500;
var
  LResp: IHttpResponse;
  LHeaders: IHttpHeaders;
  LCaught: Boolean;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-length', '0');
  LResp := NewResponse(HTTP_STATUS_INTERNAL_SERVER_ERROR, LHeaders, nil);
  LCaught := False;
  try
    HttpEnsureSuccess(LResp);
  except
    on E: EHttpError do
      LCaught := (Pos('500', E.Message) > 0) and
        (Pos('Internal Server Error', E.Message) > 0);
  end;
  Check(LCaught, 'EnsureSuccess raises EHttpError on 500');
end;

procedure TestHttpEnsureSuccessRaisesOnNil;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    HttpEnsureSuccess(nil);
  except
    on E: EHttpError do
      LCaught := (E.Kind = hekArgument) and (Pos('nil', E.Message) > 0);
  end;
  Check(LCaught, 'EnsureSuccess raises hekArgument on nil');
end;

{ HttpGetString / HttpGetBytes tests }

procedure TestHttpGetStringSuccess;
var
  LTransport: TTimeoutCaptureTransport;
  LClient: IHttpClient;
  LBody: string;
begin
  // TTimeoutCaptureTransport returns empty 200 — HttpGetString should return ''
  LTransport := TTimeoutCaptureTransport.Create(3000);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LBody := HttpGetString(LClient, 'http://localhost/test');
  CheckEqual('', LBody, 'GetString returns empty body from 200');
end;

procedure TestHttpGetStringRaisesOn404;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LCaught: Boolean;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LTransport.RedirectStatus := HTTP_STATUS_NOT_FOUND;
  LTransport.RedirectLocation := '';
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LCaught := False;
  try
    HttpGetString(LClient, 'http://localhost/missing');
  except
    on E: EHttpError do
      LCaught := (Pos('404', E.Message) > 0) and
        (Pos('Not Found', E.Message) > 0) and
        (Pos('GET', E.Message) > 0) and
        (Pos('http://localhost/missing', E.Message) > 0);
  end;
  Check(LCaught, 'GetString raises EHttpError on 404 with method/URL context');
end;

procedure TestHttpEnsureSuccessContextIncludesMethodUrl;
var
  LResp: IHttpResponse;
  LHeaders: IHttpHeaders;
  LCaught: Boolean;
  LMsg: string;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-length', '0');
  LResp := NewResponse(HTTP_STATUS_NOT_FOUND, LHeaders, nil);
  LCaught := False;
  LMsg := '';
  try
    HttpEnsureSuccess(LResp, 'GET', 'http://example.test/item');
  except
    on E: EHttpError do
    begin
      LCaught := E.Kind = hekStatus;
      LMsg := E.Message;
    end;
  end;
  Check(LCaught, 'EnsureSuccess context raises hekStatus');
  Check(Pos('GET', LMsg) > 0, 'EnsureSuccess context includes method');
  Check(Pos('http://example.test/item', LMsg) > 0, 'EnsureSuccess context includes URL');
  Check(Pos('404', LMsg) > 0, 'EnsureSuccess context includes status');
end;

procedure TestHttpGetBytesSuccess;
var
  LTransport: TTimeoutCaptureTransport;
  LClient: IHttpClient;
  LBody: TBytes;
begin
  LTransport := TTimeoutCaptureTransport.Create(3000);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LBody := HttpGetBytes(LClient, 'http://localhost/test');
  CheckEqual(Int64(0), Int64(Length(LBody)), 'GetBytes returns empty bytes from 200');
end;

procedure TestHttpGetBytesRaisesOn500;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LCaught: Boolean;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LTransport.RedirectStatus := HTTP_STATUS_INTERNAL_SERVER_ERROR;
  LTransport.RedirectLocation := '';
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LCaught := False;
  try
    HttpGetBytes(LClient, 'http://localhost/error');
  except
    on E: EHttpError do
      LCaught := (Pos('500', E.Message) > 0) and
        (Pos('Internal Server Error', E.Message) > 0);
  end;
  Check(LCaught, 'GetBytes raises EHttpError on 500');
end;

{ WithRetry tests }

procedure TestHttpGetJsonSuccess;
var
  LTransport: TJsonBodyTransport;
  LClient: IHttpClient;
  LDoc: IJsonDocument;
begin
  LTransport := TJsonBodyTransport.Create(HTTP_STATUS_OK, '{"a":1}');
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LDoc := HttpGetJson(LClient, 'http://localhost/api');
  Check(LDoc <> nil, 'GetJson returns document');
  Check(not LDoc.HasError, 'GetJson document has no parse error');
  Check(LDoc.Root.IsObject, 'GetJson root is object');
  CheckEqual(Int64(1), LDoc.Root.ObjectGet('a').AsInt, 'GetJson field a=1');
end;

procedure TestHttpGetJsonMethodSuccess;
var
  LTransport: TJsonBodyTransport;
  LClient: IHttpClient;
  LDoc: IJsonDocument;
begin
  LTransport := TJsonBodyTransport.Create(HTTP_STATUS_OK, '{"ok":true}');
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LDoc := LClient.GetJson('http://localhost/api');
  Check(LDoc <> nil, 'method GetJson returns document');
  Check(LDoc.Root.ObjectGet('ok').AsBool, 'method GetJson field ok');
end;

procedure TestHttpGetJsonRaisesOn404;
var
  LTransport: TJsonBodyTransport;
  LClient: IHttpClient;
  LCaught: Boolean;
  LKind: THttpErrorKind;
begin
  LTransport := TJsonBodyTransport.Create(HTTP_STATUS_NOT_FOUND, '{"err":1}');
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LCaught := False;
  LKind := hekUnknown;
  try
    HttpGetJson(LClient, 'http://localhost/missing');
  except
    on E: EHttpError do
    begin
      LCaught := True;
      LKind := E.Kind;
    end;
  end;
  Check(LCaught, 'GetJson raises on 404');
  Check(LKind = hekStatus, 'GetJson 404 is hekStatus');
end;

procedure TestHttpGetJsonRaisesOnInvalidJson;
var
  LTransport: TJsonBodyTransport;
  LClient: IHttpClient;
  LCaught: Boolean;
  LKind: THttpErrorKind;
  LOp: string;
begin
  LTransport := TJsonBodyTransport.Create(HTTP_STATUS_OK, 'not-json');
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LCaught := False;
  LKind := hekUnknown;
  LOp := '';
  try
    HttpGetJson(LClient, 'http://localhost/bad');
  except
    on E: EHttpError do
    begin
      LCaught := True;
      LKind := E.Kind;
      LOp := E.Op;
    end;
  end;
  Check(LCaught, 'GetJson raises on invalid JSON');
  Check(LKind = hekProtocol, 'invalid JSON is hekProtocol');
  CheckEqual('json', LOp, 'invalid JSON Op=json');
end;

procedure TestHttpPostJsonDocumentSuccess;
var
  LTransport: TJsonBodyTransport;
  LClient: IHttpClient;
  LBody, LDoc: IJsonDocument;
begin
  LTransport := TJsonBodyTransport.Create(HTTP_STATUS_OK, '{"id":7}');
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LBody := JsonParse('{"name":"x"}');
  LDoc := HttpPostJsonDocument(LClient, 'http://localhost/api', LBody);
  Check(LDoc <> nil, 'PostJsonDocument returns document');
  CheckEqual(Int64(7), LDoc.Root.ObjectGet('id').AsInt, 'PostJsonDocument field id');
end;

procedure TestHttpPostJsonDocumentRaisesOn404;
var
  LTransport: TJsonBodyTransport;
  LClient: IHttpClient;
  LBody: IJsonDocument;
  LCaught: Boolean;
  LKind: THttpErrorKind;
begin
  LTransport := TJsonBodyTransport.Create(HTTP_STATUS_NOT_FOUND, '{"err":1}');
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LBody := JsonParse('{"name":"x"}');
  LCaught := False;
  LKind := hekUnknown;
  try
    HttpPostJsonDocument(LClient, 'http://localhost/missing', LBody);
  except
    on E: EHttpError do
    begin
      LCaught := True;
      LKind := E.Kind;
    end;
  end;
  Check(LCaught, 'PostJsonDocument raises on 404');
  Check(LKind = hekStatus, 'PostJsonDocument 404 is hekStatus');
end;

procedure TestHttpPostJsonDocumentRaisesOnInvalidJson;
var
  LTransport: TJsonBodyTransport;
  LClient: IHttpClient;
  LBody: IJsonDocument;
  LCaught: Boolean;
  LKind: THttpErrorKind;
  LOp: string;
begin
  LTransport := TJsonBodyTransport.Create(HTTP_STATUS_OK, 'not-json');
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LBody := JsonParse('{"name":"x"}');
  LCaught := False;
  LKind := hekUnknown;
  LOp := '';
  try
    HttpPostJsonDocument(LClient, 'http://localhost/bad', LBody);
  except
    on E: EHttpError do
    begin
      LCaught := True;
      LKind := E.Kind;
      LOp := E.Op;
    end;
  end;
  Check(LCaught, 'PostJsonDocument raises on invalid JSON');
  Check(LKind = hekProtocol, 'PostJsonDocument invalid JSON is hekProtocol');
  CheckEqual('json', LOp, 'PostJsonDocument Op=json');
end;

procedure TestHttpReadResponseJsonSuccess;
var
  LResp: IHttpResponse;
  LDoc: IJsonDocument;
  LHeaders: IHttpHeaders;
begin
  LHeaders := NewHttpHeaders;
  LHeaders.SetHeader('content-type', 'application/json');
  LResp := NewResponse(HTTP_STATUS_OK, LHeaders, StringBodyReader('{"n":2}'));
  LDoc := HttpReadResponseJson(LResp, 'GET', 'http://localhost/x');
  CheckEqual(Int64(2), LDoc.Root.ObjectGet('n').AsInt, 'ReadResponseJson field n');
end;

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
procedure TestHttpEnsureSuccessOpIsEnsure;
var
  LResp: IHttpResponse;
  LOp: string;
  LStatus: THttpStatus;
  LCaught: Boolean;
begin
  LOp := '';
  LStatus := 0;
  LCaught := False;
  LResp := NewResponse(HTTP_STATUS_NOT_FOUND, NewHeaders, nil);
  try
    HttpEnsureSuccess(LResp, 'GET', 'http://example.test/x');
  except
    on E: EHttpError do
    begin
      LCaught := True;
      LOp := E.Op;
      LStatus := E.Status;
    end;
  end;
  Check(LCaught, 'EnsureSuccess raises');
  CheckEqual('ensure', LOp, 'EnsureSuccess Op=ensure');
  CheckEqual(Int64(HTTP_STATUS_NOT_FOUND), Int64(LStatus), 'EnsureSuccess preserves Status');
end;

{ HttpPostString/PutString/PatchString/DeleteString tests }

procedure TestHttpPostStringSuccess;
var
  LTransport: TTimeoutCaptureTransport;
  LClient: IHttpClient;
  LBody: string;
begin
  LTransport := TTimeoutCaptureTransport.Create(3000);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LBody := HttpPostString(LClient, 'http://localhost/test', 'text/plain', 'hello');
  CheckEqual('', LBody, 'PostString returns empty body from 200');
end;

procedure TestHttpPostStringRaisesOn404;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LCaught: Boolean;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LTransport.RedirectStatus := HTTP_STATUS_NOT_FOUND;
  LTransport.RedirectLocation := '';
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LCaught := False;
  try
    HttpPostString(LClient, 'http://localhost/error', 'text/plain', 'body');
  except
    on E: EHttpError do
      LCaught := (Pos('404', E.Message) > 0);
  end;
  Check(LCaught, 'PostString raises EHttpError on 404');
end;

procedure TestHttpPutStringSuccess;
var
  LTransport: TTimeoutCaptureTransport;
  LClient: IHttpClient;
  LBody: string;
begin
  LTransport := TTimeoutCaptureTransport.Create(3000);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LBody := HttpPutString(LClient, 'http://localhost/test', 'application/json', '{}');
  CheckEqual('', LBody, 'PutString returns empty body from 200');
end;

procedure TestHttpPutStringRaisesOn500;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LCaught: Boolean;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LTransport.RedirectStatus := HTTP_STATUS_INTERNAL_SERVER_ERROR;
  LTransport.RedirectLocation := '';
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LCaught := False;
  try
    HttpPutString(LClient, 'http://localhost/error', 'text/plain', 'body');
  except
    on E: EHttpError do
      LCaught := (Pos('500', E.Message) > 0);
  end;
  Check(LCaught, 'PutString raises EHttpError on 500');
end;

procedure TestHttpPatchStringSuccess;
var
  LTransport: TTimeoutCaptureTransport;
  LClient: IHttpClient;
  LBody: string;
begin
  LTransport := TTimeoutCaptureTransport.Create(3000);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LBody := HttpPatchString(LClient, 'http://localhost/test', 'text/plain', 'patch');
  CheckEqual('', LBody, 'PatchString returns empty body from 200');
end;

procedure TestHttpDeleteStringSuccess;
var
  LTransport: TTimeoutCaptureTransport;
  LClient: IHttpClient;
  LBody: string;
begin
  LTransport := TTimeoutCaptureTransport.Create(3000);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LBody := HttpDeleteString(LClient, 'http://localhost/test');
  CheckEqual('', LBody, 'DeleteString returns empty body from 200');
end;

procedure TestHttpDeleteStringRaisesOn404;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LCaught: Boolean;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LTransport.RedirectStatus := HTTP_STATUS_NOT_FOUND;
  LTransport.RedirectLocation := '';
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LCaught := False;
  try
    HttpDeleteString(LClient, 'http://localhost/error');
  except
    on E: EHttpError do
      LCaught := (Pos('404', E.Message) > 0);
  end;
  Check(LCaught, 'DeleteString raises EHttpError on 404');
end;

procedure TestHttpHeadSuccess;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LTransport.RedirectStatus := HTTP_STATUS_OK;
  LTransport.RedirectLocation := '';
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LResp := HttpHead(LClient, 'http://localhost/test');
  Check(LResp <> nil, 'HttpHead returns response');
  CheckEqual(200, LResp.StatusCode, 'HttpHead returns 200');
end;

procedure TestHttpHeadRaisesOn404;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LCaught: Boolean;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LTransport.RedirectStatus := HTTP_STATUS_NOT_FOUND;
  LTransport.RedirectLocation := '';
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LCaught := False;
  try
    HttpHead(LClient, 'http://localhost/missing');
  except
    on E: EHttpError do
      LCaught := (Pos('404', E.Message) > 0);
  end;
  Check(LCaught, 'HttpHead raises EHttpError on 404');
end;

procedure TestHttpOptionsSuccess;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LTransport.RedirectStatus := HTTP_STATUS_OK;
  LTransport.RedirectLocation := '';
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LResp := HttpOptions(LClient, 'http://localhost/test');
  Check(LResp <> nil, 'HttpOptions returns response');
  CheckEqual(200, LResp.StatusCode, 'HttpOptions returns 200');
end;

procedure TestHttpOptionsRaisesOn403;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LCaught: Boolean;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LTransport.RedirectStatus := HTTP_STATUS_FORBIDDEN;
  LTransport.RedirectLocation := '';
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LCaught := False;
  try
    HttpOptions(LClient, 'http://localhost/forbidden');
  except
    on E: EHttpError do
      LCaught := (Pos('403', E.Message) > 0);
  end;
  Check(LCaught, 'HttpOptions raises EHttpError on 403');
end;

procedure TestHttpPostJsonSuccess;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LDoc: IJsonDocument;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LTransport.RedirectStatus := HTTP_STATUS_OK;
  LTransport.RedirectLocation := '';
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LDoc := JsonParse('{"key":"value"}');
  // Should not raise; body is empty from mock transport
  HttpPostJson(LClient, 'http://localhost/test', LDoc);
end;

procedure TestHttpPutJsonSuccess;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LDoc: IJsonDocument;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LTransport.RedirectStatus := HTTP_STATUS_OK;
  LTransport.RedirectLocation := '';
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LDoc := JsonParse('{"id":1}');
  HttpPutJson(LClient, 'http://localhost/test', LDoc);
end;

procedure TestHttpPatchJsonSuccess;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LDoc: IJsonDocument;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LTransport.RedirectStatus := HTTP_STATUS_OK;
  LTransport.RedirectLocation := '';
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LDoc := JsonParse('{"name":"test"}');
  HttpPatchJson(LClient, 'http://localhost/test', LDoc);
end;

procedure TestHttpDeleteJsonSuccess;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LDoc: IJsonDocument;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LTransport.RedirectStatus := HTTP_STATUS_OK;
  LTransport.RedirectLocation := '';
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LDoc := JsonParse('{"id":1}');
  HttpDeleteJson(LClient, 'http://localhost/test', LDoc);
end;

{ Main }

begin
  T := TTestSuite.Create('nextpas.core.http.client.body_helpers');
  T.Test('HttpGetToWriter copies response body', @TestHttpGetToWriterCopiesResponseBody);
  T.Test('HttpGetToWriter closes body after successful copy',
    @TestHttpGetToWriterClosesBodyAfterSuccessfulCopy);
  T.Test('HttpGetToWriter closes body when copy fails',
    @TestHttpGetToWriterClosesBodyWhenCopyFails);
  T.Test('HttpGetToWriter keeps copy error when close fails',
    @TestHttpGetToWriterKeepsWriteErrorWhenCloseFails);
  T.Test('HttpGetToWriter closes non-2xx body before raising',
    @TestHttpGetToWriterClosesNon2xxBodyBeforeRaising);
  T.Test('HttpReadResponseBodyString reads live response body',
    @TestHttpReadResponseBodyStringReadsLiveResponse);
  T.Test('HttpReadResponseBodyString nil body returns empty',
    @TestHttpReadResponseBodyStringNilBodyReturnsEmpty);
  T.Test('HttpReadResponseBodyString closes body after read',
    @TestHttpReadResponseBodyStringClosesBodyAfterRead);
  T.Test('HttpReadResponseBodyString rejects nil response',
    @TestHttpReadResponseBodyStringRejectsNilResponse);
  T.Test('HttpReadResponseBodyBytes reads live response body',
    @TestHttpReadResponseBodyBytesReadsLiveResponse);
  T.Test('HttpReadResponseBodyBytes nil body returns empty',
    @TestHttpReadResponseBodyBytesNilBodyReturnsEmpty);
  T.Test('HttpReadResponseBodyBytes closes body after read',
    @TestHttpReadResponseBodyBytesClosesBodyAfterRead);
  T.Test('HttpReadResponseBodyBytes keeps read error when close fails',
    @TestHttpReadResponseBodyBytesKeepsReadErrorWhenCloseFails);
  T.Test('HttpReadResponseBodyBytes rejects nil response',
    @TestHttpReadResponseBodyBytesRejectsNilResponse);
  T.Test('ExtractCharsetFromContentType', @TestExtractCharsetFromContentType);
  T.Test('HttpReadResponseBodyStringAuto UTF-8', @TestHttpReadResponseBodyStringAutoUtf8);
  T.Test('HttpReadResponseBodyStringAuto Latin-1', @TestHttpReadResponseBodyStringAutoLatin1);
  T.Test('HttpReadResponseBodyStringAuto no charset', @TestHttpReadResponseBodyStringAutoNoCharset);
  T.Test('HttpDecodeContentEncoding gzip', @TestHttpDecodeContentEncodingGzip);
  T.Test('HttpDecodeContentEncoding deflate', @TestHttpDecodeContentEncodingDeflate);
  T.Test('HttpDecodeContentEncoding identity/empty',
    @TestHttpDecodeContentEncodingIdentityAndEmpty);
  T.Test('HttpDecodeContentEncoding unsupported br',
    @TestHttpDecodeContentEncodingUnsupported);
  T.Test('HttpDecodeContentEncoding multi-coding rejected',
    @TestHttpDecodeContentEncodingMultiCodingRejected);
  T.Test('HttpDecodeContentEncoding corrupt gzip',
    @TestHttpDecodeContentEncodingCorrupt);
  T.Test('HttpDecodeContentEncoding max size',
    @TestHttpDecodeContentEncodingMaxSize);
  T.Test('HttpReadResponseBodyBytesDecoded gzip',
    @TestHttpReadResponseBodyBytesDecodedGzip);
  T.Test('HttpReadResponseBodyBytesDecoded no encoding raw',
    @TestHttpReadResponseBodyBytesDecodedNoEncodingIsRaw);
  T.Test('HttpReadResponseBodyStringDecoded gzip',
    @TestHttpReadResponseBodyStringDecodedGzip);
  T.Test('HttpReadResponseBodyStringDecoded live CompressionMiddleware',
    @TestHttpReadResponseBodyBytesDecodedLiveCompression);
  T.Test('HttpReleaseResponseBody closes close-capable body',
    @TestHttpReleaseResponseBodyClosesCloseCapableBody);
  T.Test('HttpReleaseResponseBody drains plain reader',
    @TestHttpReleaseResponseBodyDrainsPlainReader);
  T.Test('HttpReleaseResponseBody nil body noop',
    @TestHttpReleaseResponseBodyNilBodyNoop);
  T.Test('HttpReleaseResponseBody rejects nil response',
    @TestHttpReleaseResponseBodyRejectsNilResponse);
  T.Test('HttpGetToFile writes final path atomically', @TestHttpGetToFileWritesFinalPathAtomically);
  T.Test('HttpGetToFile rejects 404 responses', @TestHttpGetToFileRejects404Responses);
  T.Test('HttpGetToFile cleans temp files on truncated body', @TestHttpGetToFileCleansTempFilesOnTruncatedBody);
  T.Test('HttpGetToFile keeps read error when close fails',
    @TestHttpGetToFileKeepsReadErrorWhenCloseFails);
  T.Test('HttpEnsureSuccess passes on 200', @TestHttpEnsureSuccess200);
  T.Test('HttpEnsureSuccess passes on 201', @TestHttpEnsureSuccess201);
  T.Test('HttpEnsureSuccess raises on 404', @TestHttpEnsureSuccessRaisesOn404);
  T.Test('HttpEnsureSuccess raises on 500', @TestHttpEnsureSuccessRaisesOn500);
  T.Test('HttpEnsureSuccess raises on nil', @TestHttpEnsureSuccessRaisesOnNil);
  T.Test('HttpEnsureSuccess context includes method/URL',
    @TestHttpEnsureSuccessContextIncludesMethodUrl);
  T.Test('GetString returns body on 200', @TestHttpGetStringSuccess);
  T.Test('GetString raises on 404', @TestHttpGetStringRaisesOn404);
  T.Test('GetBytes returns body on 200', @TestHttpGetBytesSuccess);
  T.Test('GetBytes raises on 500', @TestHttpGetBytesRaisesOn500);
  T.Test('HttpGetJson parses object on 200', @TestHttpGetJsonSuccess);
  T.Test('IHttpClient.GetJson parses object on 200', @TestHttpGetJsonMethodSuccess);
  T.Test('HttpGetJson raises hekStatus on 404', @TestHttpGetJsonRaisesOn404);
  T.Test('HttpGetJson raises hekProtocol Op=json on invalid body', @TestHttpGetJsonRaisesOnInvalidJson);
  T.Test('HttpPostJsonDocument parses object on 200', @TestHttpPostJsonDocumentSuccess);
  T.Test('HttpPostJsonDocument raises hekStatus on 404',
    @TestHttpPostJsonDocumentRaisesOn404);
  T.Test('HttpPostJsonDocument raises hekProtocol Op=json on invalid body',
    @TestHttpPostJsonDocumentRaisesOnInvalidJson);
  T.Test('HttpReadResponseJson parses object', @TestHttpReadResponseJsonSuccess);
  T.Test('HttpEnsureSuccess Op=ensure on non-2xx',
    @TestHttpEnsureSuccessOpIsEnsure);
  T.Test('PostString returns body on 200', @TestHttpPostStringSuccess);
  T.Test('PostString raises on 404', @TestHttpPostStringRaisesOn404);
  T.Test('PutString returns body on 200', @TestHttpPutStringSuccess);
  T.Test('PutString raises on 500', @TestHttpPutStringRaisesOn500);
  T.Test('PatchString returns body on 200', @TestHttpPatchStringSuccess);
  T.Test('DeleteString returns body on 200', @TestHttpDeleteStringSuccess);
  T.Test('DeleteString raises on 404', @TestHttpDeleteStringRaisesOn404);
  T.Test('Head returns response on 200', @TestHttpHeadSuccess);
  T.Test('Head raises on 404', @TestHttpHeadRaisesOn404);
  T.Test('Options returns response on 200', @TestHttpOptionsSuccess);
  T.Test('Options raises on 403', @TestHttpOptionsRaisesOn403);
  T.Test('PostJson sends JSON body', @TestHttpPostJsonSuccess);
  T.Test('PutJson sends JSON body', @TestHttpPutJsonSuccess);
  T.Test('PatchJson sends JSON body', @TestHttpPatchJsonSuccess);
  T.Test('DeleteJson sends JSON body', @TestHttpDeleteJsonSuccess);
  if not T.Run then Halt(1);
end.
