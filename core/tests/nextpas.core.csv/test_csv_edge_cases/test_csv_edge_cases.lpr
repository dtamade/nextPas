program test_csv_edge_cases;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.csv,
  nextpas.core.testing;

var
  T: TTestRunner;

{ ===== RFC 4180 edge cases ===== }

procedure TestCRLFLineEndings;
var
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LReader := TCsvReader.Create('a,b' + #13#10 + '1,2');
  Check(LReader.ReadRow(LFields), 'CRLF: read row 1');
  CheckEqual('a', LFields[0], 'CRLF: header a');
  Check(LReader.ReadRow(LFields), 'CRLF: read row 2');
  CheckEqual('1', LFields[0], 'CRLF: data 1');
  Check(not LReader.ReadRow(LFields), 'CRLF: end of file');
end;

procedure TestLFOnlyLineEndings;
var
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LReader := TCsvReader.Create('a,b' + #10 + '1,2');
  Check(LReader.ReadRow(LFields), 'LF: read row 1');
  Check(LReader.ReadRow(LFields), 'LF: read row 2');
  Check(not LReader.ReadRow(LFields), 'LF: end of file');
end;

procedure TestCROnlyLineEndings;
var
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LReader := TCsvReader.Create('a,b' + #13 + '1,2');
  Check(LReader.ReadRow(LFields), 'CR: read row 1');
  Check(LReader.ReadRow(LFields), 'CR: read row 2');
end;

procedure TestQuotedFieldWithComma;
var
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LReader := TCsvReader.Create('"hello, world",42');
  Check(LReader.ReadRow(LFields), 'quoted comma: row read');
  CheckEqual('hello, world', LFields[0], 'quoted comma: field 0');
  CheckEqual('42', LFields[1], 'quoted comma: field 1');
end;

procedure TestQuotedFieldWithNewline;
var
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LReader := TCsvReader.Create('"line1' + #10 + 'line2",next');
  Check(LReader.ReadRow(LFields), 'quoted newline: row read');
  CheckEqual('line1' + #10 + 'line2', LFields[0], 'quoted newline: field 0');
  CheckEqual('next', LFields[1], 'quoted newline: field 1');
end;

procedure TestEscapedQuotes;
var
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LReader := TCsvReader.Create('"say ""hello""",end');
  Check(LReader.ReadRow(LFields), 'escaped quote: row read');
  CheckEqual('say "hello"', LFields[0], 'escaped quote: field 0');
end;

{ ===== Empty and edge field cases ===== }

procedure TestEmptyFields;
var
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LReader := TCsvReader.Create(',');
  Check(LReader.ReadRow(LFields), 'empty fields: row read');
  CheckEqual(UInt64(2), UInt64(Length(LFields)), 'empty fields: 2 fields');
  CheckEqual('', LFields[0], 'empty fields: field 0 empty');
  CheckEqual('', LFields[1], 'empty fields: field 1 empty');
end;

procedure TestTrailingEmptyField;
var
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LReader := TCsvReader.Create('a,b,');
  Check(LReader.ReadRow(LFields), 'trailing empty: row read');
  CheckEqual(UInt64(3), UInt64(Length(LFields)), 'trailing empty: 3 fields');
  CheckEqual('', LFields[2], 'trailing empty: field 2 empty');
end;

procedure TestLeadingEmptyField;
var
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LReader := TCsvReader.Create(',b,c');
  Check(LReader.ReadRow(LFields), 'leading empty: row read');
  CheckEqual(UInt64(3), UInt64(Length(LFields)), 'leading empty: 3 fields');
  CheckEqual('', LFields[0], 'leading empty: field 0 empty');
  CheckEqual('b', LFields[1], 'leading empty: field 1');
end;

procedure TestSingleField;
var
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LReader := TCsvReader.Create('solo');
  Check(LReader.ReadRow(LFields), 'single field: row read');
  CheckEqual(UInt64(1), UInt64(Length(LFields)), 'single field: 1 field');
  CheckEqual('solo', LFields[0], 'single field: value');
end;

procedure TestQuotedEmptyString;
var
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LReader := TCsvReader.Create('""');
  Check(LReader.ReadRow(LFields), 'quoted empty: row read');
  CheckEqual('', LFields[0], 'quoted empty: empty string');
end;

{ ===== Custom delimiter tests ===== }

procedure TestTabDelimiter;
var
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LReader := TCsvReader.Create('a' + #9 + 'b' + #10 + '1' + #9 + '2', #9);
  Check(LReader.ReadRow(LFields), 'tab: read row 1');
  CheckEqual('a', LFields[0], 'tab: header a');
  CheckEqual('b', LFields[1], 'tab: header b');
  Check(LReader.ReadRow(LFields), 'tab: read row 2');
  CheckEqual('1', LFields[0], 'tab: data 1');
end;

procedure TestSemicolonDelimiter;
var
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LReader := TCsvReader.Create('a;b' + #10 + '1;2', ';');
  Check(LReader.ReadRow(LFields), 'semicolon: read row 1');
  CheckEqual('a', LFields[0], 'semicolon: header a');
  Check(LReader.ReadRow(LFields), 'semicolon: read row 2');
  CheckEqual('1', LFields[0], 'semicolon: data 1');
end;

{ ===== Comment handling ===== }

procedure TestCommentLines;
var
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LReader := TCsvReader.Create('# comment' + #10 + 'a,b' + #10 + '# another' + #10 + '1,2', ',', 0, False, '#');
  Check(LReader.ReadRow(LFields), 'comment: read row 1');
  CheckEqual('a', LFields[0], 'comment: header a');
  Check(LReader.ReadRow(LFields), 'comment: read row 2');
  CheckEqual('1', LFields[0], 'comment: data 1');
  Check(not LReader.ReadRow(LFields), 'comment: end');
end;

{ ===== FieldsPerRecord validation ===== }

procedure TestFieldsPerRecordMatch;
var
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LReader := TCsvReader.Create('a,b' + #10 + '1,2', ',', 2);
  Check(LReader.ReadRow(LFields), 'FPR match: row 1');
  Check(LReader.ReadRow(LFields), 'FPR match: row 2');
  Check(not LReader.ReadRow(LFields), 'FPR match: end');
end;

procedure TestFieldsPerRecordMismatch;
var
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LReader := TCsvReader.Create('a,b' + #10 + '1,2,3', ',', 2);
  Check(LReader.ReadRow(LFields), 'FPR mismatch: row 1');
  Check(LReader.ReadRow(LFields), 'FPR mismatch: row 2 still succeeds');
  Check(LReader.HasError, 'FPR mismatch: error set');
  Check(Pos('Wrong number', LReader.GetError) > 0, 'FPR mismatch: error message');
end;

{ ===== TrimSpace behavior ===== }

procedure TestTrimSpaceOn;
var
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LReader := TCsvReader.Create(' a , b ' + #10 + ' 1 , 2 ', ',', 0, True);
  Check(LReader.ReadRow(LFields), 'trim space: row 1');
  CheckEqual('a', LFields[0], 'trim space: trimmed a');
  CheckEqual('b', LFields[1], 'trim space: trimmed b');
  Check(LReader.ReadRow(LFields), 'trim space: row 2');
  CheckEqual('1', LFields[0], 'trim space: trimmed 1');
end;

procedure TestTrimSpaceOnQuoted;
var
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LReader := TCsvReader.Create(' " quoted " , " data " ', ',', 0, True);
  Check(LReader.ReadRow(LFields), 'trim space quoted: row read');
  CheckEqual(' quoted ', LFields[0], 'trim space quoted: interior spaces preserved');
end;

{ ===== BOM handling ===== }

procedure TestUTF8BOM;
var
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LReader := TCsvReader.Create(#$EF#$BB#$BF + 'name,age' + #10 + 'Ada,37');
  Check(LReader.ReadRow(LFields), 'BOM: row 1 read');
  CheckEqual(#$EF#$BB#$BF + 'name', LFields[0], 'BOM: preserved in first field');
  Check(LReader.ReadRow(LFields), 'BOM: row 2 read');
  CheckEqual('Ada', LFields[0], 'BOM: data Ada');
end;

{ ===== Empty input ===== }

procedure TestEmptyInput;
var
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LReader := TCsvReader.Create('');
  Check(not LReader.ReadRow(LFields), 'empty input: no rows');
  Check(not LReader.HasError, 'empty input: no error');
end;

procedure TestBlankLineInput;
var
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LReader := TCsvReader.Create(#10 + #10 + #10);
  Check(not LReader.ReadRow(LFields), 'blank lines: no rows');
  Check(not LReader.HasError, 'blank lines: no error');
end;

{ ===== CsvParse/CsvParseWith edge cases ===== }

procedure TestCsvParseEmpty;
var
  LRows: TStringMatrix;
begin
  LRows := CsvParse('');
  CheckEqual(UInt64(0), UInt64(Length(LRows)), 'CsvParse empty: 0 rows');
end;

procedure TestCsvParseSingleRow;
var
  LRows: TStringMatrix;
begin
  LRows := CsvParse('only');
  CheckEqual(UInt64(1), UInt64(Length(LRows)), 'CsvParse single: 1 row');
  CheckEqual('only', LRows[0][0], 'CsvParse single: value');
end;

procedure TestCsvParseWithDelimiter;
var
  LRows: TStringMatrix;
begin
  LRows := CsvParseWith('a;b', nil, ';');
  CheckEqual(UInt64(1), UInt64(Length(LRows)), 'CsvParseWith semicolon: 1 row');
  CheckEqual('a', LRows[0][0], 'CsvParseWith semicolon: field 0');
  CheckEqual('b', LRows[0][1], 'CsvParseWith semicolon: field 1');
end;

{ ===== Very long field ===== }

procedure TestLongField;
var
  LReader: TCsvReader;
  LFields: TStringArray;
  LLong: string;
  LI: Integer;
begin
  LLong := '';
  for LI := 1 to 4096 do
    LLong := LLong + 'x';
  LReader := TCsvReader.Create(LLong + ',end');
  Check(LReader.ReadRow(LFields), 'long field: row read');
  CheckEqual(UInt64(2), UInt64(Length(LFields)), 'long field: 2 fields');
  CheckEqual(LLong, LFields[0], 'long field: value preserved');
  CheckEqual('end', LFields[1], 'long field: second field');
end;

{ ===== ReadAll with large dataset ===== }

procedure TestReadAllLarge;
var
  LInput: string;
  LI: Integer;
  LRows: TStringMatrix;
begin
  LInput := '';
  for LI := 0 to 199 do
    LInput := LInput + IntToStr(LI) + ',field' + IntToStr(LI) + #10;
  LRows := TCsvReader.Create(LInput).ReadAll;
  CheckEqual(UInt64(200), UInt64(Length(LRows)), 'ReadAll large: 200 rows');
  CheckEqual('0', LRows[0][0], 'ReadAll large: first row first col');
  CheckEqual('199', LRows[199][0], 'ReadAll large: last row first col');
end;

{ ===== Error state: bare quote in unquoted field ===== }

procedure TestBareQuoteError;
var
  LReader: TCsvReader;
  LFields: TStringArray;
begin
  LReader := TCsvReader.Create('hello"world,next');
  Check(LReader.ReadRow(LFields), 'bare quote: row still returns');
  Check(LReader.HasError, 'bare quote: error set');
  Check(Pos('Bare quote', LReader.GetError) > 0, 'bare quote: error message');
end;

{ ===== Error state: unclosed quoted field ===== }

procedure TestUnclosedQuote;
var
  LReader: TCsvReader;
  LFields: TStringArray;
  LError: TCsvError;
begin
  LReader := TCsvReader.Create('"unclosed');
  Check(LReader.ReadRow(LFields), 'unclosed quote: row returns');
  Check(LReader.HasError, 'unclosed quote: error set');
  LError := LReader.Error;
  Check(LError.Line > 0, 'unclosed quote: line set');
  Check(LError.Column > 0, 'unclosed quote: column set');
end;

begin
  T := TTestRunner.Create('csv edge cases');
  { RFC 4180 line endings }
  T.Run('CRLF line endings', @TestCRLFLineEndings);
  T.Run('LF only line endings', @TestLFOnlyLineEndings);
  T.Run('CR only line endings', @TestCROnlyLineEndings);
  { Quoted fields }
  T.Run('quoted field with comma', @TestQuotedFieldWithComma);
  T.Run('quoted field with newline', @TestQuotedFieldWithNewline);
  T.Run('escaped quotes', @TestEscapedQuotes);
  { Empty/edge fields }
  T.Run('empty fields', @TestEmptyFields);
  T.Run('trailing empty field', @TestTrailingEmptyField);
  T.Run('leading empty field', @TestLeadingEmptyField);
  T.Run('single field', @TestSingleField);
  T.Run('quoted empty string', @TestQuotedEmptyString);
  { Custom delimiters }
  T.Run('tab delimiter', @TestTabDelimiter);
  T.Run('semicolon delimiter', @TestSemicolonDelimiter);
  { Comments }
  T.Run('comment lines', @TestCommentLines);
  { FieldsPerRecord }
  T.Run('fields per record match', @TestFieldsPerRecordMatch);
  T.Run('fields per record mismatch', @TestFieldsPerRecordMismatch);
  { TrimSpace }
  T.Run('trim space on', @TestTrimSpaceOn);
  T.Run('trim space on quoted', @TestTrimSpaceOnQuoted);
  { BOM }
  T.Run('UTF-8 BOM', @TestUTF8BOM);
  { Empty input }
  T.Run('empty input', @TestEmptyInput);
  T.Run('blank line input', @TestBlankLineInput);
  { Parse functions }
  T.Run('CsvParse empty', @TestCsvParseEmpty);
  T.Run('CsvParse single row', @TestCsvParseSingleRow);
  T.Run('CsvParseWith delimiter', @TestCsvParseWithDelimiter);
  { Stress }
  T.Run('long field 4KB', @TestLongField);
  T.Run('ReadAll 200 rows', @TestReadAllLarge);
  { Error states }
  T.Run('bare quote error', @TestBareQuoteError);
  T.Run('unclosed quote error', @TestUnclosedQuote);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
