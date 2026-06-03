unit nextpas.core.http.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.http.base;

type
  TStringArray = array of string;

  { Header callback for iteration }
  THeaderIterator = reference to procedure(const AName, AValue: string);

  IHttpHeaders = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000001}']
    procedure Set_(const AName, AValue: string);
    procedure Add(const AName, AValue: string);
    function Get(const AName: string): string;
    function GetAll(const AName: string): TStringArray;
    function Has(const AName: string): Boolean;
    procedure Del(const AName: string);
    function Count: Int32;
    procedure ForEach(const ACallback: THeaderIterator);
    function Clone: IHttpHeaders;
  end;

  IHttpRequest = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000002}']
    function GetMethod: THttpMethod;
    function GetUrl: TUrl;
    function GetVersion: THttpVersion;
    function GetHeaders: IHttpHeaders;
    function GetBody: IReader;
    function GetContentLength: Int64;
    function GetRemoteAddr: string;
    function PathParam(const AName: string): string;
    function QueryParam(const AName: string): string;
    property Method: THttpMethod read GetMethod;
    property Url: TUrl read GetUrl;
    property Version: THttpVersion read GetVersion;
    property Headers: IHttpHeaders read GetHeaders;
    property Body: IReader read GetBody;
    property ContentLength: Int64 read GetContentLength;
    property RemoteAddr: string read GetRemoteAddr;
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
    procedure Post(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Put(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Delete(const APattern: string; const AHandler: THttpHandlerFunc);
    procedure Use(const AMiddleware: IHttpMiddleware);
  end;

  IHttpServer = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000008}']
    procedure ListenAndServe(const AAddr: string; const APort: UInt16);
    procedure Shutdown;
    function LocalAddr: TNetAddress;
  end;

  IHttpClient = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-400000000009}']
    function Do_(const AReq: IHttpRequest): IHttpResponse;
    function Get(const AUrl: string): IHttpResponse;
    function Post(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
    function Put(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
    function Delete(const AUrl: string): IHttpResponse;
    function Patch(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
    function Head(const AUrl: string): IHttpResponse;
  end;

  { Transport layer — protocol implementations register these }
  IHttpTransport = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-40000000000A}']
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
  end;

  IHttpServerTransport = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-40000000000B}']
    procedure ServeConn(const AConn: ITcpStream; const AHandler: IHttpHandler);
  end;

implementation

end.
