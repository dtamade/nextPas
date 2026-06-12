program test_json_writer;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.text.view,
  nextpas.core.text.builder,
  nextpas.core.json.writer,
  nextpas.core.errors,
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

procedure TestLongKeyEscape;
var B: TStringBuilder; W: TJsonWriter;
const
  LONG_KEY = 'abcdefghijklmnop"qrstuvwxyz012345';
  EXPECTED = '{"abcdefghijklmnop\"qrstuvwxyz012345":1}';
begin
  B.Init(128); W.Init(B);
  W.BeginObject;
  W.Key(PAnsiChar(LONG_KEY), Length(LONG_KEY));
  W.Int(1);
  W.EndObject;
  CheckEqual(EXPECTED, B.ToString, 'long key quote escaped');
  B.Done;
end;

procedure TestInvalidCloseOperationsFailClosed;
var
  B: TStringBuilder;
  W: TJsonWriter;
  LRaised: Boolean;
begin
  B.Init(64);
  try
    W.Init(B);

    LRaised := False;
    try
      W.EndObject;
    except
      on E: EInvalidOperationError do
        LRaised := True;
    end;
    Check(LRaised, 'root EndObject raises invalid operation');
    CheckEqual('', B.ToString, 'invalid root close writes nothing');

    W.BeginArray;
    LRaised := False;
    try
      W.EndObject;
    except
      on E: EInvalidOperationError do
        LRaised := True;
    end;
    Check(LRaised, 'mismatched EndObject raises invalid operation');
    W.Int(7);
    W.EndArray;
    CheckEqual('[7]', B.ToString, 'mismatched close preserves open array');
  finally
    B.Done;
  end;
end;

procedure TestObjectKeyValueSequenceFailClosed;
var
  B: TStringBuilder;
  W: TJsonWriter;
  LRaised: Boolean;
begin
  B.Init(128);
  try
    W.Init(B);
    W.BeginObject;

    LRaised := False;
    try
      W.Int(1);
    except
      on E: EInvalidOperationError do
        LRaised := True;
    end;
    Check(LRaised, 'object value before key raises invalid operation');
    CheckEqual('{', B.ToString, 'value-before-key writes nothing');

    W.Key('a');
    LRaised := False;
    try
      W.Key('b');
    except
      on E: EInvalidOperationError do
        LRaised := True;
    end;
    Check(LRaised, 'key before previous value raises invalid operation');
    W.Int(2);

    W.Key('pending');
    LRaised := False;
    try
      W.EndObject;
    except
      on E: EInvalidOperationError do
        LRaised := True;
    end;
    Check(LRaised, 'pending object key close raises invalid operation');
    W.Str('value');
    W.EndObject;
    CheckEqual('{"a":2,"pending":"value"}', B.ToString,
      'invalid object operations preserve recoverable state');
  finally
    B.Done;
  end;
end;

procedure TestArrayRejectsKeysAndRootRejectsExtraValues;
var
  B: TStringBuilder;
  W: TJsonWriter;
  LRaised: Boolean;
begin
  B.Init(128);
  try
    W.Init(B);
    W.BeginArray;
    LRaised := False;
    try
      W.Key('bad');
    except
      on E: EInvalidOperationError do
        LRaised := True;
    end;
    Check(LRaised, 'array key raises invalid operation');
    W.Int(1);
    W.EndArray;
    CheckEqual('[1]', B.ToString, 'array key failure writes nothing');

    LRaised := False;
    try
      W.Null;
    except
      on E: EInvalidOperationError do
        LRaised := True;
    end;
    Check(LRaised, 'root rejects value after completed root value');
    CheckEqual('[1]', B.ToString, 'extra root value writes nothing');
  finally
    B.Done;
  end;
end;

procedure TestContainerDepthLimitFailsBeforeWriting;
var
  B: TStringBuilder;
  W: TJsonWriter;
  I: Int32;
  LBefore: string;
  LRaised: Boolean;
begin
  B.Init(SizeUInt(JSON_WRITER_MAX_DEPTH * 2 + 16));
  try
    W.Init(B);
    for I := 1 to JSON_WRITER_MAX_DEPTH do
      W.BeginArray;
    LBefore := B.ToString;

    LRaised := False;
    try
      W.BeginArray;
    except
      on E: EResourceExhaustedError do
        LRaised := True;
    end;
    Check(LRaised, 'container stack overflow raises resource exhausted');
    CheckEqual(LBefore, B.ToString,
      'container stack overflow writes nothing');

    for I := 1 to JSON_WRITER_MAX_DEPTH do
      W.EndArray;
    CheckEqual(StringOfChar('[', JSON_WRITER_MAX_DEPTH) +
      StringOfChar(']', JSON_WRITER_MAX_DEPTH), B.ToString,
      'writer remains recoverable after depth-limit failure');
  finally
    B.Done;
  end;
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
  T.Run('long key escape', @TestLongKeyEscape);
  T.Run('invalid close operations fail closed',
    @TestInvalidCloseOperationsFailClosed);
  T.Run('object key/value sequence fail closed',
    @TestObjectKeyValueSequenceFailClosed);
  T.Run('array key and root extra value fail closed',
    @TestArrayRejectsKeysAndRootRejectsExtraValues);
  T.Run('container depth limit fails before writing',
    @TestContainerDepthLimitFailsBeforeWriting);
  T.Summary;
end.
