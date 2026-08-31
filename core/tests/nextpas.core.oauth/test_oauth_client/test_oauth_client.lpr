program test_oauth_client;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.exception,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.message,
  nextpas.core.http.headers,
  nextpas.core.http.client,
  nextpas.core.oauth.client;

var
  T: TTestSuite;

type
  { 记录请求 + 返回预设响应的 fake transport（零网络、确定性） }
  TFakeTransport = class(TInterfacedObject, IHttpTransport)
  public
    LastMethod: string;
    LastUrl: string;
    LastContentType: string;
    LastBody: string;
    RespStatus: Integer;
    RespBody: string;
    RaiseOnCall: Boolean;
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
  end;

function TFakeTransport.RoundTrip(const AReq: IHttpRequest): IHttpResponse;
var
  LB: TBytes;
begin
  if RaiseOnCall then
    raise ENextPasError.Create('transport down');
  LastMethod := HttpMethodToStr(AReq.Method);
  LastUrl := AReq.Url.ToString;
  LastContentType := AReq.Headers.Get('Content-Type');
  SetLength(LB, AReq.ContentLength);
  if AReq.ContentLength > 0 then
  begin
    if AReq.Body.Read(LB[0], Length(LB)) < Cardinal(Length(LB)) then
    begin
      { 短读容忍：按实际读到的截断 }
    end;
  end;
  SetString(LastBody, PAnsiChar(@LB[0]), Length(LB));
  Result := NewResponse(THttpStatus(RespStatus), NewHttpHeaders, RespBody);
end;

const
  ENDPOINTS_AUTH = 'https://accounts.example.com/oauth/authorize';
  ENDPOINTS_TOKEN = 'https://accounts.example.com/oauth/token';

function MakeClient(out ATransport: TFakeTransport): IHttpClient;
begin
  ATransport := TFakeTransport.Create;
  ATransport.RespStatus := 200;
  Result := NewHttpClient(ATransport);
end;

function Endpoints(const ASecret: string): TOAuth2Endpoints;
begin
  Result := Default(TOAuth2Endpoints);
  Result.AuthorizationUrl := ENDPOINTS_AUTH;
  Result.TokenUrl := ENDPOINTS_TOKEN;
  Result.ClientSecret := ASecret;
end;

procedure TestBuildAuthorizeUrlFull;
var
  LUrl: string;
begin
  LUrl := BuildAuthorizeUrl(Endpoints(''), 'cid',
    'https://app.example.com/cb', 'email profile', 'st.1600.sig', 'challenge-x');
  Check(Pos('https://accounts.example.com/oauth/authorize?', LUrl) = 1, 'base url');
  Check(Pos('response_type=code', LUrl) > 0, 'response_type');
  Check(Pos('&client_id=cid', LUrl) > 0, 'client_id plain safe');
  Check(Pos('redirect_uri=https%3A%2F%2Fapp.example.com%2Fcb', LUrl) > 0,
    'redirect_uri encoded');
  Check(Pos('&scope=email%20profile', LUrl) > 0, 'scope encoded (space %20)');
  Check(Pos('&state=st.1600.sig', LUrl) > 0, 'state passthrough');
  Check(Pos('&code_challenge=challenge-x', LUrl) > 0, 'code_challenge');
  Check(Pos('&code_challenge_method=S256', LUrl) > 0, 'method S256 fixed');
end;

procedure TestBuildAuthorizeUrlNoScope;
var
  LUrl: string;
begin
  LUrl := BuildAuthorizeUrl(Endpoints(''), 'cid', 'https://a/cb', '',
    'st', 'cc');
  Check(Pos('scope=', LUrl) = 0, 'empty scope omitted');
end;

procedure TestBuildAuthorizeUrlValidation;
var
  LE: TOAuth2Endpoints;
  LOk: Boolean;

  procedure ExpectArgError(const AId, ARedirect, AState, ACc: string; const AMsg: string);
  var
    LOkLocal: Boolean;
  begin
    LOkLocal := False;
    try
      BuildAuthorizeUrl(LE, AId, ARedirect, '', AState, ACc);
    except
      on E: EArgumentError do LOkLocal := True;
      on E: Exception do LOkLocal := False;
    end;
    Check(LOkLocal, AMsg);
  end;

begin
  LE := Endpoints('');
  ExpectArgError('', 'r', 's', 'c', 'missing client_id -> EArgumentError');
  ExpectArgError('id', '', 's', 'c', 'missing redirect_uri -> EArgumentError');
  ExpectArgError('id', 'r', '', 'c', 'missing state -> EArgumentError');
  ExpectArgError('id', 'r', 's', '', 'missing code_challenge -> EArgumentError');

  LE.TokenUrl := '';
  LOk := False;
  try
    BuildAuthorizeUrl(LE, 'id', 'r', '', 's', 'c');
  except
    on E: EArgumentError do LOk := True;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'unconfigured endpoints -> EArgumentError');
end;

procedure TestExchangeSuccess;
var
  LTransport: TFakeTransport;
  LClient: IHttpClient;
  LResult: TOAuth2TokenResult;
begin
  LClient := MakeClient(LTransport);
  LTransport.RespStatus := 200;
  LTransport.RespBody :=
    '{"access_token":"at-1","token_type":"Bearer","expires_in":3600,' +
    '"refresh_token":"rt-1","id_token":"it-1","scope":"email"}';

  LResult := ExchangeAuthorizationCode(LClient, Endpoints('sec-1'),
    'cid', 'https://app/cb', 'auth-code-1', 'verifier-1');

  Check(LResult.Ok, 'exchange ok');
  CheckEqual('at-1', LResult.AccessToken, 'access_token');
  CheckEqual('Bearer', LResult.TokenType, 'token_type');
  CheckEqual(Int64(3600), LResult.ExpiresIn, 'expires_in');
  CheckEqual('rt-1', LResult.RefreshToken, 'refresh_token');
  CheckEqual('it-1', LResult.IdToken, 'id_token');
  CheckEqual('email', LResult.Scope, 'scope');

  CheckEqual('POST', LTransport.LastMethod, 'token request is POST');
  CheckEqual(ENDPOINTS_TOKEN, LTransport.LastUrl, 'token url');
  CheckEqual('application/x-www-form-urlencoded', LTransport.LastContentType,
    'form content type');
  Check(Pos('grant_type=authorization_code', LTransport.LastBody) > 0, 'grant_type');
  Check(Pos('&code=auth-code-1', LTransport.LastBody) > 0, 'code');
  Check(Pos('&redirect_uri=https%3A%2F%2Fapp%2Fcb', LTransport.LastBody) > 0,
    'redirect_uri encoded');
  Check(Pos('&client_id=cid', LTransport.LastBody) > 0, 'client_id');
  Check(Pos('&client_secret=sec-1', LTransport.LastBody) > 0, 'client_secret when set');
  Check(Pos('&code_verifier=verifier-1', LTransport.LastBody) > 0, 'code_verifier (PKCE)');
end;

procedure TestExchangePublicClientNoSecret;
var
  LTransport: TFakeTransport;
  LClient: IHttpClient;
  LResult: TOAuth2TokenResult;
begin
  LClient := MakeClient(LTransport);
  LTransport.RespBody := '{"access_token":"at"}';
  LResult := ExchangeAuthorizationCode(LClient, Endpoints(''),
    'cid', 'r', 'c', 'v');
  Check(LResult.Ok, 'public client ok');
  Check(Pos('client_secret', LTransport.LastBody) = 0,
    'no client_secret for public client');
end;

procedure TestExchangeOAuthError;
var
  LTransport: TFakeTransport;
  LClient: IHttpClient;
  LResult: TOAuth2TokenResult;
begin
  LClient := MakeClient(LTransport);
  LTransport.RespStatus := 400;
  LTransport.RespBody :=
    '{"error":"invalid_grant","error_description":"code expired"}';

  LResult := ExchangeAuthorizationCode(LClient, Endpoints(''),
    'cid', 'r', 'c', 'v');
  Check(not LResult.Ok, 'oauth error not ok');
  CheckEqual('invalid_grant', LResult.ErrorCode, 'rfc 6749 error code surfaced');
  CheckEqual('code expired', LResult.ErrorDescription, 'error description');
end;

procedure TestExchangeHttp500NonJson;
var
  LTransport: TFakeTransport;
  LClient: IHttpClient;
  LResult: TOAuth2TokenResult;
begin
  LClient := MakeClient(LTransport);
  LTransport.RespStatus := 500;
  LTransport.RespBody := '<html>boom</html>';

  LResult := ExchangeAuthorizationCode(LClient, Endpoints(''),
    'cid', 'r', 'c', 'v');
  Check(not LResult.Ok, 'http 500 not ok');
  CheckEqual('http_500', LResult.ErrorCode, 'status fallback error code');
end;

procedure TestRefreshSuccess;
var
  LTransport: TFakeTransport;
  LClient: IHttpClient;
  LResult: TOAuth2TokenResult;
begin
  LClient := MakeClient(LTransport);
  LTransport.RespStatus := 200;
  LTransport.RespBody :=
    '{"access_token":"at-2","refresh_token":"rt-2","expires_in":7200}';

  LResult := RefreshAccessToken(LClient, Endpoints('sec'), 'cid', 'rt-old');
  Check(LResult.Ok, 'refresh ok');
  CheckEqual('at-2', LResult.AccessToken, 'new access token');
  CheckEqual('rt-2', LResult.RefreshToken, 'rotated refresh token');
  Check(Pos('grant_type=refresh_token', LTransport.LastBody) > 0, 'grant_type refresh');
  Check(Pos('&refresh_token=rt-old', LTransport.LastBody) > 0, 'old refresh token sent');
  Check(Pos('&client_secret=sec', LTransport.LastBody) > 0, 'secret sent');
end;

procedure TestTransportExceptionPropagates;
var
  LTransport: TFakeTransport;
  LClient: IHttpClient;
  LOk: Boolean;
begin
  LClient := MakeClient(LTransport);
  LTransport.RaiseOnCall := True;
  LOk := False;
  try
    ExchangeAuthorizationCode(LClient, Endpoints(''), 'cid', 'r', 'c', 'v');
  except
    on E: ENextPasError do
      LOk := Pos('transport down', E.Message) > 0;
    on E: Exception do LOk := False;
  end;
  Check(LOk, 'transport exception propagates (caller distinguishes outage)');
end;

begin
  T := TTestSuite.Create('nextpas.core.oauth.client');
  T.Test('Build authorize url full', @TestBuildAuthorizeUrlFull);
  T.Test('Build authorize url no scope', @TestBuildAuthorizeUrlNoScope);
  T.Test('Build authorize url validation', @TestBuildAuthorizeUrlValidation);
  T.Test('Exchange success (confidential)', @TestExchangeSuccess);
  T.Test('Exchange public client omits secret', @TestExchangePublicClientNoSecret);
  T.Test('Exchange oauth error surfaced', @TestExchangeOAuthError);
  T.Test('Exchange http 500 non-json', @TestExchangeHttp500NonJson);
  T.Test('Refresh success', @TestRefreshSuccess);
  T.Test('Transport exception propagates', @TestTransportExceptionPropagates);
  if not T.Run then Halt(1);
end.
