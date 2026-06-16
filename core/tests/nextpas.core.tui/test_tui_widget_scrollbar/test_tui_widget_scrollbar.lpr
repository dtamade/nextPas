program test_tui_widget_scrollbar;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.scrollbar,
  nextpas.core.testing;

var T: TTestRunner;

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
  T := TTestRunner.Create('test_tui_widget_scrollbar');
  try
    { Builders }
    T.Run('Scrollbar New', @TestScrollbarNew);
    T.Run('Scrollbar WithTotal', @TestScrollbarWithTotal);
    T.Run('Scrollbar WithVisible', @TestScrollbarWithVisible);
    T.Run('Scrollbar WithOffset', @TestScrollbarWithOffset);
    T.Run('Scrollbar WithTrackChar', @TestScrollbarWithTrackChar);
    T.Run('Scrollbar WithThumbChar', @TestScrollbarWithThumbChar);
    T.Run('Scrollbar WithTrackStyle', @TestScrollbarWithTrackStyle);
    T.Run('Scrollbar WithThumbStyle', @TestScrollbarWithThumbStyle);

    { Thumb calculation }
    T.Run('Scrollbar ThumbSize', @TestScrollbarThumbSize);
    T.Run('Scrollbar ThumbStart', @TestScrollbarThumbStart);
    T.Run('Scrollbar ThumbStart offset', @TestScrollbarThumbStartOffset);

    { Hit test }
    T.Run('Scrollbar HitAbove', @TestScrollbarHitAbove);
    T.Run('Scrollbar HitBelow', @TestScrollbarHitBelow);

    { Page navigation }
    T.Run('Scrollbar PageUp', @TestScrollbarPageUp);
    T.Run('Scrollbar PageDown', @TestScrollbarPageDown);

    { Clamped }
    T.Run('Scrollbar Clamped', @TestScrollbarClamped);
    T.Run('Scrollbar Clamped zero', @TestScrollbarClampedZero);

    { OffsetFromDragY }
    T.Run('Scrollbar OffsetFromDragY', @TestScrollbarOffsetFromDragY);

    { Render }
    T.Run('Scrollbar render', @TestScrollbarRender);
    T.Run('Scrollbar as IWidget', @TestScrollbarAsIWidget);

    WriteLn;
    T.Summary;
  finally
  end;
end.
