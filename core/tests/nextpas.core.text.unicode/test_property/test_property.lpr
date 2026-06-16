program test_property;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.testing,
  nextpas.core.text.unicode.base,
  nextpas.core.text.unicode;

var
  T: TTestRunner;

procedure TestAsciiProperties;
begin
  Check(IsUpper(Ord('A')), 'A uppercase');
  Check(IsLower(Ord('a')), 'a lowercase');
  Check(IsAlpha(Ord('Z')), 'Z alpha');
  Check(IsDigit(Ord('9')), '9 digit');
  Check(IsWhitespace(Ord(' ')), 'space whitespace');
  Check(IsControl(0), 'NUL control');
  Check(IsLetter(Ord('Q')), 'Q letter');
  Check(not IsLetter(Ord('9')), '9 not letter');
end;

procedure TestBmpProperties;
begin
  CheckEqual(Int64(Ord(gcuOtherLetter)), Int64(Ord(GetGeneralCategory($4E2D))), 'CJK category');
  Check(IsLetter($4E2D), 'CJK letter');
  Check(IsUpper($0391), 'Greek capital alpha uppercase');
  Check(IsLower($03B1), 'Greek small alpha lowercase');
  Check(IsUpper($0416), 'Cyrillic ZHE uppercase');
  Check(IsLower($0436), 'Cyrillic zhe lowercase');
  Check(IsWhitespace($2003), 'EM SPACE whitespace');
  Check(IsSeparator($2003), 'EM SPACE separator');
  Check(IsDigit($0660), 'Arabic-Indic zero digit');
  Check(IsNumber($0660), 'Arabic-Indic zero number');
end;

procedure TestSmpProperties;
begin
  CheckEqual(Int64(Ord(gcuUppercaseLetter)), Int64(Ord(GetGeneralCategory($1D400))), 'math bold capital A category');
  Check(IsUpper($1D400), 'math bold capital A uppercase');
  Check(IsLower($1D41A), 'math bold small a lowercase');
  Check(IsAlpha($1D400), 'math bold capital A alphabetic');
  CheckEqual(Int64(Ord(gcuOtherLetter)), Int64(Ord(GetGeneralCategory($12000))), 'cuneiform category');
  Check(IsLetter($12000), 'cuneiform letter');
end;

procedure TestCaseMapping;
begin
  CheckEqual(Int64(Ord('A')), Int64(CodepointToUpper(Ord('a'))), 'a upper');
  CheckEqual(Int64(Ord('a')), Int64(CodepointToLower(Ord('A'))), 'A lower');
  CheckEqual(Int64($00DF), Int64(CodepointToLower($1E9E)), 'capital sharp s lower');
  CheckEqual(Int64($00DF), Int64(CodepointToUpper($00DF)), 'sharp s simple upper unchanged');
  CheckEqual(Int64($1E9E), Int64(CodepointToTitle($1E9E)), 'capital sharp s title unchanged');
end;

procedure TestPunctuationSymbolAndMark;
begin
  Check(IsPunctuation($0021), 'exclamation punctuation');
  Check(IsSymbol($002B), 'plus symbol');
  Check(IsMark($0301), 'combining acute mark');
end;

procedure TestBoundaryCases;
begin
  CheckEqual(Int64(Ord(gcuControl)), Int64(Ord(GetGeneralCategory($0000))), 'U+0000 category');
  CheckEqual(Int64(Ord(gcuUnassigned)), Int64(Ord(GetGeneralCategory($10FFFF))), 'U+10FFFF category');
  CheckEqual(Int64(Ord(gcuSurrogate)), Int64(Ord(GetGeneralCategory($D800))), 'surrogate category');
  CheckEqual(Int64($10FFFF), Int64(CodepointToUpper($10FFFF)), 'U+10FFFF upper unchanged');
  CheckEqual(Int64($D800), Int64(CodepointToLower($D800)), 'surrogate lower unchanged');
end;

begin
  T := TTestRunner.Create('nextpas.core.text.unicode');
  T.Run('ASCII properties', @TestAsciiProperties);
  T.Run('BMP properties', @TestBmpProperties);
  T.Run('SMP properties', @TestSmpProperties);
  T.Run('case mapping', @TestCaseMapping);
  T.Run('punctuation/symbol/mark', @TestPunctuationSymbolAndMark);
  T.Run('boundary cases', @TestBoundaryCases);
  T.Summary;
end.
