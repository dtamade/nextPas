program test_http_cookie;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.base,
  nextpas.core.http.base,
  nextpas.core.http.headers,
  nextpas.core.http.intf,
  nextpas.core.http.cookie;

procedure TestParseSimpleCookie;
var
  LCookies: TRequestCookies;
begin
  LCookies := ParseCookies('session_id=abc123');
  CheckEqual('abc123', LCookies.Get('session_id'), 'session_id value');
  CheckEqual(Int64(1), Int64(LCookies.Count), 'count');
  Check(LCookies.Has('session_id'), 'has session_id');
end;

procedure TestParseMultipleCookies;
var
  LCookies: TRequestCookies;
begin
  LCookies := ParseCookies('name1=value1; name2=value2; name3=value3');
  CheckEqual('value1', LCookies.Get('name1'), 'name1');
  CheckEqual('value2', LCookies.Get('name2'), 'name2');
  CheckEqual('value3', LCookies.Get('name3'), 'name3');
  CheckEqual(Int64(3), Int64(LCookies.Count), 'count');
end;

procedure TestParseEmptyCookie;
var
  LCookies: TRequestCookies;
begin
  LCookies := ParseCookies('');
  CheckEqual(Int64(0), Int64(LCookies.Count), 'empty count');
end;

procedure TestParseQuotedValue;
var
  LCookies: TRequestCookies;
begin
  LCookies := ParseCookies('name="quoted value"');
  CheckEqual('quoted value', LCookies.Get('name'), 'quoted');
end;

procedure TestParseWhitespace;
var
  LCookies: TRequestCookies;
begin
  LCookies := ParseCookies('  name1 = value1 ;  name2 = value2  ');
  CheckEqual('value1', LCookies.Get('name1'), 'name1');
  CheckEqual('value2', LCookies.Get('name2'), 'name2');
end;

procedure TestParseMissingValue;
var
  LCookies: TRequestCookies;
begin
  LCookies := ParseCookies('name1=; name2=value2');
  CheckEqual('', LCookies.Get('name1'), 'name1 empty');
  CheckEqual('value2', LCookies.Get('name2'), 'name2');
  CheckEqual(Int64(2), Int64(LCookies.Count), 'count');
end;

procedure TestParseMissingEquals;
var
  LCookies: TRequestCookies;
begin
  LCookies := ParseCookies('name1; name2=value2');
  CheckEqual('', LCookies.Get('name1'), 'name1 no value');
  CheckEqual('value2', LCookies.Get('name2'), 'name2');
  CheckEqual(Int64(2), Int64(LCookies.Count), 'count');
end;

procedure TestCookieNotFound;
var
  LCookies: TRequestCookies;
begin
  LCookies := ParseCookies('name1=value1');
  CheckEqual('', LCookies.Get('nonexistent'), 'not found');
  Check(not LCookies.Has('nonexistent'), 'not has');
end;

procedure TestMakeCookie;
var
  LCookie: TSetCookie;
  LStr: string;
begin
  LCookie := MakeCookie('session', 'abc123');
  LStr := BuildSetCookie(LCookie);
  Check(Pos('session=abc123', LStr) > 0, 'has name=value');
  Check(Pos('Path=/', LStr) > 0, 'has Path=/');
end;

procedure TestSetCookieWithDomain;
var
  LStr: string;
begin
  LStr := BuildSetCookie(MakeCookie('s', 'v').WithDomain('example.com'));
  Check(Pos('Domain=example.com', LStr) > 0, 'has domain');
end;

procedure TestSetCookieWithHttpOnly;
var
  LStr: string;
begin
  LStr := BuildSetCookie(MakeCookie('s', 'v').WithHttpOnly(True));
  Check(Pos('HttpOnly', LStr) > 0, 'has httponly');
end;

procedure TestSetCookieWithSecure;
var
  LStr: string;
begin
  LStr := BuildSetCookie(MakeCookie('s', 'v').WithSecure(True));
  Check(Pos('Secure', LStr) > 0, 'has secure');
end;

procedure TestSetCookieWithSameSite;
var
  LStr: string;
begin
  LStr := BuildSetCookie(MakeCookie('s', 'v').WithSameSite(ssLax));
  Check(Pos('SameSite=Lax', LStr) > 0, 'has samesite');
end;

procedure TestSetCookieWithMaxAge;
var
  LStr: string;
begin
  LStr := BuildSetCookie(MakeCookie('s', 'v').WithMaxAge(3600));
  Check(Pos('Max-Age=3600', LStr) > 0, 'has max-age');
end;

procedure TestSetCookieWithExpires;
var
  LStr: string;
begin
  LStr := BuildSetCookie(MakeCookie('s', 'v').WithExpires('Sun, 06 Jul 2026 12:00:00 GMT'));
  Check(Pos('Expires=Sun, 06 Jul 2026 12:00:00 GMT', LStr) > 0, 'has expires');
end;

procedure TestSetCookieChaining;
var
  LCookie: TSetCookie;
  LStr: string;
begin
  LCookie := MakeCookie('session', 'abc123')
    .WithDomain('example.com')
    .WithPath('/api')
    .WithHttpOnly(True)
    .WithSecure(True)
    .WithSameSite(ssStrict)
    .WithMaxAge(7200);
  LStr := BuildSetCookie(LCookie);
  Check(Pos('session=abc123', LStr) > 0, 'name=value');
  Check(Pos('Domain=example.com', LStr) > 0, 'domain');
  Check(Pos('Path=/api', LStr) > 0, 'path');
  Check(Pos('HttpOnly', LStr) > 0, 'httponly');
  Check(Pos('Secure', LStr) > 0, 'secure');
  Check(Pos('SameSite=Strict', LStr) > 0, 'samesite');
  Check(Pos('Max-Age=7200', LStr) > 0, 'max-age');
end;

procedure TestSetCookieToString;
var
  LCookie: TSetCookie;
begin
  LCookie := MakeCookie('token', 'xyz').WithHttpOnly(True);
  CheckEqual(BuildSetCookie(LCookie), LCookie.ToString, 'ToString');
end;

procedure TestParseSingleCookie;
var
  LName, LValue: string;
begin
  Check(ParseSingleCookie('foo=bar', LName, LValue), 'result');
  CheckEqual('foo', LName, 'name');
  CheckEqual('bar', LValue, 'value');
end;

procedure TestParseSingleCookieNoValue;
var
  LName, LValue: string;
begin
  Check(ParseSingleCookie('foo', LName, LValue), 'result');
  CheckEqual('foo', LName, 'name');
  CheckEqual('', LValue, 'value');
end;

procedure TestSameSiteValues;
var
  LStr: string;
begin
  LStr := BuildSetCookie(MakeCookie('s', 'v').WithSameSite(ssStrict));
  Check(Pos('SameSite=Strict', LStr) > 0, 'strict');
  LStr := BuildSetCookie(MakeCookie('s', 'v').WithSameSite(ssNone));
  Check(Pos('SameSite=None', LStr) > 0, 'none');
  LStr := BuildSetCookie(MakeCookie('s', 'v').WithSameSite(ssLax));
  Check(Pos('SameSite=Lax', LStr) > 0, 'lax');
end;

procedure TestGetPair;
var
  LCookies: TRequestCookies;
  LName, LValue: string;
begin
  LCookies := ParseCookies('a=1; b=2; c=3');
  LCookies.GetPair(1, LName, LValue);
  CheckEqual('b', LName, 'name');
  CheckEqual('2', LValue, 'value');
end;

procedure TestGetPairOutOfRange;
var
  LCookies: TRequestCookies;
  LName, LValue: string;
begin
  LCookies := ParseCookies('a=1');
  LCookies.GetPair(99, LName, LValue);
  CheckEqual('', LName, 'name empty');
  CheckEqual('', LValue, 'value empty');
end;

procedure TestMakeCookieRejectsNonAsciiName;
begin
  try
    MakeCookie('na' + #$C3#$A9, 'value');
    Check(False, 'non-ASCII cookie name must raise');
  except
    on E: ECore do Check(True, 'non-ASCII cookie name rejected');
  end;
end;

procedure TestMakeCookieRejectsNonAsciiValue;
begin
  try
    MakeCookie('name', 'caf' + #$C3#$A9);
    Check(False, 'non-ASCII cookie value must raise');
  except
    on E: ECore do Check(True, 'non-ASCII cookie value rejected');
  end;
end;

procedure TestBuildCookieRejectsNonAsciiAttribute;
begin
  try
    BuildSetCookie(MakeCookie('name', 'value').WithDomain(
      'ex' + #$C3#$A4 + 'mple.com'));
    Check(False, 'non-ASCII cookie attribute must raise');
  except
    on E: ECore do Check(True, 'non-ASCII cookie attribute rejected');
  end;
end;

procedure TestJarDropsSameSiteNoneWithoutSecure;
var
  LJar: IHttpCookieJar;
  LHeaders: IHttpHeaders;
  LUrl: TUrl;
begin
  LJar := NewHttpCookieJar;
  LUrl := TUrl.Parse('https://example.com/');
  LHeaders := NewHttpHeaders;
  LHeaders.Add('set-cookie', 'x=1; SameSite=None; Path=/');
  LJar.StoreFromResponse(LUrl, LHeaders);
  CheckEqual('', LJar.CookieHeaderFor(LUrl),
    'SameSite=None without Secure is not stored');
end;

procedure TestJarDefaultSameSiteLaxSendsSameSite;
var
  LJar: IHttpCookieJar;
  LHeaders: IHttpHeaders;
  LUrl: TUrl;
  LCookie: string;
begin
  LJar := NewHttpCookieJar;
  LUrl := TUrl.Parse('http://example.com/app');
  LHeaders := NewHttpHeaders;
  LHeaders.Add('set-cookie', 'sess=abc; Path=/');
  LJar.StoreFromResponse(LUrl, LHeaders);
  LCookie := LJar.CookieHeaderFor(LUrl);
  Check(Pos('sess=abc', LCookie) > 0,
    'absent SameSite defaults to Lax and sends on same-site request');
end;

procedure TestHttpCookieSiteKeyETldPlusOne;
begin
  CheckEqual('example.com', HttpCookieSiteKey('example.com'), 'apex');
  CheckEqual('example.com', HttpCookieSiteKey('a.b.example.com'), 'subdomain');
  CheckEqual('foo.co.uk', HttpCookieSiteKey('foo.co.uk'), 'multi-label apex');
  CheckEqual('foo.co.uk', HttpCookieSiteKey('a.foo.co.uk'), 'multi-label sub');
  CheckEqual('bar.co.uk', HttpCookieSiteKey('www.bar.co.uk'), 'other multi-label');
  Check(HttpCookieSiteKey('a.foo.co.uk') <> HttpCookieSiteKey('a.bar.co.uk'),
    'distinct registrable domains under co.uk');
  CheckEqual('localhost', HttpCookieSiteKey('localhost'), 'localhost');
  CheckEqual('127.0.0.1', HttpCookieSiteKey('127.0.0.1'), 'ipv4');
  CheckEqual('github.io', HttpCookieSiteKey('github.io'), 'suffix host');
  CheckEqual('user.github.io', HttpCookieSiteKey('pages.user.github.io'),
    'github.io pages site');
end;

procedure TestJarRejectsPublicSuffixDomain;
var
  LJar: IHttpCookieJar;
  LHeaders: IHttpHeaders;
  LUrl: TUrl;
begin
  LJar := NewHttpCookieJar;
  LUrl := TUrl.Parse('https://a.foo.co.uk/');
  LHeaders := NewHttpHeaders;
  LHeaders.Add('set-cookie',
    'bad=1; Domain=co.uk; Path=/; SameSite=Lax; Secure');
  LJar.StoreFromResponse(LUrl, LHeaders);
  CheckEqual('', LJar.CookieHeaderFor(LUrl),
    'Domain=public-suffix is rejected (no super-cookie)');

  LHeaders := NewHttpHeaders;
  LHeaders.Add('set-cookie',
    'bad2=1; Domain=com; Path=/; SameSite=Lax; Secure');
  LJar.StoreFromResponse(TUrl.Parse('https://example.com/'), LHeaders);
  CheckEqual('', LJar.CookieHeaderFor(TUrl.Parse('https://example.com/')),
    'Domain=com single-label public suffix rejected');
end;

procedure TestJarMultiLabelTldSameSiteSharing;
var
  LJar: IHttpCookieJar;
  LHeaders: IHttpHeaders;
  LStoreUrl, LSiblingUrl, LOtherSiteUrl: TUrl;
  LCookie: string;
begin
  { Domain=foo.co.uk is registrable (eTLD+1); siblings share site; bar.co.uk does not. }
  LJar := NewHttpCookieJar;
  LStoreUrl := TUrl.Parse('https://a.foo.co.uk/');
  LSiblingUrl := TUrl.Parse('https://b.foo.co.uk/app');
  LOtherSiteUrl := TUrl.Parse('https://a.bar.co.uk/');
  LHeaders := NewHttpHeaders;
  LHeaders.Add('set-cookie',
    'sess=1; Domain=foo.co.uk; Path=/; SameSite=Lax; Secure');
  LJar.StoreFromResponse(LStoreUrl, LHeaders);

  LCookie := LJar.CookieHeaderFor(LSiblingUrl);
  Check(Pos('sess=1', LCookie) > 0,
    'multi-label eTLD+1 Domain sends to sibling host');

  LCookie := LJar.CookieHeaderFor(LOtherSiteUrl);
  Check(Pos('sess=1', LCookie) = 0,
    'other registrable domain under co.uk does not receive cookie');
end;

procedure TestJarSameSiteSendsOnRegistrableDomain;
var
  LJar: IHttpCookieJar;
  LHeaders: IHttpHeaders;
  LStoreUrl, LSubUrl: TUrl;
  LCookie: string;
begin
  LJar := NewHttpCookieJar;
  LStoreUrl := TUrl.Parse('https://www.example.com/');
  LSubUrl := TUrl.Parse('https://api.example.com/v1');
  LHeaders := NewHttpHeaders;
  LHeaders.Add('set-cookie',
    'lax=1; Domain=example.com; Path=/; SameSite=Lax; Secure');
  LHeaders.Add('set-cookie',
    'strict=1; Domain=example.com; Path=/; SameSite=Strict; Secure');
  LHeaders.Add('set-cookie',
    'none=1; Domain=example.com; Path=/; SameSite=None; Secure');
  LJar.StoreFromResponse(LStoreUrl, LHeaders);

  LCookie := LJar.CookieHeaderFor(LSubUrl);
  Check(Pos('lax=1', LCookie) > 0, 'same-site subdomain sends Lax');
  Check(Pos('strict=1', LCookie) > 0, 'same-site subdomain sends Strict');
  Check(Pos('none=1', LCookie) > 0, 'same-site subdomain sends None');
end;

var
  T: TTestSuite;
begin
  T := TTestSuite.Create('cookie');
  T.Test('ParseSimpleCookie', @TestParseSimpleCookie);
  T.Test('ParseMultipleCookies', @TestParseMultipleCookies);
  T.Test('ParseEmptyCookie', @TestParseEmptyCookie);
  T.Test('ParseQuotedValue', @TestParseQuotedValue);
  T.Test('ParseWhitespace', @TestParseWhitespace);
  T.Test('ParseMissingValue', @TestParseMissingValue);
  T.Test('ParseMissingEquals', @TestParseMissingEquals);
  T.Test('CookieNotFound', @TestCookieNotFound);
  T.Test('MakeCookie', @TestMakeCookie);
  T.Test('SetCookieWithDomain', @TestSetCookieWithDomain);
  T.Test('SetCookieWithHttpOnly', @TestSetCookieWithHttpOnly);
  T.Test('SetCookieWithSecure', @TestSetCookieWithSecure);
  T.Test('SetCookieWithSameSite', @TestSetCookieWithSameSite);
  T.Test('SetCookieWithMaxAge', @TestSetCookieWithMaxAge);
  T.Test('SetCookieWithExpires', @TestSetCookieWithExpires);
  T.Test('SetCookieChaining', @TestSetCookieChaining);
  T.Test('SetCookieToString', @TestSetCookieToString);
  T.Test('ParseSingleCookie', @TestParseSingleCookie);
  T.Test('ParseSingleCookieNoValue', @TestParseSingleCookieNoValue);
  T.Test('SameSiteValues', @TestSameSiteValues);
  T.Test('GetPair', @TestGetPair);
  T.Test('GetPairOutOfRange', @TestGetPairOutOfRange);
  T.Test('MakeCookieRejectsNonAsciiName', @TestMakeCookieRejectsNonAsciiName);
  T.Test('MakeCookieRejectsNonAsciiValue', @TestMakeCookieRejectsNonAsciiValue);
  T.Test('BuildCookieRejectsNonAsciiAttribute', @TestBuildCookieRejectsNonAsciiAttribute);
  T.Test('JarDropsSameSiteNoneWithoutSecure', @TestJarDropsSameSiteNoneWithoutSecure);
  T.Test('JarDefaultSameSiteLaxSendsSameSite', @TestJarDefaultSameSiteLaxSendsSameSite);
  T.Test('HttpCookieSiteKeyETldPlusOne', @TestHttpCookieSiteKeyETldPlusOne);
  T.Test('JarRejectsPublicSuffixDomain', @TestJarRejectsPublicSuffixDomain);
  T.Test('JarMultiLabelTldSameSiteSharing', @TestJarMultiLabelTldSameSiteSharing);
  T.Test('JarSameSiteSendsOnRegistrableDomain', @TestJarSameSiteSendsOnRegistrableDomain);
  if not T.Run then Halt(1);
end.
