program test_tui_layout;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.layout,
  nextpas.core.test;

var
  T: TTestSuite;

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

procedure TestLayoutDefault;
var
  LL: TLayout;
begin
  LL := TLayout.Default;
  Check(LL.Direction = dirVertical, 'default is vertical');
  CheckEqual(Int64(0), Int64(System.Length(LL.Constraints)), 'default no constraints');
end;

procedure TestLayoutHorizontal;
var
  LL: TLayout;
  LRects: TRectArray;
begin
  LL := TLayout.Horizontal([LengthConstraint(5), LengthConstraint(5)]);
  Check(LL.Direction = dirHorizontal, 'horizontal direction');
  LRects := LL.Split(TRect.Make(0, 0, 10, 5));
  CheckEqual(Int64(5), Int64(LRects[0].Width), 'slot 0 width 5');
  CheckEqual(Int64(5), Int64(LRects[1].Width), 'slot 1 width 5');
end;

procedure TestLayoutVertical;
var
  LL: TLayout;
  LRects: TRectArray;
begin
  LL := TLayout.Vertical([LengthConstraint(3), LengthConstraint(7)]);
  Check(LL.Direction = dirVertical, 'vertical direction');
  LRects := LL.Split(TRect.Make(0, 0, 10, 10));
  CheckEqual(Int64(3), Int64(LRects[0].Height), 'slot 0 height 3');
  CheckEqual(Int64(7), Int64(LRects[1].Height), 'slot 1 height 7');
end;

procedure TestLayoutWithDirection;
var
  LL: TLayout;
begin
  LL := TLayout.Default.WithDirection(dirHorizontal);
  Check(LL.Direction = dirHorizontal, 'direction changed');
end;

procedure TestRatioConstraint;
var
  LRects: TRectArray;
begin
  { Ratio 1:3 on width 90 -> floor(90*100/3%) = floor(33.3%) = 29 }
  LRects := HorizontalSplit(TRect.Make(0, 0, 90, 5),
    [RatioConstraint(1, 3), FillConstraint(1)]);
  Check(LRects[0].Width >= 29, 'ratio 1/3 ~ 29');
  Check(LRects[0].Width <= 30, 'ratio 1/3 ~ 30');
end;

procedure TestSingleConstraint;
var
  LRects: TRectArray;
begin
  LRects := VerticalSplit(TRect.Make(0, 0, 10, 10), [LengthConstraint(10)]);
  CheckEqual(Int64(1), Int64(System.Length(LRects)), 'single slot');
  CheckEqual(Int64(10), Int64(LRects[0].Height), 'full height');
end;

procedure TestMixedLengthFill;
var
  LRects: TRectArray;
begin
  LRects := VerticalSplit(TRect.Make(0, 0, 10, 20),
    [LengthConstraint(5), FillConstraint(1)]);
  CheckEqual(Int64(5), Int64(LRects[0].Height), 'length 5');
  CheckEqual(Int64(15), Int64(LRects[1].Height), 'fill gets remaining 15');
end;

procedure TestFillZeroWeight;
var
  LRects: TRectArray;
begin
  { FillConstraint(0) should default to weight 1 }
  LRects := HorizontalSplit(TRect.Make(0, 0, 10, 5), [FillConstraint(0)]);
  CheckEqual(Int64(10), Int64(LRects[0].Width), 'zero weight fill gets all');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.layout');
  T.Test('length split', @TestLengthSplit);
  T.Test('percentage split', @TestPercentageSplit);
  T.Test('min fills remaining', @TestMinFillsRemaining);
  T.Test('fill weights', @TestFillWeights);
  T.Test('max constraint', @TestMaxConstraint);
  T.Test('residual absorption', @TestResidualAbsorption);
  T.Test('adjacent no gap', @TestAdjacentNoGap);
  T.Test('horizontal keeps height', @TestHorizontalKeepsHeight);
  T.Test('empty constraints', @TestEmptyConstraints);
  T.Test('layout default', @TestLayoutDefault);
  T.Test('layout horizontal', @TestLayoutHorizontal);
  T.Test('layout vertical', @TestLayoutVertical);
  T.Test('layout with direction', @TestLayoutWithDirection);
  T.Test('ratio constraint', @TestRatioConstraint);
  T.Test('single constraint', @TestSingleConstraint);
  T.Test('mixed length fill', @TestMixedLengthFill);
  T.Test('fill zero weight', @TestFillZeroWeight);
  if not T.Run then Halt(1);
end.
