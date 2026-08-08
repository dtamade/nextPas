program test_tui_ansi_parse;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.tui.style,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.ansi.parse,
  nextpas.core.test;

var
  T: TTestSuite;

function PLines(const ARaw: string): TAnsiLineArray;
begin
  Result := ParseAnsiLines(ARaw, TStyle.Default, TAnsiParseOptions.Create);
end;

procedure TestPlainText;
var
  L: TAnsiLineArray;
begin
  L := PLines('hello');
  CheckEqual(1, Length(L), 'one line');
  CheckEqual('hello', L[0].Chars, 'plain text');
  CheckEqual(5, L[0].ColumnCount, 'column count');
end;

procedure TestStripsSgrToPlainText;
var
  L: TAnsiLineArray;
begin
  L := PLines(#27'[31mred'#27'[0m');
  CheckEqual(1, Length(L), 'one line');
  CheckEqual('red', L[0].Chars, 'sgr stripped');
end;

procedure TestNewlineSplitsLines;
var
  L: TAnsiLineArray;
begin
  L := PLines('a'#10'b');
  CheckEqual(2, Length(L), 'two lines');
  CheckEqual('a', L[0].Chars, 'first');
  CheckEqual('b', L[1].Chars, 'second');
end;

procedure TestTrailingNewlineAddsNoBlankLine;
var
  L: TAnsiLineArray;
begin
  L := PLines('ab'#10);
  CheckEqual(1, Length(L), 'no trailing blank line');
  CheckEqual('ab', L[0].Chars, 'content');
end;

procedure TestCrLf;
var
  L: TAnsiLineArray;
begin
  L := PLines('a'#13#10'b');
  CheckEqual(2, Length(L), 'crlf splits');
  CheckEqual('a', L[0].Chars, 'first');
end;

procedure TestCarriageReturnOverwritesInPlace;
var
  L: TAnsiLineArray;
begin
  L := PLines('abcdef'#13'XY');
  CheckEqual(1, Length(L), 'one line');
  CheckEqual('XYcdef', L[0].Chars, 'cr overwrites start');
end;

procedure TestProgressBarCollapsesToFinalState;
var
  L: TAnsiLineArray;
begin
  L := PLines('10%'#13'20%'#13'100%');
  CheckEqual(1, Length(L), 'single line');
  CheckEqual('100%', L[0].Chars, 'final state only');
end;

procedure TestCursorUpThenCarriageReturnAndErase;
var
  L: TAnsiLineArray;
begin
  L := PLines('line1'#10'line2'#27'[1A'#13'X'#27'[K');
  CheckEqual(2, Length(L), 'two lines');
  CheckEqual('X', L[0].Chars, 'cursor up + overwrite + erase');
  CheckEqual('line2', L[1].Chars, 'second line intact');
end;

procedure TestCursorUpWritesOver;
var
  L: TAnsiLineArray;
begin
  L := PLines('aaaa'#10'bbbb'#27'[1A'#13'X');
  CheckEqual(2, Length(L), 'two lines');
  CheckEqual('Xaaa', L[0].Chars, 'cursor up overwrite');
end;

procedure TestTabAdvancesToNextStop;
var
  L: TAnsiLineArray;
begin
  L := PLines('a'#9'b');
  CheckEqual(1, Length(L), 'one line');
  CheckEqual('a       b', L[0].Chars, 'tab to col 8');
  CheckEqual(9, L[0].ColumnCount, 'tab width');
end;

procedure TestBackspace;
var
  L: TAnsiLineArray;
begin
  L := PLines('abc'#8'X');
  CheckEqual('abX', L[0].Chars, 'bs moves col back');
end;

procedure TestEraseLine0ToCol;
var
  L: TAnsiLineArray;
begin
  L := PLines('abcdef'#27'[3G'#27'[K');
  CheckEqual(1, Length(L), 'one line');
  CheckEqual('ab', L[0].Chars, 'erase from col 3');
end;

procedure TestEraseDisplay2;
var
  L: TAnsiLineArray;
begin
  L := PLines('a'#10'b'#10'c'#27'[1A'#27'[2J'#10'z');
  CheckEqual(2, Length(L), 'rows after clear + newline');
  CheckEqual('z', L[1].Chars, 'last row');
end;

procedure TestMalformedEscapeDoesNotPanic;
var
  L: TAnsiLineArray;
begin
  L := PLines('ok'#27'[3;1m'#27'[x'#27);
  CheckEqual(1, Length(L), 'survives malformed');
  CheckEqual('ok', L[0].Chars, 'content preserved');
end;

procedure TestSgrSplitsIntoStyledSegments;
var
  L: TAnsiLineArray;
  C: TColor;
begin
  L := PLines(#27'[31mred'#27'[0mplain');
  CheckEqual(1, Length(L), 'one line');
  CheckEqual(2, Length(L[0].Segments), 'two segments');
  CheckEqual(0, L[0].Segments[0].StartCol, 'seg0 start');
  CheckEqual(3, L[0].Segments[0].Len, 'seg0 len');
  CheckEqual(3, L[0].Segments[1].StartCol, 'seg1 start');
  CheckEqual(5, L[0].Segments[1].Len, 'seg1 len');
  C := L[0].Segments[0].Style.Fg;
  CheckTrue(C.Kind = ckIndexed, 'fg indexed');
  CheckEqual(1, Integer(C.Index), 'fg = ansi red');
end;

procedure TestSgr256Color;
var
  L: TAnsiLineArray;
  C: TColor;
begin
  L := PLines(#27'[38;5;196mX'#27'[0m');
  C := L[0].Segments[0].Style.Fg;
  CheckTrue(C.Kind = ckIndexed, '256 fg indexed');
  CheckEqual(196, Integer(C.Index), '256 idx');
end;

procedure TestSgrRgb;
var
  L: TAnsiLineArray;
  C: TColor;
begin
  L := PLines(#27'[38;2;10;20;30mX'#27'[0m');
  C := L[0].Segments[0].Style.Fg;
  CheckTrue(C.Kind = ckRgb, 'rgb fg');
  CheckEqual(10, Integer(C.R), 'r');
  CheckEqual(20, Integer(C.G), 'g');
  CheckEqual(30, Integer(C.B), 'b');
end;

procedure TestSgrColonSubparams;
var
  L: TAnsiLineArray;
  C: TColor;
begin
  L := PLines(#27'[38:5:196mX'#27'[0m');
  C := L[0].Segments[0].Style.Fg;
  CheckTrue(C.Kind = ckIndexed, 'colon 256 fg');
  CheckEqual(196, Integer(C.Index), 'colon idx');
end;

procedure TestBrightColors;
var
  L: TAnsiLineArray;
  C: TColor;
begin
  L := PLines(#27'[91mX'#27'[0m');
  C := L[0].Segments[0].Style.Fg;
  CheckTrue(C.Kind = ckIndexed, 'bright fg');
  CheckEqual(8 + 1, Integer(C.Index), 'bright red = idx 9');
end;

procedure TestModifier;
var
  L: TAnsiLineArray;
  M: TModifier;
begin
  L := PLines(#27'[1;4mX'#27'[0m');
  M := L[0].Segments[0].Style.AddMod;
  CheckTrue(mbBold in M, 'bold');
  CheckTrue(mbUnderlined in M, 'underlined');
end;

procedure TestModifierOff;
var
  L: TAnsiLineArray;
begin
  L := PLines(#27'[1mB'#27'[22mN');
  CheckTrue(mbBold in L[0].Segments[0].Style.AddMod, 'bold on');
  CheckTrue(not (mbBold in L[0].Segments[1].Style.AddMod), 'bold off');
end;

procedure TestStyleResetToBase;
var
  L: TAnsiLineArray;
begin
  L := PLines(#27'[31mred'#27'[0mplain');
  CheckTrue(L[0].Segments[1].Style.Fg.Kind = ckUnset, 'reset -> base fg');
end;

procedure TestEmptyInputYieldsNoLines;
var
  L: TAnsiLineArray;
begin
  L := PLines('');
  CheckEqual(0, Length(L), 'no lines');
end;

procedure TestTrailingSpacesTrimmed;
var
  L: TAnsiLineArray;
begin
  L := PLines('a  b   ');
  CheckEqual(1, Length(L), 'one line');
  CheckEqual('a  b', L[0].Chars, 'trailing base-space trimmed');
end;

procedure TestStyledTrailingSpaceKept;
var
  L: TAnsiLineArray;
begin
  L := PLines('a'#27'[31m b'#27'[0m');
  CheckEqual(1, Length(L), 'one line');
  CheckEqual('a b', L[0].Chars, 'styled space kept');
end;

procedure TestOscIgnored;
var
  L: TAnsiLineArray;
begin
  L := PLines('x'#27']0;title'#7'y');
  CheckEqual(1, Length(L), 'one line');
  CheckEqual('xy', L[0].Chars, 'osc stripped');
end;

procedure TestWideCharTwoColumns;
var
  L: TAnsiLineArray;
begin
  L := PLines('a' + #$E4#$B8#$AD + 'b');   { 'a中b' UTF-8 }
  CheckEqual(1, Length(L), 'one line');
  CheckEqual('a' + #$E4#$B8#$AD + 'b', L[0].Chars, 'wide char kept');
  CheckEqual(4, L[0].ColumnCount, 'wide char = 2 cols');
end;

procedure TestMaxColumnsClamp;
var
  L: TAnsiLineArray;
  O: TAnsiParseOptions;
begin
  O := TAnsiParseOptions.Create;
  O.MaxColumns := 4;
  L := ParseAnsiLines('abcdef', TStyle.Default, O);
  CheckEqual(1, Length(L), 'one line');
  CheckEqual('abcd', L[0].Chars, 'clamped at 4 cols');
end;

procedure TestMaxRowsClamp;
var
  L: TAnsiLineArray;
  O: TAnsiParseOptions;
  I: Integer;
  S: string;
begin
  O := TAnsiParseOptions.Create;
  O.MaxRows := 3;
  S := '';
  for I := 1 to 10 do
    S := S + IntToStr(I) + #10;
  L := ParseAnsiLines(S, TStyle.Default, O);
  CheckEqual(3, Length(L), 'clamped rows');
end;

procedure TestOverwriteThenErase;
var
  L: TAnsiLineArray;
begin
  L := PLines('hello world'#13'hi'#27'[2K'#13'done');
  CheckEqual(1, Length(L), 'one line');
  CheckEqual('done', L[0].Chars, 'erase all then rewrite');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.ansi.parse');
  T.Test('plain text', @TestPlainText);
  T.Test('sgr stripped to plain', @TestStripsSgrToPlainText);
  T.Test('newline splits lines', @TestNewlineSplitsLines);
  T.Test('trailing newline no blank line', @TestTrailingNewlineAddsNoBlankLine);
  T.Test('crlf', @TestCrLf);
  T.Test('carriage return overwrites', @TestCarriageReturnOverwritesInPlace);
  T.Test('progress bar collapses', @TestProgressBarCollapsesToFinalState);
  T.Test('cursor up + erase', @TestCursorUpThenCarriageReturnAndErase);
  T.Test('cursor up writes over', @TestCursorUpWritesOver);
  T.Test('tab stop', @TestTabAdvancesToNextStop);
  T.Test('backspace', @TestBackspace);
  T.Test('erase line 0', @TestEraseLine0ToCol);
  T.Test('erase display 2', @TestEraseDisplay2);
  T.Test('malformed escape safe', @TestMalformedEscapeDoesNotPanic);
  T.Test('sgr styled segments', @TestSgrSplitsIntoStyledSegments);
  T.Test('sgr 256 color', @TestSgr256Color);
  T.Test('sgr rgb', @TestSgrRgb);
  T.Test('sgr colon subparams', @TestSgrColonSubparams);
  T.Test('bright colors', @TestBrightColors);
  T.Test('modifier on', @TestModifier);
  T.Test('modifier off', @TestModifierOff);
  T.Test('style reset to base', @TestStyleResetToBase);
  T.Test('empty input', @TestEmptyInputYieldsNoLines);
  T.Test('trailing spaces trimmed', @TestTrailingSpacesTrimmed);
  T.Test('styled trailing space kept', @TestStyledTrailingSpaceKept);
  T.Test('osc ignored', @TestOscIgnored);
  T.Test('wide char 2 cols', @TestWideCharTwoColumns);
  T.Test('max columns clamp', @TestMaxColumnsClamp);
  T.Test('max rows clamp', @TestMaxRowsClamp);
  T.Test('overwrite then erase', @TestOverwriteThenErase);
  if not T.Run then
    Halt(1);
end.
