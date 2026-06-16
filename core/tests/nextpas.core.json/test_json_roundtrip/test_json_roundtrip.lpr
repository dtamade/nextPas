program test_json_roundtrip;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.text.view,
  nextpas.core.mem.default,
  nextpas.core.json,
  nextpas.core.json.types,
  nextpas.core.json.value,
  nextpas.core.json.builder,
  nextpas.core.testing;

var
  T: TTestRunner;

{ ---------------------------------------------------------------------------
  Helper: walk a TJsonValue recursively and rebuild it with JsonBuilder.
  Returns the builder output string. }
function RebuildViaBuilder(const AValue: TJsonValue): string;
var
  B: IJsonBuilder;

  procedure WriteValue(const V: TJsonValue);
  var
    I: UInt32;
    K: TStringView;
  begin
    case V.Kind of
      jnkNull:   B.Null;
      jnkBool:   B.Bool(V.AsBool);
      jnkInt:    B.Int(V.AsInt);
      jnkReal:   B.Float(V.AsFloat);
      jnkString: B.Str(V.AsStr.ToString);
      jnkArray:
        begin
          B.BeginArray;
          for I := 0 to V.ArrayLen - 1 do
            WriteValue(V.ArrayGet(I));
          B.EndArray;
        end;
      jnkObject:
        begin
          B.BeginObject;
          for I := 0 to V.ObjectLen - 1 do
          begin
            K := V.ObjectKeyAt(I);
            B.Key(K.ToString);
            WriteValue(V.ObjectValueAt(I));
          end;
          B.EndObject;
        end;
    end;
  end;

begin
  B := JsonBuilder(4096);
  WriteValue(AValue);
  Result := B.ToString;
end;

{ Helper: parse a string into IJsonDocument, asserting no error. }
function MustParse(const AInput: string): IJsonDocument;
begin
  Result := JsonParse(AInput);
  Check(not Result.HasError, 'parse error on: ' + AInput);
end;

{ ---- Test 1: Scalar roundtrip ---- }
procedure TestScalarRoundtrip;
var
  Doc, Doc2: IJsonDocument;
  B: string;
begin
  { null }
  Doc := MustParse('null');
  B := RebuildViaBuilder(Doc.Root);
  Doc2 := MustParse(B);
  Check(Doc2.Root.IsNull, 'null roundtrip');

  { true }
  Doc := MustParse('true');
  B := RebuildViaBuilder(Doc.Root);
  Doc2 := MustParse(B);
  CheckEqual(True, Doc2.Root.AsBool, 'true roundtrip');

  { false }
  Doc := MustParse('false');
  B := RebuildViaBuilder(Doc.Root);
  Doc2 := MustParse(B);
  CheckEqual(False, Doc2.Root.AsBool, 'false roundtrip');

  { integer }
  Doc := MustParse('42');
  B := RebuildViaBuilder(Doc.Root);
  Doc2 := MustParse(B);
  CheckEqual(Int64(42), Doc2.Root.AsInt, 'int roundtrip');

  { negative integer }
  Doc := MustParse('-7');
  B := RebuildViaBuilder(Doc.Root);
  Doc2 := MustParse(B);
  CheckEqual(Int64(-7), Doc2.Root.AsInt, 'neg int roundtrip');

  { float -- compare via parsed value, not string equality }
  Doc := MustParse('3.14');
  B := RebuildViaBuilder(Doc.Root);
  Doc2 := MustParse(B);
  Check(Abs(Doc2.Root.AsFloat - 3.14) < 1e-15, 'float roundtrip');

  { string }
  Doc := MustParse('"hello"');
  B := RebuildViaBuilder(Doc.Root);
  Doc2 := MustParse(B);
  CheckEqual('hello', Doc2.Root.AsStr.ToString, 'string roundtrip');

  { empty string }
  Doc := MustParse('""');
  B := RebuildViaBuilder(Doc.Root);
  Doc2 := MustParse(B);
  CheckEqual('', Doc2.Root.AsStr.ToString, 'empty string roundtrip');
end;

{ ---- Test 2: Object roundtrip ---- }
procedure TestObjectRoundtrip;
var
  Doc, Doc2: IJsonDocument;
  B: string;
begin
  Doc := MustParse('{"name":"Alice","age":30}');
  Check(Doc.Root.IsObject, 'is object');
  CheckEqual(Int64(2), Int64(Doc.Root.ObjectLen), 'obj len');

  B := RebuildViaBuilder(Doc.Root);
  Doc2 := MustParse(B);
  Check(Doc2.Root.IsObject, 'rebuilt is object');
  CheckEqual(Int64(2), Int64(Doc2.Root.ObjectLen), 'rebuilt obj len');
  CheckEqual('Alice', Doc2.Root.ObjectGet('name').AsStr.ToString, 'name match');
  CheckEqual(Int64(30), Doc2.Root.ObjectGet('age').AsInt, 'age match');
end;

{ ---- Test 3: Array roundtrip ---- }
procedure TestArrayRoundtrip;
var
  Doc, Doc2: IJsonDocument;
  B: string;
begin
  Doc := MustParse('[1,2,3]');
  Check(Doc.Root.IsArray, 'is array');
  CheckEqual(Int64(3), Int64(Doc.Root.ArrayLen), 'arr len');

  B := RebuildViaBuilder(Doc.Root);
  Doc2 := MustParse(B);
  Check(Doc2.Root.IsArray, 'rebuilt is array');
  CheckEqual(Int64(3), Int64(Doc2.Root.ArrayLen), 'rebuilt arr len');
  CheckEqual(Int64(1), Doc2.Root.ArrayGet(0).AsInt, 'arr[0]');
  CheckEqual(Int64(2), Doc2.Root.ArrayGet(1).AsInt, 'arr[1]');
  CheckEqual(Int64(3), Doc2.Root.ArrayGet(2).AsInt, 'arr[2]');
end;

{ ---- Test 4: Nested roundtrip ---- }
procedure TestNestedRoundtrip;
var
  Doc, Doc2: IJsonDocument;
  Items: TJsonValue;
  B: string;
begin
  Doc := MustParse('{"items":[{"id":1},{"id":2}]}');
  Items := Doc.Root.ObjectGet('items');
  Check(Items.IsArray, 'items is array');
  CheckEqual(Int64(2), Int64(Items.ArrayLen), 'items len');
  CheckEqual(Int64(1), Items.ArrayGet(0).ObjectGet('id').AsInt, 'items[0].id');
  CheckEqual(Int64(2), Items.ArrayGet(1).ObjectGet('id').AsInt, 'items[1].id');

  B := RebuildViaBuilder(Doc.Root);
  Doc2 := MustParse(B);
  Items := Doc2.Root.ObjectGet('items');
  Check(Items.IsArray, 'rebuilt items is array');
  CheckEqual(Int64(2), Int64(Items.ArrayLen), 'rebuilt items len');
  CheckEqual(Int64(1), Items.ArrayGet(0).ObjectGet('id').AsInt, 'rebuilt items[0].id');
  CheckEqual(Int64(2), Items.ArrayGet(1).ObjectGet('id').AsInt, 'rebuilt items[1].id');
end;

{ ---- Test 5: Empty containers roundtrip ---- }
procedure TestEmptyContainers;
var
  Doc, Doc2: IJsonDocument;
  B: string;
begin
  { empty object }
  Doc := MustParse('{}');
  Check(Doc.Root.IsObject, '{} is object');
  CheckEqual(Int64(0), Int64(Doc.Root.ObjectLen), '{} len 0');
  B := RebuildViaBuilder(Doc.Root);
  Doc2 := MustParse(B);
  Check(Doc2.Root.IsObject, 'rebuilt {} is object');
  CheckEqual(Int64(0), Int64(Doc2.Root.ObjectLen), 'rebuilt {} len 0');

  { empty array }
  Doc := MustParse('[]');
  Check(Doc.Root.IsArray, '[] is array');
  CheckEqual(Int64(0), Int64(Doc.Root.ArrayLen), '[] len 0');
  B := RebuildViaBuilder(Doc.Root);
  Doc2 := MustParse(B);
  Check(Doc2.Root.IsArray, 'rebuilt [] is array');
  CheckEqual(Int64(0), Int64(Doc2.Root.ArrayLen), 'rebuilt [] len 0');
end;

{ ---- Test 6: Unicode roundtrip ---- }
procedure TestUnicodeRoundtrip;
var
  Doc, Doc2: IJsonDocument;
  B: string;
begin
  { Chinese characters }
  Doc := MustParse('{"msg":"'#$E4#$B8#$AD#$E6#$96#$87'"}');
  B := RebuildViaBuilder(Doc.Root);
  Doc2 := MustParse(B);
  CheckEqual(#$E4#$B8#$AD#$E6#$96#$87, Doc2.Root.ObjectGet('msg').AsStr.ToString,
    'Chinese chars roundtrip');

  { Emoji via escaped surrogate pair: U+1F600 = 😀 }
  Doc := MustParse('{"e":"😀"}');
  Check(not Doc.HasError, 'emoji parse ok');
  B := RebuildViaBuilder(Doc.Root);
  Doc2 := MustParse(B);
  Check(not Doc2.HasError, 'emoji rebuild parse ok');
  { The decoded UTF-8 should be 4 bytes for the emoji }
  CheckEqual(Int64(4), Int64(Length(Doc2.Root.ObjectGet('e').AsStr.ToString)),
    'emoji 4-byte UTF-8 roundtrip');
end;

{ ---- Test 7: All types roundtrip ---- }
procedure TestAllTypesRoundtrip;
var
  Doc, Doc2: IJsonDocument;
  B: string;
  Root: TJsonValue;
begin
  Doc := MustParse(
    '{"null_val":null,"bool_val":true,"int_val":42,"real_val":1.5,' +
    '"str_val":"hello","arr_val":[1,2],"obj_val":{"k":"v"}}');
  Check(Doc.Root.IsObject, 'all-types is object');
  CheckEqual(Int64(7), Int64(Doc.Root.ObjectLen), '7 keys');

  B := RebuildViaBuilder(Doc.Root);
  Doc2 := MustParse(B);
  Root := Doc2.Root;
  Check(Root.IsObject, 'rebuilt is object');
  Check(Root.ObjectGet('null_val').IsNull, 'null preserved');
  CheckEqual(True, Root.ObjectGet('bool_val').AsBool, 'bool preserved');
  CheckEqual(Int64(42), Root.ObjectGet('int_val').AsInt, 'int preserved');
  Check(Abs(Root.ObjectGet('real_val').AsFloat - 1.5) < 1e-15, 'real preserved');
  CheckEqual('hello', Root.ObjectGet('str_val').AsStr.ToString, 'str preserved');
  Check(Root.ObjectGet('arr_val').IsArray, 'arr preserved');
  CheckEqual(Int64(2), Int64(Root.ObjectGet('arr_val').ArrayLen), 'arr len preserved');
  Check(Root.ObjectGet('obj_val').IsObject, 'obj preserved');
  CheckEqual('v', Root.ObjectGet('obj_val').ObjectGet('k').AsStr.ToString, 'nested obj preserved');
end;

{ ---- Test 8: Large document roundtrip ---- }
procedure TestLargeDocumentRoundtrip;
var
  Doc, Doc2: IJsonDocument;
  Root, Root2: TJsonValue;
  B: string;
  I: Int32;
  Key: string;
begin
  { Build a 100-key JSON object via builder, parse, rebuild, compare }
  Doc := MustParse(
    '{"k0":0,"k1":1,"k2":2,"k3":3,"k4":4,"k5":5,"k6":6,"k7":7,"k8":8,"k9":9,' +
    '"k10":10,"k11":11,"k12":12,"k13":13,"k14":14,"k15":15,"k16":16,"k17":17,"k18":18,"k19":19,' +
    '"k20":20,"k21":21,"k22":22,"k23":23,"k24":24,"k25":25,"k26":26,"k27":27,"k28":28,"k29":29,' +
    '"k30":30,"k31":31,"k32":32,"k33":33,"k34":34,"k35":35,"k36":36,"k37":37,"k38":38,"k39":39,' +
    '"k40":40,"k41":41,"k42":42,"k43":43,"k44":44,"k45":45,"k46":46,"k47":47,"k48":48,"k49":49,' +
    '"k50":50,"k51":51,"k52":52,"k53":53,"k54":54,"k55":55,"k56":56,"k57":57,"k58":58,"k59":59,' +
    '"k60":60,"k61":61,"k62":62,"k63":63,"k64":64,"k65":65,"k66":66,"k67":67,"k68":68,"k69":69,' +
    '"k70":70,"k71":71,"k72":72,"k73":73,"k74":74,"k75":75,"k76":76,"k77":77,"k78":78,"k79":79,' +
    '"k80":80,"k81":81,"k82":82,"k83":83,"k84":84,"k85":85,"k86":86,"k87":87,"k88":88,"k89":89,' +
    '"k90":90,"k91":91,"k92":92,"k93":93,"k94":94,"k95":95,"k96":96,"k97":97,"k98":98,"k99":99}');

  Root := Doc.Root;
  Check(Root.IsObject, 'large is object');
  CheckEqual(Int64(100), Int64(Root.ObjectLen), '100 keys');

  B := RebuildViaBuilder(Root);
  Doc2 := MustParse(B);
  Root2 := Doc2.Root;
  Check(Root2.IsObject, 'rebuilt large is object');
  CheckEqual(Int64(100), Int64(Root2.ObjectLen), 'rebuilt 100 keys');

  for I := 0 to 99 do
  begin
    Key := 'k' + IntToStr(I);
    Check(Root2.ObjectHas(Key), Key + ' exists');
    CheckEqual(Int64(I), Root2.ObjectGet(Key).AsInt, Key + ' value');
  end;
end;

{ ---- Test 9: Builder escape roundtrip ---- }
procedure TestBuilderEscapeRoundtrip;
var
  Doc, Doc2: IJsonDocument;
  B: string;
begin
  { String with embedded quotes, backslash, newline, tab }
  Doc := MustParse('"line1\nline2\ttab\\slash\"quote"');
  Check(not Doc.HasError, 'escaped parse ok');

  B := RebuildViaBuilder(Doc.Root);
  Doc2 := MustParse(B);
  Check(not Doc2.HasError, 'rebuilt escaped parse ok');

  { The decoded string should contain actual special chars }
  Check(Pos(#10, Doc2.Root.AsStr.ToString) > 0, 'rebuilt has newline');
  Check(Pos(#9, Doc2.Root.AsStr.ToString) > 0, 'rebuilt has tab');
  Check(Pos('\', Doc2.Root.AsStr.ToString) > 0, 'rebuilt has backslash');
  Check(Pos('"', Doc2.Root.AsStr.ToString) > 0, 'rebuilt has quote');

  { Verify the builder output is valid JSON that re-parses identically }
  CheckEqual(Doc.Root.AsStr.ToString, Doc2.Root.AsStr.ToString,
    'escaped string content matches');
end;

{ ---- Test 10: Deep nesting roundtrip ---- }
procedure TestDeepNestingRoundtrip;
var
  Doc, Doc2: IJsonDocument;
  B: string;
  V: TJsonValue;
  I: Int32;
begin
  // 10 levels: {"l1":{"l2":{"l3":...{"l10":42}...}}}
  Doc := MustParse(
    '{"l1":{"l2":{"l3":{"l4":{"l5":{"l6":{"l7":{"l8":{"l9":{"l10":42}}}}}}}}}}');
  Check(not Doc.HasError, 'deep parse ok');

  B := RebuildViaBuilder(Doc.Root);
  Doc2 := MustParse(B);
  Check(not Doc2.HasError, 'deep rebuild parse ok');

  { Navigate 10 levels deep }
  V := Doc2.Root;
  for I := 1 to 10 do
  begin
    Check(V.IsObject, 'level ' + IntToStr(I) + ' is object');
    CheckEqual(Int64(1), Int64(V.ObjectLen), 'level ' + IntToStr(I) + ' len 1');
    V := V.ObjectGet('l' + IntToStr(I));
  end;
  CheckEqual(Int64(42), V.AsInt, 'deep value = 42');
end;

begin
  T := TTestRunner.Create('nextpas.core.json (roundtrip)');
  T.Run('scalar roundtrip', @TestScalarRoundtrip);
  T.Run('object roundtrip', @TestObjectRoundtrip);
  T.Run('array roundtrip', @TestArrayRoundtrip);
  T.Run('nested roundtrip', @TestNestedRoundtrip);
  T.Run('empty containers', @TestEmptyContainers);
  T.Run('unicode roundtrip', @TestUnicodeRoundtrip);
  T.Run('all types roundtrip', @TestAllTypesRoundtrip);
  T.Run('large document roundtrip', @TestLargeDocumentRoundtrip);
  T.Run('builder escape roundtrip', @TestBuilderEscapeRoundtrip);
  T.Run('deep nesting roundtrip', @TestDeepNestingRoundtrip);
  T.Summary;
end.
