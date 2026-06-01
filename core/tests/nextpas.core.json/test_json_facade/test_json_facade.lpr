program test_json_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.mem.default,
  nextpas.core.json,
  nextpas.core.json.types,
  nextpas.core.json.value,
  nextpas.core.testing;

var
  T: TTestRunner;


procedure TestJsonParseInterface;
var Doc: IJsonDocument; V: TJsonValue;
begin
  Doc := JsonParse('{"name":"Alice","age":30}');
  Check(not Doc.HasError, 'no error');
  V := Doc.Root;
  CheckEqual('Alice', V.ObjectGet('name').AsStr.ToString, 'name');
  CheckEqual(Int64(30), V.ObjectGet('age').AsInt, 'age');
end;

procedure TestJsonParseAutoRelease;
var Doc: IJsonDocument;
begin
  Doc := JsonParse('[1,2,3]');
  Check(Doc.Root.IsArray, 'is array');
  CheckEqual(Int64(3), Int64(Doc.Root.ArrayLen), 'len=3');
  Doc := nil;
  Check(True, 'no crash after release');
end;

procedure TestJsonStringify;
var Doc: IJsonDocument; S: string;
begin
  Doc := JsonParse('{"x":1,"y":[true,null]}');
  S := Doc.Stringify;
  CheckEqual('{"x":1,"y":[true,null]}', S, 'stringify');
end;

procedure TestJsonStringifyFunc;
var Doc: IJsonDocument; S: string;
begin
  Doc := JsonParse('42');
  S := JsonStringify(Doc.Root);
  CheckEqual('42', S, 'stringify func');
end;

procedure TestJsonParseError;
var Doc: IJsonDocument;
begin
  Doc := JsonParse('{bad}');
  Check(Doc.HasError, 'has error');
end;

procedure TestTryJsonParseSuccess;
var
  LDoc: IJsonDocument;
begin
  Check(TryJsonParse('{"ok":true,"n":7}', LDoc), 'try parse success');
  Check(LDoc <> nil, 'doc assigned');
  Check(not LDoc.HasError, 'no error');
  Check(LDoc.Root.ObjectGet('ok').AsBool, 'ok=true');
  CheckEqual(Int64(7), LDoc.Root.ObjectGet('n').AsInt, 'n=7');
end;

procedure TestTryJsonParseFailureReturnsDiagnosticDoc;
var
  LDoc: IJsonDocument;
begin
  Check(not TryJsonParse('{bad}', LDoc), 'try parse failure');
  Check(LDoc <> nil, 'diagnostic doc assigned');
  Check(LDoc.HasError, 'diagnostic doc has error');
end;

procedure TestJsonParseNested;
var Doc: IJsonDocument; V: TJsonValue;
begin
  Doc := JsonParse('{"user":{"id":1,"name":"Bob"},"items":[10,20]}');
  V := Doc.Root;
  CheckEqual(Int64(1), V.ObjectGet('user').ObjectGet('id').AsInt, 'user.id');
  CheckEqual('Bob', V.ObjectGet('user').ObjectGet('name').AsStr.ToString, 'user.name');
  CheckEqual(Int64(20), V.ObjectGet('items').ArrayGet(1).AsInt, 'items[1]');
end;

procedure TestPrettyPrint;
var Doc: IJsonDocument; S: string;
begin
  Doc := JsonParse('{"a":1,"b":[2,3]}');
  S := Doc.StringifyPretty(2);
  Check(Pos(#10, S) > 0, 'has newlines');
  Check(Pos('  "a"', S) > 0, 'indented key');
  Check(Pos('  "b"', S) > 0, 'indented key b');
end;

procedure TestJsonParseWithAllocator;
var Doc: IJsonDocument;
begin
  Doc := JsonParseWith('{"x":99}', DefaultAllocator);
  Check(not Doc.HasError, 'no error');
  CheckEqual(Int64(99), Doc.Root.ObjectGet('x').AsInt, 'x=99');
end;

procedure TestStringifyRoundTrip;
var Doc: IJsonDocument; S: string;
const
  INPUTS: array[0..5] of string = (
    'null', 'true', '42', '3.14', '"hello"', '{"a":[1,2,3],"b":null}'
  );
var I: Int32;
begin
  for I := 0 to High(INPUTS) do
  begin
    Doc := JsonParse(INPUTS[I]);
    S := Doc.Stringify;
    CheckEqual(INPUTS[I], S, 'roundtrip ' + INPUTS[I]);
  end;
end;

procedure TestEdgeCaseNumbers;
var Doc: IJsonDocument;
begin
  Doc := JsonParse('9223372036854775807');
  CheckEqual(Int64(9223372036854775807), Doc.Root.AsInt, 'max int64');

  Doc := JsonParse('-9223372036854775808');
  CheckEqual(Int64(-9223372036854775808), Doc.Root.AsInt, 'min int64');

  Doc := JsonParse('1.7976931348623157e+308');
  Check(Doc.Root.AsFloat > 1e307, 'max double');

  Doc := JsonParse('5e-324');
  Check(Doc.Root.AsFloat > 0, 'min positive double');
end;

procedure TestEscapedBackslashCombos;
var Doc: IJsonDocument; S: string;
begin
  Doc := JsonParse('"a'#92#92'b"');
  S := Doc.Root.AsStr.ToString;
  CheckEqual(Int64(3), Int64(Length(S)), 'a\\b len=3');
  Check(S[2] = '\', 'middle is backslash');

  Doc := JsonParse('"'#92#92#92'""');
  S := Doc.Root.AsStr.ToString;
  CheckEqual(Int64(2), Int64(Length(S)), '\\\\" decoded len=2');
  Check(S[1] = '\', 'first is bs');
  Check(S[2] = '"', 'second is quote');
end;

begin
  T := TTestRunner.Create('nextpas.core.json (facade)');
  T.Run('parse interface', @TestJsonParseInterface);
  T.Run('auto release', @TestJsonParseAutoRelease);
  T.Run('stringify', @TestJsonStringify);
  T.Run('stringify func', @TestJsonStringifyFunc);
  T.Run('parse error', @TestJsonParseError);
  T.Run('TryJsonParse success', @TestTryJsonParseSuccess);
  T.Run('TryJsonParse failure returns diagnostic doc', @TestTryJsonParseFailureReturnsDiagnosticDoc);
  T.Run('parse nested', @TestJsonParseNested);
  T.Run('pretty print', @TestPrettyPrint);
  T.Run('parse with allocator', @TestJsonParseWithAllocator);
  T.Run('stringify round-trip', @TestStringifyRoundTrip);
  T.Run('edge case numbers', @TestEdgeCaseNumbers);
  T.Run('escaped backslash combos', @TestEscapedBackslashCombos);
  T.Summary;
end.
