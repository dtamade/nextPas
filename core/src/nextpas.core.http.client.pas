unit nextpas.core.http.client;
{**
 * @desc HTTP/1.1 client with per-host connection pooling and keep-alive.
 *       Supports automatic redirect following.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.net.intf,
  nextpas.core.tls.base,
  nextpas.core.http.base,
  nextpas.core.http.form.base,
  nextpas.core.json.value,
  nextpas.core.json,
  nextpas.core.http.intf;

type
  THttpClientOptions = nextpas.core.http.base.THttpClientOptions;
  IHttpTransportIdleConnections = nextpas.core.http.intf.IHttpTransportIdleConnections;

  THttpClient = class(TInterfacedObject, IHttpClient)
  private
    FOptions: THttpClientOptions;
    FTransport: IHttpTransport;
    function DoRequest(const AReq: IHttpRequest; ARedirectsLeft: Int32;
      var ARequestBodyCloseAttempted: Boolean): IHttpResponse;
  public
    constructor Create(const AOptions: THttpClientOptions); overload;
    constructor Create(const ATransport: IHttpTransport;
      const AOptions: THttpClientOptions); overload;
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
  end;

function NewHttpClient: IHttpClient; overload;
function NewHttpClient(const AOptions: THttpClientOptions): IHttpClient; overload;
function NewHttpClient(const ATransport: IHttpTransport): IHttpClient; overload;
function NewHttpClient(const ATransport: IHttpTransport;
  const AOptions: THttpClientOptions): IHttpClient; overload;
function HttpGetToWriter(const AClient: IHttpClient; const AUrl: string;
  const ADest: IWriter): Int64;
function HttpGetToFile(const AClient: IHttpClient; const AUrl, ADestPath: string): Int64;
procedure HttpReleaseResponseBody(const AResp: IHttpResponse);
function HttpReadResponseBodyBytes(const AResp: IHttpResponse): TBytes;
function HttpReadResponseBodyString(const AResp: IHttpResponse): string;
function HttpReadResponseBodyStringAuto(const AResp: IHttpResponse): string;
{** @desc Decode ABody for a single Content-Encoding token.
   Empty/identity → pass-through. gzip/deflate → decompress via core.compress.
   Unsupported / multi-coding → hekProtocol Op=content_encoding.
   Corrupt payload → hekBody Op=content_encoding.
   AMaxSize > 0 caps decompressed size; AMaxSize < 0 → hekArgument. }
function HttpDecodeContentEncoding(const AEncoding: string;
  const ABody: TBytes; const AMaxSize: Int64 = 0): TBytes;
{** @desc Read wire body then decode via response Content-Encoding.
   Consumes/closes body like HttpReadResponseBodyBytes. Missing encoding → raw. }
function HttpReadResponseBodyBytesDecoded(const AResp: IHttpResponse;
  const AMaxSize: Int64 = 0): TBytes;
{** @desc HttpReadResponseBodyBytesDecoded as string (byte→char, same as raw string helper). }
function HttpReadResponseBodyStringDecoded(const AResp: IHttpResponse;
  const AMaxSize: Int64 = 0): string;
{** @desc Raise EHttpError if response status is not 2xx (200-299). Returns AResp for chaining. }
function HttpEnsureSuccess(const AResp: IHttpResponse): IHttpResponse; overload;
{** @desc Same as HttpEnsureSuccess, with method/URL prefix in error messages. }
function HttpEnsureSuccess(const AResp: IHttpResponse;
  const AMethod, AUrl: string): IHttpResponse; overload;
{** @desc GET url, ensure 2xx, return body as string. Raises on non-2xx. }
function HttpGetString(const AClient: IHttpClient; const AUrl: string): string;
{** @desc GET url, ensure 2xx, return body as TBytes. Raises on non-2xx. }
function HttpGetBytes(const AClient: IHttpClient; const AUrl: string): TBytes;
{** @desc Ensure 2xx and parse response body as JSON document.
   Invalid JSON raises EHttpError(hekProtocol, Op=json). }
function HttpReadResponseJson(const AResp: IHttpResponse): IJsonDocument; overload;
{** @desc Same as HttpReadResponseJson, with method/URL prefix in error messages. }
function HttpReadResponseJson(const AResp: IHttpResponse;
  const AMethod, AUrl: string): IJsonDocument; overload;
{** @desc GET url, ensure 2xx, parse body as JSON document. Raises on non-2xx or invalid JSON. }
function HttpGetJson(const AClient: IHttpClient; const AUrl: string): IJsonDocument;
{** @desc POST with body, ensure 2xx, return response body as string. Raises on non-2xx. }
function HttpPostString(const AClient: IHttpClient;
  const AUrl, AContentType, ABody: string): string;
{** @desc PUT with body, ensure 2xx, return response body as string. Raises on non-2xx. }
function HttpPutString(const AClient: IHttpClient;
  const AUrl, AContentType, ABody: string): string;
{** @desc PATCH with body, ensure 2xx, return response body as string. Raises on non-2xx. }
function HttpPatchString(const AClient: IHttpClient;
  const AUrl, AContentType, ABody: string): string;
{** @desc DELETE url, ensure 2xx, return response body as string. Raises on non-2xx. }
function HttpDeleteString(const AClient: IHttpClient;
  const AUrl: string): string;
{** @desc HEAD url, ensure 2xx, return response (headers only, no body). Raises on non-2xx.
   Useful for checking resource existence or reading Content-Length/ETag headers. }
function HttpHead(const AClient: IHttpClient; const AUrl: string): IHttpResponse;
{** @desc OPTIONS url, ensure 2xx, return response. Raises on non-2xx.
   Useful for CORS preflight or discovering allowed methods. }
function HttpOptions(const AClient: IHttpClient; const AUrl: string): IHttpResponse;
{** @desc POST JSON body, ensure 2xx, return response body as string. Raises on non-2xx. }
function HttpPostJson(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): string;
{** @desc PUT JSON body, ensure 2xx, return response body as string. Raises on non-2xx. }
function HttpPutJson(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): string;
{** @desc PATCH JSON body, ensure 2xx, return response body as string. Raises on non-2xx. }
function HttpPatchJson(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): string;
{** @desc DELETE with JSON body, ensure 2xx, return response body as string. Raises on non-2xx. }
function HttpDeleteJson(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): string;
{** @desc POST JSON body, ensure 2xx, parse response as JSON document.
   Invalid JSON raises EHttpError(hekProtocol, Op=json). }
function HttpPostJsonDocument(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): IJsonDocument;
{** @desc PUT JSON body, ensure 2xx, parse response as JSON document. }
function HttpPutJsonDocument(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): IJsonDocument;
{** @desc PATCH JSON body, ensure 2xx, parse response as JSON document. }
function HttpPatchJsonDocument(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): IJsonDocument;
function ExtractCharsetFromContentType(const AContentType: string): string;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.io,
  nextpas.core.io.memory,
  nextpas.core.text.conv,
  nextpas.core.encoding,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.form,
  nextpas.core.http.impl.registry,
  nextpas.core.http.client.redirect,
  nextpas.core.http.client.decorator,
  nextpas.core.http.client.helpers,
  nextpas.core.platform.thread,
  nextpas.core.time,
  nextpas.core.time.datetime,
  nextpas.core.time.offsetdatetime,
  nextpas.core.time.timezone;

procedure ValidateClientOptions(const AOptions: THttpClientOptions);
begin
  if AOptions.Timeout < 0 then
    raise EHttpError.Create(hekArgument, 'HTTP client timeout must not be negative');
  if AOptions.ConnectTimeout < 0 then
    raise EHttpError.Create(hekArgument,
      'HTTP client connect timeout must not be negative');
  if AOptions.MaxRedirects < 0 then
    raise EHttpError.Create(hekArgument, 'HTTP client max redirects must not be negative');
  if AOptions.IdleTTL < 0 then
    raise EHttpError.Create(hekArgument, 'HTTP client IdleTTL must not be negative');
end;

procedure CloseRequestBody(const ABody: IReader);
var
  LReadCloser: IReadCloser;
  LCloser: ICloser;
  LStream: IStream;
begin
  if ABody = nil then
    Exit;
  if Supports(ABody, IReadCloser, LReadCloser) then
  begin
    LReadCloser.Close;
    Exit;
  end;
  if Supports(ABody, ICloser, LCloser) then
  begin
    LCloser.Close;
    Exit;
  end;
  if Supports(ABody, IStream, LStream) then
    LStream.Close;
end;

procedure CloseRequestBodyIgnoringErrors(const ABody: IReader);
begin
  try
    CloseRequestBody(ABody);
  except
    on E: Exception do ;
  end;
end;

function BufferedBodyRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType, ABody: string): IHttpRequest; overload;
var
  LBuilder: THttpRequestBuilder;
begin
  LBuilder := THttpRequestBuilder.Create(AMethod, AUrl);
  if AContentType <> '' then
    LBuilder := LBuilder.ContentType(AContentType);
  Result := LBuilder.Body(ABody).Build;
end;

function BufferedBodyRequest(const AMethod: THttpMethod; const AUrl,
  AContentType: string; const ABody: TBytes): IHttpRequest; overload;
var
  LBuilder: THttpRequestBuilder;
begin
  LBuilder := THttpRequestBuilder.Create(AMethod, AUrl);
  if AContentType <> '' then
    LBuilder := LBuilder.ContentType(AContentType);
  Result := LBuilder.Body(ABody).Build;
end;



{ THttpClient }

constructor THttpClient.Create(const AOptions: THttpClientOptions);
begin
  Create(nil, AOptions);
end;

constructor THttpClient.Create(const ATransport: IHttpTransport;
  const AOptions: THttpClientOptions);
begin
  inherited Create;
  ValidateClientOptions(AOptions);
  FOptions := AOptions;
  if ATransport <> nil then
    FTransport := ATransport
  else
    FTransport := ResolveClientTransport(
      AOptions.EffectiveVersion(GetDefaultClientVersion), AOptions);
end;

function RequestCancelToken(const AReq: IHttpRequest): IHttpCancelToken;
var
  LReqOpts: IHttpRequestWithOptions;
begin
  Result := nil;
  if Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
    Result := LReqOpts.RequestOptions.EffectiveCancelToken;
end;

function THttpClient.DoRequest(const AReq: IHttpRequest; ARedirectsLeft: Int32;
  var ARequestBodyCloseAttempted: Boolean): IHttpResponse;
var
  LUrl: TUrl;
  LResp: IHttpResponse;
  LLocation: string;
  LLocations: TStringArray;
  LNewUrl: TUrl;
  LNewReq: IHttpRequest;
  LRespHeaders: IHttpHeaders;
  LNewHeaders: IHttpHeaders;
  LBodyStream: IStream;
  LBodyStartPosition: Int64;
  LReqOpts: IHttpRequestWithOptions;
  LNewReqOpts: IHttpRequestWithOptions;
  LFollowRedirects: Boolean;
begin
  LUrl := AReq.Url;
  HttpThrowIfCanceled(RequestCancelToken(AReq));
  CaptureRedirectBodyPosition(AReq, LBodyStream, LBodyStartPosition);
  LResp := FTransport.RoundTrip(AReq);
  if LResp = nil then
    raise EHttpError.CreateOp(hekConnect, 'round_trip',
      FormatHttpClientError(HttpMethodToStr(AReq.Method), LUrl,
        'HTTP transport returned no response'));

  // Determine redirect behavior: per-request override or client default
  LFollowRedirects := FOptions.FollowRedirects;
  if Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
    LFollowRedirects := LReqOpts.RequestOptions.EffectiveFollowRedirects(
      FOptions.FollowRedirects);

  // Handle redirects
  if LFollowRedirects and
     ((LResp.StatusCode = HTTP_STATUS_MOVED_PERMANENTLY) or
      (LResp.StatusCode = HTTP_STATUS_FOUND) or
      (LResp.StatusCode = HTTP_STATUS_SEE_OTHER) or
      (LResp.StatusCode = HTTP_STATUS_TEMPORARY_REDIRECT) or
      (LResp.StatusCode = HTTP_STATUS_PERMANENT_REDIRECT)) then
  begin
    HttpThrowIfCanceled(RequestCancelToken(AReq));
    if ARedirectsLeft <= 0 then
    begin
      ReleaseResponseBodyIgnoringErrors(LResp);
      raise EHttpError.CreateOp(hekRedirect, 'redirect',
        FormatHttpClientError(HttpMethodToStr(AReq.Method), LUrl,
          'too many redirects'));
    end;

    LRespHeaders := LResp.Headers;
    if LRespHeaders = nil then
    begin
      ReleaseResponseBodyIgnoringErrors(LResp);
      raise EHttpError.CreateOp(hekRedirect, 'redirect',
        FormatHttpClientError(HttpMethodToStr(AReq.Method), LUrl,
          'redirect with no response headers'));
    end;

    LLocations := LRespHeaders.GetAll('location');
    if Length(LLocations) > 1 then
    begin
      ReleaseResponseBodyIgnoringErrors(LResp);
      raise EHttpError.CreateOp(hekRedirect, 'redirect',
        FormatHttpClientError(HttpMethodToStr(AReq.Method), LUrl,
          'redirect with duplicate Location headers'));
    end;

    if Length(LLocations) = 1 then
      LLocation := LLocations[0]
    else
      LLocation := '';
    if LLocation = '' then
    begin
      ReleaseResponseBodyIgnoringErrors(LResp);
      raise EHttpError.CreateOp(hekRedirect, 'redirect',
        FormatHttpClientError(HttpMethodToStr(AReq.Method), LUrl,
          'redirect with no Location header'));
    end;

    try
      LNewUrl := ResolveRedirectUrl(LUrl, LLocation);
    except
      on E: EHttpError do
      begin
        ReleaseResponseBodyIgnoringErrors(LResp);
        if E.Kind = hekRedirect then
          raise EHttpError.CreateOp(hekRedirect, 'redirect',
            FormatHttpClientError(HttpMethodToStr(AReq.Method), LUrl,
              E.Message))
        else
          raise;
      end;
      else
      begin
        ReleaseResponseBodyIgnoringErrors(LResp);
        raise;
      end;
    end;
    ReleaseResponseBody(LResp);

    // Go-style 301/302/303 redirects keep HEAD, otherwise replay as GET.
    if (LResp.StatusCode = HTTP_STATUS_MOVED_PERMANENTLY) or
       (LResp.StatusCode = HTTP_STATUS_FOUND) or
       (LResp.StatusCode = HTTP_STATUS_SEE_OTHER) then
    begin
      LNewHeaders := RedirectHeadersFor(AReq, LUrl, LNewUrl, False);
      ARequestBodyCloseAttempted := True;
      CloseRequestBody(AReq.Body);
      LNewReq := THttpRequest.Create(MethodForGetStyleRedirect(AReq.Method),
        LNewUrl, hvHttp11, LNewHeaders, nil, 0);
    end
    else
    begin
      try
        RewindRedirectBody(AReq, LBodyStream, LBodyStartPosition);
      except
        on E: EHttpError do
          raise EHttpError.CreateOp(E.Kind, 'redirect',
            FormatHttpClientError(HttpMethodToStr(AReq.Method), LUrl,
              E.Message));
        else
          raise;
      end;
      LNewHeaders := RedirectHeadersFor(AReq, LUrl, LNewUrl, True);
      LNewReq := THttpRequest.Create(AReq.Method, LNewUrl, hvHttp11,
        LNewHeaders, AReq.Body, AReq.ContentLength);
    end;
    { Redirects create a fresh request object. Preserve per-request options so
      streaming sinks, cancellation, timeout, and redirect policy remain
      attached to every hop. }
    if Supports(AReq, IHttpRequestWithOptions, LReqOpts) and
       Supports(LNewReq, IHttpRequestWithOptions, LNewReqOpts) then
      LNewReqOpts.SetRequestOptions(LReqOpts.RequestOptions);

    Result := DoRequest(LNewReq, ARedirectsLeft - 1, ARequestBodyCloseAttempted);
  end
  else
  begin
    Result := LResp;
    { Stamp final URL on the concrete response (transport-built THttpResponse).
      Custom mock transports that implement IHttpResponse without THttpResponse
      keep FinalUrl empty — that is intentional. }
    if Result is THttpResponse then
      (Result as THttpResponse).SetFinalUrl(LUrl.ToString);
  end;
end;

function THttpClient.Send(const AReq: IHttpRequest): IHttpResponse;
var
  LRequestBodyCloseAttempted: Boolean;
  LResp: IHttpResponse;
  LReqOpts: IHttpRequestWithOptions;
  LMaxRedirects: Int32;
begin
  if AReq = nil then
    raise EHttpError.Create(hekArgument, 'HTTP request is nil');
  HttpThrowIfCanceled(RequestCancelToken(AReq));
  LRequestBodyCloseAttempted := False;
  LResp := nil;

  // Determine max redirects: per-request override or client default
  LMaxRedirects := FOptions.MaxRedirects;
  if Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
    LMaxRedirects := LReqOpts.RequestOptions.EffectiveMaxRedirects(
      FOptions.MaxRedirects);

  try
    LResp := DoRequest(AReq, LMaxRedirects, LRequestBodyCloseAttempted);
  except
    if not LRequestBodyCloseAttempted then
      try
        CloseRequestBody(AReq.Body);
      except
        // Preserve the transport or redirect error that made cleanup necessary.
      end;
    raise;
  end;

  if not LRequestBodyCloseAttempted then
    try
      CloseRequestBody(AReq.Body);
    except
      if LResp <> nil then
        try
          ReleaseResponseBody(LResp);
        except
          // Preserve the request-body close failure that made the response unreachable.
        end;
      raise;
    end;
  Result := LResp;
end;

procedure THttpClient.CloseIdleConnections;
var
  LIdleTransport: IHttpTransportIdleConnections;
begin
  if Supports(FTransport, IHttpTransportIdleConnections, LIdleTransport) then
    LIdleTransport.CloseIdleConnections;
end;

function THttpClient.Get(const AUrl: string): IHttpResponse;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse(AUrl);
  LReq := THttpRequest.Create(hmGet, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
  Result := Send(LReq);
end;

function THttpClient.GetString(const AUrl: string): string;
begin
  Result := HttpGetString(Self, AUrl);
end;

function THttpClient.GetBytes(const AUrl: string): TBytes;
begin
  Result := HttpGetBytes(Self, AUrl);
end;

function THttpClient.GetJson(const AUrl: string): IJsonDocument;
begin
  Result := HttpGetJson(Self, AUrl);
end;

function THttpClient.PostString(const AUrl, AContentType, ABody: string): string;
begin
  Result := HttpPostString(Self, AUrl, AContentType, ABody);
end;

function THttpClient.PutString(const AUrl, AContentType, ABody: string): string;
begin
  Result := HttpPutString(Self, AUrl, AContentType, ABody);
end;

function THttpClient.PatchString(const AUrl, AContentType, ABody: string): string;
begin
  Result := HttpPatchString(Self, AUrl, AContentType, ABody);
end;

function THttpClient.DeleteString(const AUrl: string): string;
begin
  Result := HttpDeleteString(Self, AUrl);
end;

function THttpClient.Post(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
begin
  Result := Send(BufferedBodyRequest(hmPost, AUrl, AContentType, ABody));
end;

function THttpClient.Post(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
begin
  Result := Send(BufferedBodyRequest(hmPost, AUrl, AContentType, ABody));
end;

function THttpClient.Put(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
begin
  Result := Send(BufferedBodyRequest(hmPut, AUrl, AContentType, ABody));
end;

function THttpClient.Put(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
begin
  Result := Send(BufferedBodyRequest(hmPut, AUrl, AContentType, ABody));
end;

function THttpClient.Delete(const AUrl: string): IHttpResponse;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse(AUrl);
  LReq := THttpRequest.Create(hmDelete, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
  Result := Send(LReq);
end;

function THttpClient.Delete(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
begin
  Result := Send(BufferedBodyRequest(hmDelete, AUrl, AContentType, ABody));
end;

function THttpClient.Delete(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
begin
  Result := Send(BufferedBodyRequest(hmDelete, AUrl, AContentType, ABody));
end;

function THttpClient.Patch(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
begin
  Result := Send(BufferedBodyRequest(hmPatch, AUrl, AContentType, ABody));
end;

function THttpClient.Patch(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
begin
  Result := Send(BufferedBodyRequest(hmPatch, AUrl, AContentType, ABody));
end;

function THttpClient.Head(const AUrl: string): IHttpResponse;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse(AUrl);
  LReq := THttpRequest.Create(hmHead, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
  Result := Send(LReq);
end;

function THttpClient.Options(const AUrl: string): IHttpResponse;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse(AUrl);
  LReq := THttpRequest.Create(hmOptions, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
  Result := Send(LReq);
end;

function THttpClient.PostForm(const AUrl: string;
  const AFields: TFormFieldArray): IHttpResponse;
var
  LBody: string;
begin
  LBody := nextpas.core.http.form.EncodeUrlEncodedForm(AFields);
  Result := Post(AUrl, 'application/x-www-form-urlencoded', LBody);
end;

function THttpClient.PostMultipart(const AUrl: string;
  const AFields: TFormFieldArray; const AFiles: THttpFileArray): IHttpResponse;
var
  LBoundary, LBody: string;
begin
  LBoundary := nextpas.core.http.form.NewMultipartBoundary;
  LBody := nextpas.core.http.form.EncodeMultipartFormData(AFields, AFiles,
    LBoundary);
  Result := Post(AUrl, 'multipart/form-data; boundary=' + LBoundary, LBody);
end;

function THttpClient.PostJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := Post(AUrl, 'application/json', JsonStringify(ABody));
end;

function THttpClient.PutJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := Put(AUrl, 'application/json', JsonStringify(ABody));
end;

function THttpClient.PatchJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := Patch(AUrl, 'application/json', JsonStringify(ABody));
end;

function THttpClient.DeleteJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := Delete(AUrl, 'application/json', JsonStringify(ABody));
end;

function THttpClient.SendStreaming(const AMethod: THttpMethod;
  const AUrl: string; const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpResponse;
var
  LBuilder: THttpRequestBuilder;
begin
  LBuilder := THttpRequestBuilder.Create(AMethod, AUrl);
  if AContentType <> '' then
    LBuilder := LBuilder.ContentType(AContentType);
  LBuilder := LBuilder.Body(ABody);
  { ContentLength < 0 → H1 chunked framing (builder omits CL / sets TE). }
  if AContentLength >= 0 then
    LBuilder := LBuilder.ContentLength(AContentLength);
  Result := Send(LBuilder.Build);
end;

function THttpClient.WithBasicAuth(const AUsername, APassword: string): IHttpClient;
begin
  Result := TAuthClient.Create(Self, 'Basic ' + Base64Encode(StringToUTF8Bytes(AUsername + ':' + APassword)));
end;

function THttpClient.WithBearerAuth(const AToken: string): IHttpClient;
begin
  Result := TAuthClient.Create(Self, 'Bearer ' + AToken);
end;

function THttpClient.WithHeader(const AName, AValue: string): IHttpClient;
begin
  Result := THeaderClient.Create(Self, AName, AValue);
end;

function THttpClient.WithTimeout(const ATimeoutMs: Int64): IHttpClient;
begin
  Result := TOptionsOverrideClient.Create(Self,
    Default(THttpRequestOptions).WithTimeout(ATimeoutMs));
end;

function THttpClient.WithConnectTimeout(const ATimeoutMs: Int64): IHttpClient;
begin
  { Rebuild transport so ConnectTimeout is plumbed to H1/H2 dial options. }
  Result := NewHttpClient(FOptions.WithConnectTimeout(ATimeoutMs));
end;

function THttpClient.WithMaxRedirects(const AMaxRedirects: Int32): IHttpClient;
begin
  Result := TOptionsOverrideClient.Create(Self,
    Default(THttpRequestOptions).WithMaxRedirects(AMaxRedirects));
end;

function THttpClient.WithFollowRedirects(const AFollow: Boolean): IHttpClient;
begin
  Result := TOptionsOverrideClient.Create(Self,
    Default(THttpRequestOptions).WithFollowRedirects(AFollow));
end;

function THttpClient.WithRetry(const AMaxRetries: Int32): IHttpClient;
begin
  Result := TRetryClient.Create(Self, AMaxRetries);
end;

function THttpClient.WithCookieJar(const AJar: IHttpCookieJar): IHttpClient;
begin
  if AJar = nil then
    raise EHttpError.Create(hekArgument, 'HTTP cookie jar is nil');
  Result := TCookieJarClient.Create(Self, AJar);
end;

function THttpClient.WithProxyUrl(const AProxyUrl: string): IHttpClient;
begin
  Result := NewHttpClient(FOptions.WithProxyUrl(AProxyUrl));
end;

function THttpClient.WithDialFunc(const ADial: THttpDialFunc): IHttpClient;
begin
  Result := NewHttpClient(FOptions.WithDialFunc(ADial));
end;

function THttpClient.WithTLSContext(const ATLSContext: ISSLContext): IHttpClient;
begin
  Result := NewHttpClient(FOptions.WithTLSContext(ATLSContext));
end;


{ Factory functions }

function NewHttpClient: IHttpClient;
begin
  Result := THttpClient.Create(THttpClientOptions.Default);
end;

function NewHttpClient(const AOptions: THttpClientOptions): IHttpClient;
begin
  Result := THttpClient.Create(AOptions);
end;

function NewHttpClient(const ATransport: IHttpTransport): IHttpClient;
begin
  Result := THttpClient.Create(ATransport, THttpClientOptions.Default);
end;

function NewHttpClient(const ATransport: IHttpTransport;
  const AOptions: THttpClientOptions): IHttpClient;
begin
  Result := THttpClient.Create(ATransport, AOptions);
end;

function HttpGetToWriter(const AClient: IHttpClient; const AUrl: string; const ADest: IWriter): Int64;
begin
  Result := nextpas.core.http.client.helpers.HttpGetToWriter(AClient, AUrl, ADest);
end;

function HttpGetToFile(const AClient: IHttpClient; const AUrl, ADestPath: string): Int64;
begin
  Result := nextpas.core.http.client.helpers.HttpGetToFile(AClient, AUrl, ADestPath);
end;

procedure HttpReleaseResponseBody(const AResp: IHttpResponse);
begin
  nextpas.core.http.client.helpers.HttpReleaseResponseBody(AResp);
end;

function HttpReadResponseBodyBytes(const AResp: IHttpResponse): TBytes;
begin
  Result := nextpas.core.http.client.helpers.HttpReadResponseBodyBytes(AResp);
end;

function HttpReadResponseBodyString(const AResp: IHttpResponse): string;
begin
  Result := nextpas.core.http.client.helpers.HttpReadResponseBodyString(AResp);
end;

function HttpReadResponseBodyStringAuto(const AResp: IHttpResponse): string;
begin
  Result := nextpas.core.http.client.helpers.HttpReadResponseBodyStringAuto(AResp);
end;

function HttpDecodeContentEncoding(const AEncoding: string; const ABody: TBytes; const AMaxSize: Int64): TBytes;
begin
  Result := nextpas.core.http.client.helpers.HttpDecodeContentEncoding(AEncoding, ABody, AMaxSize);
end;

function HttpReadResponseBodyBytesDecoded(const AResp: IHttpResponse; const AMaxSize: Int64): TBytes;
begin
  Result := nextpas.core.http.client.helpers.HttpReadResponseBodyBytesDecoded(AResp, AMaxSize);
end;

function HttpReadResponseBodyStringDecoded(const AResp: IHttpResponse; const AMaxSize: Int64): string;
begin
  Result := nextpas.core.http.client.helpers.HttpReadResponseBodyStringDecoded(AResp, AMaxSize);
end;

function HttpEnsureSuccess(const AResp: IHttpResponse; const AMethod, AUrl: string): IHttpResponse;
begin
  Result := nextpas.core.http.client.helpers.HttpEnsureSuccess(AResp, AMethod, AUrl);
end;

function HttpEnsureSuccess(const AResp: IHttpResponse): IHttpResponse;
begin
  Result := nextpas.core.http.client.helpers.HttpEnsureSuccess(AResp);
end;

function HttpGetString(const AClient: IHttpClient; const AUrl: string): string;
begin
  Result := nextpas.core.http.client.helpers.HttpGetString(AClient, AUrl);
end;

function HttpGetBytes(const AClient: IHttpClient; const AUrl: string): TBytes;
begin
  Result := nextpas.core.http.client.helpers.HttpGetBytes(AClient, AUrl);
end;

function HttpReadResponseJson(const AResp: IHttpResponse; const AMethod, AUrl: string): IJsonDocument;
begin
  Result := nextpas.core.http.client.helpers.HttpReadResponseJson(AResp, AMethod, AUrl);
end;

function HttpReadResponseJson(const AResp: IHttpResponse): IJsonDocument;
begin
  Result := nextpas.core.http.client.helpers.HttpReadResponseJson(AResp);
end;

function HttpGetJson(const AClient: IHttpClient; const AUrl: string): IJsonDocument;
begin
  Result := nextpas.core.http.client.helpers.HttpGetJson(AClient, AUrl);
end;

function HttpPostString(const AClient: IHttpClient; const AUrl, AContentType, ABody: string): string;
begin
  Result := nextpas.core.http.client.helpers.HttpPostString(AClient, AUrl, AContentType, ABody);
end;

function HttpPutString(const AClient: IHttpClient; const AUrl, AContentType, ABody: string): string;
begin
  Result := nextpas.core.http.client.helpers.HttpPutString(AClient, AUrl, AContentType, ABody);
end;

function HttpPatchString(const AClient: IHttpClient; const AUrl, AContentType, ABody: string): string;
begin
  Result := nextpas.core.http.client.helpers.HttpPatchString(AClient, AUrl, AContentType, ABody);
end;

function HttpDeleteString(const AClient: IHttpClient; const AUrl: string): string;
begin
  Result := nextpas.core.http.client.helpers.HttpDeleteString(AClient, AUrl);
end;

function HttpHead(const AClient: IHttpClient; const AUrl: string): IHttpResponse;
begin
  Result := nextpas.core.http.client.helpers.HttpHead(AClient, AUrl);
end;

function HttpOptions(const AClient: IHttpClient; const AUrl: string): IHttpResponse;
begin
  Result := nextpas.core.http.client.helpers.HttpOptions(AClient, AUrl);
end;

function HttpPostJson(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): string;
begin
  Result := nextpas.core.http.client.helpers.HttpPostJson(AClient, AUrl, ABody);
end;

function HttpPutJson(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): string;
begin
  Result := nextpas.core.http.client.helpers.HttpPutJson(AClient, AUrl, ABody);
end;

function HttpPatchJson(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): string;
begin
  Result := nextpas.core.http.client.helpers.HttpPatchJson(AClient, AUrl, ABody);
end;

function HttpDeleteJson(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): string;
begin
  Result := nextpas.core.http.client.helpers.HttpDeleteJson(AClient, AUrl, ABody);
end;

function HttpPostJsonDocument(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): IJsonDocument;
begin
  Result := nextpas.core.http.client.helpers.HttpPostJsonDocument(AClient, AUrl, ABody);
end;

function HttpPutJsonDocument(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): IJsonDocument;
begin
  Result := nextpas.core.http.client.helpers.HttpPutJsonDocument(AClient, AUrl, ABody);
end;

function HttpPatchJsonDocument(const AClient: IHttpClient; const AUrl: string; const ABody: IJsonDocument): IJsonDocument;
begin
  Result := nextpas.core.http.client.helpers.HttpPatchJsonDocument(AClient, AUrl, ABody);
end;

function ExtractCharsetFromContentType(const AContentType: string): string;
begin
  Result := nextpas.core.http.client.helpers.ExtractCharsetFromContentType(AContentType);
end;

end.
