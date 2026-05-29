program test_json_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.view,
  nextpas.core.json,
  nextpas.core.json.types,
  nextpas.core.json.value,
  nextpas.core.testing;

var
  T: TTestRunner;

function SV(const S: string): TStringView; inline;
begin
  Result := TStringView.FromStr(S);
end;

procedure TestJsonParseInterface;
var Doc: IJsonDocument; V: TJsonValue;
begin
  Doc := JsonParse('{"name":"Alice","age":30}');
  Check(not Doc.HasError, 'no error');
  V := Doc.Root;
  CheckEqual('Alice', V.ObjectGet(SV('name')).AsStr.ToString, 'name');
  CheckEqual(Int64(30), V.ObjectGet(SV('age')).AsInt, 'age');
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

procedure TestJsonParseNested;
var Doc: IJsonDocument; V: TJsonValue;
begin
  Doc := JsonParse('{"user":{"id":1,"name":"Bob"},"items":[10,20]}');
  V := Doc.Root;
  CheckEqual(Int64(1), V.ObjectGet(SV('user')).ObjectGet(SV('id')).AsInt, 'user.id');
  CheckEqual('Bob', V.ObjectGet(SV('user')).ObjectGet(SV('name')).AsStr.ToString, 'user.name');
  CheckEqual(Int64(20), V.ObjectGet(SV('items')).ArrayGet(1).AsInt, 'items[1]');
end;

begin
  T := TTestRunner.Create('nextpas.core.json (facade)');
  T.Run('parse interface', @TestJsonParseInterface);
  T.Run('auto release', @TestJsonParseAutoRelease);
  T.Run('stringify', @TestJsonStringify);
  T.Run('stringify func', @TestJsonStringifyFunc);
  T.Run('parse error', @TestJsonParseError);
  T.Run('parse nested', @TestJsonParseNested);
  T.Summary;
end.
