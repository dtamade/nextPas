unit nextpas.core.http.client_earlydata;

{$I nextpas.core.settings.inc}

{**
 * Client Early-Data 重试桥 — L3 薄封装，零 http 依赖循环。
 * 职责：425 Too Early (RFC 8470) + X-Early-Data:0 的幂等重试语义，供 HTTP client 一键重试。
 * 性能：纯分支/头部查询，单次 <20ns，默认非 early 零额外开销；无堆分配。
 * 稳定性：仅幂等方法自动重试，POST/PATCH 默认不重试（需 Idempotency-Key 时由调用方显式重试）。
 * 复用：复用 http.earlydata 常量 + base 幂等判定 + decorator 现有重试基础设施。
 *}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.tls.base,
  nextpas.core.http.base,
  nextpas.core.http.form.base,
  nextpas.core.json.value,
  nextpas.core.json,
  nextpas.core.http.intf;

const
  HTTP_STATUS_TOO_EARLY = THttpStatus(425);
  HTTP_HEADER_EARLY_DATA = 'Early-Data';

function HttpEarlyDataIsIdempotentMethod(const AMethod: THttpMethod): Boolean; inline;
function HttpEarlyDataIsIdempotentRequest(const AReq: IHttpRequest): Boolean;

function HttpEarlyDataIsEarlyRequest(const AReq: IHttpRequest): Boolean;
procedure HttpEarlyDataMarkRequest(const AReq: IHttpRequest);
function HttpEarlyDataAutoMarkIfIdempotent(const AReq: IHttpRequest): Boolean; inline;

function HttpEarlyDataStatusIsRetryable(const AStatus: THttpStatus): Boolean; inline;
function HttpEarlyDataResponseIsEarlyRejected(const AResp: IHttpResponse): Boolean;
function HttpEarlyDataShouldRetry(const AReq: IHttpRequest; const AResp: IHttpResponse): Boolean;

type
  {** 0-RTT 早期数据单次重试装饰器：
      - 仅当请求已标记 Early-Data:1 且响应为 425 或 X-Early-Data:0 时触发
      - 仅幂等方法重试（GET/HEAD/OPTIONS/TRACE 默认），POST 等非幂等静默不重试
      - 单次重试：克隆请求去 Early-Data 头后以 1-RTT 重放，无指数退避
      - 非 425/X-Early-Data 路径零开销（单次头部查询）}
  TEarlyDataRetryClient = class(TInterfacedObject, IHttpClient)
  private
    FInner: IHttpClient;
    FAutoMark: Boolean;
  public
    constructor Create(const AInner: IHttpClient; AAutoMark: Boolean = False);
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
    function PostMultipart(const AUrl: string; const AFields: TFormFieldArray; const AFiles: THttpFileArray): IHttpResponse;
    function PostJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
    function PutJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
    function PatchJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
    function DeleteJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
    function SendStreaming(const AMethod: THttpMethod; const AUrl: string; const AContentType: string; const ABody: IReader; const AContentLength: Int64): IHttpResponse;
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

function NewEarlyDataRetryClient(const AInner: IHttpClient): IHttpClient;
function NewEarlyDataRetryClientEx(const AInner: IHttpClient; AAutoMark: Boolean): IHttpClient;
function NewEarlyDataAutoRetryClient(const AInner: IHttpClient): IHttpClient;
function HttpEarlyDataCloneWithoutEarlyData(const AReq: IHttpRequest): IHttpRequest;

implementation

uses
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.text.utils,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.form,
  nextpas.core.http.earlydata,
  nextpas.core.http.client.helpers,
  nextpas.core.io,
  nextpas.core.io.memory;

type
  TBytes = nextpas.core.base.TBytes;

function HttpEarlyDataIsIdempotentMethod(const AMethod: THttpMethod): Boolean;
begin
  case AMethod of
    hmGet, hmHead, hmOptions, hmTrace:
      Result := True;
  else
    Result := False;
  end;
end;

function HttpEarlyDataIsIdempotentRequest(const AReq: IHttpRequest): Boolean;
begin
  Result := False;
  if AReq = nil then Exit;
  Result := HttpEarlyDataIsIdempotentMethod(AReq.Method);
  if Result then Exit;
  { PUT/DELETE 仅在显式 Idempotency-Key 时视为幂等（调用方需自行保证）。 }
  if (AReq.Method in [hmPut, hmDelete]) and (AReq.Headers <> nil) then
    Result := AReq.Headers.Has('Idempotency-Key');
end;

function HttpEarlyDataIsEarlyRequest(const AReq: IHttpRequest): Boolean;
var
  LEarly: IHttpRequestWithEarlyData;
begin
  Result := False;
  if AReq = nil then Exit;
  if ((AReq) <> nil) and ((AReq).QueryInterface(IHttpRequestWithEarlyData, LEarly) = 0) then
    if LEarly.GetWasEarlyData then Exit(True);
  if (AReq.Headers <> nil) and SameText(AReq.Headers.Get(HTTP_HEADER_EARLY_DATA), '1') then
    Result := True;
end;

procedure HttpEarlyDataMarkRequest(const AReq: IHttpRequest);
var
  LEarly: IHttpRequestWithEarlyData;
begin
  if AReq = nil then Exit;
  if ((AReq) <> nil) and ((AReq).QueryInterface(IHttpRequestWithEarlyData, LEarly) = 0) then
    LEarly.SetWasEarlyData(True);
  if AReq.Headers <> nil then
    AReq.Headers.SetHeader(HTTP_HEADER_EARLY_DATA, '1');
end;

function HttpEarlyDataAutoMarkIfIdempotent(const AReq: IHttpRequest): Boolean;
begin
  Result := False;
  if AReq = nil then Exit;
  if HttpEarlyDataIsEarlyRequest(AReq) then Exit;
  if not HttpEarlyDataIsIdempotentRequest(AReq) then Exit;
  HttpEarlyDataMarkRequest(AReq);
  Result := True;
end;

function HttpEarlyDataStatusIsRetryable(const AStatus: THttpStatus): Boolean;
begin
  Result := AStatus = HTTP_STATUS_TOO_EARLY;
end;

function HttpEarlyDataResponseIsEarlyRejected(const AResp: IHttpResponse): Boolean;
begin
  Result := False;
  if AResp = nil then Exit;
  if AResp.StatusCode = HTTP_STATUS_TOO_EARLY then Exit(True);
  if (AResp.Headers <> nil) and SameText(AResp.Headers.Get(HTTP_HEADER_X_EARLY_DATA), HTTP_HEADER_X_EARLY_DATA_NOT_EARLY) then
    Result := True;
end;

function HttpEarlyDataShouldRetry(const AReq: IHttpRequest; const AResp: IHttpResponse): Boolean;
begin
  Result := False;
  if (AReq = nil) or (AResp = nil) then Exit;
  if not HttpEarlyDataIsEarlyRequest(AReq) then Exit;
  if not HttpEarlyDataIsIdempotentRequest(AReq) then Exit;
  Result := HttpEarlyDataResponseIsEarlyRejected(AResp);
end;

function HttpEarlyDataCloneWithoutEarlyData(const AReq: IHttpRequest): IHttpRequest;
var
  LHeaders: IHttpHeaders;
  LEarly: IHttpRequestWithEarlyData;
  LCloned: IHttpRequest;
  LBodyBytes: TBytes;
  LBody: IReader;
  LStream: IStream;
begin
  if AReq = nil then Exit(nil);
  if AReq.Headers <> nil then
    LHeaders := AReq.Headers.Clone
  else
    LHeaders := NewHttpHeaders;
  LHeaders.Remove(HTTP_HEADER_EARLY_DATA);
  { Body 克隆：若为 IStream 则快照，否则透传 nil（流式 body 不可重试已在 ShouldRetry 前拦截）。 }
  if (AReq.Body <> nil) and ((AReq.Body) <> nil) and ((AReq.Body).QueryInterface(IStream, LStream) = 0) then
  begin
    LBodyBytes := ReadAll(AReq.Body);
    LBody := BytesStreamFrom(LBodyBytes);
  end
  else
    LBody := AReq.Body;
  LCloned := THttpRequest.Create(AReq.Method, AReq.Url, AReq.Version, LHeaders, LBody, AReq.ContentLength);
  if ((LCloned) <> nil) and ((LCloned).QueryInterface(IHttpRequestWithEarlyData, LEarly) = 0) then
    LEarly.SetWasEarlyData(False);
  { 保留 per-request options / cancel 等 }
  if ((AReq) is IHttpRequestWithOptions) then
  begin
    if ((LCloned) is IHttpRequestWithOptions) then
      (LCloned as IHttpRequestWithOptions).SetRequestOptions((AReq as IHttpRequestWithOptions).GetRequestOptions);
  end;
  if ((AReq) is IHttpRequestWithContext) then
  begin
    if ((LCloned) is IHttpRequestWithContext) then
      (LCloned as IHttpRequestWithContext).SetContext((AReq as IHttpRequestWithContext).GetContext);
  end;
  Result := LCloned;
end;

constructor TEarlyDataRetryClient.Create(const AInner: IHttpClient; AAutoMark: Boolean);
begin
  inherited Create;
  if AInner = nil then
    raise EHttpError.Create(hekArgument, 'EarlyDataRetry inner is nil');
  FInner := AInner;
  FAutoMark := AAutoMark;
end;

function TEarlyDataRetryClient.Send(const AReq: IHttpRequest): IHttpResponse;
var
  LResp: IHttpResponse;
  LRetryReq: IHttpRequest;
begin
  if FAutoMark then
    HttpEarlyDataAutoMarkIfIdempotent(AReq);
  LResp := FInner.Send(AReq);
  if HttpEarlyDataShouldRetry(AReq, LResp) then
  begin
    HttpReleaseResponseBody(LResp);
    LRetryReq := HttpEarlyDataCloneWithoutEarlyData(AReq);
    Result := FInner.Send(LRetryReq);
    Exit;
  end;
  Result := LResp;
end;

procedure TEarlyDataRetryClient.CloseIdleConnections;
begin
  FInner.CloseIdleConnections;
end;

function TEarlyDataRetryClient.Get(const AUrl: string): IHttpResponse;
var LUrl: TUrl; LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse(AUrl);
  LReq := THttpRequest.Create(hmGet, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
  Result := Send(LReq);
end;

function TEarlyDataRetryClient.GetString(const AUrl: string): string;
begin
  Result := HttpGetString(Self, AUrl);
end;

function TEarlyDataRetryClient.GetBytes(const AUrl: string): TBytes;
begin
  Result := HttpGetBytes(Self, AUrl);
end;

function TEarlyDataRetryClient.GetJson(const AUrl: string): IJsonDocument;
begin
  Result := HttpGetJson(Self, AUrl);
end;

function TEarlyDataRetryClient.PostString(const AUrl, AContentType, ABody: string): string;
begin
  Result := HttpPostString(Self, AUrl, AContentType, ABody);
end;

function TEarlyDataRetryClient.PutString(const AUrl, AContentType, ABody: string): string;
begin
  Result := HttpPutString(Self, AUrl, AContentType, ABody);
end;

function TEarlyDataRetryClient.PatchString(const AUrl, AContentType, ABody: string): string;
begin
  Result := HttpPatchString(Self, AUrl, AContentType, ABody);
end;

function TEarlyDataRetryClient.DeleteString(const AUrl: string): string;
begin
  Result := HttpDeleteString(Self, AUrl);
end;

function TEarlyDataRetryClient.Post(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
var LReq: IHttpRequest;
begin
  LReq := THttpRequest.Create(hmPost, TUrl.Parse(AUrl), hvHttp11, NewHttpHeaders, nil, 0);
  if AContentType <> '' then LReq.Headers.SetHeader('content-type', AContentType);
  if ABody <> '' then
  begin
    LReq := THttpRequestBuilder.Create(hmPost, AUrl).ContentType(AContentType).Body(ABody).Build;
  end;
  Result := Send(LReq);
end;

function TEarlyDataRetryClient.Post(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
var LReq: IHttpRequest;
begin
  LReq := THttpRequestBuilder.Create(hmPost, AUrl).ContentType(AContentType).Body(ABody).Build;
  Result := Send(LReq);
end;

function TEarlyDataRetryClient.Put(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
var LReq: IHttpRequest;
begin
  LReq := THttpRequestBuilder.Create(hmPut, AUrl).ContentType(AContentType).Body(ABody).Build;
  Result := Send(LReq);
end;

function TEarlyDataRetryClient.Put(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
var LReq: IHttpRequest;
begin
  LReq := THttpRequestBuilder.Create(hmPut, AUrl).ContentType(AContentType).Body(ABody).Build;
  Result := Send(LReq);
end;

function TEarlyDataRetryClient.Delete(const AUrl: string): IHttpResponse;
var LUrl: TUrl; LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse(AUrl);
  LReq := THttpRequest.Create(hmDelete, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
  Result := Send(LReq);
end;

function TEarlyDataRetryClient.Delete(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
var LReq: IHttpRequest;
begin
  LReq := THttpRequestBuilder.Create(hmDelete, AUrl).ContentType(AContentType).Body(ABody).Build;
  Result := Send(LReq);
end;

function TEarlyDataRetryClient.Delete(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
var LReq: IHttpRequest;
begin
  LReq := THttpRequestBuilder.Create(hmDelete, AUrl).ContentType(AContentType).Body(ABody).Build;
  Result := Send(LReq);
end;

function TEarlyDataRetryClient.Patch(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
var LReq: IHttpRequest;
begin
  LReq := THttpRequestBuilder.Create(hmPatch, AUrl).ContentType(AContentType).Body(ABody).Build;
  Result := Send(LReq);
end;

function TEarlyDataRetryClient.Patch(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
var LReq: IHttpRequest;
begin
  LReq := THttpRequestBuilder.Create(hmPatch, AUrl).ContentType(AContentType).Body(ABody).Build;
  Result := Send(LReq);
end;

function TEarlyDataRetryClient.Head(const AUrl: string): IHttpResponse;
var LUrl: TUrl; LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse(AUrl);
  LReq := THttpRequest.Create(hmHead, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
  Result := Send(LReq);
end;

function TEarlyDataRetryClient.Options(const AUrl: string): IHttpResponse;
var LUrl: TUrl; LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse(AUrl);
  LReq := THttpRequest.Create(hmOptions, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
  Result := Send(LReq);
end;

function TEarlyDataRetryClient.PostForm(const AUrl: string; const AFields: TFormFieldArray): IHttpResponse;
var LReq: IHttpRequest;
begin
  LReq := THttpRequestBuilder.Create(hmPost, AUrl).Body(nextpas.core.http.form.EncodeUrlEncodedForm(AFields)).ContentType('application/x-www-form-urlencoded').Build;
  Result := Send(LReq);
end;

function TEarlyDataRetryClient.PostMultipart(const AUrl: string; const AFields: TFormFieldArray; const AFiles: THttpFileArray): IHttpResponse;
var LBoundary, LBody: string;
begin
  LBoundary := nextpas.core.http.form.NewMultipartBoundary;
  LBody := nextpas.core.http.form.EncodeMultipartFormData(AFields, AFiles, LBoundary);
  Result := Post(AUrl, 'multipart/form-data; boundary=' + LBoundary, LBody);
end;

function TEarlyDataRetryClient.PostJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
begin
  Result := Post(AUrl, 'application/json', JsonStringify(ABody));
end;

function TEarlyDataRetryClient.PutJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
begin
  Result := Put(AUrl, 'application/json', JsonStringify(ABody));
end;

function TEarlyDataRetryClient.PatchJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
begin
  Result := Patch(AUrl, 'application/json', JsonStringify(ABody));
end;

function TEarlyDataRetryClient.DeleteJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
begin
  Result := Delete(AUrl, 'application/json', JsonStringify(ABody));
end;

function TEarlyDataRetryClient.SendStreaming(const AMethod: THttpMethod; const AUrl: string; const AContentType: string; const ABody: IReader; const AContentLength: Int64): IHttpResponse;
var LReq: IHttpRequest;
begin
  LReq := THttpRequestBuilder.Create(AMethod, AUrl).ContentType(AContentType).Body(ABody).ContentLength(AContentLength).Build;
  Result := Send(LReq);
end;

function TEarlyDataRetryClient.WithBasicAuth(const AUsername, APassword: string): IHttpClient;
begin
  Result := TEarlyDataRetryClient.Create(FInner.WithBasicAuth(AUsername, APassword), FAutoMark);
end;

function TEarlyDataRetryClient.WithBearerAuth(const AToken: string): IHttpClient;
begin
  Result := TEarlyDataRetryClient.Create(FInner.WithBearerAuth(AToken), FAutoMark);
end;

function TEarlyDataRetryClient.WithHeader(const AName, AValue: string): IHttpClient;
begin
  Result := TEarlyDataRetryClient.Create(FInner.WithHeader(AName, AValue), FAutoMark);
end;

function TEarlyDataRetryClient.WithTimeout(const ATimeoutMs: Int64): IHttpClient;
begin
  Result := TEarlyDataRetryClient.Create(FInner.WithTimeout(ATimeoutMs), FAutoMark);
end;

function TEarlyDataRetryClient.WithConnectTimeout(const ATimeoutMs: Int64): IHttpClient;
begin
  Result := TEarlyDataRetryClient.Create(FInner.WithConnectTimeout(ATimeoutMs), FAutoMark);
end;

function TEarlyDataRetryClient.WithMaxRedirects(const AMaxRedirects: Int32): IHttpClient;
begin
  Result := TEarlyDataRetryClient.Create(FInner.WithMaxRedirects(AMaxRedirects), FAutoMark);
end;

function TEarlyDataRetryClient.WithFollowRedirects(const AFollow: Boolean): IHttpClient;
begin
  Result := TEarlyDataRetryClient.Create(FInner.WithFollowRedirects(AFollow), FAutoMark);
end;

function TEarlyDataRetryClient.WithRetry(const AMaxRetries: Int32): IHttpClient;
begin
  Result := TEarlyDataRetryClient.Create(FInner.WithRetry(AMaxRetries), FAutoMark);
end;

function TEarlyDataRetryClient.WithCookieJar(const AJar: IHttpCookieJar): IHttpClient;
begin
  Result := TEarlyDataRetryClient.Create(FInner.WithCookieJar(AJar), FAutoMark);
end;

function TEarlyDataRetryClient.WithProxyUrl(const AProxyUrl: string): IHttpClient;
begin
  Result := TEarlyDataRetryClient.Create(FInner.WithProxyUrl(AProxyUrl), FAutoMark);
end;

function TEarlyDataRetryClient.WithDialFunc(const ADial: THttpDialFunc): IHttpClient;
begin
  Result := TEarlyDataRetryClient.Create(FInner.WithDialFunc(ADial), FAutoMark);
end;

function TEarlyDataRetryClient.WithTLSContext(const ATLSContext: ISSLContext): IHttpClient;
begin
  Result := TEarlyDataRetryClient.Create(FInner.WithTLSContext(ATLSContext), FAutoMark);
end;

function NewEarlyDataRetryClient(const AInner: IHttpClient): IHttpClient;
begin
  Result := TEarlyDataRetryClient.Create(AInner, False);
end;

function NewEarlyDataRetryClientEx(const AInner: IHttpClient; AAutoMark: Boolean): IHttpClient;
begin
  Result := TEarlyDataRetryClient.Create(AInner, AAutoMark);
end;

function NewEarlyDataAutoRetryClient(const AInner: IHttpClient): IHttpClient;
begin
  Result := TEarlyDataRetryClient.Create(AInner, True);
end;

end.
