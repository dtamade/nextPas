program test_tui_widget_scrollview;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base, nextpas.core.base.utils,
  nextpas.core.tui.base, nextpas.core.tui.color, nextpas.core.tui.style,
  nextpas.core.tui.buffer, nextpas.core.tui.widget.scrollview,
  nextpas.core.test;

var T: TTestSuite;

procedure TestStateEmpty;
var S: TScrollViewState;
begin S := TScrollViewState.Empty; Check(S.OffsetY = 0, 'empty'); end;

procedure TestStateScrollDown;
var S: TScrollViewState;
begin S := TScrollViewState.Empty; S.ScrollDown(5); Check(S.OffsetY = 5, 'down5'); S.ScrollDown(3); Check(S.OffsetY = 8, 'down3'); end;

procedure TestStateScrollUp;
var S: TScrollViewState;
begin S := TScrollViewState.Empty; S.ScrollDown(10); S.ScrollUp(4); Check(S.OffsetY = 6, 'up4'); end;

procedure TestStateScrollUpBoundary;
var S: TScrollViewState;
begin S := TScrollViewState.Empty; S.ScrollUp(5); Check(S.OffsetY = 0, 'boundary'); end;

procedure TestStatePageDown;
var S: TScrollViewState;
begin S := TScrollViewState.Empty; S.PageDown(10); Check(S.OffsetY = 10, 'pagedown'); end;

procedure TestStatePageUp;
var S: TScrollViewState;
begin S := TScrollViewState.Empty; S.PageDown(20); S.PageUp(10); Check(S.OffsetY = 10, 'pageup'); end;

procedure TestStateScrollToTop;
var S: TScrollViewState;
begin S := TScrollViewState.Empty; S.ScrollDown(50); S.ScrollToTop; Check(S.OffsetY = 0, 'top'); end;

procedure TestStateScrollToBottom;
var S: TScrollViewState;
begin S := TScrollViewState.Empty; S.ScrollToBottom(10); Check(True, 'bottom'); end;

procedure TestStateEnsureVisible;
var S: TScrollViewState;
begin S := TScrollViewState.Empty; S.EnsureVisible(50, 10); Check(S.OffsetY >= 40, 'visible'); end;

procedure TestNew;
begin Check(TScrollView.New <> nil, 'New'); end;

procedure TestWithStyle;
var S: TStyle;
begin S.Fg := IndexedColor(1); Check(TScrollView.New.WithStyle(S) <> nil, 'WithStyle'); end;

procedure TestWithScrollbarStyle;
var S: TStyle;
begin S.Fg := IndexedColor(2); Check(TScrollView.New.WithScrollbarStyle(S) <> nil, 'WithScrollbarStyle'); end;

procedure TestWithShowScrollbar;
begin Check(TScrollView.New.WithShowScrollbar(True) <> nil, 'WithShowScrollbar'); end;

procedure TestRender;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 30, 10);
  B := TBuffer.CreateEmpty(A);
  try
    TScrollView.New.Render(A, B);
    Check(True, 'Render');
  finally
    B.Free;
  end;
end;

procedure TestRenderStateful;
var B: TBuffer; A: TRect; S: TScrollViewState;
begin
  A := TRect.Make(0, 0, 30, 10);
  B := TBuffer.CreateEmpty(A);
  try
    S := TScrollViewState.Empty;
    TScrollView.New.RenderStateful(A, B, S);
    Check(True, 'RenderStateful');
  finally
    B.Free;
  end;
end;

procedure TestRenderEmpty;
var B: TBuffer; A: TRect; S: TScrollViewState;
begin
  A := TRect.Make(0, 0, 20, 5);
  B := TBuffer.CreateEmpty(A);
  try
    S := TScrollViewState.Empty;
    TScrollView.New.RenderStateful(A, B, S);
    Check(True, 'Render empty scrollview');
  finally
    B.Free;
  end;
end;

procedure TestRenderSmallArea;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 3, 2);
  B := TBuffer.CreateEmpty(A);
  try
    TScrollView.New.Render(A, B);
    Check(True, 'Render in small area');
  finally
    B.Free;
  end;
end;

procedure TestStateScrollDownMultiple;
var S: TScrollViewState;
begin
  S := TScrollViewState.Empty;
  S.ScrollDown(5);
  S.ScrollDown(5);
  S.ScrollDown(5);
  Check(S.OffsetY = 15, 'Should be 15 after 3x5');
end;

procedure TestScrollDownClampsToContentHeight;
var S: TScrollViewState;
begin
  S := TScrollViewState.Empty;
  S.ContentHeight := 20;
  S.ScrollDown(100);
  CheckEqual(19, S.OffsetY, 'clamped to ContentHeight-1');
end;

procedure TestScrollDownClampsExact;
var S: TScrollViewState;
begin
  S := TScrollViewState.Empty;
  S.ContentHeight := 10;
  S.ScrollDown(10);
  CheckEqual(9, S.OffsetY, 'exact ContentHeight clamps');
end;

procedure TestScrollDownZeroContent;
var S: TScrollViewState;
begin
  S := TScrollViewState.Empty;
  S.ContentHeight := 0;
  S.ScrollDown(5);
  CheckEqual(5, S.OffsetY, 'zero content allows scroll');
end;

procedure TestPageDownClamps;
var S: TScrollViewState;
begin
  S := TScrollViewState.Empty;
  S.ContentHeight := 15;
  S.PageDown(100);
  CheckEqual(14, S.OffsetY, 'PageDown clamps');
end;

procedure TestBuilderChaining;
var S1, S2: TStyle;
begin S1.Fg := IndexedColor(1); S2.Fg := IndexedColor(2); Check(TScrollView.New.WithStyle(S1).WithScrollbarStyle(S2).WithShowScrollbar(True) <> nil, 'chain'); end;

begin
  T := TTestSuite.Create('tui_widget_scrollview');
  T.Test('StateEmpty', @TestStateEmpty);
  T.Test('StateScrollDown', @TestStateScrollDown);
  T.Test('StateScrollUp', @TestStateScrollUp);
  T.Test('StateScrollUpBoundary', @TestStateScrollUpBoundary);
  T.Test('StatePageDown', @TestStatePageDown);
  T.Test('StatePageUp', @TestStatePageUp);
  T.Test('StateScrollToTop', @TestStateScrollToTop);
  T.Test('StateScrollToBottom', @TestStateScrollToBottom);
  T.Test('StateEnsureVisible', @TestStateEnsureVisible);
  T.Test('New', @TestNew);
  T.Test('WithStyle', @TestWithStyle);
  T.Test('WithScrollbarStyle', @TestWithScrollbarStyle);
  T.Test('WithShowScrollbar', @TestWithShowScrollbar);
  T.Test('Render', @TestRender);
  T.Test('RenderStateful', @TestRenderStateful);
  T.Test('ScrollDown clamps', @TestScrollDownClampsToContentHeight);
  T.Test('ScrollDown clamps exact', @TestScrollDownClampsExact);
  T.Test('ScrollDown zero content', @TestScrollDownZeroContent);
  T.Test('PageDown clamps', @TestPageDownClamps);
  T.Test('Builder chaining', @TestBuilderChaining);
  T.Test('Render empty', @TestRenderEmpty);
  T.Test('Render small area', @TestRenderSmallArea);
  T.Test('StateScrollDown multiple', @TestStateScrollDownMultiple);
  if not T.Run then Halt(1);
end.
