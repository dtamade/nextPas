program test_tui_layout_dsl;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.layout,
  nextpas.core.tui.layout.dsl,
  nextpas.core.test;

var
  T: TTestSuite;

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

procedure TestAtLeastAtMost;
var
  LRects: TRectArray;
begin
  { V with AtLeast(10) and Flex in 10x20 area }
  LRects := V(TRect.Make(0, 0, 10, 20), [AtLeast(10), Flex()]);
  Check(LRects[0].Height >= 10, 'AtLeast 10');
  Check(LRects[1].Height >= 0, 'Flex remaining');
  CheckEqual(Int64(20), Int64(LRects[0].Height + LRects[1].Height), 'total height');
end;

procedure TestEvenFunction;
var
  LRects: TRectArray;
  LConstraints: TConstraints;
begin
  LConstraints := Even(3);
  CheckEqual(Int64(3), Int64(Length(LConstraints)), 'Even(3) gives 3 constraints');
  LRects := V(TRect.Make(0, 0, 10, 30), LConstraints);
  CheckEqual(Int64(10), Int64(LRects[0].Height), 'each slot 10');
  CheckEqual(Int64(10), Int64(LRects[1].Height), 'each slot 10');
  CheckEqual(Int64(10), Int64(LRects[2].Height), 'each slot 10');
end;

procedure TestNestedHSplit;
var
  LOuter, LInner: TRectArray;
begin
  { H split then V split each half }
  LOuter := H(TRect.Make(0, 0, 100, 10), [Flex(), Flex()]);
  CheckEqual(Int64(2), Int64(Length(LOuter)), 'two halves');
  LInner := V(LOuter[0], [Flex(), Flex()]);
  CheckEqual(Int64(2), Int64(Length(LInner)), 'each half split vertically');
  CheckEqual(Int64(50), Int64(LInner[0].Width), 'inner width 50');
  CheckEqual(Int64(5), Int64(LInner[0].Height), 'inner height 5');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.layout.dsl');
  T.Test('constraint aliases', @TestConstraintAliases);
  T.Test('V split', @TestVSplit);
  T.Test('H split', @TestHSplit);
  T.Test('AtLeast AtMost', @TestAtLeastAtMost);
  T.Test('Even function', @TestEvenFunction);
  T.Test('nested H then V split', @TestNestedHSplit);
  if not T.Run then Halt(1);
end.
