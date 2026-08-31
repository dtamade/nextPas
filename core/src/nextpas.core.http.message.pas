unit nextpas.core.http.message;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.net.base,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.url,
  nextpas.core.json,
  nextpas.core.mem.arena.intf;

type
  { Builder body discriminant: distinguishes "no body" from empty string/bytes. }
  THttpBuilderBodyKind = (
    bbkNone,
    bbkString,
    bbkBytes,
    bbkReader
  );

  THttpRequest = class(TInterfacedObject, IHttpRequest, IHttpRequestWithOptions,
    IHttpRequestWithContext, IHttpRequestWithArena, IHttpRequestWithEarlyData)
  private
    type
      TPathParam = record
        Name: string;
        Value: string;
      end;
    var
      FMethod: THttpMethod;
      FUrl: TUrl;
      FRawRequestTarget: string;
      FUrlParsed: Boolean;
      FRequestTargetPartsParsed: Boolean;
      FVersion: THttpVersion;
      FHeaders: IHttpHeaders;
      FTrailers: IHttpHeaders;
      FBody: IReader;
      FContentLength: Int64;
      FPathParams: array of TPathParam;
      FRemoteAddr: string;
      FRemoteNetAddr: TNetAddress;
      FRemoteAddrFromNet: Boolean;
      FQueryParsed: Boolean;
      FQueryParams: TQueryParams;
      FRequestOptions: THttpRequestOptions;
      FContext: IHttpContext;
      FArena: IArena;
      FEarlyData: Boolean;
    procedure EnsureUrlParsed;
    procedure EnsureRequestTargetParts;
  public
    constructor Create(const AMethod: THttpMethod; const AUrl: TUrl;
      const AVersion: THttpVersion; const AHeaders: IHttpHeaders;
      const ABody: IReader; const AContentLength: Int64);
    constructor CreateFromRequestTarget(const AMethod: THttpMethod;
      const ARequestTarget: string; const AVersion: THttpVersion;
      const AHeaders: IHttpHeaders; const ABody: IReader;
      const AContentLength: Int64);
    procedure SetPathParam(const AName, AValue: string);
    procedure SetRemoteAddr(const AAddr: string);
    procedure SetRemoteNetAddr(const AAddr: TNetAddress);
    procedure SetTrailers(const ATrailers: IHttpHeaders);
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
    procedure SetRequestOptions(const AOptions: THttpRequestOptions);
    function GetRequestOptions: THttpRequestOptions;
    function GetContext: IHttpContext;
    procedure SetContext(const ACtx: IHttpContext);
    function GetArena: IArena;
    procedure SetArena(const AArena: IArena);
    function GetWasEarlyData: Boolean;
    procedure SetWasEarlyData(const AValue: Boolean);
  end;

  THttpResponse = class(TInterfacedObject, IHttpResponse)
  private
    FStatusCode: THttpStatus;
    FHeaders: IHttpHeaders;
    FBody: IReader;
    FBodyClosed: Boolean;
    FFinalUrl: string;
    FVersion: THttpVersion;
  public
    constructor Create(const AStatusCode: THttpStatus;
      const AHeaders: IHttpHeaders; const ABody: IReader;
      const AVersion: THttpVersion = hvHttp11);
    destructor Destroy; override;
    function GetStatusCode: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function GetBody: IReader;
    function GetFinalUrl: string;
    function GetVersion: THttpVersion;
    { Client stamps the request URL that produced this response. }
    procedure SetFinalUrl(const AUrl: string);
    procedure Close;
  end;

{ Factory helpers — whitelist only. Headers/body/auth → THttpRequestBuilder. }
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string): IHttpRequest; overload;
function NewGetRequest(const APath: string): IHttpRequest;
function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ABody: IReader): IHttpResponse; overload;
function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ANilBody: Pointer): IHttpResponse; overload;
function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ABodyText: string): IHttpResponse; overload;
function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ABodyBytes: TBytes): IHttpResponse; overload;
function HttpWriteResponseString(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const AContentType, ABody: string): SizeUInt;
{** @desc Write JSON response: sets application/json content-type, serializes value, writes body. }
function HttpWriteResponseJson(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const AValue: TJsonValue): SizeUInt;
{** @desc Write binary response: sets content-type and content-length, writes TBytes body. }
function HttpWriteResponseBytes(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const AContentType: string;
  const ABody: TBytes): SizeUInt;
{** @desc Write HTML response: sets text/html content-type, writes string body. }
function HttpWriteResponseHtml(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const ABody: string): SizeUInt;
{** @desc Read request body as TBytes up to HTTP_DEFAULT_BODY_READ_MAX.
   Returns nil if body is nil. Raises on nil request.
   Exceeds max → EHttpError(hekBody, Op=body). }
function HttpReadRequestBodyBytes(const AReq: IHttpRequest): TBytes;
{** @desc Read request body as TBytes with explicit max.
   AMaxBytes <= 0 means unlimited (tests/tools only).
   Exceeds max → EHttpError(hekBody, Op=body). }
function HttpReadRequestBodyBytesMax(const AReq: IHttpRequest;
  const AMaxBytes: Int64): TBytes;
{** @desc Read request body with no size bound (tests/tools only).
   Prefer HttpReadRequestBodyBytes / HttpReadRequestBodyBytesMax(positive). }
function HttpReadRequestBodyBytesUnlimited(const AReq: IHttpRequest): TBytes;
{** @desc Read request body as string. Returns '' if body is nil. Raises on nil request.
   Uses HTTP_DEFAULT_BODY_READ_MAX (see HttpReadRequestBodyBytes). }
function HttpReadRequestBodyString(const AReq: IHttpRequest): string;
{** @desc Read request body and parse as JSON document. Raises on nil request or invalid JSON.
   Uses HTTP_DEFAULT_BODY_READ_MAX (see HttpReadRequestBodyBytes). }
function HttpReadRequestBodyJson(const AReq: IHttpRequest): IJsonDocument;
{** @desc Write a redirect response with Location header and optional HTML body.
   AStatus should be a 3xx code (301/302/303/307/308). }
procedure HttpRedirect(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const ALocation: string);
{** @desc 301 Moved Permanently redirect. }
procedure HttpRedirectMovedPermanently(const AW: IHttpResponseWriter;
  const ALocation: string); inline;
{** @desc 302 Found redirect (temporary, method may change to GET). }
procedure HttpRedirectFound(const AW: IHttpResponseWriter;
  const ALocation: string); inline;
{** @desc 303 See Other redirect (always changes method to GET). }
procedure HttpRedirectSeeOther(const AW: IHttpResponseWriter;
  const ALocation: string); inline;
{** @desc 307 Temporary Redirect (preserves method and body). }
procedure HttpRedirectTemporaryRedirect(const AW: IHttpResponseWriter;
  const ALocation: string); inline;
{** @desc 308 Permanent Redirect (preserves method and body). }
procedure HttpRedirectPermanentRedirect(const AW: IHttpResponseWriter;
  const ALocation: string); inline;

{** Retry-safety policy shared by WithRetry and H1/H2 pool reconnect.
   Safe methods: GET / HEAD / OPTIONS / TRACE. }
function HttpIsRetryableMethod(const AMethod: THttpMethod): Boolean; inline;
{** True if request carries Idempotency-Key or X-Idempotency-Key. }
function HttpHasRetryIdempotencyKey(const AReq: IHttpRequest): Boolean; inline;
{** True when method is retryable or an explicit idempotency key is present. }
function HttpIsRetrySafeRequest(const AReq: IHttpRequest): Boolean; inline;
{** @desc Write an RFC 7807 Problem Details error response.
   Sets content-type application/problem+json. }
function HttpWriteErrorResponse(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const ACode, AMessage: string;
  const AInstance: string = ''): SizeUInt;
{** @desc Write 400 Bad Request JSON error response. }
function HttpWriteErrorBadRequest(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
{** @desc Write 401 Unauthorized JSON error response. }
function HttpWriteErrorUnauthorized(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
{** @desc Write 403 Forbidden JSON error response. }
function HttpWriteErrorForbidden(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
{** @desc Write 404 Not Found JSON error response. }
function HttpWriteErrorNotFound(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
{** @desc Write 204 No Content response. Raises if body is non-empty. }
procedure HttpWriteResponseNoContent(const AW: IHttpResponseWriter);
{** @desc Write 200 OK response with no body. Sets status to 200 and writes empty body. }
procedure HttpWriteResponseOk(const AW: IHttpResponseWriter);
{** @desc Write 201 Created response with no body. Sets status to 201 and writes empty body.
   Use for POST requests that successfully create a resource. }
procedure HttpWriteResponseCreated(const AW: IHttpResponseWriter);
{** @desc Write 202 Accepted response with no body. Sets status to 202 and writes empty body.
   Use for async operations that have been accepted for processing. }
procedure HttpWriteResponseAccepted(const AW: IHttpResponseWriter);
{** @desc Write 304 Not Modified response with no body.
   Use for conditional requests where the resource hasn't changed. }
procedure HttpWriteResponseNotModified(const AW: IHttpResponseWriter);
{** @desc Write 205 Reset Content response with no body.
   Instructs client to reset the document view (e.g., clear a form). }
procedure HttpWriteResponseResetContent(const AW: IHttpResponseWriter);
{** @desc Write 410 Gone response with no body.
   Indicates the resource has been permanently removed. }
procedure HttpWriteResponseGone(const AW: IHttpResponseWriter);
{** @desc Write 500 Internal Server Error JSON error response. }
function HttpWriteErrorInternal(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
{** @desc Write 429 Too Many Requests JSON error response. }
function HttpWriteErrorTooManyRequests(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
{** @desc Write 409 Conflict JSON error response. }
function HttpWriteErrorConflict(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
{** @desc Write 422 Unprocessable Entity JSON error response. }
function HttpWriteErrorUnprocessableEntity(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
{** @desc Write 413 Payload Too Large JSON error response. }
function HttpWriteErrorPayloadTooLarge(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
{** @desc Write 415 Unsupported Media Type JSON error response. }
function HttpWriteErrorUnsupportedMediaType(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
{** @desc Write 504 Gateway Timeout JSON error response. }
function HttpWriteErrorGatewayTimeout(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;

type
  { Fluent builder for HTTP requests.
    Usage: THttpRequestBuilder.Create(hmGet, 'http://example.com')
             .Header('Accept', 'application/json')
             .BearerAuth('token')
             .QueryParam('page', '1')
             .Build }
  THttpRequestBuilder = record
  private
    FMethod: THttpMethod;
    FUrl: string;
    FHeaders: IHttpHeaders;
    FBodyReader: IReader;
    FBodyString: string;
    FBodyBytes: TBytes;
    FBodyKind: THttpBuilderBodyKind;
    FContentLength: Int64;
    FHasContentLength: Boolean;
    FContentType: string;
    FQueryParams: TQueryParams;
    FQueryCount: Int32;
    FRequestOptions: THttpRequestOptions;
  public
    constructor Create(const AMethod: THttpMethod; const AUrl: string);
    function Header(const AName, AValue: string): THttpRequestBuilder;
    { Merge/replace with a full header bag (clone of AHeaders when FHeaders empty). }
    function Headers(const AHeaders: IHttpHeaders): THttpRequestBuilder;
    function BasicAuth(const AUsername, APassword: string): THttpRequestBuilder;
    function BearerAuth(const AToken: string): THttpRequestBuilder;
    function ContentType(const AContentType: string): THttpRequestBuilder;
    { Known-length for Body(IReader). Optional: omit for H1 chunked (CL = -1). }
    function ContentLength(const ALen: Int64): THttpRequestBuilder;
    function Body(const ABody: string): THttpRequestBuilder; overload;
    function Body(const ABody: TBytes): THttpRequestBuilder; overload;
    function Body(const ABody: IReader): THttpRequestBuilder; overload;
    function QueryParam(const AName, AValue: string): THttpRequestBuilder;
    function Timeout(const ATimeoutMs: Int64): THttpRequestBuilder;
    function MaxRedirects(const AMaxRedirects: Int32): THttpRequestBuilder;
    function FollowRedirects(const AFollow: Boolean): THttpRequestBuilder;
    function CancelToken(const AToken: IHttpCancelToken): THttpRequestBuilder;
    { Streaming response-body sink (SSE / long-poll): live dispatch per parsed
       body chunk on the transport IO thread. See THttpResponseBodyChunkProc. }
    function ResponseBodyChunk(
      const AChunkProc: THttpResponseBodyChunkProc): THttpRequestBuilder;
    { Response-headers-ready callback: fires once after response headers are
       parsed (status visible), before body chunks. See THttpResponseStatusProc. }
    function ResponseStatus(
      const AProc: THttpResponseStatusProc): THttpRequestBuilder;
    { Skip response-body buffering (SSE / long-poll sinks): parsed body bytes go
       only to ResponseBodyChunk; NewBodyReader returns nil and the parser's
       32MB body cap no longer applies. }
    function SkipBodyBuffer: THttpRequestBuilder;
    function Build: IHttpRequest;
  end;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.io.memory,
  nextpas.core.text.conv,
  nextpas.core.encoding,
  nextpas.core.http.headers;

function BytesBodyReader(const ABodyBytes: TBytes): IReader;
var
  LStream: IStream;
begin
  LStream := CreateBytesStreamFrom(ABodyBytes);
  Result := LStream as IReader;
end;

function StringBodyReader(const ABodyText: string): IReader;
var
  LData: TBytes;
begin
  SetLength(LData, Length(ABodyText));
  if Length(ABodyText) > 0 then
    Move(ABodyText[1], LData[0], Length(ABodyText));
  Result := BytesBodyReader(LData);
end;

{ Escape a string for safe embedding in JSON. Handles ", \, and control chars. }
function JsonEscapeStr(const AStr: string): string;
var
  LI, LJ, LLen, LOutLen: SizeInt;
  LCh: Char;
begin
  LLen := Length(AStr);
  if LLen = 0 then
    Exit('');
  { Pre-scan to calculate exact output length }
  LOutLen := LLen;
  for LI := 1 to LLen do
  begin
    LCh := AStr[LI];
    case LCh of
      '"', '\', #8, #9, #10, #12, #13:
        Inc(LOutLen); { 2 bytes output instead of 1 }
    else
      if Ord(LCh) < 32 then
        Inc(LOutLen, 5); { \u00XX = 6 bytes instead of 1 }
    end;
  end;
  SetLength(Result, LOutLen);
  LJ := 1;
  for LI := 1 to LLen do
  begin
    LCh := AStr[LI];
    case LCh of
      '"': begin Result[LJ] := '\'; Result[LJ+1] := '"'; Inc(LJ, 2); end;
      '\': begin Result[LJ] := '\'; Result[LJ+1] := '\'; Inc(LJ, 2); end;
      #8:  begin Result[LJ] := '\'; Result[LJ+1] := 'b'; Inc(LJ, 2); end;
      #9:  begin Result[LJ] := '\'; Result[LJ+1] := 't'; Inc(LJ, 2); end;
      #10: begin Result[LJ] := '\'; Result[LJ+1] := 'n'; Inc(LJ, 2); end;
      #12: begin Result[LJ] := '\'; Result[LJ+1] := 'f'; Inc(LJ, 2); end;
      #13: begin Result[LJ] := '\'; Result[LJ+1] := 'r'; Inc(LJ, 2); end;
    else
      if Ord(LCh) < 32 then
      begin
        Result[LJ] := '\';
        Result[LJ+1] := 'u';
        Result[LJ+2] := '0';
        Result[LJ+3] := '0';
        Result[LJ+4] := Char(Ord('0') + (Ord(LCh) shr 4));
        Result[LJ+5] := Char(Ord('0') + (Ord(LCh) and $0F));
        Inc(LJ, 6);
      end
      else
      begin
        Result[LJ] := LCh;
        Inc(LJ);
      end;
    end;
  end;
  SetLength(Result, LJ - 1);
end;

function HeadersOrNew(const AHeaders: IHttpHeaders): IHttpHeaders;
begin
  if AHeaders <> nil then
    Result := AHeaders
  else
    Result := NewHttpHeaders;
end;

function NewRequestContentTypeHeaders(const AContentType: string): IHttpHeaders;
begin
  if AContentType = '' then
    Exit(nil);
  Result := NewHttpHeaders;
  Result.SetHeader('content-type', AContentType);
end;

function ParseDeclaredContentLength(const AValue: string): Int64;
var
  LI: SizeInt;
  LDigit: Int64;
begin
  if AValue = '' then
    raise EHttpError.Create(hekArgument, 'HTTP request content-length is invalid');
  Result := 0;
  for LI := 1 to Length(AValue) do
  begin
    if (AValue[LI] < '0') or (AValue[LI] > '9') then
      raise EHttpError.Create(hekArgument, 'HTTP request content-length is invalid');
    LDigit := Ord(AValue[LI]) - Ord('0');
    if Result > ((High(Int64) - LDigit) div 10) then
      raise EHttpError.Create(hekArgument, 'HTTP request content-length is too large');
    Result := (Result * 10) + LDigit;
  end;
end;

function TransferEncodingIsChunkedOnly(const AValue: string): Boolean;
var
  LCompact: string;
  LI: SizeInt;
begin
  { Accept only "chunked" (case-insensitive, optional surrounding spaces).
     Multi-coding TE (e.g. gzip, chunked) is not supported for request bodies. }
  LCompact := '';
  for LI := 1 to Length(AValue) do
    if AValue[LI] <> ' ' then
      LCompact := LCompact + LowerCase(AValue[LI]);
  Result := LCompact = 'chunked';
end;

procedure ValidateRequestBodyHeaders(const AHeaders: IHttpHeaders;
  const ADeclaredContentLength: Int64);
var
  LValues: TStringArray;
  LTeValues: TStringArray;
  LHeaderLength: Int64;
  LI: SizeInt;
begin
  if AHeaders = nil then
    Exit;

  LValues := AHeaders.GetAll('content-length');
  LTeValues := AHeaders.GetAll('transfer-encoding');

  if ADeclaredContentLength < 0 then
  begin
    { Chunked / unknown-length request body. }
    if Length(LValues) > 0 then
      raise EHttpError.Create(hekArgument,
        'HTTP request content-length conflicts with chunked body');
    if Length(LTeValues) = 0 then
      Exit;
    for LI := Low(LTeValues) to High(LTeValues) do
      if not TransferEncodingIsChunkedOnly(LTeValues[LI]) then
        raise EHttpError.Create(hekArgument,
          'HTTP request transfer-encoding must be chunked for unknown-length body');
    Exit;
  end;

  if Length(LTeValues) > 0 then
    raise EHttpError.Create(hekArgument,
      'HTTP request transfer-encoding is unsupported');

  if Length(LValues) = 0 then
    Exit;
  if Length(LValues) <> 1 then
    raise EHttpError.Create(hekArgument,
      'HTTP request content-length is duplicated');
  LHeaderLength := ParseDeclaredContentLength(LValues[0]);
  if LHeaderLength <> ADeclaredContentLength then
    raise EHttpError.Create(hekArgument,
      'HTTP request content-length conflicts with body length');
end;

procedure ValidateFixedBodyResponseHeaders(const AHeaders: IHttpHeaders;
  const ABodyLength: Int64);
var
  LValues: TStringArray;
  LHeaderLength: Int64;
begin
  if AHeaders = nil then
    Exit;

  if AHeaders.Has('transfer-encoding') then
    raise EHttpError.Create(hekArgument,
      'HTTP response transfer-encoding is unsupported');

  LValues := AHeaders.GetAll('content-length');
  if Length(LValues) = 0 then
    Exit;
  if Length(LValues) <> 1 then
    raise EHttpError.Create(hekArgument,
      'HTTP response content-length is duplicated');
  LHeaderLength := ParseDeclaredContentLength(LValues[0]);
  if LHeaderLength <> ABodyLength then
    raise EHttpError.Create(hekArgument,
      'HTTP response content-length conflicts with body length');
end;

function ResponseStatusMustNotHaveBody(const AStatus: THttpStatus): Boolean;
begin
  Result := HttpStatusIsInformational(AStatus) or
    (AStatus = HTTP_STATUS_NO_CONTENT) or
    (AStatus = HTTP_STATUS_NOT_MODIFIED);
end;

procedure ValidateFixedBodyResponseStatus(const AStatus: THttpStatus;
  const ABodyLength: Int64);
begin
  if (ABodyLength > 0) and ResponseStatusMustNotHaveBody(AStatus) then
    raise EHttpError.Create(hekArgument, 'HTTP response status must not include a body');
end;

procedure RequireResponseWriter(const AW: IHttpResponseWriter);
begin
  if AW = nil then
    raise EHttpError.Create(hekArgument, 'HTTP response writer is nil');
end;

function WriteAllResponseBodyString(const AW: IHttpResponseWriter;
  const ABody: string): SizeUInt;
var
  LTotal: SizeUInt;
  LWritten: SizeUInt;
  LLen: SizeUInt;
begin
  LLen := SizeUInt(Length(ABody));
  LTotal := 0;
  while LTotal < LLen do
  begin
    LWritten := AW.Write(ABody[LTotal + 1], LLen - LTotal);
    if LWritten = 0 then
      raise EIOError.Create('HTTP response writer made zero progress');
    if LWritten > LLen - LTotal then
      raise EIOError.Create('HTTP response writer over-reported progress');
    Inc(LTotal, LWritten);
  end;
  Result := LTotal;
end;

{ THttpRequest }

constructor THttpRequest.Create(const AMethod: THttpMethod; const AUrl: TUrl;
  const AVersion: THttpVersion; const AHeaders: IHttpHeaders;
  const ABody: IReader; const AContentLength: Int64);
begin
  inherited Create;
  FMethod := AMethod;
  FUrl := AUrl;
  FRawRequestTarget := '';
  FUrlParsed := True;
  FRequestTargetPartsParsed := True;
  FVersion := AVersion;
  FHeaders := HeadersOrNew(AHeaders);
  FTrailers := nil;
  FBody := ABody;
  FContentLength := AContentLength;
end;

constructor THttpRequest.CreateFromRequestTarget(const AMethod: THttpMethod;
  const ARequestTarget: string; const AVersion: THttpVersion;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64);
begin
  inherited Create;
  FMethod := AMethod;
  FUrl := Default(TUrl);
  FRawRequestTarget := ARequestTarget;
  FUrlParsed := False;
  FRequestTargetPartsParsed := False;
  FVersion := AVersion;
  FHeaders := HeadersOrNew(AHeaders);
  FTrailers := nil;
  FBody := ABody;
  FContentLength := AContentLength;
end;

procedure THttpRequest.EnsureUrlParsed;
begin
  if FUrlParsed then
    Exit;
  FUrl := TUrl.ParseRequestTarget(FRawRequestTarget);
  FUrlParsed := True;
  FRequestTargetPartsParsed := True;
end;

procedure THttpRequest.EnsureRequestTargetParts;
var
  LRest: string;
  LPos: SizeInt;
begin
  if FRequestTargetPartsParsed then
    Exit;
  if FUrlParsed then
  begin
    FRequestTargetPartsParsed := True;
    Exit;
  end;

  if FRawRequestTarget = '' then
    raise EHttpError.Create(hekParse, 'Cannot parse empty request-target');

  if (FRawRequestTarget[1] <> '/') and (FRawRequestTarget[1] <> '*') and
    (Pos('://', FRawRequestTarget) > 0) then
  begin
    EnsureUrlParsed;
    Exit;
  end;

  LRest := FRawRequestTarget;

  LPos := Pos('#', LRest);
  if LPos > 0 then
  begin
    FUrl.Fragment := Copy(LRest, LPos + 1, Length(LRest) - LPos);
    LRest := Copy(LRest, 1, LPos - 1);
  end;

  LPos := Pos('?', LRest);
  if LPos > 0 then
  begin
    FUrl.RawQuery := Copy(LRest, LPos + 1, Length(LRest) - LPos);
    LRest := Copy(LRest, 1, LPos - 1);
  end;

  FUrl.Path := LRest;
  FRequestTargetPartsParsed := True;
end;

procedure THttpRequest.SetPathParam(const AName, AValue: string);
var
  LLen: Int32;
begin
  LLen := Length(FPathParams);
  SetLength(FPathParams, LLen + 1);
  FPathParams[LLen].Name := AName;
  FPathParams[LLen].Value := AValue;
end;

procedure THttpRequest.SetTrailers(const ATrailers: IHttpHeaders);
begin
  FTrailers := ATrailers;
end;

function THttpRequest.GetMethod: THttpMethod;
begin
  Result := FMethod;
end;

function THttpRequest.GetUrl: TUrl;
begin
  EnsureUrlParsed;
  Result := FUrl;
end;

function THttpRequest.GetPath: string;
begin
  EnsureRequestTargetParts;
  Result := FUrl.Path;
end;

function THttpRequest.GetRawQuery: string;
begin
  EnsureRequestTargetParts;
  Result := FUrl.RawQuery;
end;

function THttpRequest.GetVersion: THttpVersion;
begin
  Result := FVersion;
end;

function THttpRequest.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function THttpRequest.GetTrailers: IHttpHeaders;
begin
  Result := FTrailers;
end;

function THttpRequest.GetBody: IReader;
begin
  Result := FBody;
end;

function THttpRequest.GetContentLength: Int64;
begin
  Result := FContentLength;
end;

function THttpRequest.PathParam(const AName: string): string;
var
  LI: Int32;
begin
  for LI := 0 to High(FPathParams) do
    if FPathParams[LI].Name = AName then
      Exit(FPathParams[LI].Value);
  Result := '';
end;

function THttpRequest.GetRemoteAddr: string;
begin
  if FRemoteAddrFromNet and (FRemoteAddr = '') then
    FRemoteAddr := FRemoteNetAddr.ToString;
  Result := FRemoteAddr;
end;

{ Peer IP without the port. From the socket we have the structured
  TNetAddress (IP field is already bracket-free); for a caller-provided
  RemoteAddr string we strip the port the way the family does (token888
  ExtractClientIp): bracketed '[ipv6]:port' keeps the bracket content,
  'ip:port' keeps everything before the last ':'. }
function THttpRequest.GetRemoteIp: string;
var
  LLast, I: SizeInt;
begin
  if FRemoteAddrFromNet then
    Exit(FRemoteNetAddr.IP);
  Result := FRemoteAddr;
  if Result = '' then
    Exit;
  if Result[1] = '[' then
  begin
    I := Pos(']', Result);
    if I > 2 then
      Result := Copy(Result, 2, I - 2);
    Exit;
  end;
  LLast := 0;
  for I := 1 to Length(Result) do
    if Result[I] = ':' then
      LLast := I;
  if LLast > 1 then
    Result := Copy(Result, 1, LLast - 1);
end;

procedure THttpRequest.SetRemoteAddr(const AAddr: string);
begin
  FRemoteAddr := AAddr;
  FRemoteAddrFromNet := False;
end;

procedure THttpRequest.SetRemoteNetAddr(const AAddr: TNetAddress);
begin
  FRemoteNetAddr := AAddr;
  FRemoteAddr := '';
  FRemoteAddrFromNet := True;
end;

function THttpRequest.QueryParam(const AName: string): string;
begin
  if not FQueryParsed then
  begin
    EnsureRequestTargetParts;
    FQueryParams := ParseQueryString(FUrl.RawQuery);
    FQueryParsed := True;
  end;
  Result := QueryParamValue(FQueryParams, AName);
end;

procedure THttpRequest.SetRequestOptions(const AOptions: THttpRequestOptions);
begin
  FRequestOptions := AOptions;
end;

function THttpRequest.GetRequestOptions: THttpRequestOptions;
begin
  Result := FRequestOptions;
end;

function THttpRequest.GetContext: IHttpContext;
begin
  Result := FContext;
end;

procedure THttpRequest.SetContext(const ACtx: IHttpContext);
begin
  FContext := ACtx;
end;

function THttpRequest.GetArena: IArena;
begin
  Result := FArena;
end;

procedure THttpRequest.SetArena(const AArena: IArena);
begin
  FArena := AArena;
end;

function THttpRequest.GetWasEarlyData: Boolean;
begin
  Result := FEarlyData;
end;

procedure THttpRequest.SetWasEarlyData(const AValue: Boolean);
begin
  FEarlyData := AValue;
end;

{ THttpResponse }

constructor THttpResponse.Create(const AStatusCode: THttpStatus;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AVersion: THttpVersion);
begin
  inherited Create;
  FStatusCode := AStatusCode;
  FHeaders := HeadersOrNew(AHeaders);
  FBody := ABody;
  FBodyClosed := False;
  FFinalUrl := '';
  FVersion := AVersion;
end;

destructor THttpResponse.Destroy;
begin
  try
    Close;
  except
    { Destructor must not raise. }
  end;
  inherited;
end;

function THttpResponse.GetStatusCode: THttpStatus;
begin
  Result := FStatusCode;
end;

function THttpResponse.GetHeaders: IHttpHeaders;
begin
  Result := FHeaders;
end;

function THttpResponse.GetBody: IReader;
begin
  Result := FBody;
end;

function THttpResponse.GetFinalUrl: string;
begin
  Result := FFinalUrl;
end;

function THttpResponse.GetVersion: THttpVersion;
begin
  Result := FVersion;
end;

procedure THttpResponse.SetFinalUrl(const AUrl: string);
begin
  FFinalUrl := AUrl;
end;

procedure THttpResponse.Close;
var
  LBody: IReader;
  LReadCloser: IReadCloser;
  LCloser: ICloser;
  LStream: IStream;
  LBuf: array[0..4095] of Byte;
begin
  if FBodyClosed then
    Exit;
  FBodyClosed := True;
  LBody := FBody;
  if LBody = nil then
    Exit;

  if Supports(LBody, IReadCloser, LReadCloser) then
  begin
    LReadCloser.Close;
    Exit;
  end;
  if Supports(LBody, ICloser, LCloser) then
  begin
    LCloser.Close;
    Exit;
  end;
  if Supports(LBody, IStream, LStream) then
  begin
    LStream.Close;
    Exit;
  end;

  while LBody.Read(LBuf[0], SizeUInt(Length(LBuf))) > 0 do
    ;
end;

{ Factory helpers }

function MakeHttpRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest;
var
  LHeaders: IHttpHeaders;
begin
  if AContentLength < -1 then
    raise EHttpError.Create(hekArgument, 'HTTP request content-length is invalid');
  if (ABody = nil) and (AContentLength > 0) then
    raise EHttpError.Create(hekArgument,
      'HTTP request body is nil but content-length is positive');
  if (ABody = nil) and (AContentLength < 0) then
    raise EHttpError.Create(hekArgument,
      'HTTP request body is nil but chunked framing was requested');

  LHeaders := AHeaders;
  if LHeaders = nil then
    LHeaders := NewHttpHeaders;
  ValidateRequestBodyHeaders(LHeaders, AContentLength);
  if AContentLength < 0 then
  begin
    { Unknown-length body → H1 Transfer-Encoding: chunked. }
    if not LHeaders.Has('transfer-encoding') then
      LHeaders.SetHeader('transfer-encoding', 'chunked');
  end
  else if AContentLength > 0 then
    LHeaders.SetHeader('content-length', IntToStr(AContentLength))
  else if ABody <> nil then
    LHeaders.SetHeader('content-length', '0');
  Result := THttpRequest.Create(AMethod, AUrl, hvHttp11, LHeaders, ABody,
    AContentLength);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl): IHttpRequest;
begin
  Result := THttpRequest.Create(AMethod, AUrl, hvHttp11, NewHttpHeaders, nil, 0);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl));
end;

function NewGetRequest(const APath: string): IHttpRequest;
var
  LUrl: TUrl;
begin
  LUrl := Default(TUrl);
  LUrl.Path := APath;
  Result := THttpRequest.Create(hmGet, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
end;

function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ABody: IReader): IHttpResponse;
begin
  Result := THttpResponse.Create(AStatus, AHeaders, ABody);
end;

function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ANilBody: Pointer): IHttpResponse;
begin
  if ANilBody <> nil then
    raise EHttpError.Create(hekArgument,
      'HTTP nil-body response compatibility overload only accepts nil');
  Result := THttpResponse.Create(AStatus, AHeaders, nil);
end;

function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ABodyText: string): IHttpResponse;
var
  LHeaders: IHttpHeaders;
begin
  LHeaders := HeadersOrNew(AHeaders);
  ValidateFixedBodyResponseStatus(AStatus, Int64(Length(ABodyText)));
  ValidateFixedBodyResponseHeaders(LHeaders, Int64(Length(ABodyText)));
  LHeaders.SetHeader('content-length', IntToStr(Int64(Length(ABodyText))));
  Result := THttpResponse.Create(AStatus, LHeaders, StringBodyReader(ABodyText));
end;

function NewResponse(const AStatus: THttpStatus; const AHeaders: IHttpHeaders;
  const ABodyBytes: TBytes): IHttpResponse;
var
  LHeaders: IHttpHeaders;
begin
  LHeaders := HeadersOrNew(AHeaders);
  ValidateFixedBodyResponseStatus(AStatus, Int64(Length(ABodyBytes)));
  ValidateFixedBodyResponseHeaders(LHeaders, Int64(Length(ABodyBytes)));
  LHeaders.SetHeader('content-length', IntToStr(Int64(Length(ABodyBytes))));
  Result := THttpResponse.Create(AStatus, LHeaders, BytesBodyReader(ABodyBytes));
end;

function HttpWriteResponseString(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const AContentType, ABody: string): SizeUInt;
begin
  RequireResponseWriter(AW);
  if HttpStatusIsInformational(AStatus) then
    raise EHttpError.Create(hekArgument,
      'HTTP response string helper requires a final response status');
  if ResponseStatusMustNotHaveBody(AStatus) then
  begin
    if ABody <> '' then
      raise EHttpError.Create(hekArgument, 'HTTP response status must not include a body');
    AW.WriteHeader(AStatus);
    Exit(0);
  end;

  if AContentType <> '' then
    AW.GetHeaders.SetHeader('content-type', AContentType);
  AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(Length(ABody))));
  AW.WriteHeader(AStatus);
  Result := WriteAllResponseBodyString(AW, ABody);
end;

function HttpWriteResponseJson(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const AValue: TJsonValue): SizeUInt;
begin
  Result := HttpWriteResponseString(AW, AStatus, 'application/json',
    JsonStringify(AValue));
end;

function HttpWriteResponseBytes(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const AContentType: string;
  const ABody: TBytes): SizeUInt;
var
  LLen: SizeUInt;
  LTotal: SizeUInt;
  LWritten: SizeUInt;
begin
  RequireResponseWriter(AW);
  if HttpStatusIsInformational(AStatus) then
    raise EHttpError.Create(hekArgument,
      'HTTP response bytes helper requires a final response status');
  if ResponseStatusMustNotHaveBody(AStatus) then
  begin
    if (ABody <> nil) and (Length(ABody) > 0) then
      raise EHttpError.Create(hekArgument, 'HTTP response status must not include a body');
    AW.WriteHeader(AStatus);
    Exit(0);
  end;

  LLen := SizeUInt(Length(ABody));
  if AContentType <> '' then
    AW.GetHeaders.SetHeader('content-type', AContentType);
  AW.GetHeaders.SetHeader('content-length', IntToStr(Int64(LLen)));
  AW.WriteHeader(AStatus);
  LTotal := 0;
  while LTotal < LLen do
  begin
    LWritten := AW.Write(ABody[LTotal], LLen - LTotal);
    if LWritten = 0 then
      raise EIOError.Create('HTTP response writer made zero progress');
    if LWritten > LLen - LTotal then
      raise EIOError.Create('HTTP response writer over-reported progress');
    Inc(LTotal, LWritten);
  end;
  Result := LTotal;
end;

function HttpWriteResponseHtml(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const ABody: string): SizeUInt;
begin
  Result := HttpWriteResponseString(AW, AStatus, 'text/html; charset=utf-8', ABody);
end;

function HttpReadRequestBodyBytesMax(const AReq: IHttpRequest;
  const AMaxBytes: Int64): TBytes;
var
  LBody: IReader;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LTotal: Int64;
  LBounded: Boolean;
begin
  if AReq = nil then
    raise EHttpError.CreateOp(hekArgument, 'body', 'HTTP request is nil');
  LBody := AReq.Body;
  if LBody = nil then
    Exit(nil);
  LBounded := AMaxBytes > 0;
  Result := nil;
  LTotal := 0;
  repeat
    LN := LBody.Read(LBuf[0], SizeUInt(Length(LBuf)));
    if LN > 0 then
    begin
      if Int64(LN) > High(Int64) - LTotal then
        raise EHttpError.CreateOp(hekBody, 'body',
          'HTTP request body byte count overflow');
      Inc(LTotal, Int64(LN));
      if LBounded and (LTotal > AMaxBytes) then
        raise EHttpError.CreateOp(hekBody, 'body',
          'Request body exceeds maximum allowed size (' +
          IntToStr(AMaxBytes) + ' bytes)');
      SetLength(Result, LTotal);
      Move(LBuf[0], Result[LTotal - Int64(LN)], LN);
    end;
  until LN = 0;
end;

function HttpReadRequestBodyBytes(const AReq: IHttpRequest): TBytes;
begin
  Result := HttpReadRequestBodyBytesMax(AReq, HTTP_DEFAULT_BODY_READ_MAX);
end;

function HttpReadRequestBodyBytesUnlimited(const AReq: IHttpRequest): TBytes;
begin
  Result := HttpReadRequestBodyBytesMax(AReq, 0);
end;

function HttpReadRequestBodyString(const AReq: IHttpRequest): string;
var
  LBody: TBytes;
begin
  LBody := HttpReadRequestBodyBytes(AReq);
  Result := '';
  SetLength(Result, Length(LBody));
  if Length(LBody) > 0 then
    Move(LBody[0], Result[1], Length(LBody));
end;

function HttpReadRequestBodyJson(const AReq: IHttpRequest): IJsonDocument;
var
  LBody: string;
begin
  LBody := HttpReadRequestBodyString(AReq);
  Result := JsonParse(LBody);
  if (Result <> nil) and Result.HasError then
    raise EHttpError.Create(hekParse, 'HTTP request body contains invalid JSON');
end;

{ Escape a string for safe inclusion in an HTML attribute context.
  Prevents XSS by encoding characters that could break out of attributes. }
function HtmlEscapeAttr(const S: string): string;
var
  I, LLen, LOut: SizeInt;
  LBuf: string;
begin
  LLen := Length(S);
  LOut := 0;
  SetLength(LBuf, LLen * 6); { worst case: every char → '&xxxxx;' }
  for I := 1 to LLen do
  begin
    case S[I] of
      '&': begin System.Move('&amp;', LBuf[LOut + 1], 5); Inc(LOut, 5); end;
      '"': begin System.Move('&quot;', LBuf[LOut + 1], 6); Inc(LOut, 6); end;
      '<': begin System.Move('&lt;', LBuf[LOut + 1], 4); Inc(LOut, 4); end;
      '>': begin System.Move('&gt;', LBuf[LOut + 1], 4); Inc(LOut, 4); end;
      '''': begin System.Move('&#39;', LBuf[LOut + 1], 5); Inc(LOut, 5); end;
    else
      begin LBuf[LOut + 1] := S[I]; Inc(LOut); end;
    end;
  end;
  SetLength(LBuf, LOut);
  Result := LBuf;
end;

procedure HttpRedirect(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const ALocation: string);
var
  LBody, LEscaped: string;
begin
  RequireResponseWriter(AW);
  if not HttpStatusIsRedirect(AStatus) then
    raise EHttpError.Create(hekArgument, 'HttpRedirect requires a 3xx redirect status');
  if ALocation = '' then
    raise EHttpError.Create(hekArgument, 'HttpRedirect location must not be empty');
  { Reject protocol-relative URLs to prevent open redirect }
  if (Length(ALocation) >= 2) and (ALocation[1] = '/') and (ALocation[2] = '/') then
    raise EHttpError.Create(hekArgument,
      'HttpRedirect: protocol-relative URL not allowed');
  AW.GetHeaders.SetHeader('location', ALocation);
  LEscaped := HtmlEscapeAttr(ALocation);
  LBody := '<html><body>Redirecting to <a href="' + LEscaped + '">' +
    LEscaped + '</a></body></html>';
  HttpWriteResponseString(AW, AStatus, 'text/html', LBody);
end;

procedure HttpRedirectMovedPermanently(const AW: IHttpResponseWriter;
  const ALocation: string);
begin
  HttpRedirect(AW, HTTP_STATUS_MOVED_PERMANENTLY, ALocation);
end;

procedure HttpRedirectFound(const AW: IHttpResponseWriter;
  const ALocation: string);
begin
  HttpRedirect(AW, HTTP_STATUS_FOUND, ALocation);
end;

procedure HttpRedirectSeeOther(const AW: IHttpResponseWriter;
  const ALocation: string);
begin
  HttpRedirect(AW, HTTP_STATUS_SEE_OTHER, ALocation);
end;

procedure HttpRedirectTemporaryRedirect(const AW: IHttpResponseWriter;
  const ALocation: string);
begin
  HttpRedirect(AW, HTTP_STATUS_TEMPORARY_REDIRECT, ALocation);
end;

procedure HttpRedirectPermanentRedirect(const AW: IHttpResponseWriter;
  const ALocation: string);
begin
  HttpRedirect(AW, HTTP_STATUS_PERMANENT_REDIRECT, ALocation);
end;

function HttpIsRetryableMethod(const AMethod: THttpMethod): Boolean;
begin
  Result := AMethod in [hmGet, hmHead, hmOptions, hmTrace];
end;

function HttpHasRetryIdempotencyKey(const AReq: IHttpRequest): Boolean;
begin
  Result := (AReq <> nil) and (AReq.Headers <> nil) and
    (AReq.Headers.Has('idempotency-key') or
     AReq.Headers.Has('x-idempotency-key'));
end;

function HttpIsRetrySafeRequest(const AReq: IHttpRequest): Boolean;
begin
  if AReq = nil then
    Exit(False);
  Result := HttpIsRetryableMethod(AReq.Method) or
    HttpHasRetryIdempotencyKey(AReq);
end;

function HttpWriteErrorResponse(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const ACode, AMessage: string;
  const AInstance: string = ''): SizeUInt;
var
  LJson: string;
begin
  LJson := '{"type":"about:blank","title":"' + JsonEscapeStr(ACode) +
    '","detail":"' + JsonEscapeStr(AMessage) +
    '","status":' + IntToStr(AStatus);
  if AInstance <> '' then
    LJson := LJson + ',"instance":"' + JsonEscapeStr(AInstance) + '"';
  LJson := LJson + '}';
  Result := HttpWriteResponseString(AW, AStatus, 'application/problem+json', LJson);
end;

function HttpWriteErrorBadRequest(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt;
begin
  Result := HttpWriteErrorResponse(AW, HTTP_STATUS_BAD_REQUEST, 'bad_request', AMessage);
end;

function HttpWriteErrorUnauthorized(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt;
begin
  Result := HttpWriteErrorResponse(AW, HTTP_STATUS_UNAUTHORIZED, 'unauthorized', AMessage);
end;

function HttpWriteErrorForbidden(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt;
begin
  Result := HttpWriteErrorResponse(AW, HTTP_STATUS_FORBIDDEN, 'forbidden', AMessage);
end;

function HttpWriteErrorNotFound(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt;
begin
  Result := HttpWriteErrorResponse(AW, HTTP_STATUS_NOT_FOUND, 'not_found', AMessage);
end;

function HttpWriteErrorInternal(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt;
begin
  Result := HttpWriteErrorResponse(AW, HTTP_STATUS_INTERNAL_SERVER_ERROR, 'internal_error', AMessage);
end;

function HttpWriteErrorTooManyRequests(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt;
begin
  Result := HttpWriteErrorResponse(AW, HTTP_STATUS_TOO_MANY_REQUESTS, 'too_many_requests', AMessage);
end;

function HttpWriteErrorConflict(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt;
begin
  Result := HttpWriteErrorResponse(AW, HTTP_STATUS_CONFLICT, 'conflict', AMessage);
end;

function HttpWriteErrorUnprocessableEntity(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt;
begin
  Result := HttpWriteErrorResponse(AW, HTTP_STATUS_UNPROCESSABLE_ENTITY, 'unprocessable_entity', AMessage);
end;

{** @desc Write 413 Payload Too Large JSON error response. }
function HttpWriteErrorPayloadTooLarge(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt;
begin
  Result := HttpWriteErrorResponse(AW, HTTP_STATUS_PAYLOAD_TOO_LARGE, 'payload_too_large', AMessage);
end;

function HttpWriteErrorUnsupportedMediaType(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt;
begin
  Result := HttpWriteErrorResponse(AW, HTTP_STATUS_UNSUPPORTED_MEDIA_TYPE, 'unsupported_media_type', AMessage);
end;

function HttpWriteErrorGatewayTimeout(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt;
begin
  Result := HttpWriteErrorResponse(AW, HTTP_STATUS_GATEWAY_TIMEOUT, 'gateway_timeout', AMessage);
end;

procedure HttpWriteResponseNoContent(const AW: IHttpResponseWriter);
begin
  RequireResponseWriter(AW);
  AW.WriteHeader(HTTP_STATUS_NO_CONTENT);
end;

procedure HttpWriteResponseOk(const AW: IHttpResponseWriter);
begin
  RequireResponseWriter(AW);
  AW.WriteHeader(HTTP_STATUS_OK);
end;

procedure HttpWriteResponseCreated(const AW: IHttpResponseWriter);
begin
  RequireResponseWriter(AW);
  AW.WriteHeader(HTTP_STATUS_CREATED);
end;

procedure HttpWriteResponseAccepted(const AW: IHttpResponseWriter);
begin
  RequireResponseWriter(AW);
  AW.WriteHeader(HTTP_STATUS_ACCEPTED);
end;

procedure HttpWriteResponseNotModified(const AW: IHttpResponseWriter);
begin
  RequireResponseWriter(AW);
  AW.WriteHeader(HTTP_STATUS_NOT_MODIFIED);
end;

procedure HttpWriteResponseResetContent(const AW: IHttpResponseWriter);
begin
  RequireResponseWriter(AW);
  AW.WriteHeader(HTTP_STATUS_RESET_CONTENT);
end;

procedure HttpWriteResponseGone(const AW: IHttpResponseWriter);
begin
  RequireResponseWriter(AW);
  AW.WriteHeader(HTTP_STATUS_GONE);
end;

{ THttpRequestBuilder }

constructor THttpRequestBuilder.Create(const AMethod: THttpMethod;
  const AUrl: string);
begin
  FMethod := AMethod;
  FUrl := AUrl;
  FHeaders := nil;
  FBodyReader := nil;
  FBodyString := '';
  FBodyBytes := nil;
  FBodyKind := bbkNone;
  FContentLength := 0;
  FHasContentLength := False;
  FContentType := '';
  FQueryCount := 0;
  FRequestOptions := Default(THttpRequestOptions);
end;

function THttpRequestBuilder.Header(const AName,
  AValue: string): THttpRequestBuilder;
begin
  Result := Self;
  if Result.FHeaders = nil then
    Result.FHeaders := NewHttpHeaders;
  Result.FHeaders.SetHeader(AName, AValue);
end;

function THttpRequestBuilder.Headers(
  const AHeaders: IHttpHeaders): THttpRequestBuilder;
var
  LTarget: IHttpHeaders;
begin
  Result := Self;
  if AHeaders = nil then
    Exit;
  if Result.FHeaders = nil then
    Result.FHeaders := AHeaders.Clone
  else
  begin
    LTarget := Result.FHeaders;
    AHeaders.ForEach(
      procedure(const AName, AValue: string)
      begin
        LTarget.Add(AName, AValue);
      end);
  end;
end;

function THttpRequestBuilder.BasicAuth(const AUsername,
  APassword: string): THttpRequestBuilder;
begin
  Result := Self;
  if Result.FHeaders = nil then
    Result.FHeaders := NewHttpHeaders;
  Result.FHeaders.SetHeader('authorization',
    'Basic ' + Base64Encode(StringToUTF8Bytes(AUsername + ':' + APassword)));
end;

function THttpRequestBuilder.BearerAuth(
  const AToken: string): THttpRequestBuilder;
begin
  Result := Self;
  if Result.FHeaders = nil then
    Result.FHeaders := NewHttpHeaders;
  Result.FHeaders.SetHeader('authorization', 'Bearer ' + AToken);
end;

function THttpRequestBuilder.ContentType(
  const AContentType: string): THttpRequestBuilder;
begin
  Result := Self;
  Result.FContentType := AContentType;
end;

function THttpRequestBuilder.ContentLength(
  const ALen: Int64): THttpRequestBuilder;
begin
  Result := Self;
  { -1 requests H1 chunked framing; other negatives are invalid. }
  if ALen < -1 then
    raise EHttpError.Create(hekArgument,
      'THttpRequestBuilder.ContentLength must be >= -1');
  Result.FContentLength := ALen;
  Result.FHasContentLength := True;
end;

function THttpRequestBuilder.Body(
  const ABody: string): THttpRequestBuilder;
begin
  Result := Self;
  Result.FBodyString := ABody;
  Result.FBodyReader := nil;
  Result.FBodyBytes := nil;
  Result.FBodyKind := bbkString;
end;

function THttpRequestBuilder.Body(
  const ABody: TBytes): THttpRequestBuilder;
begin
  Result := Self;
  Result.FBodyBytes := ABody;
  Result.FBodyString := '';
  Result.FBodyReader := nil;
  Result.FBodyKind := bbkBytes;
end;

function THttpRequestBuilder.Body(
  const ABody: IReader): THttpRequestBuilder;
begin
  Result := Self;
  Result.FBodyReader := ABody;
  Result.FBodyString := '';
  Result.FBodyBytes := nil;
  Result.FBodyKind := bbkReader;
end;

function THttpRequestBuilder.QueryParam(const AName,
  AValue: string): THttpRequestBuilder;
begin
  Result := Self;
  if Result.FQueryCount >= Length(Result.FQueryParams) then
    SetLength(Result.FQueryParams, Result.FQueryCount + 4);
  Result.FQueryParams[Result.FQueryCount].Name := AName;
  Result.FQueryParams[Result.FQueryCount].Value := AValue;
  Inc(Result.FQueryCount);
end;

function THttpRequestBuilder.Timeout(
  const ATimeoutMs: Int64): THttpRequestBuilder;
begin
  Result := Self;
  Result.FRequestOptions.TimeoutMs := ATimeoutMs;
  Result.FRequestOptions.HasTimeout := True;
end;

function THttpRequestBuilder.MaxRedirects(
  const AMaxRedirects: Int32): THttpRequestBuilder;
begin
  Result := Self;
  Result.FRequestOptions.MaxRedirects := AMaxRedirects;
  Result.FRequestOptions.HasMaxRedirects := True;
end;

function THttpRequestBuilder.FollowRedirects(
  const AFollow: Boolean): THttpRequestBuilder;
begin
  Result := Self;
  Result.FRequestOptions.FollowRedirects := AFollow;
  Result.FRequestOptions.HasFollowRedirects := True;
end;

function THttpRequestBuilder.CancelToken(
  const AToken: IHttpCancelToken): THttpRequestBuilder;
begin
  Result := Self;
  Result.FRequestOptions.CancelToken := AToken;
  Result.FRequestOptions.HasCancelToken := True;
end;

function THttpRequestBuilder.ResponseBodyChunk(
  const AChunkProc: THttpResponseBodyChunkProc): THttpRequestBuilder;
begin
  Result := Self;
  Result.FRequestOptions.ResponseBodyChunk := AChunkProc;
end;

function THttpRequestBuilder.ResponseStatus(
  const AProc: THttpResponseStatusProc): THttpRequestBuilder;
begin
  Result := Self;
  Result.FRequestOptions.ResponseStatus := AProc;
end;

function THttpRequestBuilder.SkipBodyBuffer: THttpRequestBuilder;
begin
  Result := Self;
  Result.FRequestOptions.SkipBodyBuffer := True;
end;

function THttpRequestBuilder.Build: IHttpRequest;
var
  LI: SizeInt;
  LUrl: string;
  LHeaders: IHttpHeaders;
  LQueryStr: string;
  LQuerySlice: TQueryParams;
  LBody: IReader;
  LBodyString: string;
  LBodyBytes: TBytes;
begin
  LUrl := FUrl;
  if FQueryCount > 0 then
  begin
    SetLength(LQuerySlice, FQueryCount);
    { Element-by-element copy to properly handle managed string fields }
    for LI := 0 to FQueryCount - 1 do
      LQuerySlice[LI] := FQueryParams[LI];
    LQueryStr := EncodeQueryString(LQuerySlice);
    if LQueryStr <> '' then
    begin
      if Pos('?', LUrl) > 0 then
        LUrl := LUrl + '&' + LQueryStr
      else
        LUrl := LUrl + '?' + LQueryStr;
    end;
  end;

  LHeaders := FHeaders;
  if LHeaders = nil then
    LHeaders := NewHttpHeaders;
  if FContentType <> '' then
    LHeaders.SetHeader('content-type', FContentType);

  case FBodyKind of
    bbkReader:
      begin
        if FHasContentLength then
          Result := MakeHttpRequest(FMethod, TUrl.Parse(LUrl), LHeaders,
            FBodyReader, FContentLength)
        else
          { Unknown length → H1 chunked request body (ContentLength = -1). }
          Result := MakeHttpRequest(FMethod, TUrl.Parse(LUrl), LHeaders,
            FBodyReader, -1);
      end;
    bbkString:
      begin
        LBodyString := FBodyString;
        LBody := StringBodyReader(LBodyString);
        Result := MakeHttpRequest(FMethod, TUrl.Parse(LUrl), LHeaders, LBody,
          Int64(Length(LBodyString)));
      end;
    bbkBytes:
      begin
        LBodyBytes := FBodyBytes;
        LBody := BytesBodyReader(LBodyBytes);
        Result := MakeHttpRequest(FMethod, TUrl.Parse(LUrl), LHeaders, LBody,
          Int64(Length(LBodyBytes)));
      end;
  else
    Result := MakeHttpRequest(FMethod, TUrl.Parse(LUrl), LHeaders, nil, 0);
  end;

  if FRequestOptions.HasTimeout or FRequestOptions.HasMaxRedirects or
    FRequestOptions.HasFollowRedirects or FRequestOptions.HasCancelToken or
    Assigned(FRequestOptions.ResponseBodyChunk) or
    Assigned(FRequestOptions.ResponseStatus) or
    FRequestOptions.SkipBodyBuffer then
    (Result as IHttpRequestWithOptions).SetRequestOptions(FRequestOptions);
end;

end.
