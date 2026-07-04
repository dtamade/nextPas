program test_tui_text;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.text,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestSpanRaw;
var
  LSpan: TSpan;
begin
  LSpan := TSpan.Raw('hello');
  CheckEqual('hello', LSpan.Content, 'content');
  CheckEqual(Int64(5), Int64(LSpan.Width), 'ascii width 5');
  Check(not ColorIsSet(LSpan.Style.Fg), 'raw style default');
end;

procedure TestSpanStyled;
var
  LSpan: TSpan;
begin
  LSpan := TSpan.Styled('x', StyleDefault.WithFg(TUI_RED));
  Check(ColorEquals(LSpan.Style.Fg, TUI_RED), 'styled fg');
end;

procedure TestSpanCJKWidth;
var
  LSpan: TSpan;
begin
  { '中文' = 2 CJK chars, width 4 }
  LSpan := TSpan.Raw(#$E4#$B8#$AD#$E6#$96#$87);
  CheckEqual(Int64(4), Int64(LSpan.Width), 'CJK width 4');
end;

procedure TestSpanKeycapEmojiWidth;
var
  LSpan: TSpan;
begin
  LSpan := TSpan.Raw('1' + #$EF#$B8#$8F + #$E2#$83#$A3);
  CheckEqual(Int64(2), Int64(LSpan.Width), 'keycap emoji width 2');
end;

procedure TestLineFromString;
var
  LLine: TLine;
begin
  LLine := TLine.FromString('abc');
  CheckEqual(Int64(1), Int64(System.Length(LLine.Spans)), 'one span');
  CheckEqual(Int64(3), Int64(LLine.Width), 'line width 3');
end;

procedure TestLineFromSpans;
var
  LLine: TLine;
begin
  LLine := TLine.FromSpans([TSpan.Raw('ab'), TSpan.Raw('cde')]);
  CheckEqual(Int64(2), Int64(System.Length(LLine.Spans)), 'two spans');
  CheckEqual(Int64(5), Int64(LLine.Width), 'combined width 5');
end;

procedure TestLineAlignment;
var
  LLine: TLine;
begin
  LLine := TLine.FromString('x').WithAlignment(caCenter);
  Check(LLine.HasAlignment, 'has alignment');
  Check(LLine.Alignment = caCenter, 'center');
end;

procedure TestTextFromStringMultiline;
var
  LText: TText;
begin
  LText := TText.FromString('line1'#10'line2'#10'line3');
  CheckEqual(Int64(3), Int64(LText.Height), 'height 3');
  CheckEqual(Int64(5), Int64(LText.Width), 'max width 5');
end;

procedure TestTextCRLF;
var
  LText: TText;
begin
  LText := TText.FromString('a'#13#10'bb');
  CheckEqual(Int64(2), Int64(LText.Height), 'CRLF height 2');
  { 第一行应去掉 CR -> 'a' width 1 }
  CheckEqual(Int64(1), Int64(LText.Lines[0].Width), 'first line trimmed CR');
end;

procedure TestTextTrailingLF;
var
  LText: TText;
begin
  { 以 LF 结尾产生空尾行 }
  LText := TText.FromString('x'#10);
  CheckEqual(Int64(2), Int64(LText.Height), 'trailing LF -> 2 lines');
end;

procedure TestTextFromLines;
var
  LText: TText;
begin
  LText := TText.FromLines([TLine.FromString('aa'), TLine.FromString('bbbb')]);
  CheckEqual(Int64(2), Int64(LText.Height), 'height 2');
  CheckEqual(Int64(4), Int64(LText.Width), 'max width 4');
end;

procedure TestTextStyled;
var
  LText: TText;
begin
  LText := TText.Styled('hi', StyleDefault.WithModifier([mbBold]));
  Check(mbBold in LText.Style.AddMod, 'text bold style');
  CheckEqual(Int64(1), Int64(LText.Height), 'single line');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.text');
  T.Test('span raw', @TestSpanRaw);
  T.Test('span styled', @TestSpanStyled);
  T.Test('span cjk width', @TestSpanCJKWidth);
  T.Test('span keycap emoji width', @TestSpanKeycapEmojiWidth);
  T.Test('line from string', @TestLineFromString);
  T.Test('line from spans', @TestLineFromSpans);
  T.Test('line alignment', @TestLineAlignment);
  T.Test('text multiline', @TestTextFromStringMultiline);
  T.Test('text crlf', @TestTextCRLF);
  T.Test('text trailing lf', @TestTextTrailingLF);
  T.Test('text from lines', @TestTextFromLines);
  T.Test('text styled', @TestTextStyled);
  if not T.Run then Halt(1);
end.
