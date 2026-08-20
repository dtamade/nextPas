program test_http_client;

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
  { Streaming sink integration: raw listener writes body in two chunks with a
    sleep between them; client asserts live per-chunk dispatch. }
  GStreamListener: ITcpListener;
  { Raw listener replying a non-2xx status with a JSON body. }
  GStatusErrorListener: ITcpListener;
  { Raw listener replying headers + Content-Length: 0 (zero-body streaming
    response; status-split must complete at the header block). }
  GZeroBodyListener: ITcpListener;

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

type
  { Collects streamed body chunks; asserts live dispatch order/content. }
  TClientChunkSink = class
  public
    FChunks: Int32;
    FTotal: string;
    procedure OnBodyChunk(const AData: PByte; ASize: SizeUInt);
  end;

  { ResponseStatus + body chunk sink with an ordering trace: records the call
     order so tests can assert status fires before the first body chunk. }
  TClientStreamSink = class
  public
    FOrder: Int32;
    FStatusCalls: Int32;
    FStatusOrder: Int32;
    FStatusValue: THttpStatus;
    FChunks: Int32;
    FFirstChunkOrder: Int32;
    FTotal: string;
    procedure OnResponseStatus(const AStatus: THttpStatus);
    procedure OnBodyChunk(const AData: PByte; ASize: SizeUInt);
  end;

procedure TClientChunkSink.OnBodyChunk(const AData: PByte; ASize: SizeUInt);
var
  LStr: string;
begin
  Inc(FChunks);
  if ASize = 0 then
    Exit;
  SetLength(LStr, SizeInt(ASize));
  Move(AData^, LStr[1], ASize);
  FTotal := FTotal + LStr;
end;

procedure TClientStreamSink.OnResponseStatus(const AStatus: THttpStatus);
begin
  Inc(FStatusCalls);
  FStatusValue := AStatus;
  Inc(FOrder);
  FStatusOrder := FOrder;
end;

procedure TClientStreamSink.OnBodyChunk(const AData: PByte; ASize: SizeUInt);
var
  LStr: string;
begin
  Inc(FChunks);
  if FFirstChunkOrder = 0 then
  begin
    Inc(FOrder);
    FFirstChunkOrder := FOrder;
  end;
  if ASize = 0 then
    Exit;
  SetString(LStr, PAnsiChar(AData), SizeInt(ASize));
  FTotal := FTotal + LStr;
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

{ Raw listener that writes a Content-Length body in two chunks with a 250ms
  gap, so the client-side streaming sink can observe live dispatch. }
function StreamChunkThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LAccum: string;
  LHead: string;
  LPart1: string;
  LPart2: string;
  LP: SizeInt;
begin
  Result := nil;
  try
    LConn := GStreamListener.Accept;
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

    LHead := 'HTTP/1.1 200 OK'#13#10'Content-Length: 11'#13#10#13#10;
    LPart1 := 'hello ';
    LPart2 := 'world';
    LConn.Write(LHead[1], SizeUInt(Length(LHead)));
    LConn.Write(LPart1[1], SizeUInt(Length(LPart1)));
    platform_thread_sleep_ns(250000000);
    LConn.Write(LPart2[1], SizeUInt(Length(LPart2)));
  except
  end;
  LConn.Close;
end;

{ Raw listener replying 429 with a small JSON body — error-transparent path
  exercises ResponseStatus on a non-2xx final response. }
function ErrorStatusThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LAccum: string;
  LHead: string;
  LP: SizeInt;
begin
  Result := nil;
  try
    LConn := GStatusErrorListener.Accept;
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
    LHead := 'HTTP/1.1 429 Too Many Requests'#13#10 +
             'Content-Type: application/json'#13#10 +
             'Content-Length: 24'#13#10#13#10 +
             '{"error":"rate limited"}';
    LConn.Write(LHead[1], SizeUInt(Length(LHead)));
  except
  end;
  LConn.Close;
end;

{ Raw listener replying with headers + Content-Length: 0 — zero body bytes at
  all. Status-split streaming must complete the message at the header block
  instead of pausing forever waiting for a body chunk that never arrives. }
function ZeroBodyStreamThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LAccum: string;
  LHead: string;
  LP: SizeInt;
begin
  Result := nil;
  try
    LConn := GZeroBodyListener.Accept;
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
    LHead := 'HTTP/1.1 200 OK'#13#10 +
             'Content-Type: text/event-stream'#13#10 +
             'Content-Length: 0'#13#10#13#10;
    LConn.Write(LHead[1], SizeUInt(Length(LHead)));
  except
  end;
  LConn.Close;
end;

{ Raw listener replying with the FULL response (headers + body) in a single
  write — mirrors a coalesced read where llhttp sees the final headers and the
  whole body inside one Execute call. This is the exact shape that used to
  dispatch body chunks before the ResponseStatus callback. }
function CoalescedBodyThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LAccum: string;
  LHead: string;
  LP: SizeInt;
begin
  Result := nil;
  try
    LConn := GStreamListener.Accept;
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
    LHead := 'HTTP/1.1 200 OK'#13#10'Content-Length: 11'#13#10#13#10 +
             'hello world';
    LConn.Write(LHead[1], SizeUInt(Length(LHead)));
  except
  end;
  LConn.Close;
end;

{ Raw listener sending a lone 100 Continue first (so the client consumes it in
  its own read and resets to a fresh parser for the final response), then the
  final 200 with headers + body coalesced in one write. Exercises the
  status-split mount on the informational-reset parser. }
function InformationalThenCoalescedThread(AArg: Pointer): Pointer; cdecl;
var
  LConn: ITcpStream;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LAccum: string;
  LInform: string;
  LFinal: string;
  LP: SizeInt;
begin
  Result := nil;
  try
    LConn := GStreamListener.Accept;
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
    LInform := 'HTTP/1.1 100 Continue'#13#10#13#10;
    LConn.Write(LInform[1], SizeUInt(Length(LInform)));
    platform_thread_sleep_ns(200000000);
    LFinal := 'HTTP/1.1 200 OK'#13#10'Content-Length: 11'#13#10#13#10 +
              'hello world';
    LConn.Write(LFinal[1], SizeUInt(Length(LFinal)));
  except
  end;
  LConn.Close;
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
    AW.GetHeaders.SetHeader('content-length', '5');
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

procedure TestClientSendRejectsNilRequest;
var
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LRaised: Boolean;
begin
  LClient := NewHttpClient;
  LReq := nil;
  LRaised := False;
  try
    LClient.Send(LReq);
  except
    on E: EHttpError do
      LRaised := E.Kind = hekArgument;
  end;
  Check(LRaised, 'Client.Send rejects nil request');
end;

procedure TestH1ClientTransportRejectsNilRequestInputs;
var
  LTransport: IHttpTransport;
  LOptions: TH1ClientTransportOptions;
  LReq: IHttpRequest;
  LRaised: Boolean;
begin
  LOptions := Default(TH1ClientTransportOptions);
  LTransport := NewH1ClientTransport(LOptions);

  LRaised := False;
  try
    LTransport.RoundTrip(nil);
  except
    on E: EHttpError do
      LRaised := E.Kind = hekArgument;
  end;
  Check(LRaised, 'H1 transport RoundTrip rejects nil request as hekArgument');

  LReq := TNilHeadersRequest.Create('http://127.0.0.1:1/no-connect') as IHttpRequest;
  LRaised := False;
  try
    LTransport.RoundTrip(LReq);
  except
    on E: EHttpError do
      LRaised := E.Kind = hekArgument;
  end;
  Check(LRaised, 'H1 transport RoundTrip rejects nil request headers as hekArgument');
end;

procedure TestClientSendRejectsNilTransportResponse;
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
    LClient.Send(LReq);
  except
    on E: EHttpError do
      LRaised := True;
  end;

  Check(LRaised, 'Client.Send rejects nil transport response');
end;

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
    AW.GetHeaders.SetHeader('content-length', '2');
    AW.GetHeaders.SetHeader('x-echo', LGotHeader);
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LUrl := TUrl.Parse('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/echo-header');
    LReq := THttpRequest.Create(hmGet, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
    LReq.Headers.SetHeader('x-custom', 'hello-from-client');
    LResp := LClient.Send(LReq);
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    CheckEqual('hello-from-client', LResp.Headers.Get('x-echo'), 'custom header echoed');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientSendWithBasicAuthHelper;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LReq: IHttpRequest;
  LHeaders: IHttpHeaders;
  LGotAuth: string;
begin
  LGotAuth := '';
  LRouter := THttpRouter.Create;
  LRouter.Get('/auth', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var
    LB: string;
  begin
    LGotAuth := AReq.Headers.Get('authorization');
    LB := 'ok';
    AW.GetHeaders.SetHeader('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LHeaders := NewHeaders;
    SetBasicAuth(LHeaders, 'Aladdin', 'open sesame');
    LReq := THttpRequestBuilder.Create(hmGet, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/auth').Headers(LHeaders).Build;

    LResp := LClient.Send(LReq);

    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    CheckEqual('Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==', LGotAuth,
      'basic auth helper header forwarded');
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
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LB))));
    AW.WriteHeader(HTTP_STATUS_CREATED);
    AW.Write(LB[1], SizeUInt(Length(LB)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LPostData := 'key=value';
    LResp := LClient.Post(
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/submit',
      'application/x-www-form-urlencoded',
      LPostData);
    CheckEqual(Int64(201), Int64(LResp.StatusCode), 'status 201');
    LBody := ReadBodyStr(LResp);
    CheckEqual('accepted', LBody, 'body matches');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientSendWithRequestHelperHeadersBody;
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
    AW.GetHeaders.SetHeader('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LHeaders := NewHeaders;
    LHeaders.SetHeader('x-client', 'request-helper');
    LReq := nextpas.core.http.THttpRequestBuilder.Create(hmPost, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/builder').Headers(LHeaders).Body('payload').Build;

    LResp := LClient.Send(LReq);

    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    CheckEqual('request-helper', LGotHeader, 'custom header forwarded');
    CheckEqual(Int64(7), LGotContentLength, 'content-length forwarded');
    CheckEqual('payload', LGotBody, 'body forwarded');
    CheckEqual('ok', ReadBodyStr(LResp), 'response body');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientSendWithRequestHelperHeadersOnly;
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
  LGotHasContentLengthHeader: Boolean;
  LGotContentLength: Int64;
  LGotBodyWasNil: Boolean;
  LGotPath: string;
  LGotQuery: string;
begin
  LGotHeader := '';
  LGotHasContentLengthHeader := True;
  LGotContentLength := -1;
  LGotBodyWasNil := False;
  LGotPath := '';
  LGotQuery := '';
  LRouter := THttpRouter.Create;
  LRouter.Get('/headers-only', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LB: string;
  begin
    LGotHeader := AReq.Headers.Get('x-client');
    LGotHasContentLengthHeader := AReq.Headers.Has('content-length');
    LGotContentLength := AReq.ContentLength;
    LGotBodyWasNil := AReq.Body = nil;
    LGotPath := AReq.Path;
    LGotQuery := AReq.RawQuery;
    LB := 'ok';
    AW.GetHeaders.SetHeader('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LHeaders := NewHeaders;
    LHeaders.SetHeader('x-client', 'headers-only');
    LReq := nextpas.core.http.THttpRequestBuilder.Create(hmGet, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/headers-only?x=1').Headers(LHeaders).Build;
    Check(not LReq.Headers.Has('content-length'),
      'headers-only helper does not populate content-length during request construction');

    LResp := LClient.Send(LReq);

    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    CheckEqual('headers-only', LGotHeader, 'custom header forwarded');
    Check(not LGotHasContentLengthHeader,
      'headers-only helper does not publish content-length header to the server');
    CheckEqual(Int64(0), LGotContentLength, 'headers-only helper keeps zero content-length');
    Check(LGotBodyWasNil, 'headers-only helper keeps request body nil');
    CheckEqual('/headers-only', LGotPath, 'headers-only helper preserves path');
    CheckEqual('x=1', LGotQuery, 'headers-only helper preserves query');
    CheckEqual('ok', ReadBodyStr(LResp), 'response body');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientSendWithRequestHelperBytesBody;
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
    AW.GetHeaders.SetHeader('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LHeaders := NewHeaders;
    LHeaders.SetHeader('x-client', 'bytes-helper');
    SetLength(LBody, 5);
    LBody[0] := Ord('b');
    LBody[1] := Ord('i');
    LBody[2] := Ord('n');
    LBody[3] := 0;
    LBody[4] := 255;
    LReq := nextpas.core.http.THttpRequestBuilder.Create(hmPost, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/bytes').Headers(LHeaders).Body(LBody).Build;

    LResp := LClient.Send(LReq);

    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    CheckEqual(Int64(5), LGotContentLength, 'bytes content-length forwarded');
    CheckEqual('bin' + #0 + #255, LGotBody, 'bytes body forwarded');
    CheckEqual('ok', ReadBodyStr(LResp), 'response body');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientSendWithRequestHelperStringBodyWithoutHeaders;
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
    AW.GetHeaders.SetHeader('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LReq := nextpas.core.http.THttpRequestBuilder.Create(hmPost, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/no-headers-string').Body('payload').Build;

    LResp := LClient.Send(LReq);

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

procedure TestClientSendWithRequestHelperBytesBodyWithoutHeaders;
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
    AW.GetHeaders.SetHeader('content-length', '2');
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
    LReq := nextpas.core.http.THttpRequestBuilder.Create(hmPost, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/no-headers-bytes').Body(LBody).ContentLength(0).Build;

    LResp := LClient.Send(LReq);

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

procedure TestClientSendWithRequestHelperStringBodyAndContentTypeWithoutHeaders;
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
    AW.GetHeaders.SetHeader('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LReq := nextpas.core.http.THttpRequestBuilder.Create(hmPost, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/content-type-string').ContentType('text/plain; charset=utf-8').Body('payload').Build;

    LResp := LClient.Send(LReq);

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

procedure TestClientSendWithRequestHelperBytesBodyAndContentTypeWithoutHeaders;
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
    AW.GetHeaders.SetHeader('content-length', '2');
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
    LReq := nextpas.core.http.THttpRequestBuilder.Create(hmPost, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/content-type-bytes').ContentType('application/octet-stream').Body(LBody).Build;

    LResp := LClient.Send(LReq);

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

procedure TestH1ClientTransportDestroyClosesIdlePoolSourceContract;
var
  LSource: string;
  LDestroyPos: SizeInt;
  LDestroyBlock: string;
begin
  { Owner: impl.h1.client (STRUCT residual extract from impl.h1). }
  LSource := ReadFileText('../../../src/nextpas.core.http.impl.h1.client.pas');
  Check(Pos('destructor Destroy; override;', LSource) > 0,
    'h1 client transport declares destructor for idle-pool ownership');
  LDestroyPos := Pos('destructor TH1ClientTransport.Destroy;', LSource);
  Check(LDestroyPos > 0,
    'h1 client transport implements destructor for idle-pool ownership');
  if LDestroyPos > 0 then
  begin
    LDestroyBlock := Copy(LSource, LDestroyPos, 256);
    Check((Pos('FPool.Free', LDestroyBlock) > 0) or
          (Pos('FPool.Clear', LDestroyBlock) > 0),
      'h1 client transport destructor closes pooled idle connections');
  end;
end;

procedure TestH1ClientPoolMaxSizePerAuthoritySourceContract;
var
  LSource: string;
  LPutPos: SizeInt;
  LPutBlock: string;
begin
  { STRUCT-1: pool body lives in impl.h1.pool. }
  LSource := ReadFileText('../../../src/nextpas.core.http.impl.h1.pool.pas');
  LPutPos := Pos('procedure TH1IdleConnectionPool.Put(', LSource);
  Check(LPutPos > 0, 'h1 PoolPut is present');
  if LPutPos > 0 then
  begin
    { Window covers per-authority MaxPoolSize, IdleTTL stamp, expire eviction,
      and close-outside-lock tail (Wave R1). }
    LPutBlock := Copy(LSource, LPutPos, 2400);
    Check(Pos('LAuthorityIdle', LPutBlock) > 0,
      'h1 PoolPut counts idle connections per authority');
    Check(Pos('FCount >= FMaxPoolSize', LPutBlock) = 0,
      'h1 PoolPut does not use global FPoolCount as MaxPoolSize cap');
    Check(Pos('LAuthorityIdle >= FMaxPoolSize', LPutBlock) > 0,
      'h1 PoolPut enforces MaxPoolSize against per-authority idle count');
    Check(Pos('IdleAtMs', LPutBlock) > 0,
      'h1 PoolPut stamps IdleAtMs for IdleTTL');
    Check(Pos('EntryExpired', LPutBlock) > 0,
      'h1 PoolPut evicts expired idle peers before MaxPoolSize count');
    Check(Pos('LToClose', LPutBlock) > 0,
      'h1 PoolPut defers Close outside FPoolLock');
  end;
end;

procedure TestH1ClientPooledRetryFreshFailureClosesConnectionSourceContract;
var
  LSource: string;
  LReconnectPos: SizeInt;
  LReconnectBlock: string;
begin
  { Owner: impl.h1.client (STRUCT residual extract from impl.h1). }
  LSource := ReadFileText('../../../src/nextpas.core.http.impl.h1.client.pas');
  LReconnectPos := Pos(
    'RewindRetryBody(AReq, LBodyStream, LBodyStartPosition);', LSource);
  Check(LReconnectPos > 0,
    'h1 client pooled retry reconnect path is present');
  if LReconnectPos > 0 then
  begin
    { Window covers ConnectTimeout re-arm, cancel checkpoints, timeout-wrap,
      dial helper, cancel token wire, and bare re-raise on the fresh path. }
    LReconnectBlock := Copy(LSource, LReconnectPos, 2200);
    Check((Pos('PrepareFreshConnection;', LReconnectBlock) > 0) or
          (Pos('LConn := H1ClientDial(LConnectHost, LConnectPort,', LReconnectBlock) > 0) or
          (Pos('LConn := TcpConnect(LConnectHost, LConnectPort);', LReconnectBlock) > 0) or
          (Pos('LConn := TcpConnect(LHost, LPort);', LReconnectBlock) > 0),
      'h1 client pooled retry opens a fresh connection after body rewind');
    Check(Pos('try', LReconnectBlock) > 0,
      'h1 client pooled retry wraps fresh connection operations');
    Check(Pos('except', LReconnectBlock) > 0,
      'h1 client pooled retry handles fresh connection failure');
    Check(Pos('LConn.Close;', LReconnectBlock) > 0,
      'h1 client pooled retry closes fresh connection on failure');
    Check(Pos('raise;', LReconnectBlock) > 0,
      'h1 client pooled retry preserves the original fresh failure');
    Check(Pos('HttpWrapTransportException', LReconnectBlock) > 0,
      'h1 client pooled retry wraps bare transport timeout/connect errors');
  end;
end;

procedure TestOpenSSLContextFreesPinValidatorSourceContract;
var
  LSource: string;
  LDestroyPos: SizeInt;
  LDestroyBlock: string;
begin
  { Wave X4: TPinValidator is a owned TObject on SSL context; must FreeAndNil
    in Destroy or each CreateContext leaves a ~32-byte residual. }
  LSource := ReadFileText('../../../src/nextpas.core.tls.openssl.context.pas');
  LDestroyPos := Pos('destructor TOpenSSLContext.Destroy;', LSource);
  Check(LDestroyPos > 0, 'OpenSSL context destructor is present');
  if LDestroyPos > 0 then
  begin
    LDestroyBlock := Copy(LSource, LDestroyPos, 500);
    Check(Pos('FreeAndNil(FPinValidator)', LDestroyBlock) > 0,
      'OpenSSL context Destroy frees owned FPinValidator');
  end;
end;

procedure TestWindowsCancelWaitablePairSourceContract;
var
  LCancelSrc: string;
  LPlatformSrc: string;
  LPairPos: SizeInt;
  LPairBlock: string;
begin
  { Wave PD-3-3: Windows platform_socket_pair emulates socketpair via TCP
    loopback so NewNetCancelToken gets a waitable wake (same as Unix path). }
  LCancelSrc := ReadFileText('../../../src/nextpas.core.net.cancel.pas');
  Check(Pos('platform_socket_pair', LCancelSrc) > 0,
    'net.cancel attempts platform_socket_pair for waitable wake');
  Check(Pos('Falls back to probe-only only if platform_socket_pair fails', LCancelSrc) > 0,
    'net.cancel documents probe-only as pair-failure fallback only');
  Check(Pos('Windows falls back to probe-only', LCancelSrc) = 0,
    'net.cancel no longer claims Windows is always probe-only');
  LPlatformSrc := ReadFileText('../../../src/nextpas.core.platform.socket.pas');
  LPairPos := Pos('No native socketpair on Windows', LPlatformSrc);
  Check(LPairPos > 0, 'Windows platform_socket_pair documents loopback emulation');
  LPairBlock := Copy(LPlatformSrc, LPairPos, 2500);
  Check(Pos('platform_sockaddr_loopback4', LPairBlock) > 0,
    'Windows pair uses loopback bind');
  Check(Pos('platform_socket_connect', LPairBlock) > 0,
    'Windows pair connects write end');
  Check(Pos('platform_socket_accept', LPairBlock) > 0,
    'Windows pair accepts read end');
  Check(Pos('PLATFORM_ERR_UNSUPPORTED', LPairBlock) > 0,
    'Windows pair still returns UNSUPPORTED for non-STREAM');
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
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LB))));
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
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LB))));
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
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LB))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], SizeUInt(Length(LB)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Put(
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/resource',
      'application/json',
      '{"name":"next"}');
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
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LB))));
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
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LB))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], SizeUInt(Length(LB)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Patch(
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/resource',
      'application/merge-patch+json',
      '{"enabled":true}');
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
    AW.GetHeaders.SetHeader('content-length', '5');
    AW.GetHeaders.SetHeader('x-head-ok', 'yes');
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

procedure TestClientOptionsSendsOptions;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LGotMethod: THttpMethod;
begin
  LGotMethod := hmGet;
  LRouter := THttpRouter.Create;
  LRouter.Handle(hmOptions, '/resource', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LGotMethod := AReq.Method;
    AW.GetHeaders.SetHeader('allow', 'GET, HEAD, OPTIONS');
    AW.GetHeaders.SetHeader('content-length', '0');
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Options('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/resource');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    Check(LGotMethod = hmOptions, 'server received OPTIONS');
    CheckEqual('GET, HEAD, OPTIONS', LResp.Headers.Get('allow'), 'allow header present');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientPostFormEncodesFields;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LGotMethod: THttpMethod;
  LGotContentType: string;
  LFields: TFormFieldArray;
begin
  LGotMethod := hmGet;
  LGotContentType := '';
  LRouter := THttpRouter.Create;
  LRouter.Handle(hmPost, '/submit', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LGotMethod := AReq.Method;
    LGotContentType := AReq.Headers.Get('content-type');
    AW.GetHeaders.SetHeader('content-length', '0');
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    SetLength(LFields, 2);
    LFields[0].Name := 'user';
    LFields[0].Value := 'alice';
    LFields[1].Name := 'pass';
    LFields[1].Value := 'secret';
    LClient := NewHttpClient;
    LResp := LClient.PostForm('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/submit', LFields);
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    Check(LGotMethod = hmPost, 'server received POST');
    CheckEqual('application/x-www-form-urlencoded', LGotContentType, 'content-type set');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientPostJsonSendsJson;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LGotMethod: THttpMethod;
  LGotContentType: string;
  LDoc: IJsonDocument;
begin
  LGotMethod := hmGet;
  LGotContentType := '';
  LRouter := THttpRouter.Create;
  LRouter.Handle(hmPost, '/api', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LGotMethod := AReq.Method;
    LGotContentType := AReq.Headers.Get('content-type');
    AW.GetHeaders.SetHeader('content-length', '0');
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LDoc := JsonParse('{"name":"alice","age":30}');
    LClient := NewHttpClient;
    LResp := LClient.PostJson('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/api', LDoc.Root);
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    Check(LGotMethod = hmPost, 'server received POST');
    CheckEqual('application/json', LGotContentType, 'content-type is application/json');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientDeleteWithBody;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LGotMethod: THttpMethod;
  LGotContentType: string;
  LGotBody: string;
begin
  LGotMethod := hmGet;
  LGotContentType := '';
  LGotBody := '';
  LRouter := THttpRouter.Create;
  LRouter.Handle(hmDelete, '/resource', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LGotMethod := AReq.Method;
    LGotContentType := AReq.Headers.Get('content-type');
    if AReq.Body <> nil then
      LGotBody := ReadReaderStr(AReq.Body);
    AW.GetHeaders.SetHeader('content-length', '0');
    AW.WriteHeader(HTTP_STATUS_NO_CONTENT);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Delete('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/resource',
      'application/json', '{"id":42}');
    Check(LGotMethod = hmDelete, 'server received DELETE');
    CheckEqual('application/json', LGotContentType, 'content-type set');
    CheckEqual('{"id":42}', LGotBody, 'body sent');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientDeleteJson;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LGotMethod: THttpMethod;
  LGotContentType: string;
  LDoc: IJsonDocument;
begin
  LGotMethod := hmGet;
  LGotContentType := '';
  LRouter := THttpRouter.Create;
  LRouter.Handle(hmDelete, '/api', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LGotMethod := AReq.Method;
    LGotContentType := AReq.Headers.Get('content-type');
    AW.GetHeaders.SetHeader('content-length', '0');
    AW.WriteHeader(HTTP_STATUS_NO_CONTENT);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LDoc := JsonParse('{"id":123}');
    LClient := NewHttpClient;
    LResp := LClient.DeleteJson('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/api', LDoc.Root);
    Check(LGotMethod = hmDelete, 'server received DELETE');
    CheckEqual('application/json', LGotContentType, 'content-type is application/json');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientWithBasicAuthSetsHeader;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LGotAuth: string;
begin
  LGotAuth := '';
  LRouter := THttpRouter.Create;
  LRouter.Handle(hmGet, '/secret', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LGotAuth := AReq.Headers.Get('authorization');
    AW.GetHeaders.SetHeader('content-length', '0');
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient.WithBasicAuth('admin', 's3cret');
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/secret');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    Check(Pos('Basic ', LGotAuth) = 1, 'authorization starts with Basic');
    Check(Length(LGotAuth) > 6, 'authorization has value');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientWithBearerAuthSetsHeader;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LGotAuth: string;
begin
  LGotAuth := '';
  LRouter := THttpRouter.Create;
  LRouter.Handle(hmGet, '/api', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LGotAuth := AReq.Headers.Get('authorization');
    AW.GetHeaders.SetHeader('content-length', '0');
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient.WithBearerAuth('mytoken123');
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/api');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    CheckEqual('Bearer mytoken123', LGotAuth, 'bearer token set');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientWithHeaderSetsCustomHeader;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LGotUA: string;
begin
  LGotUA := '';
  LRouter := THttpRouter.Create;
  LRouter.Handle(hmGet, '/test', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LGotUA := AReq.Headers.Get('user-agent');
    AW.GetHeaders.SetHeader('content-length', '0');
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient.WithHeader('user-agent', 'nextPasTest/1.0');
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/test');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    CheckEqual('nextPasTest/1.0', LGotUA, 'custom header set');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientWithHeaderChainsWithAuth;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LGotAuth: string;
  LGotAccept: string;
begin
  LGotAuth := '';
  LGotAccept := '';
  LRouter := THttpRouter.Create;
  LRouter.Handle(hmGet, '/api', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LGotAuth := AReq.Headers.Get('authorization');
    LGotAccept := AReq.Headers.Get('accept');
    AW.GetHeaders.SetHeader('content-length', '0');
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient
      .WithBearerAuth('mytoken')
      .WithHeader('accept', 'application/json');
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/api');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    CheckEqual('Bearer mytoken', LGotAuth, 'auth header from chain');
    CheckEqual('application/json', LGotAccept, 'accept header from chain');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientWithHeaderMultipleHeaders;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LGotUA: string;
  LGotAccept: string;
begin
  LGotUA := '';
  LGotAccept := '';
  LRouter := THttpRouter.Create;
  LRouter.Handle(hmGet, '/multi', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LGotUA := AReq.Headers.Get('user-agent');
    LGotAccept := AReq.Headers.Get('accept');
    AW.GetHeaders.SetHeader('content-length', '0');
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient
      .WithHeader('user-agent', 'nextPas/2.0')
      .WithHeader('accept', 'text/html');
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/multi');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    CheckEqual('nextPas/2.0', LGotUA, 'user-agent from chain');
    CheckEqual('text/html', LGotAccept, 'accept from chain');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientWithHeaderDoesNotAffectOriginalClient;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LOriginal: IHttpClient;
  LDecorated: IHttpClient;
  LResp: IHttpResponse;
  LGotUA: string;
begin
  LGotUA := '';
  LRouter := THttpRouter.Create;
  LRouter.Handle(hmGet, '/orig', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  begin
    LGotUA := AReq.Headers.Get('user-agent');
    AW.GetHeaders.SetHeader('content-length', '0');
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LOriginal := NewHttpClient;
    LDecorated := LOriginal.WithHeader('user-agent', 'decorated/1.0');
    LResp := LOriginal.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/orig');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'original status 200');
    Check(LGotUA <> 'decorated/1.0', 'original client unaffected');
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

procedure TestClientDoesNotPoolResponseWithConnectionCloseTokenList;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
  LRaised: Boolean;
begin
  GRawAcceptCount := 0;
  GRawResponse1 := 'HTTP/1.1 200 OK'#13#10 +
                   'Content-Length: 2'#13#10 +
                   'Connection: keep-alive, close'#13#10 +
                   #13#10 +
                   'ok';
  GRawResponse2 := 'HTTP/1.1 200 OK'#13#10 +
                   'Content-Length: 8'#13#10 +
                   'Connection: close'#13#10 +
                   #13#10 +
                   'fresh-ok';
  GRawAcceptLimit := 2;
  GRawListener := NetTcpListen('127.0.0.1', 0);
  LPort := GRawListener.LocalAddr.Port;
  platform_thread_create(LHandle, @RawResponseThread, nil);

  try
    LClient := NewHttpClient;
    LResp := LClient.Get('http://127.0.0.1:' +
      IntToStr(Int64(LPort)) + '/prime');
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'connection close token-list priming response status');
    CheckEqual('ok', ReadBodyStr(LResp),
      'connection close token-list priming response body');

    LReq := THttpRequestBuilder.Create(hmPost, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/upload').Headers(NewHeaders).Body(StringBodyReader('payload')).ContentLength(Int64(7)).Build;
    LRaised := False;
    try
      LResp := LClient.Send(LReq);
    except
      on E: Exception do
        LRaised := True;
    end;

    Check(not LRaised,
      'client does not reuse response connection with close token-list');
    if not LRaised then
    begin
      CheckEqual(Int64(200), Int64(LResp.StatusCode),
        'fresh request after close token-list response succeeds');
      CheckEqual('fresh-ok', ReadBodyStr(LResp),
        'fresh request after close token-list response body');
    end;
    CheckEqual(Int64(2), Int64(GRawAcceptCount),
      'close token-list response makes next request open a fresh connection');
  finally
    if GRawAcceptCount < 2 then
      WakeRetryAcceptThread(LPort);
    GRawListener.Close;
    platform_thread_join(LHandle, LRet);
    GRawListener := nil;
    GRawAcceptCount := 0;
    GRawResponse1 := '';
    GRawResponse2 := '';
    GRawAcceptLimit := 0;
  end;
end;

procedure TestClientStreamingBodyChunkSink;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
  LSink: TClientChunkSink;
begin
  GStreamListener := NetTcpListen('127.0.0.1', 0);
  LPort := GStreamListener.LocalAddr.Port;
  platform_thread_create(LHandle, @StreamChunkThread, nil);
  LSink := TClientChunkSink.Create;
  try
    LClient := NewHttpClient;
    LReq := THttpRequestBuilder.Create(hmGet,
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/stream')
      .ResponseBodyChunk(@LSink.OnBodyChunk).Build;
    LResp := LClient.Send(LReq);
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'streamed response status');
    CheckEqual('hello world', LSink.FTotal,
      'sink received complete streamed body');
    Check(LSink.FChunks >= 2,
      'sink dispatched multiple chunks across the 250ms gap');
    { Full buffered body still consistent (NewBodyReader snapshot path). }
    CheckEqual('hello world', ReadBodyStr(LResp),
      'buffered response body matches streamed body');
  finally
    GStreamListener.Close;
    platform_thread_join(LHandle, LRet);
    GStreamListener := nil;
    LSink.Free;
  end;
end;

procedure TestClientResponseStatusFiresBeforeBodyChunks;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
  LSink: TClientStreamSink;
begin
  GStreamListener := NetTcpListen('127.0.0.1', 0);
  LPort := GStreamListener.LocalAddr.Port;
  platform_thread_create(LHandle, @StreamChunkThread, nil);
  LSink := TClientStreamSink.Create;
  try
    LClient := NewHttpClient;
    LReq := THttpRequestBuilder.Create(hmGet,
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/stream')
      .ResponseStatus(@LSink.OnResponseStatus)
      .ResponseBodyChunk(@LSink.OnBodyChunk).Build;
    LResp := LClient.Send(LReq);
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'status-callback response status');
    CheckEqual(Int64(1), Int64(LSink.FStatusCalls),
      'status callback fires exactly once');
    CheckEqual(Int64(200), Int64(LSink.FStatusValue),
      'status callback reports 200');
    Check(LSink.FStatusOrder > 0, 'status callback observed in order trace');
    Check(LSink.FFirstChunkOrder > LSink.FStatusOrder,
      'status callback fires before first body chunk');
    CheckEqual('hello world', LSink.FTotal,
      'status+chunk sink received full body');
    CheckEqual('hello world', ReadBodyStr(LResp),
      'buffered body intact when status callback is set');
  finally
    GStreamListener.Close;
    platform_thread_join(LHandle, LRet);
    GStreamListener := nil;
    LSink.Free;
  end;
end;

procedure TestClientResponseStatusPrecedesCoalescedBodyChunk;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
  LSink: TClientStreamSink;
begin
  { Headers + body arrive in a single read: llhttp parses the final response
    headers and the body inside one Execute call. Regression guard — the
    status callback must still fire before any body chunk (coalesced-read
    ordering used to be inverted and dropped streamed frames). }
  GStreamListener := NetTcpListen('127.0.0.1', 0);
  LPort := GStreamListener.LocalAddr.Port;
  platform_thread_create(LHandle, @CoalescedBodyThread, nil);
  LSink := TClientStreamSink.Create;
  try
    LClient := NewHttpClient;
    LReq := THttpRequestBuilder.Create(hmGet,
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/coalesced')
      .ResponseStatus(@LSink.OnResponseStatus)
      .ResponseBodyChunk(@LSink.OnBodyChunk).Build;
    LResp := LClient.Send(LReq);
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'coalesced response status');
    CheckEqual(Int64(1), Int64(LSink.FStatusCalls),
      'status callback fires exactly once on coalesced response');
    CheckEqual(Int64(200), Int64(LSink.FStatusValue),
      'status callback reports 200 on coalesced response');
    Check(LSink.FStatusOrder > 0, 'status callback observed in order trace');
    Check(LSink.FFirstChunkOrder > LSink.FStatusOrder,
      'status callback fires before first body chunk on coalesced response');
    CheckEqual('hello world', LSink.FTotal,
      'coalesced response body fully streamed to chunk sink');
    CheckEqual('hello world', ReadBodyStr(LResp),
      'buffered body intact on coalesced response');
  finally
    GStreamListener.Close;
    platform_thread_join(LHandle, LRet);
    GStreamListener := nil;
    LSink.Free;
  end;
end;

procedure TestClientResponseStatusPrecedesCoalescedBodyChunkAfterInformational;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
  LSink: TClientStreamSink;
begin
  { A lone 1xx forces the transport to reset to a fresh parser for the final
    response; that parser must also split status from body when the final
    response's headers + body arrive coalesced. Regression guard for the
    status-split mount on the informational-reset parser. }
  GStreamListener := NetTcpListen('127.0.0.1', 0);
  LPort := GStreamListener.LocalAddr.Port;
  platform_thread_create(LHandle, @InformationalThenCoalescedThread, nil);
  LSink := TClientStreamSink.Create;
  try
    LClient := NewHttpClient;
    LReq := THttpRequestBuilder.Create(hmGet,
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/inform-then-coalesced')
      .ResponseStatus(@LSink.OnResponseStatus)
      .ResponseBodyChunk(@LSink.OnBodyChunk).Build;
    LResp := LClient.Send(LReq);
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'final response status after informational reset');
    CheckEqual(Int64(1), Int64(LSink.FStatusCalls),
      'status callback fires exactly once after informational reset');
    CheckEqual(Int64(200), Int64(LSink.FStatusValue),
      'status callback reports final 200, not the 100');
    Check(LSink.FStatusOrder > 0, 'status callback observed in order trace');
    Check(LSink.FFirstChunkOrder > LSink.FStatusOrder,
      'status callback fires before first body chunk after informational reset');
    CheckEqual('hello world', LSink.FTotal,
      'final body fully streamed after informational reset');
  finally
    GStreamListener.Close;
    platform_thread_join(LHandle, LRet);
    GStreamListener := nil;
    LSink.Free;
  end;
end;

procedure TestClientResponseStatusReportsErrorStatus;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
  LSink: TClientStreamSink;
  LRaised: Boolean;
begin
  GStatusErrorListener := NetTcpListen('127.0.0.1', 0);
  LPort := GStatusErrorListener.LocalAddr.Port;
  platform_thread_create(LHandle, @ErrorStatusThread, nil);
  LSink := TClientStreamSink.Create;
  try
    LClient := NewHttpClient;
    LReq := THttpRequestBuilder.Create(hmGet,
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/err')
      .ResponseStatus(@LSink.OnResponseStatus).Build;
    LRaised := False;
    try
      LResp := LClient.Send(LReq);
    except
      on E: Exception do
        LRaised := True;
    end;
    Check(not LRaised, 'non-2xx status is not a transport error');
    CheckEqual(Int64(1), Int64(LSink.FStatusCalls),
      'status callback fires once for 4xx');
    CheckEqual(Int64(429), Int64(LSink.FStatusValue),
      'status callback reports 429');
    if not LRaised then
      CheckEqual(Int64(429), Int64(LResp.StatusCode),
        'response status is 429');
  finally
    GStatusErrorListener.Close;
    platform_thread_join(LHandle, LRet);
    GStatusErrorListener := nil;
    LSink.Free;
  end;
end;

procedure TestClientSkipBodyBufferStreamsWithoutRetaining;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
  LSink: TClientChunkSink;
begin
  GStreamListener := NetTcpListen('127.0.0.1', 0);
  LPort := GStreamListener.LocalAddr.Port;
  platform_thread_create(LHandle, @StreamChunkThread, nil);
  LSink := TClientChunkSink.Create;
  try
    LClient := NewHttpClient;
    LReq := THttpRequestBuilder.Create(hmGet,
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/stream')
      .ResponseBodyChunk(@LSink.OnBodyChunk).SkipBodyBuffer.Build;
    LResp := LClient.Send(LReq);
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'skip-buffer streamed status');
    CheckEqual('hello world', LSink.FTotal,
      'skip-buffer sink still receives every body byte');
    Check(LSink.FChunks >= 2,
      'skip-buffer sink dispatches live chunks across the 250ms gap');
    Check(LResp.Body = nil,
      'skip-buffer mode does not retain response body');
  finally
    GStreamListener.Close;
    platform_thread_join(LHandle, LRet);
    GStreamListener := nil;
    LSink.Free;
  end;
end;

{ Zero-body streaming response: status-split must complete at the headers
  (Content-Length: 0). Regression for the pause-at-headers hang that left the
  read loop blocked until the request deadline. }
procedure TestClientZeroBodyStreamCompletesAtHeaders;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
  LSink: TClientStreamSink;
  LRaised: Boolean;
begin
  GZeroBodyListener := NetTcpListen('127.0.0.1', 0);
  LPort := GZeroBodyListener.LocalAddr.Port;
  platform_thread_create(LHandle, @ZeroBodyStreamThread, nil);
  LSink := TClientStreamSink.Create;
  try
    LClient := NewHttpClient;
    LReq := THttpRequestBuilder.Create(hmGet,
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/empty')
      .ResponseStatus(@LSink.OnResponseStatus)
      .ResponseBodyChunk(@LSink.OnBodyChunk)
      .SkipBodyBuffer
      .Timeout(2000)
      .Build;
    LRaised := False;
    try
      LResp := LClient.Send(LReq);
    except
      on E: Exception do
        LRaised := True;
    end;
    Check(not LRaised,
      'zero-body stream completes without read-deadline raise');
    if not LRaised then
    begin
      CheckEqual(Int64(200), Int64(LResp.StatusCode),
        'zero-body stream status');
      CheckEqual(Int64(1), Int64(LSink.FStatusCalls),
        'status callback fires exactly once');
      CheckEqual(Int64(200), Int64(LSink.FStatusValue),
        'status callback reports 200');
      CheckEqual(Int64(0), Int64(LSink.FChunks),
        'no body chunks for Content-Length: 0');
      Check(LResp.Body = nil,
        'skip-buffer mode does not retain body');
    end;
  finally
    GZeroBodyListener.Close;
    platform_thread_join(LHandle, LRet);
    GZeroBodyListener := nil;
    LSink.Free;
  end;
end;

procedure TestClientDoesNotPoolRequestWithConnectionCloseTokenList;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LHeaders: IHttpHeaders;
  LResp: IHttpResponse;
  LRaised: Boolean;
begin
  GPoisonAcceptCount := 0;
  GPoisonReusedMethod := '';
  GPoisonListener := NetTcpListen('127.0.0.1', 0);
  LPort := GPoisonListener.LocalAddr.Port;
  platform_thread_create(LHandle, @RequestConnectionClosePoolThread, nil);

  try
    LClient := NewHttpClient;
    LHeaders := NewHeaders;
    LHeaders.SetHeader('connection', 'keep-alive, close');
    LReq := THttpRequestBuilder.Create(hmGet, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/close-after-request').Headers(LHeaders).Build;
    LResp := LClient.Send(LReq);
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'request connection close token-list status');
    CheckEqual('ok', ReadBodyStr(LResp),
      'request connection close token-list body');
    CheckEqual(Int64(1), Int64(GPoisonAcceptCount),
      'request connection close token-list opens first connection');

    LRaised := False;
    try
      LResp := LClient.Get('http://127.0.0.1:' +
        IntToStr(Int64(LPort)) + '/fresh-after-close');
    except
      on E: Exception do
        LRaised := True;
    end;

    Check(not LRaised,
      'client does not reuse request connection with close token-list');
    if not LRaised then
    begin
      CheckEqual(Int64(200), Int64(LResp.StatusCode),
        'fresh request after request close token-list succeeds');
      CheckEqual('fresh-ok', ReadBodyStr(LResp),
        'fresh request after request close token-list body');
    end;
    LClient := nil;
    CheckEqual('', GPoisonReusedMethod,
      'request close token-list is not reused on the first connection');
    CheckEqual(Int64(2), Int64(GPoisonAcceptCount),
      'request close token-list makes next request open a fresh connection');
  finally
    LClient := nil;
    if GPoisonAcceptCount < 2 then
      WakeRetryAcceptThread(LPort);
    GPoisonListener.Close;
    platform_thread_join(LHandle, LRet);
    GPoisonListener := nil;
    GPoisonAcceptCount := 0;
    GPoisonReusedMethod := '';
  end;
end;

procedure TestClientConnectionCloseSameReadTailReturnsFirstResponse;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  GRawAcceptCount := 0;
  GRawResponse1 := 'HTTP/1.1 200 OK'#13#10 +
                   'Content-Length: 2'#13#10 +
                   'Connection: close'#13#10 +
                   #13#10 +
                   'ok' +
                   'HTTP/1.1 599 Poisoned'#13#10 +
                   'Content-Length: 6'#13#10 +
                   #13#10 +
                   'poison';
  GRawResponse2 := 'HTTP/1.1 200 OK'#13#10 +
                   'Content-Length: 8'#13#10 +
                   'Connection: close'#13#10 +
                   #13#10 +
                   'fresh-ok';
  GRawAcceptLimit := 2;
  GRawListener := NetTcpListen('127.0.0.1', 0);
  LPort := GRawListener.LocalAddr.Port;
  platform_thread_create(LHandle, @RawResponseThread, nil);

  try
    LClient := NewHttpClient;

    LResp := LClient.Get('http://127.0.0.1:' +
      IntToStr(Int64(LPort)) + '/prime');
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'connection-close same-read tail returns first response status');
    CheckEqual('ok', ReadBodyStr(LResp),
      'connection-close same-read tail returns first response body');

    LResp := LClient.Get('http://127.0.0.1:' +
      IntToStr(Int64(LPort)) + '/fresh');
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'connection-close same-read tail follow-up opens fresh connection');
    CheckEqual('fresh-ok', ReadBodyStr(LResp),
      'connection-close same-read tail follow-up body');
    CheckEqual(Int64(2), Int64(GRawAcceptCount),
      'connection-close same-read tail is not pooled for follow-up request');
  finally
    if GRawAcceptCount < 2 then
      WakeRetryAcceptThread(LPort);
    GRawListener.Close;
    platform_thread_join(LHandle, LRet);
    GRawListener := nil;
    GRawAcceptCount := 0;
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

procedure TestClientSkips100ContinueBeforeFinalResponse;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  GRawResponse1 := 'HTTP/1.1 100 Continue'#13#10 +
                   #13#10 +
                   'HTTP/1.1 200 OK'#13#10 +
                   'Content-Length: 8'#13#10 +
                   'Connection: close'#13#10 +
                   #13#10 +
                   'final-ok';
  GRawResponse2 := '';
  GRawAcceptLimit := 1;
  GRawListener := NetTcpListen('127.0.0.1', 0);
  LPort := GRawListener.LocalAddr.Port;
  platform_thread_create(LHandle, @RawResponseThread, nil);

  try
    LClient := NewHttpClient;
    LResp := LClient.Get('http://127.0.0.1:' +
      IntToStr(Int64(LPort)) + '/continue');

    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'client returns final response after 100 Continue');
    CheckEqual('final-ok', ReadBodyStr(LResp),
      'client reads final response body after 100 Continue');
  finally
    GRawListener.Close;
    platform_thread_join(LHandle, LRet);
    GRawListener := nil;
    GRawResponse1 := '';
    GRawResponse2 := '';
    GRawAcceptLimit := 0;
  end;
end;

procedure TestClientSkips103EarlyHintsBeforeFinalResponse;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  GRawResponse1 := 'HTTP/1.1 103 Early Hints'#13#10 +
                   'Link: </style.css>; rel=preload'#13#10 +
                   #13#10 +
                   'HTTP/1.1 200 OK'#13#10 +
                   'Content-Length: 8'#13#10 +
                   'Connection: close'#13#10 +
                   #13#10 +
                   'final-ok';
  GRawResponse2 := '';
  GRawAcceptLimit := 1;
  GRawListener := NetTcpListen('127.0.0.1', 0);
  LPort := GRawListener.LocalAddr.Port;
  platform_thread_create(LHandle, @RawResponseThread, nil);

  try
    LClient := NewHttpClient;
    LResp := LClient.Get('http://127.0.0.1:' +
      IntToStr(Int64(LPort)) + '/early-hints');

    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'client returns final response after 103 Early Hints');
    CheckEqual('final-ok', ReadBodyStr(LResp),
      'client reads final response body after 103 Early Hints');
  finally
    GRawListener.Close;
    platform_thread_join(LHandle, LRet);
    GRawListener := nil;
    GRawResponse1 := '';
    GRawResponse2 := '';
    GRawAcceptLimit := 0;
  end;
end;

procedure TestClientRejectsInformationalOnlyResponseEof;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LRaised: Boolean;
  LMessage: string;
begin
  GRawResponse1 := 'HTTP/1.1 103 Early Hints'#13#10 +
                   'Link: </style.css>; rel=preload'#13#10 +
                   #13#10;
  GRawResponse2 := '';
  GRawAcceptLimit := 1;
  GRawListener := NetTcpListen('127.0.0.1', 0);
  LPort := GRawListener.LocalAddr.Port;
  platform_thread_create(LHandle, @RawResponseThread, nil);

  try
    LClient := NewHttpClient;
    LRaised := False;
    LMessage := '';
    try
      LClient.Get('http://127.0.0.1:' +
        IntToStr(Int64(LPort)) + '/early-hints-only');
    except
      on E: EHttpError do
      begin
        LRaised := True;
        LMessage := E.Message;
      end;
    end;

    Check(LRaised, 'informational-only response EOF raises EHttpError');
    Check(Pos('missing final response', LMessage) > 0,
      'informational-only response EOF reports missing final response');
  finally
    GRawListener.Close;
    platform_thread_join(LHandle, LRet);
    GRawListener := nil;
    GRawResponse1 := '';
    GRawResponse2 := '';
    GRawAcceptLimit := 0;
  end;
end;

procedure TestClientDoesNotPool101SwitchingProtocolsConnection;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  GPoisonAcceptCount := 0;
  GPoisonListener := NetTcpListen('127.0.0.1', 0);
  LPort := GPoisonListener.LocalAddr.Port;
  platform_thread_create(LHandle, @SwitchingProtocolsPoolThread, nil);

  try
    LClient := NewHttpClient;

    LResp := LClient.Get('http://127.0.0.1:' +
      IntToStr(Int64(LPort)) + '/upgrade');
    CheckEqual(Int64(101), Int64(LResp.StatusCode),
      'client returns 101 Switching Protocols as the final response');

    LResp := LClient.Get('http://127.0.0.1:' +
      IntToStr(Int64(LPort)) + '/fresh');
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'request after 101 uses a fresh HTTP connection');
    CheckEqual('fresh-ok', ReadBodyStr(LResp),
      'fresh request after 101 receives normal HTTP response body');
    CheckEqual(Int64(2), Int64(GPoisonAcceptCount),
      '101 Switching Protocols connection is not returned to the HTTP pool');

    LClient := nil;
  finally
    if GPoisonAcceptCount < 2 then
      WakeRetryAcceptThread(LPort);
    GPoisonListener.Close;
    platform_thread_join(LHandle, LRet);
    GPoisonListener := nil;
  end;
end;

procedure TestClientRequestBodyDoesNotExceedContentLength;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
begin
  GBodyLimitDeclaredBody := '';
  GBodyLimitExtraBody := '';
  GBodyLimitReplyAfterRead := True;
  GBodyLimitListener := NetTcpListen('127.0.0.1', 0);
  LPort := GBodyLimitListener.LocalAddr.Port;
  platform_thread_create(LHandle, @BodyLimitCaptureThread, nil);

  try
    LClient := NewHttpClient;
    LReq := THttpRequestBuilder.Create(hmPost, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/upload').Headers(NewHeaders).Body(StringBodyReader('abcdef')).ContentLength(Int64(3)).Build;
    LResp := LClient.Send(LReq);

    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'declared-short body request returns response');
    CheckEqual('ok', ReadBodyStr(LResp),
      'declared-short body response body');
    CheckEqual('abc', GBodyLimitDeclaredBody,
      'client writes exactly declared request body bytes');
    CheckEqual('', GBodyLimitExtraBody,
      'client does not write bytes beyond declared content-length');
  finally
    GBodyLimitListener.Close;
    platform_thread_join(LHandle, LRet);
    GBodyLimitListener := nil;
    GBodyLimitReplyAfterRead := False;
  end;
end;

procedure TestClientSerializesContentLengthWhenRequestHeaderRemoved;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
begin
  GBodyLimitDeclaredBody := '';
  GBodyLimitExtraBody := '';
  GBodyLimitReplyAfterRead := True;
  GBodyLimitListener := NetTcpListen('127.0.0.1', 0);
  LPort := GBodyLimitListener.LocalAddr.Port;
  platform_thread_create(LHandle, @BodyLimitCaptureThread, nil);

  try
    LClient := NewHttpClient;
    LReq := THttpRequestBuilder.Create(hmPost, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/upload').Headers(NewHeaders).Body(StringBodyReader('payload')).ContentLength(Int64(7)).Build;
    LReq.Headers.Remove('content-length');
    Check(not LReq.Headers.Has('content-length'),
      'test precondition removes request content-length header');

    LResp := LClient.Send(LReq);

    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'removed content-length header request returns response');
    CheckEqual('ok', ReadBodyStr(LResp),
      'removed content-length header response body');
    CheckEqual('payload', GBodyLimitDeclaredBody,
      'transport serializes request ContentLength as fixed body framing');
    CheckEqual('', GBodyLimitExtraBody,
      'transport does not send unframed request body bytes');
    Check(not LReq.Headers.Has('content-length'),
      'transport framing does not mutate request headers');
  finally
    GBodyLimitListener.Close;
    platform_thread_join(LHandle, LRet);
    GBodyLimitListener := nil;
    GBodyLimitReplyAfterRead := False;
  end;
end;

procedure TestClientRequestBodySkipsNonNilBodyWhenContentLengthZero;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
begin
  GBodyLimitDeclaredBody := '';
  GBodyLimitExtraBody := '';
  GBodyLimitReplyAfterRead := True;
  GBodyLimitListener := NetTcpListen('127.0.0.1', 0);
  LPort := GBodyLimitListener.LocalAddr.Port;
  platform_thread_create(LHandle, @BodyLimitCaptureThread, nil);

  try
    LClient := NewHttpClient;
    LReq := THttpRequestBuilder.Create(hmPost, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/upload').Headers(NewHeaders).Body(StringBodyReader('abcdef')).ContentLength(Int64(0)).Build;
    LResp := LClient.Send(LReq);

    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'zero-length non-nil body request returns response');
    CheckEqual('', GBodyLimitDeclaredBody,
      'zero content-length has no declared body bytes');
    CheckEqual('', GBodyLimitExtraBody,
      'zero content-length skips non-nil body bytes');
  finally
    GBodyLimitListener.Close;
    platform_thread_join(LHandle, LRet);
    GBodyLimitListener := nil;
    GBodyLimitReplyAfterRead := False;
  end;
end;

procedure TestClientRejectsRequestBodyShorterThanContentLength;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LRaised: Boolean;
  LJoined: Boolean;
begin
  GBodyLimitDeclaredBody := '';
  GBodyLimitExtraBody := '';
  GBodyLimitReplyAfterRead := False;
  GBodyLimitListener := NetTcpListen('127.0.0.1', 0);
  LPort := GBodyLimitListener.LocalAddr.Port;
  platform_thread_create(LHandle, @BodyLimitCaptureThread, nil);
  LJoined := False;

  try
    LClient := NewHttpClient;
    LReq := THttpRequestBuilder.Create(hmPost, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/upload').Headers(NewHeaders).Body(StringBodyReader('abc')).ContentLength(Int64(6)).Build;
    LRaised := False;
    try
      LClient.Send(LReq);
    except
      on E: EHttpError do
        LRaised := True;
    end;

    Check(LRaised,
      'client rejects request body shorter than declared content-length');
    GBodyLimitListener.Close;
    platform_thread_join(LHandle, LRet);
    LJoined := True;
    CheckEqual('abc', GBodyLimitDeclaredBody,
      'short request still writes available body bytes before rejecting');
  finally
    if not LJoined then
    begin
      GBodyLimitListener.Close;
      platform_thread_join(LHandle, LRet);
    end;
    GBodyLimitListener := nil;
    GBodyLimitReplyAfterRead := False;
  end;
end;

function TestStringToBytes(const AValue: string): TBytes;
begin
  SetLength(Result, Length(AValue));
  if Length(AValue) > 0 then
    Move(AValue[1], Result[0], Length(AValue));
end;

procedure TestClientClosesCloseCapableRequestBodyAfterSend;
var
  LBody: TTrackedRequestBody;
  LTransportObj: TRequestBodyCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
begin
  LBody := TTrackedRequestBody.Create('payload');
  LTransportObj := TRequestBodyCaptureTransport.Create(LBody);
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LReq := THttpRequestBuilder.Create(hmPost, 'http://example.test/upload').Headers(NewHeaders).Body(LBody as IReader).ContentLength(Int64(7)).Build;

  LResp := LClient.Send(LReq);

  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'request body close success path returns transport response');
  Check(not LTransportObj.TrackedBodyClosedAtEntry,
    'Send keeps request body open at transport entry');
  Check(not LTransportObj.TrackedBodyClosedBeforeReturn,
    'Send keeps request body open while transport runs');
  CheckEqual('payload', LTransportObj.SeenBody,
    'Send still streams the request body to the transport');
  Check(LBody.Closed,
    'Send closes close-capable request body after round trip');
end;

procedure TestClientClosesCloseCapableRequestBodyOnTransportError;
var
  LBody: TTrackedRequestBody;
  LTransportObj: TRequestBodyCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LRaised: Boolean;
begin
  LBody := TTrackedRequestBody.Create('payload');
  LTransportObj := TRequestBodyCaptureTransport.Create(LBody, True);
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

  Check(LRaised, 'transport error still surfaces to caller');
  Check(not LTransportObj.TrackedBodyClosedAtEntry,
    'transport error path keeps request body open at transport entry');
  Check(not LTransportObj.TrackedBodyClosedBeforeReturn,
    'transport error path keeps request body open while transport runs');
  CheckEqual('payload', LTransportObj.SeenBody,
    'transport error path still exposes the request body to the transport');
  Check(LBody.Closed,
    'Send closes close-capable request body when transport raises');
end;

procedure TestClientReleasesResponseBodyWhenRequestBodyCloseFails;
var
  LReqBody: TTrackedRequestBody;
  LRespBody: TRedirectTrackedBody;
  LTransportObj: TRequestBodyCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LRaised: Boolean;
begin
  LReqBody := TTrackedRequestBody.Create('payload', True);
  LRespBody := TRedirectTrackedBody.Create('discard');
  LTransportObj := TRequestBodyCaptureTransport.Create(LReqBody, False,
    LRespBody as IReader);
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LReq := THttpRequestBuilder.Create(hmPost, 'http://example.test/upload').Headers(NewHeaders).Body(LReqBody as IReader).ContentLength(Int64(7)).Build;

  LRaised := False;
  try
    LClient.Send(LReq);
  except
    on E: EHttpError do
      LRaised := E.Message = 'request body close failed';
  end;

  Check(LRaised, 'request body close error surfaces to caller');
  CheckEqual(Int64(1), Int64(LReqBody.CloseCount),
    'Send tries to close request body once');
  CheckEqual('payload', LTransportObj.SeenBody,
    'transport still receives request body before close failure');
  Check(LRespBody.Closed,
    'Send releases returned response body before surfacing request close error');
end;

procedure TestClientKeepsRequestBodyCloseErrorWhenResponseReleaseFails;
var
  LReqBody: TTrackedRequestBody;
  LRespBody: TCloseFailingResponseBody;
  LTransportObj: TRequestBodyCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LRaisedRequestCloseError: Boolean;
  LRaisedResponseCloseError: Boolean;
begin
  LReqBody := TTrackedRequestBody.Create('payload', True);
  LRespBody := TCloseFailingResponseBody.Create;
  LTransportObj := TRequestBodyCaptureTransport.Create(LReqBody, False,
    LRespBody as IReader);
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LReq := THttpRequestBuilder.Create(hmPost, 'http://example.test/upload').Headers(NewHeaders).Body(LReqBody as IReader).ContentLength(Int64(7)).Build;

  LRaisedRequestCloseError := False;
  LRaisedResponseCloseError := False;
  try
    LClient.Send(LReq);
  except
    on E: EHttpError do
    begin
      LRaisedRequestCloseError := E.Message = 'request body close failed';
      LRaisedResponseCloseError := E.Message = 'response body close failed';
    end;
  end;

  Check(LRaisedRequestCloseError,
    'request body close error remains the surfaced error');
  Check(not LRaisedResponseCloseError,
    'response release failure does not replace request close error');
  CheckEqual(Int64(1), Int64(LRespBody.CloseCount),
    'response body release was still attempted once');
  Check(LRespBody.Closed, 'response body close was attempted');
end;

procedure TestClientKeepsTransportErrorWhenRequestBodyCloseFails;
var
  LReqBody: TTrackedRequestBody;
  LTransportObj: TRequestBodyCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LRaisedTransportError: Boolean;
  LRaisedRequestCloseError: Boolean;
begin
  LReqBody := TTrackedRequestBody.Create('payload', True);
  LTransportObj := TRequestBodyCaptureTransport.Create(LReqBody, True);
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LReq := THttpRequestBuilder.Create(hmPost, 'http://example.test/upload').Headers(NewHeaders).Body(LReqBody as IReader).ContentLength(Int64(7)).Build;

  LRaisedTransportError := False;
  LRaisedRequestCloseError := False;
  try
    LClient.Send(LReq);
  except
    on E: EHttpError do
    begin
      LRaisedTransportError := E.Message = 'request body transport failed';
      LRaisedRequestCloseError := E.Message = 'request body close failed';
    end;
  end;

  Check(LRaisedTransportError,
    'transport error remains the surfaced error');
  Check(not LRaisedRequestCloseError,
    'request body cleanup failure does not replace transport error');
  CheckEqual(Int64(1), Int64(LReqBody.CloseCount),
    'request body cleanup was still attempted once');
end;

procedure TestClientSendStreamingKnownLengthBody;
var
  LBody: TTrackedRequestBody;
  LTransportObj: TRequestBodyCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LBody := TTrackedRequestBody.Create('payload');
  LTransportObj := TRequestBodyCaptureTransport.Create(nil);
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LResp := LClient.SendStreaming(hmPost, 'http://example.test/upload',
    'text/plain', LBody as IReader, Int64(7));
  CheckEqual(Int64(200), Int64(LResp.StatusCode), 'streaming returns response');
  CheckEqual(Int64(Ord(hmPost)), Int64(Ord(LTransportObj.SeenMethod)),
    'streaming method');
  CheckEqual(Int64(7), LTransportObj.SeenContentLength, 'streaming content-length');
  CheckEqual('payload', LTransportObj.SeenBody, 'streaming body');
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

procedure TestClientShortcutBodyOverloadsOmitEmptyContentType;
var
  LTransportObj: TRequestBodyCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LBytes: TBytes;
begin
  LTransportObj := TRequestBodyCaptureTransport.Create(nil);
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LResp := LClient.Post('http://example.test/upload', '', 'payload');
  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'post string empty content-type returns transport response');
  CheckShortcutOmitsEmptyContentType('post string', LTransportObj, hmPost,
    'payload');

  SetLength(LBytes, 3);
  LBytes[0] := Ord('b');
  LBytes[1] := 0;
  LBytes[2] := 255;
  LTransportObj := TRequestBodyCaptureTransport.Create(nil);
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LResp := LClient.Put('http://example.test/upload', '', LBytes);
  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'put bytes empty content-type returns transport response');
  CheckShortcutOmitsEmptyContentType('put bytes', LTransportObj, hmPut,
    'b' + #0 + #255);

  LTransportObj := TRequestBodyCaptureTransport.Create(nil);
  LTransport := LTransportObj;
  LClient := NewHttpClient(LTransport);
  LResp := LClient.Patch('http://example.test/upload', '', 'stream-body');
  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'patch string empty content-type returns transport response');
  CheckShortcutOmitsEmptyContentType('patch string', LTransportObj, hmPatch,
    'stream-body');
end;

{ Test 4: Client follows redirect (301 -> 200) }
procedure TestClientResponseMetadataOnDirectGet;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LUrl: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Get('/meta', procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter)
  var LB: string;
  begin
    LB := 'ok';
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LB))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], SizeUInt(Length(LB)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LUrl := 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/meta';
    LResp := LClient.Get(LUrl);
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'direct get status 200');
    CheckEqual(LUrl, LResp.FinalUrl, 'FinalUrl matches request URL');
    CheckEqual(Int64(Ord(hvHttp11)), Int64(Ord(LResp.Version)),
      'H1 live response version is HTTP/1.1');
    CheckEqual('ok', ReadBodyStr(LResp), 'direct get body');
  finally
    StopServer(LServer, LHandle);
  end;
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
    on E: EHttpError do
      LCaught := E.Kind = hekArgument;
  end;
  Check(LCaught, 'negative client timeout raises hekArgument');

  LOptions := THttpClientOptions.Default;
  LOptions.MaxRedirects := -1;
  LTransport := TNilResponseTransport.Create as IHttpTransport;
  LCaught := False;
  try
    NewHttpClient(LTransport, LOptions);
  except
    on E: EHttpError do
      LCaught := E.Kind = hekArgument;
  end;
  Check(LCaught, 'negative client max redirects raises hekArgument');
end;

{ Test 5: Client respects max redirects (infinite loop -> error) }
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

procedure TestClientPoolIdleTTLExpiresIdleConnections;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LOptions: THttpClientOptions;
  LResp: IHttpResponse;
  LRet: Pointer;
  LUrl: string;
begin
  { IdleTTL=40ms: first request pools; after sleep, second request redials. }
  GAcceptCount := 0;
  GPoolListener := NetTcpListen('127.0.0.1', 0);
  LPort := GPoolListener.LocalAddr.Port;
  platform_thread_create(LHandle, @PoolAcceptThread, nil);
  try
    LOptions := THttpClientOptions.Default.WithIdleTTL(40);
    LClient := NewHttpClient(LOptions);
    LUrl := 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/ttl';
    LResp := LClient.Get(LUrl);
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'idle TTL first status');
    HttpReleaseResponseBody(LResp);
    CheckEqual(Int64(1), Int64(GAcceptCount), 'idle TTL first accept');
    platform_thread_sleep_ns(80000000); { 80ms > IdleTTL }
    LResp := LClient.Get(LUrl);
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'idle TTL second status');
    HttpReleaseResponseBody(LResp);
    CheckEqual(Int64(2), Int64(GAcceptCount),
      'expired idle connection is not reused after IdleTTL');
    { Drop pooled sockets before tearing down the accept thread so Read/join
      cannot race a half-closed keep-alive peer (suite hang residual). }
    LClient.CloseIdleConnections;
    LClient := nil;
  finally
    if LClient <> nil then
    begin
      try
        LClient.CloseIdleConnections;
      except
      end;
      LClient := nil;
    end;
    if GPoolListener <> nil then
      GPoolListener.Close;
    platform_thread_join(LHandle, LRet);
    GPoolListener := nil;
    GAcceptCount := 0;
  end;
end;

procedure TestClientPoolIdleTTLZeroKeepsReuse;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LOptions: THttpClientOptions;
  LResp: IHttpResponse;
  LRet: Pointer;
  LUrl: string;
begin
  { IdleTTL=0: no wall-clock eviction; short sleep still reuses. }
  GAcceptCount := 0;
  GPoolListener := NetTcpListen('127.0.0.1', 0);
  LPort := GPoolListener.LocalAddr.Port;
  platform_thread_create(LHandle, @PoolAcceptThread, nil);
  try
    LOptions := THttpClientOptions.Default.WithIdleTTL(0);
    LClient := NewHttpClient(LOptions);
    LUrl := 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/ttl0';
    LResp := LClient.Get(LUrl);
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'idle TTL0 first status');
    HttpReleaseResponseBody(LResp);
    platform_thread_sleep_ns(50000000); { 50ms }
    LResp := LClient.Get(LUrl);
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'idle TTL0 second status');
    HttpReleaseResponseBody(LResp);
    CheckEqual(Int64(1), Int64(GAcceptCount),
      'IdleTTL=0 keeps reuse after short idle');
    LClient.CloseIdleConnections;
    LClient := nil;
  finally
    if LClient <> nil then
    begin
      try
        LClient.CloseIdleConnections;
      except
      end;
      LClient := nil;
    end;
    if GPoolListener <> nil then
      GPoolListener.Close;
    platform_thread_join(LHandle, LRet);
    GPoolListener := nil;
    GAcceptCount := 0;
  end;
end;

procedure TestH1PoolHealthProbeSourceContract;
var
  LSource: string;
  LGetPos: SizeInt;
  LReusablePos: SizeInt;
  LGetBlock: string;
  LReusableBlock: string;
  LEndPos: SizeInt;
begin
  { Wave I1: borrow-time TryRead probe is the H1 active health check.
    Live peer-close races are covered by stale-retry suites; this contract
    locks the probe into PoolGet outside the pool lock.
    STRUCT-1: pool body lives in impl.h1.pool. }
  LSource := ReadFileText('../../../src/nextpas.core.http.impl.h1.pool.pas');
  LReusablePos := Pos(
    'function TH1IdleConnectionPool.ConnectionIsReusable', LSource);
  Check(LReusablePos > 0, 'PooledConnectionIsReusable exists');
  LGetPos := Pos('function TH1IdleConnectionPool.Get(', LSource);
  Check(LGetPos > LReusablePos, 'PoolGet follows reusable helper');
  LReusableBlock := Copy(LSource, LReusablePos, LGetPos - LReusablePos);
  Check(Pos('Active health probe on borrow', LReusableBlock) > 0,
    'H1 probe documents Wave I1 health check');
  Check(Pos('TryRead', LReusableBlock) > 0,
    'H1 probe uses non-blocking TryRead');
  Check(Pos('tsiorWouldBlock', LReusableBlock) > 0,
    'H1 probe treats WouldBlock as live idle');
  LEndPos := Pos('procedure TH1IdleConnectionPool.Put(', LSource);
  Check(LEndPos > LGetPos, 'PoolPut follows PoolGet');
  LGetBlock := Copy(LSource, LGetPos, LEndPos - LGetPos);
  Check(Pos('ConnectionIsReusable(LCandidate)', LGetBlock) > 0,
    'PoolGet invokes health probe on candidate');
  Check(Pos('Never Close or probe sockets while holding FLock', LGetBlock) > 0,
    'PoolGet probes outside pool lock');
end;

procedure TestClientMaxPoolSizeIsPerAuthority;
var
  LPortA, LPortB: UInt16;
  LHandleA, LHandleB: TPlatformThreadHandle;
  LClient: IHttpClient;
  LOptions: THttpClientOptions;
  LResp: IHttpResponse;
  LRet: Pointer;
  LUrlA, LUrlB: string;
begin
  { MaxPoolSize=1 is per authority: two ports each keep one idle and both reuse.
    A global cap of 1 would drop the second authority and re-accept it. }
  GAcceptCount := 0;
  GAcceptCountAlt := 0;
  GPoolListener := NetTcpListen('127.0.0.1', 0);
  GPoolListenerAlt := NetTcpListen('127.0.0.1', 0);
  LPortA := GPoolListener.LocalAddr.Port;
  LPortB := GPoolListenerAlt.LocalAddr.Port;
  platform_thread_create(LHandleA, @PoolAcceptThread, nil);
  platform_thread_create(LHandleB, @PoolAcceptThreadAlt, nil);
  try
    LOptions := THttpClientOptions.Default.WithMaxPoolSize(1);
    LClient := NewHttpClient(LOptions);
    LUrlA := 'http://127.0.0.1:' + IntToStr(Int64(LPortA)) + '/a';
    LUrlB := 'http://127.0.0.1:' + IntToStr(Int64(LPortB)) + '/b';

    LResp := LClient.Get(LUrlA);
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'authority A first status');
    HttpReleaseResponseBody(LResp);

    LResp := LClient.Get(LUrlB);
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'authority B first status');
    HttpReleaseResponseBody(LResp);

    LResp := LClient.Get(LUrlA);
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'authority A reuse status');
    HttpReleaseResponseBody(LResp);

    LResp := LClient.Get(LUrlB);
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'authority B reuse status');
    HttpReleaseResponseBody(LResp);

    CheckEqual(Int64(1), Int64(GAcceptCount),
      'authority A accepted once under MaxPoolSize=1');
    CheckEqual(Int64(1), Int64(GAcceptCountAlt),
      'authority B accepted once under MaxPoolSize=1');
    LClient := nil;
  finally
    GPoolListener.Close;
    GPoolListenerAlt.Close;
    platform_thread_join(LHandleA, LRet);
    platform_thread_join(LHandleB, LRet);
    GPoolListener := nil;
    GPoolListenerAlt := nil;
    GAcceptCount := 0;
    GAcceptCountAlt := 0;
  end;
end;

procedure TestClientTimeoutDoesNotPoisonIdleConnectionReuse;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LOptions: THttpClientOptions;
  LResp: IHttpResponse;
  LRet: Pointer;
begin
  GAcceptCount := 0;
  GPoolListener := NetTcpListen('127.0.0.1', 0);
  LPort := GPoolListener.LocalAddr.Port;
  platform_thread_create(LHandle, @TimeoutReuseAcceptThread, nil);

  try
    LOptions := THttpClientOptions.Default;
    LOptions.Timeout := 100;
    LClient := NewHttpClient(LOptions);

    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/ping');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'first request status 200');
    CheckEqual(Int64(1), Int64(GAcceptCount),
      'first request opens first connection');

    platform_thread_sleep_ns(250000000);

    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/ping');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'second request status 200');
    CheckEqual(Int64(1), Int64(GAcceptCount),
      'expired per-request timeout does not poison idle reuse');

    LClient := nil;
  finally
    GPoolListener.Close;
    platform_thread_join(LHandle, LRet);
    GPoolListener := nil;
  end;
end;

procedure TestClientRequestWriteFailureClosesBodyAndDropsConnection;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
  LBody: TTrackedRequestBody;
  LRaised: Boolean;
  LRet: Pointer;
begin
  GWriteFailureAcceptCount := 0;
  GWriteFailureFirstBody := '';
  GWriteFailureListener := NetTcpListen('127.0.0.1', 0);
  LPort := GWriteFailureListener.LocalAddr.Port;
  platform_thread_create(LHandle, @RequestWriteFailureThread, nil);

  try
    LClient := NewHttpClient;
    LBody := TTrackedRequestBody.Create('payload');
    LReq := THttpRequestBuilder.Create(hmPost, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/upload').Headers(NewHeaders).Body(LBody as IReader).ContentLength(Int64(7)).Build;

    LRaised := False;
    try
      LClient.Send(LReq);
    except
      on E: Exception do
        LRaised := True;
    end;

    Check(LRaised,
      'request write failure before response surfaces to caller');
    Check(LBody.Closed,
      'request write failure closes close-capable request body');
    CheckEqual(Int64(1), Int64(LBody.CloseCount),
      'request write failure closes request body exactly once');
    CheckEqual('payload', GWriteFailureFirstBody,
      'server observed first request body before closing connection');

    LResp := LClient.Get(
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/after-failure');
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'client remains usable after request write failure');
    CheckEqual('ok', ReadBodyStr(LResp),
      'follow-up request reads fresh response body');
    CheckEqual(Int64(2), Int64(GWriteFailureAcceptCount),
      'failed request connection is not returned to the idle pool');

    LClient := nil;
  finally
    if GWriteFailureAcceptCount < 2 then
      WakeRetryAcceptThread(LPort);
    GWriteFailureListener.Close;
    platform_thread_join(LHandle, LRet);
    GWriteFailureListener := nil;
  end;
end;

procedure TestClientSendsIdempotentReplayableBodyAfterClosedPooledConnection;
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
    LHeaders.SetHeader('idempotency-key', 'retry-safe');
    LReq := THttpRequestBuilder.Create(hmPost, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/upload').Headers(LHeaders).Body(StringBodyReader('payload')).ContentLength(Int64(7)).Build;
    LResp := LClient.Send(LReq);

    CheckEqual(Int64(2), Int64(GRetryAcceptCount),
      'closed pooled connection is discarded before idempotent send');
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'idempotent request succeeds on fresh connection');
    CheckEqual('POST', GRetrySecondMethod,
      'idempotent request sends once on fresh connection');
    CheckEqual('payload', GRetrySecondBody,
      'idempotent request body is not replayed');
    CheckEqual('retry-ok', ReadBodyStr(LResp), 'fresh response body');

    LClient := nil;
  finally
    if GRetryAcceptCount < 2 then
      WakeRetryAcceptThread(LPort);
    GRetryListener.Close;
    platform_thread_join(LHandle, LRet);
    GRetryListener := nil;
  end;
end;

procedure TestClientRetriesReplayableBodyWhenPooledConnectionClosesAfterRequestWrite;
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
  GRetryPooledMethod := '';
  GRetryPooledBody := '';
  GRetrySecondMethod := '';
  GRetrySecondBody := '';
  GRetryListener := NetTcpListen('127.0.0.1', 0);
  LPort := GRetryListener.LocalAddr.Port;
  platform_thread_create(LHandle, @PostWritePooledRetryThread, nil);

  try
    LClient := NewHttpClient;

    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/prime');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'priming request status 200');
    CheckEqual('ok', ReadBodyStr(LResp), 'priming response body');
    CheckEqual(Int64(1), Int64(GRetryAcceptCount), 'priming request opened first connection');

    LHeaders := NewHeaders;
    LHeaders.SetHeader('idempotency-key', 'retry-safe');
    LReq := THttpRequestBuilder.Create(hmPost, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/upload').Headers(LHeaders).Body(StringBodyReader('payload')).ContentLength(Int64(7)).Build;
    LResp := LClient.Send(LReq);

    CheckEqual(Int64(2), Int64(GRetryAcceptCount),
      'post-write pooled close reconnects once');
    CheckEqual('POST', GRetryPooledMethod,
      'old pooled connection observed retry-safe request method before close');
    CheckEqual('payload', GRetryPooledBody,
      'old pooled connection observed complete request body before close');
    CheckEqual('POST', GRetrySecondMethod,
      'fresh connection receives replayed request method');
    CheckEqual('payload', GRetrySecondBody,
      'fresh connection receives replayed request body');
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'replayed request succeeds on fresh connection');
    CheckEqual('retry-ok', ReadBodyStr(LResp), 'fresh response body');

    LClient := nil;
  finally
    if LClient <> nil then
      LClient.CloseIdleConnections;
    if GRetryAcceptCount < 2 then
      WakeRetryAcceptThread(LPort);
    GRetryListener.Close;
    platform_thread_join(LHandle, LRet);
    GRetryListener := nil;
    GRetryPooledMethod := '';
    GRetryPooledBody := '';
  end;
end;

procedure TestClientDoesNotRetryLocalRequestBodySerializationError;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
  LHeaders: IHttpHeaders;
  LRaised: Boolean;
  LErrorMessage: string;
  LRet: Pointer;
  LJoined: Boolean;
begin
  GRetryAcceptCount := 0;
  GRetryPooledMethod := '';
  GRetryPooledBody := '';
  GRetrySecondMethod := '';
  GRetrySecondBody := '';
  GRetryListener := NetTcpListen('127.0.0.1', 0);
  LPort := GRetryListener.LocalAddr.Port;
  platform_thread_create(LHandle, @PostWritePooledRetryThread, nil);
  LJoined := False;

  try
    LClient := NewHttpClient;

    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/prime');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'priming request status 200');
    CheckEqual('ok', ReadBodyStr(LResp), 'priming response body');
    CheckEqual(Int64(1), Int64(GRetryAcceptCount),
      'priming request opened first connection');

    LHeaders := NewHeaders;
    LHeaders.SetHeader('idempotency-key', 'retry-safe');
    LReq := THttpRequestBuilder.Create(hmPost, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/upload').Headers(LHeaders).Body(StringBodyReader('abc')).ContentLength(Int64(6)).Build;

    LRaised := False;
    LErrorMessage := '';
    try
      LClient.Send(LReq);
    except
      on E: EHttpError do
      begin
        LRaised := True;
        LErrorMessage := E.Message;
      end;
      on E: Exception do
        LErrorMessage := E.ClassName + ': ' + E.Message;
    end;

    LClient := nil;
    if GRetryAcceptCount < 2 then
      WakeRetryAcceptThread(LPort);
    GRetryListener.Close;
    platform_thread_join(LHandle, LRet);
    LJoined := True;
    GRetryListener := nil;

    Check(LRaised,
      'local request body serialization failure raises EHttpError');
    CheckEqual('HTTP request body shorter than declared content-length',
      LErrorMessage, 'local request body serialization error is preserved');
    CheckEqual('POST', GRetryPooledMethod,
      'old pooled connection observed retry-safe request method before local error');
    CheckEqual('abc', GRetryPooledBody,
      'old pooled connection observed partial request body before local error');
    CheckEqual('', GRetrySecondMethod,
      'local request body serialization failure does not open fresh retry request');
    CheckEqual('', GRetrySecondBody,
      'local request body serialization failure does not replay body');
  finally
    if not LJoined then
    begin
      if LClient <> nil then
        LClient.CloseIdleConnections;
      if GRetryAcceptCount < 2 then
        WakeRetryAcceptThread(LPort);
      if GRetryListener <> nil then
        GRetryListener.Close;
      platform_thread_join(LHandle, LRet);
    end;
    GRetryListener := nil;
    GRetryPooledMethod := '';
    GRetryPooledBody := '';
  end;
end;

procedure TestClientDoesNotRetryRequestBodyReadError;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
  LHeaders: IHttpHeaders;
  LBody: TPartialReadFailingRequestBody;
  LRaised: Boolean;
  LErrorMessage: string;
  LRet: Pointer;
  LJoined: Boolean;
begin
  GRetryAcceptCount := 0;
  GRetryPooledMethod := '';
  GRetryPooledBody := '';
  GRetrySecondMethod := '';
  GRetrySecondBody := '';
  GRetryListener := NetTcpListen('127.0.0.1', 0);
  LPort := GRetryListener.LocalAddr.Port;
  platform_thread_create(LHandle, @PostWritePooledRetryThread, nil);
  LJoined := False;

  try
    LClient := NewHttpClient;

    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/prime');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'priming request status 200');
    CheckEqual('ok', ReadBodyStr(LResp), 'priming response body');
    CheckEqual(Int64(1), Int64(GRetryAcceptCount),
      'priming request opened first connection');

    LBody := TPartialReadFailingRequestBody.Create('abc');
    LHeaders := NewHeaders;
    LHeaders.SetHeader('idempotency-key', 'retry-safe');
    LReq := THttpRequestBuilder.Create(hmPost, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/upload').Headers(LHeaders).Body(LBody as IReader).ContentLength(Int64(6)).Build;

    LRaised := False;
    LErrorMessage := '';
    try
      LClient.Send(LReq);
    except
      on E: EHttpError do
      begin
        LRaised := True;
        LErrorMessage := E.Message;
      end;
      on E: Exception do
        LErrorMessage := E.ClassName + ': ' + E.Message;
    end;

    LClient := nil;
    if GRetryAcceptCount < 2 then
      WakeRetryAcceptThread(LPort);
    GRetryListener.Close;
    platform_thread_join(LHandle, LRet);
    LJoined := True;
    GRetryListener := nil;

    Check(LRaised,
      'request body read failure raises EHttpError');
    Check(Pos('request body read failed', LErrorMessage) > 0,
      'request body read error is preserved');
    Check(LBody.Closed,
      'request body read failure closes close-capable request body');
    CheckEqual(Int64(1), Int64(LBody.CloseCount),
      'request body read failure closes request body exactly once');
    CheckEqual('POST', GRetryPooledMethod,
      'old pooled connection observed retry-safe request method before read error');
    CheckEqual('abc', GRetryPooledBody,
      'old pooled connection observed partial request body before read error');
    CheckEqual('', GRetrySecondMethod,
      'request body read failure does not open fresh retry request');
    CheckEqual('', GRetrySecondBody,
      'request body read failure does not replay body');
  finally
    if not LJoined then
    begin
      if LClient <> nil then
        LClient.CloseIdleConnections;
      if GRetryAcceptCount < 2 then
        WakeRetryAcceptThread(LPort);
      if GRetryListener <> nil then
        GRetryListener.Close;
      platform_thread_join(LHandle, LRet);
    end;
    GRetryListener := nil;
    GRetryPooledMethod := '';
    GRetryPooledBody := '';
  end;
end;

procedure TestClientPooledRetryUsesSingleTimeoutBudget;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LOptions: THttpClientOptions;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
  LHeaders: IHttpHeaders;
  LRaised: Boolean;
  LRet: Pointer;
begin
  GRetryAcceptCount := 0;
  GRetryPooledMethod := '';
  GRetryPooledBody := '';
  GRetrySecondMethod := '';
  GRetrySecondBody := '';
  GRetryListener := NetTcpListen('127.0.0.1', 0);
  LPort := GRetryListener.LocalAddr.Port;
  platform_thread_create(LHandle, @PooledRetrySingleTimeoutBudgetThread, nil);

  try
    LOptions := THttpClientOptions.Default;
    LOptions.Timeout := 400;
    LClient := NewHttpClient(LOptions);

    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/prime');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'priming request status 200');
    CheckEqual('ok', ReadBodyStr(LResp), 'priming response body');
    CheckEqual(Int64(1), Int64(GRetryAcceptCount),
      'priming request opened first connection');

    LHeaders := NewHeaders;
    LHeaders.SetHeader('idempotency-key', 'retry-safe');
    LReq := THttpRequestBuilder.Create(hmPost, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/upload').Headers(LHeaders).Body(StringBodyReader('payload')).ContentLength(Int64(7)).Build;

    LRaised := False;
    try
      LResp := LClient.Send(LReq);
      if LResp <> nil then
        HttpReleaseResponseBody(LResp);
    except
      on E: Exception do
        LRaised := True;
    end;

    CheckEqual(Int64(2), Int64(GRetryAcceptCount),
      'pooled stale retry opened a fresh connection');
    CheckEqual('POST', GRetryPooledMethod,
      'old pooled connection observed retry-safe request method before close');
    CheckEqual('payload', GRetryPooledBody,
      'old pooled connection observed complete request body before close');
    CheckEqual('POST', GRetrySecondMethod,
      'fresh connection receives replayed request method');
    CheckEqual('payload', GRetrySecondBody,
      'fresh connection receives replayed request body');
    Check(LRaised,
      'fresh retry must use remaining request timeout budget, not a new full timeout');

    LClient := nil;
  finally
    if LClient <> nil then
      LClient.CloseIdleConnections;
    if GRetryAcceptCount < 2 then
      WakeRetryAcceptThread(LPort);
    GRetryListener.Close;
    platform_thread_join(LHandle, LRet);
    GRetryListener := nil;
    GRetryPooledMethod := '';
    GRetryPooledBody := '';
  end;
end;

procedure TestClientSendsNonIdempotentBodyAfterClosedPooledConnection;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
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

    LReq := THttpRequestBuilder.Create(hmPost, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/upload').Headers(NewHeaders).Body(StringBodyReader('payload')).ContentLength(Int64(7)).Build;
    LResp := LClient.Send(LReq);

    CheckEqual(Int64(2), Int64(GRetryAcceptCount),
      'closed pooled connection is discarded before non-idempotent send');
    CheckEqual('POST', GRetrySecondMethod,
      'non-idempotent request sends once on fresh connection');
    CheckEqual('payload', GRetrySecondBody,
      'non-idempotent request body is not replayed');
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'non-idempotent request succeeds on fresh connection');
    CheckEqual('retry-ok', ReadBodyStr(LResp), 'fresh response body');

    LClient := nil;
  finally
    if GRetryAcceptCount < 2 then
      WakeRetryAcceptThread(LPort);
    GRetryListener.Close;
    platform_thread_join(LHandle, LRet);
    GRetryListener := nil;
  end;
end;

procedure TestClientSendsNonReplayableIdempotentBodyAfterClosedPooledConnection;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LHeaders: IHttpHeaders;
  LResp: IHttpResponse;
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
    LHeaders.SetHeader('idempotency-key', 'retry-safe');
    LReq := THttpRequestBuilder.Create(hmPost, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/upload').Headers(LHeaders).Body(TOneShotReader.Create('payload') as IReader).ContentLength(Int64(7)).Build;
    LResp := LClient.Send(LReq);

    CheckEqual(Int64(2), Int64(GRetryAcceptCount),
      'closed pooled connection is discarded before non-replayable body send');
    CheckEqual('POST', GRetrySecondMethod,
      'non-replayable body request sends once on fresh connection');
    CheckEqual('payload', GRetrySecondBody,
      'non-replayable body is not replayed');
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'non-replayable body request succeeds on fresh connection');
    CheckEqual('retry-ok', ReadBodyStr(LResp), 'fresh response body');

    LClient := nil;
  finally
    if GRetryAcceptCount < 2 then
      WakeRetryAcceptThread(LPort);
    GRetryListener.Close;
    platform_thread_join(LHandle, LRet);
    GRetryListener := nil;
  end;
end;

procedure TestClientDoesNotRetryAfterResponseBodyTimeout;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LOptions: THttpClientOptions;
  LRaised: Boolean;
  LRet: Pointer;
begin
  GRetryAcceptCount := 0;
  GRetryBodyTimeoutSecondAttemptSeen := False;
  GRetryListener := NetTcpListen('127.0.0.1', 0);
  LPort := GRetryListener.LocalAddr.Port;
  platform_thread_create(LHandle, @PooledBodyTimeoutThread, nil);

  try
    LOptions := THttpClientOptions.Default;
    LOptions.Timeout := 200;
    LClient := NewHttpClient(LOptions);

    CheckEqual(Int64(200), Int64(LClient.Get(
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/prime').StatusCode),
      'priming request status 200');
    CheckEqual(Int64(1), Int64(GRetryAcceptCount),
      'priming request opened first connection');

    LRaised := False;
    try
      LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/partial');
    except
      on E: Exception do
        LRaised := True;
    end;

    Check(LRaised, 'partial response body timeout raises');
    CheckEqual(Int64(1), Int64(GRetryAcceptCount),
      'client does not retry after response body has started');
    Check(not GRetryBodyTimeoutSecondAttemptSeen,
      'server did not observe retry after partial response body');

    LClient := nil;
  finally
    if GRetryAcceptCount < 2 then
      WakeRetryAcceptThread(LPort);
    GRetryListener.Close;
    platform_thread_join(LHandle, LRet);
    GRetryListener := nil;
    GRetryBodyTimeoutSecondAttemptSeen := False;
  end;
end;

procedure TestClientDropsPooledConnectionWithUnreadResponseTail;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LRet: Pointer;
begin
  GPoisonAcceptCount := 0;
  GPoisonListener := NetTcpListen('127.0.0.1', 0);
  LPort := GPoisonListener.LocalAddr.Port;
  platform_thread_create(LHandle, @PooledResponseTailThread, nil);

  try
    LClient := NewHttpClient;

    LResp := LClient.Get('http://127.0.0.1:' +
      IntToStr(Int64(LPort)) + '/prime');
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'priming response status 200');
    CheckEqual('ok', ReadBodyStr(LResp), 'priming response body');

    platform_thread_sleep_ns(150000000);

    LResp := LClient.Get('http://127.0.0.1:' +
      IntToStr(Int64(LPort)) + '/real');
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'follow-up response uses fresh connection');
    CheckEqual('fresh-ok', ReadBodyStr(LResp), 'follow-up response body');
    CheckEqual(Int64(2), Int64(GPoisonAcceptCount),
      'poisoned pooled connection was discarded before reuse');

    LClient := nil;
  finally
    if GPoisonAcceptCount < 2 then
      WakeRetryAcceptThread(LPort);
    GPoisonListener.Close;
    platform_thread_join(LHandle, LRet);
    GPoisonListener := nil;
  end;
end;

procedure TestClientDropsPooledConnectionWithSameReadResponseTail;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LRet: Pointer;
begin
  GPoisonAcceptCount := 0;
  GPoisonListener := NetTcpListen('127.0.0.1', 0);
  LPort := GPoisonListener.LocalAddr.Port;
  platform_thread_create(LHandle, @SameReadResponseTailThread, nil);

  try
    LClient := NewHttpClient;

    LResp := LClient.Get('http://127.0.0.1:' +
      IntToStr(Int64(LPort)) + '/prime');
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'priming response status 200');
    CheckEqual('ok', ReadBodyStr(LResp), 'priming response body');

    LResp := LClient.Get('http://127.0.0.1:' +
      IntToStr(Int64(LPort)) + '/real');
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'same-read poison tail follow-up response uses fresh connection');
    CheckEqual('fresh-ok', ReadBodyStr(LResp),
      'same-read poison tail follow-up body');
    CheckEqual(Int64(2), Int64(GPoisonAcceptCount),
      'same-read poison tail connection was discarded before reuse');

    LClient := nil;
  finally
    if GPoisonAcceptCount < 2 then
      WakeRetryAcceptThread(LPort);
    GPoisonListener.Close;
    platform_thread_join(LHandle, LRet);
    GPoisonListener := nil;
  end;
end;

procedure TestClientDoesNotRetryPooledConnectionAfterMalformedChunkedResponse;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LRaised: Boolean;
  LParseError: Boolean;
  LRet: Pointer;
begin
  GPoisonAcceptCount := 0;
  GPoisonReusedMethod := '';
  GPoisonListener := NetTcpListen('127.0.0.1', 0);
  LPort := GPoisonListener.LocalAddr.Port;
  platform_thread_create(LHandle, @MalformedPooledChunkedResponseThread, nil);

  try
    LClient := NewHttpClient;

    LResp := LClient.Get('http://127.0.0.1:' +
      IntToStr(Int64(LPort)) + '/prime');
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'priming response status 200');
    CheckEqual('ok', ReadBodyStr(LResp), 'priming response body');
    CheckEqual(Int64(1), Int64(GPoisonAcceptCount),
      'priming request opens first connection');

    LRaised := False;
    LParseError := False;
    try
      LClient.Get('http://127.0.0.1:' +
        IntToStr(Int64(LPort)) + '/malformed');
    except
      on E: EHttpError do
      begin
        LRaised := True;
        LParseError := Pos('HTTP parse error', E.Message) > 0;
      end;
    end;

    Check(LRaised, 'malformed chunked response raises EHttpError');
    Check(LParseError, 'malformed chunked response reports parse error');
    CheckEqual(Int64(1), Int64(GPoisonAcceptCount),
      'client does not retry after malformed response has started');

    LResp := LClient.Get('http://127.0.0.1:' +
      IntToStr(Int64(LPort)) + '/fresh');
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'follow-up response uses fresh connection');
    CheckEqual('fresh-ok', ReadBodyStr(LResp), 'follow-up response body');
    CheckEqual(Int64(2), Int64(GPoisonAcceptCount),
      'malformed pooled connection was discarded before reuse');
    CheckEqual('', GPoisonReusedMethod,
      'follow-up request was not sent on malformed pooled connection');

    LClient := nil;
  finally
    if GPoisonAcceptCount < 2 then
      WakeRetryAcceptThread(LPort);
    GPoisonListener.Close;
    platform_thread_join(LHandle, LRet);
    GPoisonListener := nil;
    GPoisonReusedMethod := '';
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
    AW.GetHeaders.SetHeader('content-length', '2');
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
      on E: EHttpError do
      begin
        LCaught := True;
        Check(E.Kind = hekTimeout, 'timeout Kind is hekTimeout');
        Check(HttpErrorIsTimeout(E), 'HttpErrorIsTimeout recognizes boundary error');
      end;
      on E: ETimeoutError do
        Check(False, 'transport timeout must not escape as bare ETimeoutError');
    end;
    Check(LCaught, 'timeout raises EHttpError(hekTimeout)');
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
    AW.GetHeaders.SetHeader('content-length', '2');
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
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(LB))));
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

procedure TestClientAutoHostDoesNotMutateRequestHeaders;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
  LHeaders: IHttpHeaders;
  LGotHost: string;
begin
  LGotHost := '';
  LRouter := THttpRouter.Create;
  LRouter.Get('/check-host', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  const
    BODY = 'ok';
  begin
    LGotHost := AReq.Headers.Get('host');
    AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(BODY))));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(BODY[1], SizeUInt(Length(BODY)));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LHeaders := NewHeaders;
    LReq := THttpRequestBuilder.Create(hmGet, 'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/check-host').Headers(LHeaders).Build;
    Check(not LHeaders.Has('host'),
      'auto host wire-only: source headers start without host');
    Check(not LReq.Headers.Has('host'),
      'auto host wire-only: request starts without host');

    LClient := NewHttpClient;
    LResp := LClient.Send(LReq);
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'auto host wire-only: status 200');
    Check(LGotHost <> '',
      'auto host wire-only: host appears on wire');
    Check(Pos('127.0.0.1', LGotHost) > 0,
      'auto host wire-only: wire host contains IP');
    Check(not LReq.Headers.Has('host'),
      'auto host wire-only: request headers remain unmodified');
    Check(not LHeaders.Has('host'),
      'auto host wire-only: source headers remain unmodified');
  finally
    StopServer(LServer, LHandle);
  end;
end;

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

procedure TestClientCustomTransportAcceptsNonHttpScheme;
var
  LTransportObj: TUrlCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransportObj := TUrlCaptureTransport.Create;
  LTransport := LTransportObj as IHttpTransport;
  LClient := NewHttpClient(LTransport);

  LResp := LClient.Get('https://example.test/custom');

  CheckEqual(Int64(200), Int64(LResp.StatusCode),
    'custom transport returns response for non-http scheme');
  CheckEqual(Int64(1), Int64(LTransportObj.Calls),
    'custom transport receives non-http request');
  CheckEqual('https', LTransportObj.SeenScheme,
    'custom transport sees original scheme');
  CheckEqual('example.test', LTransportObj.SeenHost,
    'custom transport sees original host');
  CheckEqual('/custom', LTransportObj.SeenPath,
    'custom transport sees original path');
end;

procedure TestClientDirectUrlRejectsInvalidPortBeforeTransport;
var
  LTransportObj: TUrlCaptureTransport;
  LTransport: IHttpTransport;
  LClient: IHttpClient;
  LRaised: Boolean;
begin
  LTransportObj := TUrlCaptureTransport.Create;
  LTransport := LTransportObj as IHttpTransport;
  LClient := NewHttpClient(LTransport);

  LRaised := False;
  try
    LClient.Get('http://127.0.0.1:notaport/');
  except
    on E: EHttpError do
      LRaised := True;
  end;

  Check(LRaised, 'direct URL invalid port raises EHttpError');
  CheckEqual(Int64(0), Int64(LTransportObj.Calls),
    'direct URL invalid port fails before transport dispatch');
end;

procedure TestClientRejectsUnsupportedDirectSchemes;
begin
  { https is supported on H1 (direct TLS); non-http(s) schemes stay rejected. }
  CheckClientRejectsUnsupportedDirectScheme('ftp');
end;

procedure TestClientAutoHostRejectsInvalidHeaderValue;
var
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LUrl: TUrl;
  LRaised: Boolean;
  LRejectedHeaderValue: Boolean;
begin
  LUrl := Default(TUrl);
  LUrl.Scheme := 'http';
  LUrl.Host := '127.0.0.1'#13'evil';
  LUrl.Port := 9;
  LUrl.Path := '/';

  LClient := NewHttpClient;
  LReq := NewRequest(hmGet, LUrl);
  LRaised := False;
  LRejectedHeaderValue := False;
  try
    LClient.Send(LReq);
  except
    on E: EHttpError do
    begin
      LRaised := True;
      LRejectedHeaderValue := Pos('invalid header value', E.Message) > 0;
    end;
  end;
  Check(LRaised, 'auto host invalid value raises EHttpError');
  Check(LRejectedHeaderValue,
    'auto host invalid value fails before network write');
  Check(not LReq.Headers.Has('host'),
    'auto host invalid value does not mutate request headers');
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

procedure TestClientRejectsCustomHeaderValueInjectionBeforeWireWrite;
begin
  CheckClientRejectsCustomWireHeader('x-safe',
    'ok'#13#10'x-injected: yes', 'x-injected: yes',
    'custom header value CRLF injection');
end;

procedure TestClientRejectsCustomHeaderNameInjectionBeforeWireWrite;
begin
  CheckClientRejectsCustomWireHeader('x-safe'#13#10'x-injected',
    'yes', 'x-injected: yes',
    'custom header name CRLF injection');
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

procedure TestClientRejectsRequestTargetInjectionBeforeWireWrite;
begin
  CheckClientRejectsRequestTargetBeforeWireWrite(
    '/safe'#13#10'x-injected: yes', '', 'x-injected: yes',
    'request path CRLF injection');
  CheckClientRejectsRequestTargetBeforeWireWrite(
    '/safe', 'ok=1'#13#10'x-injected: yes', 'x-injected: yes',
    'request query CRLF injection');
  CheckClientRejectsRequestTargetBeforeWireWrite(
    '/has space', '', '/has space',
    'request path space injection');
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

procedure TestClientIdlePoolReusesCaseEquivalentAuthorityHost;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LLowerUrl: TUrl;
  LUpperUrl: TUrl;
  LRet: Pointer;
begin
  GAcceptCount := 0;
  GPoolRequest1 := '';
  GPoolRequest2 := '';
  GPoolListener := NetTcpListen('127.0.0.1', 0);
  LPort := GPoolListener.LocalAddr.Port;
  platform_thread_create(LHandle, @PoolAuthorityCaseThread, nil);

  try
    LLowerUrl := TUrl.Parse('http://localhost:' + IntToStr(Int64(LPort)) + '/pool-a');
    LUpperUrl := TUrl.Parse('http://LOCALHOST:' + IntToStr(Int64(LPort)) + '/pool-b');
    CheckEqual('localhost', LLowerUrl.Host,
      'url parser preserves lowercase host authority');
    CheckEqual('LOCALHOST', LUpperUrl.Host,
      'url parser preserves uppercase host authority');
    CheckEqual('LOCALHOST:' + IntToStr(Int64(LPort)), LUpperUrl.HostPort,
      'wire HostPort keeps parsed host case');

    LClient := NewHttpClient;
    LResp := LClient.Get(LLowerUrl.ToString);
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'lowercase authority request status 200');
    HttpReleaseResponseBody(LResp);

    LResp := LClient.Get(LUpperUrl.ToString);
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'uppercase authority request status 200');
    HttpReleaseResponseBody(LResp);

    CheckEqual('localhost:' + IntToStr(Int64(LPort)),
      RawHeaderValue(GPoolRequest1, 'host'),
      'first request wire Host keeps lowercase HostPort');
    CheckEqual('LOCALHOST:' + IntToStr(Int64(LPort)),
      RawHeaderValue(GPoolRequest2, 'host'),
      'second request wire Host keeps uppercase HostPort');
    CheckEqual(Int64(1), Int64(GAcceptCount),
      'case-equivalent authority host reuses one idle connection');
    LClient := nil;
  finally
    GPoolListener.Close;
    platform_thread_join(LHandle, LRet);
    GPoolListener := nil;
    GPoolRequest1 := '';
    GPoolRequest2 := '';
  end;
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

procedure TestWithTimeoutDecorator;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LTransport.RedirectLocation := '/new';
  LTransport.RedirectStatus := HTTP_STATUS_FOUND;
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LResp := LClient.WithTimeout(5000).Get('http://localhost/test');
  Check(LResp <> nil, 'WithTimeout decorator does not crash');
  HttpReleaseResponseBody(LResp);
end;

procedure TestWithTimeoutOuterWinsAndComposesWithRetry;
{ Wave E2: outer WithTimeout overrides; stack with WithRetry still applies. }
var
  LTransport: TTimeoutCaptureTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransport := TTimeoutCaptureTransport.Create(3000);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);

  LResp := LClient.WithTimeout(5000).WithTimeout(9000).Get('http://localhost/t');
  CheckEqual(Int64(9000), LTransport.CapturedTimeoutMs,
    'outer WithTimeout(9000) wins over WithTimeout(5000)');
  HttpReleaseResponseBody(LResp);

  LResp := LClient.WithRetry(1).WithTimeout(8000).Get('http://localhost/t');
  CheckEqual(Int64(8000), LTransport.CapturedTimeoutMs,
    'WithRetry then WithTimeout still overrides transport default');
  HttpReleaseResponseBody(LResp);

  LResp := LClient.WithTimeout(7000).WithRetry(1).Get('http://localhost/t');
  CheckEqual(Int64(7000), LTransport.CapturedTimeoutMs,
    'WithTimeout under WithRetry still applies request timeout');
  HttpReleaseResponseBody(LResp);
end;

procedure TestWithHeaderOuterWinsOverInner;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LResp := LClient
    .WithHeader('X-Trace', 'inner')
    .WithHeader('X-Trace', 'outer')
    .Get('http://localhost/hdr');
  Check(LResp <> nil, 'stacked WithHeader returns response');
  CheckEqual(Int64(2), Int64(LTransport.Calls),
    'default follow-redirects makes second capture call');
  CheckEqual('outer', LTransport.SeenTraceHeader,
    'outer WithHeader wins for same name');
  HttpReleaseResponseBody(LResp);
end;

procedure TestPerRequestTimeoutAtTransportLevel;
var
  LTransport: TTimeoutCaptureTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LReq: IHttpRequest;
begin
  // Default timeout = 3000, per-request override = 8000
  LTransport := TTimeoutCaptureTransport.Create(3000);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);

  // Test 1: No per-request override — should use transport default
  LResp := LClient.Get('http://localhost/test');
  CheckEqual(Int64(3000), LTransport.CapturedTimeoutMs,
    'without per-request override, uses transport default');
  HttpReleaseResponseBody(LResp);

  // Test 2: WithTimeout overrides the transport default
  LResp := LClient.WithTimeout(8000).Get('http://localhost/test');
  CheckEqual(Int64(8000), LTransport.CapturedTimeoutMs,
    'WithTimeout(8000) overrides transport default 3000');
  HttpReleaseResponseBody(LResp);

  // Test 3: Builder with per-request timeout
  LReq := THttpRequestBuilder.Create(hmGet, 'http://localhost/test')
    .Timeout(12000)
    .Build;
  LResp := LClient.Send(LReq);
  CheckEqual(Int64(12000), LTransport.CapturedTimeoutMs,
    'builder Timeout(12000) overrides transport default');
  HttpReleaseResponseBody(LResp);

  // Test 4: Direct request with IHttpRequestWithOptions
  LReq := THttpRequestBuilder.Create(hmGet, 'http://localhost/test').Headers(NewHeaders).Build;
  (LReq as IHttpRequestWithOptions).SetRequestOptions(
    Default(THttpRequestOptions).WithTimeout(15000));
  LResp := LClient.Send(LReq);
  CheckEqual(Int64(15000), LTransport.CapturedTimeoutMs,
    'direct IHttpRequestWithOptions timeout 15000 overrides transport default');
  HttpReleaseResponseBody(LResp);
end;

{ THttpRequestBuilder tests }

procedure TestBuilderGetRequest;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LReq := THttpRequestBuilder.Create(hmGet, 'http://localhost/test').Build;
  Check(LReq <> nil, 'builder Build returns non-nil request');
  CheckEqual(Int64(hmGet), Int64(LReq.Method), 'builder sets GET method');
  CheckEqual('/test', LReq.Path, 'builder sets path');
  LResp := LClient.Send(LReq);
  Check(LResp <> nil, 'builder GET request sent successfully');
  HttpReleaseResponseBody(LResp);
end;

procedure TestBuilderPostWithBody;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LReq := THttpRequestBuilder.Create(hmPost, 'http://localhost/api')
    .ContentType('application/json')
    .Body('{"key":"value"}')
    .Build;
  CheckEqual(Int64(hmPost), Int64(LReq.Method), 'builder sets POST method');
  Check(LReq.Headers.Has('content-type'), 'builder sets content-type header');
  CheckEqual('application/json', LReq.Headers.Get('content-type'),
    'builder content-type value');
  LResp := LClient.Send(LReq);
  Check(LResp <> nil, 'builder POST request sent successfully');
  HttpReleaseResponseBody(LResp);
end;

procedure TestBuilderHeadersAndAuth;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LReq: IHttpRequest;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LReq := THttpRequestBuilder.Create(hmGet, 'http://localhost/test')
    .Header('Accept', 'application/json')
    .Header('X-Custom', 'phase18')
    .BearerAuth('my-token')
    .Build;
  CheckEqual('application/json', LReq.Headers.Get('accept'),
    'builder sets Accept header');
  CheckEqual('phase18', LReq.Headers.Get('x-custom'),
    'builder sets custom header');
  CheckEqual('Bearer my-token', LReq.Headers.Get('authorization'),
    'builder sets Bearer auth header');
end;

procedure TestBuilderBasicAuth;
var
  LReq: IHttpRequest;
begin
  LReq := THttpRequestBuilder.Create(hmGet, 'http://localhost/test')
    .BasicAuth('user', 'pass')
    .Build;
  Check(LReq.Headers.Has('authorization'),
    'builder BasicAuth sets authorization header');
  CheckEqual('Basic', System.Copy(LReq.Headers.Get('authorization'), 1, 5),
    'builder BasicAuth prefix');
end;

procedure TestBuilderQueryParams;
var
  LReq: IHttpRequest;
begin
  LReq := THttpRequestBuilder.Create(hmGet, 'http://localhost/search')
    .QueryParam('q', 'hello')
    .QueryParam('page', '1')
    .Build;
  Check(Pos('q=hello', LReq.Url.RawQuery) > 0,
    'builder QueryParam contains q=hello');
  Check(Pos('page=1', LReq.Url.RawQuery) > 0,
    'builder QueryParam contains page=1');
end;

procedure TestBuilderQueryParamsExistingQuery;
var
  LReq: IHttpRequest;
begin
  LReq := THttpRequestBuilder.Create(hmGet, 'http://localhost/search?existing=yes')
    .QueryParam('new', 'value')
    .Build;
  Check(Pos('existing=yes', LReq.Url.RawQuery) > 0,
    'builder preserves existing query');
  Check(Pos('new=value', LReq.Url.RawQuery) > 0,
    'builder appends new query param');
end;

procedure TestBuilderPerRequestOptions;
var
  LTransport: TRedirectCaptureTransport;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
begin
  LTransport := TRedirectCaptureTransport.Create;
  LTransport.RedirectLocation := '/new';
  LTransport.RedirectStatus := HTTP_STATUS_FOUND;
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LReq := THttpRequestBuilder.Create(hmGet, 'http://localhost/orig')
    .FollowRedirects(False)
    .Build;
  LResp := LClient.Send(LReq);
  CheckEqual(Int64(HTTP_STATUS_FOUND), Int64(LResp.StatusCode),
    'builder FollowRedirects(false) prevents redirect');
  HttpReleaseResponseBody(LResp);
end;

procedure TestBuilderChaining;
var
  LReq: IHttpRequest;
begin
  LReq := THttpRequestBuilder.Create(hmPut, 'http://localhost/api/item')
    .ContentType('application/json')
    .BearerAuth('token123')
    .Header('Accept', 'application/json')
    .QueryParam('verbose', 'true')
    .Body('{"update":true}')
    .Timeout(3000)
    .Build;
  CheckEqual(Int64(hmPut), Int64(LReq.Method), 'chained builder method');
  CheckEqual('application/json', LReq.Headers.Get('content-type'),
    'chained builder content-type');
  CheckEqual('Bearer token123', LReq.Headers.Get('authorization'),
    'chained builder auth');
  CheckEqual('application/json', LReq.Headers.Get('accept'),
    'chained builder accept header');
  Check(Pos('verbose=true', LReq.Url.RawQuery) > 0,
    'chained builder query param');
end;

procedure TestBuilderReaderBodyWithoutContentLengthIsChunked;
var
  LReq: IHttpRequest;
begin
  LReq := THttpRequestBuilder.Create(hmPost, 'http://localhost/api')
    .Body(StringBodyReader('payload'))
    .Build;
  CheckEqual(Int64(-1), LReq.ContentLength,
    'builder Body(IReader) without CL uses unknown-length sentinel');
  CheckEqual('chunked', LowerCase(LReq.Headers.Get('transfer-encoding')),
    'builder publishes transfer-encoding: chunked');
  Check(not LReq.Headers.Has('content-length'),
    'chunked body must not publish content-length');
  Check(LReq.Body <> nil, 'chunked builder body is non-nil');
end;

procedure TestBuilderReaderBodyWithContentLength;
var
  LReq: IHttpRequest;
begin
  LReq := THttpRequestBuilder.Create(hmPost, 'http://localhost/api')
    .ContentType('text/plain')
    .Body(StringBodyReader('payload'))
    .ContentLength(7)
    .Build;
  CheckEqual(Int64(7), LReq.ContentLength,
    'builder ContentLength applies to reader body');
  CheckEqual('7', LReq.Headers.Get('content-length'),
    'builder publishes matching content-length header');
  Check(LReq.Body <> nil, 'builder reader body is non-nil');
end;

procedure TestBuilderEmptyStringBody;
var
  LReq: IHttpRequest;
begin
  LReq := THttpRequestBuilder.Create(hmPost, 'http://localhost/api')
    .Body('')
    .Build;
  CheckEqual(Int64(0), LReq.ContentLength,
    'empty string body publishes Content-Length 0');
  CheckEqual('0', LReq.Headers.Get('content-length'),
    'empty string body sets content-length header');
  Check(LReq.Body <> nil, 'empty string body is still a body reader');
end;

{ Streaming body tests }

procedure TestBuilderStreamingRequestContentLength;
var
  LBody: TTrackedRequestBody;
  LReq: IHttpRequest;
begin
  LBody := TTrackedRequestBody.Create('streaming-data');
  LReq := THttpRequestBuilder.Create(hmPost, 'http://localhost/upload')
    .ContentType('application/octet-stream')
    .Body(LBody as IReader)
    .ContentLength(14)
    .Build;
  Check(LReq <> nil, 'builder streaming request returns non-nil');
  CheckEqual(Int64(hmPost), Int64(LReq.Method), 'streaming request method');
  CheckEqual('application/octet-stream', LReq.Headers.Get('content-type'),
    'streaming request content-type');
  CheckEqual('14', LReq.Headers.Get('content-length'),
    'streaming request content-length');
  Check(LReq.Body <> nil, 'streaming request has body');
  Check(not LBody.Closed, 'streaming body NOT closed at creation');
end;

procedure TestSendStreamingBodyClosedAfterSend;
var
  LBody: TTrackedRequestBody;
  LTransport: TRequestBodyCaptureTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LBody := TTrackedRequestBody.Create('upload-payload');
  LTransport := TRequestBodyCaptureTransport.Create(LBody);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LResp := LClient.SendStreaming(hmPost, 'http://localhost/upload',
    'application/octet-stream', LBody as IReader, 14);
  Check(LResp <> nil, 'SendStreaming returns response');
  Check(LBody.Closed, 'streaming body closed after Send');
  CheckEqual('upload-payload', LTransport.SeenBody,
    'transport received streaming body data');
  HttpReleaseResponseBody(LResp);
end;

procedure TestSendStreamingBodyClosedOnError;
var
  LBody: TTrackedRequestBody;
  LTransport: TRequestBodyCaptureTransport;
  LClient: IHttpClient;
  LCaught: Boolean;
begin
  LBody := TTrackedRequestBody.Create('error-payload', True);
  LTransport := TRequestBodyCaptureTransport.Create(LBody);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LCaught := False;
  try
    LClient.SendStreaming(hmPost, 'http://localhost/upload',
      'application/octet-stream', LBody as IReader, 14);
  except
    on E: Exception do
      LCaught := True;
  end;
  Check(LCaught, 'SendStreaming propagates body close error');
end;

procedure TestBuilderStreamingRequestWithHeaders;
var
  LBody: TTrackedRequestBody;
  LReq: IHttpRequest;
begin
  LBody := TTrackedRequestBody.Create('data');
  LReq := THttpRequestBuilder.Create(hmPut, 'http://localhost/update')
    .Header('x-custom', 'phase19')
    .Body(LBody as IReader)
    .ContentLength(4)
    .Build;
  CheckEqual('phase19', LReq.Headers.Get('x-custom'),
    'streaming request preserves custom headers');
  CheckEqual('4', LReq.Headers.Get('content-length'),
    'streaming request sets content-length');
end;

{ HttpEnsureSuccess tests }

{ HttpGetString / HttpGetBytes tests }

{ WithRetry tests }

procedure TestWithRetrySucceedsAfterRetries;
var
  LTransport: TRetryTestTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransport := TRetryTestTransport.Create(2, HTTP_STATUS_SERVICE_UNAVAILABLE);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LResp := LClient.WithRetry(3).Get('http://localhost/test');
  Check(LResp <> nil, 'Retry returns response');
  CheckEqual(200, Int32(LResp.StatusCode), 'Retry eventually succeeds');
  CheckEqual(3, LTransport.Calls, 'Retry makes 3 calls total (2 fail + 1 success)');
end;

procedure TestWithRetryStopsOnSuccess;
var
  LTransport: TRetryTestTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransport := TRetryTestTransport.Create(0, HTTP_STATUS_SERVICE_UNAVAILABLE);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LResp := LClient.WithRetry(3).Get('http://localhost/test');
  Check(LResp <> nil, 'Returns response');
  CheckEqual(200, Int32(LResp.StatusCode), 'First attempt succeeds');
  CheckEqual(1, LTransport.Calls, 'Only 1 call when first succeeds');
end;

procedure TestWithRetryStopsOn4xx;
var
  LTransport: TRetryTestTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransport := TRetryTestTransport.Create(5, HTTP_STATUS_NOT_FOUND);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LResp := LClient.WithRetry(3).Get('http://localhost/test');
  Check(LResp <> nil, 'Returns response');
  CheckEqual(404, Int32(LResp.StatusCode), 'Returns 404 without retrying');
  CheckEqual(1, LTransport.Calls, 'Only 1 call for 4xx');
end;

procedure TestWithRetryExhaustsRetries;
var
  LTransport: TRetryTestTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransport := TRetryTestTransport.Create(10, HTTP_STATUS_SERVICE_UNAVAILABLE);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LResp := LClient.WithRetry(2).Get('http://localhost/test');
  Check(LResp <> nil, 'Returns response');
  CheckEqual(503, Int32(LResp.StatusCode), 'Returns 503 after exhausting retries');
  CheckEqual(3, LTransport.Calls, 'Makes 3 calls (1 initial + 2 retries)');
end;

procedure TestWithRetryZeroMeansNoRetry;
var
  LTransport: TRetryTestTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransport := TRetryTestTransport.Create(5, HTTP_STATUS_BAD_GATEWAY);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LResp := LClient.WithRetry(0).Get('http://localhost/test');
  Check(LResp <> nil, 'Returns response');
  CheckEqual(502, Int32(LResp.StatusCode), 'Returns 502 with 0 retries');
  CheckEqual(1, LTransport.Calls, 'Only 1 call with 0 retries');
end;

procedure TestWithRetryChainsWithAuth;
var
  LTransport: TRetryTestTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransport := TRetryTestTransport.Create(1, HTTP_STATUS_SERVICE_UNAVAILABLE);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LResp := LClient.WithBearerAuth('token123').WithRetry(2).Get('http://localhost/test');
  Check(LResp <> nil, 'Chained retry returns response');
  CheckEqual(200, Int32(LResp.StatusCode), 'Chained retry eventually succeeds');
  CheckEqual(2, LTransport.Calls, 'Makes 2 calls (1 fail + 1 success)');
end;

procedure TestWithRetryRejectsNegative;
var
  LTransport: TRetryTestTransport;
  LClient: IHttpClient;
  LCaught: Boolean;
begin
  LTransport := TRetryTestTransport.Create(0, HTTP_STATUS_OK);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LCaught := False;
  try
    LClient.WithRetry(-1);
  except
    on E: EHttpError do
      LCaught := (E.Kind = hekArgument) and (Pos('negative', E.Message) > 0);
  end;
  Check(LCaught, 'WithRetry(-1) raises hekArgument');
end;

procedure TestWithRetryRetriesTimeoutException;
var
  LTransport: TRetryTestTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransport := TRetryTestTransport.CreateRaising(2, hekTimeout);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LResp := LClient.WithRetry(3).Get('http://localhost/test');
  Check(LResp <> nil, 'timeout retry returns response');
  CheckEqual(200, Int32(LResp.StatusCode), 'timeout retry eventually succeeds');
  CheckEqual(3, LTransport.Calls, 'timeout: 2 fails + 1 success');
end;

procedure TestWithRetryRetriesConnectException;
var
  LTransport: TRetryTestTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransport := TRetryTestTransport.CreateRaising(1, hekConnect);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LResp := LClient.WithRetry(2).Get('http://localhost/test');
  Check(LResp <> nil, 'connect retry returns response');
  CheckEqual(200, Int32(LResp.StatusCode), 'connect retry eventually succeeds');
  CheckEqual(2, LTransport.Calls, 'connect: 1 fail + 1 success');
end;

procedure TestWithRetryDoesNotRetryParseException;
var
  LTransport: TRetryTestTransport;
  LClient: IHttpClient;
  LCaught: Boolean;
  LKind: THttpErrorKind;
begin
  LTransport := TRetryTestTransport.CreateRaising(5, hekParse);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LCaught := False;
  LKind := hekUnknown;
  try
    LClient.WithRetry(3).Get('http://localhost/test');
  except
    on E: EHttpError do
    begin
      LCaught := True;
      LKind := E.Kind;
    end;
  end;
  Check(LCaught, 'parse error surfaces');
  Check(LKind = hekParse, 'parse kind preserved');
  CheckEqual(1, LTransport.Calls, 'parse is not retried');
end;

procedure TestWithRetryDoesNotRetryNonIdempotentPost;
var
  LTransport: TRetryTestTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransport := TRetryTestTransport.Create(5, HTTP_STATUS_SERVICE_UNAVAILABLE);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LResp := LClient.WithRetry(3).Post('http://localhost/test',
    'text/plain', 'payload');
  Check(LResp <> nil, 'POST returns response');
  CheckEqual(503, Int32(LResp.StatusCode), 'POST 5xx not retried without key');
  CheckEqual(1, LTransport.Calls, 'POST without Idempotency-Key is single-shot');
end;

procedure TestWithRetryRetriesPostWithIdempotencyKey;
var
  LTransport: TRetryTestTransport;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
begin
  LTransport := TRetryTestTransport.Create(2, HTTP_STATUS_SERVICE_UNAVAILABLE);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LReq := THttpRequestBuilder.Create(hmPost, 'http://localhost/test')
    .Header('Idempotency-Key', 'k-1')
    .Body('payload')
    .Build;
  LResp := LClient.WithRetry(3).Send(LReq);
  Check(LResp <> nil, 'idempotent POST returns response');
  CheckEqual(200, Int32(LResp.StatusCode), 'idempotent POST eventually succeeds');
  CheckEqual(3, LTransport.Calls, 'POST+Idempotency-Key retries like GET');
end;

procedure TestHttpIsRetrySafeRequestHelpers;
var
  LGet, LPost, LPostKey: IHttpRequest;
begin
  LGet := NewRequest(hmGet, TUrl.Parse('http://localhost/a'));
  LPost := THttpRequestBuilder.Create(hmPost, 'http://localhost/b')
    .Body('x').Build;
  LPostKey := THttpRequestBuilder.Create(hmPost, 'http://localhost/c')
    .Header('X-Idempotency-Key', 'z').Body('x').Build;
  Check(HttpIsRetryableMethod(hmGet), 'GET is retryable method');
  Check(not HttpIsRetryableMethod(hmPost), 'POST is not retryable method');
  Check(HttpIsRetrySafeRequest(LGet), 'GET is retry-safe');
  Check(not HttpIsRetrySafeRequest(LPost), 'POST without key is not safe');
  Check(HttpIsRetrySafeRequest(LPostKey), 'POST with X-Idempotency-Key is safe');
  Check(HttpHasRetryIdempotencyKey(LPostKey), 'key helper true');
  Check(not HttpHasRetryIdempotencyKey(LPost), 'key helper false');
end;

procedure TestWithRetryRetries429WithRetryAfterZero;
var
  LTransport: TRetryTestTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransport := TRetryTestTransport.Create(1, HTTP_STATUS_TOO_MANY_REQUESTS);
  LTransport.RetryAfter := '0';
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LResp := LClient.WithRetry(2).Get('http://localhost/test');
  Check(LResp <> nil, '429 retry returns response');
  CheckEqual(200, Int32(LResp.StatusCode), '429 + Retry-After:0 eventually succeeds');
  CheckEqual(2, LTransport.Calls, '429: 1 fail + 1 success');
end;

procedure TestWithRetryRetries429WithHttpDateRetryAfterPast;
var
  LTransport: TRetryTestTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  { Past IMF-fix → delay 0 (same as Retry-After:0); avoids multi-second sleep. }
  LTransport := TRetryTestTransport.Create(1, HTTP_STATUS_TOO_MANY_REQUESTS);
  LTransport.RetryAfter := 'Sun, 06 Nov 1994 08:49:37 GMT';
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LResp := LClient.WithRetry(2).Get('http://localhost/test');
  Check(LResp <> nil, '429 HTTP-date retry returns response');
  CheckEqual(200, Int32(LResp.StatusCode), 'past HTTP-date Retry-After succeeds quickly');
  CheckEqual(2, LTransport.Calls, 'HTTP-date: 1 fail + 1 success');
end;

procedure TestWithRetryRetries503WithInvalidRetryAfter;
var
  LTransport: TRetryTestTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransport := TRetryTestTransport.Create(1, HTTP_STATUS_SERVICE_UNAVAILABLE);
  LTransport.RetryAfter := 'not-a-number';
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LResp := LClient.WithRetry(2).Get('http://localhost/test');
  Check(LResp <> nil, '503 invalid Retry-After returns response');
  CheckEqual(200, Int32(LResp.StatusCode), 'invalid Retry-After falls back to backoff');
  CheckEqual(2, LTransport.Calls, '503 invalid header still retries');
end;

procedure TestWithRetryDoesNotRetryOther4xx;
var
  LTransport: TRetryTestTransport;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LTransport := TRetryTestTransport.Create(5, HTTP_STATUS_FORBIDDEN);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LResp := LClient.WithRetry(3).Get('http://localhost/test');
  CheckEqual(403, Int32(LResp.StatusCode), '403 not retried');
  CheckEqual(1, LTransport.Calls, 'only one call for non-429 4xx');
end;

procedure TestHttpPutPatchJsonDocumentSuccess;
var
  LTransport: TJsonBodyTransport;
  LClient: IHttpClient;
  LBody, LDoc: IJsonDocument;
begin
  LTransport := TJsonBodyTransport.Create(HTTP_STATUS_OK, '{"ok":true}');
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LBody := JsonParse('{"v":1}');
  LDoc := HttpPutJsonDocument(LClient, 'http://localhost/api', LBody);
  Check(LDoc.Root.ObjectGet('ok').AsBool, 'PutJsonDocument ok');
  LDoc := HttpPatchJsonDocument(LClient, 'http://localhost/api', LBody);
  Check(LDoc.Root.ObjectGet('ok').AsBool, 'PatchJsonDocument ok');
end;

procedure TestCancelTokenRaisesHekCanceledAtSend;
var
  LTransport: TRetryTestTransport;
  LClient: IHttpClient;
  LToken: IHttpCancelToken;
  LReq: IHttpRequest;
  LCaught: Boolean;
  LKind: THttpErrorKind;
begin
  LTransport := TRetryTestTransport.Create(0, HTTP_STATUS_OK);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LToken := NewHttpCancelToken;
  LToken.Cancel;
  LReq := THttpRequestBuilder.Create(hmGet, 'http://localhost/test')
    .CancelToken(LToken)
    .Build;
  LCaught := False;
  LKind := hekUnknown;
  try
    LClient.Send(LReq);
  except
    on E: EHttpError do
    begin
      LCaught := True;
      LKind := E.Kind;
    end;
  end;
  Check(LCaught, 'canceled request raises');
  Check(LKind = hekCanceled, 'cancel kind is hekCanceled');
  CheckEqual(0, LTransport.Calls, 'canceled before transport RoundTrip');
end;

procedure TestCancelTokenNotCanceledAllowsSend;
var
  LTransport: TRetryTestTransport;
  LClient: IHttpClient;
  LToken: IHttpCancelToken;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
begin
  LTransport := TRetryTestTransport.Create(0, HTTP_STATUS_OK);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LToken := NewHttpCancelToken;
  LReq := THttpRequestBuilder.Create(hmGet, 'http://localhost/test')
    .CancelToken(LToken)
    .Build;
  LResp := LClient.Send(LReq);
  Check(LResp <> nil, 'uncanceled token allows send');
  CheckEqual(200, Int32(LResp.StatusCode), 'status 200');
  CheckEqual(1, LTransport.Calls, 'one transport call');
end;

procedure TestClientSendsChunkedRequestBody;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LReq: IHttpRequest;
  LResp: IHttpResponse;
  LGotBody: string;
  LGotCL: Int64;
  LGotTE: string;
begin
  LGotBody := '';
  LGotCL := -2;
  LGotTE := '';
  LRouter := THttpRouter.Create;
  LRouter.Post('/chunk-upload', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LB: string;
  begin
    LGotBody := ReadReaderStr(AReq.Body);
    LGotCL := AReq.ContentLength;
    LGotTE := AReq.Headers.Get('transfer-encoding');
    LB := 'ok';
    AW.GetHeaders.SetHeader('content-length', '2');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], 2);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LReq := THttpRequestBuilder.Create(hmPost,
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/chunk-upload')
      .ContentType('text/plain')
      .Body(StringBodyReader('chunked-payload'))
      .Build;
    LResp := LClient.Send(LReq);
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'chunked request returns 200');
    CheckEqual('chunked-payload', LGotBody, 'server decoded chunked request body');
    CheckEqual('ok', ReadBodyStr(LResp), 'chunked request response body');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientCookieJarInjectsAndStores;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LJar: IHttpCookieJar;
  LResp: IHttpResponse;
  LSeenCookie: string;
  LUrl: string;
begin
  LSeenCookie := '';
  LRouter := THttpRouter.Create;
  LRouter.Get('/set', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LB: string;
  begin
    AW.GetHeaders.Add('set-cookie', 'session=abc123; Path=/');
    LB := 'set';
    AW.GetHeaders.SetHeader('content-length', '3');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], 3);
  end);
  LRouter.Get('/echo', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LB: string;
  begin
    LSeenCookie := AReq.Headers.Get('cookie');
    LB := 'echo';
    AW.GetHeaders.SetHeader('content-length', '4');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], 4);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LJar := NewHttpCookieJar;
    LClient := NewHttpClient.WithCookieJar(LJar);
    LUrl := 'http://127.0.0.1:' + IntToStr(Int64(LPort));
    LResp := LClient.Get(LUrl + '/set');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'set-cookie response 200');
    HttpReleaseResponseBody(LResp);
    LResp := LClient.Get(LUrl + '/echo');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'echo response 200');
    Check(Pos('session=abc123', LSeenCookie) > 0,
      'cookie jar injects stored Set-Cookie');
    HttpReleaseResponseBody(LResp);
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientHttpProxyAbsoluteForm;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LOpts: THttpClientOptions;
  LResp: IHttpResponse;
  LReqLine: string;
  LLineEnd: SizeInt;
begin
  GRawResponse1 := 'HTTP/1.1 200 OK'#13#10 +
                   'Content-Length: 2'#13#10 +
                   #13#10 +
                   'ok';
  GRawResponse2 := '';
  GRawRequest1 := '';
  GRawAcceptLimit := 1;
  GRawListener := NetTcpListen('127.0.0.1', 0);
  LPort := GRawListener.LocalAddr.Port;
  platform_thread_create(LHandle, @RawResponseThread, nil);
  try
    LOpts := THttpClientOptions.Default.WithProxyUrl(
      'http://127.0.0.1:' + IntToStr(Int64(LPort)));
    LClient := NewHttpClient(LOpts);
    LResp := LClient.Get('http://example.test/proxy-path?q=1');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'proxy returns 200');
    CheckEqual('ok', ReadBodyStr(LResp), 'proxy response body');
    LLineEnd := Pos(#13#10, GRawRequest1);
    Check(LLineEnd > 0, 'proxy received request-line');
    LReqLine := System.Copy(GRawRequest1, 1, LLineEnd - 1);
    Check(Pos('GET http://example.test/proxy-path?q=1 HTTP/1.1', LReqLine) > 0,
      'proxy uses absolute-form request-target');
  finally
    GRawListener.Close;
    platform_thread_join(LHandle, LRet);
    GRawListener := nil;
    GRawResponse1 := '';
    GRawResponse2 := '';
    GRawRequest1 := '';
    GRawAcceptLimit := 0;
  end;
end;

procedure TestClientWithProxyUrlFluentAbsoluteForm;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LReqLine: string;
  LLineEnd: SizeInt;
begin
  GRawResponse1 := 'HTTP/1.1 200 OK'#13#10 +
                   'Content-Length: 2'#13#10 +
                   #13#10 +
                   'ok';
  GRawResponse2 := '';
  GRawRequest1 := '';
  GRawAcceptLimit := 1;
  GRawListener := NetTcpListen('127.0.0.1', 0);
  LPort := GRawListener.LocalAddr.Port;
  platform_thread_create(LHandle, @RawResponseThread, nil);
  try
    LClient := NewHttpClient.WithProxyUrl(
      'http://127.0.0.1:' + IntToStr(Int64(LPort)));
    LResp := LClient.Get('http://example.test/via-fluent');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'fluent proxy returns 200');
    LLineEnd := Pos(#13#10, GRawRequest1);
    Check(LLineEnd > 0, 'fluent proxy received request-line');
    LReqLine := System.Copy(GRawRequest1, 1, LLineEnd - 1);
    Check(Pos('GET http://example.test/via-fluent HTTP/1.1', LReqLine) > 0,
      'fluent WithProxyUrl uses absolute-form');
    HttpReleaseResponseBody(LResp);
  finally
    GRawListener.Close;
    platform_thread_join(LHandle, LRet);
    GRawListener := nil;
    GRawResponse1 := '';
    GRawResponse2 := '';
    GRawRequest1 := '';
    GRawAcceptLimit := 0;
  end;
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

procedure TestClientHttpsProxyConnectTunnel;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LOpts: THttpClientOptions;
  LResp: IHttpResponse;
  LReqLine: string;
  LLineEnd: SizeInt;
begin
  GConnectProxyMode := 'ok';
  GConnectProxyConnectRequest := '';
  GConnectProxyHttpRequest := '';
  GConnectProxyHttpReply :=
    'HTTP/1.1 200 OK'#13#10 +
    'Content-Length: 8'#13#10 +
    #13#10 +
    'tunneled';
  GConnectProxyServerCtx := NewConnectTestServerCtx('example.test');
  GConnectProxyListener := NetTcpListen('127.0.0.1', 0);
  LPort := GConnectProxyListener.LocalAddr.Port;
  platform_thread_create(LHandle, @ConnectProxyThread, nil);
  try
    LOpts := THttpClientOptions.Default
      .WithProxyUrl('http://127.0.0.1:' + IntToStr(Int64(LPort)))
      .WithTimeout(10000)
      .WithConnectTimeout(5000);
    LOpts.TLSContext := NewConnectTestClientCtx;
    LClient := NewHttpClient(LOpts);
    LResp := LClient.Get('https://example.test/via-connect?q=1');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'CONNECT tunnel returns 200');
    CheckEqual('tunneled', ReadBodyStr(LResp), 'CONNECT tunnel response body');

    LLineEnd := Pos(#13#10, GConnectProxyConnectRequest);
    Check(LLineEnd > 0, 'proxy received CONNECT request-line');
    LReqLine := System.Copy(GConnectProxyConnectRequest, 1, LLineEnd - 1);
    Check(Pos('CONNECT example.test:443 HTTP/1.1', LReqLine) > 0,
      'proxy receives CONNECT authority-form target');

    LLineEnd := Pos(#13#10, GConnectProxyHttpRequest);
    Check(LLineEnd > 0, 'origin received request-line over TLS tunnel');
    LReqLine := System.Copy(GConnectProxyHttpRequest, 1, LLineEnd - 1);
    Check(Pos('GET /via-connect?q=1 HTTP/1.1', LReqLine) > 0,
      'tunneled request uses origin-form (not absolute-form)');
    Check(Pos('GET https://', GConnectProxyHttpRequest) = 0,
      'tunneled request does not use absolute-form');
  finally
    GConnectProxyListener.Close;
    platform_thread_join(LHandle, LRet);
    GConnectProxyListener := nil;
    GConnectProxyServerCtx := nil;
    GConnectProxyConnectRequest := '';
    GConnectProxyHttpRequest := '';
    GConnectProxyHttpReply := '';
    GConnectProxyMode := '';
  end;
end;

procedure TestClientHttpsProxyConnectDenied;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LOpts: THttpClientOptions;
  LRaised: Boolean;
  LConnectKind: Boolean;
begin
  GConnectProxyMode := 'deny';
  GConnectProxyConnectRequest := '';
  GConnectProxyHttpRequest := '';
  GConnectProxyHttpReply := '';
  GConnectProxyServerCtx := nil;
  GConnectProxyListener := NetTcpListen('127.0.0.1', 0);
  LPort := GConnectProxyListener.LocalAddr.Port;
  platform_thread_create(LHandle, @ConnectProxyThread, nil);
  try
    LOpts := THttpClientOptions.Default
      .WithProxyUrl('http://127.0.0.1:' + IntToStr(Int64(LPort)))
      .WithTimeout(5000)
      .WithConnectTimeout(3000);
    LOpts.TLSContext := NewConnectTestClientCtx;
    LClient := NewHttpClient(LOpts);
    LRaised := False;
    LConnectKind := False;
    try
      LClient.Get('https://example.test/denied');
    except
      on E: EHttpError do
      begin
        LRaised := True;
        LConnectKind := (E.Kind = hekConnect) or
          (Pos('CONNECT', UpperCase(E.Message)) > 0);
      end;
    end;
    Check(LRaised, 'denied CONNECT raises EHttpError');
    Check(LConnectKind, 'denied CONNECT reports connect/tunnel failure');
    Check(Pos('CONNECT example.test:443', GConnectProxyConnectRequest) > 0,
      'denied path still sent CONNECT request');
  finally
    GConnectProxyListener.Close;
    platform_thread_join(LHandle, LRet);
    GConnectProxyListener := nil;
    GConnectProxyServerCtx := nil;
    GConnectProxyConnectRequest := '';
    GConnectProxyHttpRequest := '';
    GConnectProxyMode := '';
  end;
end;

procedure TestClientDirectHttpsRoundTrip;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LOpts: THttpClientOptions;
  LResp: IHttpResponse;
  LReqLine: string;
  LLineEnd: SizeInt;
begin
  GDirectHttpsRequest := '';
  GDirectHttpsReply :=
    'HTTP/1.1 200 OK'#13#10 +
    'Content-Length: 6'#13#10 +
    #13#10 +
    'direct';
  GDirectHttpsServerCtx := NewConnectTestServerCtx('127.0.0.1');
  GDirectHttpsListener := NetTcpListen('127.0.0.1', 0);
  LPort := GDirectHttpsListener.LocalAddr.Port;
  platform_thread_create(LHandle, @DirectHttpsThread, nil);
  try
    LOpts := THttpClientOptions.Default
      .WithTimeout(10000)
      .WithConnectTimeout(5000);
    LOpts.TLSContext := NewConnectTestClientCtx;
    LClient := NewHttpClient(LOpts);
    LResp := LClient.Get('https://127.0.0.1:' + IntToStr(Int64(LPort)) +
      '/direct-https?x=1');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'direct https returns 200');
    CheckEqual('direct', ReadBodyStr(LResp), 'direct https response body');

    LLineEnd := Pos(#13#10, GDirectHttpsRequest);
    Check(LLineEnd > 0, 'direct https server received request-line');
    LReqLine := System.Copy(GDirectHttpsRequest, 1, LLineEnd - 1);
    Check(Pos('GET /direct-https?x=1 HTTP/1.1', LReqLine) > 0,
      'direct https uses origin-form request-target');
    Check(Pos('GET https://', GDirectHttpsRequest) = 0,
      'direct https does not use absolute-form');
  finally
    GDirectHttpsListener.Close;
    platform_thread_join(LHandle, LRet);
    GDirectHttpsListener := nil;
    GDirectHttpsServerCtx := nil;
    GDirectHttpsRequest := '';
    GDirectHttpsReply := '';
  end;
end;

procedure TestClientWithTLSContextFluentDirectHttps;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LReqLine: string;
  LLineEnd: SizeInt;
begin
  { Single accept server: prove fluent WithTLSContext rebuilds transport
    (options.WithTLSContext covered by test_http_base). }
  GDirectHttpsRequest := '';
  GDirectHttpsReply :=
    'HTTP/1.1 200 OK'#13#10 +
    'Content-Length: 6'#13#10 +
    #13#10 +
    'fluent';
  GDirectHttpsServerCtx := NewConnectTestServerCtx('127.0.0.1');
  GDirectHttpsListener := NetTcpListen('127.0.0.1', 0);
  LPort := GDirectHttpsListener.LocalAddr.Port;
  platform_thread_create(LHandle, @DirectHttpsThread, nil);
  try
    LClient := NewHttpClient(
      THttpClientOptions.Default.WithTimeout(10000).WithConnectTimeout(5000))
      .WithTLSContext(NewConnectTestClientCtx);
    LResp := LClient.Get('https://127.0.0.1:' + IntToStr(Int64(LPort)) +
      '/tls-fluent');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'fluent WithTLSContext https 200');
    CheckEqual('fluent', ReadBodyStr(LResp), 'fluent WithTLSContext body');
    LLineEnd := Pos(#13#10, GDirectHttpsRequest);
    Check(LLineEnd > 0, 'fluent TLS server received request');
    LReqLine := System.Copy(GDirectHttpsRequest, 1, LLineEnd - 1);
    Check(Pos('GET /tls-fluent HTTP/1.1', LReqLine) > 0,
      'fluent TLS uses origin-form');
  finally
    GDirectHttpsListener.Close;
    platform_thread_join(LHandle, LRet);
    GDirectHttpsListener := nil;
    GDirectHttpsServerCtx := nil;
    GDirectHttpsRequest := '';
    GDirectHttpsReply := '';
  end;
end;

procedure TestClientHttpsProxyConnect407BasicOnlyMessage;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LOpts: THttpClientOptions;
  LRaised: Boolean;
  LMsg: string;
  LKind: THttpErrorKind;
begin
  { Wave I: CONNECT 407 is not Digest-retried; error text freezes Basic-only. }
  GConnectProxyMode := 'auth-required';
  GConnectProxyConnectRequest := '';
  GConnectProxyHttpRequest := '';
  GConnectProxyHttpReply := '';
  GConnectProxyServerCtx := nil;
  GConnectProxyListener := NetTcpListen('127.0.0.1', 0);
  LPort := GConnectProxyListener.LocalAddr.Port;
  platform_thread_create(LHandle, @ConnectProxyThread, nil);
  try
    LOpts := THttpClientOptions.Default
      .WithProxyUrl('http://127.0.0.1:' + IntToStr(Int64(LPort)))
      .WithTimeout(5000)
      .WithConnectTimeout(3000);
    LOpts.TLSContext := NewConnectTestClientCtx;
    LClient := NewHttpClient(LOpts);
    LRaised := False;
    LMsg := '';
    LKind := hekProtocol;
    try
      LClient.Get('https://example.test/need-auth');
    except
      on E: EHttpError do
      begin
        LRaised := True;
        LMsg := E.Message;
        LKind := E.Kind;
      end;
    end;
    Check(LRaised, 'CONNECT 407 raises EHttpError');
    CheckEqual(Int64(Ord(hekConnect)), Int64(Ord(LKind)),
      'CONNECT 407 is hekConnect');
    Check(Pos('407', LMsg) > 0, 'CONNECT 407 message includes status');
    Check(Pos('Basic', LMsg) > 0,
      'CONNECT 407 message freezes Basic-only proxy auth stance');
    Check(Pos('CONNECT example.test:443', GConnectProxyConnectRequest) > 0,
      '407 path still sent CONNECT');
  finally
    GConnectProxyListener.Close;
    platform_thread_join(LHandle, LRet);
    GConnectProxyListener := nil;
    GConnectProxyServerCtx := nil;
    GConnectProxyConnectRequest := '';
    GConnectProxyHttpRequest := '';
    GConnectProxyMode := '';
  end;
end;

procedure TestProxyAuthBasicOnlySourceContract;
var
  LSource, LH1Client, LWire: string;
begin
  { CONNECT/Basic freeze lives in client transport; helper in wire. }
  LH1Client := ReadFileText('../../../src/nextpas.core.http.impl.h1.client.pas');
  LWire := ReadFileText('../../../src/nextpas.core.http.impl.h1.wire.pas');
  LSource := LH1Client + LWire;
  Check(Pos('function ProxyBasicAuthorizationValue', LSource) > 0,
    'proxy auth helper is Basic-only');
  Check(Pos('''Basic '' + Base64Encode', LSource) > 0,
    'proxy auth encodes Basic scheme');
  Check(Pos('ProxyUrl UserInfo → Proxy-Authorization Basic only', LSource) > 0,
    'CONNECT 407 error freezes Basic-only product stance');
  { Implementation symbols — comments may name parked schemes. }
  Check(Pos('function ProxyDigest', LSource) = 0,
    'no ProxyDigest implementation');
  Check(Pos('function ProxyNtlm', LSource) = 0,
    'no ProxyNtlm implementation');
  Check(Pos('function ProxyNegotiate', LSource) = 0,
    'no ProxyNegotiate implementation');
  Check(Pos('Proxy-Authenticate:', LSource) = 0,
    'H1 client does not parse Proxy-Authenticate challenges');
end;

procedure TestClientHttpsProxyConnectWithBasicAuth;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LOpts: THttpClientOptions;
  LResp: IHttpResponse;
  LExpectedAuth: string;
begin
  GConnectProxyMode := 'ok';
  GConnectProxyConnectRequest := '';
  GConnectProxyHttpRequest := '';
  GConnectProxyHttpReply :=
    'HTTP/1.1 200 OK'#13#10 +
    'Content-Length: 8'#13#10 +
    #13#10 +
    'tunneled';
  GConnectProxyServerCtx := NewConnectTestServerCtx('example.test');
  GConnectProxyListener := NetTcpListen('127.0.0.1', 0);
  LPort := GConnectProxyListener.LocalAddr.Port;
  platform_thread_create(LHandle, @ConnectProxyThread, nil);
  try
    LExpectedAuth := 'Basic ' +
      Base64Encode(StringToUTF8Bytes('proxyuser:proxypass'));
    LOpts := THttpClientOptions.Default
      .WithProxyUrl('http://proxyuser:proxypass@127.0.0.1:' +
        IntToStr(Int64(LPort)))
      .WithTimeout(10000)
      .WithConnectTimeout(5000);
    LOpts.TLSContext := NewConnectTestClientCtx;
    LClient := NewHttpClient(LOpts);
    LResp := LClient.Get('https://example.test/via-auth');
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'CONNECT with Basic auth returns 200');
    CheckEqual(LExpectedAuth,
      RawHeaderValue(GConnectProxyConnectRequest, 'Proxy-Authorization'),
      'CONNECT injects Proxy-Authorization Basic from UserInfo');
    Check(Pos('CONNECT example.test:443', GConnectProxyConnectRequest) > 0,
      'auth path still sends CONNECT authority-form');
  finally
    GConnectProxyListener.Close;
    platform_thread_join(LHandle, LRet);
    GConnectProxyListener := nil;
    GConnectProxyServerCtx := nil;
    GConnectProxyConnectRequest := '';
    GConnectProxyHttpRequest := '';
    GConnectProxyHttpReply := '';
    GConnectProxyMode := '';
  end;
end;

procedure TestClientHttpProxyAbsoluteFormWithBasicAuth;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LOpts: THttpClientOptions;
  LResp: IHttpResponse;
  LExpectedAuth: string;
begin
  GRawResponse1 := 'HTTP/1.1 200 OK'#13#10 +
                   'Content-Length: 2'#13#10 +
                   #13#10 +
                   'ok';
  GRawResponse2 := '';
  GRawRequest1 := '';
  GRawAcceptLimit := 1;
  GRawListener := NetTcpListen('127.0.0.1', 0);
  LPort := GRawListener.LocalAddr.Port;
  platform_thread_create(LHandle, @RawResponseThread, nil);
  try
    LExpectedAuth := 'Basic ' +
      Base64Encode(StringToUTF8Bytes('alice:s3cret'));
    LOpts := THttpClientOptions.Default.WithProxyUrl(
      'http://alice:s3cret@127.0.0.1:' + IntToStr(Int64(LPort)));
    LClient := NewHttpClient(LOpts);
    LResp := LClient.Get('http://example.test/proxy-auth');
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'absolute-form with Basic auth returns 200');
    Check(Pos('GET http://example.test/proxy-auth HTTP/1.1', GRawRequest1) > 0,
      'absolute-form with auth keeps absolute request-target');
    CheckEqual(LExpectedAuth,
      RawHeaderValue(GRawRequest1, 'Proxy-Authorization'),
      'absolute-form injects Proxy-Authorization Basic from UserInfo');
  finally
    GRawListener.Close;
    platform_thread_join(LHandle, LRet);
    GRawListener := nil;
    GRawResponse1 := '';
    GRawResponse2 := '';
    GRawRequest1 := '';
    GRawAcceptLimit := 0;
  end;
end;

procedure TestClientHttpProxyAbsoluteFormKeepsExplicitProxyAuth;
var
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LOpts: THttpClientOptions;
  LReq: IHttpRequest;
  LUrl: TUrl;
  LResp: IHttpResponse;
begin
  GRawResponse1 := 'HTTP/1.1 200 OK'#13#10 +
                   'Content-Length: 2'#13#10 +
                   #13#10 +
                   'ok';
  GRawResponse2 := '';
  GRawRequest1 := '';
  GRawAcceptLimit := 1;
  GRawListener := NetTcpListen('127.0.0.1', 0);
  LPort := GRawListener.LocalAddr.Port;
  platform_thread_create(LHandle, @RawResponseThread, nil);
  try
    LOpts := THttpClientOptions.Default.WithProxyUrl(
      'http://alice:s3cret@127.0.0.1:' + IntToStr(Int64(LPort)));
    LClient := NewHttpClient(LOpts);
    LUrl := TUrl.Parse('http://example.test/keep-auth');
    LReq := NewRequest(hmGet, LUrl);
    LReq.Headers.SetHeader('proxy-authorization', 'Basic explicit-token');
    LResp := LClient.Send(LReq);
    CheckEqual(Int64(200), Int64(LResp.StatusCode),
      'explicit Proxy-Authorization still succeeds');
    CheckEqual('Basic explicit-token',
      RawHeaderValue(GRawRequest1, 'Proxy-Authorization'),
      'explicit Proxy-Authorization is not overwritten by UserInfo');
  finally
    GRawListener.Close;
    platform_thread_join(LHandle, LRet);
    GRawListener := nil;
    GRawResponse1 := '';
    GRawResponse2 := '';
    GRawRequest1 := '';
    GRawAcceptLimit := 0;
  end;
end;

procedure TestClientCookieJarExpiresMaxAge;
var
  LJar: IHttpCookieJar;
  LHeaders: IHttpHeaders;
  LUrl: TUrl;
  LCookie: string;
begin
  LJar := NewHttpCookieJar;
  LUrl := TUrl.Parse('http://example.test/path');
  LHeaders := NewHeaders;
  LHeaders.Add('set-cookie', 'gone=1; Max-Age=0; Path=/');
  LJar.StoreFromResponse(LUrl, LHeaders);
  LCookie := LJar.CookieHeaderFor(LUrl);
  CheckEqual('', LCookie, 'Max-Age=0 cookie is not stored/injected');

  LHeaders := NewHeaders;
  LHeaders.Add('set-cookie', 'live=yes; Max-Age=3600; Path=/');
  LJar.StoreFromResponse(LUrl, LHeaders);
  LCookie := LJar.CookieHeaderFor(LUrl);
  Check(Pos('live=yes', LCookie) > 0, 'positive Max-Age cookie is stored');

  LJar := NewHttpCookieJar;
  LHeaders := NewHeaders;
  LHeaders.Add('set-cookie',
    'stale=1; Expires=Sun, 06 Nov 1994 08:49:37 GMT; Path=/');
  LJar.StoreFromResponse(LUrl, LHeaders);
  LCookie := LJar.CookieHeaderFor(LUrl);
  CheckEqual('', LCookie, 'past Expires cookie is not stored/injected');
end;

procedure TestClientPostMultipart;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LFields: TFormFieldArray;
  LFiles: THttpFileArray;
  LGotContentType: string;
  LGotBody: string;
begin
  LGotContentType := '';
  LGotBody := '';
  LRouter := THttpRouter.Create;
  LRouter.Handle(hmPost, '/up', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LBuf: array[0..4095] of AnsiChar;
    LN: SizeUInt;
    LChunk: string;
  begin
    LGotContentType := AReq.Headers.Get('content-type');
    LGotBody := '';
    if AReq.Body <> nil then
    begin
      repeat
        LN := AReq.Body.Read(LBuf[0], SizeOf(LBuf));
        if LN > 0 then
        begin
          SetLength(LChunk, LN);
          Move(LBuf[0], LChunk[1], LN);
          LGotBody := LGotBody + LChunk;
        end;
      until LN = 0;
    end;
    AW.GetHeaders.SetHeader('content-length', '0');
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    SetLength(LFields, 1);
    LFields[0].Name := 'title';
    LFields[0].Value := 'hello';
    SetLength(LFiles, 1);
    LFiles[0].FieldName := 'file';
    LFiles[0].FileName := 'a.txt';
    LFiles[0].ContentType := 'text/plain';
    LFiles[0].Content := 'xyz';
    LClient := NewHttpClient;
    LResp := LClient.PostMultipart(
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/up', LFields, LFiles);
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'multipart status 200');
    Check(Pos('multipart/form-data; boundary=', LGotContentType) = 1,
      'multipart content-type with boundary');
    Check(Pos('name="title"', LGotBody) > 0, 'multipart body has field');
    Check(Pos('filename="a.txt"', LGotBody) > 0, 'multipart body has file');
    Check(Pos('xyz', LGotBody) > 0, 'multipart body has file content');
    HttpReleaseResponseBody(LResp);
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientConnectTimeoutOptionDefault;
var
  LOpts: THttpClientOptions;
begin
  LOpts := THttpClientOptions.Default;
  CheckEqual(Int64(0), LOpts.ConnectTimeout, 'default ConnectTimeout is 0');
  CheckEqual(LOpts.Timeout, LOpts.EffectiveConnectTimeout,
    'EffectiveConnectTimeout falls back to Timeout');
  LOpts := LOpts.WithConnectTimeout(1500);
  CheckEqual(Int64(1500), LOpts.ConnectTimeout, 'WithConnectTimeout sets field');
  CheckEqual(Int64(1500), LOpts.EffectiveConnectTimeout,
    'EffectiveConnectTimeout prefers ConnectTimeout');
end;

procedure TestClientWithConnectTimeoutFluent;
var
  LClient: IHttpClient;
begin
  LClient := NewHttpClient.WithConnectTimeout(1500);
  Check(LClient <> nil, 'WithConnectTimeout returns client');
  { Decorator rebind: fluent chain keeps usable client surface. }
  LClient := NewHttpClient.WithHeader('X-Test', '1').WithConnectTimeout(2000);
  Check(LClient <> nil, 'WithConnectTimeout rebinds through decorator');
  LClient := LClient.WithTimeout(5000);
  Check(LClient <> nil, 'decorator chain after WithConnectTimeout works');
end;

procedure TestClientWithConnectTimeoutSourceContract;
var
  LSource: string;
  LDeco: string;
begin
  LSource := ReadFileText('../../../src/nextpas.core.http.client.pas');
  LDeco := ReadFileText('../../../src/nextpas.core.http.client.decorator.pas');
  Check(Pos('function THttpClient.WithConnectTimeout(', LSource) > 0,
    'client implements WithConnectTimeout');
  Check(Pos('NewHttpClient(FOptions.WithConnectTimeout(ATimeoutMs))', LSource) > 0,
    'WithConnectTimeout rebuilds transport via NewHttpClient');
  Check(Pos('function THttpClientForwarder.WithConnectTimeout(', LDeco) > 0,
    'forwarder rebinds WithConnectTimeout (decorator unit)');
  Check(Pos('RebindInner(FInner.WithConnectTimeout(ATimeoutMs))', LDeco) > 0,
    'forwarder re-stacks around rebuilt base client');
  LSource := ReadFileText('../../../src/nextpas.core.http.intf.pas');
  Check(Pos('function WithConnectTimeout(const ATimeoutMs: Int64): IHttpClient;',
    LSource) > 0, 'IHttpClient declares WithConnectTimeout');
end;

{ Live H1 dial timeout through NewHttpClient (backlog-full peer; no blackhole IP). }
procedure TestClientLiveConnectTimeout;
var
  LListener: ITcpListener;
  LFillers: array of ITcpStream;
  LConn: ITcpStream;
  LClient: IHttpClient;
  LPort: UInt16;
  I: Integer;
  LFilled: Boolean;
  LGot: Boolean;
  LKind: THttpErrorKind;
begin
  LListener := TcpListen('127.0.0.1', 0);
  LPort := LListener.LocalAddr.Port;
  SetLength(LFillers, 0);
  LFilled := False;
  for I := 1 to 256 do
  begin
    try
      LConn := TcpConnect('127.0.0.1', LPort, 100);
      SetLength(LFillers, Length(LFillers) + 1);
      LFillers[High(LFillers)] := LConn;
    except
      on E: ETimeoutError do
      begin
        LFilled := True;
        Break;
      end;
      on E: ENetworkError do
      begin
        LFilled := True;
        Break;
      end;
    end;
  end;
  Check(LFilled or (Length(LFillers) > 0),
    'backlog fill made progress for client connect-timeout setup');
  LClient := NewHttpClient.WithConnectTimeout(200).WithTimeout(5000);
  LGot := False;
  LKind := hekUnknown;
  try
    LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/');
  except
    on E: EHttpError do
    begin
      LKind := E.Kind;
      LGot := E.Kind in [hekTimeout, hekConnect];
    end;
    on E: ETimeoutError do
    begin
      LGot := True;
      LKind := hekTimeout;
    end;
  end;
  Check(LGot,
    'live client dial timeout surfaces as hekTimeout/hekConnect (kind=' +
    IntToStr(Ord(LKind)) + ')');
  for I := 0 to High(LFillers) do
    if LFillers[I] <> nil then
      LFillers[I].Close;
  LListener.Close;
end;

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
procedure TestClientLiveMidReadCancel;
var
  LServerHandle: TPlatformThreadHandle;
  LCancelHandle: TPlatformThreadHandle;
  LRet: Pointer;
  LClient: IHttpClient;
  LToken: IHttpCancelToken;
  LReq: IHttpRequest;
  LGot: Boolean;
  LKind: THttpErrorKind;
  LWait: Int32;
begin
  GMidReadCancelPort := 0;
  GMidReadCancelToken := nil;
  platform_thread_create(LServerHandle, @MidReadHoldServerThread, nil);
  LWait := 0;
  while (GMidReadCancelPort = 0) and (LWait < 200) do
  begin
    platform_thread_sleep_ns(5000000);
    Inc(LWait);
  end;
  Check(GMidReadCancelPort <> 0, 'mid-read hold server published port');

  LToken := NewHttpCancelToken;
  GMidReadCancelToken := LToken;
  platform_thread_create(LCancelHandle, @MidReadCancelSignalThread, nil);
  LClient := NewHttpClient.WithTimeout(10000);
  LReq := THttpRequestBuilder.Create(hmGet,
    'http://127.0.0.1:' + IntToStr(Int64(GMidReadCancelPort)) + '/')
    .CancelToken(LToken)
    .Build;
  LGot := False;
  LKind := hekUnknown;
  try
    LClient.Send(LReq);
  except
    on E: EHttpError do
    begin
      LKind := E.Kind;
      LGot := E.Kind = hekCanceled;
    end;
    on E: ECancelledError do
    begin
      LGot := True;
      LKind := hekCanceled;
    end;
  end;
  platform_thread_join(LCancelHandle, LRet);
  platform_thread_join(LServerHandle, LRet);
  GMidReadCancelToken := nil;
  Check(LGot, 'live mid-read cancel surfaces hekCanceled (kind=' +
    IntToStr(Ord(LKind)) + ')');
end;

procedure TestClientCancelAndTransportCreateOpSourceContract;
var
  LHttpBase, LH1Client, LHelpers: string;
begin
  { cancel/timeout map live in http.base; H1 client RoundTrip CreateOp in
    impl.h1.client; free helpers in client.helpers. }
  LHttpBase := ReadFileText('../../../src/nextpas.core.http.base.pas');
  LH1Client := ReadFileText('../../../src/nextpas.core.http.impl.h1.client.pas');
  LHelpers := ReadFileText('../../../src/nextpas.core.http.client.helpers.pas');
  Check(Pos('raise EHttpError.CreateOp(hekCanceled, ''cancel'',', LHttpBase) > 0,
    'cancel token uses CreateOp with Op=cancel');
  Check(Pos('EHttpError.CreateOp(hekTimeout, ''transport'',', LHttpBase) > 0,
    'timeout path uses CreateOp with Op=transport');
  Check(Pos('raise EHttpError.CreateOp(hekConnect, ''connect'',', LH1Client) > 0,
    'proxy CONNECT failures use CreateOp with Op=connect');
  Check(Pos('raise EHttpError.CreateOp(hekParse, ''transport'',', LH1Client) > 0,
    'H1 response parse failures use CreateOp with Op=transport');
  Check(Pos('raise EHttpError.CreateOp(hekConnect, ''transport'',', LH1Client) > 0,
    'H1 incomplete response uses CreateOp with Op=transport');
  Check(Pos('CreateOp(hekProtocol, ''json'',', LHelpers) > 0,
    'json helpers use CreateOp with Op=json');
  Check(Pos('CreateOp(hekProtocol, ''content_encoding'',', LHelpers) > 0,
    'content_encoding protocol uses CreateOp');
  Check(Pos('CreateOp(hekBody, ''content_encoding'',', LHelpers) > 0,
    'content_encoding body uses CreateOp');
  Check(Pos('CreateOp(hekStatus, ''ensure'',', LHelpers) > 0,
    'ensure uses CreateOp with Op=ensure');
  Check(Pos('CreateOp(hekConnect, ''download'',', LHelpers) > 0,
    'download uses CreateOp with Op=download');
end;

procedure TestClientTaxonomyOpsAlignedSourceContract;
{ Wave E1: client hotspot Ops stay aligned with CONTRACT Op table. }
var
  LClient, LHelpers: string;
begin
  LClient := ReadFileText('../../../src/nextpas.core.http.client.pas');
  LHelpers := ReadFileText('../../../src/nextpas.core.http.client.helpers.pas');
  Check(Pos('CreateOp(hekProtocol, ''json'',', LHelpers) > 0,
    'json decode failures use Op=json');
  Check(Pos('CreateOp(hekProtocol, ''content_encoding'',', LHelpers) > 0,
    'unsupported Content-Encoding uses Op=content_encoding');
  Check(Pos('CreateOp(hekBody, ''content_encoding'',', LHelpers) > 0,
    'corrupt Content-Encoding uses Op=content_encoding');
  Check(Pos('CreateOp(hekStatus, ''ensure'',', LHelpers) > 0,
    'ensure non-2xx uses Op=ensure');
  Check(Pos('CreateOp(hekConnect, ''download'',', LHelpers) > 0,
    'download nil response uses Op=download');
  Check(Pos('raise EArgumentError', LClient) = 0,
    'client must not raise bare EArgumentError');
  Check(Pos('raise EArgumentError', LHelpers) = 0,
    'client helpers must not raise bare EArgumentError');
end;

procedure TestClientDefaultUserAgent;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LGotUA: string;
begin
  LGotUA := '';
  LRouter := THttpRouter.Create;
  LRouter.Handle(hmGet, '/ua', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  begin
    LGotUA := AReq.Headers.Get('user-agent');
    AW.GetHeaders.SetHeader('content-length', '0');
    AW.WriteHeader(HTTP_STATUS_OK);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Get('http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/ua');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200');
    CheckEqual('nextpas-http/1.0', LGotUA, 'default User-Agent injected when absent');
    HttpReleaseResponseBody(LResp);
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientGetStringMethod;
var
  LRouter: THttpRouter;
  LServer: THttpServer;
  LPort: UInt16;
  LHandle: TPlatformThreadHandle;
  LClient: IHttpClient;
  LBody: string;
begin
  LRouter := THttpRouter.Create;
  LRouter.Handle(hmGet, '/hi', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LB: string;
  begin
    LB := 'hello';
    AW.GetHeaders.SetHeader('content-length', '5');
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], 5);
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    LClient := NewHttpClient;
    LBody := LClient.GetString(
      'http://127.0.0.1:' + IntToStr(Int64(LPort)) + '/hi');
    CheckEqual('hello', LBody, 'IHttpClient.GetString returns body');
  finally
    StopServer(LServer, LHandle);
  end;
end;

procedure TestClientPostStringMethod;
var
  LTransport: TTimeoutCaptureTransport;
  LClient: IHttpClient;
  LBody: string;
begin
  LTransport := TTimeoutCaptureTransport.Create(3000);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  LBody := LClient.PostString('http://localhost/test', 'text/plain', 'hello');
  CheckEqual('', LBody, 'IHttpClient.PostString returns body on 200');
end;

procedure TestClientPostStringRaisesWithContext;
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
    LClient.PostString('http://localhost/error', 'text/plain', 'body');
  except
    on E: EHttpError do
      LCaught := (Pos('404', E.Message) > 0) and
        (Pos('POST', E.Message) > 0) and
        (Pos('http://localhost/error', E.Message) > 0);
  end;
  Check(LCaught, 'IHttpClient.PostString raises with method/URL context');
end;

procedure TestClientPutPatchDeleteStringMethods;
var
  LTransport: TTimeoutCaptureTransport;
  LClient: IHttpClient;
begin
  LTransport := TTimeoutCaptureTransport.Create(3000);
  LClient := NewHttpClient(LTransport, THttpClientOptions.Default);
  CheckEqual('', LClient.PutString('http://localhost/p', 'text/plain', 'x'),
    'IHttpClient.PutString on 200');
  CheckEqual('', LClient.PatchString('http://localhost/p', 'text/plain', 'x'),
    'IHttpClient.PatchString on 200');
  CheckEqual('', LClient.DeleteString('http://localhost/p'),
    'IHttpClient.DeleteString on 200');
end;

{ HttpPostString/PutString/PatchString/DeleteString tests }

{ DialFunc 测试全局记录（匿名函数避免闭包捕获，沿用代理测试的全局模式） }
var
  GDialFuncCount: Integer = 0;
  GDialFuncHost: string = '';
  GDialFuncPort: UInt16 = 0;
  GDialFuncServerPort: UInt16 = 0;

{ DialFunc 注入：连接经自定义拨号建立（SOCKS5 隧道等语义）；拨号函数收到
  请求 URL 的目标 host/port；请求/响应经隧道完整往返。 }
procedure TestClientWithDialFunc;
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
  LRouter.Get('/dialed', procedure(const AReq: IHttpRequest;
    const AW: IHttpResponseWriter)
  var
    LB: string;
  begin
    LB := 'via-dial';
    AW.GetHeaders.SetHeader('content-length', IntToStr(Length(LB)));
    AW.WriteHeader(HTTP_STATUS_OK);
    AW.Write(LB[1], Length(LB));
  end);
  LHandle := StartServer(LRouter as IHttpHandler, LServer, LPort);
  try
    GDialFuncCount := 0;
    GDialFuncHost := '';
    GDialFuncPort := 0;
    GDialFuncServerPort := LPort;
    LClient := NewHttpClient.WithDialFunc(
      function(const AHost: string; const APort: UInt16;
        const AConnectTimeoutMs, ATimeoutMs: Int64): ITcpStream
      begin
        Inc(GDialFuncCount);
        GDialFuncHost := AHost;
        GDialFuncPort := APort;
        { 隧道语义：拨号函数决定实际连接目标（本例落到进程内服务器） }
        Result := TcpConnect('127.0.0.1', GDialFuncServerPort);
      end);
    LResp := LClient.Get('http://dial-target.test:8080/dialed');
    CheckEqual(Int64(200), Int64(LResp.StatusCode), 'status 200 via dial func');
    LBody := ReadBodyStr(LResp);
    CheckEqual('via-dial', LBody, 'body matches');
    CheckEqual(1, GDialFuncCount, 'dial func invoked once');
    CheckEqual('dial-target.test', GDialFuncHost, 'dial receives request host');
    CheckEqual(Int64(8080), Int64(GDialFuncPort), 'dial receives request port');
  finally
    StopServer(LServer, LHandle);
  end;
end;

{ DialFunc 失败必须以异常上抛（传输层语义），不得返回 nil 让上层崩溃。 }
procedure TestClientDialFuncFailureRaises;
var
  LClient: IHttpClient;
  LRaised: Boolean;
begin
  LClient := NewHttpClient.WithDialFunc(
    function(const AHost: string; const APort: UInt16;
      const AConnectTimeoutMs, ATimeoutMs: Int64): ITcpStream
    begin
      Result := nil;
      raise EHttpError.Create(hekConnect, 'dial func: tunnel failed (test)');
    end);
  LRaised := False;
  try
    LClient.Get('http://127.0.0.1:1/nope');
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'dial func failure propagates as exception');
end;

{ Main }

begin
  T := TTestSuite.Create('nextpas.core.http.client');
  T.Test('Client GET returns 200 + body', @TestClientGet200);
  T.Test('Client dials through custom DialFunc tunnel', @TestClientWithDialFunc);
  T.Test('Client DialFunc failure propagates as exception',
    @TestClientDialFuncFailureRaises);
  T.Test('Client Send rejects nil request', @TestClientSendRejectsNilRequest);
  T.Test('H1 client transport rejects nil request inputs',
    @TestH1ClientTransportRejectsNilRequestInputs);
  T.Test('Client Send rejects nil transport response',
    @TestClientSendRejectsNilTransportResponse);
  T.Test('Client GET with custom headers', @TestClientGetCustomHeaders);
  T.Test('Client Send forwards Basic auth helper header',
    @TestClientSendWithBasicAuthHelper);
  T.Test('Client POST with body', @TestClientPostBody);
  T.Test('Client Send uses NewRequest headers/body helper',
    @TestClientSendWithRequestHelperHeadersBody);
  T.Test('Client Send uses NewRequest headers-only helper',
    @TestClientSendWithRequestHelperHeadersOnly);
  T.Test('Client Send uses NewRequest bytes body helper',
    @TestClientSendWithRequestHelperBytesBody);
  T.Test('Client Send uses NewRequest string body helper without headers',
    @TestClientSendWithRequestHelperStringBodyWithoutHeaders);
  T.Test('Client Send uses NewRequest bytes body helper without headers',
    @TestClientSendWithRequestHelperBytesBodyWithoutHeaders);
  T.Test('Client Send uses NewRequest string body helper with content-type without headers',
    @TestClientSendWithRequestHelperStringBodyAndContentTypeWithoutHeaders);
  T.Test('Client Send uses NewRequest bytes body helper with content-type without headers',
    @TestClientSendWithRequestHelperBytesBodyAndContentTypeWithoutHeaders);
  T.Test('Client shortcut bodies use bytes buffer',
    @TestClientShortcutBodyImplementationUsesBytesBuffer);
  T.Test('H1 client transport destroy closes idle pool source contract',
    @TestH1ClientTransportDestroyClosesIdlePoolSourceContract);
  T.Test('H1 client pool MaxPoolSize per authority source contract',
    @TestH1ClientPoolMaxSizePerAuthoritySourceContract);
  T.Test('H1 client pooled retry fresh failure closes connection source contract',
    @TestH1ClientPooledRetryFreshFailureClosesConnectionSourceContract);
  T.Test('OpenSSL context frees PinValidator source contract',
    @TestOpenSSLContextFreesPinValidatorSourceContract);
  T.Test('Windows cancel waitable pair source contract',
    @TestWindowsCancelWaitablePairSourceContract);
  T.Test('Client POST string body overload',
    @TestClientPostStringBodyOverload);
  T.Test('Client PUT sends body and content type', @TestClientPutBodyAndContentType);
  T.Test('Client DELETE sends no body', @TestClientDeleteNoBody);
  T.Test('Client PATCH bytes body overload',
    @TestClientPatchBytesBodyOverload);
  T.Test('Client PATCH sends body and content type', @TestClientPatchBodyAndContentType);
  T.Test('Client HEAD sends HEAD and exposes headers', @TestClientHeadSendsHead);
  T.Test('Client OPTIONS sends OPTIONS and exposes Allow header', @TestClientOptionsSendsOptions);
  T.Test('Client PostForm encodes fields with correct content-type', @TestClientPostFormEncodesFields);
  T.Test('Client PostJson sends JSON with correct content-type', @TestClientPostJsonSendsJson);
  T.Test('Client DELETE sends body and content type', @TestClientDeleteWithBody);
  T.Test('Client DeleteJson sends JSON with correct content-type', @TestClientDeleteJson);
  T.Test('Client WithBasicAuth sets Authorization header', @TestClientWithBasicAuthSetsHeader);
  T.Test('Client WithBearerAuth sets Authorization header', @TestClientWithBearerAuthSetsHeader);
  T.Test('Client WithHeader sets custom header', @TestClientWithHeaderSetsCustomHeader);
  T.Test('Client WithHeader chains with auth', @TestClientWithHeaderChainsWithAuth);
  T.Test('Client WithHeader multiple headers', @TestClientWithHeaderMultipleHeaders);
  T.Test('Client WithHeader does not affect original client', @TestClientWithHeaderDoesNotAffectOriginalClient);
  T.Test('Client reads chunked response body', @TestClientReadsChunkedResponse);
  T.Test('Client reads close-delimited response body', @TestClientReadsCloseDelimitedResponse);
  T.Test('Client does not pool response Connection close token-list',
    @TestClientDoesNotPoolResponseWithConnectionCloseTokenList);
  T.Test('Client streaming body chunk sink live dispatch',
    @TestClientStreamingBodyChunkSink);
  T.Test('Client does not pool request Connection close token-list',
    @TestClientDoesNotPoolRequestWithConnectionCloseTokenList);
  T.Test('Client Connection close same-read tail returns first response',
    @TestClientConnectionCloseSameReadTailReturnsFirstResponse);
  T.Test('Client rejects truncated content-length response', @TestClientRejectsTruncatedContentLengthResponse);
  T.Test('Client skips 100 Continue before final response',
    @TestClientSkips100ContinueBeforeFinalResponse);
  T.Test('Client skips 103 Early Hints before final response',
    @TestClientSkips103EarlyHintsBeforeFinalResponse);
  T.Test('Client rejects informational-only response EOF',
    @TestClientRejectsInformationalOnlyResponseEof);
  T.Test('Client does not pool 101 Switching Protocols connection',
    @TestClientDoesNotPool101SwitchingProtocolsConnection);
  T.Test('Client request body does not exceed ContentLength',
    @TestClientRequestBodyDoesNotExceedContentLength);
  T.Test('Client serializes ContentLength when request header removed',
    @TestClientSerializesContentLengthWhenRequestHeaderRemoved);
  T.Test('Client request body skips non-nil body when ContentLength is zero',
    @TestClientRequestBodySkipsNonNilBodyWhenContentLengthZero);
  T.Test('Client rejects request body shorter than ContentLength',
    @TestClientRejectsRequestBodyShorterThanContentLength);
  T.Test('Client Send closes close-capable request body after round trip',
    @TestClientClosesCloseCapableRequestBodyAfterSend);
  T.Test('Client Send closes close-capable request body on transport error',
    @TestClientClosesCloseCapableRequestBodyOnTransportError);
  T.Test('Client Send releases response body when request body close fails',
    @TestClientReleasesResponseBodyWhenRequestBodyCloseFails);
  T.Test('Client Send keeps request close error when response release fails',
    @TestClientKeepsRequestBodyCloseErrorWhenResponseReleaseFails);
  T.Test('Client Send keeps transport error when request body close fails',
    @TestClientKeepsTransportErrorWhenRequestBodyCloseFails);
  T.Test('SendStreaming known-length body',
    @TestClientSendStreamingKnownLengthBody);
  T.Test('Client shortcut body overloads omit empty content-type',
    @TestClientShortcutBodyOverloadsOmitEmptyContentType);
  T.Test('Client response FinalUrl and Version on direct GET',
    @TestClientResponseMetadataOnDirectGet);
  T.Test('Client options reject negative values',
    @TestClientOptionsRejectNegativeValues);
  T.Test('Client CloseIdleConnections drops pooled connections',
    @TestClientCloseIdleConnectionsDropsPooledConnections);
  T.Test('Client pool IdleTTL expires idle connections',
    @TestClientPoolIdleTTLExpiresIdleConnections);
  T.Test('Client pool IdleTTL=0 keeps reuse',
    @TestClientPoolIdleTTLZeroKeepsReuse);
  T.Test('H1 pool health probe source contract',
    @TestH1PoolHealthProbeSourceContract);
  T.Test('Client MaxPoolSize is per authority',
    @TestClientMaxPoolSizeIsPerAuthority);
  T.Test('Client timeout does not poison idle connection reuse',
    @TestClientTimeoutDoesNotPoisonIdleConnectionReuse);
  T.Test('Client request write failure closes body and drops connection',
    @TestClientRequestWriteFailureClosesBodyAndDropsConnection);
  T.Test('Client sends idempotent replayable body after closed pooled connection',
    @TestClientSendsIdempotentReplayableBodyAfterClosedPooledConnection);
  T.Test('Client retries replayable body when pooled connection closes after request write',
    @TestClientRetriesReplayableBodyWhenPooledConnectionClosesAfterRequestWrite);
  T.Test('Client does not retry local request body serialization error',
    @TestClientDoesNotRetryLocalRequestBodySerializationError);
  T.Test('Client does not retry request body read error',
    @TestClientDoesNotRetryRequestBodyReadError);
  T.Test('Client pooled retry uses single timeout budget',
    @TestClientPooledRetryUsesSingleTimeoutBudget);
  T.Test('Client sends non-idempotent body after closed pooled connection',
    @TestClientSendsNonIdempotentBodyAfterClosedPooledConnection);
  T.Test('Client sends non-replayable idempotent body after closed pooled connection',
    @TestClientSendsNonReplayableIdempotentBodyAfterClosedPooledConnection);
  T.Test('Client does not retry after response body timeout',
    @TestClientDoesNotRetryAfterResponseBodyTimeout);
  T.Test('Client drops pooled connection with unread response tail',
    @TestClientDropsPooledConnectionWithUnreadResponseTail);
  T.Test('Client drops pooled connection with same-read response tail',
    @TestClientDropsPooledConnectionWithSameReadResponseTail);
  T.Test('Client does not retry pooled connection after malformed chunked response',
    @TestClientDoesNotRetryPooledConnectionAfterMalformedChunkedResponse);
  T.Test('Client timeout on slow server', @TestClientTimeout);
  T.Test('Client handles 404 response', @TestClientHandles404);
  T.Test('Client sets Host header automatically', @TestClientSetsHostHeader);
  T.Test('Client auto Host does not mutate request headers',
    @TestClientAutoHostDoesNotMutateRequestHeaders);
  T.Test('Client rejects unsupported direct schemes',
    @TestClientRejectsUnsupportedDirectSchemes);
  T.Test('Client custom transport accepts non-http scheme',
    @TestClientCustomTransportAcceptsNonHttpScheme);
  T.Test('Client direct URL rejects invalid port before transport',
    @TestClientDirectUrlRejectsInvalidPortBeforeTransport);
  T.Test('Client auto Host rejects invalid header value',
    @TestClientAutoHostRejectsInvalidHeaderValue);
  T.Test('Client rejects custom header value injection before wire write',
    @TestClientRejectsCustomHeaderValueInjectionBeforeWireWrite);
  T.Test('Client rejects custom header name injection before wire write',
    @TestClientRejectsCustomHeaderNameInjectionBeforeWireWrite);
  T.Test('Client rejects request target injection before wire write',
    @TestClientRejectsRequestTargetInjectionBeforeWireWrite);
  T.Test('Client idle pool reuses case-equivalent authority host',
    @TestClientIdlePoolReusesCaseEquivalentAuthorityHost);
  T.Test('Connection reuse', @TestConnectionReuse);
  T.Test('WithTimeout decorator does not crash',
    @TestWithTimeoutDecorator);
  T.Test('WithTimeout outer wins and composes with WithRetry',
    @TestWithTimeoutOuterWinsAndComposesWithRetry);
  T.Test('WithHeader outer wins over inner',
    @TestWithHeaderOuterWinsOverInner);
  T.Test('Per-request timeout overrides transport default',
    @TestPerRequestTimeoutAtTransportLevel);
  T.Test('Builder creates GET request', @TestBuilderGetRequest);
  T.Test('Builder POST with body and content-type', @TestBuilderPostWithBody);
  T.Test('Builder headers and BearerAuth', @TestBuilderHeadersAndAuth);
  T.Test('Builder BasicAuth', @TestBuilderBasicAuth);
  T.Test('Builder query parameters', @TestBuilderQueryParams);
  T.Test('Builder preserves existing query', @TestBuilderQueryParamsExistingQuery);
  T.Test('Builder per-request FollowRedirects(false)', @TestBuilderPerRequestOptions);
  T.Test('Builder full chaining', @TestBuilderChaining);
  T.Test('Builder Body(IReader) without CL is chunked',
    @TestBuilderReaderBodyWithoutContentLengthIsChunked);
  T.Test('Builder Body(IReader)+ContentLength',
    @TestBuilderReaderBodyWithContentLength);
  T.Test('Builder empty string body is Content-Length 0',
    @TestBuilderEmptyStringBody);
  T.Test('Builder streaming request sets content-length',
    @TestBuilderStreamingRequestContentLength);
  T.Test('SendStreaming closes body after send',
    @TestSendStreamingBodyClosedAfterSend);
  T.Test('SendStreaming closes body on error',
    @TestSendStreamingBodyClosedOnError);
  T.Test('Builder streaming request preserves headers',
    @TestBuilderStreamingRequestWithHeaders);
  T.Test('WithRetry succeeds after retries', @TestWithRetrySucceedsAfterRetries);
  T.Test('WithRetry stops on first success', @TestWithRetryStopsOnSuccess);
  T.Test('WithRetry does not retry on 4xx', @TestWithRetryStopsOn4xx);
  T.Test('WithRetry exhausts retries on 5xx', @TestWithRetryExhaustsRetries);
  T.Test('WithRetry(0) means no retry', @TestWithRetryZeroMeansNoRetry);
  T.Test('WithRetry chains with WithBearerAuth', @TestWithRetryChainsWithAuth);
  T.Test('WithRetry rejects negative count', @TestWithRetryRejectsNegative);
  T.Test('WithRetry retries hekTimeout exception', @TestWithRetryRetriesTimeoutException);
  T.Test('WithRetry retries hekConnect exception', @TestWithRetryRetriesConnectException);
  T.Test('WithRetry does not retry hekParse', @TestWithRetryDoesNotRetryParseException);
  T.Test('WithRetry does not retry non-idempotent POST', @TestWithRetryDoesNotRetryNonIdempotentPost);
  T.Test('WithRetry retries POST with Idempotency-Key', @TestWithRetryRetriesPostWithIdempotencyKey);
  T.Test('HttpIsRetrySafeRequest helpers', @TestHttpIsRetrySafeRequestHelpers);
  T.Test('WithRetry retries 429 with Retry-After:0', @TestWithRetryRetries429WithRetryAfterZero);
  T.Test('WithRetry retries 429 with past HTTP-date Retry-After',
    @TestWithRetryRetries429WithHttpDateRetryAfterPast);
  T.Test('WithRetry 503 invalid Retry-After still retries', @TestWithRetryRetries503WithInvalidRetryAfter);
  T.Test('WithRetry does not retry other 4xx', @TestWithRetryDoesNotRetryOther4xx);
  T.Test('HttpPut/PatchJsonDocument parse object on 200',
    @TestHttpPutPatchJsonDocumentSuccess);
  T.Test('CancelToken raises hekCanceled at Send', @TestCancelTokenRaisesHekCanceledAtSend);
  T.Test('CancelToken allows send when not canceled', @TestCancelTokenNotCanceledAllowsSend);
  T.Test('Client sends H1 chunked request body', @TestClientSendsChunkedRequestBody);
  T.Test('Client cookie jar injects and stores', @TestClientCookieJarInjectsAndStores);
  T.Test('Client cookie jar Max-Age=0 expires', @TestClientCookieJarExpiresMaxAge);
  T.Test('Client HTTP proxy absolute-form', @TestClientHttpProxyAbsoluteForm);
  T.Test('Client WithProxyUrl fluent absolute-form',
    @TestClientWithProxyUrlFluentAbsoluteForm);
  T.Test('Client HTTPS proxy CONNECT tunnel',
    @TestClientHttpsProxyConnectTunnel);
  T.Test('Client HTTPS proxy CONNECT denied',
    @TestClientHttpsProxyConnectDenied);
  T.Test('Client direct HTTPS round-trip',
    @TestClientDirectHttpsRoundTrip);
  T.Test('Client WithTLSContext fluent direct HTTPS',
    @TestClientWithTLSContextFluentDirectHttps);
  T.Test('Client HTTPS proxy CONNECT 407 Basic-only message',
    @TestClientHttpsProxyConnect407BasicOnlyMessage);
  T.Test('Proxy auth Basic-only source contract',
    @TestProxyAuthBasicOnlySourceContract);
  T.Test('Client HTTPS proxy CONNECT Basic auth',
    @TestClientHttpsProxyConnectWithBasicAuth);
  T.Test('Client HTTP proxy absolute-form Basic auth',
    @TestClientHttpProxyAbsoluteFormWithBasicAuth);
  T.Test('Client HTTP proxy keeps explicit Proxy-Authorization',
    @TestClientHttpProxyAbsoluteFormKeepsExplicitProxyAuth);
  T.Test('Client WithConnectTimeout fluent rebuilds',
    @TestClientWithConnectTimeoutFluent);
  T.Test('Client WithConnectTimeout source contract',
    @TestClientWithConnectTimeoutSourceContract);
  T.Test('Client live ConnectTimeout via backlog-full peer',
    @TestClientLiveConnectTimeout);
  T.Test('Client live mid-read cancel via hold server',
    @TestClientLiveMidReadCancel);
  T.Test('Client cancel/transport CreateOp source contract',
    @TestClientCancelAndTransportCreateOpSourceContract);
  T.Test('Client taxonomy Ops aligned source contract',
    @TestClientTaxonomyOpsAlignedSourceContract);
  T.Test('Client PostMultipart encodes fields and files', @TestClientPostMultipart);
  T.Test('Client ConnectTimeout option defaults',
    @TestClientConnectTimeoutOptionDefault);
  T.Test('Client default User-Agent', @TestClientDefaultUserAgent);
  T.Test('Client GetString method', @TestClientGetStringMethod);
  T.Test('Client PostString method', @TestClientPostStringMethod);
  T.Test('Client PostString raises with context',
    @TestClientPostStringRaisesWithContext);
  T.Test('Client Put/Patch/DeleteString methods',
    @TestClientPutPatchDeleteStringMethods);
  T.Test('Client ResponseStatus fires before body chunks',
    @TestClientResponseStatusFiresBeforeBodyChunks);
  T.Test('Client ResponseStatus precedes coalesced body chunk',
    @TestClientResponseStatusPrecedesCoalescedBodyChunk);
  T.Test('Client ResponseStatus precedes coalesced body chunk after 1xx',
    @TestClientResponseStatusPrecedesCoalescedBodyChunkAfterInformational);
  T.Test('Client ResponseStatus reports non-2xx error status',
    @TestClientResponseStatusReportsErrorStatus);
  T.Test('Client SkipBodyBuffer streams without retaining body',
    @TestClientSkipBodyBufferStreamsWithoutRetaining);
  T.Test('Client zero-body stream completes at headers (status-split)',
    @TestClientZeroBodyStreamCompletesAtHeaders);
  if not T.Run then Halt(1);
end.
