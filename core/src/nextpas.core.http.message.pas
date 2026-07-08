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
  nextpas.core.json;

type
  THttpRequest = class(TInterfacedObject, IHttpRequest, IHttpRequestWithOptions)
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
    function PathParam(const AName: string): string;
    function QueryParam(const AName: string): string;
    procedure SetRequestOptions(const AOptions: THttpRequestOptions);
    function GetRequestOptions: THttpRequestOptions;
  end;

  THttpResponse = class(TInterfacedObject, IHttpResponse)
  private
    FStatusCode: THttpStatus;
    FHeaders: IHttpHeaders;
    FBody: IReader;
  public
    constructor Create(const AStatusCode: THttpStatus;
      const AHeaders: IHttpHeaders; const ABody: IReader);
    function GetStatusCode: THttpStatus;
    function GetHeaders: IHttpHeaders;
    function GetBody: IReader;
  end;

{ Factory helpers }
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ANilBody: Pointer): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ANilBody: Pointer): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ABody: IReader; const AContentLength: Int64): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ABody: IReader; const AContentLength: Int64): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ABodyText: string): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ABodyText: string): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AContentType, ABodyText: string): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType, ABodyText: string): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders; const ABodyText: string): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABodyText: string): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ABodyBytes: TBytes): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ABodyBytes: TBytes): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AContentType: string; const ABodyBytes: TBytes): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType: string; const ABodyBytes: TBytes): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders; const ABodyBytes: TBytes): IHttpRequest; overload;
function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABodyBytes: TBytes): IHttpRequest; overload;
function NewGetRequest(const APath: string): IHttpRequest;
{** Create a request with a streaming body that is NOT buffered into memory.
   The body reader is passed directly to the transport. The caller must ensure
   the body remains valid until Send closes it. Content-Length must be known
   and declared by the caller. If the body supports IStream seeking, redirect
   retries will rewind automatically; otherwise redirects that change the body
   (301/302/303) will close the stream and drop the body. }
function NewStreamingRequest(const AMethod: THttpMethod; const AUrl: string;
  const ABody: IReader; const AContentLength: Int64): IHttpRequest; overload;
function NewStreamingRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest; overload;
function NewStreamingRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest; overload;
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
{** @desc Read request body as TBytes. Returns nil if body is nil. Raises on nil request. }
function HttpReadRequestBodyBytes(const AReq: IHttpRequest): TBytes;
{** @desc Read request body as string. Returns '' if body is nil. Raises on nil request. }
function HttpReadRequestBodyString(const AReq: IHttpRequest): string;
{** @desc Read request body and parse as JSON document. Raises on nil request or invalid JSON. }
function HttpReadRequestBodyJson(const AReq: IHttpRequest): IJsonDocument;
{** @desc Write a redirect response with Location header and optional HTML body.
   AStatus should be a 3xx code (301/302/303/307/308). }
procedure HttpRedirect(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const ALocation: string);
{** @desc Write a JSON error response: {"error":{"code":"<code>","message":"<msg>"}}.
   Sets content-type application/json. }
function HttpWriteErrorResponse(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const ACode, AMessage: string): SizeUInt;
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
{** @desc Write 500 Internal Server Error JSON error response. }
function HttpWriteErrorInternal(const AW: IHttpResponseWriter;
  const AMessage: string): SizeUInt; inline;
{** @desc Write 429 Too Many Requests JSON error response. }
function HttpWriteErrorTooManyRequests(const AW: IHttpResponseWriter;
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
    FHasBody: Boolean;
    FContentType: string;
    FQueryParams: TQueryParams;
    FQueryCount: Int32;
    FRequestOptions: THttpRequestOptions;
  public
    constructor Create(const AMethod: THttpMethod; const AUrl: string);
    function Header(const AName, AValue: string): THttpRequestBuilder;
    function BasicAuth(const AUsername, APassword: string): THttpRequestBuilder;
    function BearerAuth(const AToken: string): THttpRequestBuilder;
    function ContentType(const AContentType: string): THttpRequestBuilder;
    function Body(const ABody: string): THttpRequestBuilder; overload;
    function Body(const ABody: TBytes): THttpRequestBuilder; overload;
    function Body(const ABody: IReader): THttpRequestBuilder; overload;
    function QueryParam(const AName, AValue: string): THttpRequestBuilder;
    function Timeout(const ATimeoutMs: Int64): THttpRequestBuilder;
    function MaxRedirects(const AMaxRedirects: Int32): THttpRequestBuilder;
    function FollowRedirects(const AFollow: Boolean): THttpRequestBuilder;
    function Build: IHttpRequest;
  end;

implementation

uses
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
    raise EArgumentError.Create('HTTP request content-length is invalid');
  Result := 0;
  for LI := 1 to Length(AValue) do
  begin
    if (AValue[LI] < '0') or (AValue[LI] > '9') then
      raise EArgumentError.Create('HTTP request content-length is invalid');
    LDigit := Ord(AValue[LI]) - Ord('0');
    if Result > ((High(Int64) - LDigit) div 10) then
      raise EArgumentError.Create('HTTP request content-length is too large');
    Result := (Result * 10) + LDigit;
  end;
end;

procedure ValidateRequestBodyHeaders(const AHeaders: IHttpHeaders;
  const ADeclaredContentLength: Int64);
var
  LValues: TStringArray;
  LHeaderLength: Int64;
begin
  if AHeaders = nil then
    Exit;

  LValues := AHeaders.GetAll('content-length');
  if AHeaders.Has('transfer-encoding') then
    raise EArgumentError.Create('HTTP request transfer-encoding is unsupported');

  if Length(LValues) = 0 then
    Exit;
  if Length(LValues) <> 1 then
    raise EArgumentError.Create('HTTP request content-length is duplicated');
  LHeaderLength := ParseDeclaredContentLength(LValues[0]);
  if LHeaderLength <> ADeclaredContentLength then
    raise EArgumentError.Create('HTTP request content-length conflicts with body length');
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
    raise EArgumentError.Create('HTTP response transfer-encoding is unsupported');

  LValues := AHeaders.GetAll('content-length');
  if Length(LValues) = 0 then
    Exit;
  if Length(LValues) <> 1 then
    raise EArgumentError.Create('HTTP response content-length is duplicated');
  LHeaderLength := ParseDeclaredContentLength(LValues[0]);
  if LHeaderLength <> ABodyLength then
    raise EArgumentError.Create(
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
    raise EHttpError.Create('HTTP response status must not include a body');
end;

procedure RequireResponseWriter(const AW: IHttpResponseWriter);
begin
  if AW = nil then
    raise EArgumentError.Create('HTTP response writer is nil');
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
    raise EHttpError.Create('Cannot parse empty request-target');

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

{ THttpResponse }

constructor THttpResponse.Create(const AStatusCode: THttpStatus;
  const AHeaders: IHttpHeaders; const ABody: IReader);
begin
  inherited Create;
  FStatusCode := AStatusCode;
  FHeaders := HeadersOrNew(AHeaders);
  FBody := ABody;
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

{ Factory helpers }

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl): IHttpRequest;
begin
  Result := THttpRequest.Create(AMethod, AUrl, hvHttp11, NewHttpHeaders, nil, 0);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl));
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders): IHttpRequest;
begin
  ValidateRequestBodyHeaders(AHeaders, 0);
  Result := THttpRequest.Create(AMethod, AUrl, hvHttp11, HeadersOrNew(AHeaders),
    nil, 0);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl), AHeaders, nil, 0);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ANilBody: Pointer): IHttpRequest;
begin
  if ANilBody <> nil then
    raise EArgumentError.Create(
      'HTTP nil-body compatibility overload only accepts nil');
  Result := NewRequest(AMethod, AUrl, TBytes(nil));
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ANilBody: Pointer): IHttpRequest;
begin
  if ANilBody <> nil then
    raise EArgumentError.Create(
      'HTTP nil-body compatibility overload only accepts nil');
  Result := NewRequest(AMethod, TUrl.Parse(AUrl), TBytes(nil));
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ABody: IReader; const AContentLength: Int64): IHttpRequest;
begin
  Result := NewRequest(AMethod, AUrl, nil, ABody, AContentLength);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ABody: IReader; const AContentLength: Int64): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl), nil, ABody, AContentLength);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest;
begin
  Result := NewRequest(AMethod, AUrl,
    NewRequestContentTypeHeaders(AContentType), ABody, AContentLength);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl), AContentType, ABody,
    AContentLength);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest;
var
  LHeaders: IHttpHeaders;
begin
  if AContentLength < 0 then
    raise EArgumentError.Create('HTTP request content-length is negative');
  if (ABody = nil) and (AContentLength > 0) then
    raise EArgumentError.Create(
      'HTTP request body is nil but content-length is positive');

  LHeaders := AHeaders;
  if LHeaders = nil then
    LHeaders := NewHttpHeaders;
  ValidateRequestBodyHeaders(LHeaders, AContentLength);
  if (ABody <> nil) or (AContentLength > 0) then
    LHeaders.SetHeader('content-length', IntToStr(AContentLength));
  Result := THttpRequest.Create(AMethod, AUrl, hvHttp11, LHeaders, ABody,
    AContentLength);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl), AHeaders, ABody,
    AContentLength);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ABodyText: string): IHttpRequest;
begin
  Result := NewRequest(AMethod, AUrl, nil, ABodyText);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ABodyText: string): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl), nil, ABodyText);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AContentType, ABodyText: string): IHttpRequest;
begin
  Result := NewRequest(AMethod, AUrl,
    NewRequestContentTypeHeaders(AContentType), ABodyText);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType, ABodyText: string): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl), AContentType, ABodyText);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders; const ABodyText: string): IHttpRequest;
begin
  Result := NewRequest(AMethod, AUrl, AHeaders, StringBodyReader(ABodyText),
    Int64(Length(ABodyText)));
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABodyText: string): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl), AHeaders, ABodyText);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const ABodyBytes: TBytes): IHttpRequest;
begin
  Result := NewRequest(AMethod, AUrl, nil, ABodyBytes);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const ABodyBytes: TBytes): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl), nil, ABodyBytes);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AContentType: string; const ABodyBytes: TBytes): IHttpRequest;
begin
  Result := NewRequest(AMethod, AUrl,
    NewRequestContentTypeHeaders(AContentType), ABodyBytes);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType: string; const ABodyBytes: TBytes): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl), AContentType, ABodyBytes);
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AHeaders: IHttpHeaders; const ABodyBytes: TBytes): IHttpRequest;
begin
  Result := NewRequest(AMethod, AUrl, AHeaders, BytesBodyReader(ABodyBytes),
    Int64(Length(ABodyBytes)));
end;

function NewRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABodyBytes: TBytes): IHttpRequest;
begin
  Result := NewRequest(AMethod, TUrl.Parse(AUrl), AHeaders, ABodyBytes);
end;

function NewGetRequest(const APath: string): IHttpRequest;
var
  LUrl: TUrl;
begin
  LUrl := Default(TUrl);
  LUrl.Path := APath;
  Result := THttpRequest.Create(hmGet, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
end;

function NewStreamingRequest(const AMethod: THttpMethod; const AUrl: string;
  const ABody: IReader; const AContentLength: Int64): IHttpRequest;
begin
  Result := NewRequest(AMethod, AUrl, nil, ABody, AContentLength);
end;

function NewStreamingRequest(const AMethod: THttpMethod; const AUrl: string;
  const AHeaders: IHttpHeaders; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest;
begin
  Result := NewRequest(AMethod, AUrl, AHeaders, ABody, AContentLength);
end;

function NewStreamingRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpRequest;
begin
  Result := NewRequest(AMethod, AUrl, AContentType, ABody, AContentLength);
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
    raise EArgumentError.Create(
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
    raise EHttpError.Create(
      'HTTP response string helper requires a final response status');
  if ResponseStatusMustNotHaveBody(AStatus) then
  begin
    if ABody <> '' then
      raise EHttpError.Create('HTTP response status must not include a body');
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
    raise EHttpError.Create(
      'HTTP response bytes helper requires a final response status');
  if ResponseStatusMustNotHaveBody(AStatus) then
  begin
    if (ABody <> nil) and (Length(ABody) > 0) then
      raise EHttpError.Create('HTTP response status must not include a body');
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

function HttpReadRequestBodyBytes(const AReq: IHttpRequest): TBytes;
var
  LBody: IReader;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LTotal: SizeUInt;
begin
  if AReq = nil then
    raise EArgumentError.Create('HTTP request is nil');
  LBody := AReq.Body;
  if LBody = nil then
    Exit(nil);
  Result := nil;
  LTotal := 0;
  repeat
    LN := LBody.Read(LBuf[0], SizeUInt(Length(LBuf)));
    if LN > 0 then
    begin
      SetLength(Result, LTotal + LN);
      Move(LBuf[0], Result[LTotal], LN);
      Inc(LTotal, LN);
    end;
  until LN = 0;
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
    raise EHttpError.Create('HTTP request body contains invalid JSON');
end;

procedure HttpRedirect(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const ALocation: string);
var
  LBody: string;
begin
  RequireResponseWriter(AW);
  if not HttpStatusIsRedirect(AStatus) then
    raise EHttpError.Create('HttpRedirect requires a 3xx redirect status');
  if ALocation = '' then
    raise EArgumentError.Create('HttpRedirect location must not be empty');
  AW.GetHeaders.SetHeader('location', ALocation);
  LBody := '<html><body>Redirecting to <a href="' + ALocation + '">' +
    ALocation + '</a></body></html>';
  HttpWriteResponseString(AW, AStatus, 'text/html', LBody);
end;

function HttpWriteErrorResponse(const AW: IHttpResponseWriter;
  const AStatus: THttpStatus; const ACode, AMessage: string): SizeUInt;
var
  LJson: string;
begin
  LJson := '{"error":{"code":"' + ACode + '","message":"' + AMessage + '"}}';
  Result := HttpWriteResponseString(AW, AStatus, 'application/json', LJson);
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

procedure HttpWriteResponseNoContent(const AW: IHttpResponseWriter);
begin
  RequireResponseWriter(AW);
  AW.WriteHeader(HTTP_STATUS_NO_CONTENT);
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
  FHasBody := False;
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

function THttpRequestBuilder.Body(
  const ABody: string): THttpRequestBuilder;
begin
  Result := Self;
  Result.FBodyString := ABody;
  Result.FBodyReader := nil;
  Result.FBodyBytes := nil;
  Result.FHasBody := True;
end;

function THttpRequestBuilder.Body(
  const ABody: TBytes): THttpRequestBuilder;
begin
  Result := Self;
  Result.FBodyBytes := ABody;
  Result.FBodyString := '';
  Result.FBodyReader := nil;
  Result.FHasBody := True;
end;

function THttpRequestBuilder.Body(
  const ABody: IReader): THttpRequestBuilder;
begin
  Result := Self;
  Result.FBodyReader := ABody;
  Result.FBodyString := '';
  Result.FBodyBytes := nil;
  Result.FHasBody := True;
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

function THttpRequestBuilder.Build: IHttpRequest;
var
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
    Move(FQueryParams[0], LQuerySlice[0], FQueryCount * SizeOf(TQueryParam));
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

  if FHasBody then
  begin
    if FBodyReader <> nil then
      Result := NewRequest(FMethod, LUrl, LHeaders, FBodyReader, 0)
    else if FBodyString <> '' then
    begin
      LBodyString := FBodyString;
      LBody := StringBodyReader(LBodyString);
      Result := NewRequest(FMethod, LUrl, LHeaders, LBody, Int64(Length(LBodyString)));
    end
    else if FBodyBytes <> nil then
    begin
      LBodyBytes := FBodyBytes;
      LBody := BytesBodyReader(LBodyBytes);
      Result := NewRequest(FMethod, LUrl, LHeaders, LBody, Int64(Length(LBodyBytes)));
    end
    else
      Result := NewRequest(FMethod, LUrl, LHeaders, nil, 0);
  end
  else
    Result := NewRequest(FMethod, LUrl, LHeaders, nil, 0);

  if FRequestOptions.HasTimeout or FRequestOptions.HasMaxRedirects or
    FRequestOptions.HasFollowRedirects then
    (Result as IHttpRequestWithOptions).SetRequestOptions(FRequestOptions);
end;

end.
