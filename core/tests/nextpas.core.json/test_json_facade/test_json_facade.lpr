program test_json_facade;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.mem.default,
  nextpas.core.json,
  nextpas.core.json.types,
  nextpas.core.json.value,
  nextpas.core.testing;

var
  T: TTestRunner;

function BuildLargeDuplicateKeyObject: string;
var
  LI: Integer;
begin
  Result := '{"dup":1';
  for LI := 1 to 16 do
    Result := Result + ',"k' + IntToStr(LI) + '":' + IntToStr(LI);
  Result := Result + ',"dup":99}';
end;


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

procedure TestJsonParseErrorPosition;
var
  LDoc: IJsonDocument;
  LErr: TJsonError;
const
  INPUT = '{"ok":true}'#10'bad';
begin
  LDoc := JsonParse(INPUT);
  Check(LDoc.HasError, 'has trailing-content error');
  LErr := LDoc.Error;
  CheckEqual('trailing content', LErr.Message.ToString, 'diagnostic message');
  CheckEqual(Int64(12), Int64(LErr.Offset), 'diagnostic byte offset');
  CheckEqual(Int64(2), Int64(LErr.Line), 'diagnostic line');
  CheckEqual(Int64(1), Int64(LErr.Column), 'diagnostic column');
end;

procedure TestJsonParseUnexpectedEndOfInputPosition;
var
  LDoc: IJsonDocument;
  LErr: TJsonError;
begin
  LDoc := JsonParse('{"server":');
  Check(LDoc.HasError, 'has eof error');
  LErr := LDoc.Error;
  CheckEqual('unexpected end of input', LErr.Message.ToString,
    'diagnostic message');
  CheckEqual(Int64(10), Int64(LErr.Offset), 'diagnostic byte offset');
  CheckEqual(Int64(1), Int64(LErr.Line), 'diagnostic line');
  CheckEqual(Int64(11), Int64(LErr.Column), 'diagnostic column');
end;

procedure TestJsonDiagnosticDocumentStringifyFailsClosed;
var
  LDoc: IJsonDocument;
  LTryDoc: IJsonDocument;
  LRaised: Boolean;

  procedure CheckDiagnosticStringifyFailsClosed(const ADoc: IJsonDocument;
    const ASource: string);
  begin
    Check(ADoc.HasError, ASource + ' diagnostic doc has error');

    LRaised := False;
    try
      ADoc.Stringify;
    except
      on E: EInvalidOperationError do
      begin
        LRaised := True;
        Check(Pos('diagnostic document', E.Message) > 0,
          ASource + ' stringify error identifies diagnostic document');
      end;
    end;
    Check(LRaised, ASource + ' Stringify raises for diagnostic document');

    LRaised := False;
    try
      ADoc.StringifyPretty(2);
    except
      on E: EInvalidOperationError do
      begin
        LRaised := True;
        Check(Pos('diagnostic document', E.Message) > 0,
          ASource + ' pretty stringify error identifies diagnostic document');
      end;
    end;
    Check(LRaised, ASource + ' StringifyPretty raises for diagnostic document');

    LRaised := False;
    try
      JsonStringify(ADoc.Root);
    except
      on E: EInvalidOperationError do
      begin
        LRaised := True;
        Check(Pos('diagnostic document', E.Message) > 0,
          ASource + ' value stringify error identifies diagnostic document');
      end;
    end;
    Check(LRaised, ASource + ' JsonStringify raises for diagnostic document root');
  end;
begin
  LDoc := JsonParse('{"server":');
  CheckDiagnosticStringifyFailsClosed(LDoc, 'JsonParse');

  Check(not TryJsonParse('{"server":', LTryDoc), 'TryJsonParse failure');
  CheckDiagnosticStringifyFailsClosed(LTryDoc, 'TryJsonParse');
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
  LErr: TJsonError;
begin
  Check(not TryJsonParse('{"server":', LDoc), 'try parse failure');
  Check(LDoc <> nil, 'diagnostic doc assigned');
  Check(LDoc.HasError, 'diagnostic doc has error');
  LErr := LDoc.Error;
  CheckEqual('unexpected end of input', LErr.Message.ToString,
    'diagnostic message');
  CheckEqual(Int64(10), Int64(LErr.Offset), 'diagnostic byte offset');
  CheckEqual(Int64(1), Int64(LErr.Line), 'diagnostic line');
  CheckEqual(Int64(11), Int64(LErr.Column), 'diagnostic column');
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

procedure TestDuplicateKeyLookupAndIterationSmallObject;
var
  Doc: IJsonDocument;
  Root: TJsonValue;
begin
  Doc := JsonParse('{"dup":1,"keep":2,"dup":3}');
  Check(not Doc.HasError, 'small duplicate object parses');
  Root := Doc.Root;
  CheckEqual(Int64(3), Int64(Root.ObjectLen),
    'small-object iteration keeps duplicate entries');
  CheckEqual(Int64(3), Root.ObjectGet('dup').AsInt,
    'small-object lookup returns last duplicate value');
  CheckEqual('dup', Root.ObjectKeyAt(0).ToString,
    'small-object first duplicate key retained');
  CheckEqual(Int64(1), Root.ObjectValueAt(0).AsInt,
    'small-object first duplicate value retained');
  CheckEqual('dup', Root.ObjectKeyAt(2).ToString,
    'small-object last duplicate key retained');
  CheckEqual(Int64(3), Root.ObjectValueAt(2).AsInt,
    'small-object last duplicate value retained');
end;

procedure TestDuplicateKeyLookupAndIterationLargeObject;
var
  Doc: IJsonDocument;
  Root: TJsonValue;
  Input: string;
begin
  Input := BuildLargeDuplicateKeyObject;
  Doc := JsonParse(Input);
  Check(not Doc.HasError, 'large duplicate object parses');
  Root := Doc.Root;
  CheckEqual(Int64(18), Int64(Root.ObjectLen),
    'large-object iteration keeps duplicate entries');
  CheckEqual(Int64(99), Root.ObjectGet('dup').AsInt,
    'large-object lookup returns last duplicate value');
  CheckEqual(Int64(16), Root.ObjectGet('k16').AsInt,
    'large-object hash path still finds ordinary keys');
  CheckEqual('dup', Root.ObjectKeyAt(0).ToString,
    'large-object first duplicate key retained');
  CheckEqual(Int64(1), Root.ObjectValueAt(0).AsInt,
    'large-object first duplicate value retained');
  CheckEqual('dup', Root.ObjectKeyAt(17).ToString,
    'large-object last duplicate key retained');
  CheckEqual(Int64(99), Root.ObjectValueAt(17).AsInt,
    'large-object last duplicate value retained');
end;

begin
  T := TTestRunner.Create('nextpas.core.json (facade)');
  T.Run('parse interface', @TestJsonParseInterface);
  T.Run('auto release', @TestJsonParseAutoRelease);
  T.Run('stringify', @TestJsonStringify);
  T.Run('stringify func', @TestJsonStringifyFunc);
  T.Run('parse error', @TestJsonParseError);
  T.Run('parse error position', @TestJsonParseErrorPosition);
  T.Run('parse unexpected end of input position',
    @TestJsonParseUnexpectedEndOfInputPosition);
  T.Run('diagnostic document stringify fails closed',
    @TestJsonDiagnosticDocumentStringifyFailsClosed);
  T.Run('TryJsonParse success', @TestTryJsonParseSuccess);
  T.Run('TryJsonParse failure returns diagnostic doc', @TestTryJsonParseFailureReturnsDiagnosticDoc);
  T.Run('parse nested', @TestJsonParseNested);
  T.Run('pretty print', @TestPrettyPrint);
  T.Run('parse with allocator', @TestJsonParseWithAllocator);
  T.Run('stringify round-trip', @TestStringifyRoundTrip);
  T.Run('edge case numbers', @TestEdgeCaseNumbers);
  T.Run('escaped backslash combos', @TestEscapedBackslashCombos);
  T.Run('duplicate keys small object lookup and iteration',
    @TestDuplicateKeyLookupAndIterationSmallObject);
  T.Run('duplicate keys large object lookup and iteration',
    @TestDuplicateKeyLookupAndIterationLargeObject);
  T.Summary;
end.
