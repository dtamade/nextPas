program test_json_facade_surface;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.json,
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

  LError := JsonParse('{bad}').Error;
  Check(LError.Line > 0, 'error type visible through facade');

  CheckEqual('42', JsonStringify(JsonParse('42').Root),
    'JsonStringify available through facade');
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
  T.Test('facade exposes reader parse', @TestFacadeExposesReaderParse);
  if not T.Run then Halt(1);
end.
