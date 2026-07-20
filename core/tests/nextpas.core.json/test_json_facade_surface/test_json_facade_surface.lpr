program test_json_facade_surface;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.format.limits,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.json,
  nextpas.core.text.view,
  nextpas.core.test;

var
  T: TTestSuite;

function BytesFromString(const AText: string): TBytes;
var
  LI: Integer;
begin
  SetLength(Result, Length(AText));
  for LI := 1 to Length(AText) do
    Result[LI - 1] := Byte(AText[LI]);
end;

procedure TestFacadeExposesCoreSurface;
var
  LDoc: IJsonDocument;
  LValue: TJsonValue;
  LError: TJsonError;
begin
  LDoc := JsonParse('{"name":"Alice","age":30}');
  Check(not LDoc.HasError, 'parse via facade succeeds');

  LValue := LDoc.Root;
  Check(LValue.IsObject, 'root is object');
  CheckEqual('Alice', LValue.ObjectGet('name').AsStr.ToString, 'name');
  CheckEqual(Int64(30), LValue.ObjectGet('age').AsInt, 'age');
  CheckEqual('Alice', LValue.Get('name').AsStr.ToString, 'Get aliases ObjectGet');
  Check(LValue.ObjectGet('age').IsInt or LValue.ObjectGet('age').IsFloat,
    'IsInt/IsFloat predicates');

  LError := JsonParse('{bad}').Error;
  Check(LError.Line > 0, 'error type visible through facade');
  CheckEqual(LError.Column, LError.Col, 'Column/Col aliases match');

  CheckEqual('42', JsonStringify(JsonParse('42').Root),
    'JsonStringify available through facade');
end;

procedure TestFacadeExposesTryAsAccessors;
var
  LDoc: IJsonDocument;
  LRoot: TJsonValue;
  LBool: Boolean;
  LInt: Int64;
  LFloat: Double;
  LStr: TStringView;
begin
  LDoc := JsonParse('{"b":true,"i":7,"f":1.25,"s":"hi","n":null}');
  Check(not LDoc.HasError, 'tryas parse');
  LRoot := LDoc.Root;
  Check(LRoot.ObjectGet('b').TryAsBool(LBool) and LBool, 'TryAsBool true');
  Check(LRoot.ObjectGet('i').TryAsInt(LInt) and (LInt = 7), 'TryAsInt');
  Check(LRoot.ObjectGet('f').TryAsFloat(LFloat) and (Abs(LFloat - 1.25) < 1e-9),
    'TryAsFloat');
  Check(LRoot.ObjectGet('i').TryAsFloat(LFloat) and (Abs(LFloat - 7.0) < 1e-9),
    'TryAsFloat promotes int');
  Check(LRoot.ObjectGet('s').TryAsStr(LStr) and (LStr.ToString = 'hi'),
    'TryAsStr');
  Check(not LRoot.ObjectGet('n').TryAsBool(LBool), 'TryAsBool rejects null');
  Check(not LRoot.ObjectGet('s').TryAsInt(LInt), 'TryAsInt rejects string');
end;

procedure TestBulkParseLimitGuard;
var
  LRaised: Boolean;
begin
  RequireFormatBulkByteCount(0, 'JsonBulk');
  RequireFormatBulkByteCount(FORMAT_BULK_PARSE_MAX_BYTES, 'JsonBulk');
  LRaised := False;
  try
    RequireFormatBulkByteCount(FORMAT_BULK_PARSE_MAX_BYTES + 1, 'JsonBulk');
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'bulk over limit raises EArgumentError');
end;

procedure TestFacadeExposesReaderParse;
var
  LStream: IStream;
  LDoc: IJsonDocument;
  LRaised: Boolean;
  LOk: Boolean;
begin
  LStream := CreateBytesStreamFrom(BytesFromString('{"k":7}'));
  LDoc := JsonParse(LStream as IReader);
  Check(not LDoc.HasError, 'IReader parse ok');
  CheckEqual(Int64(7), LDoc.Root.ObjectGet('k').AsInt, 'IReader value');

  LStream := CreateBytesStreamFrom(BytesFromString('[1,2]'));
  LOk := TryJsonParse(LStream as IReader, LDoc);
  Check(LOk, 'TryJsonParse IReader succeeds');
  CheckEqual(Int64(2), Int64(LDoc.Root.ArrayLen), 'TryJsonParse array len');

  LRaised := False;
  try
    JsonParse(IReader(nil));
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'nil IReader raises');
end;

begin
  T := TTestSuite.Create('nextpas.core.json (facade surface)');
  T.Test('facade exposes core surface', @TestFacadeExposesCoreSurface);
  T.Test('facade exposes TryAs accessors', @TestFacadeExposesTryAsAccessors);
  T.Test('facade exposes reader parse', @TestFacadeExposesReaderParse);
  T.Test('bulk parse limit guard', @TestBulkParseLimitGuard);
  if not T.Run then Halt(1);
end.
