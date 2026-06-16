program test_csv_facade_surface;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.csv,
  nextpas.core.mem.default,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestFacadeExposesCoreSurface;
var
  LReader: TCsvReader;
  LFields: TStringArray;
  LRows: TStringMatrix;
  LWriter: TCsvWriter;
  LError: TCsvError;
begin
  LReader := TCsvReader.Create('name,age' + #10 + 'Ada,37');
  Check(LReader.ReadRow(LFields), 'header row readable via facade');
  CheckEqual('name', LFields[0], 'header field 0');
  CheckEqual('age', LFields[1], 'header field 1');
  Check(LReader.ReadRow(LFields), 'data row readable via facade');
  CheckEqual('Ada', LFields[0], 'data field 0');
  CheckEqual('37', LFields[1], 'data field 1');
  CheckEqual(False, LReader.ReadRow(LFields), 'reader reaches end');
  CheckEqual(False, LReader.HasError, 'reader success state exposed');

  LRows := TCsvReader.Create('lang,year' + #10 + 'Pascal,1970').ReadAll;
  CheckEqual(Int64(2), Int64(Length(LRows)), 'matrix row count visible');
  CheckEqual('Pascal', LRows[1][0], 'matrix field value visible');

  LReader := TCsvReader.Create('"unterminated');
  Check(LReader.ReadRow(LFields), 'malformed row still surfaces a row call result');
  Check(LReader.HasError, 'reader error state visible');
  LError := LReader.Error;
  Check(LError.Line > 0, 'structured csv error visible through facade');
  Check(LReader.GetError <> '', 'string error visible through facade');

  LWriter := TCsvWriter.Create(';');
  LWriter.WriteField('left');
  LWriter.WriteField('right');
  LWriter.EndRow;
  LWriter.WriteRow(['Ada', '37']);
  Check(Pos('left;right', LWriter.ToString) = 1,
    'writer surface visible through facade');
end;

procedure TestFacadeExposesAllocatorSurface;
var
  LReader: TCsvReader;
  LRows: TStringMatrix;
begin
  LReader := TCsvReader.Create('x,y', ',', 0, False, #0, nil);
  Check(LReader.Allocator <> nil, 'reader allocator accessor visible');

  LRows := CsvParse('name,age' + #10 + 'Ada,37');
  CheckEqual(Int64(2), Int64(Length(LRows)), 'CsvParse row count visible');
  CheckEqual('37', LRows[1][1], 'CsvParse data value visible');

  LRows := CsvParseWith('lang;year' + #10 + 'Pascal;1970',
    DefaultAllocator, ';');
  CheckEqual(Int64(2), Int64(Length(LRows)),
    'CsvParseWith row count visible');
  CheckEqual('Pascal', LRows[1][0], 'CsvParseWith field value visible');
end;

begin
  T := TTestRunner.Create('nextpas.core.csv (facade surface)');
  T.Run('facade exposes core surface', @TestFacadeExposesCoreSurface);
  T.Run('facade exposes allocator surface',
    @TestFacadeExposesAllocatorSurface);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
