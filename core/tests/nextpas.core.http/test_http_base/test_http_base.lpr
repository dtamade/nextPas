program test_http_base;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.http.base;

var
  T: TTestRunner;

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
    Check(LErr.Category = ecNetwork, 'EHttpError category is network');
    CheckEqual('network boundary', LErr.Message, 'EHttpError preserves message');
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
      Check(E.Category = ecNetwork, 'HttpStrToMethod error category is network');
    end;
  end;
  Check(LCaught, 'HttpStrToMethod raises EHttpError for invalid method');
end;

procedure TestHttpStatusText;
begin
  CheckEqual('Continue', HttpStatusText(100), '100');
  CheckEqual('OK', HttpStatusText(200), '200');
  CheckEqual('Created', HttpStatusText(201), '201');
  CheckEqual('No Content', HttpStatusText(204), '204');
  CheckEqual('Moved Permanently', HttpStatusText(301), '301');
  CheckEqual('Found', HttpStatusText(302), '302');
  CheckEqual('Not Modified', HttpStatusText(304), '304');
  CheckEqual('Bad Request', HttpStatusText(400), '400');
  CheckEqual('Unauthorized', HttpStatusText(401), '401');
  CheckEqual('Forbidden', HttpStatusText(403), '403');
  CheckEqual('Not Found', HttpStatusText(404), '404');
  CheckEqual('Method Not Allowed', HttpStatusText(405), '405');
  CheckEqual('Internal Server Error', HttpStatusText(500), '500');
  CheckEqual('Expectation Failed', HttpStatusText(417), '417');
  CheckEqual('Bad Gateway', HttpStatusText(502), '502');
  CheckEqual('Service Unavailable', HttpStatusText(503), '503');
  CheckEqual('Unknown', HttpStatusText(999), '999 unknown');
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

procedure TestUrlHostPort;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('http://example.com:9090/x');
  CheckEqual('example.com:9090', LUrl.HostPort, 'with port');

  LUrl := TUrl.Parse('http://example.com/x');
  CheckEqual('example.com', LUrl.HostPort, 'without port');
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
  CheckEqual(Int64(10), Int64(LOptions.MaxRedirects), 'default max redirects');
  Check(LOptions.FollowRedirects, 'default follows redirects');
end;

procedure TestHttpServerOptionsDefault;
var
  LOptions: THttpServerOptions;
begin
  LOptions := THttpServerOptions.Default;
  Check(LOptions.Backend = TCP_SERVER_BACKEND_THREADED, 'default backend');
  CheckEqual(Int64(0), LOptions.ReadTimeout, 'default read timeout');
  CheckEqual(Int64(0), LOptions.WriteTimeout, 'default write timeout');
  CheckEqual(Int64(30000), LOptions.IdleTimeout, 'default idle timeout');
  CheckEqual(Int64(8192), Int64(LOptions.MaxHeaderSize), 'default max header size');
  CheckEqual(Int64(4194304), LOptions.MaxBodySize, 'default max body size');
end;

begin
  T := TTestRunner.Create('nextpas.core.http.base');
  T.Run('HttpMethodToStr', @TestHttpMethodToStr);
  T.Run('HttpStrToMethod', @TestHttpStrToMethod);
  T.Run('EHttpError category', @TestHttpErrorCategory);
  T.Run('HttpStatusText', @TestHttpStatusText);
  T.Run('HttpVersionToStr', @TestHttpVersionToStr);
  T.Run('TUrl.Parse full URL', @TestUrlParseFullUrl);
  T.Run('TUrl.Parse with userinfo', @TestUrlParseWithUserInfo);
  T.Run('TUrl.Parse relative path', @TestUrlParseRelativePath);
  T.Run('TUrl.Parse with port', @TestUrlParseWithPort);
  T.Run('TUrl.Parse empty raises', @TestUrlParseEmptyRaises);
  T.Run('TUrl.ToString round-trip', @TestUrlToString);
  T.Run('TUrl.HostPort', @TestUrlHostPort);
  T.Run('TUrl.Parse IPv6', @TestUrlParseIPv6);
  T.Run('TUrl.ParseRequestTarget origin-form', @TestUrlParseRequestTargetOriginForm);
  T.Run('TUrl.ParseRequestTarget path-only', @TestUrlParseRequestTargetPathOnly);
  T.Run('TUrl.ParseRequestTarget absolute-form', @TestUrlParseRequestTargetAbsoluteForm);
  T.Run('TUrl.ParseRequestTarget asterisk-form', @TestUrlParseRequestTargetAsteriskForm);
  T.Run('TUrl.ParseRequestTarget authority-form', @TestUrlParseRequestTargetAuthorityForm);
  T.Run('TUrl.ParseRequestTarget scheme-like origin-form', @TestUrlParseRequestTargetOriginFormWithSchemeLikePath);
  T.Run('TUrl.ParseRequestTarget empty raises', @TestUrlParseRequestTargetEmptyRaises);
  T.Run('THttpClientOptions.Default', @TestHttpClientOptionsDefault);
  T.Run('THttpServerOptions.Default', @TestHttpServerOptionsDefault);
  T.Summary;
end.
