program test_csv;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.csv,
  nextpas.core.testing;

var
  T: TTestRunner;

{ === Reader Tests === }

procedure TestBasicSingleRow;
var
  R: TCsvReader;
  Fields: TStringArray;
begin
  R := TCsvReader.Create('a,b,c');
  Check(R.ReadRow(Fields), 'should read row');
  CheckEqual(Int64(3), Int64(Length(Fields)), 'field count');
  CheckEqual('a', Fields[0], 'field 0');
  CheckEqual('b', Fields[1], 'field 1');
  CheckEqual('c', Fields[2], 'field 2');
end;

procedure TestBasicMultiRow;
var
  R: TCsvReader;
  Fields: TStringArray;
begin
  R := TCsvReader.Create('a,b' + #10 + 'c,d' + #10);
  Check(R.ReadRow(Fields), 'row 1');
  CheckEqual('a', Fields[0], 'r1f0');
  CheckEqual('b', Fields[1], 'r1f1');
  Check(R.ReadRow(Fields), 'row 2');
  CheckEqual('c', Fields[0], 'r2f0');
  CheckEqual('d', Fields[1], 'r2f1');
  Check(not R.ReadRow(Fields), 'no row 3');
end;

procedure TestQuotedFieldWithComma;
var
  R: TCsvReader;
  Fields: TStringArray;
begin
  R := TCsvReader.Create('a,"b,c",d');
  Check(R.ReadRow(Fields), 'read');
  CheckEqual(Int64(3), Int64(Length(Fields)), 'count');
  CheckEqual('a', Fields[0], 'f0');
  CheckEqual('b,c', Fields[1], 'f1 with comma');
  CheckEqual('d', Fields[2], 'f2');
end;

procedure TestQuotedFieldWithNewline;
var
  R: TCsvReader;
  Fields: TStringArray;
begin
  R := TCsvReader.Create('"line1' + #10 + 'line2",b');
  Check(R.ReadRow(Fields), 'read');
  CheckEqual(Int64(2), Int64(Length(Fields)), 'count');
  CheckEqual('line1' + #10 + 'line2', Fields[0], 'f0 with newline');
  CheckEqual('b', Fields[1], 'f1');
end;

procedure TestDoubleQuoteEscape;
var
  R: TCsvReader;
  Fields: TStringArray;
begin
  R := TCsvReader.Create('"say ""hello""",b');
  Check(R.ReadRow(Fields), 'read');
  CheckEqual(Int64(2), Int64(Length(Fields)), 'count');
  CheckEqual('say "hello"', Fields[0], 'escaped quotes');
  CheckEqual('b', Fields[1], 'f1');
end;

procedure TestEmptyFields;
var
  R: TCsvReader;
  Fields: TStringArray;
begin
  R := TCsvReader.Create(',a,,b,');
  Check(R.ReadRow(Fields), 'read');
  CheckEqual(Int64(5), Int64(Length(Fields)), 'count');
  CheckEqual('', Fields[0], 'empty f0');
  CheckEqual('a', Fields[1], 'f1');
  CheckEqual('', Fields[2], 'empty f2');
  CheckEqual('b', Fields[3], 'f3');
  CheckEqual('', Fields[4], 'empty f4');
end;

procedure TestEmptyInput;
var
  R: TCsvReader;
  Fields: TStringArray;
begin
  R := TCsvReader.Create('');
  Check(not R.ReadRow(Fields), 'empty input returns false');
end;

procedure TestSingleField;
var
  R: TCsvReader;
  Fields: TStringArray;
begin
  R := TCsvReader.Create('hello');
  Check(R.ReadRow(Fields), 'read');
  CheckEqual(Int64(1), Int64(Length(Fields)), 'count');
  CheckEqual('hello', Fields[0], 'single field');
end;

procedure TestCRLFLineEnding;
var
  R: TCsvReader;
  Fields: TStringArray;
begin
  R := TCsvReader.Create('a,b' + #13#10 + 'c,d' + #13#10);
  Check(R.ReadRow(Fields), 'row 1');
  CheckEqual('a', Fields[0], 'r1f0');
  CheckEqual('b', Fields[1], 'r1f1');
  Check(R.ReadRow(Fields), 'row 2');
  CheckEqual('c', Fields[0], 'r2f0');
  CheckEqual('d', Fields[1], 'r2f1');
end;

procedure TestTabDelimiter;
var
  R: TCsvReader;
  Fields: TStringArray;
begin
  R := TCsvReader.Create('a' + #9 + 'b' + #9 + 'c');
  R.Delimiter := #9;
  Check(R.ReadRow(Fields), 'read');
  CheckEqual(Int64(3), Int64(Length(Fields)), 'count');
  CheckEqual('a', Fields[0], 'f0');
  CheckEqual('b', Fields[1], 'f1');
  CheckEqual('c', Fields[2], 'f2');
end;

procedure TestSemicolonDelimiter;
var
  R: TCsvReader;
  Fields: TStringArray;
begin
  R := TCsvReader.Create('a;b;c');
  R.Delimiter := ';';
  Check(R.ReadRow(Fields), 'read');
  CheckEqual(Int64(3), Int64(Length(Fields)), 'count');
  CheckEqual('a', Fields[0], 'f0');
  CheckEqual('b', Fields[1], 'f1');
  CheckEqual('c', Fields[2], 'f2');
end;

procedure TestReadAll;
var
  R: TCsvReader;
  M: TStringMatrix;
begin
  R := TCsvReader.Create('a,b' + #10 + 'c,d' + #10 + 'e,f');
  M := R.ReadAll;
  CheckEqual(Int64(3), Int64(Length(M)), 'row count');
  CheckEqual('a', M[0][0], 'r0f0');
  CheckEqual('d', M[1][1], 'r1f1');
  CheckEqual('f', M[2][1], 'r2f1');
end;

procedure TestLongField;
var
  R: TCsvReader;
  Fields: TStringArray;
  LLong: string;
  I: Integer;
begin
  LLong := '';
  for I := 1 to 10000 do
    LLong := LLong + 'x';
  R := TCsvReader.Create(LLong + ',short');
  Check(R.ReadRow(Fields), 'read');
  CheckEqual(Int64(2), Int64(Length(Fields)), 'count');
  CheckEqual(Int64(10000), Int64(Length(Fields[0])), 'long field len');
  CheckEqual('short', Fields[1], 'f1');
end;

{ === Writer Tests === }

procedure TestWriterBasic;
var W: TCsvWriter;
begin
  W := TCsvWriter.Create;
  W.WriteRow(['a', 'b', 'c']);
  CheckEqual('a,b,c' + #10, W.ToString, 'basic row');
end;

procedure TestWriterQuoting;
var W: TCsvWriter;
begin
  W := TCsvWriter.Create;
  W.WriteRow(['hello', 'world,earth', 'done']);
  CheckEqual('hello,"world,earth",done' + #10, W.ToString, 'quoted comma');
end;

procedure TestWriterQuoteEscape;
var W: TCsvWriter;
begin
  W := TCsvWriter.Create;
  W.WriteRow(['say "hi"', 'ok']);
  CheckEqual('"say ""hi""",ok' + #10, W.ToString, 'escaped quotes');
end;

procedure TestWriterNewlineInField;
var W: TCsvWriter;
begin
  W := TCsvWriter.Create;
  W.WriteRow(['line1' + #10 + 'line2', 'b']);
  CheckEqual('"line1' + #10 + 'line2",b' + #10, W.ToString, 'newline in field');
end;

procedure TestWriterCRLF;
var W: TCsvWriter;
begin
  W := TCsvWriter.Create(',', True);
  W.WriteRow(['a', 'b']);
  CheckEqual('a,b' + #13#10, W.ToString, 'CRLF ending');
end;

procedure TestWriterCustomDelimiter;
var W: TCsvWriter;
begin
  W := TCsvWriter.Create(#9);
  W.WriteRow(['a', 'b', 'c']);
  CheckEqual('a' + #9 + 'b' + #9 + 'c' + #10, W.ToString, 'tab delim');
end;

procedure TestWriterMultiRow;
var W: TCsvWriter;
begin
  W := TCsvWriter.Create;
  W.WriteRow(['a', 'b']);
  W.WriteRow(['c', 'd']);
  CheckEqual('a,b' + #10 + 'c,d' + #10, W.ToString, 'multi row');
end;

procedure TestWriterFieldByField;
var W: TCsvWriter;
begin
  W := TCsvWriter.Create;
  W.WriteField('x');
  W.WriteField('y');
  W.EndRow;
  CheckEqual('x,y' + #10, W.ToString, 'field by field');
end;

{ === Roundtrip Tests === }

procedure TestRoundtrip;
var
  W: TCsvWriter;
  R: TCsvReader;
  Fields: TStringArray;
begin
  W := TCsvWriter.Create;
  W.WriteRow(['hello', 'world,earth', 'say "hi"']);
  W.WriteRow(['line1' + #10 + 'line2', '', 'end']);
  R := TCsvReader.Create(W.ToString);
  Check(R.ReadRow(Fields), 'row 1');
  CheckEqual(Int64(3), Int64(Length(Fields)), 'r1 count');
  CheckEqual('hello', Fields[0], 'r1f0');
  CheckEqual('world,earth', Fields[1], 'r1f1');
  CheckEqual('say "hi"', Fields[2], 'r1f2');
  Check(R.ReadRow(Fields), 'row 2');
  CheckEqual(Int64(3), Int64(Length(Fields)), 'r2 count');
  CheckEqual('line1' + #10 + 'line2', Fields[0], 'r2f0');
  CheckEqual('', Fields[1], 'r2f1 empty');
  CheckEqual('end', Fields[2], 'r2f2');
end;

procedure TestRFC4180QuotedCRLF;
var R: TCsvReader; Fields: TStringArray;
begin
  R := TCsvReader.Create('"field' + #13#10 + 'break",next');
  Check(R.ReadRow(Fields), 'read');
  CheckEqual(Int64(2), Int64(Length(Fields)), 'count');
  CheckEqual('field' + #13#10 + 'break', Fields[0], 'CRLF in field');
  CheckEqual('next', Fields[1], 'f1');
end;

procedure TestRFC4180EmptyQuoted;
var R: TCsvReader; Fields: TStringArray;
begin
  R := TCsvReader.Create('"",a,""');
  Check(R.ReadRow(Fields), 'read');
  CheckEqual(Int64(3), Int64(Length(Fields)), 'count');
  CheckEqual('', Fields[0], 'empty quoted f0');
  CheckEqual('a', Fields[1], 'f1');
  CheckEqual('', Fields[2], 'empty quoted f2');
end;

{ === Error Handling Tests === }

procedure TestHasErrorUnclosedQuote;
var R: TCsvReader; Fields: TStringArray;
begin
  R := TCsvReader.Create('"unclosed field,b');
  R.ReadRow(Fields);
  Check(R.HasError, 'unclosed quote should set error');
  Check(Length(R.GetError) > 0, 'error message not empty');
end;

procedure TestHasErrorNormal;
var R: TCsvReader; Fields: TStringArray;
begin
  R := TCsvReader.Create('a,b,c');
  R.ReadRow(Fields);
  Check(not R.HasError, 'normal parse no error');
  CheckEqual('', R.GetError, 'no error message');
end;

procedure TestHasErrorMultilineUnclosed;
var R: TCsvReader; Fields: TStringArray;
begin
  R := TCsvReader.Create('"line1' + #10 + 'line2' + #10 + 'line3');
  R.ReadRow(Fields);
  Check(R.HasError, 'multiline unclosed quote should error');
  Check(Length(R.GetError) > 0, 'multiline error msg not empty');
end;

procedure TestHasErrorBareQuoteInUnquotedField;
var R: TCsvReader; Fields: TStringArray;
begin
  R := TCsvReader.Create('ab"cd,ef');
  R.ReadRow(Fields);
  Check(R.HasError, 'bare quote in unquoted field should error');
  Check(Length(R.GetError) > 0, 'bare quote error msg not empty');
end;

procedure TestHasErrorTextAfterClosingQuote;
var R: TCsvReader; Fields: TStringArray;
begin
  R := TCsvReader.Create('"ab"cd,ef');
  R.ReadRow(Fields);
  Check(R.HasError, 'text after closing quote should error');
  Check(Length(R.GetError) > 0, 'post-quote error msg not empty');
end;

{ === FieldsPerRecord Tests === }

procedure TestFieldsPerRecordCorrect;
var R: TCsvReader; Fields: TStringArray;
begin
  R := TCsvReader.Create('a,b,c' + #10 + 'd,e,f', ',', 3);
  Check(R.ReadRow(Fields), 'row 1');
  Check(not R.HasError, 'no error row 1');
  CheckEqual(Int64(3), Int64(Length(Fields)), 'count row 1');
  Check(R.ReadRow(Fields), 'row 2');
  Check(not R.HasError, 'no error row 2');
end;

procedure TestFieldsPerRecordMismatch;
var R: TCsvReader; Fields: TStringArray;
begin
  R := TCsvReader.Create('a,b,c' + #10 + 'd,e', ',', 3);
  Check(R.ReadRow(Fields), 'row 1');
  Check(not R.HasError, 'no error row 1');
  Check(R.ReadRow(Fields), 'row 2');
  Check(R.HasError, 'error on row 2 (2 fields, expected 3)');
end;

{ === TrimSpace Tests === }

procedure TestTrimSpace;
var R: TCsvReader; Fields: TStringArray;
begin
  R := TCsvReader.Create(' a , b , c ', ',', 0, True);
  Check(R.ReadRow(Fields), 'read');
  CheckEqual(Int64(3), Int64(Length(Fields)), 'count');
  CheckEqual('a', Fields[0], 'trimmed f0');
  CheckEqual('b', Fields[1], 'trimmed f1');
  CheckEqual('c', Fields[2], 'trimmed f2');
end;

procedure TestTrimSpacePreservesQuoted;
var R: TCsvReader; Fields: TStringArray;
begin
  R := TCsvReader.Create('" a ",b', ',', 0, True);
  Check(R.ReadRow(Fields), 'read');
  CheckEqual('a', Fields[0], 'quoted trimmed');
  CheckEqual('b', Fields[1], 'f1');
end;

{ === Comment Tests === }

procedure TestCommentSkip;
var R: TCsvReader; Fields: TStringArray;
begin
  R := TCsvReader.Create('# comment' + #10 + 'a,b,c', ',', 0, False, '#');
  Check(R.ReadRow(Fields), 'read');
  CheckEqual(Int64(3), Int64(Length(Fields)), 'count');
  CheckEqual('a', Fields[0], 'f0');
  CheckEqual('b', Fields[1], 'f1');
  CheckEqual('c', Fields[2], 'f2');
end;

procedure TestCommentMultipleLines;
var R: TCsvReader; Fields: TStringArray;
begin
  R := TCsvReader.Create('# line1' + #10 + '# line2' + #10 + 'x,y', ',', 0, False, '#');
  Check(R.ReadRow(Fields), 'read');
  CheckEqual(Int64(2), Int64(Length(Fields)), 'count');
  CheckEqual('x', Fields[0], 'f0');
  CheckEqual('y', Fields[1], 'f1');
  Check(not R.ReadRow(Fields), 'no more rows');
end;

procedure TestCommentOnlyInput;
var R: TCsvReader; Fields: TStringArray;
begin
  R := TCsvReader.Create('# only comments' + #10 + '# here', ',', 0, False, '#');
  Check(not R.ReadRow(Fields), 'no data rows');
end;

{ === Combined: Comment + TrimSpace === }

procedure TestCommentPlusTrimSpace;
var R: TCsvReader; Fields: TStringArray;
begin
  R := TCsvReader.Create('# header' + #10 + ' a , b ', ',', 0, True, '#');
  Check(R.ReadRow(Fields), 'read');
  CheckEqual(Int64(2), Int64(Length(Fields)), 'count');
  CheckEqual('a', Fields[0], 'trimmed f0');
  CheckEqual('b', Fields[1], 'trimmed f1');
end;

{ === Main === }

begin
  T := TTestRunner.Create('nextpas.core.csv');

  { Reader tests }
  T.Run('BasicSingleRow', @TestBasicSingleRow);
  T.Run('BasicMultiRow', @TestBasicMultiRow);
  T.Run('QuotedFieldWithComma', @TestQuotedFieldWithComma);
  T.Run('QuotedFieldWithNewline', @TestQuotedFieldWithNewline);
  T.Run('DoubleQuoteEscape', @TestDoubleQuoteEscape);
  T.Run('EmptyFields', @TestEmptyFields);
  T.Run('EmptyInput', @TestEmptyInput);
  T.Run('SingleField', @TestSingleField);
  T.Run('CRLFLineEnding', @TestCRLFLineEnding);
  T.Run('TabDelimiter', @TestTabDelimiter);
  T.Run('SemicolonDelimiter', @TestSemicolonDelimiter);
  T.Run('ReadAll', @TestReadAll);
  T.Run('LongField', @TestLongField);

  { Writer tests }
  T.Run('WriterBasic', @TestWriterBasic);
  T.Run('WriterQuoting', @TestWriterQuoting);
  T.Run('WriterQuoteEscape', @TestWriterQuoteEscape);
  T.Run('WriterNewlineInField', @TestWriterNewlineInField);
  T.Run('WriterCRLF', @TestWriterCRLF);
  T.Run('WriterCustomDelimiter', @TestWriterCustomDelimiter);
  T.Run('WriterMultiRow', @TestWriterMultiRow);
  T.Run('WriterFieldByField', @TestWriterFieldByField);

  { Roundtrip tests }
  T.Run('Roundtrip', @TestRoundtrip);
  T.Run('RFC4180QuotedCRLF', @TestRFC4180QuotedCRLF);
  T.Run('RFC4180EmptyQuoted', @TestRFC4180EmptyQuoted);

  { Error handling tests }
  T.Run('HasError.UnclosedQuote', @TestHasErrorUnclosedQuote);
  T.Run('HasError.Normal', @TestHasErrorNormal);
  T.Run('HasError.MultilineUnclosed', @TestHasErrorMultilineUnclosed);
  T.Run('HasError.BareQuoteInUnquotedField', @TestHasErrorBareQuoteInUnquotedField);
  T.Run('HasError.TextAfterClosingQuote', @TestHasErrorTextAfterClosingQuote);

  { FieldsPerRecord tests }
  T.Run('FieldsPerRecord.Correct', @TestFieldsPerRecordCorrect);
  T.Run('FieldsPerRecord.Mismatch', @TestFieldsPerRecordMismatch);

  { TrimSpace tests }
  T.Run('TrimSpace', @TestTrimSpace);
  T.Run('TrimSpace.PreservesQuoted', @TestTrimSpacePreservesQuoted);

  { Comment tests }
  T.Run('Comment.Skip', @TestCommentSkip);
  T.Run('Comment.MultipleLines', @TestCommentMultipleLines);
  T.Run('Comment.OnlyInput', @TestCommentOnlyInput);

  { Combined tests }
  T.Run('Comment+TrimSpace', @TestCommentPlusTrimSpace);

  T.Summary;
end.
