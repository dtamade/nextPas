program test_csv_roundtrip;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.csv,
  nextpas.core.mem.default,
  nextpas.core.testing;

var
  T: TTestRunner;

{ ===== Writer → Reader roundtrip ===== }

procedure TestBasicRoundtrip;
var
  LWriter: TCsvWriter;
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LWriter := TCsvWriter.Create;
  LWriter.WriteRow(['name', 'age', 'city']);
  LWriter.WriteRow(['Ada', '37', 'London']);
  LReader := TCsvReader.Create(LWriter.ToString);
  Check(LReader.ReadRow(LFields), 'basic rt: row 1');
  CheckEqual('name', LFields[0], 'basic rt: name');
  CheckEqual('age', LFields[1], 'basic rt: age');
  CheckEqual('city', LFields[2], 'basic rt: city');
  Check(LReader.ReadRow(LFields), 'basic rt: row 2');
  CheckEqual('Ada', LFields[0], 'basic rt: Ada');
  CheckEqual('37', LFields[1], 'basic rt: 37');
  CheckEqual('London', LFields[2], 'basic rt: London');
  Check(not LReader.ReadRow(LFields), 'basic rt: end');
end;

procedure TestRoundtripWithQuoting;
var
  LWriter: TCsvWriter;
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LWriter := TCsvWriter.Create;
  LWriter.WriteRow(['text with "quotes"', 'hello, world', 'multiline']);
  LReader := TCsvReader.Create(LWriter.ToString);
  Check(LReader.ReadRow(LFields), 'quoting rt: row read');
  CheckEqual('text with "quotes"', LFields[0], 'quoting rt: quotes preserved');
  CheckEqual('hello, world', LFields[1], 'quoting rt: comma preserved');
  CheckEqual('multiline', LFields[2], 'quoting rt: normal field');
end;

procedure TestRoundtripWithNewlines;
var
  LWriter: TCsvWriter;
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LWriter := TCsvWriter.Create;
  LWriter.WriteRow(['line1' + #10 + 'line2', 'normal']);
  LReader := TCsvReader.Create(LWriter.ToString);
  Check(LReader.ReadRow(LFields), 'newline rt: row read');
  CheckEqual('line1' + #10 + 'line2', LFields[0], 'newline rt: newline preserved');
  CheckEqual('normal', LFields[1], 'newline rt: normal field');
end;

procedure TestRoundtripWithEmpty;
var
  LWriter: TCsvWriter;
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LWriter := TCsvWriter.Create;
  LWriter.WriteRow(['', 'middle', '']);
  LReader := TCsvReader.Create(LWriter.ToString);
  Check(LReader.ReadRow(LFields), 'empty rt: row read');
  CheckEqual('', LFields[0], 'empty rt: first empty');
  CheckEqual('middle', LFields[1], 'empty rt: middle');
  CheckEqual('', LFields[2], 'empty rt: last empty');
end;

procedure TestRoundtripTabDelimiter;
var
  LWriter: TCsvWriter;
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LWriter := TCsvWriter.Create(#9);
  LWriter.WriteRow(['a', 'b', 'c']);
  LReader := TCsvReader.Create(LWriter.ToString, #9);
  Check(LReader.ReadRow(LFields), 'tab rt: row read');
  CheckEqual('a', LFields[0], 'tab rt: a');
  CheckEqual('b', LFields[1], 'tab rt: b');
  CheckEqual('c', LFields[2], 'tab rt: c');
end;

procedure TestRoundtripCRLF;
var
  LWriter: TCsvWriter;
  LReader: TCsvReader;
  LFields: TStringArray;
  LStr: string;
begin
  LWriter := TCsvWriter.Create(',', True);
  LWriter.WriteRow(['a', 'b']);
  LWriter.WriteRow(['1', '2']);
  LStr := LWriter.ToString;
  Check(Pos(#13#10, LStr) > 0, 'CRLF rt: has CRLF');
  LReader := TCsvReader.Create(LStr);
  Check(LReader.ReadRow(LFields), 'CRLF rt: row 1');
  Check(LReader.ReadRow(LFields), 'CRLF rt: row 2');
  Check(not LReader.ReadRow(LFields), 'CRLF rt: end');
end;

procedure TestRoundtripCreateWith;
var
  LWriter: TCsvWriter;
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LWriter := TCsvWriter.CreateWith(DefaultAllocator);
  LWriter.WriteRow(['hello', 'world']);
  LReader := TCsvReader.Create(LWriter.ToString, ',', 0, False, #0, DefaultAllocator);
  Check(LReader.ReadRow(LFields), 'CreateWith rt: row read');
  CheckEqual('hello', LFields[0], 'CreateWith rt: hello');
  CheckEqual('world', LFields[1], 'CreateWith rt: world');
end;

procedure TestRoundtripLargeDataset;
var
  LWriter: TCsvWriter;
  LReader: TCsvReader;
  LFields: TStringArray;
  LInput, LOutput: string;
  LI, LRowCount: Integer;
begin
  { Write 100 rows }
  LWriter := TCsvWriter.Create;
  for LI := 0 to 99 do
    LWriter.WriteRow(['row' + IntToStr(LI), 'col' + IntToStr(LI)]);
  LOutput := LWriter.ToString;
  { Read back all rows }
  LReader := TCsvReader.Create(LOutput);
  LRowCount := 0;
  while LReader.ReadRow(LFields) do
  begin
    Inc(LRowCount);
    CheckEqual(UInt64(2), UInt64(Length(LFields)),
      'large rt: row ' + IntToStr(LRowCount) + ' has 2 fields');
  end;
  CheckEqual(Int64(100), Int64(LRowCount), 'large rt: 100 rows');
  Check(not LReader.HasError, 'large rt: no error');
end;

{ ===== Parse → Write → Re-parse ===== }

procedure TestParseThenWrite;
var
  LRows: TStringMatrix;
  LWriter: TCsvWriter;
  LI: Integer;
  LReader: TCsvReader;
  LFields: TStringArray;
  LCount: Integer;
begin
  LRows := CsvParse('a,b,c' + #10 + '1,2,3' + #10 + 'x,y,z');
  CheckEqual(UInt64(3), UInt64(Length(LRows)), 'parse-write: 3 rows');

  LWriter := TCsvWriter.Create;
  for LI := 0 to High(LRows) do
    LWriter.WriteRow(LRows[LI]);
  LReader := TCsvReader.Create(LWriter.ToString);
  LCount := 0;
  while LReader.ReadRow(LFields) do
  begin
    Inc(LCount);
    CheckEqual(UInt64(3), UInt64(Length(LFields)),
      'parse-write: row ' + IntToStr(LCount) + ' has 3 fields');
  end;
  CheckEqual(Int64(3), Int64(LCount), 'parse-write: 3 rows read back');
end;

begin
  T := TTestRunner.Create('csv roundtrip');
  T.Run('basic roundtrip', @TestBasicRoundtrip);
  T.Run('roundtrip with quoting', @TestRoundtripWithQuoting);
  T.Run('roundtrip with newlines', @TestRoundtripWithNewlines);
  T.Run('roundtrip with empty fields', @TestRoundtripWithEmpty);
  T.Run('roundtrip tab delimiter', @TestRoundtripTabDelimiter);
  T.Run('roundtrip CRLF', @TestRoundtripCRLF);
  T.Run('roundtrip with CreateWith', @TestRoundtripCreateWith);
  T.Run('roundtrip large dataset', @TestRoundtripLargeDataset);
  T.Run('parse then write roundtrip', @TestParseThenWrite);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
