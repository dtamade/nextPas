unit nextpas.core.http.extensions;
{**
 * @desc HTTP extensions facade. Pure re-export of static/websocket/sse/
 *       cookie/stream/form/mem helpers via inline zero-copy forwarding.
 *       Owner modules retain logic; this unit only aggregates.
 *
 *       Performance: inline thin forwarding (const string/TBytes), real
 *       loops/SIMD stay out-of-line per design-conventions. Bytes reuse
 *       `nextpas.core.bytes.ops` single source in owner impl.
 *       Stability: resource release via owner (try/finally, CloseIdle,
 *       HttpReleaseResponseBody); facade adds no ownership.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.static,
  nextpas.core.http.websocket,
  nextpas.core.http.websocket.room,
  nextpas.core.http.sse,
  nextpas.core.http.cookie,
  nextpas.core.http.stream,
  nextpas.core.http.form,
  nextpas.core.http.mem,
  nextpas.core.http.client,
  nextpas.core.http.server,
  nextpas.core.vfs.intf,
  nextpas.core.io.intf,
  nextpas.core.json;

type
  TSSEvent = nextpas.core.http.sse.TSSEvent;
  ISSEEventWriter = nextpas.core.http.sse.ISSEEventWriter;
  TSameSite = nextpas.core.http.cookie.TSameSite;
  TRequestCookies = nextpas.core.http.cookie.TRequestCookies;
  TSetCookie = nextpas.core.http.cookie.TSetCookie;
  TWebSocketOptions = nextpas.core.http.websocket.TWebSocketOptions;
  TWebSocketOriginCheck = nextpas.core.http.websocket.TWebSocketOriginCheck;
  TWebSocketOpcode = nextpas.core.http.websocket.TWebSocketOpcode;
  TWebSocketFrame = nextpas.core.http.websocket.TWebSocketFrame;
  IWebSocketRoom = nextpas.core.http.websocket.room.IWebSocketRoom;
  TWebSocketRoomManager = nextpas.core.http.websocket.room.TWebSocketRoomManager;
  TFormField = nextpas.core.http.form.TFormField;
  TFormFieldArray = nextpas.core.http.form.TFormFieldArray;
  THttpFile = nextpas.core.http.form.THttpFile;
  THttpFileArray = nextpas.core.http.form.THttpFileArray;
  TMultipartFormData = nextpas.core.http.form.TMultipartFormData;
  TMultipartParseOptions = nextpas.core.http.form.TMultipartParseOptions;
  TChunkCallback = nextpas.core.http.stream.TChunkCallback;
  IHttpCookieJar = nextpas.core.http.intf.IHttpCookieJar;
  IWebSocket = nextpas.core.http.websocket.IWebSocket;

const
  wsOpContinuation = nextpas.core.http.websocket.wsOpContinuation;
  wsOpText = nextpas.core.http.websocket.wsOpText;
  wsOpBinary = nextpas.core.http.websocket.wsOpBinary;
  wsOpClose = nextpas.core.http.websocket.wsOpClose;
  wsOpPing = nextpas.core.http.websocket.wsOpPing;
  wsOpPong = nextpas.core.http.websocket.wsOpPong;
  WEBSOCKET_DEFAULT_MAX_FRAME_SIZE = nextpas.core.http.websocket.WEBSOCKET_DEFAULT_MAX_FRAME_SIZE;
  WEBSOCKET_DEFAULT_MAX_MESSAGE_SIZE = nextpas.core.http.websocket.WEBSOCKET_DEFAULT_MAX_MESSAGE_SIZE;
  WEBSOCKET_ROOM_DEFAULT_MAX = nextpas.core.http.websocket.room.WEBSOCKET_ROOM_DEFAULT_MAX;

{ Static helpers }
function ServeFile(const APath: string): THttpHandlerFunc; inline;
function ServeDir(const ARoot: string): THttpHandlerFunc; inline;
function ServeVfs(const AFs: IVfs): THttpHandlerFunc; inline;
function ServeFileDownload(const APath: string): THttpHandlerFunc; overload; inline;
function ServeFileDownload(const APath, ADownloadName: string): THttpHandlerFunc; overload; inline;
function HttpMakeStrongETag(const ASize, AModTime: Int64): string; inline;
function HttpIfNoneMatchMatches(const AIfNoneMatch, AServerETag: string): Boolean; inline;
function HttpNotModifiedSince(const AIfModifiedSince: string; const AModTimeUnix: Int64): Boolean; inline;
function HttpTryWriteNotModified(const AReq: IHttpRequest; const AW: IHttpResponseWriter; const AETag, ALastModified: string; const AModTimeUnix: Int64): Boolean; inline;

{ WebSocket }
function UpgradeWebSocket(const AReq: IHttpRequest; const AW: IHttpResponseWriter): IWebSocket; overload; inline;
function UpgradeWebSocket(const AReq: IHttpRequest; const AW: IHttpResponseWriter; const AOptions: TWebSocketOptions): IWebSocket; overload; inline;
function ConnectWebSocket(const AUrl: string): IWebSocket; overload; inline;
function ConnectWebSocket(const AUrl: string; const AOptions: TWebSocketOptions): IWebSocket; overload; inline;
function ConnectWebSocket(const AClient: IHttpClient; const AUrl: string): IWebSocket; overload; inline;
function ConnectWebSocket(const AClient: IHttpClient; const AUrl: string; const AOptions: TWebSocketOptions): IWebSocket; overload; inline;

{ SSE }
function StartSSE(const AW: IHttpResponseWriter): ISSEEventWriter; inline;
function MakeSSEvent(const AType, AData, AId: string): TSSEvent; inline;

{ Stream }
function HttpWriteStream(const AW: IHttpResponseWriter; const AReader: IReader; const ABufSize: SizeUInt = 32768): Int64; inline;
function HttpWriteStreamWithLength(const AW: IHttpResponseWriter; const AContentLength: Int64; const AReader: IReader; const ABufSize: SizeUInt = 32768): Int64; inline;
function HttpRequestReadChunks(const ABody: IReader; const ABufSize: SizeUInt; const AOnChunk: TChunkCallback): Int64; inline;
function HttpRequestReadBody(const ABody: IReader; const AMaxBytes: Int64; const ABufSize: SizeUInt = 32768): TBytes; inline;

{ Cookie }
function ParseCookies(const AHeaderValue: string): TRequestCookies; inline;
function BuildSetCookie(const ACookie: TSetCookie): string; inline;
function MakeCookie(const AName, AValue: string): TSetCookie; inline;
function ParseSingleCookie(const AStr: string; out AName, AValue: string): Boolean; inline;
function NewHttpCookieJar: IHttpCookieJar; inline;
function HttpCookieSiteKey(const AHost: string): string; inline;

{ Form }
function EncodeUrlEncodedForm(const AFields: TFormFieldArray): string; inline;
function NewMultipartBoundary: string; inline;
function EncodeMultipartFormData(const AFields: TFormFieldArray; const AFiles: THttpFileArray; const ABoundary: string = ''): string; inline;
function MultipartParseOptionsDefault: TMultipartParseOptions; inline;
function ParseMultipartFormData(const ABody, ABoundary: string): TMultipartFormData; inline;
function ParseMultipartFormDataFromReader(const ABody: IReader; const ABoundary: string; const AOptions: TMultipartParseOptions): TMultipartFormData; inline;

{ Message helpers (response writing) }
function HttpWriteResponseString(const AW: IHttpResponseWriter; const AStatus: THttpStatus; const AContentType, ABody: string): SizeUInt; inline;
function HttpWriteResponseJson(const AW: IHttpResponseWriter; const AStatus: THttpStatus; const AValue: TJsonValue): SizeUInt; inline;
function HttpWriteResponseBytes(const AW: IHttpResponseWriter; const AStatus: THttpStatus; const AContentType: string; const ABody: TBytes): SizeUInt; inline;
function HttpWriteResponseHtml(const AW: IHttpResponseWriter; const AStatus: THttpStatus; const ABody: string): SizeUInt; inline;
procedure HttpWriteResponseNoContent(const AW: IHttpResponseWriter); inline;
procedure HttpWriteResponseOk(const AW: IHttpResponseWriter); inline;
procedure HttpWriteResponseCreated(const AW: IHttpResponseWriter); inline;
procedure HttpWriteResponseAccepted(const AW: IHttpResponseWriter); inline;
procedure HttpWriteResponseNotModified(const AW: IHttpResponseWriter); inline;
procedure HttpWriteResponseResetContent(const AW: IHttpResponseWriter); inline;
procedure HttpWriteResponseGone(const AW: IHttpResponseWriter); inline;
function HttpReadRequestBodyBytes(const AReq: IHttpRequest): TBytes; inline;
function HttpReadRequestBodyBytesMax(const AReq: IHttpRequest; const AMaxBytes: Int64): TBytes; inline;
function HttpReadRequestBodyBytesUnlimited(const AReq: IHttpRequest): TBytes; inline;
function HttpReadRequestBodyString(const AReq: IHttpRequest): string; inline;
function HttpReadRequestBodyJson(const AReq: IHttpRequest): IJsonDocument; inline;
procedure HttpRedirect(const AW: IHttpResponseWriter; const AStatus: THttpStatus; const ALocation: string); inline;
procedure HttpRedirectMovedPermanently(const AW: IHttpResponseWriter; const ALocation: string); inline;
procedure HttpRedirectFound(const AW: IHttpResponseWriter; const ALocation: string); inline;
procedure HttpRedirectSeeOther(const AW: IHttpResponseWriter; const ALocation: string); inline;
procedure HttpRedirectTemporaryRedirect(const AW: IHttpResponseWriter; const ALocation: string); inline;
procedure HttpRedirectPermanentRedirect(const AW: IHttpResponseWriter; const ALocation: string); inline;
function HttpWriteErrorResponse(const AW: IHttpResponseWriter; const AStatus: THttpStatus; const ACode, AMessage: string; const AInstance: string = ''): SizeUInt; inline;
function HttpWriteErrorBadRequest(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt; inline;
function HttpWriteErrorUnauthorized(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt; inline;
function HttpWriteErrorForbidden(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt; inline;
function HttpWriteErrorNotFound(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt; inline;
function HttpWriteErrorInternal(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt; inline;
function HttpWriteErrorTooManyRequests(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt; inline;
function HttpWriteErrorConflict(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt; inline;
function HttpWriteErrorUnprocessableEntity(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt; inline;
function HttpWriteErrorPayloadTooLarge(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt; inline;

{ Client body helpers }
procedure HttpReleaseResponseBody(const AResp: IHttpResponse); inline;
function HttpReadResponseBodyBytes(const AResp: IHttpResponse): TBytes; inline;
function HttpReadResponseBodyString(const AResp: IHttpResponse): string; inline;
function HttpReadResponseBodyStringAuto(const AResp: IHttpResponse): string; inline;
function HttpDecodeContentEncoding(const AEncoding: string; const ABody: TBytes; const AMaxSize: Int64 = 0): TBytes; inline;
function HttpReadResponseBodyBytesDecoded(const AResp: IHttpResponse; const AMaxSize: Int64 = 0): TBytes; inline;
function HttpReadResponseBodyStringDecoded(const AResp: IHttpResponse; const AMaxSize: Int64 = 0): string; inline;
function HttpEnsureSuccess(const AResp: IHttpResponse): IHttpResponse; overload; inline;
function HttpEnsureSuccess(const AResp: IHttpResponse; const AMethod, AUrl: string): IHttpResponse; overload; inline;
function HttpGetString(const AClient: IHttpClient; const AUrl: string): string; inline;
function HttpGetBytes(const AClient: IHttpClient; const AUrl: string): TBytes; inline;
function HttpReadResponseJson(const AResp: IHttpResponse): IJsonDocument; overload; inline;
function HttpReadResponseJson(const AResp: IHttpResponse; const AMethod, AUrl: string): IJsonDocument; overload; inline;
function HttpGetJson(const AClient: IHttpClient; const AUrl: string): IJsonDocument; inline;
function HttpPostString(const AClient: IHttpClient; const AUrl, AContentType, ABody: string): string; inline;
function HttpPutString(const AClient: IHttpClient; const AUrl, AContentType, ABody: string): string; inline;
function HttpPatchString(const AClient: IHttpClient; const AUrl, AContentType, ABody: string): string; inline;
function HttpDeleteString(const AClient: IHttpClient; const AUrl: string): string; inline;
function HttpHead(const AClient: IHttpClient; const AUrl: string): IHttpResponse; inline;
function HttpOptions(const AClient: IHttpClient; const AUrl: string): IHttpResponse; inline;
function HttpPostJson(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): string; inline;
function HttpPutJson(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): string; inline;
function HttpPatchJson(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): string; inline;
function HttpDeleteJson(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): string; inline;
function HttpPostJsonDocument(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): IJsonDocument; inline;
function HttpPutJsonDocument(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): IJsonDocument; inline;
function HttpPatchJsonDocument(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): IJsonDocument; inline;
function HttpGetToWriter(const AClient: IHttpClient; const AUrl: string; const ADest: IWriter): Int64; inline;
function HttpGetToFile(const AClient: IHttpClient; const AUrl, ADestPath: string): Int64; inline;
function ExtractCharsetFromContentType(const AContentType: string): string; inline;

implementation

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

function HttpWriteResponseString(const AW: IHttpResponseWriter; const AStatus: THttpStatus; const AContentType, ABody: string): SizeUInt;
begin
  Result := nextpas.core.http.message.HttpWriteResponseString(AW, AStatus, AContentType, ABody);
end;

function HttpWriteResponseJson(const AW: IHttpResponseWriter; const AStatus: THttpStatus; const AValue: TJsonValue): SizeUInt;
begin
  Result := nextpas.core.http.message.HttpWriteResponseJson(AW, AStatus, AValue);
end;

function HttpWriteResponseBytes(const AW: IHttpResponseWriter; const AStatus: THttpStatus; const AContentType: string; const ABody: TBytes): SizeUInt;
begin
  Result := nextpas.core.http.message.HttpWriteResponseBytes(AW, AStatus, AContentType, ABody);
end;

function HttpWriteResponseHtml(const AW: IHttpResponseWriter; const AStatus: THttpStatus; const ABody: string): SizeUInt;
begin
  Result := nextpas.core.http.message.HttpWriteResponseHtml(AW, AStatus, ABody);
end;

procedure HttpWriteResponseNoContent(const AW: IHttpResponseWriter);
begin
  nextpas.core.http.message.HttpWriteResponseNoContent(AW);
end;

procedure HttpWriteResponseOk(const AW: IHttpResponseWriter);
begin
  nextpas.core.http.message.HttpWriteResponseOk(AW);
end;

procedure HttpWriteResponseCreated(const AW: IHttpResponseWriter);
begin
  nextpas.core.http.message.HttpWriteResponseCreated(AW);
end;

procedure HttpWriteResponseAccepted(const AW: IHttpResponseWriter);
begin
  nextpas.core.http.message.HttpWriteResponseAccepted(AW);
end;

procedure HttpWriteResponseNotModified(const AW: IHttpResponseWriter);
begin
  nextpas.core.http.message.HttpWriteResponseNotModified(AW);
end;

procedure HttpWriteResponseResetContent(const AW: IHttpResponseWriter);
begin
  nextpas.core.http.message.HttpWriteResponseResetContent(AW);
end;

procedure HttpWriteResponseGone(const AW: IHttpResponseWriter);
begin
  nextpas.core.http.message.HttpWriteResponseGone(AW);
end;

function HttpReadRequestBodyBytes(const AReq: IHttpRequest): TBytes;
begin
  Result := nextpas.core.http.message.HttpReadRequestBodyBytes(AReq);
end;

function HttpReadRequestBodyBytesMax(const AReq: IHttpRequest; const AMaxBytes: Int64): TBytes;
begin
  Result := nextpas.core.http.message.HttpReadRequestBodyBytesMax(AReq, AMaxBytes);
end;

function HttpReadRequestBodyBytesUnlimited(const AReq: IHttpRequest): TBytes;
begin
  Result := nextpas.core.http.message.HttpReadRequestBodyBytesUnlimited(AReq);
end;

function HttpReadRequestBodyString(const AReq: IHttpRequest): string;
begin
  Result := nextpas.core.http.message.HttpReadRequestBodyString(AReq);
end;

function HttpReadRequestBodyJson(const AReq: IHttpRequest): IJsonDocument;
begin
  Result := nextpas.core.http.message.HttpReadRequestBodyJson(AReq);
end;

procedure HttpRedirect(const AW: IHttpResponseWriter; const AStatus: THttpStatus; const ALocation: string);
begin
  nextpas.core.http.message.HttpRedirect(AW, AStatus, ALocation);
end;

procedure HttpRedirectMovedPermanently(const AW: IHttpResponseWriter; const ALocation: string);
begin
  nextpas.core.http.message.HttpRedirectMovedPermanently(AW, ALocation);
end;

procedure HttpRedirectFound(const AW: IHttpResponseWriter; const ALocation: string);
begin
  nextpas.core.http.message.HttpRedirectFound(AW, ALocation);
end;

procedure HttpRedirectSeeOther(const AW: IHttpResponseWriter; const ALocation: string);
begin
  nextpas.core.http.message.HttpRedirectSeeOther(AW, ALocation);
end;

procedure HttpRedirectTemporaryRedirect(const AW: IHttpResponseWriter; const ALocation: string);
begin
  nextpas.core.http.message.HttpRedirectTemporaryRedirect(AW, ALocation);
end;

procedure HttpRedirectPermanentRedirect(const AW: IHttpResponseWriter; const ALocation: string);
begin
  nextpas.core.http.message.HttpRedirectPermanentRedirect(AW, ALocation);
end;

function HttpWriteErrorResponse(const AW: IHttpResponseWriter; const AStatus: THttpStatus; const ACode, AMessage: string; const AInstance: string): SizeUInt;
begin
  Result := nextpas.core.http.message.HttpWriteErrorResponse(AW, AStatus, ACode, AMessage, AInstance);
end;

function HttpWriteErrorBadRequest(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.message.HttpWriteErrorBadRequest(AW, AMessage);
end;

function HttpWriteErrorUnauthorized(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.message.HttpWriteErrorUnauthorized(AW, AMessage);
end;

function HttpWriteErrorForbidden(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.message.HttpWriteErrorForbidden(AW, AMessage);
end;

function HttpWriteErrorNotFound(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.message.HttpWriteErrorNotFound(AW, AMessage);
end;

function HttpWriteErrorInternal(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.message.HttpWriteErrorInternal(AW, AMessage);
end;

function HttpWriteErrorTooManyRequests(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.message.HttpWriteErrorTooManyRequests(AW, AMessage);
end;

function HttpWriteErrorConflict(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.message.HttpWriteErrorConflict(AW, AMessage);
end;

function HttpWriteErrorUnprocessableEntity(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.message.HttpWriteErrorUnprocessableEntity(AW, AMessage);
end;

function HttpWriteErrorPayloadTooLarge(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.message.HttpWriteErrorPayloadTooLarge(AW, AMessage);
end;

procedure HttpReleaseResponseBody(const AResp: IHttpResponse);
begin
  nextpas.core.http.client.HttpReleaseResponseBody(AResp);
end;

function HttpReadResponseBodyBytes(const AResp: IHttpResponse): TBytes;
begin
  Result := nextpas.core.http.client.HttpReadResponseBodyBytes(AResp);
end;

function HttpReadResponseBodyString(const AResp: IHttpResponse): string;
begin
  Result := nextpas.core.http.client.HttpReadResponseBodyString(AResp);
end;

function HttpReadResponseBodyStringAuto(const AResp: IHttpResponse): string;
begin
  Result := nextpas.core.http.client.HttpReadResponseBodyStringAuto(AResp);
end;

function HttpDecodeContentEncoding(const AEncoding: string; const ABody: TBytes; const AMaxSize: Int64): TBytes;
begin
  Result := nextpas.core.http.client.HttpDecodeContentEncoding(AEncoding, ABody, AMaxSize);
end;

function HttpReadResponseBodyBytesDecoded(const AResp: IHttpResponse; const AMaxSize: Int64): TBytes;
begin
  Result := nextpas.core.http.client.HttpReadResponseBodyBytesDecoded(AResp, AMaxSize);
end;

function HttpReadResponseBodyStringDecoded(const AResp: IHttpResponse; const AMaxSize: Int64): string;
begin
  Result := nextpas.core.http.client.HttpReadResponseBodyStringDecoded(AResp, AMaxSize);
end;

function HttpEnsureSuccess(const AResp: IHttpResponse): IHttpResponse;
begin
  Result := nextpas.core.http.client.HttpEnsureSuccess(AResp);
end;

function HttpEnsureSuccess(const AResp: IHttpResponse; const AMethod, AUrl: string): IHttpResponse;
begin
  Result := nextpas.core.http.client.HttpEnsureSuccess(AResp, AMethod, AUrl);
end;

function HttpGetString(const AClient: IHttpClient; const AUrl: string): string;
begin
  Result := nextpas.core.http.client.HttpGetString(AClient, AUrl);
end;

function HttpGetBytes(const AClient: IHttpClient; const AUrl: string): TBytes;
begin
  Result := nextpas.core.http.client.HttpGetBytes(AClient, AUrl);
end;

function HttpReadResponseJson(const AResp: IHttpResponse): IJsonDocument;
begin
  Result := nextpas.core.http.client.HttpReadResponseJson(AResp);
end;

function HttpReadResponseJson(const AResp: IHttpResponse; const AMethod, AUrl: string): IJsonDocument;
begin
  Result := nextpas.core.http.client.HttpReadResponseJson(AResp, AMethod, AUrl);
end;

function HttpGetJson(const AClient: IHttpClient; const AUrl: string): IJsonDocument;
begin
  Result := nextpas.core.http.client.HttpGetJson(AClient, AUrl);
end;

function HttpPostString(const AClient: IHttpClient; const AUrl, AContentType, ABody: string): string;
begin
  Result := nextpas.core.http.client.HttpPostString(AClient, AUrl, AContentType, ABody);
end;

function HttpPutString(const AClient: IHttpClient; const AUrl, AContentType, ABody: string): string;
begin
  Result := nextpas.core.http.client.HttpPutString(AClient, AUrl, AContentType, ABody);
end;

function HttpPatchString(const AClient: IHttpClient; const AUrl, AContentType, ABody: string): string;
begin
  Result := nextpas.core.http.client.HttpPatchString(AClient, AUrl, AContentType, ABody);
end;

function HttpDeleteString(const AClient: IHttpClient; const AUrl: string): string;
begin
  Result := nextpas.core.http.client.HttpDeleteString(AClient, AUrl);
end;

function HttpHead(const AClient: IHttpClient; const AUrl: string): IHttpResponse;
begin
  Result := nextpas.core.http.client.HttpHead(AClient, AUrl);
end;

function HttpOptions(const AClient: IHttpClient; const AUrl: string): IHttpResponse;
begin
  Result := nextpas.core.http.client.HttpOptions(AClient, AUrl);
end;

function HttpPostJson(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): string;
begin
  Result := nextpas.core.http.client.HttpPostJson(AClient, AUrl, ABody);
end;

function HttpPutJson(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): string;
begin
  Result := nextpas.core.http.client.HttpPutJson(AClient, AUrl, ABody);
end;

function HttpPatchJson(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): string;
begin
  Result := nextpas.core.http.client.HttpPatchJson(AClient, AUrl, ABody);
end;

function HttpDeleteJson(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): string;
begin
  Result := nextpas.core.http.client.HttpDeleteJson(AClient, AUrl, ABody);
end;

function HttpPostJsonDocument(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): IJsonDocument;
begin
  Result := nextpas.core.http.client.HttpPostJsonDocument(AClient, AUrl, ABody);
end;

function HttpPutJsonDocument(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): IJsonDocument;
begin
  Result := nextpas.core.http.client.HttpPutJsonDocument(AClient, AUrl, ABody);
end;

function HttpPatchJsonDocument(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): IJsonDocument;
begin
  Result := nextpas.core.http.client.HttpPatchJsonDocument(AClient, AUrl, ABody);
end;

function HttpGetToWriter(const AClient: IHttpClient; const AUrl: string; const ADest: IWriter): Int64;
begin
  Result := nextpas.core.http.client.HttpGetToWriter(AClient, AUrl, ADest);
end;

function HttpGetToFile(const AClient: IHttpClient; const AUrl, ADestPath: string): Int64;
begin
  Result := nextpas.core.http.client.HttpGetToFile(AClient, AUrl, ADestPath);
end;

function ExtractCharsetFromContentType(const AContentType: string): string;
begin
  Result := nextpas.core.http.client.ExtractCharsetFromContentType(AContentType);
end;

end.
