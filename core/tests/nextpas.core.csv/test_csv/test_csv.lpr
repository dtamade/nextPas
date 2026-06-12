program test_csv;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.csv,
  nextpas.core.errors,
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

procedure TestBlankLinesSkipped;
var
  R: TCsvReader;
  Fields: TStringArray;
begin
  R := TCsvReader.Create(#10 + 'a,b' + #13#10 + #13#10 + 'c,d' + #10);
  Check(R.ReadRow(Fields), 'row 1 after leading blank');
  CheckEqual(Int64(2), Int64(Length(Fields)), 'row 1 field count');
  CheckEqual('a', Fields[0], 'row 1 field 0');
  CheckEqual('b', Fields[1], 'row 1 field 1');
  Check(R.ReadRow(Fields), 'row 2 after blank separator');
  CheckEqual(Int64(2), Int64(Length(Fields)), 'row 2 field count');
  CheckEqual('c', Fields[0], 'row 2 field 0');
  CheckEqual('d', Fields[1], 'row 2 field 1');
  Check(not R.ReadRow(Fields), 'no rows after trailing blank');
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

procedure ExpectReaderCreateRejectsDelimiter(ADelimiter: AnsiChar;
  const ACase: string);
var
  R: TCsvReader;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    R := TCsvReader.Create('a,b', ADelimiter);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'reader rejects invalid delimiter ' + ACase);
end;

procedure TestReaderCreateRejectsInvalidDelimiter;
begin
  ExpectReaderCreateRejectsDelimiter(#0, 'NUL');
  ExpectReaderCreateRejectsDelimiter(#10, 'LF');
  ExpectReaderCreateRejectsDelimiter(#13, 'CR');
  ExpectReaderCreateRejectsDelimiter('"', 'quote');
end;

procedure TestReaderDelimiterSetterRejectsInvalidDelimiterAndKeepsPreviousDelimiter;
var
  R: TCsvReader;
  Fields: TStringArray;
  LRaised: Boolean;
begin
  R := TCsvReader.Create('a;b;c');
  R.Delimiter := ';';
  LRaised := False;
  try
    R.Delimiter := #10;
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'delimiter setter rejects invalid delimiter');
  Check(R.ReadRow(Fields), 'reader remains usable after rejected delimiter');
  CheckEqual(Int64(3), Int64(Length(Fields)),
    'rejected delimiter keeps previous delimiter');
  CheckEqual('a', Fields[0], 'field 0 after rejected delimiter');
  CheckEqual('b', Fields[1], 'field 1 after rejected delimiter');
  CheckEqual('c', Fields[2], 'field 2 after rejected delimiter');
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

procedure TestReadAllStopsBeforeMalformedRow;
var
  R: TCsvReader;
  M: TStringMatrix;
  LErr: TCsvError;
begin
  R := TCsvReader.Create('ok,1' + #10 + '"unterminated');
  M := R.ReadAll;
  CheckEqual(Int64(1), Int64(Length(M)),
    'ReadAll keeps only complete rows before malformed input');
  CheckEqual('ok', M[0][0], 'complete row field 0 retained');
  CheckEqual('1', M[0][1], 'complete row field 1 retained');
  Check(R.HasError, 'ReadAll exposes malformed-row error in-band');
  CheckEqual('Unclosed quoted field', R.GetError, 'ReadAll malformed-row message');
  LErr := R.Error;
  CheckEqual(Int64(2), Int64(LErr.Line), 'ReadAll malformed-row line');
  Check(LErr.Offset > 0, 'ReadAll malformed-row offset');
end;

procedure TestReadAllStopsBeforeWrongFieldCountRow;
var
  R: TCsvReader;
  M: TStringMatrix;
  LErr: TCsvError;
begin
  R := TCsvReader.Create('a,b,c' + #10 + 'x,y', ',', 3);
  M := R.ReadAll;
  CheckEqual(Int64(1), Int64(Length(M)),
    'ReadAll keeps only complete rows before width mismatch');
  CheckEqual('a', M[0][0], 'width-mismatch row 0 field 0 retained');
  CheckEqual('c', M[0][2], 'width-mismatch row 0 field 2 retained');
  Check(R.HasError, 'ReadAll exposes width mismatch in-band');
  CheckEqual('Wrong number of fields', R.GetError,
    'ReadAll width mismatch message');
  LErr := R.Error;
  CheckEqual(Int64(2), Int64(LErr.Line), 'ReadAll width mismatch line');
  CheckEqual(Int64(4), Int64(LErr.Column), 'ReadAll width mismatch column');
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

procedure TestWriterQuotesSurroundingWhitespace;
var
  W: TCsvWriter;
  R: TCsvReader;
  Fields: TStringArray;
begin
  W := TCsvWriter.Create;
  W.WriteRow([' leading', 'trailing ', #9 + 'tabbed', 'tabbed' + #9]);
  CheckEqual('" leading","trailing ","' + #9 + 'tabbed","tabbed' + #9 +
    '"' + #10, W.ToString, 'quotes surrounding whitespace');

  R := TCsvReader.Create(W.ToString, ',', 0, True);
  Check(R.ReadRow(Fields), 'trim-space reader reads writer output');
  CheckEqual(' leading', Fields[0], 'leading space preserved');
  CheckEqual('trailing ', Fields[1], 'trailing space preserved');
  CheckEqual(#9 + 'tabbed', Fields[2], 'leading tab preserved');
  CheckEqual('tabbed' + #9, Fields[3], 'trailing tab preserved');
end;

procedure TestWriterQuotesSingleEmptyField;
var
  W: TCsvWriter;
  R: TCsvReader;
  Fields: TStringArray;
begin
  W := TCsvWriter.Create;
  W.WriteRow(['']);
  CheckEqual('""' + #10, W.ToString, 'single empty field is explicit');

  R := TCsvReader.Create(W.ToString);
  Check(R.ReadRow(Fields), 'reader sees the row');
  CheckEqual(Int64(1), Int64(Length(Fields)), 'field count');
  CheckEqual('', Fields[0], 'empty field payload');
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

procedure TestWriterToStringRejectsUnfinishedRow;
var
  W: TCsvWriter;
  LRaised: Boolean;
begin
  W := TCsvWriter.Create;
  W.WriteField('partial');

  LRaised := False;
  try
    W.ToString;
    Fail('ToString must reject unfinished row');
  except
    on E: EInvalidOperationError do
      LRaised := True;
  end;
  Check(LRaised, 'unfinished row raises EInvalidOperationError');

  W.EndRow;
  CheckEqual('partial' + #10, W.ToString,
    'writer stays usable after rejected unfinished-row ToString');
end;

procedure TestWriterRejectsZeroFieldRow;
var
  W: TCsvWriter;
  LRaised: Boolean;
begin
  W := TCsvWriter.Create;

  LRaised := False;
  try
    W.WriteRow([]);
    Fail('zero-field row must be rejected');
  except
    on E: EInvalidOperationError do
      LRaised := True;
  end;
  Check(LRaised, 'zero-field row raises EInvalidOperationError');
  CheckEqual('', W.ToString, 'zero-field row leaves output unchanged');

  LRaised := False;
  try
    W.EndRow;
    Fail('empty EndRow must be rejected');
  except
    on E: EInvalidOperationError do
      LRaised := True;
  end;
  Check(LRaised, 'empty EndRow raises EInvalidOperationError');
  CheckEqual('', W.ToString, 'empty EndRow leaves output unchanged');

  W.WriteRow(['a', 'b']);
  CheckEqual('a,b' + #10, W.ToString,
    'writer stays usable after rejected zero-field row');
end;

procedure ExpectWriterCreateRejectsDelimiter(ADelimiter: AnsiChar;
  const ACase: string);
var
  W: TCsvWriter;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    W := TCsvWriter.Create(ADelimiter);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'writer rejects invalid delimiter ' + ACase);
end;

procedure TestWriterCreateRejectsInvalidDelimiter;
begin
  ExpectWriterCreateRejectsDelimiter(#0, 'NUL');
  ExpectWriterCreateRejectsDelimiter(#10, 'LF');
  ExpectWriterCreateRejectsDelimiter(#13, 'CR');
  ExpectWriterCreateRejectsDelimiter('"', 'quote');
end;

procedure TestWriterCommentMarkerQuotesLeadingCommentField;
var
  W: TCsvWriter;
  R: TCsvReader;
  Fields: TStringArray;
begin
  W := TCsvWriter.Create(',', False, '#');
  W.WriteRow(['#literal', 'value']);
  W.WriteRow(['normal', '#payload']);
  CheckEqual('"#literal",value' + #10 + 'normal,#payload' + #10,
    W.ToString, 'writer quotes only row-leading comment marker fields');

  R := TCsvReader.Create(W.ToString, ',', 0, False, '#');
  Check(R.ReadRow(Fields), 'comment-enabled reader sees quoted leading marker');
  CheckEqual('#literal', Fields[0], 'quoted leading marker payload');
  CheckEqual('value', Fields[1], 'quoted leading marker sibling field');
  Check(R.ReadRow(Fields), 'comment-enabled reader sees normal row');
  CheckEqual('normal', Fields[0], 'normal row field 0');
  CheckEqual('#payload', Fields[1], 'non-leading marker field is data');
  Check(not R.ReadRow(Fields), 'no extra rows after comment-safe output');
end;

procedure TestWriterCommentMarkerFieldByFieldQuotesLeadingCommentField;
var
  W: TCsvWriter;
  R: TCsvReader;
  Fields: TStringArray;
begin
  W := TCsvWriter.Create(',', False, '#');
  W.WriteField('#literal');
  W.WriteField('value');
  W.EndRow;
  CheckEqual('"#literal",value' + #10, W.ToString,
    'field-by-field writer quotes row-leading comment marker field');

  R := TCsvReader.Create(W.ToString, ',', 0, False, '#');
  Check(R.ReadRow(Fields), 'comment-enabled reader sees field-by-field output');
  CheckEqual('#literal', Fields[0], 'field-by-field marker payload');
  CheckEqual('value', Fields[1], 'field-by-field sibling field');
  Check(not R.ReadRow(Fields), 'no extra rows after field-by-field output');
end;

procedure ExpectWriterCreateRejectsComment(AComment: AnsiChar;
  const ACase: string);
var
  W: TCsvWriter;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    W := TCsvWriter.Create(',', False, AComment);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'writer rejects invalid comment marker ' + ACase);
end;

procedure TestWriterCreateRejectsInvalidCommentMarker;
var
  W: TCsvWriter;
begin
  ExpectWriterCreateRejectsComment(',', 'delimiter');
  ExpectWriterCreateRejectsComment(#10, 'LF');
  ExpectWriterCreateRejectsComment(#13, 'CR');
  ExpectWriterCreateRejectsComment('"', 'quote');

  W := TCsvWriter.Create(',', False, #0);
  W.WriteRow(['#literal']);
  CheckEqual('#literal' + #10, W.ToString,
    'NUL comment marker keeps default writer output');
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

procedure TestErrorPositionBareQuoteCRLF;
var
  R: TCsvReader;
  Fields: TStringArray;
  LErr: TCsvError;
begin
  R := TCsvReader.Create('a,b' + #13#10 + 'c"d,e');
  Check(R.ReadRow(Fields), 'row 1');
  Check(not R.HasError, 'row 1 has no error');
  Check(R.ReadRow(Fields), 'row 2');
  Check(R.HasError, 'bare quote on row 2 should error');
  LErr := R.Error;
  CheckEqual('Bare quote in unquoted field', LErr.Message, 'error message');
  CheckEqual(Int64(6), Int64(LErr.Offset), 'error byte offset');
  CheckEqual(Int64(2), Int64(LErr.Line), 'error line');
  CheckEqual(Int64(2), Int64(LErr.Column), 'error column');
end;

procedure TestErrorPositionUnclosedQuoteOpeningPosition;
var
  R: TCsvReader;
  Fields: TStringArray;
  LErr: TCsvError;
begin
  R := TCsvReader.Create('ok,1' + #10 + '"line1' + #10 + 'line2');
  Check(R.ReadRow(Fields), 'row 1');
  Check(not R.HasError, 'row 1 has no error');
  Check(R.ReadRow(Fields), 'row 2 returns the row that exposed the error');
  Check(R.HasError, 'unclosed quote on row 2 should error');
  LErr := R.Error;
  CheckEqual('Unclosed quoted field', LErr.Message, 'error message');
  CheckEqual(Int64(5), Int64(LErr.Offset), 'error byte offset');
  CheckEqual(Int64(2), Int64(LErr.Line), 'error line');
  CheckEqual(Int64(1), Int64(LErr.Column), 'error column');
end;

procedure TestTrimSpaceErrorPositionUnclosedQuoteOpeningPosition;
var
  R: TCsvReader;
  Fields: TStringArray;
  LErr: TCsvError;
begin
  R := TCsvReader.Create('a,b' + #10 + '  "unterminated', ',', 0, True);
  Check(R.ReadRow(Fields), 'row 1');
  Check(not R.HasError, 'row 1 has no error');
  Check(R.ReadRow(Fields), 'row 2 returns the row that exposed the error');
  Check(R.HasError, 'trim-space unclosed quote should error');
  LErr := R.Error;
  CheckEqual('Unclosed quoted field', LErr.Message, 'error message');
  CheckEqual(Int64(6), Int64(LErr.Offset), 'error byte offset');
  CheckEqual(Int64(2), Int64(LErr.Line), 'error line');
  CheckEqual(Int64(3), Int64(LErr.Column), 'error column');
end;

procedure TestReadRowFailClosedAfterError;
var
  R: TCsvReader;
  Fields: TStringArray;
  LFirstErr, LErr: TCsvError;
begin
  R := TCsvReader.Create('ok,1' + #10 + 'ba"d,2' + #10 + 'next,row');
  Check(R.ReadRow(Fields), 'row 1');
  Check(not R.HasError, 'row 1 has no error');
  Check(R.ReadRow(Fields), 'row 2 returns the row that exposed the error');
  Check(R.HasError, 'row 2 sets error');
  LFirstErr := R.Error;
  CheckEqual('Bare quote in unquoted field', LFirstErr.Message,
    'first error message');
  CheckEqual(Int64(7), Int64(LFirstErr.Offset), 'first error byte offset');
  CheckEqual(Int64(2), Int64(LFirstErr.Line), 'first error line');
  CheckEqual(Int64(3), Int64(LFirstErr.Column), 'first error column');

  Check(not R.ReadRow(Fields), 'reader fails closed after first error');
  CheckEqual(Int64(0), Int64(Length(Fields)),
    'reader does not return rows after first error');
  LErr := R.Error;
  CheckEqual(LFirstErr.Message, LErr.Message, 'sticky error message');
  CheckEqual(Int64(LFirstErr.Offset), Int64(LErr.Offset),
    'sticky error offset');
  CheckEqual(Int64(LFirstErr.Line), Int64(LErr.Line), 'sticky error line');
  CheckEqual(Int64(LFirstErr.Column), Int64(LErr.Column),
    'sticky error column');

  Check(not R.ReadRow(Fields), 'reader remains failed closed');
  CheckEqual(Int64(0), Int64(Length(Fields)),
    'reader still does not return rows after first error');
  LErr := R.Error;
  CheckEqual(LFirstErr.Message, LErr.Message, 'still sticky error message');
  CheckEqual(Int64(LFirstErr.Offset), Int64(LErr.Offset),
    'still sticky error offset');
  CheckEqual(Int64(LFirstErr.Line), Int64(LErr.Line), 'still sticky error line');
  CheckEqual(Int64(LFirstErr.Column), Int64(LErr.Column),
    'still sticky error column');
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
var
  R: TCsvReader;
  Fields: TStringArray;
  LErr: TCsvError;
begin
  R := TCsvReader.Create('a,b,c' + #10 + 'd,e' + #10 + 'x,y,z', ',', 3);
  Check(R.ReadRow(Fields), 'row 1');
  Check(not R.HasError, 'no error row 1');
  Check(R.ReadRow(Fields), 'row 2');
  Check(R.HasError, 'error on row 2 (2 fields, expected 3)');
  LErr := R.Error;
  CheckEqual('Wrong number of fields', LErr.Message, 'error message');
  CheckEqual(Int64(9), Int64(LErr.Offset), 'error byte offset');
  CheckEqual(Int64(2), Int64(LErr.Line), 'error line');
  CheckEqual(Int64(4), Int64(LErr.Column), 'error column');
end;

procedure TestFieldsPerRecordZeroInfersFirstRecordWidth;
var
  R: TCsvReader;
  Fields: TStringArray;
  LErr: TCsvError;
begin
  R := TCsvReader.Create('a,b' + #10 + 'c,d,e', ',', 0);
  Check(R.ReadRow(Fields), 'row 1');
  Check(not R.HasError, 'row 1 establishes default width');
  CheckEqual(Int64(2), Int64(Length(Fields)), 'row 1 width');

  Check(R.ReadRow(Fields), 'row 2 returns the mismatched row');
  Check(R.HasError, 'default width rejects later row with different width');
  LErr := R.Error;
  CheckEqual('Wrong number of fields', LErr.Message, 'error message');
  CheckEqual(Int64(9), Int64(LErr.Offset), 'error byte offset');
  CheckEqual(Int64(2), Int64(LErr.Line), 'error line');
  CheckEqual(Int64(6), Int64(LErr.Column), 'error column');
end;

procedure TestFieldsPerRecordNegativeAllowsVariableWidth;
var
  R: TCsvReader;
  Fields: TStringArray;
begin
  R := TCsvReader.Create('a,b' + #10 + 'c,d,e', ',', -1);
  Check(R.ReadRow(Fields), 'row 1');
  CheckEqual(Int64(2), Int64(Length(Fields)), 'row 1 width');
  Check(R.ReadRow(Fields), 'row 2');
  CheckEqual(Int64(3), Int64(Length(Fields)), 'row 2 variable width');
  Check(not R.HasError, 'negative width mode allows variable-width rows');
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
  CheckEqual(' a ', Fields[0], 'quoted payload preserved');
  CheckEqual('b', Fields[1], 'f1');
end;

procedure TestTrimSpaceAllowsLeadingSpaceBeforeQuotedField;
var
  R: TCsvReader;
  Fields: TStringArray;
begin
  R := TCsvReader.Create('  "a",  " b", c ', ',', 0, True);
  Check(R.ReadRow(Fields), 'read');
  CheckEqual(False, R.HasError,
    'trim-space reader accepts leading spaces before opening quotes');
  CheckEqual(Int64(3), Int64(Length(Fields)), 'count');
  CheckEqual('a', Fields[0], 'quoted field after leading spaces');
  CheckEqual(' b', Fields[1], 'quoted payload still preserved');
  CheckEqual('c', Fields[2], 'unquoted field still trims');
end;

procedure TestTrimSpaceAllowsTrailingSpaceAfterQuotedField;
var
  R: TCsvReader;
  Fields: TStringArray;
begin
  R := TCsvReader.Create('"a" , " b" '#9', c', ',', 0, True);
  Check(R.ReadRow(Fields), 'read');
  CheckEqual(False, R.HasError,
    'trim-space reader accepts spaces or tabs after closing quotes');
  CheckEqual(Int64(3), Int64(Length(Fields)), 'count');
  CheckEqual('a', Fields[0], 'quoted field before trailing space');
  CheckEqual(' b', Fields[1], 'quoted payload still preserved');
  CheckEqual('c', Fields[2], 'unquoted field still trims');
end;

procedure TestTrimSpaceKeepsWhitespaceDelimiterAfterQuotedField;
var
  R: TCsvReader;
  Fields: TStringArray;
begin
  R := TCsvReader.Create('"a"'#9'"b"', #9, 0, True);
  Check(R.ReadRow(Fields), 'tab-delimited read');
  CheckEqual(False, R.HasError,
    'trim-space reader keeps tab delimiter after closing quote');
  CheckEqual(Int64(2), Int64(Length(Fields)), 'tab-delimited count');
  CheckEqual('a', Fields[0], 'tab-delimited first quoted field');
  CheckEqual('b', Fields[1], 'tab-delimited second quoted field');
end;

procedure ExpectTrimSpacePreservesWhitespaceDelimiter(const AInput: string;
  ADelimiter: AnsiChar; const ACase: string);
var
  R: TCsvReader;
  Fields: TStringArray;
begin
  R := TCsvReader.Create(AInput, ADelimiter, 0, True);
  Check(R.ReadRow(Fields), ACase + ' read');
  CheckEqual(False, R.HasError, ACase + ' no parse error');
  CheckEqual(Int64(3), Int64(Length(Fields)), ACase + ' field count');
  CheckEqual('a', Fields[0], ACase + ' first field');
  CheckEqual('', Fields[1], ACase + ' empty middle field');
  CheckEqual('b', Fields[2], ACase + ' third field');
end;

procedure TestTrimSpaceDoesNotSkipWhitespaceDelimiter;
begin
  ExpectTrimSpacePreservesWhitespaceDelimiter('a'#9#9'b', #9,
    'trim-space tab delimiter');
  ExpectTrimSpacePreservesWhitespaceDelimiter('a  b', ' ',
    'trim-space space delimiter');
end;

procedure TestNoTrimSpaceRejectsTrailingSpaceAfterQuotedField;
var
  R: TCsvReader;
  Fields: TStringArray;
begin
  R := TCsvReader.Create('"a" ,b', ',', 0, False);
  Check(R.ReadRow(Fields), 'strict read');
  Check(R.HasError,
    'strict reader rejects whitespace after closing quote before delimiter');
  CheckEqual('Unexpected character after closing quote', R.Error.Message,
    'strict post-quote error message');
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

procedure ExpectReaderCreateRejectsComment(AComment: AnsiChar;
  const ACase: string);
var
  R: TCsvReader;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    R := TCsvReader.Create('a,b', ',', 0, False, AComment);
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'reader rejects invalid comment marker ' + ACase);
end;

procedure TestReaderCreateRejectsInvalidCommentMarker;
var
  R: TCsvReader;
  Fields: TStringArray;
begin
  ExpectReaderCreateRejectsComment(',', 'delimiter');
  ExpectReaderCreateRejectsComment(#10, 'LF');
  ExpectReaderCreateRejectsComment(#13, 'CR');
  ExpectReaderCreateRejectsComment('"', 'quote');

  R := TCsvReader.Create('#notcomment,a', ',', 0, False, #0);
  Check(R.ReadRow(Fields), 'NUL comment marker disables comments');
  CheckEqual('#notcomment', Fields[0], 'disabled comment marker field 0');
  CheckEqual('a', Fields[1], 'disabled comment marker field 1');
end;

procedure TestReaderCommentCollisionIsRejectedBeforeParsing;
var
  R: TCsvReader;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    R := TCsvReader.Create('# header' + #10 + 'a#b', '#', 0, False, '#');
  except
    on E: EArgumentError do
      LRaised := True;
  end;
  Check(LRaised, 'delimiter/comment collision fails before parsing');
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
  T.Run('BlankLinesSkipped', @TestBlankLinesSkipped);
  T.Run('SingleField', @TestSingleField);
  T.Run('CRLFLineEnding', @TestCRLFLineEnding);
  T.Run('TabDelimiter', @TestTabDelimiter);
  T.Run('SemicolonDelimiter', @TestSemicolonDelimiter);
  T.Run('ReaderCreateRejectsInvalidDelimiter',
    @TestReaderCreateRejectsInvalidDelimiter);
  T.Run('ReaderDelimiterSetterRejectsInvalidDelimiterAndKeepsPreviousDelimiter',
    @TestReaderDelimiterSetterRejectsInvalidDelimiterAndKeepsPreviousDelimiter);
  T.Run('ReadAll', @TestReadAll);
  T.Run('ReadAll.StopsBeforeMalformedRow', @TestReadAllStopsBeforeMalformedRow);
  T.Run('ReadAll.StopsBeforeWrongFieldCountRow', @TestReadAllStopsBeforeWrongFieldCountRow);
  T.Run('LongField', @TestLongField);

  { Writer tests }
  T.Run('WriterBasic', @TestWriterBasic);
  T.Run('WriterQuoting', @TestWriterQuoting);
  T.Run('WriterQuotesSurroundingWhitespace', @TestWriterQuotesSurroundingWhitespace);
  T.Run('WriterQuotesSingleEmptyField', @TestWriterQuotesSingleEmptyField);
  T.Run('WriterQuoteEscape', @TestWriterQuoteEscape);
  T.Run('WriterNewlineInField', @TestWriterNewlineInField);
  T.Run('WriterCRLF', @TestWriterCRLF);
  T.Run('WriterCustomDelimiter', @TestWriterCustomDelimiter);
  T.Run('WriterMultiRow', @TestWriterMultiRow);
  T.Run('WriterFieldByField', @TestWriterFieldByField);
  T.Run('WriterToStringRejectsUnfinishedRow',
    @TestWriterToStringRejectsUnfinishedRow);
  T.Run('WriterRejectsZeroFieldRow', @TestWriterRejectsZeroFieldRow);
  T.Run('WriterCreateRejectsInvalidDelimiter',
    @TestWriterCreateRejectsInvalidDelimiter);
  T.Run('WriterCommentMarkerQuotesLeadingCommentField',
    @TestWriterCommentMarkerQuotesLeadingCommentField);
  T.Run('WriterCommentMarkerFieldByFieldQuotesLeadingCommentField',
    @TestWriterCommentMarkerFieldByFieldQuotesLeadingCommentField);
  T.Run('WriterCreateRejectsInvalidCommentMarker',
    @TestWriterCreateRejectsInvalidCommentMarker);

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
  T.Run('HasError.PositionBareQuoteCRLF', @TestErrorPositionBareQuoteCRLF);
  T.Run('HasError.UnclosedQuoteOpeningPosition',
    @TestErrorPositionUnclosedQuoteOpeningPosition);
  T.Run('TrimSpace.UnclosedQuoteOpeningPosition',
    @TestTrimSpaceErrorPositionUnclosedQuoteOpeningPosition);
  T.Run('HasError.ReadRowFailClosedAfterError',
    @TestReadRowFailClosedAfterError);

  { FieldsPerRecord tests }
  T.Run('FieldsPerRecord.Correct', @TestFieldsPerRecordCorrect);
  T.Run('FieldsPerRecord.Mismatch', @TestFieldsPerRecordMismatch);
  T.Run('FieldsPerRecord.ZeroInfersFirstRecordWidth',
    @TestFieldsPerRecordZeroInfersFirstRecordWidth);
  T.Run('FieldsPerRecord.NegativeAllowsVariableWidth',
    @TestFieldsPerRecordNegativeAllowsVariableWidth);

  { TrimSpace tests }
  T.Run('TrimSpace', @TestTrimSpace);
  T.Run('TrimSpace.PreservesQuoted', @TestTrimSpacePreservesQuoted);
  T.Run('TrimSpace.AllowsLeadingSpaceBeforeQuotedField',
    @TestTrimSpaceAllowsLeadingSpaceBeforeQuotedField);
  T.Run('TrimSpace.AllowsTrailingSpaceAfterQuotedField',
    @TestTrimSpaceAllowsTrailingSpaceAfterQuotedField);
  T.Run('TrimSpace.KeepsWhitespaceDelimiterAfterQuotedField',
    @TestTrimSpaceKeepsWhitespaceDelimiterAfterQuotedField);
  T.Run('TrimSpace.DoesNotSkipWhitespaceDelimiter',
    @TestTrimSpaceDoesNotSkipWhitespaceDelimiter);
  T.Run('TrimSpace.FalseRejectsTrailingSpaceAfterQuotedField',
    @TestNoTrimSpaceRejectsTrailingSpaceAfterQuotedField);

  { Comment tests }
  T.Run('Comment.Skip', @TestCommentSkip);
  T.Run('Comment.MultipleLines', @TestCommentMultipleLines);
  T.Run('Comment.OnlyInput', @TestCommentOnlyInput);
  T.Run('Comment.InvalidMarker',
    @TestReaderCreateRejectsInvalidCommentMarker);
  T.Run('Comment.DelimiterCollision',
    @TestReaderCommentCollisionIsRejectedBeforeParsing);

  { Combined tests }
  T.Run('Comment+TrimSpace', @TestCommentPlusTrimSpace);

  T.Summary;
end.
