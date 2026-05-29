program test_json_parser;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.view,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.json.types,
  nextpas.core.json.parser,
  nextpas.core.json.value,
  nextpas.core.testing;

var
  T: TTestRunner;

function SV(const S: string): TStringView; inline;
begin
  Result := TStringView.FromStr(S);
end;

procedure TestParseNull;
var Doc: TJsonDocument; V: TJsonValue;
begin
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(SV('null')), 'parse null');
  V := TJsonValue.Create(Doc, Doc.Root);
  Check(V.IsNull, 'is null');
  Doc.Done;
end;

procedure TestParseBool;
var Doc: TJsonDocument; V: TJsonValue;
begin
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(SV('true')), 'parse true');
  V := TJsonValue.Create(Doc, Doc.Root);
  Check(V.IsBool, 'is bool');
  Check(V.AsBool = True, 'val true');
  Doc.Done;
end;

procedure TestParseInt;
var Doc: TJsonDocument; V: TJsonValue;
begin
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(SV('42')), 'parse 42');
  V := TJsonValue.Create(Doc, Doc.Root);
  Check(V.IsInt, 'is int');
  CheckEqual(Int64(42), V.AsInt, 'val 42');
  Doc.Done;
end;

procedure TestParseFloat;
var Doc: TJsonDocument; V: TJsonValue;
begin
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(SV('3.14')), 'parse 3.14');
  V := TJsonValue.Create(Doc, Doc.Root);
  Check(V.IsReal, 'is real');
  Check(Abs(V.AsFloat - 3.14) < 1e-15, 'val 3.14');
  Doc.Done;
end;

procedure TestParseString;
var Doc: TJsonDocument; V: TJsonValue;
begin
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(SV('"hello"')), 'parse string');
  V := TJsonValue.Create(Doc, Doc.Root);
  Check(V.IsStr, 'is str');
  CheckEqual('hello', V.AsStr.ToString, 'val hello');
  Doc.Done;
end;

procedure TestParseArray;
var Doc: TJsonDocument; V: TJsonValue;
begin
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(SV('[1,2,3]')), 'parse array');
  V := TJsonValue.Create(Doc, Doc.Root);
  Check(V.IsArray, 'is array');
  CheckEqual(Int64(3), Int64(V.ArrayLen), 'len=3');
  CheckEqual(Int64(1), V.ArrayGet(0).AsInt, '[0]=1');
  CheckEqual(Int64(2), V.ArrayGet(1).AsInt, '[1]=2');
  CheckEqual(Int64(3), V.ArrayGet(2).AsInt, '[2]=3');
  Doc.Done;
end;

procedure TestParseObject;
var Doc: TJsonDocument; V: TJsonValue;
begin
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(SV('{"name":"Alice","age":30}')), 'parse object');
  V := TJsonValue.Create(Doc, Doc.Root);
  Check(V.IsObject, 'is object');
  CheckEqual('Alice', V.ObjectGet(SV('name')).AsStr.ToString, 'name=Alice');
  CheckEqual(Int64(30), V.ObjectGet(SV('age')).AsInt, 'age=30');
  Check(V.ObjectHas(SV('name')), 'has name');
  Check(not V.ObjectHas(SV('missing')), 'no missing');
  Doc.Done;
end;

procedure TestParseNested;
var Doc: TJsonDocument; V, Items: TJsonValue;
begin
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(SV('{"items":[1,2],"ok":true}')), 'parse nested');
  V := TJsonValue.Create(Doc, Doc.Root);
  Items := V.ObjectGet(SV('items'));
  Check(Items.IsArray, 'items is array');
  CheckEqual(Int64(2), Int64(Items.ArrayLen), 'items len=2');
  CheckEqual(Int64(1), Items.ArrayGet(0).AsInt, 'items[0]=1');
  Check(V.ObjectGet(SV('ok')).AsBool, 'ok=true');
  Doc.Done;
end;

procedure TestParseEmpty;
var Doc: TJsonDocument; V: TJsonValue;
begin
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(SV('{}')), 'parse {}');
  V := TJsonValue.Create(Doc, Doc.Root);
  Check(V.IsObject, 'is object');
  CheckEqual(Int64(0), Int64(V.ObjectGet(SV('x')).IsValid), 'empty obj');
  Doc.Done;

  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(SV('[]')), 'parse []');
  V := TJsonValue.Create(Doc, Doc.Root);
  Check(V.IsArray, 'is array');
  CheckEqual(Int64(0), Int64(V.ArrayLen), 'empty arr');
  Doc.Done;
end;

procedure TestParseError;
var Doc: TJsonDocument;
begin
  Doc.Init(DefaultAllocator);
  Check(not Doc.Parse(SV('{invalid}')), 'reject invalid');
  Check(Doc.HasError, 'has error');
  Doc.Done;

  Doc.Init(DefaultAllocator);
  Check(not Doc.Parse(SV('{"a":}')), 'reject missing value');
  Doc.Done;
end;

begin
  T := TTestRunner.Create('nextpas.core.json.parser');
  T.Run('parse null', @TestParseNull);
  T.Run('parse bool', @TestParseBool);
  T.Run('parse int', @TestParseInt);
  T.Run('parse float', @TestParseFloat);
  T.Run('parse string', @TestParseString);
  T.Run('parse array', @TestParseArray);
  T.Run('parse object', @TestParseObject);
  T.Run('parse nested', @TestParseNested);
  T.Run('parse empty', @TestParseEmpty);
  T.Run('parse error', @TestParseError);
  T.Summary;
end.
