program test_tui_borders;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.borders,
  nextpas.core.testing;

var
  T: TTestRunner;

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
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.borders');
  T.Run('border sets', @TestBorderSets);
  T.Run('plain glyphs', @TestPlainGlyphs);
  T.Run('rounded glyphs', @TestRoundedGlyphs);
  T.Run('double glyphs', @TestDoubleGlyphs);
  T.Run('heavy glyphs', @TestHeavyGlyphs);
  T.Run('partial borders', @TestPartialBorders);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
