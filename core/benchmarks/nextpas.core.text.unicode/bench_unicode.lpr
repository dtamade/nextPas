program bench_unicode;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.bench,
  nextpas.core.text.unicode.base,
  nextpas.core.text.unicode.types,
  nextpas.core.text.unicode,
  nextpas.core.text.unicode.utils,
  nextpas.core.text.utf8;

const
  ASCII_50     = 'The quick brown fox jumps over the lazy dog 12345!';
  ASCII_200    = 'The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump! The five boxing wizards jump quickly. Crazy Frederick bought many very exquisite opal jewels. Sphinx of black quartz, judge my vow. Two driven jocks help fax my big quiz.';
  BMP_LATIN_50   = #$C3#$80#$C3#$81#$C3#$82#$C3#$83#$C3#$84 +
                 #$C3#$85#$C3#$86#$C3#$87#$C3#$88#$C3#$89 +
                 #$C3#$8A#$C3#$8B#$C3#$8C#$C3#$8D#$C3#$8E +
                 #$C3#$8F#$C3#$90#$C3#$91#$C3#$92#$C3#$93 +
                 #$C3#$94#$C3#$95#$C3#$96#$C3#$98#$C3#$99 +
                 #$C3#$9A#$C3#$9B#$C3#$9C#$C3#$9D#$C3#$9E +
                 #$C3#$9F#$C3#$A0#$C3#$A1#$C3#$A2#$C3#$A3 +
                 #$C3#$A4#$C3#$A5#$C3#$A6#$C3#$A7#$C3#$A8 +
                 #$C3#$A9#$C3#$AA#$C3#$AB#$C3#$AC#$C3#$AD +
                 #$C3#$AE#$C3#$AF#$C3#$B0#$C3#$B1#$C3#$B2;
  BMP_CJK_50   = #$4E00#$4E01#$4E02#$4E03#$4E04#$4E05#$4E06#$4E07#$4E08#$4E09 +
                 #$4E0A#$4E0B#$4E0C#$4E0D#$4E0E#$4E0F#$4E10#$4E11#$4E12#$4E13 +
                 #$4E14#$4E15#$4E16#$4E17#$4E18#$4E19#$4E1A#$4E1B#$4E1C#$4E1D +
                 #$4E1E#$4E1F#$4E20#$4E21#$4E22#$4E23#$4E24#$4E25#$4E26#$4E27 +
                 #$4E28#$4E29#$4E2A#$4E2B#$4E2C#$4E2D#$4E2E#$4E2F#$4E30#$4E31;

var
  LResults: IBenchResults;
  LSink: string;
  LSinkInt: Integer;

{ === N1-N10: Normalization === }

procedure BenchNFC_Ascii50(AIterations: Int64);
var I: Int64; begin for I := 1 to AIterations do LSink := NFC(ASCII_50); end;

procedure BenchNFC_Ascii200(AIterations: Int64);
var I: Int64; begin for I := 1 to AIterations do LSink := NFC(ASCII_200); end;

procedure BenchNFD_Ascii50(AIterations: Int64);
var I: Int64; begin for I := 1 to AIterations do LSink := NFD(ASCII_50); end;

procedure BenchNFC_BmpLatin50(AIterations: Int64);
var I: Int64; begin for I := 1 to AIterations do LSink := NFC(BMP_LATIN_50); end;

procedure BenchNFD_BmpLatin50(AIterations: Int64);
var I: Int64; begin for I := 1 to AIterations do LSink := NFD(BMP_LATIN_50); end;

procedure BenchNFC_BmpCjk50(AIterations: Int64);
var I: Int64; begin for I := 1 to AIterations do LSink := NFC(BMP_CJK_50); end;

procedure BenchNFD_BmpCjk50(AIterations: Int64);
var I: Int64; begin for I := 1 to AIterations do LSink := NFD(BMP_CJK_50); end;

procedure BenchNFKD_BmpLatin50(AIterations: Int64);
var I: Int64; begin for I := 1 to AIterations do LSink := NFKD(BMP_LATIN_50); end;

procedure BenchQuickCheckNFC_Ascii200(AIterations: Int64);
var I: Int64; LBool: Boolean; begin
  for I := 1 to AIterations do LBool := QuickCheckNFC(ASCII_200);
  LSinkInt := Ord(LBool);
end;

procedure BenchQuickCheckNFC_BmpLatin50(AIterations: Int64);
var I: Int64; LBool: Boolean; begin
  for I := 1 to AIterations do LBool := QuickCheckNFC(BMP_LATIN_50);
  LSinkInt := Ord(LBool);
end;

{ === G1-G4: Segmentation === }

procedure BenchNextGrapheme_Ascii200(AIterations: Int64);
var I: Int64; LPos: SizeInt; begin
  LPos := 1;
  for I := 1 to AIterations do
  begin
    LPos := UnicodeSegmenter.NextGraphemeCluster(ASCII_200, LPos);
    if LPos > Length(ASCII_200) then LPos := 1;
  end;
  LSinkInt := LPos;
end;

procedure BenchNextGrapheme_BmpCjk50(AIterations: Int64);
var I: Int64; LPos: SizeInt; begin
  LPos := 1;
  for I := 1 to AIterations do
  begin
    LPos := UnicodeSegmenter.NextGraphemeCluster(BMP_CJK_50, LPos);
    if LPos > Length(BMP_CJK_50) then LPos := 1;
  end;
  LSinkInt := LPos;
end;

procedure BenchNextWord_BmpCjk50(AIterations: Int64);
var I: Int64; LPos: SizeInt; begin
  LPos := 1;
  for I := 1 to AIterations do
  begin
    LPos := UnicodeSegmenter.NextWord(BMP_CJK_50, LPos);
    if LPos > Length(BMP_CJK_50) then LPos := 1;
  end;
  LSinkInt := LPos;
end;

procedure BenchNextLine_Ascii200(AIterations: Int64);
var I: Int64; LPos: SizeInt; begin
  LPos := 1;
  for I := 1 to AIterations do
  begin
    LPos := UnicodeSegmenter.NextLine(ASCII_200, LPos);
    if LPos > Length(ASCII_200) then LPos := 1;
  end;
  LSinkInt := LPos;
end;

{ === C1-C5: Collation === }

procedure BenchCompare_Ascii50(AIterations: Int64);
var I: Int64; LCol: IUnicodeCollator; begin
  LCol := UnicodeCollator;
  for I := 1 to AIterations do LSinkInt := LCol.Compare(ASCII_50, ASCII_200);
end;

procedure BenchCompare_BmpLatin50(AIterations: Int64);
var I: Int64; LCol: IUnicodeCollator; begin
  LCol := UnicodeCollator;
  for I := 1 to AIterations do LSinkInt := LCol.Compare(BMP_LATIN_50, BMP_LATIN_50);
end;

procedure BenchCompare_BmpCjk50(AIterations: Int64);
var I: Int64; LCol: IUnicodeCollator; begin
  LCol := UnicodeCollator;
  for I := 1 to AIterations do LSinkInt := LCol.Compare(BMP_CJK_50, BMP_CJK_50);
end;

procedure BenchGetSortKey_Ascii50(AIterations: Int64);
var I: Int64; LCol: IUnicodeCollator; LKey: TCollationKey; begin
  LCol := UnicodeCollator;
  for I := 1 to AIterations do LKey := LCol.GetSortKey(ASCII_50);
  LSinkInt := Length(LKey);
end;

procedure BenchGetSortKey_BmpLatin50(AIterations: Int64);
var I: Int64; LCol: IUnicodeCollator; LKey: TCollationKey; begin
  LCol := UnicodeCollator;
  for I := 1 to AIterations do LKey := LCol.GetSortKey(BMP_LATIN_50);
  LSinkInt := Length(LKey);
end;

{ === P1-P5: Property Lookup === }

procedure BenchGeneralCategory_Ascii200(AIterations: Int64);
var I: Int64; LCp: UInt32; LIter: TUTF8Iterator; begin
  for I := 1 to AIterations do
  begin
    LIter.Init(PByte(PAnsiChar(ASCII_200)), SizeUInt(Length(ASCII_200)));
    while LIter.Next(LCp) do
      LSinkInt := Ord(UnicodeData.GetGeneralCategory(LCp));
  end;
end;

procedure BenchGeneralCategory_BmpCjk50(AIterations: Int64);
var I: Int64; LCp: UInt32; LIter: TUTF8Iterator; begin
  for I := 1 to AIterations do
  begin
    LIter.Init(PByte(PAnsiChar(BMP_CJK_50)), SizeUInt(Length(BMP_CJK_50)));
    while LIter.Next(LCp) do
      LSinkInt := Ord(UnicodeData.GetGeneralCategory(LCp));
  end;
end;

procedure BenchBinaryProperty_Ascii200(AIterations: Int64);
var I: Int64; LCp: UInt32; LBool: Boolean; LIter: TUTF8Iterator; begin
  for I := 1 to AIterations do
  begin
    LIter.Init(PByte(PAnsiChar(ASCII_200)), SizeUInt(Length(ASCII_200)));
    while LIter.Next(LCp) do
      LBool := HasBinaryProperty(LCp, ubpWhiteSpace);
  end;
  LSinkInt := Ord(LBool);
end;

procedure BenchGetScript_BmpCjk50(AIterations: Int64);
var I: Int64; LCp: UInt32; LIter: TUTF8Iterator; begin
  for I := 1 to AIterations do
  begin
    LIter.Init(PByte(PAnsiChar(BMP_CJK_50)), SizeUInt(Length(BMP_CJK_50)));
    while LIter.Next(LCp) do
      LSinkInt := Ord(UnicodeData.GetScript(LCp));
  end;
end;

procedure BenchCCC_BmpLatin50(AIterations: Int64);
var I: Int64; LCp: UInt32; LIter: TUTF8Iterator; begin
  for I := 1 to AIterations do
  begin
    LIter.Init(PByte(PAnsiChar(BMP_LATIN_50)), SizeUInt(Length(BMP_LATIN_50)));
    while LIter.Next(LCp) do
      LSinkInt := GetCanonicalCombiningClass(LCp);
  end;
end;

{ === F1-F5: Case Folding + Utils === }

procedure BenchCaseFoldSimple_Ascii200(AIterations: Int64);
var I: Int64; LCp: UInt32; LIter: TUTF8Iterator; begin
  for I := 1 to AIterations do
  begin
    LIter.Init(PByte(PAnsiChar(ASCII_200)), SizeUInt(Length(ASCII_200)));
    while LIter.Next(LCp) do
      LSinkInt := CaseFoldSimple(LCp);
  end;
end;

procedure BenchCaseFoldSimple_BmpLatin50(AIterations: Int64);
var I: Int64; LCp: UInt32; LIter: TUTF8Iterator; begin
  for I := 1 to AIterations do
  begin
    LIter.Init(PByte(PAnsiChar(BMP_LATIN_50)), SizeUInt(Length(BMP_LATIN_50)));
    while LIter.Next(LCp) do
      LSinkInt := CaseFoldSimple(LCp);
  end;
end;

procedure BenchUTF8CaseFoldSimple_Ascii200(AIterations: Int64);
var I: Int64; begin for I := 1 to AIterations do LSink := UTF8CaseFoldSimple(ASCII_200); end;

procedure BenchUTF8CaseFoldSimple_BmpLatin50(AIterations: Int64);
var I: Int64; begin for I := 1 to AIterations do LSink := UTF8CaseFoldSimple(BMP_LATIN_50); end;

procedure BenchIsAsciiString_Ascii200(AIterations: Int64);
var I: Int64; LBool: Boolean; begin
  for I := 1 to AIterations do LBool := IsAsciiString(ASCII_200);
  LSinkInt := Ord(LBool);
end;

procedure BenchIsAsciiString_BmpLatin50(AIterations: Int64);
var I: Int64; LBool: Boolean; begin
  for I := 1 to AIterations do LBool := IsAsciiString(BMP_LATIN_50);
  LSinkInt := Ord(LBool);
end;

{ === Main === }

begin
  LSink := '';
  LSinkInt := 0;

  try
    WriteLn('=== nextpas.core.text.unicode benchmark ===');
    WriteLn('compiler-flags=-MObjFPC -Sh -O2');
    WriteLn('scope=Unicode operations across ASCII/BMP-Latin/BMP-CJK inputs');
    WriteLn;

    // N1-N10: Normalization
    LResults := TBenchSuite.Create('Unicode Normalization')
      .AddLoop('NFC ASCII-50', @BenchNFC_Ascii50)
      .AddLoop('NFC ASCII-200', @BenchNFC_Ascii200)
      .AddLoop('NFD ASCII-50', @BenchNFD_Ascii50)
      .AddLoop('NFC BMP-Latin-50', @BenchNFC_BmpLatin50)
      .AddLoop('NFD BMP-Latin-50', @BenchNFD_BmpLatin50)
      .AddLoop('NFC BMP-CJK-50', @BenchNFC_BmpCjk50)
      .AddLoop('NFD BMP-CJK-50', @BenchNFD_BmpCjk50)
      .AddLoop('NFKD BMP-Latin-50', @BenchNFKD_BmpLatin50)
      .AddLoop('QuickCheckNFC ASCII-200', @BenchQuickCheckNFC_Ascii200)
      .AddLoop('QuickCheckNFC BMP-Latin-50', @BenchQuickCheckNFC_BmpLatin50)
      .Run;
    WriteLn(LResults.PrintToConsole);
    WriteLn;

    // G1-G4: Segmentation
    LResults := TBenchSuite.Create('Unicode Segmentation')
      .AddLoop('NextGrapheme ASCII-200', @BenchNextGrapheme_Ascii200)
      .AddLoop('NextGrapheme BMP-CJK-50', @BenchNextGrapheme_BmpCjk50)
      .AddLoop('NextWord BMP-CJK-50', @BenchNextWord_BmpCjk50)
      .AddLoop('NextLine ASCII-200', @BenchNextLine_Ascii200)
      .Run;
    WriteLn(LResults.PrintToConsole);
    WriteLn;

    // C1-C5: Collation
    LResults := TBenchSuite.Create('Unicode Collation')
      .AddLoop('Compare ASCII-50 vs 200', @BenchCompare_Ascii50)
      .AddLoop('Compare BMP-Latin-50', @BenchCompare_BmpLatin50)
      .AddLoop('Compare BMP-CJK-50', @BenchCompare_BmpCjk50)
      .AddLoop('GetSortKey ASCII-50', @BenchGetSortKey_Ascii50)
      .AddLoop('GetSortKey BMP-Latin-50', @BenchGetSortKey_BmpLatin50)
      .Run;
    WriteLn(LResults.PrintToConsole);
    WriteLn;

    // P1-P5: Property Lookup
    LResults := TBenchSuite.Create('Unicode Property Lookup')
      .AddLoop('GeneralCategory ASCII-200', @BenchGeneralCategory_Ascii200)
      .AddLoop('GeneralCategory BMP-CJK-50', @BenchGeneralCategory_BmpCjk50)
      .AddLoop('BinaryProperty ASCII-200', @BenchBinaryProperty_Ascii200)
      .AddLoop('GetScript BMP-CJK-50', @BenchGetScript_BmpCjk50)
      .AddLoop('CCC BMP-Latin-50', @BenchCCC_BmpLatin50)
      .Run;
    WriteLn(LResults.PrintToConsole);
    WriteLn;

    // F1-F5: Case Folding + Utils
    LResults := TBenchSuite.Create('Unicode Case & Utils')
      .AddLoop('CaseFoldSimple ASCII-200', @BenchCaseFoldSimple_Ascii200)
      .AddLoop('CaseFoldSimple BMP-Latin-50', @BenchCaseFoldSimple_BmpLatin50)
      .AddLoop('UTF8CaseFoldSimple ASCII-200', @BenchUTF8CaseFoldSimple_Ascii200)
      .AddLoop('UTF8CaseFoldSimple BMP-Latin-50', @BenchUTF8CaseFoldSimple_BmpLatin50)
      .AddLoop('IsAsciiString ASCII-200', @BenchIsAsciiString_Ascii200)
      .AddLoop('IsAsciiString BMP-Latin-50', @BenchIsAsciiString_BmpLatin50)
      .Run;
    WriteLn(LResults.PrintToConsole);

  finally
  end;

  WriteLn;
  WriteLn('sink=', LSinkInt, ':', Length(LSink));
end.
