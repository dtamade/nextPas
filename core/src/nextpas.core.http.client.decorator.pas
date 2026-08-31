unit nextpas.core.http.client.decorator;
{**
 * @desc HTTP client decorator stack (STRUCT-2 extract from client).
 *       Forwarder + Auth/Header/Cookie/Options/Retry; no THttpClient class.
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
  { Decorator base: all convenience methods go through virtual Send. }
  THttpClientForwarder = class(TInterfacedObject, IHttpClient)
  protected
    FInner: IHttpClient;
    { Rebuild this decorator around a new base (used by WithProxyUrl / WithTLSContext). }
    function RebindInner(const AInner: IHttpClient): IHttpClient; virtual;
  public
    constructor Create(const AInner: IHttpClient);
    function Send(const AReq: IHttpRequest): IHttpResponse; virtual;
    procedure CloseIdleConnections; virtual;
    function Get(const AUrl: string): IHttpResponse; virtual;
    function GetString(const AUrl: string): string; virtual;
    function GetBytes(const AUrl: string): TBytes; virtual;
    function GetJson(const AUrl: string): IJsonDocument; virtual;
    function PostString(const AUrl, AContentType, ABody: string): string; virtual;
    function PutString(const AUrl, AContentType, ABody: string): string; virtual;
    function PatchString(const AUrl, AContentType, ABody: string): string; virtual;
    function DeleteString(const AUrl: string): string; virtual;
    function Post(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload; virtual;
    function Post(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload; virtual;
    function Put(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload; virtual;
    function Put(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload; virtual;
    function Delete(const AUrl: string): IHttpResponse; overload; virtual;
    function Delete(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload; virtual;
    function Delete(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload; virtual;
    function Patch(const AUrl, AContentType: string; const ABody: string): IHttpResponse; overload; virtual;
    function Patch(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse; overload; virtual;
    function Head(const AUrl: string): IHttpResponse; virtual;
    function Options(const AUrl: string): IHttpResponse; virtual;
    function PostForm(const AUrl: string; const AFields: TFormFieldArray): IHttpResponse; virtual;
    function PostMultipart(const AUrl: string; const AFields: TFormFieldArray;
      const AFiles: THttpFileArray): IHttpResponse; virtual;
    function PostJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse; virtual;
    function PutJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse; virtual;
    function PatchJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse; virtual;
    function DeleteJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse; virtual;
    function SendStreaming(const AMethod: THttpMethod; const AUrl: string;
      const AContentType: string; const ABody: IReader;
      const AContentLength: Int64): IHttpResponse; virtual;
    function WithBasicAuth(const AUsername, APassword: string): IHttpClient; virtual;
    function WithBearerAuth(const AToken: string): IHttpClient; virtual;
    function WithHeader(const AName, AValue: string): IHttpClient; virtual;
    function WithTimeout(const ATimeoutMs: Int64): IHttpClient; virtual;
    function WithConnectTimeout(const ATimeoutMs: Int64): IHttpClient; virtual;
    function WithMaxRedirects(const AMaxRedirects: Int32): IHttpClient; virtual;
    function WithFollowRedirects(const AFollow: Boolean): IHttpClient; virtual;
    function WithRetry(const AMaxRetries: Int32): IHttpClient; virtual;
    function WithCookieJar(const AJar: IHttpCookieJar): IHttpClient; virtual;
    function WithProxyUrl(const AProxyUrl: string): IHttpClient; virtual;
    function WithDialFunc(const ADial: THttpDialFunc): IHttpClient; virtual;
    function WithTLSContext(const ATLSContext: ISSLContext): IHttpClient; virtual;
  end;

  TCookieJarClient = class(THttpClientForwarder)
  private
    FJar: IHttpCookieJar;
  protected
    function RebindInner(const AInner: IHttpClient): IHttpClient; override;
  public
    constructor Create(const AInner: IHttpClient; const AJar: IHttpCookieJar);
    function Send(const AReq: IHttpRequest): IHttpResponse; override;
  end;

  TAuthClient = class(THttpClientForwarder)
  private
    FAuthHeader: string;
  protected
    function RebindInner(const AInner: IHttpClient): IHttpClient; override;
  public
    constructor Create(const AInner: IHttpClient; const AAuthHeader: string);
    function Send(const AReq: IHttpRequest): IHttpResponse; override;
  end;

  THeaderClient = class(THttpClientForwarder)
  private
    FName: string;
    FValue: string;
  protected
    function RebindInner(const AInner: IHttpClient): IHttpClient; override;
  public
    constructor Create(const AInner: IHttpClient; const AName, AValue: string);
    function Send(const AReq: IHttpRequest): IHttpResponse; override;
  end;

  TOptionsOverrideClient = class(THttpClientForwarder)
  private
    FRequestOptions: THttpRequestOptions;
    procedure ApplyOptions(const AReq: IHttpRequest);
  protected
    function RebindInner(const AInner: IHttpClient): IHttpClient; override;
  public
    constructor Create(const AInner: IHttpClient;
      const ARequestOptions: THttpRequestOptions);
    function Send(const AReq: IHttpRequest): IHttpResponse; override;
  end;

  TRetryClient = class(THttpClientForwarder)
  private
    FMaxRetries: Int32;
  protected
    function RebindInner(const AInner: IHttpClient): IHttpClient; override;
  public
    constructor Create(const AInner: IHttpClient; const AMaxRetries: Int32);
    function Send(const AReq: IHttpRequest): IHttpResponse; override;
  end;

{ K86 导出面（原 implementation 私有提升）：HTTP 重试语义纯函数——
  decorator 自用 + code888 provider 双消费者（刀 82 双消费者判据）。
  三家锚：grok-build RetryPolicy::server / codex retry_delay /
  opencode session/retry.ts 解析链 }

{ 可重试状态判定：429 Too Many Requests + 整个 5xx 类；其余 4xx 终结 }
function HttpStatusIsRetryable(const AStatus: THttpStatus): Boolean;

{ IMF-fix HTTP-date（RFC 7231 首选格式）→ unix 秒；失败 False。
  纯函数无时钟依赖（时钟语义在 TryHttpParseRetryAfterMs 组合层） }
function TryParseHttpDateUnix(const ADate: string; out AUnix: Int64): Boolean;

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
  nextpas.core.http.client.helpers,
  nextpas.core.platform.thread,
  nextpas.core.time,
  nextpas.core.time.datetime,
  nextpas.core.time.offsetdatetime,
  nextpas.core.time.timezone;

{ Local copies of former client-private helpers (no reverse interface dep). }

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

function RequestCancelToken(const AReq: IHttpRequest): IHttpCancelToken;
var
  LReqOpts: IHttpRequestWithOptions;
begin
  Result := nil;
  if Supports(AReq, IHttpRequestWithOptions, LReqOpts) then
    Result := LReqOpts.RequestOptions.EffectiveCancelToken;
end;

function THttpClientForwarder.WithConnectTimeout(
  const ATimeoutMs: Int64): IHttpClient;
begin
  Result := RebindInner(FInner.WithConnectTimeout(ATimeoutMs));
end;

{ THttpClientForwarder }

constructor THttpClientForwarder.Create(const AInner: IHttpClient);
begin
  inherited Create;
  if AInner = nil then
    raise EHttpError.Create(hekArgument, 'HTTP client decorator inner is nil');
  FInner := AInner;
end;

function THttpClientForwarder.RebindInner(const AInner: IHttpClient): IHttpClient;
begin
  Result := AInner;
end;

function THttpClientForwarder.Send(const AReq: IHttpRequest): IHttpResponse;
begin
  Result := FInner.Send(AReq);
end;

procedure THttpClientForwarder.CloseIdleConnections;
begin
  FInner.CloseIdleConnections;
end;

function THttpClientForwarder.Get(const AUrl: string): IHttpResponse;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse(AUrl);
  LReq := THttpRequest.Create(hmGet, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
  Result := Send(LReq);
end;

function THttpClientForwarder.GetString(const AUrl: string): string;
begin
  Result := HttpGetString(Self, AUrl);
end;

function THttpClientForwarder.GetBytes(const AUrl: string): TBytes;
begin
  Result := HttpGetBytes(Self, AUrl);
end;

function THttpClientForwarder.GetJson(const AUrl: string): IJsonDocument;
begin
  Result := HttpGetJson(Self, AUrl);
end;

function THttpClientForwarder.PostString(const AUrl, AContentType,
  ABody: string): string;
begin
  Result := HttpPostString(Self, AUrl, AContentType, ABody);
end;

function THttpClientForwarder.PutString(const AUrl, AContentType,
  ABody: string): string;
begin
  Result := HttpPutString(Self, AUrl, AContentType, ABody);
end;

function THttpClientForwarder.PatchString(const AUrl, AContentType,
  ABody: string): string;
begin
  Result := HttpPatchString(Self, AUrl, AContentType, ABody);
end;

function THttpClientForwarder.DeleteString(const AUrl: string): string;
begin
  Result := HttpDeleteString(Self, AUrl);
end;

function THttpClientForwarder.Post(const AUrl, AContentType: string;
  const ABody: string): IHttpResponse;
begin
  Result := Send(BufferedBodyRequest(hmPost, AUrl, AContentType, ABody));
end;

function THttpClientForwarder.Post(const AUrl, AContentType: string;
  const ABody: TBytes): IHttpResponse;
begin
  Result := Send(BufferedBodyRequest(hmPost, AUrl, AContentType, ABody));
end;

function THttpClientForwarder.Put(const AUrl, AContentType: string;
  const ABody: string): IHttpResponse;
begin
  Result := Send(BufferedBodyRequest(hmPut, AUrl, AContentType, ABody));
end;

function THttpClientForwarder.Put(const AUrl, AContentType: string;
  const ABody: TBytes): IHttpResponse;
begin
  Result := Send(BufferedBodyRequest(hmPut, AUrl, AContentType, ABody));
end;

function THttpClientForwarder.Delete(const AUrl: string): IHttpResponse;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse(AUrl);
  LReq := THttpRequest.Create(hmDelete, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
  Result := Send(LReq);
end;

function THttpClientForwarder.Delete(const AUrl, AContentType: string;
  const ABody: string): IHttpResponse;
begin
  Result := Send(BufferedBodyRequest(hmDelete, AUrl, AContentType, ABody));
end;

function THttpClientForwarder.Delete(const AUrl, AContentType: string;
  const ABody: TBytes): IHttpResponse;
begin
  Result := Send(BufferedBodyRequest(hmDelete, AUrl, AContentType, ABody));
end;

function THttpClientForwarder.Patch(const AUrl, AContentType: string;
  const ABody: string): IHttpResponse;
begin
  Result := Send(BufferedBodyRequest(hmPatch, AUrl, AContentType, ABody));
end;

function THttpClientForwarder.Patch(const AUrl, AContentType: string;
  const ABody: TBytes): IHttpResponse;
begin
  Result := Send(BufferedBodyRequest(hmPatch, AUrl, AContentType, ABody));
end;

function THttpClientForwarder.Head(const AUrl: string): IHttpResponse;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse(AUrl);
  LReq := THttpRequest.Create(hmHead, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
  Result := Send(LReq);
end;

function THttpClientForwarder.Options(const AUrl: string): IHttpResponse;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse(AUrl);
  LReq := THttpRequest.Create(hmOptions, LUrl, hvHttp11, NewHttpHeaders, nil, 0);
  Result := Send(LReq);
end;

function THttpClientForwarder.PostForm(const AUrl: string;
  const AFields: TFormFieldArray): IHttpResponse;
var
  LBody: string;
begin
  LBody := nextpas.core.http.form.EncodeUrlEncodedForm(AFields);
  Result := Post(AUrl, 'application/x-www-form-urlencoded', LBody);
end;

function THttpClientForwarder.PostMultipart(const AUrl: string;
  const AFields: TFormFieldArray; const AFiles: THttpFileArray): IHttpResponse;
var
  LBoundary, LBody: string;
begin
  LBoundary := nextpas.core.http.form.NewMultipartBoundary;
  LBody := nextpas.core.http.form.EncodeMultipartFormData(AFields, AFiles,
    LBoundary);
  Result := Post(AUrl, 'multipart/form-data; boundary=' + LBoundary, LBody);
end;

function THttpClientForwarder.PostJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := Post(AUrl, 'application/json', JsonStringify(ABody));
end;

function THttpClientForwarder.PutJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := Put(AUrl, 'application/json', JsonStringify(ABody));
end;

function THttpClientForwarder.PatchJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := Patch(AUrl, 'application/json', JsonStringify(ABody));
end;

function THttpClientForwarder.DeleteJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := Delete(AUrl, 'application/json', JsonStringify(ABody));
end;

function THttpClientForwarder.SendStreaming(const AMethod: THttpMethod;
  const AUrl: string; const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpResponse;
var
  LBuilder: THttpRequestBuilder;
begin
  LBuilder := THttpRequestBuilder.Create(AMethod, AUrl);
  if AContentType <> '' then
    LBuilder := LBuilder.ContentType(AContentType);
  LBuilder := LBuilder.Body(ABody);
  if AContentLength >= 0 then
    LBuilder := LBuilder.ContentLength(AContentLength);
  Result := Send(LBuilder.Build);
end;

function THttpClientForwarder.WithBasicAuth(const AUsername,
  APassword: string): IHttpClient;
begin
  Result := TAuthClient.Create(Self, 'Basic ' +
    Base64Encode(StringToUTF8Bytes(AUsername + ':' + APassword)));
end;

function THttpClientForwarder.WithBearerAuth(const AToken: string): IHttpClient;
begin
  Result := TAuthClient.Create(Self, 'Bearer ' + AToken);
end;

function THttpClientForwarder.WithHeader(const AName, AValue: string): IHttpClient;
begin
  Result := THeaderClient.Create(Self, AName, AValue);
end;

function THttpClientForwarder.WithTimeout(const ATimeoutMs: Int64): IHttpClient;
begin
  Result := TOptionsOverrideClient.Create(Self,
    Default(THttpRequestOptions).WithTimeout(ATimeoutMs));
end;

function THttpClientForwarder.WithMaxRedirects(
  const AMaxRedirects: Int32): IHttpClient;
begin
  Result := TOptionsOverrideClient.Create(Self,
    Default(THttpRequestOptions).WithMaxRedirects(AMaxRedirects));
end;

function THttpClientForwarder.WithFollowRedirects(
  const AFollow: Boolean): IHttpClient;
begin
  Result := TOptionsOverrideClient.Create(Self,
    Default(THttpRequestOptions).WithFollowRedirects(AFollow));
end;

function THttpClientForwarder.WithRetry(const AMaxRetries: Int32): IHttpClient;
begin
  Result := TRetryClient.Create(Self, AMaxRetries);
end;

function THttpClientForwarder.WithCookieJar(const AJar: IHttpCookieJar): IHttpClient;
begin
  if AJar = nil then
    raise EHttpError.Create(hekArgument, 'HTTP cookie jar is nil');
  Result := TCookieJarClient.Create(Self, AJar);
end;

function THttpClientForwarder.WithProxyUrl(const AProxyUrl: string): IHttpClient;
begin
  Result := RebindInner(FInner.WithProxyUrl(AProxyUrl));
end;

function THttpClientForwarder.WithDialFunc(const ADial: THttpDialFunc): IHttpClient;
begin
  Result := RebindInner(FInner.WithDialFunc(ADial));
end;

function THttpClientForwarder.WithTLSContext(
  const ATLSContext: ISSLContext): IHttpClient;
begin
  Result := RebindInner(FInner.WithTLSContext(ATLSContext));
end;

{ TCookieJarClient }

constructor TCookieJarClient.Create(const AInner: IHttpClient;
  const AJar: IHttpCookieJar);
begin
  inherited Create(AInner);
  FJar := AJar;
end;

function TCookieJarClient.RebindInner(const AInner: IHttpClient): IHttpClient;
begin
  Result := TCookieJarClient.Create(AInner, FJar);
end;

function TCookieJarClient.Send(const AReq: IHttpRequest): IHttpResponse;
var
  LCookie: string;
begin
  if (AReq <> nil) and (AReq.Headers <> nil) and (FJar <> nil) then
  begin
    if not AReq.Headers.Has('cookie') then
    begin
      LCookie := FJar.CookieHeaderFor(AReq.Url);
      if LCookie <> '' then
        AReq.Headers.SetHeader('cookie', LCookie);
    end;
  end;
  Result := inherited Send(AReq);
  if (Result <> nil) and (Result.Headers <> nil) and (AReq <> nil) and
     (FJar <> nil) then
    FJar.StoreFromResponse(AReq.Url, Result.Headers);
end;

{ TAuthClient }

constructor TAuthClient.Create(const AInner: IHttpClient;
  const AAuthHeader: string);
begin
  inherited Create(AInner);
  FAuthHeader := AAuthHeader;
end;

function TAuthClient.RebindInner(const AInner: IHttpClient): IHttpClient;
begin
  Result := TAuthClient.Create(AInner, FAuthHeader);
end;

function TAuthClient.Send(const AReq: IHttpRequest): IHttpResponse;
begin
  { Outer auth wins: only set when not already present. }
  if (AReq <> nil) and (AReq.Headers <> nil) and
     (not AReq.Headers.Has('authorization')) then
    AReq.Headers.SetHeader('authorization', FAuthHeader);
  Result := inherited Send(AReq);
end;

{ THeaderClient }

constructor THeaderClient.Create(const AInner: IHttpClient;
  const AName, AValue: string);
begin
  inherited Create(AInner);
  FName := AName;
  FValue := AValue;
end;

function THeaderClient.RebindInner(const AInner: IHttpClient): IHttpClient;
begin
  Result := THeaderClient.Create(AInner, FName, FValue);
end;

function THeaderClient.Send(const AReq: IHttpRequest): IHttpResponse;
begin
  { Outer WithHeader wins for the same name (Send walks outer→inner). }
  if (AReq <> nil) and (AReq.Headers <> nil) and
     (not AReq.Headers.Has(FName)) then
    AReq.Headers.SetHeader(FName, FValue);
  Result := inherited Send(AReq);
end;

{ TOptionsOverrideClient }

constructor TOptionsOverrideClient.Create(const AInner: IHttpClient;
  const ARequestOptions: THttpRequestOptions);
begin
  inherited Create(AInner);
  FRequestOptions := ARequestOptions;
end;

function TOptionsOverrideClient.RebindInner(
  const AInner: IHttpClient): IHttpClient;
begin
  Result := TOptionsOverrideClient.Create(AInner, FRequestOptions);
end;

procedure TOptionsOverrideClient.ApplyOptions(const AReq: IHttpRequest);
var
  LReqWithOpts: IHttpRequestWithOptions;
  LMerged: THttpRequestOptions;
begin
  if not Supports(AReq, IHttpRequestWithOptions, LReqWithOpts) then
    Exit;
  LMerged := LReqWithOpts.RequestOptions;
  { Outer decorator Send runs first; only fill unset fields so later fluent
    With* (outer) wins over earlier With* (inner). }
  if FRequestOptions.HasTimeout and (not LMerged.HasTimeout) then
  begin
    LMerged.TimeoutMs := FRequestOptions.TimeoutMs;
    LMerged.HasTimeout := True;
  end;
  if FRequestOptions.HasMaxRedirects and (not LMerged.HasMaxRedirects) then
  begin
    LMerged.MaxRedirects := FRequestOptions.MaxRedirects;
    LMerged.HasMaxRedirects := True;
  end;
  if FRequestOptions.HasFollowRedirects and (not LMerged.HasFollowRedirects) then
  begin
    LMerged.FollowRedirects := FRequestOptions.FollowRedirects;
    LMerged.HasFollowRedirects := True;
  end;
  if FRequestOptions.HasCancelToken and (not LMerged.HasCancelToken) then
  begin
    LMerged.CancelToken := FRequestOptions.CancelToken;
    LMerged.HasCancelToken := True;
  end;
  LReqWithOpts.SetRequestOptions(LMerged);
end;

function TOptionsOverrideClient.Send(const AReq: IHttpRequest): IHttpResponse;
begin
  ApplyOptions(AReq);
  Result := inherited Send(AReq);
end;

{ TRetryClient }

constructor TRetryClient.Create(const AInner: IHttpClient;
  const AMaxRetries: Int32);
begin
  inherited Create(AInner);
  if AMaxRetries < 0 then
    raise EHttpError.Create(hekArgument, 'Retry count must not be negative');
  FMaxRetries := AMaxRetries;
end;

function TRetryClient.RebindInner(const AInner: IHttpClient): IHttpClient;
begin
  Result := TRetryClient.Create(AInner, FMaxRetries);
end;

function CloneRetryRequest(const AReq: IHttpRequest;
  const ABodyBytes: TBytes; const AHasBody: Boolean): IHttpRequest;
var
  LHeaders: IHttpHeaders;
  LBody: IReader;
  LOpts: IHttpRequestWithOptions;
  LLen: Int64;
begin
  if (AReq.Headers <> nil) then
    LHeaders := AReq.Headers.Clone
  else
    LHeaders := NewHttpHeaders;
  if AHasBody then
  begin
    LBody := CreateBytesStreamFrom(ABodyBytes);
    LLen := Int64(Length(ABodyBytes));
    { Snapshotting makes length known: drop chunked TE and publish CL. }
    if LHeaders.Has('transfer-encoding') then
      LHeaders.Remove('transfer-encoding');
    LHeaders.SetHeader('content-length', IntToStr(LLen));
  end
  else
  begin
    LBody := nil;
    LLen := 0;
  end;
  Result := THttpRequest.Create(AReq.Method, AReq.Url, AReq.Version,
    LHeaders, LBody, LLen);
  if Supports(AReq, IHttpRequestWithOptions, LOpts) then
    (Result as IHttpRequestWithOptions).SetRequestOptions(LOpts.RequestOptions);
end;

function HttpStatusIsRetryable(const AStatus: THttpStatus): Boolean;
begin
  { 429 Too Many Requests + entire 5xx class. Other 4xx stay terminal. }
  Result := (AStatus = HTTP_STATUS_TOO_MANY_REQUESTS) or
    ((AStatus >= THttpStatus(500)) and (AStatus <= THttpStatus(599)));
end;

function TryParseHttpDateUnix(const ADate: string; out AUnix: Int64): Boolean;
{ IMF-fix preferred: "Sun, 06 Nov 1994 08:49:37 GMT". Private to client;
  do not depend on static. Boolean distinguishes parse failure from epoch 0. }
const
  MONTH_NAMES: array[1..12] of string = (
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
var
  LLen, LPos, LMonth, LI: Integer;
  LDay, LYear, LHour, LMinute, LSecond: Integer;
  LMonthStr: string;
  LDT: TOffsetDateTime;
begin
  Result := False;
  AUnix := 0;
  LLen := Length(ADate);
  if LLen < 29 then
    Exit;
  LPos := 6; { first digit of DD }
  if (LPos + 1 > LLen) then
    Exit;
  if (ADate[LPos] < '0') or (ADate[LPos] > '9') or
     (ADate[LPos + 1] < '0') or (ADate[LPos + 1] > '9') then
    Exit;
  LDay := (Ord(ADate[LPos]) - Ord('0')) * 10 +
    (Ord(ADate[LPos + 1]) - Ord('0'));
  Inc(LPos, 3); { skip DD and following SP -> Mon }
  if (LPos + 2 > LLen) then
    Exit;
  LMonthStr := System.Copy(ADate, LPos, 3);
  LMonth := 0;
  for LI := 1 to 12 do
    if LMonthStr = MONTH_NAMES[LI] then
    begin
      LMonth := LI;
      Break;
    end;
  if LMonth = 0 then
    Exit;
  Inc(LPos, 4); { Mon + SP -> YYYY }
  if (LPos + 3 > LLen) then
    Exit;
  LYear := (Ord(ADate[LPos]) - Ord('0')) * 1000
    + (Ord(ADate[LPos + 1]) - Ord('0')) * 100
    + (Ord(ADate[LPos + 2]) - Ord('0')) * 10
    + (Ord(ADate[LPos + 3]) - Ord('0'));
  Inc(LPos, 5); { YYYY + SP -> HH }
  if (LPos + 7 > LLen) then
    Exit;
  LHour := (Ord(ADate[LPos]) - Ord('0')) * 10 +
    (Ord(ADate[LPos + 1]) - Ord('0'));
  LMinute := (Ord(ADate[LPos + 3]) - Ord('0')) * 10 +
    (Ord(ADate[LPos + 4]) - Ord('0'));
  LSecond := (Ord(ADate[LPos + 6]) - Ord('0')) * 10 +
    (Ord(ADate[LPos + 7]) - Ord('0'));
  try
    LDT := TOffsetDateTime.Create(
      TNaiveDateTime.Create(LYear, LMonth, LDay, LHour, LMinute, LSecond),
      TUtcOffset.UTC);
    AUnix := LDT.ToUnixSeconds;
    Result := True;
  except
    Result := False;
    AUnix := 0;
  end;
end;

function TryHttpParseRetryAfterMs(const AHeaders: IHttpHeaders;
  out ADelayMs: Int64): Boolean;
var
  LRaw: string;
  LSec: Int64;
  LUnix: Int64;
  LNow: Int64;
  LDelaySec: Int64;
begin
  Result := False;
  ADelayMs := 0;
  if AHeaders = nil then
    Exit;
  LRaw := Trim(AHeaders.Get('retry-after'));
  if LRaw = '' then
    Exit;
  { Prefer delta-seconds; else IMF-fix HTTP-date. Both capped at 60s. }
  if TryStrToInt64(LRaw, LSec) then
  begin
    if LSec < 0 then
      Exit;
    if LSec > 60 then
      LSec := 60;
    ADelayMs := LSec * 1000;
    Result := True;
    Exit;
  end;
  if not TryParseHttpDateUnix(LRaw, LUnix) then
    Exit;
  LNow := DateTimeToUnix(DateTimeUtcNow);
  LDelaySec := LUnix - LNow;
  if LDelaySec < 0 then
    LDelaySec := 0;
  if LDelaySec > 60 then
    LDelaySec := 60;
  ADelayMs := LDelaySec * 1000;
  Result := True;
end;

function HttpRetryBackoffMs(const AAttempt: Int32): Int64;
begin
  { AAttempt is 1-based after first failure: 100, 200, 400, ... cap 5s. }
  if AAttempt <= 0 then
    Exit(100);
  Result := Int64(100) shl (AAttempt - 1);
  if Result > 5000 then
    Result := 5000;
end;

procedure HttpRetrySleepMs(const ADelayMs: Int64;
  const ACancel: IHttpCancelToken);
var
  LRemaining: Int64;
  LSlice: Int64;
begin
  if ADelayMs <= 0 then
    Exit;
  LRemaining := ADelayMs;
  while LRemaining > 0 do
  begin
    HttpThrowIfCanceled(ACancel);
    LSlice := LRemaining;
    if LSlice > 100 then
      LSlice := 100;
    platform_thread_sleep_ns(UInt64(LSlice) * 1000000);
    Dec(LRemaining, LSlice);
  end;
  HttpThrowIfCanceled(ACancel);
end;

function TRetryClient.Send(const AReq: IHttpRequest): IHttpResponse;
var
  LAttempt: Int32;
  LBackoffMs: Int64;
  LBodyBytes: TBytes;
  LHasBody: Boolean;
  LReq: IHttpRequest;
  LBodyStream: IStream;
  LRetryAfterMs: Int64;
begin
  { Non-idempotent requests never enter the retry loop (matches H1/H2 pool). }
  if (AReq = nil) or (not HttpIsRetrySafeRequest(AReq)) or (FMaxRetries <= 0) then
  begin
    Result := inherited Send(AReq);
    Exit;
  end;

  { Snapshot body once: each Send owns/closes its body, so rewind alone is not enough.
     ContentLength < 0 (H1 chunked) also has a body that must be replayable. }
  LHasBody := (AReq.Body <> nil) and (AReq.ContentLength <> 0);
  if LHasBody then
  begin
    if not Supports(AReq.Body, IStream, LBodyStream) then
    begin
      Result := inherited Send(AReq);
      Exit;
    end;
    LBodyBytes := nextpas.core.io.ReadAll(AReq.Body);
    CloseRequestBodyIgnoringErrors(AReq.Body);
  end
  else
    LBodyBytes := nil;

  LAttempt := 0;
  while True do
  begin
    if LHasBody then
      LReq := CloneRetryRequest(AReq, LBodyBytes, True)
    else
      LReq := AReq;
    try
      Result := inherited Send(LReq);
      if (Result = nil) or (not HttpStatusIsRetryable(Result.StatusCode)) then
        Exit;
      if LAttempt >= FMaxRetries then
        Exit;
      if TryHttpParseRetryAfterMs(Result.Headers, LRetryAfterMs) then
        LBackoffMs := LRetryAfterMs
      else
        LBackoffMs := HttpRetryBackoffMs(LAttempt + 1);
      HttpReleaseResponseBody(Result);
    except
      on E: Exception do
      begin
        if (not HttpErrorIsRetryable(E)) or (LAttempt >= FMaxRetries) then
          raise;
        LBackoffMs := HttpRetryBackoffMs(LAttempt + 1);
      end;
    end;
    Inc(LAttempt);
    HttpRetrySleepMs(LBackoffMs, RequestCancelToken(AReq));
  end;
end;

end.
