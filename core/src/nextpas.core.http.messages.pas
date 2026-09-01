unit nextpas.core.http.messages;
{**
 * @desc HTTP messages facade. Pure re-export of request/response builders,
 *       response writers, redirects, error helpers and body readers.
 *       Owner modules retain logic (`nextpas.core.http.message`, `nextpas.core.http.headers`,
 *       `nextpas.core.json`, `nextpas.core.bytes.ops` single source). Facade only
 *       aggregates via inline thin forwarding. Thin consumers preferring smaller
 *       surface should `uses nextpas.core.http.messages` or `nextpas.core.http.minimal`;
 *       full surface remains `uses nextpas.core.http` stable umbrella.
 *
 *       Performance: inline thin forwarding (const string/TBytes), real loops/SIMD
 *       stay out-of-line per `design-conventions.md:163` (bytes.ops single source
 *       in owners, see `nextpas.core.bytes.ops:25/89`); zero-copy views where possible
 *       (TByteSpan views, SortAsciiNormalization inline scan). No ownership added;
 *       resource release via owner (`try/finally`/`Close`/`HttpReleaseResponseBody`).
 *       CONTRACT is truth, missing capability → back-feed owner.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.json,
  nextpas.core.http.url,
  nextpas.core.http.form;

type
  THttpRequestBuilder = nextpas.core.http.message.THttpRequestBuilder;
  TFormField = nextpas.core.http.form.TFormField;
  TFormFieldArray = nextpas.core.http.form.TFormFieldArray;
  THttpFile = nextpas.core.http.form.THttpFile;
  THttpFileArray = nextpas.core.http.form.THttpFileArray;
  TMultipartFormData = nextpas.core.http.form.TMultipartFormData;
  TMultipartParseOptions = nextpas.core.http.form.TMultipartParseOptions;
  IJsonDocument = nextpas.core.json.IJsonDocument;

{ Request factories (builder recommended; these are the whitelisted primitives) }
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl): IHttpRequest; overload; inline;
function NewRequest(const AMethod: THttpMethod; const AUrl: string): IHttpRequest; overload; inline;
function NewGetRequest(const APath: string): IHttpRequest; inline;

{ Response factories }
function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ABody: IReader): IHttpResponse; overload; inline;
function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ANilBody: Pointer): IHttpResponse; overload; inline;
function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ABodyText: string): IHttpResponse; overload; inline;
function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ABodyBytes: TBytes): IHttpResponse; overload; inline;

{ Response writers }
function HttpWriteResponseString(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const AContentType, ABody: string): SizeUInt; inline;
function HttpWriteResponseJson(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const AValue: TJsonValue): SizeUInt; inline;
function HttpWriteResponseBytes(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const AContentType: string;
  const ABody: TBytes): SizeUInt; inline;
function HttpWriteResponseHtml(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const ABody: string): SizeUInt; inline;
procedure HttpWriteResponseNoContent(const AW: IHttpResponseWriter); inline;
procedure HttpWriteResponseOk(const AW: IHttpResponseWriter); inline;
procedure HttpWriteResponseCreated(const AW: IHttpResponseWriter); inline;
procedure HttpWriteResponseAccepted(const AW: IHttpResponseWriter); inline;
procedure HttpWriteResponseNotModified(const AW: IHttpResponseWriter); inline;
procedure HttpWriteResponseResetContent(const AW: IHttpResponseWriter); inline;
procedure HttpWriteResponseGone(const AW: IHttpResponseWriter); inline;

{ Request body readers (default bounded) }
function HttpReadRequestBodyBytes(const AReq: IHttpRequest): TBytes; inline;
function HttpReadRequestBodyBytesMax(const AReq: IHttpRequest;
  const AMaxBytes: Int64): TBytes; inline;
function HttpReadRequestBodyBytesUnlimited(const AReq: IHttpRequest): TBytes; inline;
function HttpReadRequestBodyString(const AReq: IHttpRequest): string; inline;
function HttpReadRequestBodyJson(const AReq: IHttpRequest): IJsonDocument; inline;

{ Redirects }
procedure HttpRedirect(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const ALocation: string); inline;
procedure HttpRedirectMovedPermanently(const AW: IHttpResponseWriter;
  const ALocation: string); inline;
procedure HttpRedirectFound(const AW: IHttpResponseWriter;
  const ALocation: string); inline;
procedure HttpRedirectSeeOther(const AW: IHttpResponseWriter;
  const ALocation: string); inline;
procedure HttpRedirectTemporaryRedirect(const AW: IHttpResponseWriter;
  const ALocation: string); inline;
procedure HttpRedirectPermanentRedirect(const AW: IHttpResponseWriter;
  const ALocation: string); inline;

{ RFC7807 error responses }
function HttpWriteErrorResponse(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const ACode, AMessage: string;
  const AInstance: string = ''): SizeUInt; inline;
function HttpWriteErrorBadRequest(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
function HttpWriteErrorUnauthorized(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
function HttpWriteErrorForbidden(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
function HttpWriteErrorNotFound(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
function HttpWriteErrorInternal(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
function HttpWriteErrorTooManyRequests(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
function HttpWriteErrorConflict(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
function HttpWriteErrorUnprocessableEntity(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
function HttpWriteErrorPayloadTooLarge(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
function HttpWriteErrorUnsupportedMediaType(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
function HttpWriteErrorGatewayTimeout(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;

{ Retry / method helpers (single source in message, bytes.ops for header compare) }
function HttpIsRetryableMethod(const AMethod: THttpMethod): Boolean; inline;
function HttpHasRetryIdempotencyKey(const AReq: IHttpRequest): Boolean; inline;
function HttpIsRetrySafeRequest(const AReq: IHttpRequest): Boolean; inline;

implementation

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewRequest(AMethod, AUrl);
end;

function NewGetRequest(const APath: string): IHttpRequest;
begin
  Result := nextpas.core.http.message.NewGetRequest(APath);
end;

function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders; const ABody: IReader): IHttpResponse;
begin
  Result := nextpas.core.http.message.NewResponse(AStatus, AHeaders, ABody);
end;

function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders; const ANilBody: Pointer): IHttpResponse;
begin
  Result := nextpas.core.http.message.NewResponse(AStatus, AHeaders, ANilBody);
end;

function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders; const ABodyText: string): IHttpResponse;
begin
  Result := nextpas.core.http.message.NewResponse(AStatus, AHeaders, ABodyText);
end;

function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders; const ABodyBytes: TBytes): IHttpResponse;
begin
  Result := nextpas.core.http.message.NewResponse(AStatus, AHeaders, ABodyBytes);
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

function HttpWriteErrorUnsupportedMediaType(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.message.HttpWriteErrorUnsupportedMediaType(AW, AMessage);
end;

function HttpWriteErrorGatewayTimeout(const AW: IHttpResponseWriter; const AMessage: string): SizeUInt;
begin
  Result := nextpas.core.http.message.HttpWriteErrorGatewayTimeout(AW, AMessage);
end;

function HttpIsRetryableMethod(const AMethod: THttpMethod): Boolean;
begin
  Result := nextpas.core.http.message.HttpIsRetryableMethod(AMethod);
end;

function HttpHasRetryIdempotencyKey(const AReq: IHttpRequest): Boolean;
begin
  Result := nextpas.core.http.message.HttpHasRetryIdempotencyKey(AReq);
end;

function HttpIsRetrySafeRequest(const AReq: IHttpRequest): Boolean;
begin
  Result := nextpas.core.http.message.HttpIsRetrySafeRequest(AReq);
end;

end.
