program test_tui_widget_split_pane;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base, nextpas.core.base.utils,
  nextpas.core.tui.base, nextpas.core.tui.color, nextpas.core.tui.style,
  nextpas.core.tui.buffer, nextpas.core.tui.event, nextpas.core.tui.widget.split_pane,
  nextpas.core.test;

var T: TTestSuite;

procedure TestStateDefault;
var S: TSplitPaneState;
begin S := TSplitPaneState.Default; Check(S.Ratio > 0, 'ratio'); Check(not S.Dragging, 'not dragging'); end;

procedure TestHorizontal;
begin Check(TSplitPane.Horizontal <> nil, 'horizontal'); end;

procedure TestVertical;
begin Check(TSplitPane.Vertical <> nil, 'vertical'); end;

procedure TestWithMinSize1;
begin Check(TSplitPane.Horizontal.WithMinSize1(10) <> nil, 'min1'); end;

procedure TestWithMinSize2;
begin Check(TSplitPane.Horizontal.WithMinSize2(15) <> nil, 'min2'); end;

procedure TestWithDividerStyle;
var S: TStyle;
begin S.Fg := IndexedColor(1); Check(TSplitPane.Horizontal.WithDividerStyle(S) <> nil, 'divstyle'); end;

procedure TestWithDividerChar;
begin Check(TSplitPane.Horizontal.WithDividerChar('|') <> nil, 'divchar'); end;

procedure TestRenderHorizontal;
var B: TBuffer; A: TRect;
begin A := TRect.Make(0, 0, 40, 10); B := TBuffer.CreateEmpty(A); TSplitPane.Horizontal.Render(A, B); B.Free; Check(True, 'horiz'); end;

procedure TestRenderVertical;
var B: TBuffer; A: TRect;
begin A := TRect.Make(0, 0, 40, 20); B := TBuffer.CreateEmpty(A); TSplitPane.Vertical.Render(A, B); B.Free; Check(True, 'vert'); end;

procedure TestBuilderChaining;
var S: TStyle;
begin S.Fg := IndexedColor(1); Check(TSplitPane.Horizontal.WithMinSize1(10).WithMinSize2(10).WithDividerStyle(S).WithDividerChar('|') <> nil, 'chain'); end;

procedure TestSplitHalfRatio;
var
  LPane: ISplitPane;
  LState: TSplitPaneState;
  LArea, LP1, LP2, LD: TRect;
  LOk: Boolean;
begin
  LPane := TSplitPane.Horizontal;
  LState := TSplitPaneState.Default;
  LState.Ratio := 0.5;
  LArea := TRect.Make(0, 0, 100, 10);
  LOk := LPane.Split(LArea, LState, LP1, LP2, LD);
  Check(LOk, 'Split should succeed');
  // Pane1 + Divider + Pane2 = total width
  Check(LP1.Width + LD.Width + LP2.Width = 100, 'Widths should sum to total');
  // With 50% ratio, pane1 ≈ pane2
  Check(LP1.Width >= 49, 'Pane1 width >= 49');
  Check(LP1.Width <= 50, 'Pane1 width <= 50');
end;

procedure TestSplitSmallRatio;
var
  LPane: ISplitPane;
  LState: TSplitPaneState;
  LArea, LP1, LP2, LD: TRect;
  LOk: Boolean;
begin
  LPane := TSplitPane.Horizontal;
  LState := TSplitPaneState.Default;
  LState.Ratio := 0.3;
  LArea := TRect.Make(0, 0, 100, 10);
  LOk := LPane.Split(LArea, LState, LP1, LP2, LD);
  Check(LOk, 'Split should succeed');
  Check(LP1.Width < LP2.Width, 'Pane1 should be smaller than Pane2');
end;

procedure TestSplitEmptyArea;
var
  LPane: ISplitPane;
  LState: TSplitPaneState;
  LArea, LP1, LP2, LD: TRect;
begin
  LPane := TSplitPane.Horizontal;
  LState := TSplitPaneState.Default;
  LArea := TRect.Make(0, 0, 0, 0);
  Check(not LPane.Split(LArea, LState, LP1, LP2, LD), 'Empty area should fail');
end;

procedure TestSplitTooSmall;
var
  LPane: ISplitPane;
  LState: TSplitPaneState;
  LArea, LP1, LP2, LD: TRect;
begin
  LPane := TSplitPane.Horizontal;
  LState := TSplitPaneState.Default;
  // MinSize1=3 + MinSize2=3 + Div=1 = 7 minimum
  LArea := TRect.Make(0, 0, 5, 10);
  Check(not LPane.Split(LArea, LState, LP1, LP2, LD), 'Too small should fail');
end;

procedure TestSplitVertical;
var
  LPane: ISplitPane;
  LState: TSplitPaneState;
  LArea, LP1, LP2, LD: TRect;
  LOk: Boolean;
begin
  LPane := TSplitPane.Vertical;
  LState := TSplitPaneState.Default;
  LState.Ratio := 0.5;
  LArea := TRect.Make(0, 0, 20, 100);
  LOk := LPane.Split(LArea, LState, LP1, LP2, LD);
  Check(LOk, 'Vertical split should succeed');
  Check(LP1.Height + LD.Height + LP2.Height = 100, 'Heights should sum to total');
end;

procedure TestHandleMouseNonDrag;
var
  LPane: ISplitPane;
  LState: TSplitPaneState;
  LArea: TRect;
  LMouse: TMouseEvent;
begin
  LPane := TSplitPane.Horizontal;
  LState := TSplitPaneState.Default;
  LArea := TRect.Make(0, 0, 100, 10);
  LMouse.Kind := mkMoved;
  LMouse.Button := mbNone;
  LMouse.X := 50; LMouse.Y := 5;
  LMouse.Modifiers := [];
  Check(not LPane.HandleMouse(LArea, LMouse, LState), 'Non-drag moved should return False');
end;

procedure TestHandleMouseUpNotDragging;
var
  LPane: ISplitPane;
  LState: TSplitPaneState;
  LArea: TRect;
  LMouse: TMouseEvent;
begin
  LPane := TSplitPane.Horizontal;
  LState := TSplitPaneState.Default;
  LArea := TRect.Make(0, 0, 100, 10);
  LMouse.Kind := mkUp;
  LMouse.Button := mbLeft;
  LMouse.X := 50; LMouse.Y := 5;
  LMouse.Modifiers := [];
  Check(not LPane.HandleMouse(LArea, LMouse, LState), 'Up when not dragging should return False');
end;

begin
  T := TTestSuite.Create('tui_widget_split_pane');
  T.Test('StateDefault', @TestStateDefault);
  T.Test('Horizontal', @TestHorizontal);
  T.Test('Vertical', @TestVertical);
  T.Test('WithMinSize1', @TestWithMinSize1);
  T.Test('WithMinSize2', @TestWithMinSize2);
  T.Test('WithDividerStyle', @TestWithDividerStyle);
  T.Test('WithDividerChar', @TestWithDividerChar);
  T.Test('RenderHorizontal', @TestRenderHorizontal);
  T.Test('RenderVertical', @TestRenderVertical);
  T.Test('Builder chaining', @TestBuilderChaining);
  T.Test('Split half ratio', @TestSplitHalfRatio);
  T.Test('Split small ratio', @TestSplitSmallRatio);
  T.Test('Split empty area', @TestSplitEmptyArea);
  T.Test('Split too small', @TestSplitTooSmall);
  T.Test('Split vertical', @TestSplitVertical);
  T.Test('HandleMouse non-drag', @TestHandleMouseNonDrag);
  T.Test('HandleMouse up not dragging', @TestHandleMouseUpNotDragging);
  if not T.Run then Halt(1);
end.
