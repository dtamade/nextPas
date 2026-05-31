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

procedure TestHttpStatusText;
begin
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

begin
  T := TTestRunner.Create('nextpas.core.http.base');
  T.Run('HttpMethodToStr', @TestHttpMethodToStr);
  T.Run('HttpStrToMethod', @TestHttpStrToMethod);
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
  T.Summary;
end.
