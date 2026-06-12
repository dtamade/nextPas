program test_grapheme;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.text.grapheme,
  nextpas.core.testing;
var T: TTestRunner;

procedure TestAscii;
var R: TGraphemeResult;
begin
  R := GraphemeNext(PByte(PAnsiChar('Hello')), 5);
  CheckEqual(Int64(1), Int64(R.ByteLen), 'ascii H = 1 byte');
  CheckEqual(Int64(1), Int64(R.Width), 'ascii H = 1 col');
  CheckEqual(Int64(1), Int64(R.CodePoints), 'ascii H = 1 cp');
end;

procedure TestCJK;
var S: AnsiString; R: TGraphemeResult;
begin
  S := #$E4#$B8#$96;
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(3), Int64(R.ByteLen), 'CJK 世 = 3 bytes');
  CheckEqual(Int64(2), Int64(R.Width), 'CJK 世 = 2 cols');
  CheckEqual(Int64(1), Int64(R.CodePoints), 'CJK 世 = 1 cp');
end;

procedure TestCombiningMark;
var S: AnsiString; R: TGraphemeResult;
begin
  S := 'e' + #$CC#$81;
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(3), Int64(R.ByteLen), 'e+combining = 3 bytes');
  CheckEqual(Int64(1), Int64(R.Width), 'e+combining = 1 col');
  CheckEqual(Int64(2), Int64(R.CodePoints), 'e+combining = 2 cps');
end;

procedure TestNKoCombiningMark;
var S: AnsiString; R: TGraphemeResult;
begin
  S := 'A' + #$DF#$AB;
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(3), Int64(R.ByteLen), 'A+NKo combining = 3 bytes');
  CheckEqual(Int64(1), Int64(R.Width), 'A+NKo combining = 1 col');
  CheckEqual(Int64(2), Int64(R.CodePoints), 'A+NKo combining = 2 cps');
end;

procedure TestWidthZeroWidthCombiningMarks;
var S: AnsiString; R: TGraphemeResult;
begin
  S := #$E1#$84#$80 + #$E1#$85#$A0; { U+1100 + U+1160 }
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(6), Int64(R.ByteLen), 'Hangul choseong + conjoining jungseong bytes');
  CheckEqual(Int64(2), Int64(R.Width), 'Hangul conjoining mark does not add width');
  CheckEqual(Int64(2), Int64(R.CodePoints), 'Hangul conjoining mark stays in cluster');

  S := #$E1#$84#$80 + #$E1#$87#$BF; { U+1100 + U+11FF }
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(6), Int64(R.ByteLen), 'Hangul conjoining upper bound bytes');
  CheckEqual(Int64(2), Int64(R.Width), 'Hangul conjoining upper bound width');
  CheckEqual(Int64(2), Int64(R.CodePoints), 'Hangul conjoining upper bound cluster');

  S := #$E1#$84#$80 + #$E1#$88#$80; { U+1100 + U+1200 }
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(3), Int64(R.ByteLen), 'Hangul range outside upper bound starts new cluster');

  S := 'A' + #$F0#$9E#$80#$80; { U+1E000 Glagolitic combining letter }
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(5), Int64(R.ByteLen), 'A + Glagolitic combining bytes');
  CheckEqual(Int64(1), Int64(R.Width), 'Glagolitic combining mark does not add width');
  CheckEqual(Int64(2), Int64(R.CodePoints), 'Glagolitic combining mark stays in cluster');

  S := 'A' + #$F0#$9E#$80#$AA; { U+1E02A }
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(5), Int64(R.ByteLen), 'Glagolitic combining upper bound bytes');
  CheckEqual(Int64(1), Int64(R.Width), 'Glagolitic combining upper bound width');
  CheckEqual(Int64(2), Int64(R.CodePoints), 'Glagolitic combining upper bound cluster');

  S := 'A' + #$F0#$9E#$80#$AB; { U+1E02B }
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(1), Int64(R.ByteLen), 'Glagolitic range outside upper bound starts new cluster');
end;

procedure TestPrependJoinsFollowingBase;
var S: AnsiString; R: TGraphemeResult;
begin
  S := #$D8#$80 + 'A'; { U+0600 + A }
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(3), Int64(R.ByteLen), 'Arabic number sign + A bytes');
  CheckEqual(Int64(1), Int64(R.Width), 'Arabic number sign + A width');
  CheckEqual(Int64(2), Int64(R.CodePoints), 'Arabic number sign + A codepoints');
end;

procedure TestPrependJoinsMalformedReplacement;
var S: AnsiString; R: TGraphemeResult;
begin
  S := #$D8#$80 + #$FF; { U+0600 + invalid byte => U+FFFD }
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(3), Int64(R.ByteLen), 'prepend + replacement bytes');
  CheckEqual(Int64(1), Int64(R.Width), 'prepend + replacement width');
  CheckEqual(Int64(2), Int64(R.CodePoints), 'prepend + replacement codepoints');
end;

procedure TestZWJEmoji;
var S: AnsiString; R: TGraphemeResult;
begin
  S := #$F0#$9F#$91#$A8 + #$E2#$80#$8D + #$F0#$9F#$91#$A9;
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  Check(R.ByteLen = Length(S), 'ZWJ man+woman = full cluster');
  Check(R.CodePoints = 3, 'ZWJ man+woman = 3 cps');
  Check(R.Width = 2, 'ZWJ man+woman = 2 cols');
end;

procedure TestZWJDoesNotJoinAfterNonEmoji;
var S: AnsiString; R: TGraphemeResult;
begin
  S := #$E2#$80#$8D + #$F0#$9F#$98#$80;
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(3), Int64(R.ByteLen), 'orphan ZWJ stops before emoji bytes');
  CheckEqual(Int64(1), Int64(R.CodePoints), 'orphan ZWJ = 1 cp');
  CheckEqual(Int64(0), Int64(R.Width), 'orphan ZWJ = 0 cols');

  S := 'A' + #$E2#$80#$8D + #$F0#$9F#$98#$80;
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(4), Int64(R.ByteLen), 'A+ZWJ stops before emoji bytes');
  CheckEqual(Int64(2), Int64(R.CodePoints), 'A+ZWJ = 2 cps');
  CheckEqual(Int64(1), Int64(R.Width), 'A+ZWJ = 1 col');
end;

procedure TestFamilyEmoji;
var S: AnsiString; R: TGraphemeResult;
begin
  S := #$F0#$9F#$91#$A8 + #$E2#$80#$8D +
       #$F0#$9F#$91#$A9 + #$E2#$80#$8D +
       #$F0#$9F#$91#$A7 + #$E2#$80#$8D +
       #$F0#$9F#$91#$A6;
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(25), Int64(R.ByteLen), 'family emoji = full cluster bytes');
  CheckEqual(Int64(7), Int64(R.CodePoints), 'family emoji = 7 cps');
  CheckEqual(Int64(2), Int64(R.Width), 'family emoji = 2 cols');
end;

procedure TestSkinToneEmoji;
var S: AnsiString; R: TGraphemeResult;
begin
  S := #$F0#$9F#$91#$8D + #$F0#$9F#$8F#$BD;
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(8), Int64(R.ByteLen), 'thumbs up medium skin tone = full cluster bytes');
  CheckEqual(Int64(2), Int64(R.CodePoints), 'thumbs up medium skin tone = 2 cps');
  CheckEqual(Int64(2), Int64(R.Width), 'thumbs up medium skin tone = 2 cols');
end;

procedure TestKeycapEmoji;
var S: AnsiString; R: TGraphemeResult;
begin
  S := '1' + #$EF#$B8#$8F + #$E2#$83#$A3;
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(7), Int64(R.ByteLen), 'keycap 1 = full cluster bytes');
  CheckEqual(Int64(3), Int64(R.CodePoints), 'keycap 1 = 3 cps');
  CheckEqual(Int64(2), Int64(R.Width), 'keycap 1 = 2 cols');

  S := '1' + #$E2#$83#$A3;
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(4), Int64(R.ByteLen), 'keycap 1 without VS16 = full cluster bytes');
  CheckEqual(Int64(2), Int64(R.CodePoints), 'keycap 1 without VS16 = 2 cps');
  CheckEqual(Int64(2), Int64(R.Width), 'keycap 1 without VS16 = 2 cols');

  S := '#' + #$EF#$B8#$8F + #$E2#$83#$A3;
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(2), Int64(R.Width), 'keycap # = 2 cols');

  S := '*' + #$EF#$B8#$8F + #$E2#$83#$A3;
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(2), Int64(R.Width), 'keycap * = 2 cols');

  S := 'A' + #$E2#$83#$A3;
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(4), Int64(R.ByteLen), 'non-keycap base + U+20E3 still clusters');
  CheckEqual(Int64(1), Int64(R.Width), 'non-keycap base + U+20E3 remains 1 col');
end;

procedure TestRegionalIndicator;
var S: AnsiString; R: TGraphemeResult;
begin
  S := #$F0#$9F#$87#$A8 + #$F0#$9F#$87#$B3;
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(8), Int64(R.ByteLen), 'flag CN = 8 bytes');
  CheckEqual(Int64(2), Int64(R.CodePoints), 'flag CN = 2 cps');
  CheckEqual(Int64(2), Int64(R.Width), 'flag CN = 2 cols');
end;

procedure TestVariationSelector;
var S: AnsiString; R: TGraphemeResult;
begin
  S := #$E2#$9D#$A4 + #$EF#$B8#$8F;
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(6), Int64(R.ByteLen), 'heart+VS16 = 6 bytes');
  CheckEqual(Int64(2), Int64(R.CodePoints), 'heart+VS16 = 2 cps');
  CheckEqual(Int64(2), Int64(R.Width), 'heart+VS16 = 2 cols');

  S := #$E2#$98#$8E + #$EF#$B8#$8F;
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(6), Int64(R.ByteLen), 'telephone+VS16 = 6 bytes');
  CheckEqual(Int64(2), Int64(R.CodePoints), 'telephone+VS16 = 2 cps');
  CheckEqual(Int64(2), Int64(R.Width), 'telephone+VS16 = 2 cols');

  S := #$E2#$9C#$88 + #$EF#$B8#$8F;
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(6), Int64(R.ByteLen), 'airplane+VS16 = 6 bytes');
  CheckEqual(Int64(2), Int64(R.CodePoints), 'airplane+VS16 = 2 cps');
  CheckEqual(Int64(2), Int64(R.Width), 'airplane+VS16 = 2 cols');

  S := #$E2#$98#$BA + #$EF#$B8#$8F;
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(6), Int64(R.ByteLen), 'smiling face+VS16 = 6 bytes');
  CheckEqual(Int64(2), Int64(R.CodePoints), 'smiling face+VS16 = 2 cps');
  CheckEqual(Int64(2), Int64(R.Width), 'smiling face+VS16 = 2 cols');

  S := #$E2#$98#$86 + #$EF#$B8#$8F;
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(6), Int64(R.ByteLen), 'white star+VS16 = 6 bytes');
  CheckEqual(Int64(2), Int64(R.CodePoints), 'white star+VS16 = 2 cps');
  CheckEqual(Int64(1), Int64(R.Width), 'white star+VS16 remains 1 col');
end;

procedure TestEmojiTagSequence;
var S: AnsiString; R: TGraphemeResult;
begin
  S := #$F0#$9F#$8F#$B4 +      { black flag }
       #$F3#$A0#$81#$A7 +      { tag g }
       #$F3#$A0#$81#$A2 +      { tag b }
       #$F3#$A0#$81#$A5 +      { tag e }
       #$F3#$A0#$81#$AE +      { tag n }
       #$F3#$A0#$81#$A7 +      { tag g }
       #$F3#$A0#$81#$BF;       { cancel tag }
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(28), Int64(R.ByteLen), 'England flag tag sequence bytes');
  CheckEqual(Int64(7), Int64(R.CodePoints), 'England flag tag sequence cps');
  CheckEqual(Int64(2), Int64(R.Width), 'England flag tag sequence width');
end;

procedure TestIndicClusters;
var S: AnsiString; R: TGraphemeResult;
begin
  S := #$E0#$AE#$95 + #$E0#$AE#$BE; { U+0B95 TAMIL KA + U+0BBE AA }
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(6), Int64(R.ByteLen), 'Tamil KA + AA bytes');
  CheckEqual(Int64(2), Int64(R.CodePoints), 'Tamil KA + AA cps');
  CheckEqual(Int64(1), Int64(R.Width), 'Tamil KA + AA width');

  S := #$E0#$A4#$95 + #$E0#$A5#$8D + #$E0#$A4#$B7; { U+0915 KA + U+094D VIRAMA + U+0937 SSA }
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(9), Int64(R.ByteLen), 'Devanagari KA + VIRAMA + SSA bytes');
  CheckEqual(Int64(3), Int64(R.CodePoints), 'Devanagari KA + VIRAMA + SSA cps');
  CheckEqual(Int64(1), Int64(R.Width), 'Devanagari KA + VIRAMA + SSA width');

  S := #$E0#$AE#$95 + #$E0#$AF#$8D + #$E0#$AE#$95; { U+0B95 TAMIL KA + U+0BCD VIRAMA + U+0B95 KA }
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  CheckEqual(Int64(9), Int64(R.ByteLen), 'Tamil KA + VIRAMA + KA bytes');
  CheckEqual(Int64(3), Int64(R.CodePoints), 'Tamil KA + VIRAMA + KA cps');
  CheckEqual(Int64(1), Int64(R.Width), 'Tamil KA + VIRAMA + KA width');
end;

procedure TestEmpty;
var R: TGraphemeResult;
begin
  R := GraphemeNext(nil, 0);
  CheckEqual(Int64(0), Int64(R.ByteLen), 'empty = 0');
end;

procedure TestNilNonzeroSpan;
var R: TGraphemeResult;
begin
  R := GraphemeNext(nil, 1);
  CheckEqual(Int64(0), Int64(R.ByteLen), 'nil nonzero = 0 bytes');
  CheckEqual(Int64(0), Int64(R.Width), 'nil nonzero = 0 cols');
  CheckEqual(Int64(0), Int64(R.CodePoints), 'nil nonzero = 0 cps');
end;

procedure TestInvalidByte;
var B: Byte; R: TGraphemeResult;
begin
  B := $FF;
  R := GraphemeNext(@B, 1);
  CheckEqual(Int64(1), Int64(R.ByteLen), 'invalid = 1 byte skip');
  CheckEqual(Int64(1), Int64(R.Width), 'invalid = 1 col');
end;

begin
  T := TTestRunner.Create('nextpas.core.text.grapheme');
  T.Run('ascii', @TestAscii);
  T.Run('cjk', @TestCJK);
  T.Run('combining mark', @TestCombiningMark);
  T.Run('nko combining mark', @TestNKoCombiningMark);
  T.Run('width zero-width combining marks', @TestWidthZeroWidthCombiningMarks);
  T.Run('prepend joins following base', @TestPrependJoinsFollowingBase);
  T.Run('prepend joins malformed replacement', @TestPrependJoinsMalformedReplacement);
  T.Run('zwj emoji', @TestZWJEmoji);
  T.Run('zwj after non-emoji', @TestZWJDoesNotJoinAfterNonEmoji);
  T.Run('family emoji', @TestFamilyEmoji);
  T.Run('skin tone emoji', @TestSkinToneEmoji);
  T.Run('keycap emoji', @TestKeycapEmoji);
  T.Run('regional indicator', @TestRegionalIndicator);
  T.Run('variation selector', @TestVariationSelector);
  T.Run('emoji tag sequence', @TestEmojiTagSequence);
  T.Run('Indic clusters', @TestIndicClusters);
  T.Run('empty', @TestEmpty);
  T.Run('nil nonzero span', @TestNilNonzeroSpan);
  T.Run('invalid byte', @TestInvalidByte);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
