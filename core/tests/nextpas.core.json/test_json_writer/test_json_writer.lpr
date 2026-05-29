program test_json_writer;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.json.writer,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestEmptyObject;
var B: TStringBuilder; W: TJsonWriter;
begin
  B.Init(32); W.Init(B);
  W.BeginObject; W.EndObject;
  CheckEqual('{}', B.ToString, 'empty object');
  B.Done;
end;

procedure TestEmptyArray;
var B: TStringBuilder; W: TJsonWriter;
begin
  B.Init(32); W.Init(B);
  W.BeginArray; W.EndArray;
  CheckEqual('[]', B.ToString, 'empty array');
  B.Done;
end;

procedure TestSimpleObject;
var B: TStringBuilder; W: TJsonWriter;
begin
  B.Init(64); W.Init(B);
  W.BeginObject;
    W.Key('name'); W.Str('Alice');
    W.Key('age'); W.Int(30);
    W.Key('active'); W.Bool(True);
    W.Key('score'); W.Float(3.14);
    W.Key('data'); W.Null;
  W.EndObject;
  CheckEqual('{"name":"Alice","age":30,"active":true,"score":3.14,"data":null}',
    B.ToString, 'simple object');
  B.Done;
end;

procedure TestNestedObject;
var B: TStringBuilder; W: TJsonWriter;
begin
  B.Init(128); W.Init(B);
  W.BeginObject;
    W.Key('user'); W.BeginObject;
      W.Key('id'); W.Int(1);
      W.Key('name'); W.Str('Bob');
    W.EndObject;
  W.EndObject;
  CheckEqual('{"user":{"id":1,"name":"Bob"}}', B.ToString, 'nested');
  B.Done;
end;

procedure TestArray;
var B: TStringBuilder; W: TJsonWriter;
begin
  B.Init(64); W.Init(B);
  W.BeginArray;
    W.Int(1); W.Int(2); W.Int(3);
  W.EndArray;
  CheckEqual('[1,2,3]', B.ToString, 'int array');
  B.Done;
end;

procedure TestMixedArray;
var B: TStringBuilder; W: TJsonWriter;
begin
  B.Init(64); W.Init(B);
  W.BeginArray;
    W.Str('hello'); W.Int(42); W.Bool(False); W.Null;
  W.EndArray;
  CheckEqual('["hello",42,false,null]', B.ToString, 'mixed array');
  B.Done;
end;

procedure TestEscapedString;
var B: TStringBuilder; W: TJsonWriter;
begin
  B.Init(64); W.Init(B);
  W.BeginObject;
    W.Key('msg'); W.Str('he said "hi"');
  W.EndObject;
  CheckEqual('{"msg":"he said \"hi\""}', B.ToString, 'escaped');
  B.Done;
end;

procedure TestUInt;
var B: TStringBuilder; W: TJsonWriter;
begin
  B.Init(32); W.Init(B);
  W.BeginArray;
    W.UInt(18446744073709551615);
  W.EndArray;
  CheckEqual('[18446744073709551615]', B.ToString, 'uint64 max');
  B.Done;
end;

procedure TestNegativeInt;
var B: TStringBuilder; W: TJsonWriter;
begin
  B.Init(32); W.Init(B);
  W.BeginArray;
    W.Int(-9223372036854775808);
  W.EndArray;
  CheckEqual('[-9223372036854775808]', B.ToString, 'int64 min');
  B.Done;
end;

procedure TestRawValue;
var B: TStringBuilder; W: TJsonWriter;
begin
  B.Init(64); W.Init(B);
  W.BeginObject;
    W.Key('raw'); W.RawValue('{"pre":"built"}', 15);
  W.EndObject;
  CheckEqual('{"raw":{"pre":"built"}}', B.ToString, 'raw value');
  B.Done;
end;

procedure TestComplexNesting;
var B: TStringBuilder; W: TJsonWriter;
begin
  B.Init(128); W.Init(B);
  W.BeginObject;
    W.Key('items'); W.BeginArray;
      W.BeginObject;
        W.Key('id'); W.Int(1);
      W.EndObject;
      W.BeginObject;
        W.Key('id'); W.Int(2);
      W.EndObject;
    W.EndArray;
  W.EndObject;
  CheckEqual('{"items":[{"id":1},{"id":2}]}', B.ToString, 'complex');
  B.Done;
end;

begin
  T := TTestRunner.Create('nextpas.core.json.writer');
  T.Run('empty object', @TestEmptyObject);
  T.Run('empty array', @TestEmptyArray);
  T.Run('simple object', @TestSimpleObject);
  T.Run('nested object', @TestNestedObject);
  T.Run('array', @TestArray);
  T.Run('mixed array', @TestMixedArray);
  T.Run('escaped string', @TestEscapedString);
  T.Run('uint64', @TestUInt);
  T.Run('int64 min', @TestNegativeInt);
  T.Run('raw value', @TestRawValue);
  T.Run('complex nesting', @TestComplexNesting);
  T.Summary;
end.
