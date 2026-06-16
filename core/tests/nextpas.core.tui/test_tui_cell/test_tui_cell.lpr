program test_tui_cell;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestSize;
begin
  CheckEqual(Int64(40), Int64(SizeOf(TCell)), 'TCell 40 bytes');
  CheckEqual(Int64(24), Int64(SizeOf(TCellGlyph)), 'TCellGlyph 24 bytes');
end;

procedure TestEmpty;
var
  LC: TCell;
begin
  LC := CELL_EMPTY;
  CheckEqual(Int64(1), Int64(LC.Glyph.Len), 'empty glyph len 1');
  CheckEqual(Int64(32), Int64(LC.Glyph.Bytes[0]), 'empty glyph space');
  Check(LC.Fg.Kind = ckReset, 'empty fg reset');
  CheckEqual(Int64(1), Int64(LC.Width), 'empty width 1');
  Check(not LC.Skip, 'empty skip false');
end;

procedure TestReset;
var
  LC: TCell;
begin
  CellSetSymbolAscii(LC, 'X');  { dirty it first via reset semantics }
  CellReset(LC);
  Check(CellEquals(LC, CELL_EMPTY), 'reset equals empty');
end;

procedure TestSetSymbolAscii;
var
  LC: TCell;
begin
  CellReset(LC);
  CellSetSymbolAscii(LC, 'A');
  CheckEqual(Int64(1), Int64(LC.Glyph.Len), 'len 1');
  CheckEqual(Int64(Ord('A')), Int64(LC.Glyph.Bytes[0]), 'byte A');
  CheckEqual(Int64(1), Int64(LC.Width), 'width 1');
  CheckEqual('A', CellGlyphAsString(LC), 'glyph string A');
end;

procedure TestSetSymbolAsciiCanonicalizesReusedCell;
var
  LC, LExpected: TCell;
  LI: Integer;
begin
  CellReset(LC);
  CellReset(LExpected);

  for LI := 1 to TUI_CELL_GLYPH_BYTES - 1 do
    LC.Glyph.Bytes[LI] := $A5;
  LC.Skip := True;

  CellSetSymbolAscii(LC, 'A');
  CellSetSymbolAscii(LExpected, 'A');

  Check(not LC.Skip, 'ascii setter clears stale skip sentinel');
  Check(CellEquals(LC, LExpected), 'ascii setter clears stale glyph tail');
end;

procedure TestSetSymbolBytes;
var
  LC: TCell;
  LBuf: array[0..2] of Byte;
begin
  CellReset(LC);
  { CJK '中' = E4 B8 AD, width 2 }
  LBuf[0] := $E4; LBuf[1] := $B8; LBuf[2] := $AD;
  CellSetSymbolBytes(LC, LBuf[0], 3, 2);
  CheckEqual(Int64(3), Int64(LC.Glyph.Len), 'len 3');
  CheckEqual(Int64(2), Int64(LC.Width), 'width 2');
  CheckEqual(#$E4#$B8#$AD, CellGlyphAsString(LC), 'glyph string CJK');
end;

procedure TestSetSymbolBytesCanonicalizesReusedCell;
var
  LC, LExpected: TCell;
  LBuf: array[0..2] of Byte;
  LI: Integer;
begin
  CellReset(LC);
  CellReset(LExpected);

  for LI := 3 to TUI_CELL_GLYPH_BYTES - 1 do
    LC.Glyph.Bytes[LI] := $A5;
  LC.Skip := True;

  LBuf[0] := $E4; LBuf[1] := $B8; LBuf[2] := $AD;
  CellSetSymbolBytes(LC, LBuf[0], 3, 2);
  CellSetSymbolBytes(LExpected, LBuf[0], 3, 2);

  Check(not LC.Skip, 'bytes setter clears stale skip sentinel');
  Check(CellEquals(LC, LExpected), 'bytes setter clears stale glyph tail');
end;

procedure TestSetSymbolTruncate;
var
  LC: TCell;
  LBuf: array[0..30] of Byte;
  I: Integer;
begin
  CellReset(LC);
  for I := 0 to 30 do LBuf[I] := Byte(Ord('a') + (I mod 26));
  CellSetSymbolBytes(LC, LBuf[0], 31, 1);
  CheckEqual(Int64(23), Int64(LC.Glyph.Len), 'truncated to 23');
end;

procedure TestSetSymbolWidthZeroCoerced;
var
  LC: TCell;
  LBuf: array[0..0] of Byte;
begin
  CellReset(LC);
  LBuf[0] := Ord('z');
  CellSetSymbolBytes(LC, LBuf[0], 1, 0);  { width 0 -> coerced to 1 }
  CheckEqual(Int64(1), Int64(LC.Width), 'width 0 coerced to 1');
end;

procedure TestApplyStyle;
var
  LC: TCell;
begin
  CellReset(LC);
  CellApplyStyle(LC, TStyle.Default.WithFg(TUI_RED).WithModifier([mbBold]));
  Check(ColorEquals(LC.Fg, TUI_RED), 'fg applied');
  Check(mbBold in LC.Modifier, 'bold applied');
  { unset fields don't overwrite }
  Check(LC.Bg.Kind = ckReset, 'bg unchanged (style bg unset)');
end;

procedure TestEquals;
var
  LA, LB: TCell;
begin
  CellReset(LA);
  CellReset(LB);
  Check(CellEquals(LA, LB), 'two empties equal');
  CellSetSymbolAscii(LA, 'A');
  CellSetSymbolAscii(LB, 'A');
  Check(CellEquals(LA, LB), 'same symbol equal');
  CellSetSymbolAscii(LB, 'B');
  Check(not CellEquals(LA, LB), 'diff symbol unequal');
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.cell');
  T.Run('size 40 bytes', @TestSize);
  T.Run('empty', @TestEmpty);
  T.Run('reset', @TestReset);
  T.Run('set symbol ascii', @TestSetSymbolAscii);
  T.Run('set symbol ascii canonicalizes reused cell', @TestSetSymbolAsciiCanonicalizesReusedCell);
  T.Run('set symbol bytes', @TestSetSymbolBytes);
  T.Run('set symbol bytes canonicalizes reused cell', @TestSetSymbolBytesCanonicalizesReusedCell);
  T.Run('set symbol truncate', @TestSetSymbolTruncate);
  T.Run('width zero coerced', @TestSetSymbolWidthZeroCoerced);
  T.Run('apply style', @TestApplyStyle);
  T.Run('equals', @TestEquals);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
