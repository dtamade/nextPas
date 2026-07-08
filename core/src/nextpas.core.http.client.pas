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
    function DoBodyRequest(const AMethod: THttpMethod;
      const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
  public
    constructor Create(const AOptions: THttpClientOptions); overload;
    constructor Create(const ATransport: IHttpTransport;
      const AOptions: THttpClientOptions); overload;
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
    function SendStreaming(const AMethod: THttpMethod; const AUrl: string;
      const AContentType: string; const ABody: IReader;
      const AContentLength: Int64): IHttpResponse;
    function WithBasicAuth(const AUsername, APassword: string): IHttpClient;
    function WithBearerAuth(const AToken: string): IHttpClient;
    function WithHeader(const AName, AValue: string): IHttpClient;
    function WithTimeout(const ATimeoutMs: Int64): IHttpClient;
    function WithMaxRedirects(const AMaxRedirects: Int32): IHttpClient;
    function WithFollowRedirects(const AFollow: Boolean): IHttpClient;
    function WithRetry(const AMaxRetries: Int32): IHttpClient;
  end;

  { Decorator that adds Authorization header to every request }
  TAuthClient = class(TInterfacedObject, IHttpClient)
  private
    FInner: IHttpClient;
    FAuthHeader: string;
    function DoBodyRequest(const AMethod: THttpMethod;
      const AUrl, AContentType, ABody: string): IHttpResponse;
  public
    constructor Create(const AInner: IHttpClient; const AAuthHeader: string);
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
    function SendStreaming(const AMethod: THttpMethod; const AUrl: string;
      const AContentType: string; const ABody: IReader;
      const AContentLength: Int64): IHttpResponse;
    function WithBasicAuth(const AUsername, APassword: string): IHttpClient;
    function WithBearerAuth(const AToken: string): IHttpClient;
    function WithHeader(const AName, AValue: string): IHttpClient;
    function WithTimeout(const ATimeoutMs: Int64): IHttpClient;
    function WithMaxRedirects(const AMaxRedirects: Int32): IHttpClient;
    function WithFollowRedirects(const AFollow: Boolean): IHttpClient;
    function WithRetry(const AMaxRetries: Int32): IHttpClient;
  end;

  { Decorator that adds an arbitrary header to every request }
  THeaderClient = class(TInterfacedObject, IHttpClient)
  private
    FInner: IHttpClient;
    FHeaderName: string;
    FHeaderValue: string;
    procedure InjectHeader(const AReq: IHttpRequest);
    function DoBodyRequest(const AMethod: THttpMethod;
      const AUrl, AContentType, ABody: string): IHttpResponse;
  public
    constructor Create(const AInner: IHttpClient;
      const AHeaderName, AHeaderValue: string);
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
    function SendStreaming(const AMethod: THttpMethod; const AUrl: string;
      const AContentType: string; const ABody: IReader;
      const AContentLength: Int64): IHttpResponse;
    function WithBasicAuth(const AUsername, APassword: string): IHttpClient;
    function WithBearerAuth(const AToken: string): IHttpClient;
    function WithHeader(const AName, AValue: string): IHttpClient;
    function WithTimeout(const ATimeoutMs: Int64): IHttpClient;
    function WithMaxRedirects(const AMaxRedirects: Int32): IHttpClient;
    function WithFollowRedirects(const AFollow: Boolean): IHttpClient;
    function WithRetry(const AMaxRetries: Int32): IHttpClient;
  end;

  { Decorator that overrides per-request options (timeout, redirect behavior) }
  TOptionsOverrideClient = class(TInterfacedObject, IHttpClient)
  private
    FInner: IHttpClient;
    FRequestOptions: THttpRequestOptions;
    procedure ApplyOptions(const AReq: IHttpRequest);
    function DoBodyRequest(const AMethod: THttpMethod;
      const AUrl, AContentType, ABody: string): IHttpResponse;
  public
    constructor Create(const AInner: IHttpClient;
      const ARequestOptions: THttpRequestOptions);
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
    function SendStreaming(const AMethod: THttpMethod; const AUrl: string;
      const AContentType: string; const ABody: IReader;
      const AContentLength: Int64): IHttpResponse;
    function WithBasicAuth(const AUsername, APassword: string): IHttpClient;
    function WithBearerAuth(const AToken: string): IHttpClient;
    function WithHeader(const AName, AValue: string): IHttpClient;
    function WithTimeout(const ATimeoutMs: Int64): IHttpClient;
    function WithMaxRedirects(const AMaxRedirects: Int32): IHttpClient;
    function WithFollowRedirects(const AFollow: Boolean): IHttpClient;
    function WithRetry(const AMaxRetries: Int32): IHttpClient;
  end;

  { Decorator that retries failed requests with exponential backoff }
  TRetryClient = class(TInterfacedObject, IHttpClient)
  private
    FInner: IHttpClient;
    FMaxRetries: Int32;
    function DoBodyRequest(const AMethod: THttpMethod;
      const AUrl, AContentType, ABody: string): IHttpResponse;
  public
    constructor Create(const AInner: IHttpClient; const AMaxRetries: Int32);
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
    function SendStreaming(const AMethod: THttpMethod; const AUrl: string;
      const AContentType: string; const ABody: IReader;
      const AContentLength: Int64): IHttpResponse;
    function WithBasicAuth(const AUsername, APassword: string): IHttpClient;
    function WithBearerAuth(const AToken: string): IHttpClient;
    function WithHeader(const AName, AValue: string): IHttpClient;
    function WithTimeout(const ATimeoutMs: Int64): IHttpClient;
    function WithMaxRedirects(const AMaxRetries: Int32): IHttpClient;
    function WithFollowRedirects(const AFollow: Boolean): IHttpClient;
    function WithRetry(const AMaxRetries: Int32): IHttpClient;
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
{** @desc Raise EHttpError if response status is not 2xx (200-299). Returns AResp for chaining. }
function HttpEnsureSuccess(const AResp: IHttpResponse): IHttpResponse;
{** @desc GET url, ensure 2xx, return body as string. Raises on non-2xx. }
function HttpGetString(const AClient: IHttpClient; const AUrl: string): string;
{** @desc GET url, ensure 2xx, return body as TBytes. Raises on non-2xx. }
function HttpGetBytes(const AClient: IHttpClient; const AUrl: string): TBytes;
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
function ExtractCharsetFromContentType(const AContentType: string): string;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.fs,
  nextpas.core.io,
  nextpas.core.io.memory,
  nextpas.core.text.conv,
  nextpas.core.encoding,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.form,
  nextpas.core.http.impl.registry,
  nextpas.core.platform.thread;

procedure CheckDownloadArgs(const AClient: IHttpClient; const AUrl: string);
begin
  if AClient = nil then
    raise EArgumentError.Create('HTTP download client is nil');
  if AUrl = '' then
    raise EArgumentError.Create('HTTP download URL is empty');
end;

procedure CheckDownloadResponse(const AResp: IHttpResponse; const AUrl: string);
begin
  if AResp = nil then
    raise EHttpError.Create('HTTP download returned no response: ' + AUrl);
  if (AResp.StatusCode < 200) or (AResp.StatusCode >= 300) then
    raise EHttpError.Create('HTTP download failed with status ' +
      IntToStr(Int64(AResp.StatusCode)) + ': ' + AUrl);
end;

procedure ValidateClientOptions(const AOptions: THttpClientOptions);
begin
  if AOptions.Timeout < 0 then
    raise EArgumentError.Create('HTTP client timeout must not be negative');
  if AOptions.MaxRedirects < 0 then
    raise EArgumentError.Create('HTTP client max redirects must not be negative');
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

function MergeRedirectPath(const ABasePath, ATargetPath: string): string;
var
  LI: SizeInt;
  LSlashPos: SizeInt;
begin
  if ATargetPath = '' then
    Exit(ABasePath);
  if ATargetPath[1] = '/' then
    Exit(ATargetPath);

  LSlashPos := 0;
  for LI := Length(ABasePath) downto 1 do
    if ABasePath[LI] = '/' then
    begin
      LSlashPos := LI;
      Break;
    end;

  if LSlashPos > 0 then
    Result := System.Copy(ABasePath, 1, LSlashPos) + ATargetPath
  else
    Result := '/' + ATargetPath;
end;

function StartsWith(const AValue, APrefix: string): Boolean;
begin
  Result := (Length(AValue) >= Length(APrefix)) and
    (System.Copy(AValue, 1, Length(APrefix)) = APrefix);
end;

function HasRedirectQueryDelimiter(const ALocation: string): Boolean;
var
  LI: SizeInt;
begin
  for LI := 1 to Length(ALocation) do
  begin
    case ALocation[LI] of
      '?':
        Exit(True);
      '#':
        Exit(False);
    end;
  end;
  Result := False;
end;

function RedirectAbsoluteScheme(const ALocation: string): string;
var
  LSchemeEnd: SizeInt;
  LI: SizeInt;
begin
  LSchemeEnd := 0;
  for LI := 1 to Length(ALocation) do
  begin
    case ALocation[LI] of
      ':':
      begin
        LSchemeEnd := LI;
        Break;
      end;
      '/', '?', '#':
        Break;
    end;
  end;
  if LSchemeEnd <= 1 then
    Exit('');
  Result := LowerCase(System.Copy(ALocation, 1, LSchemeEnd - 1));
end;

function RedirectAuthorityPortIsValid(const ALocation: string): Boolean;
var
  LAuthorityStart: SizeInt;
  LAuthorityEnd: SizeInt;
  LAuthority: string;
  LAtPos: SizeInt;
  LColonPos: SizeInt;
  LBracketPos: SizeInt;
  LPortStr: string;
  LPortValue: Int64;
  LI: SizeInt;
begin
  Result := True;
  LAuthorityStart := Pos('://', ALocation);
  if LAuthorityStart = 0 then
    Exit;
  Inc(LAuthorityStart, 3);

  LAuthorityEnd := Length(ALocation) + 1;
  for LI := LAuthorityStart to Length(ALocation) do
    if (ALocation[LI] = '/') or (ALocation[LI] = '?') or
      (ALocation[LI] = '#') then
    begin
      LAuthorityEnd := LI;
      Break;
    end;

  LAuthority := System.Copy(ALocation, LAuthorityStart,
    LAuthorityEnd - LAuthorityStart);
  if LAuthority = '' then
    Exit;

  LAtPos := Pos('@', LAuthority);
  if LAtPos > 0 then
    Delete(LAuthority, 1, LAtPos);
  if LAuthority = '' then
    Exit;

  if LAuthority[1] = '[' then
  begin
    LBracketPos := Pos(']', LAuthority);
    if LBracketPos = 0 then
    begin
      Result := False;
      Exit;
    end;
    if LBracketPos = Length(LAuthority) then
      Exit;
    if LAuthority[LBracketPos + 1] <> ':' then
    begin
      Result := False;
      Exit;
    end;
    LPortStr := System.Copy(LAuthority, LBracketPos + 2,
      Length(LAuthority) - LBracketPos - 1);
  end
  else
  begin
    LColonPos := Pos(':', LAuthority);
    if LColonPos = 0 then
      Exit;
    LPortStr := System.Copy(LAuthority, LColonPos + 1,
      Length(LAuthority) - LColonPos);
  end;

  Result := (LPortStr <> '') and TryStrToInt64(LPortStr, LPortValue) and
    (LPortValue >= 0) and (LPortValue <= 65535);
end;

function ParseRedirectAuthorityUrl(const AUrl, AScheme: string): TUrl;
begin
  Result := TUrl.Parse(AUrl);
  Result.Scheme := AScheme;
  if Result.Host = '' then
    raise EHttpError.Create('redirect URL host is empty');
  if not RedirectAuthorityPortIsValid(AUrl) then
    raise EHttpError.Create('redirect URL port is invalid');
end;

function DefaultPortForScheme(const AScheme: string): UInt16;
var
  LScheme: string;
begin
  LScheme := LowerCase(AScheme);
  if LScheme = 'http' then
    Result := 80
  else if LScheme = 'https' then
    Result := 443
  else
    Result := 0;
end;

function EffectiveAuthorityPort(const AUrl: TUrl): UInt16;
begin
  if AUrl.Port <> 0 then
    Result := AUrl.Port
  else
    Result := DefaultPortForScheme(AUrl.Scheme);
end;

function IsRedirectSameAuthority(const AInitialUrl, ARedirectUrl: TUrl): Boolean;
begin
  Result := (AInitialUrl.Host <> '') and (ARedirectUrl.Host <> '') and
    (LowerCase(AInitialUrl.Host) = LowerCase(ARedirectUrl.Host)) and
    (EffectiveAuthorityPort(AInitialUrl) = EffectiveAuthorityPort(ARedirectUrl));
end;

function IsRedirectSameOrigin(const AInitialUrl, ARedirectUrl: TUrl): Boolean;
begin
  Result := IsRedirectSameAuthority(AInitialUrl, ARedirectUrl) and
    (LowerCase(AInitialUrl.Scheme) = LowerCase(ARedirectUrl.Scheme));
end;

function MethodForGetStyleRedirect(const AMethod: THttpMethod): THttpMethod;
begin
  if AMethod = hmHead then
    Result := hmHead
  else
    Result := hmGet;
end;

function BufferedBodyRequest(const AMethod: THttpMethod; const AUrl: TUrl;
  const AContentType: string; const ABody: IReader): IHttpRequest;
var
  LHeaders: IHttpHeaders;
  LBody: TBytes;
begin
  LHeaders := NewHttpHeaders;
  if AContentType <> '' then
    LHeaders.SetHeader('content-type', AContentType);

  if ABody <> nil then
  begin
    try
      LBody := nextpas.core.io.ReadAll(ABody);
    except
      on E: Exception do
      begin
        CloseRequestBodyIgnoringErrors(ABody);
        raise;
      end;
    end;
    CloseRequestBody(ABody);
  end
  else
    LBody := nil;

  Result := NewRequest(AMethod, AUrl, LHeaders, LBody);
end;

function BufferedBodyRequest(const AMethod: THttpMethod; const AUrl: string;
  const AContentType, ABody: string): IHttpRequest; overload;
var
  LHeaders: IHttpHeaders;
begin
  LHeaders := NewHttpHeaders;
  if AContentType <> '' then
    LHeaders.SetHeader('content-type', AContentType);
  Result := NewRequest(AMethod, AUrl, LHeaders, ABody);
end;

function BufferedBodyRequest(const AMethod: THttpMethod; const AUrl,
  AContentType: string; const ABody: TBytes): IHttpRequest; overload;
var
  LHeaders: IHttpHeaders;
begin
  LHeaders := NewHttpHeaders;
  if AContentType <> '' then
    LHeaders.SetHeader('content-type', AContentType);
  Result := NewRequest(AMethod, AUrl, LHeaders, ABody);
end;

function RedirectHeadersFor(const AReq: IHttpRequest; const AInitialUrl,
  ARedirectUrl: TUrl; const AIncludeBody: Boolean): IHttpHeaders;
begin
  if (AReq <> nil) and (AReq.Headers <> nil) then
    Result := AReq.Headers.Clone
  else
    Result := NewHttpHeaders;

  if not IsRedirectSameAuthority(AInitialUrl, ARedirectUrl) then
    Result.Remove('host');
  if not AIncludeBody then
  begin
    Result.Remove('content-length');
    Result.Remove('transfer-encoding');
  end;

  if not IsRedirectSameOrigin(AInitialUrl, ARedirectUrl) then
  begin
    Result.Remove('authorization');
    Result.Remove('proxy-authorization');
    Result.Remove('www-authenticate');
    Result.Remove('cookie');
    Result.Remove('cookie2');
  end;
end;

function CaptureRedirectBodyPosition(const AReq: IHttpRequest;
  out ABodyStream: IStream; out AStartPosition: Int64): Boolean;
begin
  ABodyStream := nil;
  AStartPosition := 0;
  if (AReq = nil) or (AReq.Body = nil) then
    Exit(False);
  Result := Supports(AReq.Body, IStream, ABodyStream);
  if Result then
    AStartPosition := ABodyStream.Position;
end;

procedure RewindRedirectBody(const AReq: IHttpRequest; const ABodyStream: IStream;
  const AStartPosition: Int64);
begin
  if (AReq.Body = nil) or (AReq.ContentLength = 0) then
    Exit;
  if ABodyStream = nil then
    raise EHttpError.Create('redirect request body is not replayable');
  ABodyStream.Position := AStartPosition;
end;

procedure ReleaseResponseBody(const AResp: IHttpResponse);
var
  LBody: IReader;
  LReadCloser: IReadCloser;
  LCloser: ICloser;
  LStream: IStream;
  LBuf: array[0..4095] of Byte;
begin
  if (AResp = nil) or (AResp.Body = nil) then
    Exit;
  LBody := AResp.Body;

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

procedure ReleaseResponseBodyIgnoringErrors(const AResp: IHttpResponse);
begin
  try
    ReleaseResponseBody(AResp);
  except
    on E: Exception do ;
  end;
end;

procedure RemoveLastPathSegment(var AOutput: string);
var
  LI: SizeInt;
begin
  for LI := Length(AOutput) downto 1 do
    if AOutput[LI] = '/' then
    begin
      SetLength(AOutput, LI - 1);
      Exit;
    end;
  AOutput := '';
end;

procedure MoveFirstPathSegment(var AInput, AOutput: string);
var
  LI: SizeInt;
  LSegmentLen: SizeInt;
begin
  if AInput = '' then
    Exit;

  LSegmentLen := Length(AInput);
  if AInput[1] = '/' then
  begin
    for LI := 2 to Length(AInput) do
      if AInput[LI] = '/' then
      begin
        LSegmentLen := LI - 1;
        Break;
      end;
  end
  else
  begin
    for LI := 1 to Length(AInput) do
      if AInput[LI] = '/' then
      begin
        LSegmentLen := LI - 1;
        Break;
      end;
  end;

  AOutput := AOutput + System.Copy(AInput, 1, LSegmentLen);
  Delete(AInput, 1, LSegmentLen);
end;

function NormalizeRedirectPath(const APath: string): string;
var
  LInput: string;
begin
  LInput := APath;
  Result := '';
  while LInput <> '' do
  begin
    if StartsWith(LInput, '../') then
      Delete(LInput, 1, 3)
    else if StartsWith(LInput, './') then
      Delete(LInput, 1, 2)
    else if StartsWith(LInput, '/./') then
      Delete(LInput, 2, 2)
    else if LInput = '/.' then
      LInput := '/'
    else if StartsWith(LInput, '/../') then
    begin
      Delete(LInput, 2, 3);
      RemoveLastPathSegment(Result);
    end
    else if LInput = '/..' then
    begin
      LInput := '/';
      RemoveLastPathSegment(Result);
    end
    else if (LInput = '.') or (LInput = '..') then
      LInput := ''
    else
      MoveFirstPathSegment(LInput, Result);
  end;
end;

function ResolveRedirectUrl(const ABaseUrl: TUrl; const ALocation: string): TUrl;
var
  LTarget: TUrl;
  LHasQueryDelimiter: Boolean;
  LScheme: string;
begin
  LScheme := RedirectAbsoluteScheme(ALocation);
  if LScheme <> '' then
  begin
    if (LScheme <> 'http') and (LScheme <> 'https') then
      raise EHttpError.Create('unsupported redirect URL scheme: ' + LScheme);
    Exit(ParseRedirectAuthorityUrl(ALocation, LScheme));
  end;
  if (Length(ALocation) >= 2) and (ALocation[1] = '/') and (ALocation[2] = '/') then
  begin
    if ABaseUrl.Scheme = '' then
      raise EHttpError.Create('network-path redirect requires base URL scheme');
    Exit(ParseRedirectAuthorityUrl(ABaseUrl.Scheme + ':' + ALocation,
      ABaseUrl.Scheme));
  end;

  Result := ABaseUrl;
  LHasQueryDelimiter := HasRedirectQueryDelimiter(ALocation);
  LTarget := TUrl.ParseRequestTarget(ALocation);
  if LTarget.Path <> '' then
  begin
    Result.Path := NormalizeRedirectPath(MergeRedirectPath(Result.Path, LTarget.Path));
    Result.RawQuery := LTarget.RawQuery;
  end
  else if LHasQueryDelimiter then
    Result.RawQuery := LTarget.RawQuery;
  Result.Fragment := LTarget.Fragment;
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
  LFollowRedirects: Boolean;
begin
  LUrl := AReq.Url;
  CaptureRedirectBodyPosition(AReq, LBodyStream, LBodyStartPosition);
  LResp := FTransport.RoundTrip(AReq);
  if LResp = nil then
    raise EHttpError.Create('HTTP transport returned no response');

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
    if ARedirectsLeft <= 0 then
    begin
      ReleaseResponseBodyIgnoringErrors(LResp);
      raise EHttpError.Create('too many redirects');
    end;

    LRespHeaders := LResp.Headers;
    if LRespHeaders = nil then
    begin
      ReleaseResponseBodyIgnoringErrors(LResp);
      raise EHttpError.Create('redirect with no response headers');
    end;

    LLocations := LRespHeaders.GetAll('location');
    if Length(LLocations) > 1 then
    begin
      ReleaseResponseBodyIgnoringErrors(LResp);
      raise EHttpError.Create('redirect with duplicate Location headers');
    end;

    if Length(LLocations) = 1 then
      LLocation := LLocations[0]
    else
      LLocation := '';
    if LLocation = '' then
    begin
      ReleaseResponseBodyIgnoringErrors(LResp);
      raise EHttpError.Create('redirect with no Location header');
    end;

    try
      LNewUrl := ResolveRedirectUrl(LUrl, LLocation);
    except
      ReleaseResponseBodyIgnoringErrors(LResp);
      raise;
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
      RewindRedirectBody(AReq, LBodyStream, LBodyStartPosition);
      LNewHeaders := RedirectHeadersFor(AReq, LUrl, LNewUrl, True);
      LNewReq := THttpRequest.Create(AReq.Method, LNewUrl, hvHttp11,
        LNewHeaders, AReq.Body, AReq.ContentLength);
    end;

    Result := DoRequest(LNewReq, ARedirectsLeft - 1, ARequestBodyCloseAttempted);
  end
  else
    Result := LResp;
end;

function THttpClient.DoBodyRequest(const AMethod: THttpMethod;
  const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
var
  LUrl: TUrl;
  LReq: IHttpRequest;
begin
  LUrl := TUrl.Parse(AUrl);
  LReq := BufferedBodyRequest(AMethod, LUrl, AContentType, ABody);
  Result := Send(LReq);
end;

function THttpClient.Send(const AReq: IHttpRequest): IHttpResponse;
var
  LRequestBodyCloseAttempted: Boolean;
  LResp: IHttpResponse;
  LReqOpts: IHttpRequestWithOptions;
  LMaxRedirects: Int32;
begin
  if AReq = nil then
    raise EArgumentError.Create('HTTP request is nil');
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

function THttpClient.Post(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
begin
  Result := DoBodyRequest(hmPost, AUrl, AContentType, ABody);
end;

function THttpClient.Post(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
begin
  Result := Send(BufferedBodyRequest(hmPost, AUrl, AContentType, ABody));
end;

function THttpClient.Post(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
begin
  Result := Send(BufferedBodyRequest(hmPost, AUrl, AContentType, ABody));
end;

function THttpClient.Put(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
begin
  Result := DoBodyRequest(hmPut, AUrl, AContentType, ABody);
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

function THttpClient.Delete(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
begin
  Result := DoBodyRequest(hmDelete, AUrl, AContentType, ABody);
end;

function THttpClient.Delete(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
begin
  Result := Send(BufferedBodyRequest(hmDelete, AUrl, AContentType, ABody));
end;

function THttpClient.Delete(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
begin
  Result := Send(BufferedBodyRequest(hmDelete, AUrl, AContentType, ABody));
end;

function THttpClient.Patch(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
begin
  Result := DoBodyRequest(hmPatch, AUrl, AContentType, ABody);
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
  LReq: IHttpRequest;
begin
  LReq := NewStreamingRequest(AMethod, AUrl, AContentType, ABody,
    AContentLength);
  Result := Send(LReq);
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

{ TAuthClient }

constructor TAuthClient.Create(const AInner: IHttpClient; const AAuthHeader: string);
begin
  FInner := AInner;
  FAuthHeader := AAuthHeader;
end;

function TAuthClient.Send(const AReq: IHttpRequest): IHttpResponse;
begin
  AReq.Headers.SetHeader('authorization', FAuthHeader);
  Result := FInner.Send(AReq);
end;

procedure TAuthClient.CloseIdleConnections;
begin
  FInner.CloseIdleConnections;
end;

function TAuthClient.Get(const AUrl: string): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmGet, AUrl, '', '');
  LReq.Headers.SetHeader('authorization', FAuthHeader);
  Result := FInner.Send(LReq);
end;

function TAuthClient.DoBodyRequest(const AMethod: THttpMethod;
  const AUrl, AContentType, ABody: string): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(AMethod, AUrl, AContentType, ABody);
  LReq.Headers.SetHeader('authorization', FAuthHeader);
  Result := FInner.Send(LReq);
end;

function TAuthClient.Post(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPost, TUrl.Parse(AUrl), AContentType, ABody);
  LReq.Headers.SetHeader('authorization', FAuthHeader);
  Result := FInner.Send(LReq);
end;

function TAuthClient.Post(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
begin
  Result := DoBodyRequest(hmPost, AUrl, AContentType, ABody);
end;

function TAuthClient.Post(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPost, AUrl, AContentType, ABody);
  LReq.Headers.SetHeader('authorization', FAuthHeader);
  Result := FInner.Send(LReq);
end;

function TAuthClient.Put(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPut, TUrl.Parse(AUrl), AContentType, ABody);
  LReq.Headers.SetHeader('authorization', FAuthHeader);
  Result := FInner.Send(LReq);
end;

function TAuthClient.Put(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
begin
  Result := DoBodyRequest(hmPut, AUrl, AContentType, ABody);
end;

function TAuthClient.Put(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPut, AUrl, AContentType, ABody);
  LReq.Headers.SetHeader('authorization', FAuthHeader);
  Result := FInner.Send(LReq);
end;

function TAuthClient.Delete(const AUrl: string): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmDelete, AUrl, '', '');
  LReq.Headers.SetHeader('authorization', FAuthHeader);
  Result := FInner.Send(LReq);
end;

function TAuthClient.Delete(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmDelete, TUrl.Parse(AUrl), AContentType, ABody);
  LReq.Headers.SetHeader('authorization', FAuthHeader);
  Result := FInner.Send(LReq);
end;

function TAuthClient.Delete(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
begin
  Result := DoBodyRequest(hmDelete, AUrl, AContentType, ABody);
end;

function TAuthClient.Delete(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmDelete, AUrl, AContentType, ABody);
  LReq.Headers.SetHeader('authorization', FAuthHeader);
  Result := FInner.Send(LReq);
end;

function TAuthClient.Patch(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPatch, TUrl.Parse(AUrl), AContentType, ABody);
  LReq.Headers.SetHeader('authorization', FAuthHeader);
  Result := FInner.Send(LReq);
end;

function TAuthClient.Patch(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
begin
  Result := DoBodyRequest(hmPatch, AUrl, AContentType, ABody);
end;

function TAuthClient.Patch(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPatch, AUrl, AContentType, ABody);
  LReq.Headers.SetHeader('authorization', FAuthHeader);
  Result := FInner.Send(LReq);
end;

function TAuthClient.Head(const AUrl: string): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmHead, AUrl, '', '');
  LReq.Headers.SetHeader('authorization', FAuthHeader);
  Result := FInner.Send(LReq);
end;

function TAuthClient.Options(const AUrl: string): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmOptions, AUrl, '', '');
  LReq.Headers.SetHeader('authorization', FAuthHeader);
  Result := FInner.Send(LReq);
end;

function TAuthClient.PostForm(const AUrl: string; const AFields: TFormFieldArray): IHttpResponse;
begin
  Result := DoBodyRequest(hmPost, AUrl, 'application/x-www-form-urlencoded', EncodeUrlEncodedForm(AFields));
end;

function TAuthClient.PostJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
begin
  Result := DoBodyRequest(hmPost, AUrl, 'application/json', JsonStringify(ABody));
end;

function TAuthClient.PutJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
begin
  Result := DoBodyRequest(hmPut, AUrl, 'application/json', JsonStringify(ABody));
end;

function TAuthClient.PatchJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
begin
  Result := DoBodyRequest(hmPatch, AUrl, 'application/json', JsonStringify(ABody));
end;

function TAuthClient.DeleteJson(const AUrl: string; const ABody: TJsonValue): IHttpResponse;
begin
  Result := DoBodyRequest(hmDelete, AUrl, 'application/json', JsonStringify(ABody));
end;

function TAuthClient.SendStreaming(const AMethod: THttpMethod;
  const AUrl: string; const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := NewStreamingRequest(AMethod, AUrl, AContentType, ABody,
    AContentLength);
  LReq.Headers.SetHeader('authorization', FAuthHeader);
  Result := FInner.Send(LReq);
end;

function TAuthClient.WithBasicAuth(const AUsername, APassword: string): IHttpClient;
begin
  Result := TAuthClient.Create(FInner, 'Basic ' + Base64Encode(StringToUTF8Bytes(AUsername + ':' + APassword)));
end;

function TAuthClient.WithBearerAuth(const AToken: string): IHttpClient;
begin
  Result := TAuthClient.Create(FInner, 'Bearer ' + AToken);
end;

function TAuthClient.WithHeader(const AName, AValue: string): IHttpClient;
begin
  Result := THeaderClient.Create(Self, AName, AValue);
end;

function TAuthClient.WithTimeout(const ATimeoutMs: Int64): IHttpClient;
begin
  Result := TOptionsOverrideClient.Create(Self,
    Default(THttpRequestOptions).WithTimeout(ATimeoutMs));
end;

function TAuthClient.WithMaxRedirects(const AMaxRedirects: Int32): IHttpClient;
begin
  Result := TOptionsOverrideClient.Create(Self,
    Default(THttpRequestOptions).WithMaxRedirects(AMaxRedirects));
end;

function TAuthClient.WithFollowRedirects(const AFollow: Boolean): IHttpClient;
begin
  Result := TOptionsOverrideClient.Create(Self,
    Default(THttpRequestOptions).WithFollowRedirects(AFollow));
end;

function TAuthClient.WithRetry(const AMaxRetries: Int32): IHttpClient;
begin
  Result := TRetryClient.Create(Self, AMaxRetries);
end;

{ THeaderClient }

constructor THeaderClient.Create(const AInner: IHttpClient;
  const AHeaderName, AHeaderValue: string);
begin
  FInner := AInner;
  FHeaderName := AHeaderName;
  FHeaderValue := AHeaderValue;
end;

procedure THeaderClient.InjectHeader(const AReq: IHttpRequest);
begin
  AReq.Headers.SetHeader(FHeaderName, FHeaderValue);
end;

function THeaderClient.Send(const AReq: IHttpRequest): IHttpResponse;
begin
  InjectHeader(AReq);
  Result := FInner.Send(AReq);
end;

procedure THeaderClient.CloseIdleConnections;
begin
  FInner.CloseIdleConnections;
end;

function THeaderClient.Get(const AUrl: string): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmGet, AUrl, '', '');
  InjectHeader(LReq);
  Result := FInner.Send(LReq);
end;

function THeaderClient.DoBodyRequest(const AMethod: THttpMethod;
  const AUrl, AContentType, ABody: string): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(AMethod, AUrl, AContentType, ABody);
  InjectHeader(LReq);
  Result := FInner.Send(LReq);
end;

function THeaderClient.Post(const AUrl, AContentType: string;
  const ABody: IReader): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPost, TUrl.Parse(AUrl), AContentType, ABody);
  InjectHeader(LReq);
  Result := FInner.Send(LReq);
end;

function THeaderClient.Post(const AUrl, AContentType: string;
  const ABody: string): IHttpResponse;
begin
  Result := DoBodyRequest(hmPost, AUrl, AContentType, ABody);
end;

function THeaderClient.Post(const AUrl, AContentType: string;
  const ABody: TBytes): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPost, AUrl, AContentType, ABody);
  InjectHeader(LReq);
  Result := FInner.Send(LReq);
end;

function THeaderClient.Put(const AUrl, AContentType: string;
  const ABody: IReader): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPut, TUrl.Parse(AUrl), AContentType, ABody);
  InjectHeader(LReq);
  Result := FInner.Send(LReq);
end;

function THeaderClient.Put(const AUrl, AContentType: string;
  const ABody: string): IHttpResponse;
begin
  Result := DoBodyRequest(hmPut, AUrl, AContentType, ABody);
end;

function THeaderClient.Put(const AUrl, AContentType: string;
  const ABody: TBytes): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPut, AUrl, AContentType, ABody);
  InjectHeader(LReq);
  Result := FInner.Send(LReq);
end;

function THeaderClient.Delete(const AUrl: string): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmDelete, AUrl, '', '');
  InjectHeader(LReq);
  Result := FInner.Send(LReq);
end;

function THeaderClient.Delete(const AUrl, AContentType: string; const ABody: IReader): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmDelete, TUrl.Parse(AUrl), AContentType, ABody);
  InjectHeader(LReq);
  Result := FInner.Send(LReq);
end;

function THeaderClient.Delete(const AUrl, AContentType: string; const ABody: string): IHttpResponse;
begin
  Result := DoBodyRequest(hmDelete, AUrl, AContentType, ABody);
end;

function THeaderClient.Delete(const AUrl, AContentType: string; const ABody: TBytes): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmDelete, AUrl, AContentType, ABody);
  InjectHeader(LReq);
  Result := FInner.Send(LReq);
end;

function THeaderClient.Patch(const AUrl, AContentType: string;
  const ABody: IReader): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPatch, TUrl.Parse(AUrl), AContentType, ABody);
  InjectHeader(LReq);
  Result := FInner.Send(LReq);
end;

function THeaderClient.Patch(const AUrl, AContentType: string;
  const ABody: string): IHttpResponse;
begin
  Result := DoBodyRequest(hmPatch, AUrl, AContentType, ABody);
end;

function THeaderClient.Patch(const AUrl, AContentType: string;
  const ABody: TBytes): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPatch, AUrl, AContentType, ABody);
  InjectHeader(LReq);
  Result := FInner.Send(LReq);
end;

function THeaderClient.Head(const AUrl: string): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmHead, AUrl, '', '');
  InjectHeader(LReq);
  Result := FInner.Send(LReq);
end;

function THeaderClient.Options(const AUrl: string): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmOptions, AUrl, '', '');
  InjectHeader(LReq);
  Result := FInner.Send(LReq);
end;

function THeaderClient.PostForm(const AUrl: string;
  const AFields: TFormFieldArray): IHttpResponse;
begin
  Result := DoBodyRequest(hmPost, AUrl, 'application/x-www-form-urlencoded',
    EncodeUrlEncodedForm(AFields));
end;

function THeaderClient.PostJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := DoBodyRequest(hmPost, AUrl, 'application/json', JsonStringify(ABody));
end;

function THeaderClient.PutJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := DoBodyRequest(hmPut, AUrl, 'application/json', JsonStringify(ABody));
end;

function THeaderClient.PatchJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := DoBodyRequest(hmPatch, AUrl, 'application/json', JsonStringify(ABody));
end;

function THeaderClient.DeleteJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := DoBodyRequest(hmDelete, AUrl, 'application/json', JsonStringify(ABody));
end;

function THeaderClient.SendStreaming(const AMethod: THttpMethod;
  const AUrl: string; const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := NewStreamingRequest(AMethod, AUrl, AContentType, ABody,
    AContentLength);
  LReq.Headers.SetHeader(FHeaderName, FHeaderValue);
  Result := FInner.Send(LReq);
end;

function THeaderClient.WithBasicAuth(const AUsername, APassword: string): IHttpClient;
begin
  Result := TAuthClient.Create(Self, 'Basic ' + Base64Encode(StringToUTF8Bytes(AUsername + ':' + APassword)));
end;

function THeaderClient.WithBearerAuth(const AToken: string): IHttpClient;
begin
  Result := TAuthClient.Create(Self, 'Bearer ' + AToken);
end;

function THeaderClient.WithHeader(const AName, AValue: string): IHttpClient;
begin
  Result := THeaderClient.Create(Self, AName, AValue);
end;

function THeaderClient.WithTimeout(const ATimeoutMs: Int64): IHttpClient;
begin
  Result := TOptionsOverrideClient.Create(Self,
    Default(THttpRequestOptions).WithTimeout(ATimeoutMs));
end;

function THeaderClient.WithMaxRedirects(const AMaxRedirects: Int32): IHttpClient;
begin
  Result := TOptionsOverrideClient.Create(Self,
    Default(THttpRequestOptions).WithMaxRedirects(AMaxRedirects));
end;

function THeaderClient.WithFollowRedirects(const AFollow: Boolean): IHttpClient;
begin
  Result := TOptionsOverrideClient.Create(Self,
    Default(THttpRequestOptions).WithFollowRedirects(AFollow));
end;

function THeaderClient.WithRetry(const AMaxRetries: Int32): IHttpClient;
begin
  Result := TRetryClient.Create(Self, AMaxRetries);
end;

{ TOptionsOverrideClient }

constructor TOptionsOverrideClient.Create(const AInner: IHttpClient;
  const ARequestOptions: THttpRequestOptions);
begin
  FInner := AInner;
  FRequestOptions := ARequestOptions;
end;

procedure TOptionsOverrideClient.ApplyOptions(const AReq: IHttpRequest);
var
  LReqWithOpts: IHttpRequestWithOptions;
  LExisting: THttpRequestOptions;
  LMerged: THttpRequestOptions;
begin
  if not Supports(AReq, IHttpRequestWithOptions, LReqWithOpts) then
    Exit;
  LExisting := LReqWithOpts.RequestOptions;
  LMerged := LExisting;
  if FRequestOptions.HasTimeout then
  begin
    LMerged.TimeoutMs := FRequestOptions.TimeoutMs;
    LMerged.HasTimeout := True;
  end;
  if FRequestOptions.HasMaxRedirects then
  begin
    LMerged.MaxRedirects := FRequestOptions.MaxRedirects;
    LMerged.HasMaxRedirects := True;
  end;
  if FRequestOptions.HasFollowRedirects then
  begin
    LMerged.FollowRedirects := FRequestOptions.FollowRedirects;
    LMerged.HasFollowRedirects := True;
  end;
  LReqWithOpts.SetRequestOptions(LMerged);
end;

function TOptionsOverrideClient.DoBodyRequest(const AMethod: THttpMethod;
  const AUrl, AContentType, ABody: string): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(AMethod, AUrl, AContentType, ABody);
  ApplyOptions(LReq);
  Result := FInner.Send(LReq);
end;

function TOptionsOverrideClient.Send(const AReq: IHttpRequest): IHttpResponse;
begin
  ApplyOptions(AReq);
  Result := FInner.Send(AReq);
end;

procedure TOptionsOverrideClient.CloseIdleConnections;
begin
  FInner.CloseIdleConnections;
end;

function TOptionsOverrideClient.Get(const AUrl: string): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmGet, AUrl, '', '');
  ApplyOptions(LReq);
  Result := FInner.Send(LReq);
end;

function TOptionsOverrideClient.Post(const AUrl, AContentType: string;
  const ABody: IReader): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPost, TUrl.Parse(AUrl), AContentType, ABody);
  ApplyOptions(LReq);
  Result := FInner.Send(LReq);
end;

function TOptionsOverrideClient.Post(const AUrl, AContentType: string;
  const ABody: string): IHttpResponse;
begin
  Result := DoBodyRequest(hmPost, AUrl, AContentType, ABody);
end;

function TOptionsOverrideClient.Post(const AUrl, AContentType: string;
  const ABody: TBytes): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPost, AUrl, AContentType, ABody);
  ApplyOptions(LReq);
  Result := FInner.Send(LReq);
end;

function TOptionsOverrideClient.Put(const AUrl, AContentType: string;
  const ABody: IReader): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPut, TUrl.Parse(AUrl), AContentType, ABody);
  ApplyOptions(LReq);
  Result := FInner.Send(LReq);
end;

function TOptionsOverrideClient.Put(const AUrl, AContentType: string;
  const ABody: string): IHttpResponse;
begin
  Result := DoBodyRequest(hmPut, AUrl, AContentType, ABody);
end;

function TOptionsOverrideClient.Put(const AUrl, AContentType: string;
  const ABody: TBytes): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPut, AUrl, AContentType, ABody);
  ApplyOptions(LReq);
  Result := FInner.Send(LReq);
end;

function TOptionsOverrideClient.Delete(const AUrl: string): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmDelete, AUrl, '', '');
  ApplyOptions(LReq);
  Result := FInner.Send(LReq);
end;

function TOptionsOverrideClient.Delete(const AUrl, AContentType: string;
  const ABody: IReader): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmDelete, TUrl.Parse(AUrl), AContentType, ABody);
  ApplyOptions(LReq);
  Result := FInner.Send(LReq);
end;

function TOptionsOverrideClient.Delete(const AUrl, AContentType: string;
  const ABody: string): IHttpResponse;
begin
  Result := DoBodyRequest(hmDelete, AUrl, AContentType, ABody);
end;

function TOptionsOverrideClient.Delete(const AUrl, AContentType: string;
  const ABody: TBytes): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmDelete, AUrl, AContentType, ABody);
  ApplyOptions(LReq);
  Result := FInner.Send(LReq);
end;

function TOptionsOverrideClient.Patch(const AUrl, AContentType: string;
  const ABody: IReader): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPatch, TUrl.Parse(AUrl), AContentType, ABody);
  ApplyOptions(LReq);
  Result := FInner.Send(LReq);
end;

function TOptionsOverrideClient.Patch(const AUrl, AContentType: string;
  const ABody: string): IHttpResponse;
begin
  Result := DoBodyRequest(hmPatch, AUrl, AContentType, ABody);
end;

function TOptionsOverrideClient.Patch(const AUrl, AContentType: string;
  const ABody: TBytes): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPatch, AUrl, AContentType, ABody);
  ApplyOptions(LReq);
  Result := FInner.Send(LReq);
end;

function TOptionsOverrideClient.Head(const AUrl: string): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmHead, AUrl, '', '');
  ApplyOptions(LReq);
  Result := FInner.Send(LReq);
end;

function TOptionsOverrideClient.Options(const AUrl: string): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmOptions, AUrl, '', '');
  ApplyOptions(LReq);
  Result := FInner.Send(LReq);
end;

function TOptionsOverrideClient.PostForm(const AUrl: string;
  const AFields: TFormFieldArray): IHttpResponse;
begin
  Result := DoBodyRequest(hmPost, AUrl, 'application/x-www-form-urlencoded',
    EncodeUrlEncodedForm(AFields));
end;

function TOptionsOverrideClient.PostJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := DoBodyRequest(hmPost, AUrl, 'application/json', JsonStringify(ABody));
end;

function TOptionsOverrideClient.PutJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := DoBodyRequest(hmPut, AUrl, 'application/json', JsonStringify(ABody));
end;

function TOptionsOverrideClient.PatchJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := DoBodyRequest(hmPatch, AUrl, 'application/json', JsonStringify(ABody));
end;

function TOptionsOverrideClient.DeleteJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := DoBodyRequest(hmDelete, AUrl, 'application/json', JsonStringify(ABody));
end;

function TOptionsOverrideClient.SendStreaming(const AMethod: THttpMethod;
  const AUrl: string; const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := NewStreamingRequest(AMethod, AUrl, AContentType, ABody,
    AContentLength);
  ApplyOptions(LReq);
  Result := FInner.Send(LReq);
end;

function TOptionsOverrideClient.WithBasicAuth(const AUsername, APassword: string): IHttpClient;
begin
  Result := TAuthClient.Create(Self, 'Basic ' + Base64Encode(StringToUTF8Bytes(AUsername + ':' + APassword)));
end;

function TOptionsOverrideClient.WithBearerAuth(const AToken: string): IHttpClient;
begin
  Result := TAuthClient.Create(Self, 'Bearer ' + AToken);
end;

function TOptionsOverrideClient.WithHeader(const AName, AValue: string): IHttpClient;
begin
  Result := THeaderClient.Create(Self, AName, AValue);
end;

function TOptionsOverrideClient.WithTimeout(const ATimeoutMs: Int64): IHttpClient;
var
  LOpts: THttpRequestOptions;
begin
  LOpts := FRequestOptions;
  LOpts.TimeoutMs := ATimeoutMs;
  LOpts.HasTimeout := True;
  Result := TOptionsOverrideClient.Create(FInner, LOpts);
end;

function TOptionsOverrideClient.WithMaxRedirects(const AMaxRedirects: Int32): IHttpClient;
var
  LOpts: THttpRequestOptions;
begin
  LOpts := FRequestOptions;
  LOpts.MaxRedirects := AMaxRedirects;
  LOpts.HasMaxRedirects := True;
  Result := TOptionsOverrideClient.Create(FInner, LOpts);
end;

function TOptionsOverrideClient.WithFollowRedirects(const AFollow: Boolean): IHttpClient;
var
  LOpts: THttpRequestOptions;
begin
  LOpts := FRequestOptions;
  LOpts.FollowRedirects := AFollow;
  LOpts.HasFollowRedirects := True;
  Result := TOptionsOverrideClient.Create(FInner, LOpts);
end;

function TOptionsOverrideClient.WithRetry(const AMaxRetries: Int32): IHttpClient;
begin
  Result := TRetryClient.Create(Self, AMaxRetries);
end;

{ TRetryClient }

constructor TRetryClient.Create(const AInner: IHttpClient; const AMaxRetries: Int32);
begin
  inherited Create;
  FInner := AInner;
  if AMaxRetries < 0 then
    raise EArgumentError.Create('Retry count must not be negative');
  FMaxRetries := AMaxRetries;
end;

function TRetryClient.Send(const AReq: IHttpRequest): IHttpResponse;
var
  LAttempt: Int32;
  LBackoffMs: Int64;
begin
  Result := FInner.Send(AReq);
  for LAttempt := 1 to FMaxRetries do
  begin
    if (Result = nil) or (Result.StatusCode < 500) or (Result.StatusCode > 599) then
      Exit;
    HttpReleaseResponseBody(Result);
    LBackoffMs := 100 shl (LAttempt - 1); // 100, 200, 400, 800, ...
    if LBackoffMs > 5000 then
      LBackoffMs := 5000;
    platform_thread_sleep_ns(UInt64(LBackoffMs) * 1000000);
    Result := FInner.Send(AReq);
  end;
end;

procedure TRetryClient.CloseIdleConnections;
begin
  FInner.CloseIdleConnections;
end;

function TRetryClient.Get(const AUrl: string): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmGet, AUrl, '', '');
  Result := Send(LReq);
end;

function TRetryClient.DoBodyRequest(const AMethod: THttpMethod;
  const AUrl, AContentType, ABody: string): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(AMethod, AUrl, AContentType, ABody);
  Result := Send(LReq);
end;

function TRetryClient.Post(const AUrl, AContentType: string;
  const ABody: IReader): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPost, TUrl.Parse(AUrl), AContentType, ABody);
  Result := Send(LReq);
end;

function TRetryClient.Post(const AUrl, AContentType: string;
  const ABody: string): IHttpResponse;
begin
  Result := DoBodyRequest(hmPost, AUrl, AContentType, ABody);
end;

function TRetryClient.Post(const AUrl, AContentType: string;
  const ABody: TBytes): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPost, AUrl, AContentType, ABody);
  Result := Send(LReq);
end;

function TRetryClient.Put(const AUrl, AContentType: string;
  const ABody: IReader): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPut, TUrl.Parse(AUrl), AContentType, ABody);
  Result := Send(LReq);
end;

function TRetryClient.Put(const AUrl, AContentType: string;
  const ABody: string): IHttpResponse;
begin
  Result := DoBodyRequest(hmPut, AUrl, AContentType, ABody);
end;

function TRetryClient.Put(const AUrl, AContentType: string;
  const ABody: TBytes): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPut, AUrl, AContentType, ABody);
  Result := Send(LReq);
end;

function TRetryClient.Delete(const AUrl: string): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmDelete, AUrl, '', '');
  Result := Send(LReq);
end;

function TRetryClient.Delete(const AUrl, AContentType: string;
  const ABody: IReader): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmDelete, TUrl.Parse(AUrl), AContentType, ABody);
  Result := Send(LReq);
end;

function TRetryClient.Delete(const AUrl, AContentType: string;
  const ABody: string): IHttpResponse;
begin
  Result := DoBodyRequest(hmDelete, AUrl, AContentType, ABody);
end;

function TRetryClient.Delete(const AUrl, AContentType: string;
  const ABody: TBytes): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmDelete, AUrl, AContentType, ABody);
  Result := Send(LReq);
end;

function TRetryClient.Patch(const AUrl, AContentType: string;
  const ABody: IReader): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPatch, TUrl.Parse(AUrl), AContentType, ABody);
  Result := Send(LReq);
end;

function TRetryClient.Patch(const AUrl, AContentType: string;
  const ABody: string): IHttpResponse;
begin
  Result := DoBodyRequest(hmPatch, AUrl, AContentType, ABody);
end;

function TRetryClient.Patch(const AUrl, AContentType: string;
  const ABody: TBytes): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmPatch, AUrl, AContentType, ABody);
  Result := Send(LReq);
end;

function TRetryClient.Head(const AUrl: string): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmHead, AUrl, '', '');
  Result := Send(LReq);
end;

function TRetryClient.Options(const AUrl: string): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := BufferedBodyRequest(hmOptions, AUrl, '', '');
  Result := Send(LReq);
end;

function TRetryClient.PostForm(const AUrl: string;
  const AFields: TFormFieldArray): IHttpResponse;
begin
  Result := DoBodyRequest(hmPost, AUrl, 'application/x-www-form-urlencoded',
    EncodeUrlEncodedForm(AFields));
end;

function TRetryClient.PostJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := DoBodyRequest(hmPost, AUrl, 'application/json', JsonStringify(ABody));
end;

function TRetryClient.PutJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := DoBodyRequest(hmPut, AUrl, 'application/json', JsonStringify(ABody));
end;

function TRetryClient.PatchJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := DoBodyRequest(hmPatch, AUrl, 'application/json', JsonStringify(ABody));
end;

function TRetryClient.DeleteJson(const AUrl: string;
  const ABody: TJsonValue): IHttpResponse;
begin
  Result := DoBodyRequest(hmDelete, AUrl, 'application/json', JsonStringify(ABody));
end;

function TRetryClient.SendStreaming(const AMethod: THttpMethod;
  const AUrl: string; const AContentType: string; const ABody: IReader;
  const AContentLength: Int64): IHttpResponse;
var
  LReq: IHttpRequest;
begin
  LReq := NewStreamingRequest(AMethod, AUrl, AContentType, ABody,
    AContentLength);
  Result := Send(LReq);
end;

function TRetryClient.WithBasicAuth(const AUsername, APassword: string): IHttpClient;
begin
  Result := TAuthClient.Create(Self, 'Basic ' + Base64Encode(StringToUTF8Bytes(AUsername + ':' + APassword)));
end;

function TRetryClient.WithBearerAuth(const AToken: string): IHttpClient;
begin
  Result := TAuthClient.Create(Self, 'Bearer ' + AToken);
end;

function TRetryClient.WithHeader(const AName, AValue: string): IHttpClient;
begin
  Result := THeaderClient.Create(Self, AName, AValue);
end;

function TRetryClient.WithTimeout(const ATimeoutMs: Int64): IHttpClient;
begin
  Result := TOptionsOverrideClient.Create(Self,
    Default(THttpRequestOptions).WithTimeout(ATimeoutMs));
end;

function TRetryClient.WithMaxRedirects(const AMaxRetries: Int32): IHttpClient;
begin
  Result := TOptionsOverrideClient.Create(Self,
    Default(THttpRequestOptions).WithMaxRedirects(AMaxRetries));
end;

function TRetryClient.WithFollowRedirects(const AFollow: Boolean): IHttpClient;
begin
  Result := TOptionsOverrideClient.Create(Self,
    Default(THttpRequestOptions).WithFollowRedirects(AFollow));
end;

function TRetryClient.WithRetry(const AMaxRetries: Int32): IHttpClient;
begin
  Result := TRetryClient.Create(Self, AMaxRetries);
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

function HttpGetToWriter(const AClient: IHttpClient; const AUrl: string;
  const ADest: IWriter): Int64;
var
  LResp: IHttpResponse;
begin
  CheckDownloadArgs(AClient, AUrl);
  if ADest = nil then
    raise EArgumentError.Create('HTTP download destination writer is nil');

  LResp := AClient.Get(AUrl);
  try
    CheckDownloadResponse(LResp, AUrl);
    if LResp.Body = nil then
      Result := 0
    else
      Result := nextpas.core.io.Copy(ADest, LResp.Body);
  except
    ReleaseResponseBodyIgnoringErrors(LResp);
    raise;
  end;
  ReleaseResponseBody(LResp);
end;

function HttpGetToFile(const AClient: IHttpClient; const AUrl, ADestPath: string): Int64;
var
  LResp: IHttpResponse;
  LDestDir: string;
  LTempPath: string;
  LTempFile: IFile;
  LCommitted: Boolean;
begin
  CheckDownloadArgs(AClient, AUrl);
  if ADestPath = '' then
    raise EArgumentError.Create('HTTP download destination path is empty');

  LResp := AClient.Get(AUrl);
  try
    CheckDownloadResponse(LResp, AUrl);

    LDestDir := nextpas.core.fs.PathDir(ADestPath);
    if not nextpas.core.fs.MkdirAll(LDestDir) then
      raise EHttpError.Create('HTTP download could not create directory: ' + LDestDir);

    LTempFile := nextpas.core.fs.TempFile(LDestDir,
      '.' + nextpas.core.fs.PathBase(ADestPath) + '.tmp.');
    LTempPath := LTempFile.Name;
    LCommitted := False;
    try
      if LResp.Body <> nil then
        Result := nextpas.core.io.Copy(LTempFile as IWriter, LResp.Body)
      else
        Result := 0;
      LTempFile.Sync;
      LTempFile.Close;
      LTempFile := nil;

      if not nextpas.core.fs.Rename(LTempPath, ADestPath) then
        raise EHttpError.Create('HTTP download could not publish file: ' + ADestPath);
      LCommitted := True;
    finally
      if LTempFile <> nil then
      begin
        try
          LTempFile.Close;
        except
          on E: Exception do ;
        end;
      end;
      if (not LCommitted) and (LTempPath <> '') then
        nextpas.core.fs.Remove(LTempPath);
    end;
  except
    ReleaseResponseBodyIgnoringErrors(LResp);
    raise;
  end;
  ReleaseResponseBody(LResp);
end;

procedure HttpReleaseResponseBody(const AResp: IHttpResponse);
begin
  if AResp = nil then
    raise EArgumentError.Create('HTTP response is nil');
  ReleaseResponseBody(AResp);
end;

function HttpReadResponseBodyBytes(const AResp: IHttpResponse): TBytes;
var
  LBody: IReader;
begin
  if AResp = nil then
    raise EArgumentError.Create('HTTP response is nil');

  LBody := AResp.Body;
  if LBody = nil then
    Exit;

  try
    Result := nextpas.core.io.ReadAll(LBody);
  except
    ReleaseResponseBodyIgnoringErrors(AResp);
    raise;
  end;
  ReleaseResponseBody(AResp);
end;

function HttpReadResponseBodyString(const AResp: IHttpResponse): string;
var
  LBody: TBytes;
begin
  LBody := HttpReadResponseBodyBytes(AResp);
  Result := '';
  SetLength(Result, Length(LBody));
  if Length(LBody) > 0 then
    Move(LBody[0], Result[1], Length(LBody));
end;

function ExtractCharsetFromContentType(const AContentType: string): string;
var
  LLower, LCharset: string;
  LStart, LEnd: SizeInt;
begin
  Result := '';
  if AContentType = '' then Exit;
  LLower := LowerCase(AContentType);
  LStart := Pos('charset=', LLower);
  if LStart = 0 then Exit;
  Inc(LStart, 8); { skip 'charset=' }
  LEnd := LStart;
  while (LEnd <= Length(AContentType)) and (AContentType[LEnd] <> ';') and
    (AContentType[LEnd] <> ' ') do
    Inc(LEnd);
  SetLength(LCharset, LEnd - LStart);
  if LEnd > LStart then
    Move(AContentType[LStart], LCharset[1], LEnd - LStart);
  { Remove surrounding quotes if present }
  if (Length(LCharset) >= 2) and (LCharset[1] = '"') and
    (LCharset[Length(LCharset)] = '"') then
  begin
    SetLength(Result, Length(LCharset) - 2);
    if Length(Result) > 0 then
      Move(LCharset[2], Result[1], Length(Result));
  end
  else
    Result := LCharset;
end;

function BytesToLatin1String(const ABytes: TBytes): string;
var
  I, LLen: SizeInt;
begin
  LLen := Length(ABytes);
  SetLength(Result, LLen);
  for I := 0 to LLen - 1 do
    Result[I + 1] := Chr(ABytes[I]);
end;

function HttpReadResponseBodyStringAuto(const AResp: IHttpResponse): string;
var
  LBody: TBytes;
  LContentType, LCharset: string;
  LLowerCharset: string;
begin
  LBody := HttpReadResponseBodyBytes(AResp);
  if Length(LBody) = 0 then
    Exit('');

  LContentType := '';
  if AResp <> nil then
    LContentType := AResp.Headers.Get('content-type');
  LCharset := ExtractCharsetFromContentType(LContentType);
  LLowerCharset := LowerCase(LCharset);

  { Default to UTF-8 if no charset specified }
  if (LLowerCharset = '') or (LLowerCharset = 'utf-8') or
    (LLowerCharset = 'utf8') or (LLowerCharset = 'us-ascii') then
  begin
    Result := '';
    SetLength(Result, Length(LBody));
    Move(LBody[0], Result[1], Length(LBody));
  end
  else if (LLowerCharset = 'iso-8859-1') or (LLowerCharset = 'latin1') or
    (LLowerCharset = 'latin-1') or (LLowerCharset = 'windows-1252') then
    Result := BytesToLatin1String(LBody)
  else
  begin
    { Unknown charset — fall back to raw bytes (UTF-8 compatible) }
    Result := '';
    SetLength(Result, Length(LBody));
    Move(LBody[0], Result[1], Length(LBody));
  end;
end;

function HttpEnsureSuccess(const AResp: IHttpResponse): IHttpResponse;
begin
  if AResp = nil then
    raise EArgumentError.Create('HTTP response is nil');
  if not nextpas.core.http.base.HttpStatusIsSuccess(AResp.StatusCode) then
    raise EHttpError.Create('HTTP request failed with status ' +
      IntToStr(Int64(AResp.StatusCode)) + ' ' +
      nextpas.core.http.base.HttpStatusText(AResp.StatusCode));
  Result := AResp;
end;

function HttpGetString(const AClient: IHttpClient; const AUrl: string): string;
var
  LResp: IHttpResponse;
begin
  LResp := AClient.Get(AUrl);
  try
    HttpEnsureSuccess(LResp);
    Result := HttpReadResponseBodyString(LResp);
  except
    HttpReleaseResponseBody(LResp);
    raise;
  end;
end;

function HttpGetBytes(const AClient: IHttpClient; const AUrl: string): TBytes;
var
  LResp: IHttpResponse;
begin
  LResp := AClient.Get(AUrl);
  try
    HttpEnsureSuccess(LResp);
    Result := HttpReadResponseBodyBytes(LResp);
  except
    HttpReleaseResponseBody(LResp);
    raise;
  end;
end;

function HttpPostString(const AClient: IHttpClient;
  const AUrl, AContentType, ABody: string): string;
var
  LResp: IHttpResponse;
begin
  LResp := AClient.Post(AUrl, AContentType, ABody);
  try
    HttpEnsureSuccess(LResp);
    Result := HttpReadResponseBodyString(LResp);
  except
    HttpReleaseResponseBody(LResp);
    raise;
  end;
end;

function HttpPutString(const AClient: IHttpClient;
  const AUrl, AContentType, ABody: string): string;
var
  LResp: IHttpResponse;
begin
  LResp := AClient.Put(AUrl, AContentType, ABody);
  try
    HttpEnsureSuccess(LResp);
    Result := HttpReadResponseBodyString(LResp);
  except
    HttpReleaseResponseBody(LResp);
    raise;
  end;
end;

function HttpPatchString(const AClient: IHttpClient;
  const AUrl, AContentType, ABody: string): string;
var
  LResp: IHttpResponse;
begin
  LResp := AClient.Patch(AUrl, AContentType, ABody);
  try
    HttpEnsureSuccess(LResp);
    Result := HttpReadResponseBodyString(LResp);
  except
    HttpReleaseResponseBody(LResp);
    raise;
  end;
end;

function HttpDeleteString(const AClient: IHttpClient;
  const AUrl: string): string;
var
  LResp: IHttpResponse;
begin
  LResp := AClient.Delete(AUrl);
  try
    HttpEnsureSuccess(LResp);
    Result := HttpReadResponseBodyString(LResp);
  except
    HttpReleaseResponseBody(LResp);
    raise;
  end;
end;

function HttpHead(const AClient: IHttpClient; const AUrl: string): IHttpResponse;
begin
  Result := AClient.Head(AUrl);
  HttpEnsureSuccess(Result);
end;

function HttpOptions(const AClient: IHttpClient; const AUrl: string): IHttpResponse;
begin
  Result := AClient.Options(AUrl);
  HttpEnsureSuccess(Result);
end;

function HttpPostJson(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): string;
var
  LResp: IHttpResponse;
begin
  LResp := AClient.Post(AUrl, 'application/json', ABody.Stringify);
  try
    HttpEnsureSuccess(LResp);
    Result := HttpReadResponseBodyString(LResp);
  except
    HttpReleaseResponseBody(LResp);
    raise;
  end;
end;

function HttpPutJson(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): string;
var
  LResp: IHttpResponse;
begin
  LResp := AClient.Put(AUrl, 'application/json', ABody.Stringify);
  try
    HttpEnsureSuccess(LResp);
    Result := HttpReadResponseBodyString(LResp);
  except
    HttpReleaseResponseBody(LResp);
    raise;
  end;
end;

function HttpPatchJson(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): string;
var
  LResp: IHttpResponse;
begin
  LResp := AClient.Patch(AUrl, 'application/json', ABody.Stringify);
  try
    HttpEnsureSuccess(LResp);
    Result := HttpReadResponseBodyString(LResp);
  except
    HttpReleaseResponseBody(LResp);
    raise;
  end;
end;

function HttpDeleteJson(const AClient: IHttpClient;
  const AUrl: string; const ABody: IJsonDocument): string;
var
  LResp: IHttpResponse;
begin
  LResp := AClient.Delete(AUrl, 'application/json', ABody.Stringify);
  try
    HttpEnsureSuccess(LResp);
    Result := HttpReadResponseBodyString(LResp);
  except
    HttpReleaseResponseBody(LResp);
    raise;
  end;
end;

end.
