program test_http_url;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.test,
  nextpas.core.errors,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.http.message,
  nextpas.core.http.url;

var
  T: TTestSuite;

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

procedure TestUrlAddQueryBasic;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('http://example.com/path');
  LUrl := LUrl.AddQuery('key', 'value');
  CheckEqual('key=value', LUrl.RawQuery, 'raw query');
  CheckEqual('http://example.com/path?key=value', LUrl.ToString, 'to string');
end;

procedure TestUrlAddQueryMultiple;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('http://example.com/path');
  LUrl := LUrl.AddQuery('a', '1').AddQuery('b', '2');
  CheckEqual('a=1&b=2', LUrl.RawQuery, 'raw query');
  CheckEqual('http://example.com/path?a=1&b=2', LUrl.ToString, 'to string');
end;

procedure TestUrlAddQueryEncodesSpecialChars;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('http://example.com/');
  LUrl := LUrl.AddQuery('q', 'hello world&foo=bar');
  Check(Pos('q=hello+world', LUrl.RawQuery) = 1, 'space encoded as +');
  Check(Pos('%26', LUrl.RawQuery) > 0, '& encoded');
  Check(Pos('%3D', LUrl.RawQuery) > 0, '= encoded');
end;

procedure TestUrlAddQueryToExisting;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('http://example.com/path?existing=1');
  LUrl := LUrl.AddQuery('new', '2');
  CheckEqual('existing=1&new=2', LUrl.RawQuery, 'appended');
end;

procedure TestUrlWithQuery;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('http://example.com/path?old=1');
  LUrl := LUrl.WithQuery('new=2');
  CheckEqual('new=2', LUrl.RawQuery, 'replaced');
  CheckEqual('http://example.com/path?new=2', LUrl.ToString, 'to string');
end;

procedure TestUrlWithQueryEmpty;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('http://example.com/path?old=1');
  LUrl := LUrl.WithQuery('');
  CheckEqual('', LUrl.RawQuery, 'cleared');
  CheckEqual('http://example.com/path', LUrl.ToString, 'no question mark');
end;

procedure TestUrlGetQueryParam;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('http://example.com/path?foo=bar&baz=qux');
  CheckEqual('bar', LUrl.GetQueryParam('foo'), 'foo');
  CheckEqual('qux', LUrl.GetQueryParam('baz'), 'baz');
  CheckEqual('', LUrl.GetQueryParam('missing'), 'missing');
end;

procedure TestUrlGetQueryParamEmptyValue;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('http://example.com/path?empty=&full=x');
  CheckEqual('', LUrl.GetQueryParam('empty'), 'empty value');
  CheckEqual('x', LUrl.GetQueryParam('full'), 'full value');
end;

procedure TestUrlGetQueryParamNoValue;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('http://example.com/path?flag');
  CheckEqual('', LUrl.GetQueryParam('flag'), 'flag no value');
  Check(not LUrl.HasQueryParam('other'), 'other absent');
end;

procedure TestUrlHasQueryParam;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('http://example.com/path?foo=bar&empty');
  Check(LUrl.HasQueryParam('foo'), 'has foo');
  Check(LUrl.HasQueryParam('empty'), 'has empty');
  Check(not LUrl.HasQueryParam('missing'), 'not has missing');
end;

procedure TestUrlHasQueryParamNoQuery;
var
  LUrl: TUrl;
begin
  LUrl := TUrl.Parse('http://example.com/path');
  Check(not LUrl.HasQueryParam('foo'), 'no query string');
end;

procedure TestUrlAddQueryPreservesOtherFields;
var
  LUrl, LResult: TUrl;
begin
  LUrl.Scheme := 'https';
  LUrl.Host := 'example.com';
  LUrl.Port := 8443;
  LUrl.Path := '/api';
  LUrl.Fragment := 'section';
  LResult := LUrl.AddQuery('token', 'abc');
  CheckEqual('https', LResult.Scheme, 'scheme preserved');
  CheckEqual('example.com', LResult.Host, 'host preserved');
  Check(LResult.Port = 8443, 'port preserved');
  CheckEqual('/api', LResult.Path, 'path preserved');
  CheckEqual('section', LResult.Fragment, 'fragment preserved');
  CheckEqual('token=abc', LResult.RawQuery, 'query set');
end;

function MakeReq(const ARawQuery: string): IHttpRequest;
var
  LUrl: TUrl;
begin
  if ARawQuery = '' then
    LUrl := TUrl.Parse('http://example.com/path')
  else
    LUrl := TUrl.Parse('http://example.com/path?' + ARawQuery);
  Result := THttpRequest.Create(hmGet, LUrl, hvHttp11, nil, nil, 0);
end;

procedure TestQueryLimitMissing;
var
  LReq: IHttpRequest;
begin
  LReq := MakeReq('');
  CheckEqual(Int64(50), Int64(QueryLimitClamped(LReq, 'limit', 50, 500)), 'no query');
  LReq := MakeReq('other=1');
  CheckEqual(Int64(50), Int64(QueryLimitClamped(LReq, 'limit', 50, 500)), 'key absent');
end;

procedure TestQueryLimitNonInteger;
var
  LReq: IHttpRequest;
begin
  LReq := MakeReq('limit=abc');
  CheckEqual(Int64(50), Int64(QueryLimitClamped(LReq, 'limit', 50, 500)), 'alpha');
  LReq := MakeReq('limit=12x');
  CheckEqual(Int64(50), Int64(QueryLimitClamped(LReq, 'limit', 50, 500)), 'trailing junk');
  LReq := MakeReq('limit=');
  CheckEqual(Int64(50), Int64(QueryLimitClamped(LReq, 'limit', 50, 500)), 'empty value');
  LReq := MakeReq('limit=%2010');
  CheckEqual(Int64(10), Int64(QueryLimitClamped(LReq, 'limit', 50, 500)), 'Val skips leading space');
end;

procedure TestQueryLimitZeroNegative;
var
  LReq: IHttpRequest;
begin
  LReq := MakeReq('limit=0');
  CheckEqual(Int64(50), Int64(QueryLimitClamped(LReq, 'limit', 50, 500)), 'zero');
  LReq := MakeReq('limit=-5');
  CheckEqual(Int64(50), Int64(QueryLimitClamped(LReq, 'limit', 50, 500)), 'negative');
end;

procedure TestQueryLimitOverMax;
var
  LReq: IHttpRequest;
begin
  LReq := MakeReq('limit=600');
  CheckEqual(Int64(500), Int64(QueryLimitClamped(LReq, 'limit', 50, 500)), 'over max clamps');
  LReq := MakeReq('limit=9999999999');
  CheckEqual(Int64(500), Int64(QueryLimitClamped(LReq, 'limit', 50, 500)), 'beyond int32 clamps');
  LReq := MakeReq('limit=9999999999999999999999');
  CheckEqual(Int64(50), Int64(QueryLimitClamped(LReq, 'limit', 50, 500)), 'beyond int64 fails to default');
end;

procedure TestQueryLimitValid;
var
  LReq: IHttpRequest;
begin
  LReq := MakeReq('limit=10');
  CheckEqual(Int64(10), Int64(QueryLimitClamped(LReq, 'limit', 50, 500)), 'plain');
  LReq := MakeReq('limit=1');
  CheckEqual(Int64(1), Int64(QueryLimitClamped(LReq, 'limit', 50, 500)), 'lower bound');
  LReq := MakeReq('limit=500');
  CheckEqual(Int64(500), Int64(QueryLimitClamped(LReq, 'limit', 50, 500)), 'at max');
end;

procedure TestQueryLimitCustomDefault;
var
  LReq: IHttpRequest;
begin
  LReq := MakeReq('');
  CheckEqual(Int64(25), Int64(QueryLimitClamped(LReq, 'limit', 25, 500)), 'custom default');
  LReq := MakeReq('limit=oops');
  CheckEqual(Int64(25), Int64(QueryLimitClamped(LReq, 'limit', 25, 500)), 'custom default on junk');
end;

procedure TestQueryOffsetMissing;
var
  LReq: IHttpRequest;
begin
  LReq := MakeReq('');
  CheckEqual(Int64(0), Int64(QueryOffsetClamped(LReq, 'offset')), 'default default');
  CheckEqual(Int64(7), Int64(QueryOffsetClamped(LReq, 'offset', 7)), 'custom default');
end;

procedure TestQueryOffsetNonInteger;
var
  LReq: IHttpRequest;
begin
  LReq := MakeReq('offset=abc');
  CheckEqual(Int64(0), Int64(QueryOffsetClamped(LReq, 'offset')), 'alpha');
  LReq := MakeReq('offset=');
  CheckEqual(Int64(3), Int64(QueryOffsetClamped(LReq, 'offset', 3)), 'empty keeps custom default');
end;

procedure TestQueryOffsetNegative;
var
  LReq: IHttpRequest;
begin
  LReq := MakeReq('offset=-1');
  CheckEqual(Int64(0), Int64(QueryOffsetClamped(LReq, 'offset')), 'negative');
end;

procedure TestQueryOffsetHuge;
var
  LReq: IHttpRequest;
begin
  LReq := MakeReq('offset=9999999999');
  CheckEqual(Int64(0), Int64(QueryOffsetClamped(LReq, 'offset')), 'beyond int32 fails to default');
  LReq := MakeReq('offset=9999999999999999999999');
  CheckEqual(Int64(4), Int64(QueryOffsetClamped(LReq, 'offset', 4)), 'beyond int64 keeps default');
end;

procedure TestQueryOffsetValid;
var
  LReq: IHttpRequest;
begin
  LReq := MakeReq('offset=30');
  CheckEqual(Int64(30), Int64(QueryOffsetClamped(LReq, 'offset')), 'plain');
  LReq := MakeReq('offset=0');
  CheckEqual(Int64(0), Int64(QueryOffsetClamped(LReq, 'offset')), 'zero is valid offset');
end;

procedure TestQueryClampBadMaxRaises;
var
  LReq: IHttpRequest;
  LCaught: Boolean;
begin
  LReq := MakeReq('limit=10');
  LCaught := False;
  try
    QueryLimitClamped(LReq, 'limit', 50, 0);
  except
    on E: EHttpError do
      LCaught := E.Kind = hekArgument;
  end;
  Check(LCaught, 'max 0 raises hekArgument');
  LCaught := False;
  try
    QueryLimitClamped(LReq, 'limit', 50, -1);
  except
    on E: EHttpError do
      LCaught := E.Kind = hekArgument;
  end;
  Check(LCaught, 'negative max raises hekArgument');
end;

procedure TestQueryClampNilReqRaises;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    QueryLimitClamped(nil, 'limit', 50, 500);
  except
    on E: EHttpError do
      LCaught := E.Kind = hekArgument;
  end;
  Check(LCaught, 'nil req raises hekArgument (limit)');
  LCaught := False;
  try
    QueryOffsetClamped(nil, 'offset');
  except
    on E: EHttpError do
      LCaught := E.Kind = hekArgument;
  end;
  Check(LCaught, 'nil req raises hekArgument (offset)');
end;

begin
  T := TTestSuite.Create('nextpas.core.http.url');
  T.Test('UrlEncode simple', @TestUrlEncodeSimple);
  T.Test('UrlEncode spaces', @TestUrlEncodeSpaces);
  T.Test('UrlEncode special chars', @TestUrlEncodeSpecialChars);
  T.Test('UrlDecode percent', @TestUrlDecodePercent);
  T.Test('UrlDecode plus', @TestUrlDecodePlus);
  T.Test('UrlDecode invalid raises', @TestUrlDecodeInvalidRaises);
  T.Test('UrlEncode/Decode round-trip', @TestUrlEncodeDecodeRoundTrip);
  T.Test('UrlDecodeQuery + to space', @TestUrlDecodeQueryPlusToSpace);
  T.Test('UrlDecodeQuery percent', @TestUrlDecodeQueryPercent);
  T.Test('UrlDecodePath + literal', @TestUrlDecodePathPlusLiteral);
  T.Test('UrlDecodePath percent', @TestUrlDecodePathPercent);
  T.Test('UrlDecodePath mixed', @TestUrlDecodePathMixed);
  T.Test('UrlDecodePath invalid raises', @TestUrlDecodePathInvalidRaises);
  T.Test('ParseQueryString basic', @TestParseQueryStringBasic);
  T.Test('ParseQueryString multiple', @TestParseQueryStringMultiple);
  T.Test('ParseQueryString empty value', @TestParseQueryStringEmptyValue);
  T.Test('ParseQueryString no value', @TestParseQueryStringNoValue);
  T.Test('ParseQueryString encoded', @TestParseQueryStringEncoded);
  T.Test('EncodeQueryString round-trip', @TestEncodeQueryStringRoundTrip);
  T.Test('QueryParamValue', @TestQueryParamValue);
  T.Test('QueryParamHas', @TestQueryParamHas);
  T.Test('TUrl.AddQuery basic', @TestUrlAddQueryBasic);
  T.Test('TUrl.AddQuery multiple', @TestUrlAddQueryMultiple);
  T.Test('TUrl.AddQuery encodes special chars', @TestUrlAddQueryEncodesSpecialChars);
  T.Test('TUrl.AddQuery to existing', @TestUrlAddQueryToExisting);
  T.Test('TUrl.WithQuery replaces', @TestUrlWithQuery);
  T.Test('TUrl.WithQuery empty clears', @TestUrlWithQueryEmpty);
  T.Test('TUrl.GetQueryParam', @TestUrlGetQueryParam);
  T.Test('TUrl.GetQueryParam empty value', @TestUrlGetQueryParamEmptyValue);
  T.Test('TUrl.GetQueryParam no value', @TestUrlGetQueryParamNoValue);
  T.Test('TUrl.HasQueryParam', @TestUrlHasQueryParam);
  T.Test('TUrl.HasQueryParam no query', @TestUrlHasQueryParamNoQuery);
  T.Test('TUrl.AddQuery preserves other fields', @TestUrlAddQueryPreservesOtherFields);
  T.Test('QueryLimitClamped missing', @TestQueryLimitMissing);
  T.Test('QueryLimitClamped non-integer', @TestQueryLimitNonInteger);
  T.Test('QueryLimitClamped zero/negative', @TestQueryLimitZeroNegative);
  T.Test('QueryLimitClamped over max', @TestQueryLimitOverMax);
  T.Test('QueryLimitClamped valid', @TestQueryLimitValid);
  T.Test('QueryLimitClamped custom default', @TestQueryLimitCustomDefault);
  T.Test('QueryOffsetClamped missing', @TestQueryOffsetMissing);
  T.Test('QueryOffsetClamped non-integer', @TestQueryOffsetNonInteger);
  T.Test('QueryOffsetClamped negative', @TestQueryOffsetNegative);
  T.Test('QueryOffsetClamped huge', @TestQueryOffsetHuge);
  T.Test('QueryOffsetClamped valid', @TestQueryOffsetValid);
  T.Test('QueryLimitClamped bad max raises', @TestQueryClampBadMaxRaises);
  T.Test('QueryClamped nil req raises', @TestQueryClampNilReqRaises);
  if not T.Run then Halt(1);
end.
