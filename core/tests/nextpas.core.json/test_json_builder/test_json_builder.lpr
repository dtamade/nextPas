program test_json_builder;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.text.view,
  nextpas.core.json.builder,
  nextpas.core.json.writer,
  nextpas.core.errors,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestSimpleObject;
var B: IJsonBuilder;
begin
  B := JsonBuilder;
  B.BeginObject;
    B.Key('name'); B.Str('Alice');
    B.Key('age'); B.Int(30);
  B.EndObject;
  CheckEqual('{"name":"Alice","age":30}', B.ToString, 'simple object');
end;

procedure TestArray;
var B: IJsonBuilder;
begin
  B := JsonBuilder;
  B.BeginArray;
    B.Int(1); B.Int(2); B.Int(3);
  B.EndArray;
  CheckEqual('[1,2,3]', B.ToString, 'array');
end;

procedure TestNested;
var B: IJsonBuilder;
begin
  B := JsonBuilder;
  B.BeginObject;
    B.Key('items'); B.BeginArray;
      B.BeginObject;
        B.Key('id'); B.Int(1);
      B.EndObject;
    B.EndArray;
  B.EndObject;
  CheckEqual('{"items":[{"id":1}]}', B.ToString, 'nested');
end;

procedure TestAllTypes;
var B: IJsonBuilder;
begin
  B := JsonBuilder;
  B.BeginArray;
    B.Null;
    B.Bool(True);
    B.Bool(False);
    B.Int(-42);
    B.UInt(18446744073709551615);
    B.Float(3.14);
    B.Str('hello "world"');
  B.EndArray;
  Check(Pos('null', B.ToString) > 0, 'has null');
  Check(Pos('true', B.ToString) > 0, 'has true');
  Check(Pos('"hello \"world\""', B.ToString) > 0, 'has escaped str');
end;

procedure TestAutoRelease;
var B: IJsonBuilder;
begin
  B := JsonBuilder;
  B.BeginObject; B.Key('x'); B.Int(1); B.EndObject;
  B := nil;
  Check(True, 'no crash after release');
end;

procedure TestRawJson;
var B: IJsonBuilder;
begin
  B := JsonBuilder;
  B.BeginObject;
    B.Key('data'); B.RawJson('[1,2,3]');
  B.EndObject;
  CheckEqual('{"data":[1,2,3]}', B.ToString, 'raw json');
end;

procedure TestAsView;
var B: IJsonBuilder; V: TStringView;
begin
  B := JsonBuilder;
  B.BeginArray; B.Int(42); B.EndArray;
  V := B.AsView;
  CheckEqual(Int64(4), Int64(V.Len), 'view len=4');
  CheckEqual('[42]', V.ToString, 'view content');
end;

procedure TestLen;
var B: IJsonBuilder;
begin
  B := JsonBuilder;
  CheckEqual(Int64(0), Int64(B.Len), 'initial len=0');
  B.BeginObject; B.Key('a'); B.Int(1); B.EndObject;
  CheckEqual(Int64(Length(B.ToString)), Int64(B.Len), 'len matches ToString');
end;

procedure TestBuilderWithCapacity;
var B: IJsonBuilder;
begin
  B := JsonBuilder(4096);
  B.BeginObject;
    B.Key('x'); B.Int(1);
  B.EndObject;
  CheckEqual('{"x":1}', B.ToString, 'capacity does not affect output');
end;

procedure TestDeepNesting;
var B: IJsonBuilder;
begin
  B := JsonBuilder;
  B.BeginObject;
    B.Key('a'); B.BeginObject;
      B.Key('b'); B.BeginObject;
        B.Key('c'); B.BeginObject;
          B.Key('d'); B.BeginObject;
            B.Key('e'); B.Int(5);
          B.EndObject;
        B.EndObject;
      B.EndObject;
    B.EndObject;
  B.EndObject;
  CheckEqual('{"a":{"b":{"c":{"d":{"e":5}}}}}', B.ToString, '5-level nesting');
end;

procedure TestEmptyContainers;
var B: IJsonBuilder;
begin
  B := JsonBuilder;
  B.BeginObject; B.EndObject;
  CheckEqual('{}', B.ToString, 'empty object');

  B := JsonBuilder;
  B.BeginArray; B.EndArray;
  CheckEqual('[]', B.ToString, 'empty array');

  B := JsonBuilder;
  B.BeginObject;
    B.Key('arr'); B.BeginArray; B.EndArray;
    B.Key('obj'); B.BeginObject; B.EndObject;
  B.EndObject;
  CheckEqual('{"arr":[],"obj":{}}', B.ToString, 'nested empty');
end;

procedure TestLargeObject;
var B: IJsonBuilder; I: Int32; S: string;
begin
  B := JsonBuilder(8192);
  B.BeginObject;
  for I := 0 to 99 do
  begin
    B.Key('k' + IntToStr(I));
    B.Int(I);
  end;
  B.EndObject;
  S := B.ToString;
  Check(Pos('"k0":0', S) > 0, 'first key');
  Check(Pos('"k99":99', S) > 0, 'last key');
  Check(Int64(B.Len) > 500, 'large output');
end;

procedure TestSpecialStrings;
var B: IJsonBuilder; S: string;
begin
  B := JsonBuilder;
  B.BeginArray;
    B.Str('');
    B.Str('line1'#10'line2');
    B.Str(#9'tab');
    B.Str('back\slash');
  B.EndArray;
  S := B.ToString;
  Check(Pos('""', S) > 0, 'empty string');
  Check(Pos('\n', S) > 0, 'newline escaped');
  Check(Pos('\t', S) > 0, 'tab escaped');
  Check(Pos('\\', S) > 0, 'backslash escaped');
end;

procedure TestNumberEdges;
var B: IJsonBuilder; S: string;
begin
  B := JsonBuilder;
  B.BeginArray;
    B.Int(0);
    B.Int(-1);
    B.Int(9223372036854775807);
    B.Int(-9223372036854775808);
    B.UInt(0);
    B.UInt(18446744073709551615);
    B.Float(0.0);
    B.Float(1.0E308);
  B.EndArray;
  S := B.ToString;
  Check(Pos('9223372036854775807', S) > 0, 'int64 max');
  Check(Pos('-9223372036854775808', S) > 0, 'int64 min');
  Check(Pos('18446744073709551615', S) > 0, 'uint64 max');
end;

procedure TestMultipleRawJson;
var B: IJsonBuilder;
begin
  B := JsonBuilder;
  B.BeginArray;
    B.RawJson('{"a":1}');
    B.RawJson('[2,3]');
    B.RawJson('null');
  B.EndArray;
  CheckEqual('[{"a":1},[2,3],null]', B.ToString, 'multiple raw');
end;

procedure TestInvalidSequenceFailClosed;
var
  B: IJsonBuilder;
  LRaised: Boolean;
begin
  B := JsonBuilder;

  LRaised := False;
  try
    B.EndArray;
  except
    on E: EInvalidOperationError do
      LRaised := True;
  end;
  Check(LRaised, 'root EndArray raises invalid operation');
  CheckEqual('', B.ToString, 'root EndArray writes nothing');

  B.BeginObject;
  LRaised := False;
  try
    B.Bool(True);
  except
    on E: EInvalidOperationError do
      LRaised := True;
  end;
  Check(LRaised, 'object value before key raises invalid operation');
  CheckEqual('{', B.ToString, 'object value before key writes nothing');

  B.Key('x');
  LRaised := False;
  try
    B.EndObject;
  except
    on E: EInvalidOperationError do
      LRaised := True;
  end;
  Check(LRaised, 'pending object key close raises invalid operation');
  B.Int(1);
  B.EndObject;
  CheckEqual('{"x":1}', B.ToString, 'builder recovers after invalid sequence');
end;

procedure TestArrayKeyAndRootExtraValueFailClosed;
var
  B: IJsonBuilder;
  LRaised: Boolean;
begin
  B := JsonBuilder;
  B.BeginArray;
  LRaised := False;
  try
    B.Key('bad');
  except
    on E: EInvalidOperationError do
      LRaised := True;
  end;
  Check(LRaised, 'array key raises invalid operation');
  B.RawJson('null');
  B.EndArray;
  CheckEqual('[null]', B.ToString, 'array key failure writes nothing');

  LRaised := False;
  try
    B.Int(2);
  except
    on E: EInvalidOperationError do
      LRaised := True;
  end;
  Check(LRaised, 'root rejects value after completed root value');
  CheckEqual('[null]', B.ToString, 'root extra value writes nothing');
end;

procedure TestContainerDepthLimitFailsBeforeWriting;
var
  B: IJsonBuilder;
  I: Int32;
  LBefore: string;
  LRaised: Boolean;
begin
  B := JsonBuilder(SizeUInt(JSON_WRITER_MAX_DEPTH * 2 + 16));
  for I := 1 to JSON_WRITER_MAX_DEPTH do
    B.BeginArray;
  LBefore := B.ToString;

  LRaised := False;
  try
    B.BeginArray;
  except
    on E: EResourceExhaustedError do
      LRaised := True;
  end;
  Check(LRaised, 'builder container stack overflow raises resource exhausted');
  CheckEqual(LBefore, B.ToString,
    'builder container stack overflow writes nothing');

  for I := 1 to JSON_WRITER_MAX_DEPTH do
    B.EndArray;
  CheckEqual(StringOfChar('[', JSON_WRITER_MAX_DEPTH) +
    StringOfChar(']', JSON_WRITER_MAX_DEPTH), B.ToString,
    'builder remains recoverable after depth-limit failure');
end;

begin
  T := TTestRunner.Create('nextpas.core.json.builder');
  T.Run('simple object', @TestSimpleObject);
  T.Run('array', @TestArray);
  T.Run('nested', @TestNested);
  T.Run('all types', @TestAllTypes);
  T.Run('auto release', @TestAutoRelease);
  T.Run('raw json', @TestRawJson);
  T.Run('AsView', @TestAsView);
  T.Run('Len', @TestLen);
  T.Run('builder with capacity', @TestBuilderWithCapacity);
  T.Run('deep nesting', @TestDeepNesting);
  T.Run('empty containers', @TestEmptyContainers);
  T.Run('large object', @TestLargeObject);
  T.Run('special strings', @TestSpecialStrings);
  T.Run('number edges', @TestNumberEdges);
  T.Run('multiple raw json', @TestMultipleRawJson);
  T.Run('invalid sequence fail closed', @TestInvalidSequenceFailClosed);
  T.Run('array key and root extra value fail closed',
    @TestArrayKeyAndRootExtraValueFailClosed);
  T.Run('container depth limit fails before writing',
    @TestContainerDepthLimitFailsBeforeWriting);
  T.Summary;
end.
