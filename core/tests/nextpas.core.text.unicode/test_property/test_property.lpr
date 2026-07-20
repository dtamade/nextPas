program test_property;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.text.unicode.base,
  nextpas.core.text.unicode.types,
  nextpas.core.text.unicode;

var
  T: TTestSuite;

{ === IsUpper / IsLower === }

procedure TestIsUpper;
begin
  // ASCII
  Check(IsUpper(Ord('A')), 'A upper');
  Check(IsUpper(Ord('Z')), 'Z upper');
  Check(not IsUpper(Ord('a')), 'a not upper');
  Check(not IsUpper(Ord('0')), '0 not upper');
  // BMP: Greek
  Check(IsUpper($0391), 'Greek Alpha upper');
  Check(IsUpper($03A9), 'Greek Omega upper');
  Check(not IsUpper($03B1), 'Greek alpha not upper');
  // BMP: Cyrillic
  Check(IsUpper($0416), 'Cyrillic ZHE upper');
  Check(not IsUpper($0436), 'Cyrillic zhe not upper');
  // BMP: Latin Extended
  Check(IsUpper($00C0), 'A-grave upper');
  Check(IsUpper($0178), 'Y-diaeresis upper');
  // SMP: Math Bold
  Check(IsUpper($1D400), 'Math Bold A upper');
  Check(not IsUpper($1D41A), 'Math Bold a not upper');
  // Boundary
  Check(not IsUpper($0000), 'NUL not upper');
  Check(not IsUpper($10FFFF), 'U+10FFFF not upper');
end;

procedure TestIsLower;
begin
  // ASCII
  Check(IsLower(Ord('a')), 'a lower');
  Check(IsLower(Ord('z')), 'z lower');
  Check(not IsLower(Ord('A')), 'A not lower');
  Check(not IsLower(Ord('0')), '0 not lower');
  // BMP: Greek
  Check(IsLower($03B1), 'Greek alpha lower');
  Check(IsLower($03C9), 'Greek omega lower');
  Check(not IsLower($0391), 'Greek Alpha not lower');
  // BMP: Cyrillic
  Check(IsLower($0436), 'Cyrillic zhe lower');
  Check(not IsLower($0416), 'Cyrillic ZHE not lower');
  // BMP: Latin Extended
  Check(IsLower($00E0), 'a-grave lower');
  Check(IsLower($00FF), 'y-diaeresis lower');
  // SMP: Math Bold
  Check(IsLower($1D41A), 'Math Bold a lower');
  Check(not IsLower($1D400), 'Math Bold A not lower');
  // Boundary
  Check(not IsLower($0000), 'NUL not lower');
  Check(not IsLower($10FFFF), 'U+10FFFF not lower');
end;

{ === IsAlpha / IsLetter === }

procedure TestIsAlpha;
begin
  Check(IsAlpha(Ord('A')), 'A alpha');
  Check(IsAlpha(Ord('z')), 'z alpha');
  Check(not IsAlpha(Ord('0')), '0 not alpha');
  Check(not IsAlpha(Ord(' ')), 'space not alpha');
  Check(IsAlpha($4E2D), 'CJK alpha');
  Check(IsAlpha($0391), 'Greek Alpha alpha');
  Check(IsAlpha($0416), 'Cyrillic ZHE alpha');
  Check(IsAlpha($00C0), 'A-grave alpha');
  Check(not IsAlpha($0021), 'exclamation not alpha');
  Check(not IsAlpha($10FFFF), 'U+10FFFF not alpha');
end;

procedure TestIsLetter;
begin
  Check(IsLetter(Ord('A')), 'A letter');
  Check(IsLetter(Ord('z')), 'z letter');
  Check(not IsLetter(Ord('0')), '0 not letter');
  Check(not IsLetter(Ord(' ')), 'space not letter');
  Check(IsLetter($4E2D), 'CJK letter');
  Check(IsLetter($12000), 'cuneiform letter');
  Check(IsLetter($1D400), 'Math Bold A letter');
  Check(not IsLetter($0021), 'exclamation not letter');
  Check(not IsLetter($0301), 'combining acute not letter');
end;

{ === IsDigit / IsNumber === }

procedure TestIsDigit;
begin
  Check(IsDigit(Ord('0')), '0 digit');
  Check(IsDigit(Ord('9')), '9 digit');
  Check(not IsDigit(Ord('a')), 'a not digit');
  Check(not IsDigit(Ord(' ')), 'space not digit');
  Check(IsDigit($0660), 'Arabic-Indic zero digit');
  Check(IsDigit($0669), 'Arabic-Indic nine digit');
  Check(IsDigit($FF10), 'fullwidth zero digit');
  Check(not IsDigit($066A), 'Arabic percent not digit');
  Check(not IsDigit($4E2D), 'CJK not digit');
end;

procedure TestIsNumber;
begin
  Check(IsNumber(Ord('0')), '0 number');
  Check(IsNumber(Ord('9')), '9 number');
  Check(not IsNumber(Ord('a')), 'a not number');
  Check(IsNumber($0660), 'Arabic-Indic zero number');
  Check(IsNumber($FF10), 'fullwidth zero number');
  Check(IsNumber($00B2), 'superscript 2 number');
  Check(IsNumber($2153), 'fraction 1/3 number');
  Check(not IsNumber($002D), 'hyphen not number');
end;

{ === IsWhitespace / IsSeparator === }

procedure TestIsWhitespace;
begin
  Check(IsWhitespace(Ord(' ')), 'space whitespace');
  Check(IsWhitespace(Ord($09)), 'tab whitespace');
  Check(IsWhitespace(Ord($0A)), 'LF whitespace');
  Check(IsWhitespace(Ord($0D)), 'CR whitespace');
  Check(IsWhitespace($00A0), 'NBSP whitespace');
  Check(IsWhitespace($2003), 'EM SPACE whitespace');
  Check(not IsWhitespace($200B), 'ZWSP is Format, not whitespace');
  Check(IsWhitespace($3000), 'IDEOGRAPHIC SPACE whitespace');
  Check(not IsWhitespace(Ord('A')), 'A not whitespace');
  Check(not IsWhitespace($0000), 'NUL not whitespace');
end;

procedure TestIsSeparator;
begin
  Check(not IsSeparator(Ord($0A)), 'LF is Control, not Separator');
  Check(IsSeparator($2003), 'EM SPACE separator');
  Check(IsSeparator($2028), 'LS separator');
  Check(IsSeparator($2029), 'PS separator');
  Check(not IsSeparator(Ord('A')), 'A not separator');
  Check(IsSeparator(Ord(' ')), 'space is SpaceSeparator');
end;

{ === IsControl === }

procedure TestIsControl;
begin
  Check(IsControl($0000), 'NUL control');
  Check(IsControl($001F), 'US control');
  Check(IsControl($007F), 'DEL control');
  Check(IsControl($009F), 'APC control');
  Check(not IsControl(Ord('A')), 'A not control');
  Check(not IsControl($00A0), 'NBSP not control');
end;

{ === IsPunctuation / IsSymbol / IsMark === }

procedure TestIsPunctuation;
begin
  Check(IsPunctuation($0021), 'exclamation punctuation');
  Check(IsPunctuation($002E), 'period punctuation');
  Check(IsPunctuation($003F), 'question punctuation');
  Check(IsPunctuation($002C), 'comma punctuation');
  Check(IsPunctuation($3001), 'ideographic comma punctuation');
  Check(IsPunctuation($FF01), 'fullwidth exclamation punctuation');
  Check(not IsPunctuation(Ord('A')), 'A not punctuation');
  Check(not IsPunctuation(Ord('0')), '0 not punctuation');
end;

procedure TestIsSymbol;
begin
  Check(IsSymbol($002B), 'plus symbol');
  Check(IsSymbol($003C), 'less-than symbol');
  Check(IsSymbol($00A9), 'copyright symbol');
  Check(IsSymbol($2603), 'snowman symbol');
  Check(not IsSymbol(Ord('A')), 'A not symbol');
  Check(not IsSymbol(Ord('0')), '0 not symbol');
end;

procedure TestIsMark;
begin
  Check(IsMark($0301), 'combining acute mark');
  Check(IsMark($0308), 'combining diaeresis mark');
  Check(IsMark($0327), 'combining cedilla mark');
  Check(not IsMark(Ord('A')), 'A not mark');
  Check(not IsMark(Ord(' ')), 'space not mark');
end;

{ === GeneralCategory === }

procedure TestGeneralCategory;
begin
  CheckEqual(Int64(Ord(gcuUppercaseLetter)), Int64(Ord(GetGeneralCategory(Ord('A')))), 'A cat');
  CheckEqual(Int64(Ord(gcuLowercaseLetter)), Int64(Ord(GetGeneralCategory(Ord('a')))), 'a cat');
  CheckEqual(Int64(Ord(gcuDecimalNumber)), Int64(Ord(GetGeneralCategory(Ord('0')))), '0 cat');
  CheckEqual(Int64(Ord(gcuControl)), Int64(Ord(GetGeneralCategory($0000))), 'NUL cat');
  CheckEqual(Int64(Ord(gcuControl)), Int64(Ord(GetGeneralCategory($007F))), 'DEL cat');
  CheckEqual(Int64(Ord(gcuSpaceSeparator)), Int64(Ord(GetGeneralCategory($2003))), 'EM SPACE cat');
  CheckEqual(Int64(Ord(gcuLineSeparator)), Int64(Ord(GetGeneralCategory($2028))), 'LS cat');
  CheckEqual(Int64(Ord(gcuParagraphSeparator)), Int64(Ord(GetGeneralCategory($2029))), 'PS cat');
  CheckEqual(Int64(Ord(gcuSurrogate)), Int64(Ord(GetGeneralCategory($D800))), 'surrogate cat');
  CheckEqual(Int64(Ord(gcuUnassigned)), Int64(Ord(GetGeneralCategory($10FFFF))), 'U+10FFFF cat');
  CheckEqual(Int64(Ord(gcuOtherLetter)), Int64(Ord(GetGeneralCategory($4E2D))), 'CJK cat');
  CheckEqual(Int64(Ord(gcuOtherLetter)), Int64(Ord(GetGeneralCategory($12000))), 'cuneiform cat');
end;

{ === Case Mapping === }

procedure TestCaseMapping;
begin
  // ASCII
  CheckEqual(Int64(Ord('A')), Int64(CodepointToUpper(Ord('a'))), 'a upper');
  CheckEqual(Int64(Ord('a')), Int64(CodepointToLower(Ord('A'))), 'A lower');
  CheckEqual(Int64(Ord('Z')), Int64(CodepointToUpper(Ord('z'))), 'z upper');
  CheckEqual(Int64(Ord('z')), Int64(CodepointToLower(Ord('Z'))), 'Z lower');
  // Latin Extended
  CheckEqual(Int64($00C0), Int64(CodepointToUpper($00E0)), 'a-grave upper');
  CheckEqual(Int64($00E0), Int64(CodepointToLower($00C0)), 'A-grave lower');
  // German sharp s
  CheckEqual(Int64($00DF), Int64(CodepointToLower($1E9E)), 'capital sharp s lower');
  CheckEqual(Int64($00DF), Int64(CodepointToUpper($00DF)), 'sharp s simple upper unchanged');
  CheckEqual(Int64($1E9E), Int64(CodepointToTitle($1E9E)), 'capital sharp s title unchanged');
  // Greek
  CheckEqual(Int64($0391), Int64(CodepointToUpper($03B1)), 'Greek alpha upper');
  CheckEqual(Int64($03B1), Int64(CodepointToLower($0391)), 'Greek Alpha lower');
  // Cyrillic
  CheckEqual(Int64($0416), Int64(CodepointToUpper($0436)), 'Cyrillic zhe upper');
  CheckEqual(Int64($0436), Int64(CodepointToLower($0416)), 'Cyrillic ZHE lower');
  // Identity
  CheckEqual(Int64(Ord('0')), Int64(CodepointToUpper(Ord('0'))), '0 upper unchanged');
  CheckEqual(Int64(Ord('0')), Int64(CodepointToLower(Ord('0'))), '0 lower unchanged');
  CheckEqual(Int64($0301), Int64(CodepointToUpper($0301)), 'combining acute upper unchanged');
end;

{ === Boundary Cases === }

procedure TestBoundaryCases;
begin
  CheckEqual(Int64(Ord(gcuControl)), Int64(Ord(GetGeneralCategory($0000))), 'U+0000 category');
  CheckEqual(Int64(Ord(gcuUnassigned)), Int64(Ord(GetGeneralCategory($10FFFF))), 'U+10FFFF category');
  CheckEqual(Int64(Ord(gcuSurrogate)), Int64(Ord(GetGeneralCategory($D800))), 'surrogate category');
  CheckEqual(Int64(Ord(gcuSurrogate)), Int64(Ord(GetGeneralCategory($DFFF))), 'surrogate end category');
  CheckEqual(Int64($10FFFF), Int64(CodepointToUpper($10FFFF)), 'U+10FFFF upper unchanged');
  CheckEqual(Int64($D800), Int64(CodepointToLower($D800)), 'surrogate lower unchanged');
  Check(not IsAlpha($D800), 'surrogate not alpha');
  Check(not IsDigit($D800), 'surrogate not digit');
  Check(not IsUpper($D800), 'surrogate not upper');
  Check(not IsLower($D800), 'surrogate not lower');
end;

{ === SMP Deep Coverage === }

procedure TestSmpDeep;
begin
  // Emoji (U+1F600 range) - should be Symbol/Other
  Check(not IsAlpha($1F600), 'emoji grin not alpha');
  Check(not IsLetter($1F600), 'emoji grin not letter');
  Check(not IsDigit($1F600), 'emoji grin not digit');
  // CJK Extension B (U+20000)
  Check(IsLetter($20000), 'CJK Ext B letter');
  Check(IsAlpha($20000), 'CJK Ext B alpha');
  Check(not IsUpper($20000), 'CJK Ext B not upper');
  Check(not IsLower($20000), 'CJK Ext B not lower');
  // Musical Symbol (U+1D11E)
  Check(not IsAlpha($1D11E), 'musical not alpha');
  // Mathematical Alphanumeric (U+1D400-U+1D7FF)
  Check(IsUpper($1D400), 'Math Bold A upper');
  Check(IsLower($1D41A), 'Math Bold a lower');
  Check(IsAlpha($1D400), 'Math Bold A alpha');
  Check(IsAlpha($1D41A), 'Math Bold a alpha');
  // Deseret (U+10400)
  Check(IsUpper($10400), 'Deseret AY upper');
  Check(IsLower($10428), 'Deseret ay lower');
  Check(IsAlpha($10400), 'Deseret AY alpha');
end;

{ === HasBinaryProperty === }

procedure TestHasBinaryProperty;
begin
  // ASCII letters have Alphabetic property
  Check(HasBinaryProperty(Ord('A'), ubpAlphabetic), 'A Alphabetic');
  Check(HasBinaryProperty(Ord('z'), ubpAlphabetic), 'z Alphabetic');
  Check(not HasBinaryProperty(Ord('0'), ubpAlphabetic), '0 not Alphabetic');
  // Uppercase property
  Check(HasBinaryProperty(Ord('A'), ubpUppercase), 'A Uppercase');
  Check(not HasBinaryProperty(Ord('a'), ubpUppercase), 'a not Uppercase');
  // Lowercase property
  Check(HasBinaryProperty(Ord('a'), ubpLowercase), 'a Lowercase');
  Check(not HasBinaryProperty(Ord('A'), ubpLowercase), 'A not Lowercase');
  // CJK
  Check(HasBinaryProperty($4E2D, ubpAlphabetic), 'CJK Alphabetic');
  Check(not HasBinaryProperty($4E2D, ubpUppercase), 'CJK not Uppercase');
  // SMP
  Check(HasBinaryProperty($1D400, ubpUppercase), 'Math Bold A Uppercase');
  Check(HasBinaryProperty($1D41A, ubpLowercase), 'Math Bold a Lowercase');
end;

{ === GetGraphemeBreakProperty === }

procedure TestGraphemeBreakProperty;
begin
  // CR/LF
  CheckEqual(Int64(Ord(gbpCR)), Int64(Ord(GetGraphemeBreakProperty($000D))), 'CR GBP');
  CheckEqual(Int64(Ord(gbpLF)), Int64(Ord(GetGraphemeBreakProperty($000A))), 'LF GBP');
  // Control
  CheckEqual(Int64(Ord(gbpControl)), Int64(Ord(GetGraphemeBreakProperty($0000))), 'NUL GBP');
  CheckEqual(Int64(Ord(gbpControl)), Int64(Ord(GetGraphemeBreakProperty($007F))), 'DEL GBP');
  // Extend (combining marks)
  CheckEqual(Int64(Ord(gbpExtend)), Int64(Ord(GetGraphemeBreakProperty($0301))), 'combining acute GBP');
  // Regional Indicator (flags)
  CheckEqual(Int64(Ord(gbpRegionalIndicator)), Int64(Ord(GetGraphemeBreakProperty($1F1E6))), 'RI GBP');
  // ZWJ
  CheckEqual(Int64(Ord(gbpZWJ)), Int64(Ord(GetGraphemeBreakProperty($200D))), 'ZWJ GBP');
  // SpacingMark
  Check(GetGraphemeBreakProperty($0903) = gbpSpacingMark, 'Devanagari sign visarga SpacingMark');
end;

{ === Property Combinations === }

procedure TestPropertyCombinations;
begin
  // IsAlpha AND IsUpper = IsUpper (uppercase is subset of alpha)
  Check(IsUpper(Ord('A')) = (IsAlpha(Ord('A')) and IsUpper(Ord('A'))), 'A: Upper ⊂ Alpha');
  Check(IsLower(Ord('a')) = (IsAlpha(Ord('a')) and IsLower(Ord('a'))), 'a: Lower ⊂ Alpha');
  // IsDigit implies IsNumber
  Check(IsDigit(Ord('0')) = (IsNumber(Ord('0')) and IsDigit(Ord('0'))), '0: Digit ⊂ Number');
  // IsMark is disjoint from IsLetter
  Check(not (IsMark($0301) and IsLetter($0301)), 'Mark ∩ Letter = ∅ for combining acute');
  // IsSeparator is disjoint from IsLetter
  Check(not (IsSeparator($2003) and IsLetter($2003)), 'Separator ∩ Letter = ∅ for EM SPACE');
  // IsControl is disjoint from IsLetter
  Check(not (IsControl($0000) and IsLetter($0000)), 'Control ∩ Letter = ∅ for NUL');
  // Surrogate is not any property
  Check(not IsAlpha($D800), 'surrogate not alpha');
  Check(not IsDigit($D800), 'surrogate not digit');
  Check(not IsUpper($D800), 'surrogate not upper');
  Check(not IsLower($D800), 'surrogate not lower');
  Check(not IsWhitespace($D800), 'surrogate not whitespace');
  Check(not IsPunctuation($D800), 'surrogate not punctuation');
  Check(not IsSymbol($D800), 'surrogate not symbol');
end;

{ === Bidi_Class + Brackets (UAX #9 data) === }

procedure TestBidiClassAndBrackets;
begin
  CheckEqual(Int64(Ord(bcL)), Int64(Ord(GetBidiClass(Ord('A')))), 'A is L');
  { ASCII digits are EN }
  CheckEqual(Int64(Ord(bcEN)), Int64(Ord(GetBidiClass(Ord('0')))), '0 is EN');
  CheckEqual(Int64(Ord(bcEN)), Int64(Ord(GetBidiClass(Ord('9')))), '9 is EN');
  CheckEqual(Int64(Ord(bcWS)), Int64(Ord(GetBidiClass(Ord(' ')))), 'space is WS');
  CheckEqual(Int64(Ord(bcON)), Int64(Ord(GetBidiClass(Ord('!')))), '! is ON');
  CheckEqual(Int64(Ord(bcR)), Int64(Ord(GetBidiClass($05D0))), 'Hebrew Alef is R');
  CheckEqual(Int64(Ord(bcAL)), Int64(Ord(GetBidiClass($0627))), 'Arabic Alef is AL');
  CheckEqual(Int64(Ord(bcAN)), Int64(Ord(GetBidiClass($0660))), 'Arabic-Indic digit is AN');
  CheckEqual(Int64(Ord(bcLRE)), Int64(Ord(GetBidiClass($202A))), 'LRE');
  CheckEqual(Int64(Ord(bcRLE)), Int64(Ord(GetBidiClass($202B))), 'RLE');
  CheckEqual(Int64(Ord(bcPDF)), Int64(Ord(GetBidiClass($202C))), 'PDF');
  CheckEqual(Int64(Ord(bcLRI)), Int64(Ord(GetBidiClass($2066))), 'LRI');
  CheckEqual(Int64(Ord(bcRLI)), Int64(Ord(GetBidiClass($2067))), 'RLI');
  CheckEqual(Int64(Ord(bcFSI)), Int64(Ord(GetBidiClass($2068))), 'FSI');
  CheckEqual(Int64(Ord(bcPDI)), Int64(Ord(GetBidiClass($2069))), 'PDI');
  CheckEqual(Int64(Ord(bcNSM)), Int64(Ord(GetBidiClass($0301))), 'combining acute NSM');

  CheckEqual(Int64(Ord(bpbtOpen)), Int64(Ord(GetBidiPairedBracketType(Ord('(')))), '( open');
  CheckEqual(Int64(Ord(bpbtClose)), Int64(Ord(GetBidiPairedBracketType(Ord(')')))), ') close');
  CheckEqual(Int64(Ord(')')), Int64(GetBidiPairedBracket(Ord('('))), '( pairs )');
  CheckEqual(Int64(Ord('(')), Int64(GetBidiPairedBracket(Ord(')'))), ') pairs (');
  CheckEqual(Int64(Ord(bpbtNone)), Int64(Ord(GetBidiPairedBracketType(Ord('A')))), 'A no bracket');
  CheckEqual(Int64(Ord('A')), Int64(GetBidiPairedBracket(Ord('A'))), 'A pair self');
end;

procedure TestEastAsianWidth;
begin
  // Na / N
  CheckEqual(Int64(Ord(eawNarrow)), Int64(Ord(GetEastAsianWidth(Ord('A')))), 'A Na');
  CheckEqual(Int64(Ord(eawAmbiguous)), Int64(Ord(GetEastAsianWidth($0301))), 'combining acute A');
  CheckEqual(Int64(Ord(eawNeutral)), Int64(Ord(GetEastAsianWidth($0378))), 'unassigned N');
  // W / F
  CheckEqual(Int64(Ord(eawWide)), Int64(Ord(GetEastAsianWidth($4E2D))), 'CJK W');
  CheckEqual(Int64(Ord(eawFullwidth)), Int64(Ord(GetEastAsianWidth($FF21))), 'Fullwidth A F');
  // H halfwidth katakana
  CheckEqual(Int64(Ord(eawHalfwidth)), Int64(Ord(GetEastAsianWidth($FF66))), 'halfwidth H');
  // A ambiguous
  CheckEqual(Int64(Ord(eawAmbiguous)), Int64(Ord(GetEastAsianWidth($00A1))), 'inverted bang A');
  // FWH helper for LB19a
  Check(IsEastAsianFWH($4E2D), 'CJK FWH');
  Check(IsEastAsianFWH($FF21), 'fullwidth FWH');
  Check(IsEastAsianFWH($FF66), 'halfwidth FWH');
  Check(not IsEastAsianFWH(Ord('A')), 'A not FWH');
  Check(not IsEastAsianFWH($00A1), 'Ambiguous not FWH');
end;

begin
  T := TTestSuite.Create('nextpas.core.text.unicode');
  T.Test('IsUpper', @TestIsUpper);
  T.Test('IsLower', @TestIsLower);
  T.Test('IsAlpha', @TestIsAlpha);
  T.Test('IsLetter', @TestIsLetter);
  T.Test('IsDigit', @TestIsDigit);
  T.Test('IsNumber', @TestIsNumber);
  T.Test('IsWhitespace', @TestIsWhitespace);
  T.Test('IsSeparator', @TestIsSeparator);
  T.Test('IsControl', @TestIsControl);
  T.Test('IsPunctuation', @TestIsPunctuation);
  T.Test('IsSymbol', @TestIsSymbol);
  T.Test('IsMark', @TestIsMark);
  T.Test('GeneralCategory', @TestGeneralCategory);
  T.Test('CaseMapping', @TestCaseMapping);
  T.Test('BoundaryCases', @TestBoundaryCases);
  T.Test('SmpDeep', @TestSmpDeep);
  T.Test('HasBinaryProperty', @TestHasBinaryProperty);
  T.Test('GraphemeBreakProperty', @TestGraphemeBreakProperty);
  T.Test('PropertyCombinations', @TestPropertyCombinations);
  T.Test('BidiClassAndBrackets', @TestBidiClassAndBrackets);
  T.Test('EastAsianWidth', @TestEastAsianWidth);
  if not T.Run then Halt(1);
end.
