program test_http_url;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.errors,
  nextpas.core.http.base,
  nextpas.core.http.url;

var
  T: TTestRunner;

procedure TestUrlEncodeSimple;
begin
  CheckEqual('hello', UrlEncode('hello'), 'no special chars');
  CheckEqual('abc123', UrlEncode('abc123'), 'alphanumeric');
  CheckEqual('a-b_c.d~e', UrlEncode('a-b_c.d~e'), 'unreserved chars');
end;

procedure TestUrlEncodeSpaces;
begin
  CheckEqual('hello%20world', UrlEncode('hello world'), 'space becomes %20');
  CheckEqual('%20%20', UrlEncode('  '), 'multiple spaces');
end;

procedure TestUrlEncodeSpecialChars;
begin
  CheckEqual('%21%40%23%24%25', UrlEncode('!@#$%'), 'special chars');
  CheckEqual('%2F%3F%26%3D', UrlEncode('/?&='), 'url reserved chars');
  CheckEqual('%3C%3E%22', UrlEncode('<>"'), 'angle brackets and quote');
end;

procedure TestUrlDecodePercent;
begin
  CheckEqual('hello world', UrlDecode('hello%20world'), '%20 to space');
  CheckEqual('/', UrlDecode('%2F'), '%2F to slash');
  CheckEqual('a&b', UrlDecode('a%26b'), '%26 to ampersand');
end;

procedure TestUrlDecodePlus;
begin
  CheckEqual('hello world', UrlDecode('hello+world'), '+ to space');
  CheckEqual('a b c', UrlDecode('a+b+c'), 'multiple plus');
end;

procedure TestUrlDecodeInvalidRaises;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    UrlDecode('%2');
  except
    on E: EHttpError do
      LCaught := True;
  end;
  Check(LCaught, 'incomplete %XX raises');

  LCaught := False;
  try
    UrlDecode('%GG');
  except
    on E: EHttpError do
      LCaught := True;
  end;
  Check(LCaught, 'non-hex %XX raises');

  LCaught := False;
  try
    UrlDecode('abc%');
  except
    on E: EHttpError do
      LCaught := True;
  end;
  Check(LCaught, 'trailing % raises');
end;

procedure TestUrlEncodeDecodeRoundTrip;
var
  LOriginal, LEncoded, LDecoded: string;
begin
  LOriginal := 'hello world/foo?bar=baz&x=1 2';
  LEncoded := UrlEncode(LOriginal);
  LDecoded := UrlDecode(LEncoded);
  CheckEqual(LOriginal, LDecoded, 'round-trip');

  LOriginal := '~test-value_ok.txt';
  LEncoded := UrlEncode(LOriginal);
  CheckEqual(LOriginal, LEncoded, 'unreserved unchanged');
  LDecoded := UrlDecode(LEncoded);
  CheckEqual(LOriginal, LDecoded, 'unreserved round-trip');
end;

{ UrlDecodeQuery: '+' is interpreted as space (form-encoded behavior) }
procedure TestUrlDecodeQueryPlusToSpace;
begin
  CheckEqual('hello world', UrlDecodeQuery('hello+world'), '+ becomes space');
  CheckEqual('a b c', UrlDecodeQuery('a+b+c'), 'multiple +');
  CheckEqual('hello world', UrlDecodeQuery('hello%20world'), '%20 also becomes space');
end;

{ UrlDecodeQuery: percent-encoding works normally }
procedure TestUrlDecodeQueryPercent;
begin
  CheckEqual('hello world', UrlDecodeQuery('hello%20world'), '%20 to space');
  CheckEqual('/foo/bar', UrlDecodeQuery('%2Ffoo%2Fbar'), '%2F decoded');
end;

{ UrlDecodePath: '+' is treated as a literal character per RFC 3986 }
procedure TestUrlDecodePathPlusLiteral;
begin
  CheckEqual('report+2024.pdf', UrlDecodePath('report+2024.pdf'), '+ stays literal');
  CheckEqual('a+b+c', UrlDecodePath('a+b+c'), 'multiple + stay literal');
  CheckEqual('c++', UrlDecodePath('c++'), '+ at end');
end;

{ UrlDecodePath: percent-encoding still works normally }
procedure TestUrlDecodePathPercent;
begin
  CheckEqual('hello world', UrlDecodePath('hello%20world'), '%20 to space');
  CheckEqual('/foo/bar', UrlDecodePath('%2Ffoo%2Fbar'), '%2F decoded');
  CheckEqual('report+2024.pdf', UrlDecodePath('report%2B2024.pdf'), '%2B to +');
end;

{ UrlDecodePath: mixed '+' and percent-encoding }
procedure TestUrlDecodePathMixed;
begin
  CheckEqual('file name+2024.pdf', UrlDecodePath('file%20name+2024.pdf'),
    '%20 becomes space, + stays literal');
end;

{ UrlDecodePath: invalid percent-encoding still raises }
procedure TestUrlDecodePathInvalidRaises;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    UrlDecodePath('%2');
  except
    on E: EHttpError do
      LCaught := True;
  end;
  Check(LCaught, 'incomplete %XX raises in path');
end;

procedure TestParseQueryStringBasic;
var
  LParams: TQueryParams;
begin
  LParams := ParseQueryString('key=val');
  CheckEqual(Int64(1), Int64(Length(LParams)), 'count');
  CheckEqual('key', LParams[0].Name, 'name');
  CheckEqual('val', LParams[0].Value, 'value');
end;

procedure TestParseQueryStringMultiple;
var
  LParams: TQueryParams;
begin
  LParams := ParseQueryString('a=1&b=2&c=3');
  CheckEqual(Int64(3), Int64(Length(LParams)), 'count');
  CheckEqual('a', LParams[0].Name, 'name 0');
  CheckEqual('1', LParams[0].Value, 'value 0');
  CheckEqual('b', LParams[1].Name, 'name 1');
  CheckEqual('2', LParams[1].Value, 'value 1');
  CheckEqual('c', LParams[2].Name, 'name 2');
  CheckEqual('3', LParams[2].Value, 'value 2');
end;

procedure TestParseQueryStringEmptyValue;
var
  LParams: TQueryParams;
begin
  LParams := ParseQueryString('key=');
  CheckEqual(Int64(1), Int64(Length(LParams)), 'count');
  CheckEqual('key', LParams[0].Name, 'name');
  CheckEqual('', LParams[0].Value, 'empty value');
end;

procedure TestParseQueryStringNoValue;
var
  LParams: TQueryParams;
begin
  LParams := ParseQueryString('key');
  CheckEqual(Int64(1), Int64(Length(LParams)), 'count');
  CheckEqual('key', LParams[0].Name, 'name');
  CheckEqual('', LParams[0].Value, 'no = means empty value');
end;

procedure TestParseQueryStringEncoded;
var
  LParams: TQueryParams;
begin
  LParams := ParseQueryString('name=hello+world&path=%2Ffoo%2Fbar');
  CheckEqual(Int64(2), Int64(Length(LParams)), 'count');
  CheckEqual('name', LParams[0].Name, 'name 0');
  CheckEqual('hello world', LParams[0].Value, '+ decoded in value');
  CheckEqual('path', LParams[1].Name, 'name 1');
  CheckEqual('/foo/bar', LParams[1].Value, '%2F decoded');
end;

procedure TestEncodeQueryStringRoundTrip;
var
  LParams: TQueryParams;
  LEncoded: string;
  LParsed: TQueryParams;
begin
  SetLength(LParams, 3);
  LParams[0].Name := 'a'; LParams[0].Value := '1';
  LParams[1].Name := 'b'; LParams[1].Value := 'hello world';
  LParams[2].Name := 'path'; LParams[2].Value := '/foo/bar';

  LEncoded := EncodeQueryString(LParams);
  Check(Pos('a=1', LEncoded) > 0, 'contains a=1');
  Check(Pos('b=hello%20world', LEncoded) > 0, 'contains encoded space');
  Check(Pos('path=%2Ffoo%2Fbar', LEncoded) > 0, 'contains encoded path');

  LParsed := ParseQueryString(LEncoded);
  CheckEqual(Int64(3), Int64(Length(LParsed)), 'round-trip count');
  CheckEqual('a', LParsed[0].Name, 'rt name 0');
  CheckEqual('1', LParsed[0].Value, 'rt value 0');
  CheckEqual('b', LParsed[1].Name, 'rt name 1');
  CheckEqual('hello world', LParsed[1].Value, 'rt value 1');
  CheckEqual('path', LParsed[2].Name, 'rt name 2');
  CheckEqual('/foo/bar', LParsed[2].Value, 'rt value 2');
end;

procedure TestQueryParamValue;
var
  LParams: TQueryParams;
begin
  LParams := ParseQueryString('foo=bar&baz=qux');
  CheckEqual('bar', QueryParamValue(LParams, 'foo'), 'found foo');
  CheckEqual('qux', QueryParamValue(LParams, 'baz'), 'found baz');
  CheckEqual('', QueryParamValue(LParams, 'missing'), 'not found returns empty');
end;

procedure TestQueryParamHas;
var
  LParams: TQueryParams;
begin
  LParams := ParseQueryString('foo=bar&baz=qux');
  Check(QueryParamHas(LParams, 'foo'), 'has foo');
  Check(QueryParamHas(LParams, 'baz'), 'has baz');
  Check(not QueryParamHas(LParams, 'missing'), 'not has missing');
end;

begin
  T := TTestRunner.Create('nextpas.core.http.url');
  T.Run('UrlEncode simple', @TestUrlEncodeSimple);
  T.Run('UrlEncode spaces', @TestUrlEncodeSpaces);
  T.Run('UrlEncode special chars', @TestUrlEncodeSpecialChars);
  T.Run('UrlDecode percent', @TestUrlDecodePercent);
  T.Run('UrlDecode plus', @TestUrlDecodePlus);
  T.Run('UrlDecode invalid raises', @TestUrlDecodeInvalidRaises);
  T.Run('UrlEncode/Decode round-trip', @TestUrlEncodeDecodeRoundTrip);
  T.Run('UrlDecodeQuery + to space', @TestUrlDecodeQueryPlusToSpace);
  T.Run('UrlDecodeQuery percent', @TestUrlDecodeQueryPercent);
  T.Run('UrlDecodePath + literal', @TestUrlDecodePathPlusLiteral);
  T.Run('UrlDecodePath percent', @TestUrlDecodePathPercent);
  T.Run('UrlDecodePath mixed', @TestUrlDecodePathMixed);
  T.Run('UrlDecodePath invalid raises', @TestUrlDecodePathInvalidRaises);
  T.Run('ParseQueryString basic', @TestParseQueryStringBasic);
  T.Run('ParseQueryString multiple', @TestParseQueryStringMultiple);
  T.Run('ParseQueryString empty value', @TestParseQueryStringEmptyValue);
  T.Run('ParseQueryString no value', @TestParseQueryStringNoValue);
  T.Run('ParseQueryString encoded', @TestParseQueryStringEncoded);
  T.Run('EncodeQueryString round-trip', @TestEncodeQueryStringRoundTrip);
  T.Run('QueryParamValue', @TestQueryParamValue);
  T.Run('QueryParamHas', @TestQueryParamHas);
  T.Summary;
end.
