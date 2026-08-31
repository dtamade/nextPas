program test_tui_canvas_view;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.canvas.view,
  nextpas.core.test;

var
  T: TTestSuite;
  V: TCanvasView;

procedure TestDefaults;
begin
  V := TCanvasView.Create;
  try
    CheckEqual(Int64(1), Int64(V.Zoom), 'default zoom 1');
    CheckEqual(Int64(0), Int64(V.OriginX), 'default origin x');
    CheckEqual(Int64(0), Int64(V.OriginY), 'default origin y');
    CheckEqual(Int64(0), Int64(V.ScreenW), 'default screen w');
    CheckEqual(Int64(0), Int64(V.ScreenH), 'default screen h');
  finally
    V.Free;
  end;
end;

procedure TestClamps;
begin
  V := TCanvasView.Create;
  try
    V.SetScreenRect(0, 0, -3, -5);
    CheckEqual(Int64(0), Int64(V.ScreenW), 'screen w clamped to 0');
    CheckEqual(Int64(0), Int64(V.ScreenH), 'screen h clamped to 0');
    V.SetScreenRect(0, 0, 8, 4);
    V.SetDocSize(0, -2);
    { SetDocSize 不改视图平移/缩放状态 }
    CheckEqual(Int64(0), Int64(V.OriginX), 'doc size min leaves origin');
    CheckEqual(Int64(1), Int64(V.Zoom), 'doc size min leaves zoom');
  finally
    V.Free;
  end;
end;

procedure TestMappings;
begin
  V := TCanvasView.Create;
  try
    V.SetScreenRect(5, 2, 40, 20);
    V.SetDocSize(100, 100);
    CheckEqual(Int64(5), Int64(V.DocToScreenX(0)), 'doc 0 -> screen x0');
    CheckEqual(Int64(2), Int64(V.DocToScreenY(0)), 'doc 0 -> screen y0');
    CheckEqual(Int64(0), Int64(V.ScreenToDocX(5)), 'screen x0 -> doc 0');
    CheckEqual(Int64(0), Int64(V.ScreenToDocY(2)), 'screen y0 -> doc 0');
    { 屏幕 x7: 原点屏 x5=doc0, zoom1 每格一格 → doc 2 }
    CheckEqual(Int64(2), Int64(V.ScreenToDocX(7)), 'screen x7 -> doc 2');
    { 文档 x2 的屏幕: 5 + (2-0)*1 = 7 }
    CheckEqual(Int64(7), Int64(V.DocToScreenX(2)), 'doc x2 -> screen 7');
  finally
    V.Free;
  end;
end;

procedure TestMappingRoundTrip;
begin
  V := TCanvasView.Create;
  try
    V.SetScreenRect(3, 1, 30, 12);
    V.SetDocSize(80, 50);
    V.SetZoom(2, 10, 10);
    CheckEqual(Int64(10), Int64(V.ScreenToDocX(V.DocToScreenX(10))), 'x roundtrip');
    CheckEqual(Int64(10), Int64(V.ScreenToDocY(V.DocToScreenY(10))), 'y roundtrip');
    CheckEqual(Int64(5), Int64(V.ScreenToDocX(V.DocToScreenX(5))), 'x roundtrip 5');
  finally
    V.Free;
  end;
end;

procedure TestZoomClampAndCenter;
begin
  V := TCanvasView.Create;
  try
    V.SetScreenRect(0, 0, 40, 20);
    V.SetDocSize(100, 100);
    V.SetZoom(9, 10, 10);
    CheckEqual(Int64(4), Int64(V.Zoom), 'zoom clamped to 4');
    CheckEqual(Int64(10 - (20 div 4)), Int64(V.OriginX), 'zoom center-anchored x');
    V.SetZoom(0, 10, 10);
    CheckEqual(Int64(1), Int64(V.Zoom), 'zoom clamped to 1');
  finally
    V.Free;
  end;
end;

procedure TestZoomCenterMath;
begin
  V := TCanvasView.Create;
  try
    { 40x20 视口: FX = 锚点 - FloorDiv(20, zoom), FY = 锚点 - FloorDiv(10, zoom) }
    V.SetScreenRect(0, 0, 40, 20);
    V.SetDocSize(100, 100);
    V.SetZoom(3, 10, 10);
    CheckEqual(Int64(10 - (20 div 3)), Int64(V.OriginX), 'anchor x: 10 - 6');
    CheckEqual(Int64(10 - (10 div 3)), Int64(V.OriginY), 'anchor y: 10 - 3');
    { 锚点 10 经 FloorDiv 对齐网格, 往返无损 }
    CheckEqual(Int64(10), Int64(V.ScreenToDocX(V.DocToScreenX(10))), 'anchor preserved');
    CheckEqual(Int64(10), Int64(V.ScreenToDocY(V.DocToScreenY(10))), 'anchor preserved y');
  finally
    V.Free;
  end;
end;

procedure TestPanAndCenterOn;
begin
  V := TCanvasView.Create;
  try
    V.SetScreenRect(0, 0, 10, 6);
    V.SetDocSize(100, 100);
    V.Pan(2, -3);
    CheckEqual(Int64(2), Int64(V.OriginX), 'pan x');
    CheckEqual(Int64(-3), Int64(V.OriginY), 'pan y');

    V.CenterOn(3, 4);
    CheckEqual(Int64(3 - 5), Int64(V.OriginX), 'center on x (minus half width)');
    CheckEqual(Int64(4 - 3), Int64(V.OriginY), 'center on y (minus half height)');
    CheckEqual(Int64(3), Int64(V.ScreenToDocX(5)), 'center doc x at viewport center');
    CheckEqual(Int64(4), Int64(V.ScreenToDocY(3)), 'center doc y at viewport center');
  finally
    V.Free;
  end;
end;

procedure TestNegativeFloorDiv;
begin
  V := TCanvasView.Create;
  try
    V.SetScreenRect(0, 0, 10, 10);
    V.SetDocSize(100, 100);
    V.Pan(-3, -5);
    CheckEqual(Int64(-3), Int64(V.ScreenToDocX(0)), 'negative origin x maps back');
    CheckEqual(Int64(-5), Int64(V.ScreenToDocY(0)), 'negative origin y maps back');
    { zoom1: 屏幕 x1 在原点右一列 → doc -2 }
    CheckEqual(Int64(-2), Int64(V.ScreenToDocX(1)), 'zoom1 next column -> -2');
    { SetZoom 以中心为锚重算原点: FX = 0 - FloorDiv(5,2) = -2 (zoom2) }
    V.SetZoom(2, 0, 0);
    CheckEqual(Int64(-2), Int64(V.OriginX), 'zoom2 re-anchored origin');
    { 屏幕 x1: -2 + FloorDiv(1,2) = -2 (向下取整, 仍在 doc -2) }
    CheckEqual(Int64(-2), Int64(V.ScreenToDocX(1)), 'zoom2 negative floor');
    { 文档 -2 往返: DocToScreenX(-2) = 0, ScreenToDocX(0) = -2 }
    CheckEqual(Int64(-2), Int64(V.ScreenToDocX(V.DocToScreenX(-2))), 'zoom2 negative roundtrip');
  finally
    V.Free;
  end;
end;

procedure TestVisibleDocRect;
var
  LX0, LY0, LX1, LY1: Integer;
begin
  V := TCanvasView.Create;
  try
    V.SetScreenRect(0, 0, 10, 10);
    V.SetDocSize(100, 100);
    Check(V.VisibleDocRect(LX0, LY0, LX1, LY1), 'full viewport visible');
    CheckEqual(Int64(0), Int64(LX0), 'visible x0');
    CheckEqual(Int64(9), Int64(LX1), 'visible x1');

    V.CenterOn(50, 50);
    V.SetZoom(2, 50, 50);
    { zoom2 10x10: FX = 50 - FloorDiv(5,2) = 48; 可见 48..ScreenToDocX(9)
      ScreenToDocX(9) = 48 + FloorDiv(9,2) = 52 }
    Check(V.VisibleDocRect(LX0, LY0, LX1, LY1), 'zoomed center visible');
    CheckEqual(Int64(48), Int64(LX0), 'zoomed visible x0');
    CheckEqual(Int64(52), Int64(LX1), 'zoomed visible x1');

    V.Pan(200, 200);
    Check(not V.VisibleDocRect(LX0, LY0, LX1, LY1), 'viewport beyond doc -> invisible');

    V.Pan(-300, -300);
    Check(not V.VisibleDocRect(LX0, LY0, LX1, LY1), 'viewport before doc -> invisible');

    V.CenterOn(96, 96);
    V.SetZoom(1, 96, 96);
    Check(V.VisibleDocRect(LX0, LY0, LX1, LY1), 'partial overlap visible');
    CheckEqual(Int64(91), Int64(LX0), 'clamped left');
    CheckEqual(Int64(99), Int64(LX1), 'clamped right');
  finally
    V.Free;
  end;
end;

procedure TestDirtyRows;
var
  LFull: Boolean;
begin
  V := TCanvasView.Create;
  try
    V.SetScreenRect(0, 0, 8, 4);
    V.SetDocSize(16, 16);
    Check(V.IsFullDirty, 'fresh view full dirty');
    Check(V.IsRowDirty(0), 'full dirty marks all rows');
    Check(V.IsRowDirty(3), 'full dirty marks last row');
    V.ConsumeDirty(LFull);
    Check(LFull, 'consume reports full');
    Check(not V.IsFullDirty, 'consume clears full flag');
    Check(not V.IsRowDirty(0), 'consume clears rows');
    Check(not V.AnyDirty, 'nothing dirty after consume');

    { zoom1: 文档(2,1)-(3,2) 覆盖屏幕行 1..2 }
    V.MarkDocRectDirty(2, 1, 3, 2);
    Check(V.IsRowDirty(1), 'doc rect row 1 dirty');
    Check(V.IsRowDirty(2), 'doc rect row 2 dirty');
    Check(not V.IsRowDirty(0), 'doc rect row 0 clean');
    Check(not V.IsRowDirty(3), 'doc rect row 3 clean');
    Check(not V.IsFullDirty, 'doc rect not full dirty');

    V.ConsumeDirty(LFull);
    Check(not LFull, 'second consume not full');
    Check(not V.IsRowDirty(1), 'rows cleared after consume');

    { zoom2, FX=1, FY=1: 文档(0,1)-(1,2) 覆盖屏幕行 DocToScreenY(1)=0 .. DocToScreenY(2)+1=3 }
    V.SetZoom(2, 3, 2);
    V.ConsumeDirty(LFull);
    V.MarkDocRectDirty(0, 1, 1, 2);
    Check(V.IsRowDirty(0), 'zoom2 row 0 dirty');
    Check(V.IsRowDirty(3), 'zoom2 row 3 dirty');
    Check(not V.IsRowDirty(4), 'zoom2 row 4 out of range false');

    V.ConsumeDirty(LFull);
    V.MarkScreenRectDirty(0, 1, 0, 2);
    Check(not V.IsRowDirty(0), 'screen rect row 0 clean');
    Check(V.IsRowDirty(1), 'screen rect row 1 dirty');
    Check(V.IsRowDirty(2), 'screen rect row 2 dirty');
    Check(not V.IsRowDirty(3), 'screen rect row 3 clean');

    V.SetZoom(1, 0, 0);
    V.ConsumeDirty(LFull);
    V.MarkAllDirty;
    Check(V.IsFullDirty, 'mark all dirty');
    Check(V.AllRowsDirty, 'all rows dirty when full');
    V.ConsumeDirty(LFull);
    V.MarkScreenRectDirty(0, 0, 0, 1);
    Check(not V.AllRowsDirty, 'partial dirty not all rows');
    Check(not V.IsRowDirty(3), 'row 3 clean after partial');
    Check(V.IsRowDirty(0), 'row 0 dirty after partial');
  finally
    V.Free;
  end;
end;

procedure TestIsRowDirtyOutOfRange;
begin
  V := TCanvasView.Create;
  try
    V.SetScreenRect(0, 0, 4, 4);
    Check(not V.IsRowDirty(-1), 'row -1 false');
    Check(not V.IsRowDirty(4), 'row 4 false');
  finally
    V.Free;
  end;
end;

procedure TestSetScreenRectResetsDirty;
var
  LFull: Boolean;
begin
  V := TCanvasView.Create;
  try
    V.SetScreenRect(0, 0, 8, 4);
    V.ConsumeDirty(LFull);
    V.MarkScreenRectDirty(0, 1, 0, 2);
    V.SetScreenRect(0, 0, 8, 4);
    Check(V.IsFullDirty, 'set screen rect marks full dirty');
  finally
    V.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.canvas.view');
  T.Test('defaults', @TestDefaults);
  T.Test('clamps', @TestClamps);
  T.Test('mappings', @TestMappings);
  T.Test('mapping roundtrip', @TestMappingRoundTrip);
  T.Test('zoom clamp and center', @TestZoomClampAndCenter);
  T.Test('zoom center math', @TestZoomCenterMath);
  T.Test('pan and center on', @TestPanAndCenterOn);
  T.Test('negative floor div', @TestNegativeFloorDiv);
  T.Test('visible doc rect', @TestVisibleDocRect);
  T.Test('dirty rows', @TestDirtyRows);
  T.Test('is row dirty out of range', @TestIsRowDirtyOutOfRange);
  T.Test('set screen rect resets dirty', @TestSetScreenRectResetsDirty);
  if not T.Run then Halt(1);
end.