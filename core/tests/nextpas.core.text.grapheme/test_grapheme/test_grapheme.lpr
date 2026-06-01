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

procedure TestZWJEmoji;
var S: AnsiString; R: TGraphemeResult;
begin
  S := #$F0#$9F#$91#$A8 + #$E2#$80#$8D + #$F0#$9F#$91#$A9;
  R := GraphemeNext(PByte(PAnsiChar(S)), Length(S));
  Check(R.ByteLen = Length(S), 'ZWJ man+woman = full cluster');
  Check(R.CodePoints = 3, 'ZWJ man+woman = 3 cps');
  Check(R.Width = 2, 'ZWJ man+woman = 2 cols');
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
end;

procedure TestEmpty;
var R: TGraphemeResult;
begin
  R := GraphemeNext(nil, 0);
  CheckEqual(Int64(0), Int64(R.ByteLen), 'empty = 0');
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
  T.Run('zwj emoji', @TestZWJEmoji);
  T.Run('family emoji', @TestFamilyEmoji);
  T.Run('skin tone emoji', @TestSkinToneEmoji);
  T.Run('keycap emoji', @TestKeycapEmoji);
  T.Run('regional indicator', @TestRegionalIndicator);
  T.Run('variation selector', @TestVariationSelector);
  T.Run('empty', @TestEmpty);
  T.Run('invalid byte', @TestInvalidByte);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
