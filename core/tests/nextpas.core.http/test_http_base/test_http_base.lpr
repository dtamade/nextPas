program test_http_base;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.fs,
  nextpas.core.http.base;

var
  T: TTestSuite;

procedure TestHttpMethodToStr;
begin
  CheckEqual('GET', HttpMethodToStr(hmGet), 'GET');
  CheckEqual('HEAD', HttpMethodToStr(hmHead), 'HEAD');
  CheckEqual('POST', HttpMethodToStr(hmPost), 'POST');
  CheckEqual('PUT', HttpMethodToStr(hmPut), 'PUT');
  CheckEqual('DELETE', HttpMethodToStr(hmDelete), 'DELETE');
  CheckEqual('PATCH', HttpMethodToStr(hmPatch), 'PATCH');
  CheckEqual('OPTIONS', HttpMethodToStr(hmOptions), 'OPTIONS');
  CheckEqual('CONNECT', HttpMethodToStr(hmConnect), 'CONNECT');
  CheckEqual('TRACE', HttpMethodToStr(hmTrace), 'TRACE');
end;

procedure TestHttpStrToMethod;
var
  LCaught: Boolean;
begin
  Check(HttpStrToMethod('GET') = hmGet, 'GET');
  Check(HttpStrToMethod('HEAD') = hmHead, 'HEAD');
  Check(HttpStrToMethod('POST') = hmPost, 'POST');
  Check(HttpStrToMethod('PUT') = hmPut, 'PUT');
  Check(HttpStrToMethod('DELETE') = hmDelete, 'DELETE');
  Check(HttpStrToMethod('PATCH') = hmPatch, 'PATCH');
  Check(HttpStrToMethod('OPTIONS') = hmOptions, 'OPTIONS');
  Check(HttpStrToMethod('CONNECT') = hmConnect, 'CONNECT');
  Check(HttpStrToMethod('TRACE') = hmTrace, 'TRACE');

  LCaught := False;
  try
    HttpStrToMethod('INVALID');
  except
    on E: EHttpError do
      LCaught := True;
  end;
  Check(LCaught, 'unknown method raises EHttpError');
end;

procedure TestHttpErrorCategory;
var
  LErr: EHttpError;
  LCaught: Boolean;
begin
  LErr := EHttpError.Create('network boundary');
  try
    Check(LErr is ENextPasError, 'EHttpError inherits ENextPasError');
    Check(LErr.Category = ecNetwork, 'EHttpError default category is network');
    Check(LErr.Kind = hekUnknown, 'EHttpError default Kind is unknown');
    CheckEqual('network boundary', LErr.Message, 'EHttpError preserves message');
  finally
    LErr.Free;
  end;

  LErr := EHttpError.Create(hekTimeout, 'deadline exceeded');
  try
    Check(LErr.Kind = hekTimeout, 'typed Create sets Kind');
    Check(LErr.Category = ecTimeout, 'timeout Kind maps to ecTimeout');
  finally
    LErr.Free;
  end;

  LCaught := False;
  try
    HttpStrToMethod('INVALID');
  except
    on E: EHttpError do
    begin
      LCaught := True;
      Check(E.Kind = hekParse, 'HttpStrToMethod Kind is parse');
      Check(E.Category = ecParse, 'HttpStrToMethod error category is parse');
    end;
  end;
  Check(LCaught, 'HttpStrToMethod raises EHttpError for invalid method');
end;

procedure TestHttpErrorKindHelpers;
var
  LTimeout: EHttpError;
  LConnect: EHttpError;
  LParse: EHttpError;
  LArg: EHttpError;
  LCanceled: EHttpError;
  LBareTimeout: ETimeoutError;
  LNet: ENetworkError;
  LWrapped: Exception;
begin
  LTimeout := EHttpError.Create(hekTimeout, 'http timeout');
  LConnect := EHttpError.Create(hekConnect, 'connect failed');
  LParse := EHttpError.Create(hekParse, 'bad');
  LArg := EHttpError.Create(hekArgument, 'bad arg');
  LCanceled := EHttpError.Create(hekCanceled, 'canceled');
  LBareTimeout := ETimeoutError.Create('bare transport timeout');
  LNet := ENetworkError.Create('network failed');
  try
    Check(HttpErrorIsTimeout(LTimeout), 'hekTimeout is timeout');
    Check(HttpErrorIsTimeout(LBareTimeout), 'bare ETimeoutError is timeout');
    Check(not HttpErrorIsTimeout(LConnect), 'hekConnect is not timeout');
    Check(not HttpErrorIsTimeout(nil), 'nil is not timeout');

    Check(HttpErrorIsRetryable(LTimeout), 'timeout is retryable');
    Check(HttpErrorIsRetryable(LConnect), 'connect is retryable');
    Check(HttpErrorIsRetryable(LBareTimeout), 'bare timeout is retryable');
    Check(HttpErrorIsRetryable(LNet), 'network error is retryable');
    Check(not HttpErrorIsRetryable(LParse), 'parse is not retryable');

    Check(HttpErrorIsUserError(LArg), 'hekArgument is user error');
    Check(HttpErrorIsUserError(LCanceled), 'hekCanceled is user error');
    Check(not HttpErrorIsUserError(LTimeout), 'timeout is not user error');
    Check(not HttpErrorIsUserError(LParse), 'parse is not user error');

    LWrapped := HttpWrapTransportException(LBareTimeout);
    try
      Check(LWrapped is EHttpError, 'wrap produces EHttpError');
      Check(EHttpError(LWrapped).Kind = hekTimeout, 'wrap sets hekTimeout');
      CheckEqual('transport', EHttpError(LWrapped).Op, 'wrap sets transport op');
    finally
      LWrapped.Free;
    end;
    LWrapped := HttpWrapTransportException(LNet);
    try
      Check(LWrapped is EHttpError, 'network wrap produces EHttpError');
      Check(EHttpError(LWrapped).Kind = hekConnect, 'network wrap sets hekConnect');
      CheckEqual('transport', EHttpError(LWrapped).Op, 'network wrap sets transport op');
    finally
      LWrapped.Free;
    end;
    Check(HttpWrapTransportException(LConnect) = nil,
      'already-typed EHttpError wrap returns nil');
    Check(HttpWrapTransportException(LParse) = nil,
      'non-transport wrap returns nil');
  finally
    LTimeout.Free;
    LConnect.Free;
    LParse.Free;
    LArg.Free;
    LCanceled.Free;
    LBareTimeout.Free;
    LNet.Free;
  end;
end;

procedure TestHttpErrorCreateOpTaxonomy;
var
  LOp: EHttpError;
  LStatus: EHttpError;
  LBareArg: EArgumentError;
  LCancel: ECancelledError;
  LWrapped: Exception;
begin
  LOp := EHttpError.CreateOp(hekProtocol, 'json', 'bad json');
  try
    Check(LOp.Kind = hekProtocol, 'CreateOp sets Kind');
    CheckEqual('json', LOp.Op, 'CreateOp sets Op');
    CheckEqual('bad json', LOp.Message, 'CreateOp sets Message');
    CheckEqual(Int64(0), Int64(LOp.Status), 'CreateOp without Status leaves 0');
  finally
    LOp.Free;
  end;

  LStatus := EHttpError.CreateOp(hekStatus, 'ensure', 'not found',
    HTTP_STATUS_NOT_FOUND);
  try
    Check(LStatus.Kind = hekStatus, 'CreateOp+Status Kind');
    CheckEqual('ensure', LStatus.Op, 'CreateOp+Status Op');
    CheckEqual(Int64(HTTP_STATUS_NOT_FOUND), Int64(LStatus.Status),
      'CreateOp+Status preserves Status');
  finally
    LStatus.Free;
  end;

  LBareArg := EArgumentError.Create('foreign precondition');
  try
    Check(HttpErrorIsUserError(LBareArg),
      'foreign bare EArgumentError still counts as user error');
  finally
    LBareArg.Free;
  end;

  LCancel := ECancelledError.Create('bare cancel');
  try
    LWrapped := HttpWrapTransportException(LCancel);
    try
      Check(LWrapped is EHttpError, 'cancel wrap produces EHttpError');
      Check(EHttpError(LWrapped).Kind = hekCanceled, 'cancel wrap Kind');
      CheckEqual('transport', EHttpError(LWrapped).Op, 'cancel wrap Op=transport');
    finally
      LWrapped.Free;
    end;
  finally
    LCancel.Free;
  end;
end;

procedure TestHttpStatusText;
begin
  CheckEqual('Continue', HttpStatusText(100), '100');
  CheckEqual('OK', HttpStatusText(200), '200');
  CheckEqual('Created', HttpStatusText(201), '201');
  CheckEqual('No Content', HttpStatusText(204), '204');
  CheckEqual('Moved Permanently', HttpStatusText(301), '301');
  CheckEqual('Found', HttpStatusText(302), '302');
  CheckEqual('See Other', HttpStatusText(HTTP_STATUS_SEE_OTHER), '303');
  CheckEqual('Not Modified', HttpStatusText(304), '304');
  CheckEqual('Bad Request', HttpStatusText(400), '400');
  CheckEqual('Unauthorized', HttpStatusText(401), '401');
  CheckEqual('Forbidden', HttpStatusText(403), '403');
  CheckEqual('Not Found', HttpStatusText(404), '404');
  CheckEqual('Method Not Allowed', HttpStatusText(405), '405');
  CheckEqual('Proxy Authentication Required',
    HttpStatusText(HTTP_STATUS_PROXY_AUTH_REQUIRED), '407');
  CheckEqual('Internal Server Error', HttpStatusText(500), '500');
  CheckEqual('Expectation Failed', HttpStatusText(417), '417');
  CheckEqual('Bad Gateway', HttpStatusText(502), '502');
  CheckEqual('Service Unavailable', HttpStatusText(503), '503');
  CheckEqual('999', HttpStatusText(999), '999 unknown');
end;

procedure TestHttpStatusClassHelpers;
begin
  Check(not HttpStatusIsInformational(99), '99 is not informational');
  Check(HttpStatusIsInformational(100), '100 is informational');
  Check(HttpStatusIsInformational(199), '199 is informational');
  Check(not HttpStatusIsInformational(200), '200 is not informational');

  Check(not HttpStatusIsSuccess(199), '199 is not success');
  Check(HttpStatusIsSuccess(200), '200 is success');
  Check(HttpStatusIsSuccess(299), '299 is success');
  Check(not HttpStatusIsSuccess(300), '300 is not success');

  Check(not HttpStatusIsRedirect(299), '299 is not redirect');
  Check(HttpStatusIsRedirect(300), '300 is redirect');
  Check(HttpStatusIsRedirect(399), '399 is redirect');
  Check(not HttpStatusIsRedirect(400), '400 is not redirect');

  Check(not HttpStatusIsClientError(399), '399 is not client error');
  Check(HttpStatusIsClientError(400), '400 is client error');
  Check(HttpStatusIsClientError(499), '499 is client error');
  Check(not HttpStatusIsClientError(500), '500 is not client error');

  Check(not HttpStatusIsServerError(499), '499 is not server error');
  Check(HttpStatusIsServerError(500), '500 is server error');
  Check(HttpStatusIsServerError(599), '599 is server error');
  Check(not HttpStatusIsServerError(600), '600 is not server error');
end;

procedure TestHttpVersionToStr;
begin
  CheckEqual('HTTP/1.0', HttpVersionToStr(hvHttp10), '1.0');
  CheckEqual('HTTP/1.1', HttpVersionToStr(hvHttp11), '1.1');
  CheckEqual('HTTP/2', HttpVersionToStr(hvHttp2), '2');
  CheckEqual('HTTP/3', HttpVersionToStr(hvHttp3), '3');
end;

procedure TestUrlParseFullUrl;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('http://example.com:8080/path/to?key=val#frag');
  CheckEqual('http', LUrl.Scheme, 'scheme');
  CheckEqual('example.com', LUrl.Host, 'host');
  CheckEqual(Int64(8080), Int64(LUrl.Port), 'port');
  CheckEqual('/path/to', LUrl.Path, 'path');
  CheckEqual('key=val', LUrl.RawQuery, 'query');
  CheckEqual('frag', LUrl.Fragment, 'fragment');
  CheckEqual('', LUrl.UserInfo, 'no userinfo');
end;

procedure TestUrlParseWithUserInfo;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('http://user:pass@host.io/path');
  CheckEqual('http', LUrl.Scheme, 'scheme');
  CheckEqual('user:pass', LUrl.UserInfo, 'userinfo');
  CheckEqual('host.io', LUrl.Host, 'host');
  CheckEqual(Int64(0), Int64(LUrl.Port), 'port default');
  CheckEqual('/path', LUrl.Path, 'path');
end;

procedure TestUrlParseRelativePath;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('/api/v1?page=2');
  CheckEqual('', LUrl.Scheme, 'no scheme');
  CheckEqual('', LUrl.Host, 'no host');
  CheckEqual(Int64(0), Int64(LUrl.Port), 'no port');
  CheckEqual('/api/v1', LUrl.Path, 'path');
  CheckEqual('page=2', LUrl.RawQuery, 'query');
end;

procedure TestUrlParseWithPort;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('https://localhost:443/secure');
  CheckEqual('https', LUrl.Scheme, 'scheme');
  CheckEqual('localhost', LUrl.Host, 'host');
  CheckEqual(Int64(443), Int64(LUrl.Port), 'port');
  CheckEqual('/secure', LUrl.Path, 'path');
end;

procedure CheckUrlParseRejectsInvalidPort(const AUrl, AContext: string);
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    TUrl.Parse(AUrl);
  except
    on E: EHttpError do
      LCaught := True;
  end;
  Check(LCaught, AContext + ' raises EHttpError');
end;

procedure TestUrlParseInvalidPortRaises;
begin
  CheckUrlParseRejectsInvalidPort('http://example.com:notaport/path',
    'hostname invalid port');
  CheckUrlParseRejectsInvalidPort('http://[::1]:bad/path',
    'bracketed IPv6 invalid port');
end;

procedure TestUrlParseEmptyRaises;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    TUrl.Parse('');
  except
    on E: EHttpError do
      LCaught := True;
  end;
  Check(LCaught, 'empty URL raises EHttpError');
end;

procedure TestUrlToString;
var
  LUrl: TUrl;
  LStr: string;
begin
  LUrl := TUrl.Parse('http://example.com:8080/path?q=1#top');
  LStr := LUrl.ToString;
  CheckEqual('http://example.com:8080/path?q=1#top', LStr, 'round-trip');
end;

procedure TestUrlRedacted;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse(
    'https://user:s3cret@sub.example.com:8443/clash?token=abcd1234#frag');
  CheckEqual('https://sub.example.com:8443', LUrl.Redacted,
    'strips userinfo path query fragment');
  Check(Pos('s3cret', LUrl.Redacted) = 0, 'secret not in redacted');
  Check(Pos('token=', LUrl.Redacted) = 0, 'query not in redacted');
  CheckEqual(
    'https://user:s3cret@sub.example.com:8443/clash?token=abcd1234#frag',
    LUrl.ToString, 'ToString still complete');

  LUrl := TUrl.Parse('http://example.com/path?q=1');
  CheckEqual('http://example.com', LUrl.Redacted, 'default port omitted');

  LUrl := TUrl.Parse('https://user:pw@[2001:db8::1]:8443/ss?token=x#f');
  CheckEqual('https://[2001:db8::1]:8443', LUrl.Redacted,
    'ipv6 keeps brackets and port');
end;

procedure TestUrlHostPort;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('http://example.com:9090/x');
  CheckEqual('example.com:9090', LUrl.HostPort, 'with port');

  LUrl := TUrl.Parse('http://example.com/x');
  CheckEqual('example.com', LUrl.HostPort, 'without port');

  LUrl := TUrl.Parse('http://[::1]:9090/x');
  CheckEqual('[::1]:9090', LUrl.HostPort, 'ipv6 with port');

  LUrl := TUrl.Parse('http://[fe80::1]/x');
  CheckEqual('[fe80::1]', LUrl.HostPort, 'ipv6 without port');
end;

procedure TestUrlParseIPv6;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('http://[::1]:8080/path');
  CheckEqual('::1', LUrl.Host, 'ipv6 host');
  CheckEqual(UInt16(8080), LUrl.Port, 'ipv6 port');
  CheckEqual('/path', LUrl.Path, 'ipv6 path');

  LUrl := TUrl.Parse('http://[fe80::1]/index');
  CheckEqual('fe80::1', LUrl.Host, 'ipv6 no port host');
  CheckEqual(UInt16(0), LUrl.Port, 'ipv6 no port');
end;

procedure TestUrlParseRequestTargetOriginForm;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.ParseRequestTarget('/api/v1?page=2#frag');
  CheckEqual('', LUrl.Scheme, 'no scheme');
  CheckEqual('', LUrl.UserInfo, 'no userinfo');
  CheckEqual('', LUrl.Host, 'no host');
  CheckEqual(UInt16(0), LUrl.Port, 'no port');
  CheckEqual('/api/v1', LUrl.Path, 'path');
  CheckEqual('page=2', LUrl.RawQuery, 'query');
  CheckEqual('frag', LUrl.Fragment, 'fragment');
end;

procedure TestUrlParseRequestTargetPathOnly;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.ParseRequestTarget('/api/v1');
  CheckEqual('', LUrl.Scheme, 'no scheme');
  CheckEqual('', LUrl.Host, 'no host');
  CheckEqual('/api/v1', LUrl.Path, 'path');
  CheckEqual('', LUrl.RawQuery, 'no query');
  CheckEqual('', LUrl.Fragment, 'no fragment');
end;

procedure TestUrlParseRequestTargetAbsoluteForm;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.ParseRequestTarget('http://example.com:8080/proxy?q=1#top');
  CheckEqual('http', LUrl.Scheme, 'scheme');
  CheckEqual('example.com', LUrl.Host, 'host');
  CheckEqual(UInt16(8080), LUrl.Port, 'port');
  CheckEqual('/proxy', LUrl.Path, 'path');
  CheckEqual('q=1', LUrl.RawQuery, 'query');
  CheckEqual('top', LUrl.Fragment, 'fragment');
end;

procedure TestUrlParseRequestTargetAsteriskForm;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.ParseRequestTarget('*');
  CheckEqual('', LUrl.Scheme, 'no scheme');
  CheckEqual('', LUrl.Host, 'no host');
  CheckEqual(UInt16(0), LUrl.Port, 'no port');
  CheckEqual('*', LUrl.Path, 'asterisk path');
  CheckEqual('', LUrl.RawQuery, 'no query');
  CheckEqual('', LUrl.Fragment, 'no fragment');
end;

procedure TestUrlParseRequestTargetAuthorityForm;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.ParseRequestTarget('example.com:443');
  CheckEqual('', LUrl.Scheme, 'no scheme');
  CheckEqual('', LUrl.Host, 'authority is not parsed as URL host');
  CheckEqual(UInt16(0), LUrl.Port, 'authority port is not parsed as URL port');
  CheckEqual('example.com:443', LUrl.Path, 'authority target is preserved as path');
  CheckEqual('', LUrl.RawQuery, 'no query');
  CheckEqual('', LUrl.Fragment, 'no fragment');
end;

procedure TestUrlParseRequestTargetOriginFormWithSchemeLikePath;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.ParseRequestTarget('/http://example.com/path?q=1');
  CheckEqual('', LUrl.Scheme, 'origin-form keeps scheme-like path unparsed');
  CheckEqual('', LUrl.Host, 'no host');
  CheckEqual('/http://example.com/path', LUrl.Path, 'path');
  CheckEqual('q=1', LUrl.RawQuery, 'query');
end;

procedure TestUrlParseRequestTargetEmptyRaises;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    TUrl.ParseRequestTarget('');
  except
    on E: EHttpError do
      LCaught := True;
  end;
  Check(LCaught, 'empty request-target raises EHttpError');
end;

procedure TestHttpClientOptionsDefault;
var
  LOptions: THttpClientOptions;
begin
  LOptions := THttpClientOptions.Default;
  CheckEqual(Int64(30000), LOptions.Timeout, 'default timeout');
  CheckEqual(Int64(0), LOptions.ConnectTimeout, 'default ConnectTimeout is 0');
  CheckEqual(LOptions.Timeout, LOptions.EffectiveConnectTimeout,
    'ConnectTimeout=0 falls back to Timeout');
  CheckEqual(Int64(10), Int64(LOptions.MaxRedirects), 'default max redirects');
  Check(LOptions.FollowRedirects, 'default follows redirects');
  Check(LOptions.Version = hvHttp11, 'default client version field');
  Check(LOptions.UseRegistryVersion, 'default client uses registry version');
  Check(LOptions.TLSContext = nil, 'default client TLS context is nil');
end;

procedure TestHttpClientOptionsWithTLSContextFluent;
var
  LOptions: THttpClientOptions;
begin
  { Nil clear path: WithTLSContext(nil) keeps/clears field without crash. }
  LOptions := THttpClientOptions.Default
    .WithTimeout(15000)
    .WithTLSContext(nil)
    .WithProxyUrl('http://127.0.0.1:8080');
  CheckEqual(Int64(15000), LOptions.Timeout, 'fluent chain keeps timeout');
  Check(LOptions.TLSContext = nil, 'WithTLSContext(nil) is nil');
  CheckEqual('http://127.0.0.1:8080', LOptions.ProxyUrl, 'fluent chain keeps proxy');
end;

procedure TestHttpServerOptionsDefault;
var
  LOptions: THttpServerOptions;
begin
  LOptions := THttpServerOptions.Default;
  Check(LOptions.Backend = TCP_SERVER_BACKEND_THREADED, 'default backend');
  CheckEqual(Int64(30000), LOptions.ReadTimeout, 'default read timeout PD-1B');
  CheckEqual(Int64(30000), LOptions.WriteTimeout, 'default write timeout PD-1B');
  CheckEqual(Int64(30000), LOptions.IdleTimeout, 'default idle timeout');
  CheckEqual(Int64(8192), Int64(LOptions.MaxHeaderSize), 'default max header size');
  CheckEqual(Int64(4194304), LOptions.MaxBodySize, 'default max body size');
  Check(LOptions.Version = hvHttp11, 'default server version field');
  Check(LOptions.UseRegistryVersion, 'default server uses registry version');
  Check(LOptions.TLSContext = nil, 'default server TLS context is nil');
  Check(not LOptions.RequestArena, 'default RequestArena off');
  CheckEqual(Int64(0), Int64(LOptions.RequestArenaCapacity), 'default arena cap 0');
  LOptions := LOptions.WithRequestArena(4096);
  Check(LOptions.RequestArena, 'WithRequestArena enables');
  CheckEqual(Int64(4096), Int64(LOptions.RequestArenaCapacity), 'WithRequestArena cap');
end;

procedure TestHttpServerOptionsProduction;
var
  LDefault: THttpServerOptions;
  LProd: THttpServerOptions;
begin
  LDefault := THttpServerOptions.Default;
  LProd := THttpServerOptions.Production;
  CheckEqual(Int64(30000), LDefault.ReadTimeout, 'Default ReadTimeout is 30000');
  CheckEqual(Int64(30000), LDefault.WriteTimeout, 'Default WriteTimeout is 30000');
  CheckEqual(Int64(30000), LProd.ReadTimeout, 'Production ReadTimeout is 30000');
  CheckEqual(Int64(30000), LProd.WriteTimeout, 'Production WriteTimeout is 30000');
  CheckEqual(LDefault.IdleTimeout, LProd.IdleTimeout,
    'Production keeps Default IdleTimeout');
  CheckEqual(Int64(LDefault.MaxHeaderSize), Int64(LProd.MaxHeaderSize),
    'Production keeps Default MaxHeaderSize');
  CheckEqual(LDefault.MaxBodySize, LProd.MaxBodySize,
    'Production keeps Default MaxBodySize');
end;

procedure TestServerDefaultVsProductionSourceContract;
{ PD-1B: Default RW=30000; Production named template same RW;
  arena convenience factory must not inherit unbounded RW. }
var
  LBase, LFacade, LServer, LContract, LReadme: string;
begin
  LBase := ReadFileText('../../../src/nextpas.core.http.base.pas');
  LFacade := ReadFileText('../../../src/nextpas.core.http.pas');
  LServer := ReadFileText('../../../src/nextpas.core.http.server.pas');
  LContract := ReadFileText('../../../docs/http/CONTRACT.md');
  LReadme := ReadFileText('../../../docs/http/README.md');
  Check(Pos('Result.ReadTimeout := 30000;', LBase) > 0,
    'Default/Production ReadTimeout 30000 in base');
  Check(Pos('Result.WriteTimeout := 30000;', LBase) > 0,
    'Default/Production WriteTimeout 30000 in base');
  Check(Pos('PD-1B', LBase) > 0, 'base documents PD-1B');
  Check(Pos('THttpServerOptions.Default', LServer) > 0,
    'NewHttpServer(handler) still uses Default');
  Check(Pos('THttpServerOptions.Production.WithRequestArena', LFacade) > 0,
    'arena convenience factory bases on Production');
  Check(Pos('Production', LContract) > 0, 'CONTRACT documents Production');
  Check(Pos('ReadTimeout', LContract) > 0, 'CONTRACT mentions ReadTimeout');
  Check(Pos('IdleTimeout', LContract) > 0, 'CONTRACT documents IdleTimeout');
  Check(Pos('IdleTTL', LContract) > 0, 'CONTRACT documents IdleTTL');
  Check(Pos('Production checklist', LReadme) > 0,
    'README has Production checklist section');
  Check(Pos('THttpServerOptions.Production', LReadme) > 0,
    'README points Production for servers');
end;

procedure TestIdleTimeoutVsIdleTTLSpotCheck;
{ PD-3-1: server IdleTimeout vs client IdleTTL are different knobs. }
var
  LServer: THttpServerOptions;
  LClient: THttpClientOptions;
begin
  LServer := THttpServerOptions.Default;
  LClient := THttpClientOptions.Default;
  CheckEqual(Int64(30000), LServer.IdleTimeout,
    'server IdleTimeout default 30s (keep-alive wait on connection)');
  CheckEqual(Int64(90000), LClient.IdleTTL,
    'client IdleTTL default 90s (pool wall-clock idle eviction)');
  Check(LServer.IdleTimeout <> LClient.IdleTTL,
    'IdleTimeout and IdleTTL are not the same default — do not confuse');
  LClient := LClient.WithIdleTTL(0);
  CheckEqual(Int64(0), LClient.IdleTTL, 'IdleTTL=0 disables wall-clock eviction');
  LServer := LServer.WithIdleTimeout(0);
  CheckEqual(Int64(0), LServer.IdleTimeout, 'IdleTimeout=0 means no idle close budget');
end;

procedure TestHttpOptionsWithVersion;
var
  LClientOptions: THttpClientOptions;
  LServerOptions: THttpServerOptions;
begin
  LClientOptions := THttpClientOptions.Default.WithVersion(hvHttp2);
  Check(LClientOptions.Version = hvHttp2, 'client WithVersion stores explicit version');
  Check(not LClientOptions.UseRegistryVersion,
    'client WithVersion disables registry version');

  LServerOptions := THttpServerOptions.Default.WithVersion(hvHttp2);
  Check(LServerOptions.Version = hvHttp2, 'server WithVersion stores explicit version');
  Check(not LServerOptions.UseRegistryVersion,
    'server WithVersion disables registry version');
end;

procedure TestHttpOptionsWithTimeout;
var
  LOptions: THttpClientOptions;
begin
  LOptions := THttpClientOptions.Default.WithTimeout(5000);
  Check(LOptions.Timeout = 5000, 'WithTimeout stores value');
  Check(LOptions.MaxRedirects = 10, 'other fields preserved');
end;

procedure TestHttpOptionsWithMaxRedirects;
var
  LOptions: THttpClientOptions;
begin
  LOptions := THttpClientOptions.Default.WithMaxRedirects(3);
  Check(LOptions.MaxRedirects = 3, 'WithMaxRedirects stores value');
  Check(LOptions.Timeout = 30000, 'other fields preserved');
end;

procedure TestHttpOptionsWithFollowRedirects;
var
  LOptions: THttpClientOptions;
begin
  LOptions := THttpClientOptions.Default.WithFollowRedirects(False);
  Check(not LOptions.FollowRedirects, 'WithFollowRedirects stores false');
  LOptions := LOptions.WithFollowRedirects(True);
  Check(LOptions.FollowRedirects, 'WithFollowRedirects stores true');
end;

procedure TestHttpOptionsWithMaxPoolSize;
var
  LOptions: THttpClientOptions;
begin
  LOptions := THttpClientOptions.Default.WithMaxPoolSize(16);
  Check(LOptions.MaxPoolSize = 16, 'WithMaxPoolSize stores value');
  Check(LOptions.Timeout = 30000, 'other fields preserved');
end;

procedure TestHttpOptionsFluentChain;
var
  LOptions: THttpClientOptions;
begin
  LOptions := THttpClientOptions.Default
    .WithTimeout(10000)
    .WithMaxRedirects(5)
    .WithFollowRedirects(False)
    .WithMaxPoolSize(32);
  Check(LOptions.Timeout = 10000, 'timeout chained');
  Check(LOptions.MaxRedirects = 5, 'max redirects chained');
  Check(not LOptions.FollowRedirects, 'follow redirects chained');
  Check(LOptions.MaxPoolSize = 32, 'max pool size chained');
end;

begin
  T := TTestSuite.Create('nextpas.core.http.base');
  T.Test('HttpMethodToStr', @TestHttpMethodToStr);
  T.Test('HttpStrToMethod', @TestHttpStrToMethod);
  T.Test('EHttpError category', @TestHttpErrorCategory);
  T.Test('HttpError Kind helpers', @TestHttpErrorKindHelpers);
  T.Test('EHttpError CreateOp taxonomy', @TestHttpErrorCreateOpTaxonomy);
  T.Test('HttpStatusText', @TestHttpStatusText);
  T.Test('HttpStatus class helpers', @TestHttpStatusClassHelpers);
  T.Test('HttpVersionToStr', @TestHttpVersionToStr);
  T.Test('TUrl.Parse full URL', @TestUrlParseFullUrl);
  T.Test('TUrl.Parse with userinfo', @TestUrlParseWithUserInfo);
  T.Test('TUrl.Parse relative path', @TestUrlParseRelativePath);
  T.Test('TUrl.Parse with port', @TestUrlParseWithPort);
  T.Test('TUrl.Parse invalid port raises', @TestUrlParseInvalidPortRaises);
  T.Test('TUrl.Parse empty raises', @TestUrlParseEmptyRaises);
  T.Test('TUrl.ToString round-trip', @TestUrlToString);
  T.Test('TUrl.Redacted strips credentials', @TestUrlRedacted);
  T.Test('TUrl.HostPort', @TestUrlHostPort);
  T.Test('TUrl.Parse IPv6', @TestUrlParseIPv6);
  T.Test('TUrl.ParseRequestTarget origin-form', @TestUrlParseRequestTargetOriginForm);
  T.Test('TUrl.ParseRequestTarget path-only', @TestUrlParseRequestTargetPathOnly);
  T.Test('TUrl.ParseRequestTarget absolute-form', @TestUrlParseRequestTargetAbsoluteForm);
  T.Test('TUrl.ParseRequestTarget asterisk-form', @TestUrlParseRequestTargetAsteriskForm);
  T.Test('TUrl.ParseRequestTarget authority-form', @TestUrlParseRequestTargetAuthorityForm);
  T.Test('TUrl.ParseRequestTarget scheme-like origin-form', @TestUrlParseRequestTargetOriginFormWithSchemeLikePath);
  T.Test('TUrl.ParseRequestTarget empty raises', @TestUrlParseRequestTargetEmptyRaises);
  T.Test('THttpClientOptions.Default', @TestHttpClientOptionsDefault);
  T.Test('THttpClientOptions.WithTLSContext fluent',
    @TestHttpClientOptionsWithTLSContextFluent);
  T.Test('THttpServerOptions.Default', @TestHttpServerOptionsDefault);
  T.Test('THttpServerOptions.Production', @TestHttpServerOptionsProduction);
  T.Test('Server Default vs Production source-contract (PD-1B)',
    @TestServerDefaultVsProductionSourceContract);
  T.Test('IdleTimeout vs IdleTTL spot-check (PD-3-1)',
    @TestIdleTimeoutVsIdleTTLSpotCheck);
  T.Test('HTTP options WithVersion', @TestHttpOptionsWithVersion);
  T.Test('HTTP options WithTimeout', @TestHttpOptionsWithTimeout);
  T.Test('HTTP options WithMaxRedirects', @TestHttpOptionsWithMaxRedirects);
  T.Test('HTTP options WithFollowRedirects', @TestHttpOptionsWithFollowRedirects);
  T.Test('HTTP options WithMaxPoolSize', @TestHttpOptionsWithMaxPoolSize);
  T.Test('HTTP options fluent chain', @TestHttpOptionsFluentChain);
  if not T.Run then Halt(1);
end.
