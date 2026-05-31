program test_tui_base;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.testing;

var
  T: TTestRunner;

{ TRect.Make 与访问器 }
procedure TestRectMake;
var
  LR: TRect;
begin
  LR := TRect.Make(2, 3, 10, 5);
  CheckEqual(Int64(2), Int64(LR.X), 'X');
  CheckEqual(Int64(3), Int64(LR.Y), 'Y');
  CheckEqual(Int64(10), Int64(LR.Width), 'Width');
  CheckEqual(Int64(5), Int64(LR.Height), 'Height');
  CheckEqual(Int64(2), Int64(LR.Left), 'Left');
  CheckEqual(Int64(12), Int64(LR.Right), 'Right exclusive');
  CheckEqual(Int64(3), Int64(LR.Top), 'Top');
  CheckEqual(Int64(8), Int64(LR.Bottom), 'Bottom exclusive');
  CheckEqual(Int64(50), Int64(LR.Area), 'Area');
end;

{ IsEmpty }
procedure TestRectEmpty;
begin
  Check(TRect.Make(0, 0, 0, 5).IsEmpty, 'zero width empty');
  Check(TRect.Make(0, 0, 5, 0).IsEmpty, 'zero height empty');
  Check(not TRect.Make(0, 0, 5, 5).IsEmpty, 'non-empty');
end;

{ Contains }
procedure TestRectContains;
var
  LR: TRect;
begin
  LR := TRect.Make(2, 2, 4, 4);  { covers x in [2,6), y in [2,6) }
  Check(LR.Contains(PositionMake(2, 2)), 'top-left inclusive');
  Check(LR.Contains(PositionMake(5, 5)), 'inside');
  Check(not LR.Contains(PositionMake(6, 5)), 'right exclusive');
  Check(not LR.Contains(PositionMake(5, 6)), 'bottom exclusive');
  Check(not LR.Contains(PositionMake(1, 2)), 'left of');
end;

{ Intersects }
procedure TestRectIntersects;
var
  LA, LB, LC: TRect;
begin
  LA := TRect.Make(0, 0, 5, 5);
  LB := TRect.Make(3, 3, 5, 5);
  LC := TRect.Make(5, 5, 5, 5);
  Check(LA.Intersects(LB), 'overlapping');
  Check(not LA.Intersects(LC), 'touching at corner not intersecting');
end;

{ Intersection }
procedure TestRectIntersection;
var
  LA, LB, LR: TRect;
begin
  LA := TRect.Make(0, 0, 6, 6);
  LB := TRect.Make(3, 3, 6, 6);
  LR := LA.Intersection(LB);
  Check(RectEquals(LR, TRect.Make(3, 3, 3, 3)), 'intersection rect');

  { No overlap -> empty }
  LR := LA.Intersection(TRect.Make(100, 100, 5, 5));
  Check(LR.IsEmpty, 'no overlap empty');
end;

{ Union }
procedure TestRectUnion;
var
  LA, LB, LR: TRect;
begin
  LA := TRect.Make(0, 0, 4, 4);
  LB := TRect.Make(2, 2, 4, 4);
  LR := LA.Union(LB);
  Check(RectEquals(LR, TRect.Make(0, 0, 6, 6)), 'union rect');

  { Empty self -> other }
  LR := TRect.Make(0, 0, 0, 0).Union(LB);
  Check(RectEquals(LR, LB), 'empty self returns other');
end;

{ Inner with margin }
procedure TestRectInner;
var
  LR, LInner: TRect;
begin
  LR := TRect.Make(0, 0, 10, 10);
  LInner := LR.Inner(MarginMake(2, 1));
  Check(RectEquals(LInner, TRect.Make(2, 1, 6, 8)), 'inner with margin');

  { Margin too big collapses width to 0 }
  LInner := LR.Inner(MarginMake(10, 1));
  Check(LInner.IsEmpty, 'over-margin collapses');
end;

{ helper equality + ctors }
procedure TestHelpers;
var
  LP: TPosition;
  LS: TSize;
  LM: TMargin;
begin
  LP := PositionMake(7, 9);
  Check(PositionEquals(LP, PositionMake(7, 9)), 'position equals');
  Check(not PositionEquals(LP, PositionMake(7, 8)), 'position not equals');
  LS := SizeMake(80, 24);
  CheckEqual(Int64(80), Int64(LS.Width), 'size width');
  CheckEqual(Int64(24), Int64(LS.Height), 'size height');
  LM := MarginMake(1, 2);
  CheckEqual(Int64(1), Int64(LM.Horizontal), 'margin h');
  CheckEqual(Int64(2), Int64(LM.Vertical), 'margin v');
end;

{ Direction enum }
procedure TestDirection;
var
  LD: TDirection;
begin
  LD := dirHorizontal;
  Check(LD = dirHorizontal, 'horizontal');
  LD := dirVertical;
  Check(LD = dirVertical, 'vertical');
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.base');
  T.Run('rect make and accessors', @TestRectMake);
  T.Run('rect empty', @TestRectEmpty);
  T.Run('rect contains', @TestRectContains);
  T.Run('rect intersects', @TestRectIntersects);
  T.Run('rect intersection', @TestRectIntersection);
  T.Run('rect union', @TestRectUnion);
  T.Run('rect inner margin', @TestRectInner);
  T.Run('helpers and ctors', @TestHelpers);
  T.Run('direction enum', @TestDirection);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
