program test_tui_borders;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.borders,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestBorderSets;
begin
  Check(BORDERS_NONE = [], 'none empty');
  Check(BORDERS_ALL = [bsTop, bsRight, bsBottom, bsLeft], 'all four sides');
  Check(bsTop in BORDERS_ALL, 'top in all');
end;

procedure TestPlainGlyphs;
begin
  CheckEqual(#$E2#$94#$80, BorderSetPlain.Horizontal, 'plain horizontal ─');
  CheckEqual(#$E2#$94#$82, BorderSetPlain.Vertical, 'plain vertical │');
  CheckEqual(#$E2#$94#$8C, BorderSetPlain.TopLeft, 'plain TL ┌');
  CheckEqual(#$E2#$94#$98, BorderSetPlain.BottomRight, 'plain BR ┘');
end;

procedure TestRoundedGlyphs;
begin
  CheckEqual(#$E2#$95#$AD, BorderSetRounded.TopLeft, 'rounded TL ╭');
  CheckEqual(#$E2#$95#$AF, BorderSetRounded.BottomRight, 'rounded BR ╯');
  { rounded 横竖同 plain }
  CheckEqual(BorderSetPlain.Horizontal, BorderSetRounded.Horizontal, 'rounded H = plain H');
end;

procedure TestDoubleGlyphs;
begin
  CheckEqual(#$E2#$95#$90, BorderSetDouble.Horizontal, 'double H ═');
  CheckEqual(#$E2#$95#$94, BorderSetDouble.TopLeft, 'double TL ╔');
end;

procedure TestHeavyGlyphs;
begin
  CheckEqual(#$E2#$94#$81, BorderSetHeavy.Horizontal, 'heavy H ━');
  CheckEqual(#$E2#$94#$8F, BorderSetHeavy.TopLeft, 'heavy TL ┏');
end;

procedure TestPartialBorders;
var
  LB: TBorders;
begin
  LB := [bsTop, bsBottom];
  Check(bsTop in LB, 'top in');
  Check(bsBottom in LB, 'bottom in');
  Check(not (bsLeft in LB), 'left not in');
  Check(not (bsRight in LB), 'right not in');
end;

procedure TestAllBorderGlyphs;
begin
  { Plain: all 8 glyphs }
  CheckEqual(#$E2#$94#$90, BorderSetPlain.TopRight, 'plain TR ┐');
  CheckEqual(#$E2#$94#$94, BorderSetPlain.BottomLeft, 'plain BL └');
  { Rounded }
  CheckEqual(#$E2#$95#$AE, BorderSetRounded.TopRight, 'rounded TR ╮');
  CheckEqual(#$E2#$95#$B0, BorderSetRounded.BottomLeft, 'rounded BL ╰');
  { Double }
  CheckEqual(#$E2#$95#$97, BorderSetDouble.TopRight, 'double TR ╗');
  CheckEqual(#$E2#$95#$9A, BorderSetDouble.BottomLeft, 'double BL ╚');
  CheckEqual(#$E2#$95#$91, BorderSetDouble.Vertical, 'double V ║');
  { Heavy }
  CheckEqual(#$E2#$94#$93, BorderSetHeavy.TopRight, 'heavy TR ┓');
  CheckEqual(#$E2#$94#$97, BorderSetHeavy.BottomLeft, 'heavy BL ┗');
  CheckEqual(#$E2#$94#$83, BorderSetHeavy.Vertical, 'heavy V ┃');
end;

procedure TestSingleSideBorders;
var
  LB: TBorders;
begin
  LB := [bsTop];
  Check(bsTop in LB, 'only top');
  Check(not (bsBottom in LB), 'no bottom');
  Check(not (bsLeft in LB), 'no left');
  Check(not (bsRight in LB), 'no right');
end;

procedure TestBorderSetType;
begin
  { BorderSet should be a record with all glyph fields }
  Check(BorderSetPlain.Horizontal <> '', 'plain H not empty');
  Check(BorderSetPlain.Vertical <> '', 'plain V not empty');
  Check(BorderSetRounded.Horizontal <> '', 'rounded H not empty');
  Check(BorderSetDouble.Horizontal <> '', 'double H not empty');
  Check(BorderSetHeavy.Horizontal <> '', 'heavy H not empty');
end;


procedure TestDashedBorderSet;
begin
  Check(BorderSetDashed.Horizontal <> '', 'dashed H');
  Check(BorderSetDashed.Vertical <> '', 'dashed V');
end;

procedure TestBorderSetsDiffer;
begin
  Check(BorderSetPlain.TopLeft <> BorderSetDouble.TopLeft, 'plain != double TL');
  Check(BorderSetRounded.TopLeft <> BorderSetHeavy.TopLeft, 'rounded != heavy TL');
end;

procedure TestAllCornersPresent;
var
  S: TBorderSet;
begin
  S := BorderSetPlain;
  Check(S.TopLeft <> '', 'TL');
  Check(S.TopRight <> '', 'TR');
  Check(S.BottomLeft <> '', 'BL');
  Check(S.BottomRight <> '', 'BR');
end;


begin
  T := TTestSuite.Create('nextpas.core.tui.borders');
  T.Test('border sets', @TestBorderSets);
  T.Test('plain glyphs', @TestPlainGlyphs);
  T.Test('rounded glyphs', @TestRoundedGlyphs);
  T.Test('double glyphs', @TestDoubleGlyphs);
  T.Test('heavy glyphs', @TestHeavyGlyphs);
  T.Test('partial borders', @TestPartialBorders);
  T.Test('all border glyphs', @TestAllBorderGlyphs);
  T.Test('single side borders', @TestSingleSideBorders);
  T.Test('border set types', @TestBorderSetType);
    T.Test('dashed border set', @TestDashedBorderSet);
  T.Test('border sets differ', @TestBorderSetsDiffer);
  T.Test('all corners present', @TestAllCornersPresent);
if not T.Run then Halt(1);
end.
