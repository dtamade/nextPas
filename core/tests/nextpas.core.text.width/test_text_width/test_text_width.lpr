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
end;

procedure TestEmojiClusterString;
var
  LFamily: AnsiString;
  LSkinTone: AnsiString;
begin
  LFamily := #$F0#$9F#$91#$A8 + #$E2#$80#$8D +
             #$F0#$9F#$91#$A9 + #$E2#$80#$8D +
             #$F0#$9F#$91#$A7 + #$E2#$80#$8D +
             #$F0#$9F#$91#$A6;
  LSkinTone := #$F0#$9F#$91#$8D + #$F0#$9F#$8F#$BD;
  CheckEqual(Int64(2), Int64(StringDisplayWidth(LFamily)), 'family emoji cluster width');
  CheckEqual(Int64(2), Int64(StringDisplayWidth(LSkinTone)), 'skin tone emoji cluster width');
  CheckEqual(Int64(5), Int64(StringDisplayWidth('a' + LFamily + LSkinTone)), 'mixed emoji clusters width');
end;

{ StringDisplayWidth - 组合标记不计宽 }
procedure TestCombiningString;
begin
  { 'e' + combining acute (CC 81 = U+0301) = 1 + 0 = 1 }
  CheckEqual(Int64(1), Int64(StringDisplayWidth('e' + #$CC#$81)), 'e + combining');
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
  T.Run('mixed cjk string', @TestMixedString);
  T.Run('emoji string', @TestEmojiString);
  T.Run('emoji cluster string', @TestEmojiClusterString);
  T.Run('combining string', @TestCombiningString);
  T.Run('empty string', @TestEmptyString);
  T.Run('simd boundary 16B', @TestSimdBoundary16);
  T.Run('simd boundary 32B', @TestSimdBoundary32);
  T.Run('long ascii 4096B', @TestLongAscii);
  T.Run('non-ascii at end', @TestNonAsciiAtEnd);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
