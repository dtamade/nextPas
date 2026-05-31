program test_json_parser;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.mem.intf,
  nextpas.core.mem.default,
  nextpas.core.json.types,
  nextpas.core.json.parser,
  nextpas.core.json.value,
  nextpas.core.json.writer,
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

procedure TestObjectIteration;
var Doc: TJsonDocument; V: TJsonValue;
begin
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(SV('{"a":1,"b":2,"c":3}')), 'parse');
  V := TJsonValue.Create(Doc, Doc.Root);
  CheckEqual(Int64(3), Int64(V.ObjectLen), 'len=3');
  CheckEqual('a', V.ObjectKeyAt(0).ToString, 'key[0]=a');
  CheckEqual('b', V.ObjectKeyAt(1).ToString, 'key[1]=b');
  CheckEqual('c', V.ObjectKeyAt(2).ToString, 'key[2]=c');
  CheckEqual(Int64(1), V.ObjectValueAt(0).AsInt, 'val[0]=1');
  CheckEqual(Int64(2), V.ObjectValueAt(1).AsInt, 'val[1]=2');
  CheckEqual(Int64(3), V.ObjectValueAt(2).AsInt, 'val[2]=3');
  Doc.Done;
end;

procedure TestStringEscape;
var Doc: TJsonDocument; V: TJsonValue; S: string;
const
  INPUT = '{"msg":"hello'#92'nworld"}';
begin
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(TStringView.Create(PAnsiChar(INPUT), Length(INPUT))), 'parse');
  V := TJsonValue.Create(Doc, Doc.Root);
  S := V.ObjectGet(SV('msg')).AsStr.ToString;
  CheckEqual(Int64(11), Int64(Length(S)), 'decoded len=11');
  Check(Ord(S[6]) = 10, 'byte 6 = LF');
  Doc.Done;
end;

procedure TestUnicodeEscape;
var Doc: TJsonDocument; V: TJsonValue; S: string;
const
  INPUT = '{"c":"'#92'u00e9"}';
begin
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(TStringView.Create(PAnsiChar(INPUT), Length(INPUT))), 'parse');
  V := TJsonValue.Create(Doc, Doc.Root);
  S := V.ObjectGet(SV('c')).AsStr.ToString;
  Check(Ord(S[1]) = $C3, 'utf8 byte 0');
  Check(Ord(S[2]) = $A9, 'utf8 byte 1');
  Doc.Done;
end;

procedure TestValueKindAndValid;
var Doc: TJsonDocument; V, Missing: TJsonValue;
begin
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(SV('{"x":1}')), 'parse');
  V := TJsonValue.Create(Doc, Doc.Root);
  Check(V.IsValid, 'root valid');
  Check(V.Kind = jnkObject, 'root kind');
  Missing := V.ObjectGet(SV('missing'));
  Check(not Missing.IsValid, 'missing not valid');
  Check(Missing.Kind = jnkNull, 'missing kind = null');
  CheckEqual(Int64(0), Missing.AsInt, 'missing asint = 0');
  CheckEqual('', Missing.AsStr.ToString, 'missing asstr = empty');
  Doc.Done;
end;

procedure TestNodeCountAndInput;
var Doc: TJsonDocument;
begin
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(SV('[1,2,3]')), 'parse');
  Check(Doc.NodeCount > 0, 'nodecount > 0');
  CheckEqual(Int64(4), Int64(Doc.NodeCount), 'nodecount = 4');
  CheckEqual('[1,2,3]', Doc.Input.ToString, 'input preserved');
  Doc.Done;
end;

procedure TestJsonParseDocFunc;
var Doc: TJsonDocument; V: TJsonValue;
begin
  Doc := JsonParseDoc(SV('42'), DefaultAllocator);
  V := TJsonValue.Create(Doc, Doc.Root);
  Check(V.IsInt, 'is int');
  CheckEqual(Int64(42), V.AsInt, 'val 42');
  Doc.Done;
end;

procedure TestRoundTrip;
var Doc: TJsonDocument; V: TJsonValue;
    B: TStringBuilder; W: TJsonWriter;
    S1, S2: string;
const
  INPUT = '{"name":"Alice","scores":[1.5,2.7,3.14],"active":true,"data":null}';
begin
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(SV(INPUT)), 'parse');
  B.Init(256);
  W.Init(B);
  W.BeginObject;
    W.Key('name'); W.Str(TJsonValue.Create(Doc, Doc.Root).ObjectGet(SV('name')).AsStr);
    W.Key('scores'); W.BeginArray;
      W.Float(TJsonValue.Create(Doc, Doc.Root).ObjectGet(SV('scores')).ArrayGet(0).AsFloat);
      W.Float(TJsonValue.Create(Doc, Doc.Root).ObjectGet(SV('scores')).ArrayGet(1).AsFloat);
      W.Float(TJsonValue.Create(Doc, Doc.Root).ObjectGet(SV('scores')).ArrayGet(2).AsFloat);
    W.EndArray;
    W.Key('active'); W.Bool(TJsonValue.Create(Doc, Doc.Root).ObjectGet(SV('active')).AsBool);
    W.Key('data'); W.Null;
  W.EndObject;
  S1 := B.ToString;
  CheckEqual(INPUT, S1, 'round trip');
  B.Done;
  Doc.Done;
end;

procedure TestLargeArray;
var Doc: TJsonDocument; V: TJsonValue;
    B: TStringBuilder; W: TJsonWriter;
    I: Int32;
begin
  B.Init(4096);
  W.Init(B);
  W.BeginArray;
  for I := 0 to 99 do
    W.Int(I);
  W.EndArray;
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(TStringView.FromStr(B.ToString)), 'parse large');
  V := TJsonValue.Create(Doc, Doc.Root);
  CheckEqual(Int64(100), Int64(V.ArrayLen), 'len=100');
  CheckEqual(Int64(0), V.ArrayGet(0).AsInt, '[0]=0');
  CheckEqual(Int64(99), V.ArrayGet(99).AsInt, '[99]=99');
  Doc.Done;
  B.Done;
end;

procedure TestLargeObjectHashLookup;
var Doc: TJsonDocument; V: TJsonValue;
    B: TStringBuilder; W: TJsonWriter;
    I: Int32;
    LKey: string;
begin
  B.Init(8192);
  W.Init(B);
  W.BeginObject;
  for I := 0 to 99 do
  begin
    Str(I, LKey);
    LKey := 'key' + LKey;
    W.Key(TStringView.FromStr(LKey));
    W.Int(I * 10);
  end;
  W.EndObject;
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(TStringView.FromStr(B.ToString)), 'parse 100-key object');
  V := TJsonValue.Create(Doc, Doc.Root);
  CheckEqual(Int64(100), Int64(V.ObjectLen), 'len=100');
  for I := 0 to 99 do
  begin
    Str(I, LKey);
    LKey := 'key' + LKey;
    CheckEqual(Int64(I * 10), V.ObjectGet(LKey).AsInt, 'lookup ' + LKey);
  end;
  Check(not V.ObjectGet('nonexistent').IsValid, 'missing key');
  Check(not V.ObjectGet('key100').IsValid, 'out of range key');
  Doc.Done;
  B.Done;
end;

procedure TestInitNilAllocator;
var Doc: TJsonDocument; V: TJsonValue;
begin
  Doc.Init(nil);
  Check(Doc.Parse(SV('{"x":42}')), 'parse with nil allocator');
  V := TJsonValue.Create(Doc, Doc.Root);
  Check(V.IsObject, 'is object');
  CheckEqual(Int64(42), V.ObjectGet(SV('x')).AsInt, 'x=42');
  Doc.Done;
end;

procedure TestDeepNesting500;
var
  S: string;
  I: Integer;
  Doc: TJsonDocument;
  V: TJsonValue;
begin
  S := '';
  for I := 1 to 500 do
    S := S + '[';
  S := S + '1';
  for I := 1 to 500 do
    S := S + ']';
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(TStringView.Create(PAnsiChar(S), Length(S))), 'parse 500 deep');
  V := TJsonValue.Create(Doc, Doc.Root);
  Check(V.IsArray, 'root is array');
  Doc.Done;
end;

procedure TestDeepNestingExceedsLimit;
var
  S: string;
  I: Integer;
  Doc: TJsonDocument;
begin
  S := '';
  for I := 1 to 513 do
    S := S + '[';
  S := S + '1';
  for I := 1 to 513 do
    S := S + ']';
  Doc.Init(DefaultAllocator);
  Check(not Doc.Parse(TStringView.Create(PAnsiChar(S), Length(S))), 'reject 513 deep');
  Check(Doc.HasError, 'has depth error');
  Doc.Done;
end;

procedure TestEmptyInput;
var Doc: TJsonDocument;
begin
  Doc.Init(DefaultAllocator);
  Check(not Doc.Parse(SV('')), 'reject empty');
  Check(Doc.HasError, 'empty has error');
  Doc.Done;
end;

procedure TestWhitespaceOnlyInput;
var Doc: TJsonDocument;
begin
  Doc.Init(DefaultAllocator);
  Check(not Doc.Parse(SV('   '#9#10#13'  ')), 'reject whitespace only');
  Check(Doc.HasError, 'whitespace has error');
  Doc.Done;
end;

procedure TestUnicodeKeys;
var Doc: TJsonDocument; V: TJsonValue;
const
  INPUT = '{"世界":"hello","é":"accent"}';
begin
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(TStringView.Create(PAnsiChar(INPUT), Length(INPUT))), 'parse unicode keys');
  V := TJsonValue.Create(Doc, Doc.Root);
  Check(V.IsObject, 'is object');
  Doc.Done;
end;

procedure TestSurrogatePair;
var Doc: TJsonDocument; V: TJsonValue; S: string;
const
  INPUT = '{"emoji":"😀"}';
begin
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(TStringView.Create(PAnsiChar(INPUT), Length(INPUT))), 'parse surrogate');
  V := TJsonValue.Create(Doc, Doc.Root);
  S := V.ObjectGet(SV('emoji')).AsStr.ToString;
  Check(Length(S) = 4, 'surrogate -> 4 utf8 bytes');
  Check(Ord(S[1]) = $F0, 'utf8 byte 0');
  Doc.Done;
end;

procedure TestLargeDocument;
var
  B: TStringBuilder;
  W: TJsonWriter;
  I: Int32;
  Doc: TJsonDocument;
  V: TJsonValue;
  LKey: string;
begin
  B.Init(65536);
  W.Init(B);
  W.BeginObject;
  for I := 0 to 999 do
  begin
    Str(I, LKey);
    LKey := 'field_' + LKey;
    W.Key(TStringView.FromStr(LKey));
    W.BeginObject;
      W.Key(SV('value')); W.Int(I);
      W.Key(SV('name')); W.Str(TStringView.FromStr(LKey));
    W.EndObject;
  end;
  W.EndObject;
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(TStringView.FromStr(B.ToString)), 'parse 1000-field doc');
  V := TJsonValue.Create(Doc, Doc.Root);
  Check(V.IsObject, 'is object');
  CheckEqual(Int64(1000), Int64(V.ObjectLen), 'len=1000');
  CheckEqual(Int64(500), V.ObjectGet('field_500').ObjectGet(SV('value')).AsInt, 'field_500.value');
  Doc.Done;
  B.Done;
end;

procedure TestNumberEdgeCases;
var Doc: TJsonDocument; V: TJsonValue;
begin
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(SV('0')), 'parse 0');
  V := TJsonValue.Create(Doc, Doc.Root);
  CheckEqual(Int64(0), V.AsInt, 'val 0');
  Doc.Done;

  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(SV('-0')), 'parse -0');
  Doc.Done;

  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(SV('1e308')), 'parse 1e308');
  Doc.Done;

  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(SV('-9223372036854775808')), 'parse int64 min');
  V := TJsonValue.Create(Doc, Doc.Root);
  CheckEqual(Int64(-9223372036854775808), V.AsInt, 'int64 min');
  Doc.Done;

  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(SV('9223372036854775807')), 'parse int64 max');
  V := TJsonValue.Create(Doc, Doc.Root);
  CheckEqual(Int64(9223372036854775807), V.AsInt, 'int64 max');
  Doc.Done;
end;

procedure TestMultipleErrors;
var Doc: TJsonDocument;
begin
  Doc.Init(DefaultAllocator);
  Check(not Doc.Parse(SV('{')), 'reject unclosed object');
  Doc.Done;

  Doc.Init(DefaultAllocator);
  Check(not Doc.Parse(SV('[')), 'reject unclosed array');
  Doc.Done;

  Doc.Init(DefaultAllocator);
  Check(not Doc.Parse(SV('"unterminated')), 'reject unclosed string');
  Doc.Done;

  Doc.Init(DefaultAllocator);
  Check(not Doc.Parse(SV('tru')), 'reject truncated true');
  Doc.Done;

  Doc.Init(DefaultAllocator);
  Check(not Doc.Parse(SV('[1,]')), 'reject trailing comma');
  Doc.Done;
end;

procedure TestDocReuse;
var Doc: TJsonDocument; V: TJsonValue;
begin
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(SV('1')), 'first parse');
  Doc.Done;

  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(SV('"hello"')), 'second parse');
  V := TJsonValue.Create(Doc, Doc.Root);
  CheckEqual('hello', V.AsStr.ToString, 'reuse val');
  Doc.Done;
end;

procedure TestNestedObjectArray;
var Doc: TJsonDocument; V, Arr, Obj: TJsonValue;
const
  INPUT = '{"data":[{"id":1,"tags":["a","b"]},{"id":2,"tags":[]}]}';
begin
  Doc.Init(DefaultAllocator);
  Check(Doc.Parse(SV(INPUT)), 'parse nested obj/arr');
  V := TJsonValue.Create(Doc, Doc.Root);
  Arr := V.ObjectGet(SV('data'));
  Check(Arr.IsArray, 'data is array');
  CheckEqual(Int64(2), Int64(Arr.ArrayLen), 'data len=2');
  Obj := Arr.ArrayGet(0);
  CheckEqual(Int64(1), Obj.ObjectGet(SV('id')).AsInt, '[0].id=1');
  CheckEqual(Int64(2), Int64(Obj.ObjectGet(SV('tags')).ArrayLen), '[0].tags len=2');
  CheckEqual('a', Obj.ObjectGet(SV('tags')).ArrayGet(0).AsStr.ToString, 'tag a');
  Obj := Arr.ArrayGet(1);
  CheckEqual(Int64(2), Obj.ObjectGet(SV('id')).AsInt, '[1].id=2');
  CheckEqual(Int64(0), Int64(Obj.ObjectGet(SV('tags')).ArrayLen), '[1].tags empty');
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
  T.Run('object iteration', @TestObjectIteration);
  T.Run('string escape', @TestStringEscape);
  T.Run('unicode escape', @TestUnicodeEscape);
  T.Run('value kind and valid', @TestValueKindAndValid);
  T.Run('nodecount and input', @TestNodeCountAndInput);
  T.Run('JsonParseDoc func', @TestJsonParseDocFunc);
  T.Run('round trip', @TestRoundTrip);
  T.Run('large array', @TestLargeArray);
  T.Run('large object hash lookup', @TestLargeObjectHashLookup);
  T.Run('init nil allocator', @TestInitNilAllocator);
  T.Run('deep nesting 500', @TestDeepNesting500);
  T.Run('deep nesting exceeds limit', @TestDeepNestingExceedsLimit);
  T.Run('empty input', @TestEmptyInput);
  T.Run('whitespace only input', @TestWhitespaceOnlyInput);
  T.Run('unicode keys', @TestUnicodeKeys);
  T.Run('surrogate pair', @TestSurrogatePair);
  T.Run('large document', @TestLargeDocument);
  T.Run('number edge cases', @TestNumberEdgeCases);
  T.Run('multiple errors', @TestMultipleErrors);
  T.Run('doc reuse', @TestDocReuse);
  T.Run('nested object array', @TestNestedObjectArray);
  T.Summary;
end.
