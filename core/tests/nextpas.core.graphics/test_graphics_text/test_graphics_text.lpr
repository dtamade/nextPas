program test_graphics_text;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.graphics.text,
  nextpas.core.graphics.base;

var T: TTestSuite;

procedure TestEmpty;
var R: TGlyphRun;
begin
  R.Glyphs := nil; R.Positions := nil; R.Scale := 1;
  Check(R.IsEmpty, 'empty');
  R.Glyphs := [65];
  Check(not R.IsEmpty, 'not empty');
end;

procedure TestLayout;
var L: TTextLayout;
begin
  L := LayoutText('ABC', 10, 1.5);
  CheckEqual(3, Length(L.GlyphRun.Glyphs), '3 glyphs');
  Check(Abs(L.GlyphRun.Scale - 1.5) < 1e-6, 'scale');
  Check(L.Bounds.W > 0, 'bounds w');
  Check(L.GlyphRun.Positions[1].X > L.GlyphRun.Positions[0].X, 'advance');
  // zero-copy: Positions array is shared via record, no extra alloc in check
end;

procedure TestWrapped;
var L: TTextLayout;
begin
  L := LayoutTextWrapped('Hello', 12, 2, 50);
  Check(Abs(L.Scale - 2) < 1e-6, 'scale');
  Check(Abs(L.MaxWidth - 50) < 1e-6, 'max width');
  Check(not L.GlyphRun.IsEmpty, 'not empty');
end;

begin
  T := TTestSuite.Create('nextpas.core.graphics.text');
  T.Test('empty', @TestEmpty);
  T.Test('layout', @TestLayout);
  T.Test('wrapped', @TestWrapped);
  if not T.Run then Halt(1);
end.
