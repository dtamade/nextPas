program test_tui_layout_dsl;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.layout,
  nextpas.core.tui.layout.dsl,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestConstraintAliases;
begin
  Check(Fixed(5).Kind = ckLength, 'Fixed -> Length');
  CheckEqual(Int64(5), Int64(Fixed(5).Value), 'Fixed value');
  Check(Flex(2).Kind = ckFill, 'Flex -> Fill');
  CheckEqual(Int64(2), Int64(Flex(2).Value2), 'Flex weight');
  Check(Flex().Kind = ckFill, 'Flex default');
  CheckEqual(Int64(1), Int64(Flex().Value2), 'Flex default weight 1');
  Check(Pct(50).Kind = ckPercentage, 'Pct -> Percentage');
  Check(AtLeast(3).Kind = ckMin, 'AtLeast -> Min');
  Check(AtMost(7).Kind = ckMax, 'AtMost -> Max');
end;

procedure TestVSplit;
var
  LRects: TRectArray;
begin
  LRects := V(TRect.Make(0, 0, 10, 12), [Fixed(4), Flex()]);
  CheckEqual(Int64(2), Int64(System.Length(LRects)), 'two slots');
  CheckEqual(Int64(4), Int64(LRects[0].Height), 'fixed 4');
  CheckEqual(Int64(8), Int64(LRects[1].Height), 'flex 8');
end;

procedure TestHSplit;
var
  LRects: TRectArray;
begin
  LRects := H(TRect.Make(0, 0, 100, 5), [Pct(30), Flex()]);
  CheckEqual(Int64(30), Int64(LRects[0].Width), 'pct 30');
  CheckEqual(Int64(70), Int64(LRects[1].Width), 'flex 70');
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.layout.dsl');
  T.Run('constraint aliases', @TestConstraintAliases);
  T.Run('V split', @TestVSplit);
  T.Run('H split', @TestHSplit);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
