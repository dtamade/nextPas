unit nextpas.core.http.extensions;
{**
 * @desc HTTP extensions facade. Pure re-export of product helpers:
 *       static file serving, WebSocket (server/client/room), SSE, stream
 *       streaming, cookies, forms/multipart and low-level utils (headers/url,
 *       TCP backend, ETag helpers). Owners retain logic (`nextpas.core.http.static`,
 *       `.websocket`, `.sse`, `.stream`, `.cookie`, `.form`, `.headers`, `.url`,
 *       `nextpas.core.bytes.ops` single source); facade only aggregates via inline
 *       thin forwarding. Thin consumers should `uses nextpas.core.http.extensions`
 *       (or `messages`/`transports`/`minimal`/`middlewares`) for minimal surface;
 *       full surface remains `uses nextpas.core.http` stable umbrella.
 *
 *       Performance: inline thin forwarding (const string/TBytes), real loops/SIMD
 *       stay out-of-line per design-conventions; bytes.ops single source stays in
 *       owners (e.g. `bytes.ops` SpanCompare, FNV hash for ETag). Zero-copy where
 *       applicable (TByteSpan pending tail view, stream chunk views). Stability:
 *       resource release via owner (`try/finally`/`Close`/`FreeAndNil`/`PoolClear`);
 *       facade adds no ownership. CONTRACT is truth, missing capability → back-feed owner.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.vfs.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.url,
  nextpas.core.http.static,
  nextpas.core.http.websocket,
  nextpas.core.http.websocket.room,
  nextpas.core.http.sse,
  nextpas.core.http.stream,
  nextpas.core.http.cookie,
  nextpas.core.http.form,
  nextpas.core.net.server;

type
  TSameSite = nextpas.core.http.cookie.TSameSite;
  TRequestCookies = nextpas.core.http.cookie.TRequestCookies;
  TSetCookie = nextpas.core.http.cookie.TSetCookie;
  IHttpCookieJar = nextpas.core.http.intf.IHttpCookieJar;
  TSSEvent = nextpas.core.http.sse.TSSEvent;
  ISSEEventWriter = nextpas.core.http.sse.ISSEEventWriter;
  TWebSocketOptions = nextpas.core.http.websocket.TWebSocketOptions;
  TWebSocketOriginCheck = nextpas.core.http.websocket.TWebSocketOriginCheck;
  TWebSocketOpcode = nextpas.core.http.websocket.TWebSocketOpcode;
  TWebSocketFrame = nextpas.core.http.websocket.TWebSocketFrame;
  IWebSocket = nextpas.core.http.websocket.IWebSocket;
  IWebSocketRoom = nextpas.core.http.websocket.room.IWebSocketRoom;
  TWebSocketRoomManager = nextpas.core.http.websocket.room.TWebSocketRoomManager;
  TQueryParam = nextpas.core.http.url.TQueryParam;
  TQueryParams = nextpas.core.http.url.TQueryParams;
  TFormField = nextpas.core.http.form.TFormField;
  TFormFieldArray = nextpas.core.http.form.TFormFieldArray;
  THttpFile = nextpas.core.http.form.THttpFile;
  THttpFileArray = nextpas.core.http.form.THttpFileArray;
  TMultipartFormData = nextpas.core.http.form.TMultipartFormData;
  TMultipartParseOptions = nextpas.core.http.form.TMultipartParseOptions;
  TChunkCallback = nextpas.core.http.stream.TChunkCallback;
  TTcpServerBackend = nextpas.core.http.base.TTcpServerBackend;

const
  WEBSOCKET_DEFAULT_MAX_FRAME_SIZE = nextpas.core.http.websocket.WEBSOCKET_DEFAULT_MAX_FRAME_SIZE;
  WEBSOCKET_DEFAULT_MAX_MESSAGE_SIZE = nextpas.core.http.websocket.WEBSOCKET_DEFAULT_MAX_MESSAGE_SIZE;
  WEBSOCKET_ROOM_DEFAULT_MAX = nextpas.core.http.websocket.room.WEBSOCKET_ROOM_DEFAULT_MAX;
  TCP_SERVER_BACKEND_THREADED = nextpas.core.http.base.TCP_SERVER_BACKEND_THREADED;
  TCP_SERVER_BACKEND_EPOLL = nextpas.core.http.base.TCP_SERVER_BACKEND_EPOLL;
  TCP_SERVER_BACKEND_KQUEUE = nextpas.core.http.base.TCP_SERVER_BACKEND_KQUEUE;
  TCP_SERVER_BACKEND_IOCP = nextpas.core.http.base.TCP_SERVER_BACKEND_IOCP;
  TCP_SERVER_CONN_OWNERSHIP_SERVER = nextpas.core.http.intf.TCP_SERVER_CONN_OWNERSHIP_SERVER;
  TCP_SERVER_CONN_OWNERSHIP_HANDLER = nextpas.core.http.intf.TCP_SERVER_CONN_OWNERSHIP_HANDLER;
  wsOpContinuation = nextpas.core.http.websocket.wsOpContinuation;
  wsOpText = nextpas.core.http.websocket.wsOpText;
  wsOpBinary = nextpas.core.http.websocket.wsOpBinary;
  wsOpClose = nextpas.core.http.websocket.wsOpClose;
  wsOpPing = nextpas.core.http.websocket.wsOpPing;
  wsOpPong = nextpas.core.http.websocket.wsOpPong;

function DefaultTcpServerBackend: TTcpServerBackend; inline;
function TcpServerBackendName(const ABackend: TTcpServerBackend): string; inline;

function NewHeaders: IHttpHeaders; inline;
procedure SetBasicAuth(const AHeaders: IHttpHeaders; const AUsername, APassword: string); inline;
procedure SetBearerAuth(const AHeaders: IHttpHeaders; const AToken: string); inline;

function UrlEncode(const AStr: string): string; inline;
function UrlDecode(const AStr: string): string; inline;
function UrlDecodeQuery(const AStr: string): string; inline;
function UrlDecodePath(const AStr: string): string; inline;
function ParseQueryString(const AQuery: string): TQueryParams; inline;
function EncodeQueryString(const AParams: TQueryParams): string; inline;
function QueryParamValue(const AParams: TQueryParams; const AName: string): string; inline;
function QueryParamHas(const AParams: TQueryParams; const AName: string): Boolean; inline;

function ServeFile(const APath: string): THttpHandlerFunc; inline;
function ServeDir(const ARoot: string): THttpHandlerFunc; inline;
function ServeVfs(const AFs: IVfs): THttpHandlerFunc; inline;
function ServeFileDownload(const APath: string): THttpHandlerFunc; overload; inline;
function ServeFileDownload(const APath, ADownloadName: string): THttpHandlerFunc; overload; inline;
function HttpMakeStrongETag(const ASize, AModTime: Int64): string; inline;
function HttpIfNoneMatchMatches(const AIfNoneMatch, AServerETag: string): Boolean; inline;
function HttpNotModifiedSince(const AIfModifiedSince: string; const AModTimeUnix: Int64): Boolean; inline;
function HttpTryWriteNotModified(const AReq: IHttpRequest; const AW: IHttpResponseWriter; const AETag, ALastModified: string; const AModTimeUnix: Int64): Boolean; inline;

function UpgradeWebSocket(const AReq: IHttpRequest; const AW: IHttpResponseWriter): IWebSocket; overload; inline;
function UpgradeWebSocket(const AReq: IHttpRequest; const AW: IHttpResponseWriter; const AOptions: TWebSocketOptions): IWebSocket; overload; inline;
function ConnectWebSocket(const AUrl: string): IWebSocket; overload; inline;
function ConnectWebSocket(const AUrl: string; const AOptions: TWebSocketOptions): IWebSocket; overload; inline;
function ConnectWebSocket(const AClient: IHttpClient; const AUrl: string): IWebSocket; overload; inline;
function ConnectWebSocket(const AClient: IHttpClient; const AUrl: string; const AOptions: TWebSocketOptions): IWebSocket; overload; inline;

function StartSSE(const AW: IHttpResponseWriter): ISSEEventWriter; inline;
function MakeSSEvent(const AType, AData, AId: string): TSSEvent; inline;

function HttpWriteStream(const AW: IHttpResponseWriter; const AReader: IReader; const ABufSize: SizeUInt = 32768): Int64; inline;
function HttpWriteStreamWithLength(const AW: IHttpResponseWriter; const AContentLength: Int64; const AReader: IReader; const ABufSize: SizeUInt = 32768): Int64; inline;
function HttpRequestReadChunks(const ABody: IReader; const ABufSize: SizeUInt; const AOnChunk: TChunkCallback): Int64; inline;
function HttpRequestReadBody(const ABody: IReader; const AMaxBytes: Int64; const ABufSize: SizeUInt = 32768): TBytes; inline;

function ParseCookies(const AHeaderValue: string): TRequestCookies; inline;
function BuildSetCookie(const ACookie: TSetCookie): string; inline;
function MakeCookie(const AName, AValue: string): TSetCookie; inline;
function ParseSingleCookie(const AStr: string; out AName, AValue: string): Boolean; inline;
function NewHttpCookieJar: IHttpCookieJar; inline;
function HttpCookieSiteKey(const AHost: string): string; inline;

function EncodeUrlEncodedForm(const AFields: TFormFieldArray): string; inline;
function NewMultipartBoundary: string; inline;
function EncodeMultipartFormData(const AFields: TFormFieldArray; const AFiles: THttpFileArray; const ABoundary: string = ''): string; inline;
function MultipartParseOptionsDefault: TMultipartParseOptions; inline;
function ParseMultipartFormData(const ABody, ABoundary: string): TMultipartFormData; inline;
function ParseMultipartFormDataFromReader(const ABody: IReader; const ABoundary: string; const AOptions: TMultipartParseOptions): TMultipartFormData; inline;

implementation

function DefaultTcpServerBackend: TTcpServerBackend;
begin
  Result := nextpas.core.net.server.DefaultTcpServerBackend;
end;

function TcpServerBackendName(const ABackend: TTcpServerBackend): string;
begin
  Result := nextpas.core.net.server.TcpServerBackendName(ABackend);
end;

function NewHeaders: IHttpHeaders;
begin
  Result := nextpas.core.http.headers.NewHttpHeaders;
end;

procedure SetBasicAuth(const AHeaders: IHttpHeaders; const AUsername, APassword: string);
begin
  nextpas.core.http.headers.SetBasicAuth(AHeaders, AUsername, APassword);
end;

procedure SetBearerAuth(const AHeaders: IHttpHeaders; const AToken: string);
begin
  nextpas.core.http.headers.SetBearerAuth(AHeaders, AToken);
end;

function UrlEncode(const AStr: string): string;
begin
  Result := nextpas.core.http.url.UrlEncode(AStr);
end;

function UrlDecode(const AStr: string): string;
begin
  Result := nextpas.core.http.url.UrlDecode(AStr);
end;

function UrlDecodeQuery(const AStr: string): string;
begin
  Result := nextpas.core.http.url.UrlDecodeQuery(AStr);
end;

function UrlDecodePath(const AStr: string): string;
begin
  Result := nextpas.core.http.url.UrlDecodePath(AStr);
end;

function ParseQueryString(const AQuery: string): TQueryParams;
begin
  Result := nextpas.core.http.url.ParseQueryString(AQuery);
end;

function EncodeQueryString(const AParams: TQueryParams): string;
begin
  Result := nextpas.core.http.url.EncodeQueryString(AParams);
end;

function QueryParamValue(const AParams: TQueryParams; const AName: string): string;
begin
  Result := nextpas.core.http.url.QueryParamValue(AParams, AName);
end;

function QueryParamHas(const AParams: TQueryParams; const AName: string): Boolean;
begin
  Result := nextpas.core.http.url.QueryParamHas(AParams, AName);
end;

function ServeFile(const APath: string): THttpHandlerFunc;
begin
  Result := nextpas.core.http.static.ServeFile(APath);
end;

function ServeDir(const ARoot: string): THttpHandlerFunc;
begin
  Result := nextpas.core.http.static.ServeDir(ARoot);
end;

function ServeVfs(const AFs: IVfs): THttpHandlerFunc;
begin
  Result := nextpas.core.http.static.ServeVfs(AFs);
end;

function ServeFileDownload(const APath: string): THttpHandlerFunc;
begin
  Result := nextpas.core.http.static.ServeFileDownload(APath);
end;

function ServeFileDownload(const APath, ADownloadName: string): THttpHandlerFunc;
begin
  Result := nextpas.core.http.static.ServeFileDownload(APath, ADownloadName);
end;

function HttpMakeStrongETag(const ASize, AModTime: Int64): string;
begin
  Result := nextpas.core.http.static.HttpMakeStrongETag(ASize, AModTime);
end;

function HttpIfNoneMatchMatches(const AIfNoneMatch, AServerETag: string): Boolean;
begin
  Result := nextpas.core.http.static.HttpIfNoneMatchMatches(AIfNoneMatch, AServerETag);
end;

function HttpNotModifiedSince(const AIfModifiedSince: string; const AModTimeUnix: Int64): Boolean;
begin
  Result := nextpas.core.http.static.HttpNotModifiedSince(AIfModifiedSince, AModTimeUnix);
end;

function HttpTryWriteNotModified(const AReq: IHttpRequest; const AW: IHttpResponseWriter; const AETag, ALastModified: string; const AModTimeUnix: Int64): Boolean;
begin
  Result := nextpas.core.http.static.HttpTryWriteNotModified(AReq, AW, AETag, ALastModified, AModTimeUnix);
end;

function UpgradeWebSocket(const AReq: IHttpRequest; const AW: IHttpResponseWriter): IWebSocket;
begin
  Result := nextpas.core.http.websocket.UpgradeWebSocket(AReq, AW);
end;

function UpgradeWebSocket(const AReq: IHttpRequest; const AW: IHttpResponseWriter; const AOptions: TWebSocketOptions): IWebSocket;
begin
  Result := nextpas.core.http.websocket.UpgradeWebSocket(AReq, AW, AOptions);
end;

function ConnectWebSocket(const AUrl: string): IWebSocket;
begin
  Result := nextpas.core.http.websocket.ConnectWebSocket(AUrl);
end;

function ConnectWebSocket(const AUrl: string; const AOptions: TWebSocketOptions): IWebSocket;
begin
  Result := nextpas.core.http.websocket.ConnectWebSocket(AUrl, AOptions);
end;

function ConnectWebSocket(const AClient: IHttpClient; const AUrl: string): IWebSocket;
begin
  Result := nextpas.core.http.websocket.ConnectWebSocket(AClient, AUrl);
end;

function ConnectWebSocket(const AClient: IHttpClient; const AUrl: string; const AOptions: TWebSocketOptions): IWebSocket;
begin
  Result := nextpas.core.http.websocket.ConnectWebSocket(AClient, AUrl, AOptions);
end;

function StartSSE(const AW: IHttpResponseWriter): ISSEEventWriter;
begin
  Result := nextpas.core.http.sse.StartSSE(AW);
end;

function MakeSSEvent(const AType, AData, AId: string): TSSEvent;
begin
  Result := nextpas.core.http.sse.MakeSSEvent(AType, AData, AId);
end;

function HttpWriteStream(const AW: IHttpResponseWriter; const AReader: IReader; const ABufSize: SizeUInt): Int64;
begin
  Result := nextpas.core.http.stream.HttpWriteStream(AW, AReader, ABufSize);
end;

function HttpWriteStreamWithLength(const AW: IHttpResponseWriter; const AContentLength: Int64; const AReader: IReader; const ABufSize: SizeUInt): Int64;
begin
  Result := nextpas.core.http.stream.HttpWriteStreamWithLength(AW, AContentLength, AReader, ABufSize);
end;

function HttpRequestReadChunks(const ABody: IReader; const ABufSize: SizeUInt; const AOnChunk: TChunkCallback): Int64;
begin
  Result := nextpas.core.http.stream.HttpRequestReadChunks(ABody, ABufSize, AOnChunk);
end;

function HttpRequestReadBody(const ABody: IReader; const AMaxBytes: Int64; const ABufSize: SizeUInt): TBytes;
begin
  Result := nextpas.core.http.stream.HttpRequestReadBody(ABody, AMaxBytes, ABufSize);
end;

function ParseCookies(const AHeaderValue: string): TRequestCookies;
begin
  Result := nextpas.core.http.cookie.ParseCookies(AHeaderValue);
end;

function BuildSetCookie(const ACookie: TSetCookie): string;
begin
  Result := nextpas.core.http.cookie.BuildSetCookie(ACookie);
end;

function MakeCookie(const AName, AValue: string): TSetCookie;
begin
  Result := nextpas.core.http.cookie.MakeCookie(AName, AValue);
end;

function ParseSingleCookie(const AStr: string; out AName, AValue: string): Boolean;
begin
  Result := nextpas.core.http.cookie.ParseSingleCookie(AStr, AName, AValue);
end;

function NewHttpCookieJar: IHttpCookieJar;
begin
  Result := nextpas.core.http.cookie.NewHttpCookieJar;
end;

function HttpCookieSiteKey(const AHost: string): string;
begin
  Result := nextpas.core.http.cookie.HttpCookieSiteKey(AHost);
end;

function EncodeUrlEncodedForm(const AFields: TFormFieldArray): string;
begin
  Result := nextpas.core.http.form.EncodeUrlEncodedForm(AFields);
end;

function NewMultipartBoundary: string;
begin
  Result := nextpas.core.http.form.NewMultipartBoundary;
end;

function EncodeMultipartFormData(const AFields: TFormFieldArray; const AFiles: THttpFileArray; const ABoundary: string): string;
begin
  Result := nextpas.core.http.form.EncodeMultipartFormData(AFields, AFiles, ABoundary);
end;

function MultipartParseOptionsDefault: TMultipartParseOptions;
begin
  Result := nextpas.core.http.form.MultipartParseOptionsDefault;
end;

function ParseMultipartFormData(const ABody, ABoundary: string): TMultipartFormData;
begin
  Result := nextpas.core.http.form.ParseMultipartFormData(ABody, ABoundary);
end;

function ParseMultipartFormDataFromReader(const ABody: IReader; const ABoundary: string; const AOptions: TMultipartParseOptions): TMultipartFormData;
begin
  Result := nextpas.core.http.form.ParseMultipartFormDataFromReader(ABody, ABoundary, AOptions);
end;

end.
