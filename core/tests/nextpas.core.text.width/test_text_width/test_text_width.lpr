program test_text_width;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.width,
  nextpas.core.testing;

var
  T: TTestRunner;

{ CodepointWidth - 控制字符 }
procedure TestControlChars;
begin
  CheckEqual(Int64(0), Int64(CodepointWidth(0)), 'NUL');
  CheckEqual(Int64(0), Int64(CodepointWidth(9)), 'TAB');
  CheckEqual(Int64(0), Int64(CodepointWidth(10)), 'LF');
  CheckEqual(Int64(0), Int64(CodepointWidth(27)), 'ESC');
  CheckEqual(Int64(0), Int64(CodepointWidth($7F)), 'DEL');
  CheckEqual(Int64(0), Int64(CodepointWidth($80)), 'C1 start');
  CheckEqual(Int64(0), Int64(CodepointWidth($9F)), 'C1 end');
end;

{ CodepointWidth - ASCII / Latin 窄字符 }
procedure TestNarrowChars;
begin
  CheckEqual(Int64(1), Int64(CodepointWidth(Ord('A'))), 'A');
  CheckEqual(Int64(1), Int64(CodepointWidth(Ord(' '))), 'space');
  CheckEqual(Int64(1), Int64(CodepointWidth(Ord('~'))), 'tilde');
  CheckEqual(Int64(1), Int64(CodepointWidth($A0)), 'NBSP');
  CheckEqual(Int64(1), Int64(CodepointWidth($E9)), 'e-acute');
  CheckEqual(Int64(1), Int64(CodepointWidth($2FF)), 'before combining');
end;

{ CodepointWidth - East Asian Wide }
procedure TestWideChars;
begin
  CheckEqual(Int64(2), Int64(CodepointWidth($4E2D)), 'CJK 中');
  CheckEqual(Int64(2), Int64(CodepointWidth($3042)), 'Hiragana あ');
  CheckEqual(Int64(2), Int64(CodepointWidth($AC00)), 'Hangul 가');
  CheckEqual(Int64(2), Int64(CodepointWidth($FF21)), 'Fullwidth A');
  CheckEqual(Int64(2), Int64(CodepointWidth($1100)), 'Hangul Jamo');
  CheckEqual(Int64(2), Int64(CodepointWidth($231A)), 'watch');
end;

{ CodepointWidth - Emoji（宽） }
procedure TestEmojiWidth;
begin
  CheckEqual(Int64(2), Int64(CodepointWidth($1F600)), 'grinning face');
  CheckEqual(Int64(2), Int64(CodepointWidth($1F300)), 'cyclone');
  CheckEqual(Int64(2), Int64(CodepointWidth($2B50)), 'star');
  CheckEqual(Int64(2), Int64(CodepointWidth($1F004)), 'mahjong');
end;

{ CodepointWidth - 零宽组合标记 }
procedure TestZeroWidthMarks;
begin
  CheckEqual(Int64(0), Int64(CodepointWidth($0300)), 'combining grave');
  CheckEqual(Int64(0), Int64(CodepointWidth($200B)), 'ZWSP');
  CheckEqual(Int64(0), Int64(CodepointWidth($200D)), 'ZWJ');
  CheckEqual(Int64(0), Int64(CodepointWidth($FE0F)), 'variation selector');
  CheckEqual(Int64(0), Int64(CodepointWidth($FEFF)), 'BOM');
  CheckEqual(Int64(0), Int64(CodepointWidth($E0100)), 'VS supplement');
end;

{ CodepointWidth - CJK Extension B（高位宽） }
procedure TestSupplementaryWide;
begin
  CheckEqual(Int64(2), Int64(CodepointWidth($20000)), 'CJK Ext B start');
  CheckEqual(Int64(2), Int64(CodepointWidth($2A6DF)), 'CJK Ext B');
end;

{ StringDisplayWidth - 纯 ASCII 快路径 }
procedure TestAsciiString;
begin
  CheckEqual(Int64(0), Int64(StringDisplayWidth('')), 'empty');
  CheckEqual(Int64(5), Int64(StringDisplayWidth('hello')), 'hello');
  CheckEqual(Int64(11), Int64(StringDisplayWidth('hello world')), 'hello world');
end;

procedure TestAsciiControlStringWidth;
begin
  CheckEqual(Int64(0), Int64(StringDisplayWidth(#0)), 'NUL string width');
  CheckEqual(Int64(0), Int64(StringDisplayWidth(#9)), 'TAB string width');
  CheckEqual(Int64(2), Int64(StringDisplayWidth('A' + #0 + 'B')), 'NUL does not add a column');
  CheckEqual(Int64(2), Int64(StringDisplayWidth('A' + #9 + 'B')), 'TAB follows CodepointWidth');
end;

{ StringDisplayWidth - CJK 混合 }
procedure TestMixedString;
begin
  { '中' = E4 B8 AD (3 bytes, width 2) }
  CheckEqual(Int64(2), Int64(StringDisplayWidth(#$E4#$B8#$AD)), 'CJK 中');
  { 'a中b' = a(1) + 中(2) + b(1) = 4 }
  CheckEqual(Int64(4), Int64(StringDisplayWidth('a' + #$E4#$B8#$AD + 'b')), 'a中b');
  { 中文 = 2+2 = 4 }
  CheckEqual(Int64(4), Int64(StringDisplayWidth(#$E4#$B8#$AD#$E6#$96#$87)), '中文');
end;

{ StringDisplayWidth - emoji }
procedure TestEmojiString;
begin
  { 😀 = F0 9F 98 80 (4 bytes, width 2) }
  CheckEqual(Int64(2), Int64(StringDisplayWidth(#$F0#$9F#$98#$80)), 'emoji');
  { a😀 = 1 + 2 = 3 }
  CheckEqual(Int64(3), Int64(StringDisplayWidth('a' + #$F0#$9F#$98#$80)), 'a emoji');
  CheckEqual(Int64(2), Int64(StringDisplayWidth(#$E2#$9D#$A4 + #$EF#$B8#$8F)), 'heart VS16 emoji');
  CheckEqual(Int64(2), Int64(StringDisplayWidth(#$E2#$98#$8E + #$EF#$B8#$8F)), 'telephone VS16 emoji');
  CheckEqual(Int64(2), Int64(StringDisplayWidth(#$E2#$9C#$88 + #$EF#$B8#$8F)), 'airplane VS16 emoji');
  CheckEqual(Int64(2), Int64(StringDisplayWidth(#$E2#$98#$BA + #$EF#$B8#$8F)), 'smiling face VS16 emoji');
  CheckEqual(Int64(4), Int64(StringDisplayWidth('x' + #$E2#$98#$8E + #$EF#$B8#$8F + 'y')), 'mixed telephone VS16 width');
  CheckEqual(Int64(1), Int64(StringDisplayWidth(#$E2#$98#$86 + #$EF#$B8#$8F)), 'white star VS16 remains narrow');
end;

procedure TestEmojiClusterString;
var
  LFamily: AnsiString;
  LSkinTone: AnsiString;
  LEnglandFlag: AnsiString;
begin
  LFamily := #$F0#$9F#$91#$A8 + #$E2#$80#$8D +
             #$F0#$9F#$91#$A9 + #$E2#$80#$8D +
             #$F0#$9F#$91#$A7 + #$E2#$80#$8D +
             #$F0#$9F#$91#$A6;
  LSkinTone := #$F0#$9F#$91#$8D + #$F0#$9F#$8F#$BD;
  LEnglandFlag := #$F0#$9F#$8F#$B4 +
                  #$F3#$A0#$81#$A7 +
                  #$F3#$A0#$81#$A2 +
                  #$F3#$A0#$81#$A5 +
                  #$F3#$A0#$81#$AE +
                  #$F3#$A0#$81#$A7 +
                  #$F3#$A0#$81#$BF;
  CheckEqual(Int64(2), Int64(StringDisplayWidth(LFamily)), 'family emoji cluster width');
  CheckEqual(Int64(2), Int64(StringDisplayWidth(LSkinTone)), 'skin tone emoji cluster width');
  CheckEqual(Int64(2), Int64(StringDisplayWidth(LEnglandFlag)), 'emoji tag sequence width');
  CheckEqual(Int64(5), Int64(StringDisplayWidth('a' + LFamily + LSkinTone)), 'mixed emoji clusters width');
end;

procedure TestZWJAfterNonEmojiString;
begin
  CheckEqual(Int64(2), Int64(StringDisplayWidth(#$E2#$80#$8D + #$F0#$9F#$98#$80)),
    'orphan ZWJ+emoji stays two display clusters');
  CheckEqual(Int64(3), Int64(StringDisplayWidth('A' + #$E2#$80#$8D + #$F0#$9F#$98#$80)),
    'A+ZWJ+emoji stays two display clusters');
end;

procedure TestKeycapEmojiString;
var
  LKeycap: AnsiString;
begin
  LKeycap := '1' + #$EF#$B8#$8F + #$E2#$83#$A3;
  CheckEqual(Int64(2), Int64(StringDisplayWidth(LKeycap)), 'keycap emoji cluster width');
  CheckEqual(Int64(5), Int64(StringDisplayWidth('a' + LKeycap + 'bc')), 'mixed keycap emoji width');
  CheckEqual(Int64(2), Int64(StringDisplayWidth('1' + #$E2#$83#$A3)), 'keycap emoji without VS16 width');
  CheckEqual(Int64(2), Int64(StringDisplayWidth('#' + #$EF#$B8#$8F + #$E2#$83#$A3)), 'keycap # width');
  CheckEqual(Int64(2), Int64(StringDisplayWidth('*' + #$EF#$B8#$8F + #$E2#$83#$A3)), 'keycap * width');
  CheckEqual(Int64(1), Int64(StringDisplayWidth('A' + #$E2#$83#$A3)), 'non-keycap base + U+20E3 width');
end;

{ StringDisplayWidth - 组合标记不计宽 }
procedure TestCombiningString;
begin
  { 'e' + combining acute (CC 81 = U+0301) = 1 + 0 = 1 }
  CheckEqual(Int64(1), Int64(StringDisplayWidth('e' + #$CC#$81)), 'e + combining');
end;

procedure TestNKoCombiningString;
begin
  CheckEqual(Int64(0), Int64(CodepointWidth($07EB)), 'NKo combining short high tone');
  CheckEqual(Int64(1), Int64(StringDisplayWidth('A' + #$DF#$AB)), 'A + NKo combining mark');
end;

procedure TestWidthZeroWidthCombiningString;
begin
  CheckEqual(Int64(0), Int64(CodepointWidth($1E000)), 'Glagolitic combining letter');
  CheckEqual(Int64(0), Int64(CodepointWidth($1E02A)), 'Glagolitic combining upper bound');
  CheckEqual(Int64(1), Int64(CodepointWidth($1E02B)), 'after Glagolitic combining range');
  CheckEqual(Int64(1), Int64(StringDisplayWidth(#$D8#$80 + 'A')),
    'Arabic prepend mark joins following base');
  CheckEqual(Int64(2), Int64(StringDisplayWidth('x' + #$D8#$80 + 'A')),
    'ASCII plus Arabic prepend cluster');
  CheckEqual(Int64(2), Int64(StringDisplayWidth(#$E1#$84#$80 + #$E1#$85#$A0)),
    'Hangul conjoining mark stays with wide base');
  CheckEqual(Int64(2), Int64(StringDisplayWidth(#$E1#$84#$80 + #$E1#$87#$BF)),
    'Hangul conjoining upper bound stays with wide base');
  CheckEqual(Int64(3), Int64(StringDisplayWidth(#$E1#$84#$80 + #$E1#$88#$80)),
    'after Hangul conjoining range starts a new cluster');
  CheckEqual(Int64(1), Int64(StringDisplayWidth('A' + #$F0#$9E#$80#$80)),
    'A + Glagolitic combining mark');
  CheckEqual(Int64(1), Int64(StringDisplayWidth('A' + #$F0#$9E#$80#$AA)),
    'A + Glagolitic combining upper bound');
  CheckEqual(Int64(2), Int64(StringDisplayWidth('A' + #$F0#$9E#$80#$AB)),
    'after Glagolitic combining range starts a new cluster');
end;

procedure TestIndicClusterWidth;
begin
  CheckEqual(Int64(1), Int64(StringDisplayWidth(#$E0#$AE#$95 + #$E0#$AE#$BE)),
    'Tamil KA + AA is one display cluster');
  CheckEqual(Int64(1), Int64(StringDisplayWidth(#$E0#$A4#$95 + #$E0#$A5#$8D + #$E0#$A4#$B7)),
    'Devanagari KA + VIRAMA + SSA is one display cluster');
  CheckEqual(Int64(1), Int64(StringDisplayWidth(#$E0#$AE#$95 + #$E0#$AF#$8D + #$E0#$AE#$95)),
    'Tamil KA + VIRAMA + KA is one display cluster');
end;

{ CodepointWidth - 补充的 wide 区间（Codex 审查后新增） }
procedure TestAddedWideRanges;
begin
  CheckEqual(Int64(2), Int64(CodepointWidth($4DC0)), 'Yijing hexagram start');
  CheckEqual(Int64(2), Int64(CodepointWidth($4DFF)), 'Yijing hexagram end');
  CheckEqual(Int64(2), Int64(CodepointWidth($2630)), 'trigram');
  CheckEqual(Int64(2), Int64(CodepointWidth($FE50)), 'small form variant');
  CheckEqual(Int64(2), Int64(CodepointWidth($FE6B)), 'small form variant end');
  CheckEqual(Int64(2), Int64(CodepointWidth($1D300)), 'Tai Xuan Jing');
  CheckEqual(Int64(2), Int64(CodepointWidth($1D360)), 'Counting Rod');
  CheckEqual(Int64(2), Int64(CodepointWidth($1F191)), 'squared CL');
end;

{ CodepointWidth - 补充的零宽区间 }
procedure TestAddedZeroWidth;
begin
  CheckEqual(Int64(0), Int64(CodepointWidth($0600)), 'Arabic number sign prepend');
  CheckEqual(Int64(0), Int64(CodepointWidth($05C7)), 'Hebrew qamats qatan');
  CheckEqual(Int64(0), Int64(CodepointWidth($06DF)), 'Arabic mark');
  CheckEqual(Int64(0), Int64(CodepointWidth($1160)), 'Hangul jungseong (conjoining)');
  CheckEqual(Int64(0), Int64(CodepointWidth($11FF)), 'Hangul jongseong end');
  CheckEqual(Int64(0), Int64(CodepointWidth($094D)), 'Devanagari virama');
  CheckEqual(Int64(0), Int64(CodepointWidth($1DC0)), 'combining supplement');
end;

procedure TestEmptyString;
begin
  CheckEqual(Int64(0), Int64(StringDisplayWidth('')), 'empty string = 0');
end;

procedure TestNilNonzeroSpan;
begin
  CheckEqual(Int64(0), Int64(StringDisplayWidth(nil, 1)), 'nil nonzero span = 0');
end;

procedure TestSimdBoundary16;
var S: AnsiString;
begin
  S := StringOfChar('A', 15);
  CheckEqual(Int64(15), Int64(StringDisplayWidth(S)), '15B ascii');
  S := StringOfChar('B', 16);
  CheckEqual(Int64(16), Int64(StringDisplayWidth(S)), '16B ascii (exact SSE2 boundary)');
  S := StringOfChar('C', 17);
  CheckEqual(Int64(17), Int64(StringDisplayWidth(S)), '17B ascii');
end;

procedure TestSimdBoundary32;
var S: AnsiString;
begin
  S := StringOfChar('X', 31);
  CheckEqual(Int64(31), Int64(StringDisplayWidth(S)), '31B ascii');
  S := StringOfChar('Y', 32);
  CheckEqual(Int64(32), Int64(StringDisplayWidth(S)), '32B ascii (exact AVX2 boundary)');
  S := StringOfChar('Z', 33);
  CheckEqual(Int64(33), Int64(StringDisplayWidth(S)), '33B ascii');
  S := StringOfChar('W', 128);
  CheckEqual(Int64(128), Int64(StringDisplayWidth(S)), '128B ascii (AVX2 threshold)');
end;

procedure TestLongAscii;
var S: AnsiString;
begin
  S := StringOfChar('a', 4096);
  CheckEqual(Int64(4096), Int64(StringDisplayWidth(S)), '4096B ascii');
end;

procedure TestNonAsciiAtEnd;
var S: AnsiString;
begin
  S := StringOfChar('x', 100) + #$E4#$B8#$96;
  CheckEqual(Int64(102), Int64(StringDisplayWidth(S)), '100 ascii + 1 wide CJK = 102');
end;

begin
  T := TTestRunner.Create('nextpas.core.text.width');
  T.Run('control chars width 0', @TestControlChars);
  T.Run('narrow chars width 1', @TestNarrowChars);
  T.Run('wide chars width 2', @TestWideChars);
  T.Run('emoji width 2', @TestEmojiWidth);
  T.Run('zero-width marks width 0', @TestZeroWidthMarks);
  T.Run('supplementary wide', @TestSupplementaryWide);
  T.Run('added wide ranges', @TestAddedWideRanges);
  T.Run('added zero-width ranges', @TestAddedZeroWidth);
  T.Run('ascii string fast path', @TestAsciiString);
  T.Run('ascii control string width', @TestAsciiControlStringWidth);
  T.Run('mixed cjk string', @TestMixedString);
  T.Run('emoji string', @TestEmojiString);
  T.Run('emoji cluster string', @TestEmojiClusterString);
  T.Run('zwj after non-emoji string', @TestZWJAfterNonEmojiString);
  T.Run('keycap emoji string', @TestKeycapEmojiString);
  T.Run('combining string', @TestCombiningString);
  T.Run('nko combining string', @TestNKoCombiningString);
  T.Run('width zero-width combining string', @TestWidthZeroWidthCombiningString);
  T.Run('Indic cluster width', @TestIndicClusterWidth);
  T.Run('empty string', @TestEmptyString);
  T.Run('nil nonzero span', @TestNilNonzeroSpan);
  T.Run('simd boundary 16B', @TestSimdBoundary16);
  T.Run('simd boundary 32B', @TestSimdBoundary32);
  T.Run('long ascii 4096B', @TestLongAscii);
  T.Run('non-ascii at end', @TestNonAsciiAtEnd);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
