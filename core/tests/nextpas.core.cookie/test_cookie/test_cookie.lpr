program test_cookie;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.cookie.base,
  nextpas.core.cookie;

var
  T: TTestRunner;

procedure TestParseSimple;
var
  LCookies: TCookieArray;
begin
  LCookies := ParseCookieHeader('name=value');
  CheckEqual(Int64(1), Int64(Length(LCookies)), 'count');
  CheckEqual('name', LCookies[0].Name, 'name');
  CheckEqual('value', LCookies[0].Value, 'value');
end;

procedure TestParseMultiple;
var
  LCookies: TCookieArray;
begin
  LCookies := ParseCookieHeader('a=1; b=2; c=3');
  CheckEqual(Int64(3), Int64(Length(LCookies)), 'count');
  CheckEqual('a', LCookies[0].Name, 'first name');
  CheckEqual('1', LCookies[0].Value, 'first value');
  CheckEqual('b', LCookies[1].Name, 'second name');
  CheckEqual('2', LCookies[1].Value, 'second value');
  CheckEqual('c', LCookies[2].Name, 'third name');
  CheckEqual('3', LCookies[2].Value, 'third value');
end;

procedure TestParseEmptyValue;
var
  LCookies: TCookieArray;
begin
  LCookies := ParseCookieHeader('name=');
  CheckEqual(Int64(1), Int64(Length(LCookies)), 'count');
  CheckEqual('name', LCookies[0].Name, 'name');
  CheckEqual('', LCookies[0].Value, 'empty value');
end;

procedure TestParseNoValue;
var
  LCookies: TCookieArray;
begin
  LCookies := ParseCookieHeader('name');
  CheckEqual(Int64(1), Int64(Length(LCookies)), 'count');
  CheckEqual('name', LCookies[0].Name, 'name');
  CheckEqual('', LCookies[0].Value, 'no value');
end;

procedure TestBuildCookieHeader;
var
  LCookies: array[0..2] of TCookie;
  LResult: string;
begin
  LCookies[0] := CookieOf('a', '1');
  LCookies[1] := CookieOf('b', '2');
  LCookies[2] := CookieOf('c', '3');
  LResult := BuildCookieHeader(LCookies);
  CheckEqual('a=1; b=2; c=3', LResult, 'built header');
end;

procedure TestBuildSetCookieAllAttrs;
var
  LC: TSetCookie;
  LResult: string;
begin
  LC := Default(TSetCookie);
  LC.Name := 'session';
  LC.Value := 'abc123';
  LC.Path := '/';
  LC.Domain := 'example.com';
  LC.MaxAge := 3600;
  LC.HasMaxAge := True;
  LC.Secure := True;
  LC.HttpOnly := True;
  LC.SameSite := cssStrict;
  LResult := BuildSetCookieHeader(LC);
  CheckEqual('session=abc123; Path=/; Domain=example.com; Max-Age=3600; Secure; HttpOnly; SameSite=Strict', LResult, 'full set-cookie');
end;

procedure TestParseSetCookieFlags;
var
  LC: TSetCookie;
begin
  LC := ParseSetCookieHeader('id=xyz; Path=/app; Secure; HttpOnly; SameSite=Lax');
  CheckEqual('id', LC.Name, 'name');
  CheckEqual('xyz', LC.Value, 'value');
  CheckEqual('/app', LC.Path, 'path');
  CheckEqual(True, LC.Secure, 'secure');
  CheckEqual(True, LC.HttpOnly, 'httponly');
  Check(LC.SameSite = cssLax, 'samesite lax');
end;

procedure TestParseSetCookieMaxAge;
var
  LC: TSetCookie;
begin
  LC := ParseSetCookieHeader('token=abc; Max-Age=7200');
  CheckEqual('token', LC.Name, 'name');
  CheckEqual('abc', LC.Value, 'value');
  CheckEqual(True, LC.HasMaxAge, 'has max-age');
  CheckEqual(Int64(7200), LC.MaxAge, 'max-age value');
end;

procedure TestTryFindCookieFound;
var
  LCookies: TCookieArray;
  LVal: string;
begin
  LCookies := ParseCookieHeader('x=10; y=20; z=30');
  Check(TryFindCookie(LCookies, 'y', LVal), 'found');
  CheckEqual('20', LVal, 'value');
end;

procedure TestTryFindCookieNotFound;
var
  LCookies: TCookieArray;
  LVal: string;
begin
  LCookies := ParseCookieHeader('x=10; y=20');
  Check(not TryFindCookie(LCookies, 'missing', LVal), 'not found');
  CheckEqual('', LVal, 'empty on miss');
end;

procedure TestInvalidInputEmpty;
var
  LCookies: TCookieArray;
  LOk: Boolean;
begin
  LCookies := ParseCookieHeader('');
  CheckEqual(Int64(0), Int64(Length(LCookies)), 'empty returns 0');
  LOk := TryParseCookieHeader('', LCookies);
  CheckEqual(False, LOk, 'try returns false');
end;

procedure TestCookieOf;
var
  LC: TCookie;
begin
  LC := CookieOf('test', 'val');
  CheckEqual('test', LC.Name, 'name');
  CheckEqual('val', LC.Value, 'value');
end;

procedure TestValidCookieName;
begin
  Check(IsValidCookieName('session'), 'simple name valid');
  Check(IsValidCookieName('my-cookie_123'), 'name with dash/underscore');
  Check(not IsValidCookieName(''), 'empty name invalid');
  Check(not IsValidCookieName('bad name'), 'space in name invalid');
  Check(not IsValidCookieName('bad;name'), 'semicolon in name invalid');
  Check(not IsValidCookieName('bad=name'), 'equals in name invalid');
  Check(not IsValidCookieName('bad' + #13 + 'name'), 'CR in name invalid');
  Check(not IsValidCookieName('bad' + #10 + 'name'), 'LF in name invalid');
  Check(not IsValidCookieName('bad' + #0 + 'name'), 'NUL in name invalid');
  Check(not IsValidCookieName('bad,name'), 'comma in name invalid');
  Check(not IsValidCookieName('bad"name'), 'quote in name invalid');
end;

procedure TestValidCookieValue;
begin
  Check(IsValidCookieValue('abc123'), 'simple value valid');
  Check(IsValidCookieValue(''), 'empty value valid');
  Check(IsValidCookieValue('path=/foo'), 'value with equals/slash');
  Check(not IsValidCookieValue('bad value'), 'space in value invalid');
  Check(not IsValidCookieValue('bad;value'), 'semicolon in value invalid');
  Check(not IsValidCookieValue('bad' + #13 + 'val'), 'CR in value invalid');
  Check(not IsValidCookieValue('bad' + #10 + 'val'), 'LF in value invalid');
  Check(not IsValidCookieValue('bad"val'), 'quote in value invalid');
  Check(not IsValidCookieValue('bad\val'), 'backslash in value invalid');
end;

procedure TestBuildRejectsInvalidName;
var
  LCookies: array[0..0] of TCookie;
  LRaised: Boolean;
begin
  LCookies[0] := CookieOf('bad' + #13#10 + 'name', 'value');
  LRaised := False;
  try
    BuildCookieHeader(LCookies);
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'BuildCookieHeader rejects CRLF in name');
end;

procedure TestBuildRejectsInvalidValue;
var
  LCookies: array[0..0] of TCookie;
  LRaised: Boolean;
begin
  LCookies[0] := CookieOf('name', 'val;ue');
  LRaised := False;
  try
    BuildCookieHeader(LCookies);
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'BuildCookieHeader rejects semicolon in value');
end;

procedure TestBuildSetCookieRejectsInvalid;
var
  LC: TSetCookie;
  LRaised: Boolean;
begin
  LC := Default(TSetCookie);
  LC.Name := 'ok';
  LC.Value := 'inject' + #13#10 + 'Set-Cookie: evil=1';
  LRaised := False;
  try
    BuildSetCookieHeader(LC);
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'BuildSetCookieHeader rejects CRLF injection');
end;

begin
  T := TTestRunner.Create('nextpas.core.cookie');
  T.Run('Parse simple', @TestParseSimple);
  T.Run('Parse multiple', @TestParseMultiple);
  T.Run('Parse empty value', @TestParseEmptyValue);
  T.Run('Parse no value', @TestParseNoValue);
  T.Run('Build cookie header', @TestBuildCookieHeader);
  T.Run('Build Set-Cookie all attrs', @TestBuildSetCookieAllAttrs);
  T.Run('Parse Set-Cookie flags', @TestParseSetCookieFlags);
  T.Run('Parse Set-Cookie Max-Age', @TestParseSetCookieMaxAge);
  T.Run('TryFindCookie found', @TestTryFindCookieFound);
  T.Run('TryFindCookie not found', @TestTryFindCookieNotFound);
  T.Run('Invalid input empty', @TestInvalidInputEmpty);
  T.Run('CookieOf helper', @TestCookieOf);
  T.Run('Valid cookie name', @TestValidCookieName);
  T.Run('Valid cookie value', @TestValidCookieValue);
  T.Run('Build rejects invalid name', @TestBuildRejectsInvalidName);
  T.Run('Build rejects invalid value', @TestBuildRejectsInvalidValue);
  T.Run('BuildSetCookie rejects CRLF', @TestBuildSetCookieRejectsInvalid);
  T.Summary;
end.
