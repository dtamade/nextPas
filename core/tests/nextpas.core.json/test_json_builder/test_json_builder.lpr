program test_json_builder;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.json.builder,
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

begin
  T := TTestRunner.Create('nextpas.core.json.builder');
  T.Run('simple object', @TestSimpleObject);
  T.Run('array', @TestArray);
  T.Run('nested', @TestNested);
  T.Run('all types', @TestAllTypes);
  T.Run('auto release', @TestAutoRelease);
  T.Run('raw json', @TestRawJson);
  T.Summary;
end.
