program test_tui_widget_scrollbar;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.scrollbar,
  nextpas.core.test;

var T: TTestSuite;

{ === IScrollbar Builders === }

procedure TestScrollbarNew;
var LS: IScrollbar;
begin
  LS := TScrollbar.New;
  Check(LS <> nil, 'TScrollbar.New returns non-nil');
end;

procedure TestScrollbarWithTotal;
var LS: IScrollbar;
begin
  LS := TScrollbar.New.WithTotal(100);
  Check(LS <> nil, 'WithTotal returns non-nil');
end;

procedure TestScrollbarWithVisible;
var LS: IScrollbar;
begin
  LS := TScrollbar.New.WithTotal(100).WithVisible(10);
  Check(LS <> nil, 'WithVisible returns non-nil');
end;

procedure TestScrollbarWithOffset;
var LS: IScrollbar;
begin
  LS := TScrollbar.New.WithTotal(100).WithVisible(10).WithOffset(5);
  Check(LS <> nil, 'WithOffset returns non-nil');
end;

procedure TestScrollbarWithTrackChar;
var LS: IScrollbar; LBuf: TBuffer;
begin
  LS := TScrollbar.New.WithTotal(100).WithVisible(10)
    .WithTrackChar('.');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 1, 10));
  try
    (LS as IWidget).Render(TRect.Make(0, 0, 1, 10), LBuf);
    Check(True, 'scrollbar with track char renders');
  finally LBuf.Free; end;
end;

procedure TestScrollbarWithThumbChar;
var LS: IScrollbar; LBuf: TBuffer;
begin
  LS := TScrollbar.New.WithTotal(100).WithVisible(10)
    .WithThumbChar('#');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 1, 10));
  try
    (LS as IWidget).Render(TRect.Make(0, 0, 1, 10), LBuf);
    Check(True, 'scrollbar with thumb char renders');
  finally LBuf.Free; end;
end;

procedure TestScrollbarWithTrackStyle;
var LS: IScrollbar; LBuf: TBuffer;
begin
  LS := TScrollbar.New.WithTotal(100).WithVisible(10)
    .WithTrackStyle(TStyle.Default.WithFg(IndexedColor(8)));
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 1, 10));
  try
    (LS as IWidget).Render(TRect.Make(0, 0, 1, 10), LBuf);
    Check(True, 'scrollbar with track style renders');
  finally LBuf.Free; end;
end;

procedure TestScrollbarWithThumbStyle;
var LS: IScrollbar; LBuf: TBuffer;
begin
  LS := TScrollbar.New.WithTotal(100).WithVisible(10)
    .WithThumbStyle(TStyle.Default.WithFg(IndexedColor(15)));
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 1, 10));
  try
    (LS as IWidget).Render(TRect.Make(0, 0, 1, 10), LBuf);
    Check(True, 'scrollbar with thumb style renders');
  finally LBuf.Free; end;
end;

{ === Thumb calculation === }

procedure TestScrollbarThumbSize;
var LS: IScrollbar;
begin
  LS := TScrollbar.New.WithTotal(100).WithVisible(10);
  Check(LS.ThumbSize(20) > 0, 'thumb size is positive');
  Check(LS.ThumbSize(20) < 20, 'thumb size is less than track');
end;

procedure TestScrollbarThumbStart;
var LS: IScrollbar;
begin
  LS := TScrollbar.New.WithTotal(100).WithVisible(10).WithOffset(0);
  Check(LS.ThumbStart(20) = 0, 'thumb at start when offset 0');
end;

procedure TestScrollbarThumbStartOffset;
var LS: IScrollbar;
begin
  LS := TScrollbar.New.WithTotal(100).WithVisible(10).WithOffset(90);
  Check(LS.ThumbStart(20) > 0, 'thumb not at start when offset at end');
end;

{ === Hit test === }

procedure TestScrollbarHitAbove;
var LS: IScrollbar; Hit: TScrollbarHit;
begin
  LS := TScrollbar.New.WithTotal(1000).WithVisible(10).WithOffset(500);
  Hit := LS.HitAt(TRect.Make(0, 5, 1, 100), 5);
  Check(Hit <> shNone, 'hit is not none');
end;

procedure TestScrollbarHitBelow;
var LS: IScrollbar; Hit: TScrollbarHit;
begin
  LS := TScrollbar.New.WithTotal(1000).WithVisible(10).WithOffset(500);
  Hit := LS.HitAt(TRect.Make(0, 5, 1, 100), 105);
  Check(Hit = shNone, 'hit outside is none');
end;

procedure TestScrollbarHitNoHitWhenNotOverflow;
var LS: IScrollbar; Hit: TScrollbarHit;
begin
  { 未溢出(TotalItems <= VisibleItems)= 无滚动条可点,整列 shNone:
    退化态 ThumbSize 铺满整轨,不拦会把沟槽点击误判成 shThumb }
  LS := TScrollbar.New.WithTotal(3).WithVisible(10).WithOffset(0);
  Hit := LS.HitAt(TRect.Make(0, 0, 1, 10), 5);
  Check(Hit = shNone, 'no hit when total < visible');
  LS := TScrollbar.New.WithTotal(10).WithVisible(10).WithOffset(0);
  Hit := LS.HitAt(TRect.Make(0, 0, 1, 10), 0);
  Check(Hit = shNone, 'no hit when total = visible');
end;

{ === Page navigation === }

procedure TestScrollbarPageUp;
var LS: IScrollbar;
begin
  LS := TScrollbar.New.WithTotal(100).WithVisible(10).WithOffset(50);
  Check(LS.PageUp < 50, 'page up reduces offset');
end;

procedure TestScrollbarPageDown;
var LS: IScrollbar;
begin
  LS := TScrollbar.New.WithTotal(100).WithVisible(10).WithOffset(50);
  Check(LS.PageDown > 50, 'page down increases offset');
end;

{ === Clamped === }

procedure TestScrollbarClamped;
var LS: IScrollbar;
begin
  LS := TScrollbar.New.WithTotal(100).WithVisible(10).WithOffset(95);
  Check(LS.Clamped <= 90, 'clamped offset is valid');
end;

procedure TestScrollbarClampedZero;
var LS: IScrollbar;
begin
  LS := TScrollbar.New.WithTotal(100).WithVisible(10).WithOffset(-5);
  Check(LS.Clamped >= 0, 'clamped offset is non-negative');
end;

{ === OffsetFromDragY === }

procedure TestScrollbarOffsetFromDragY;
var LS: IScrollbar;
begin
  LS := TScrollbar.New.WithTotal(100).WithVisible(10);
  Check(LS.OffsetFromDragY(TRect.Make(0, 0, 1, 20), 0) >= 0, 'drag at top gives valid offset');
  Check(LS.OffsetFromDragY(TRect.Make(0, 0, 1, 20), 19) >= 0, 'drag at bottom gives valid offset');
end;

procedure TestScrollbarDragThumbTop;
var LS: IScrollbar;
begin
  LS := TScrollbar.New.WithTotal(100).WithVisible(10);
  { ThumbSize(20) = 10*20/100 = 2；轨道 [5, 25)，拇指顶可动区 [5, 23] }
  Check(LS.DragThumbTop(TRect.Make(0, 5, 1, 20), 10, 8, 6) = 8,
    'grab baseline offset preserved');
  Check(LS.DragThumbTop(TRect.Make(0, 5, 1, 20), 3, 8, 6) = 5,
    'clamped to track top');
  Check(LS.DragThumbTop(TRect.Make(0, 5, 1, 20), 40, 8, 6) = 23,
    'clamped to track bottom minus thumb');
  Check(LS.DragThumbTop(TRect.Make(0, 5, 1, 20), 10, 10, 10) = 10,
    'grab at thumb top follows pointer');
end;

{ === Render === }

procedure TestScrollbarRender;
var LS: IScrollbar; LBuf: TBuffer;
begin
  LS := TScrollbar.New.WithTotal(100).WithVisible(10).WithOffset(0);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 1, 20));
  try
    (LS as IWidget).Render(TRect.Make(0, 0, 1, 20), LBuf);
    Check(True, 'scrollbar renders');
  finally LBuf.Free; end;
end;

procedure TestScrollbarAsIWidget;
var LS: IScrollbar; LW: IWidget;
begin
  LS := TScrollbar.New;
  LW := LS as IWidget;
  Check(LW <> nil, 'IScrollbar casts to IWidget');
end;

begin
  T := TTestSuite.Create('test_tui_widget_scrollbar');
  try
    { Builders }
    T.Test('Scrollbar New', @TestScrollbarNew);
    T.Test('Scrollbar WithTotal', @TestScrollbarWithTotal);
    T.Test('Scrollbar WithVisible', @TestScrollbarWithVisible);
    T.Test('Scrollbar WithOffset', @TestScrollbarWithOffset);
    T.Test('Scrollbar WithTrackChar', @TestScrollbarWithTrackChar);
    T.Test('Scrollbar WithThumbChar', @TestScrollbarWithThumbChar);
    T.Test('Scrollbar WithTrackStyle', @TestScrollbarWithTrackStyle);
    T.Test('Scrollbar WithThumbStyle', @TestScrollbarWithThumbStyle);

    { Thumb calculation }
    T.Test('Scrollbar ThumbSize', @TestScrollbarThumbSize);
    T.Test('Scrollbar ThumbStart', @TestScrollbarThumbStart);
    T.Test('Scrollbar ThumbStart offset', @TestScrollbarThumbStartOffset);

    { Hit test }
    T.Test('Scrollbar HitAbove', @TestScrollbarHitAbove);
    T.Test('Scrollbar HitBelow', @TestScrollbarHitBelow);
    T.Test('Scrollbar HitNoHitWhenNotOverflow',
      @TestScrollbarHitNoHitWhenNotOverflow);

    { Page navigation }
    T.Test('Scrollbar PageUp', @TestScrollbarPageUp);
    T.Test('Scrollbar PageDown', @TestScrollbarPageDown);

    { Clamped }
    T.Test('Scrollbar Clamped', @TestScrollbarClamped);
    T.Test('Scrollbar Clamped zero', @TestScrollbarClampedZero);

    { OffsetFromDragY }
    T.Test('Scrollbar OffsetFromDragY', @TestScrollbarOffsetFromDragY);

    { DragThumbTop }
    T.Test('Scrollbar DragThumbTop', @TestScrollbarDragThumbTop);

    { Render }
    T.Test('Scrollbar render', @TestScrollbarRender);
    T.Test('Scrollbar as IWidget', @TestScrollbarAsIWidget);

    WriteLn;
  if not T.Run then Halt(1);
  finally
  end;
end.
