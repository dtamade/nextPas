unit nextpas.core.oauth.client;
{**
 * @desc OAuth2 授权码客户端（RFC 6749 §4.1 + PKCE RFC 7636，B5 第二片）。
 *       厂商中立（endpoints 配置化，Google/GitHub 仅是配置差异）；
 *       transport 经 IHttpClient 注入（测试用 fake IHttpTransport）；
 *       协议层结果结构化（Ok/ErrorCode），transport 异常原样传播
 *       （调用方区分「没网」与「授权失败」）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.http.intf;

type
  { 端点配置。ClientSecret 仅 confidential client 填；public PKCE 流留空。 }
  TOAuth2Endpoints = record
    AuthorizationUrl: string;   { authorize endpoint 基址（无 query） }
    TokenUrl: string;
    ClientSecret: string;
  end;

  { token 端点结构化结果。Ok=False 时 ErrorCode 非空：
    RFC 6749 §5.2 错误码（invalid_grant 等）或 'http_<status>'。 }
  TOAuth2TokenResult = record
    Ok: Boolean;
    AccessToken: string;
    TokenType: string;
    ExpiresIn: Int64;           { 秒；0 = 未返回 }
    RefreshToken: string;
    IdToken: string;
    Scope: string;
    ErrorCode: string;
    ErrorDescription: string;
  end;

{ 构造 authorize 跳转 URL：
  ?response_type=code&client_id&redirect_uri&state&code_challenge&
  code_challenge_method=S256[&scope]（AScope 空则省略；值全量 URL 编码）。 }
function BuildAuthorizeUrl(const AE: TOAuth2Endpoints; const AClientId,
  ARedirectUri, AScope, AState, ACodeChallenge: string): string;

{ 授权码换 token：POST form-urlencoded（grant_type=authorization_code +
  code + redirect_uri + client_id [+ client_secret] + code_verifier）。
  非 2xx 或 JSON error 字段 → Ok=False；transport 异常原样传播。 }
function ExchangeAuthorizationCode(const AClient: IHttpClient;
  const AE: TOAuth2Endpoints; const AClientId, ARedirectUri, ACode,
  ACodeVerifier: string): TOAuth2TokenResult;

{ 刷新 access token：POST grant_type=refresh_token & refresh_token &
  client_id [+ client_secret]。结果语义同上。 }
function RefreshAccessToken(const AClient: IHttpClient;
  const AE: TOAuth2Endpoints; const AClientId,
  ARefreshToken: string): TOAuth2TokenResult;

implementation

uses
  nextpas.core.encoding.url,
  nextpas.core.http.client.helpers,
  nextpas.core.http.message,
  nextpas.core.json,
  nextpas.core.json.value;

function FormEncode(const AKey, AValue: string): string; inline;
begin
  Result := AKey + '=' + UrlEncode(AValue);
end;

function IntToStrDec(const AValue: Integer): string;
begin
  Str(AValue, Result);
end;

procedure RequireEndpoints(const AE: TOAuth2Endpoints);
begin
  if (AE.TokenUrl = '') or (AE.AuthorizationUrl = '') then
    raise EArgumentError.Create('oauth2: endpoints not configured');
end;

function ParseTokenResponse(const ABody: string): TOAuth2TokenResult;
var
  LDoc: IJsonDocument;
  LV: TJsonValue;
begin
  Result := Default(TOAuth2TokenResult);

  LDoc := JsonParse(ABody);
  if (LDoc = nil) or LDoc.HasError or (not LDoc.Root.IsObject) then
  begin
    Result.ErrorCode := 'bad_response';
    Result.ErrorDescription := 'token endpoint returned non-JSON body';
    Exit;
  end;

  { RFC 6749 §5.2：error 字段存在即失败 }
  LV := LDoc.Root.Get('error');
  if LV.IsStr and (LV.AsStr.ToString <> '') then
  begin
    Result.ErrorCode := LV.AsStr.ToString;
    LV := LDoc.Root.Get('error_description');
    if LV.IsStr then
      Result.ErrorDescription := LV.AsStr.ToString;
    Exit;
  end;

  LV := LDoc.Root.Get('access_token');
  if LV.IsStr then
    Result.AccessToken := LV.AsStr.ToString;
  if Result.AccessToken = '' then
  begin
    Result.ErrorCode := 'bad_response';
    Result.ErrorDescription := 'token endpoint response missing access_token';
    Exit;
  end;

  Result.Ok := True;
  LV := LDoc.Root.Get('token_type');
  if LV.IsStr then
    Result.TokenType := LV.AsStr.ToString;
  LV := LDoc.Root.Get('expires_in');
  if LV.IsInt or LV.IsFloat then
    Result.ExpiresIn := LV.AsInt;
  LV := LDoc.Root.Get('refresh_token');
  if LV.IsStr then
    Result.RefreshToken := LV.AsStr.ToString;
  LV := LDoc.Root.Get('id_token');
  if LV.IsStr then
    Result.IdToken := LV.AsStr.ToString;
  LV := LDoc.Root.Get('scope');
  if LV.IsStr then
    Result.Scope := LV.AsStr.ToString;
end;

function DoTokenPost(const AClient: IHttpClient; const ATokenUrl,
  AForm: string): TOAuth2TokenResult;
var
  LResp: IHttpResponse;
  LStatus: Integer;
begin
  LResp := AClient.Post(ATokenUrl, 'application/x-www-form-urlencoded', AForm);
  LStatus := Integer(LResp.StatusCode);
  if (LStatus < 200) or (LStatus > 299) then
  begin
    { 4xx 常带 RFC 6749 error JSON——尽力解析；无结构化错误则 http_<status> }
    Result := ParseTokenResponse(HttpReadResponseBodyString(LResp));
    if not Result.Ok then
    begin
      if (Result.ErrorCode = '') or (Result.ErrorCode = 'bad_response') then
        Result.ErrorCode := 'http_' + IntToStrDec(LStatus);
    end;
    Exit;
  end;
  Result := ParseTokenResponse(HttpReadResponseBodyString(LResp));
end;

function BuildAuthorizeUrl(const AE: TOAuth2Endpoints; const AClientId,
  ARedirectUri, AScope, AState, ACodeChallenge: string): string;
begin
  RequireEndpoints(AE);
  if (AClientId = '') or (ARedirectUri = '') or (AState = '') or
     (ACodeChallenge = '') then
    raise EArgumentError.Create('oauth2: authorize requires client_id/redirect_uri/state/code_challenge');

  Result := AE.AuthorizationUrl +
    '?response_type=code' +
    '&client_id=' + UrlEncode(AClientId) +
    '&redirect_uri=' + UrlEncode(ARedirectUri) +
    '&state=' + UrlEncode(AState) +
    '&code_challenge=' + UrlEncode(ACodeChallenge) +
    '&code_challenge_method=S256';
  if AScope <> '' then
    Result := Result + '&scope=' + UrlEncode(AScope);
end;

function ExchangeAuthorizationCode(const AClient: IHttpClient;
  const AE: TOAuth2Endpoints; const AClientId, ARedirectUri, ACode,
  ACodeVerifier: string): TOAuth2TokenResult;
var
  LForm: string;
begin
  RequireEndpoints(AE);
  if (AClientId = '') or (ACode = '') or (ACodeVerifier = '') then
    raise EArgumentError.Create('oauth2: exchange requires client_id/code/code_verifier');
  if AClient = nil then
    raise EArgumentError.Create('oauth2: nil http client');

  LForm := FormEncode('grant_type', 'authorization_code') +
    '&' + FormEncode('code', ACode) +
    '&' + FormEncode('redirect_uri', ARedirectUri) +
    '&' + FormEncode('client_id', AClientId);
  if AE.ClientSecret <> '' then
    LForm := LForm + '&' + FormEncode('client_secret', AE.ClientSecret);
  LForm := LForm + '&' + FormEncode('code_verifier', ACodeVerifier);

  Result := DoTokenPost(AClient, AE.TokenUrl, LForm);
end;

function RefreshAccessToken(const AClient: IHttpClient;
  const AE: TOAuth2Endpoints; const AClientId,
  ARefreshToken: string): TOAuth2TokenResult;
var
  LForm: string;
begin
  RequireEndpoints(AE);
  if (AClientId = '') or (ARefreshToken = '') then
    raise EArgumentError.Create('oauth2: refresh requires client_id/refresh_token');
  if AClient = nil then
    raise EArgumentError.Create('oauth2: nil http client');

  LForm := FormEncode('grant_type', 'refresh_token') +
    '&' + FormEncode('refresh_token', ARefreshToken) +
    '&' + FormEncode('client_id', AClientId);
  if AE.ClientSecret <> '' then
    LForm := LForm + '&' + FormEncode('client_secret', AE.ClientSecret);

  Result := DoTokenPost(AClient, AE.TokenUrl, LForm);
end;

end.
