unit nextpas.core.http.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.server.base,
  nextpas.core.net.server.intf,
  nextpas.core.http.base,
  nextpas.core.http.form.base,
  nextpas.core.json.value;

type
  TStringArray = nextpas.core.base.TStringArray;
  TFormFieldArray = nextpas.core.http.form.base.TFormFieldArray;
  TJsonValue = nextpas.core.json.value.TJsonValue;
  TTcpServerConnOwnership = nextpas.core.net.server.base.TTcpServerConnOwnership;
  ITcpServerSession = nextpas.core.net.server.intf.ITcpServerSession;
  ITcpServerSessionContext = nextpas.core.net.server.intf.ITcpServerSessionContext;
  THttpRequestOptions = nextpas.core.http.base.THttpRequestOptions;

  { Header callback for iteration }
  THeaderIterator = reference to procedure(const AName, AValue: string);

  {** Per-request context for middleware-to-handler data propagation.
     Thread-safe key-value store attached to a request by context middleware.
     Values are TObject descendants; nil means "not set".
     Typical keys: 'auth_user', 'request_id', 'trace_id', 'session'. }
  IHttpContext = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000011}']
    procedure SetValue(const AKey: string; const AValue: TObject);
    function GetValue(const AKey: string): TObject;
    function Has(const AKey: string): Boolean;
    procedure Remove(const AKey: string);
  end;

  IHttpHeaders = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000001}']
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

  IHttpRequest = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000010002}']
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
    function PathParam(const AName: string): string;
    function QueryParam(const AName: string): string;
    property Method: THttpMethod read GetMethod;
    property Url: TUrl read GetUrl;
    property Path: string read GetPath;
    property RawQuery: string read GetRawQuery;
    property Version: THttpVersion read GetVersion;
    property Headers: IHttpHeaders read GetHeaders;
    property Trailers: IHttpHeaders read GetTrailers;
    property Body: IReader read GetBody;
    property ContentLength: Int64 read GetContentLength;
    property RemoteAddr: string read GetRemoteAddr;
  end;

  { Per-request options that override client defaults when present on a request }
  IHttpRequestWithOptions = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000010010}']
    function GetRequestOptions: THttpRequestOptions;
    procedure SetRequestOptions(const AOptions: THttpRequestOptions);
    property RequestOptions: THttpRequestOptions read GetRequestOptions;
  end;

  IHttpResponse = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000003}']
    function GetStatusCode: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function GetBody: IReader;
    property StatusCode: THttpStatus read GetStatusCode;
    property Headers: IHttpHeaders read GetHeaders;
    property Body: IReader read GetBody;
  end;

  IHttpResponseWriter = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000004}']
    procedure WriteHeader(const AStatus: THttpStatus);
    function GetStatus: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Flush;
    property Headers: IHttpHeaders read GetHeaders;
  end;

  { Query actual response body bytes written.
    Implemented by response writers that track byte counts.
    Metrics middleware uses this to report accurate ResponseBytes. }
  IHttpResponseBodyBytes = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-40000000000D}']
    function GetBodyBytesWritten: Int64;
  end;

  { Hijack the underlying connection from the HTTP server.
    After Hijack, the server loop will not touch the connection. }
  IHttpHijacker = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-40000000000C}']
    function Hijack: ITcpStream;
  end;

  { Forward declarations for handler types }
  IHttpHandler = interface;

  { Handler — three callback forms }
  THttpHandlerFunc = reference to procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
  THttpHandlerMethod = procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter) of object;
  THttpHandlerProc = procedure(const AReq: IHttpRequest; const AW: IHttpResponseWriter);

  IHttpHandler = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000005}']
    procedure ServeHTTP(const AReq: IHttpRequest; const AW: IHttpResponseWriter);
  end;

  IHttpMiddleware = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000006}']
    function Wrap(const ANext: IHttpHandler): IHttpHandler;
  end;

  IHttpRouter = interface(IHttpHandler)
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000007}']
    procedure Handle(const AMethod: THttpMethod; const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Get(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Head(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Post(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Put(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Delete(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Patch(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Options(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Connect(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Trace(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Use(const AMiddleware: IHttpMiddleware);
  end;

  IHttpServer = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000008}']
    procedure ListenAndServe(const AAddr: string; const APort: UInt16);
    procedure Shutdown;
    function LocalAddr: TNetAddress;
    function IsRunning: Boolean;
  end;

  IHttpClient = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000009}']
    function Send(const AReq: IHttpRequest): IHttpResponse;
    procedure CloseIdleConnections;
    function Get(const AUrl: string): IHttpResponse;
    function Post(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse; overload;
    function Post(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload;
    function Post(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload;
    function Put(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse; overload;
    function Put(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload;
    function Put(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload;
    function Delete(const AUrl: string): IHttpResponse; overload;
    function Delete(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse; overload;
    function Delete(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload;
    function Delete(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload;
    function Patch(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse; overload;
    function Patch(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload;
    function Patch(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload;
    function Head(const AUrl: string): IHttpResponse;
    function Options(const AUrl: string): IHttpResponse;
    function PostForm(const AUrl: string; const AFields: TFormFieldArray): IHttpResponse;
    function PostJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
    function PutJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
    function PatchJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
    function DeleteJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
    {** Send a streaming request whose body is NOT buffered into memory.
       The body reader is passed directly to the transport. Send takes ownership
       of the body and closes it after the round trip (success or error).
       Content-Length must be known and declared. }
    function SendStreaming(const AMethod: THttpMethod; const AUrl: string;
      const AContentType: string; const ABody: IReader;
      const AContentLength: Int64): IHttpResponse;
    function WithBasicAuth(const AUsername, APassword: string): IHttpClient;
    function WithBearerAuth(const AToken: string): IHttpClient;
    function WithHeader(const AName, AValue: string): IHttpClient;
    function WithTimeout(const ATimeoutMs: Int64): IHttpClient;
    function WithMaxRedirects(const AMaxRedirects: Int32): IHttpClient;
    function WithFollowRedirects(const AFollow: Boolean): IHttpClient;
    {** @desc Returns a decorator that retries failed requests up to AMaxRetries times.
       Retries on 5xx server errors with exponential backoff (100ms base, max 5s).
       Does NOT retry on 4xx client errors. }
    function WithRetry(const AMaxRetries: Int32): IHttpClient;
  end;

  { Transport layer — protocol implementations register these }
  IHttpTransport = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-40000000000A}']
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
  end;

  IHttpTransportIdleConnections = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-40000000000F}']
    procedure CloseIdleConnections;
  end;

  IHttpServerTransport = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-40000000000B}']
    function ServeConn(const AConn: ITcpStream;
      const AHandler: IHttpHandler): TTcpServerConnOwnership;
  end;

  IHttpServerSessionFactory = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-40000000000D}']
    function NewSession(const AConn: ITcpStream;
      const AHandler: IHttpHandler): ITcpServerSession;
  end;

  IHttpServerSessionFactoryWithContext = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-40000000000E}']
    function NewSession(const AConn: ITcpStream; const AHandler: IHttpHandler;
      const AContext: ITcpServerSessionContext): ITcpServerSession;
  end;

  IH2StreamControl = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000010}']
    procedure Reset(const AErrorCode: UInt32);
    function GetStreamID: UInt32;
    property StreamID: UInt32 read GetStreamID;
  end;

const
  TCP_SERVER_CONN_OWNERSHIP_SERVER = nextpas.core.net.server.base.tscoServer;
  TCP_SERVER_CONN_OWNERSHIP_HANDLER = nextpas.core.net.server.base.tscoHandler;

implementation

end.
