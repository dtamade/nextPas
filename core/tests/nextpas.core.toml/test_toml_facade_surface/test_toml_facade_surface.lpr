program test_toml_facade_surface;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.conv,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.io.memory,
  nextpas.core.text.view,
  nextpas.core.toml,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestFacadeExposesCoreSurface;
var
  LDoc: ITomlDocument;
  LValue: TTomlValue;
  LError: TTomlError;
  LBuilder: ITomlBuilder;
begin
  LDoc := TomlParse('title = "TOML"' + #10 + 'count = 2');
  Check(not LDoc.HasError, 'parse via facade succeeds');

  LValue := LDoc.Root;
  Check(LValue.IsTable, 'root is table');
  CheckEqual('TOML', LValue.Get('title').AsStr.ToString, 'title');
  CheckEqual(Int64(2), LValue.Get('count').AsInt, 'count');

  LError := TomlParse('= invalid').Error;
  Check(LError.Line > 0, 'error type visible through facade');
  CheckEqual(LError.Col, LError.Column, 'Col/Column aliases match');

  LBuilder := TomlBuilder;
  LBuilder.Key('when');
  LBuilder.DateTime(TomlDateTimeWithOffset(2024, 1, 15, 10, 30, 0, 0, 0));
  Check(Pos('when = ', LBuilder.ToString) = 1,
    'builder and datetime helpers available through facade');
end;

procedure TestFacadeEdgeDepthLargeAndDuplicate;
var
  LText: string;
  LPath: string;
  LDoc: ITomlDocument;
  LValue: TTomlValue;
  LI: Integer;
  LBig: string;
  LError: TTomlError;
begin
  LPath := 'l1';
  for LI := 2 to 16 do
    LPath := LPath + '.l' + IntToStr(LI);
  LText := '[' + LPath + ']' + #10 + 'v = 42' + #10;
  LDoc := TomlParse(LText);
  Check(not LDoc.HasError, 'deep nested tables parse');
  LValue := LDoc.Root;
  for LI := 1 to 16 do
    LValue := LValue.Get('l' + IntToStr(LI));
  CheckEqual(Int64(42), LValue.Get('v').AsInt, 'deep table value');

  SetLength(LBig, 4096);
  for LI := 1 to 4096 do
    LBig[LI] := Chr(Ord('A') + (LI mod 26));
  LDoc := TomlParse('blob = "' + LBig + '"' + #10);
  Check(not LDoc.HasError, 'large string value parses');
  CheckEqual(Int64(4096), Int64(Length(LDoc.Root.Get('blob').AsStr.ToString)),
    'large string length');

  LDoc := TomlParse('a = 1' + #10 + 'a = 2' + #10);
  Check(LDoc.HasError, 'duplicate key rejected');
  LError := LDoc.Error;
  Check(LError.Line > 0, 'duplicate key error has line');
end;

function TomlBytesFromString(const AText: string): TBytes;
var
  LI: Integer;
begin
  SetLength(Result, Length(AText));
  for LI := 1 to Length(AText) do
    Result[LI - 1] := Byte(AText[LI]);
end;

procedure TestFacadeExposesReaderParse;
var
  LStream: IStream;
  LDoc: ITomlDocument;
  LRaised: Boolean;
begin
  LStream := CreateBytesStreamFrom(TomlBytesFromString('x = 9' + #10));
  LDoc := TomlParse(LStream as IReader);
  Check(not LDoc.HasError, 'IReader toml parse');
  CheckEqual(Int64(9), LDoc.Root.Get('x').AsInt, 'IReader value');
  LRaised := False;
  try
    TomlParse(IReader(nil));
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'nil IReader raises');
end;

procedure TestFacadeExposesTryAsAccessors;
var
  LDoc: ITomlDocument;
  LRoot: TTomlValue;
  LBool: Boolean;
  LInt: Int64;
  LFloat: Double;
  LStr: TStringView;
begin
  LDoc := TomlParse('b = true' + #10 + 'i = 11' + #10 + 'f = 3.5' + #10 +
    's = "ok"' + #10);
  Check(not LDoc.HasError, 'tryas parse');
  LRoot := LDoc.Root;
  Check(LRoot.Get('b').TryAsBool(LBool) and LBool, 'TryAsBool');
  Check(LRoot.Get('i').TryAsInt(LInt) and (LInt = 11), 'TryAsInt');
  Check(LRoot.Get('f').TryAsFloat(LFloat) and (Abs(LFloat - 3.5) < 1e-9),
    'TryAsFloat');
  Check(LRoot.Get('s').TryAsStr(LStr) and (LStr.ToString = 'ok'), 'TryAsStr');
  Check(not LRoot.Get('s').TryAsInt(LInt), 'TryAsInt rejects string');
end;

begin
  T := TTestSuite.Create('nextpas.core.toml (facade surface)');
  T.Test('facade exposes core surface', @TestFacadeExposesCoreSurface);
  T.Test('facade edge depth large and duplicate',
    @TestFacadeEdgeDepthLargeAndDuplicate);
  T.Test('facade exposes reader parse', @TestFacadeExposesReaderParse);
  T.Test('facade exposes TryAs accessors', @TestFacadeExposesTryAsAccessors);
  if not T.Run then Halt(1);
end.
