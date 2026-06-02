program test_tui_layout;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.layout,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestLengthSplit;
var
  LRects: TRectArray;
begin
  { 垂直切分 height 10：Length 3 + Length 7 }
  LRects := VerticalSplit(TRect.Make(0, 0, 20, 10),
    [LengthConstraint(3), LengthConstraint(7)]);
  CheckEqual(Int64(2), Int64(System.Length(LRects)), 'two slots');
  CheckEqual(Int64(3), Int64(LRects[0].Height), 'slot 0 height 3');
  CheckEqual(Int64(7), Int64(LRects[1].Height), 'slot 1 height 7');
  CheckEqual(Int64(0), Int64(LRects[0].Y), 'slot 0 y 0');
  CheckEqual(Int64(3), Int64(LRects[1].Y), 'slot 1 y 3');
end;

procedure TestPercentageSplit;
var
  LRects: TRectArray;
begin
  { 水平 width 100：50% + 50% }
  LRects := HorizontalSplit(TRect.Make(0, 0, 100, 5),
    [PercentageConstraint(50), PercentageConstraint(50)]);
  CheckEqual(Int64(50), Int64(LRects[0].Width), 'left 50');
  CheckEqual(Int64(50), Int64(LRects[1].Width), 'right 50');
end;

procedure TestMinFillsRemaining;
var
  LRects: TRectArray;
begin
  { Length 3 + Min 0：Min 吸收剩余 }
  LRects := VerticalSplit(TRect.Make(0, 0, 20, 10),
    [LengthConstraint(3), MinConstraint(0)]);
  CheckEqual(Int64(3), Int64(LRects[0].Height), 'length 3');
  CheckEqual(Int64(7), Int64(LRects[1].Height), 'min takes remaining 7');
end;

procedure TestFillWeights;
var
  LRects: TRectArray;
begin
  { Fill 1 + Fill 2：1:2 分 30 -> 10 + 20 }
  LRects := HorizontalSplit(TRect.Make(0, 0, 30, 5),
    [FillConstraint(1), FillConstraint(2)]);
  CheckEqual(Int64(10), Int64(LRects[0].Width), 'fill weight 1 -> 10');
  CheckEqual(Int64(20), Int64(LRects[1].Width), 'fill weight 2 -> 20');
end;

procedure TestMaxConstraint;
var
  LRects: TRectArray;
begin
  { Max 5 + Min 0：Max 取至多 5，Min 取剩余 }
  LRects := HorizontalSplit(TRect.Make(0, 0, 20, 5),
    [MaxConstraint(5), MinConstraint(0)]);
  CheckEqual(Int64(5), Int64(LRects[0].Width), 'max capped at 5');
  CheckEqual(Int64(15), Int64(LRects[1].Width), 'min takes 15');
end;

procedure TestResidualAbsorption;
var
  LSizes: TIntArray;
begin
  { 三个 Length 之和小于 total，残差吸收进最后槽 }
  LSizes := ComputeSlotSizes(10, [LengthConstraint(2), LengthConstraint(3)]);
  CheckEqual(Int64(2), Int64(LSizes[0]), 'slot 0 = 2');
  { 残差 5 吸收进最后非 Max 槽 }
  CheckEqual(Int64(8), Int64(LSizes[1]), 'slot 1 = 3 + residual 5');
end;

procedure TestAdjacentNoGap;
var
  LRects: TRectArray;
begin
  { 相邻 rect 共享边无间隙：slot[i].Bottom = slot[i+1].Top }
  LRects := VerticalSplit(TRect.Make(0, 0, 10, 12),
    [LengthConstraint(4), LengthConstraint(4), MinConstraint(0)]);
  CheckEqual(Int64(LRects[0].Bottom), Int64(LRects[1].Top), 'no gap 0-1');
  CheckEqual(Int64(LRects[1].Bottom), Int64(LRects[2].Top), 'no gap 1-2');
end;

procedure TestHorizontalKeepsHeight;
var
  LRects: TRectArray;
begin
  LRects := HorizontalSplit(TRect.Make(2, 3, 20, 8),
    [PercentageConstraint(50), PercentageConstraint(50)]);
  CheckEqual(Int64(8), Int64(LRects[0].Height), 'keeps area height');
  CheckEqual(Int64(3), Int64(LRects[0].Y), 'keeps area y');
end;

procedure TestEmptyConstraints;
var
  LRects: TRectArray;
begin
  LRects := VerticalSplit(TRect.Make(0, 0, 10, 10), []);
  CheckEqual(Int64(0), Int64(System.Length(LRects)), 'empty constraints empty result');
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.layout');
  T.Run('length split', @TestLengthSplit);
  T.Run('percentage split', @TestPercentageSplit);
  T.Run('min fills remaining', @TestMinFillsRemaining);
  T.Run('fill weights', @TestFillWeights);
  T.Run('max constraint', @TestMaxConstraint);
  T.Run('residual absorption', @TestResidualAbsorption);
  T.Run('adjacent no gap', @TestAdjacentNoGap);
  T.Run('horizontal keeps height', @TestHorizontalKeepsHeight);
  T.Run('empty constraints', @TestEmptyConstraints);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
