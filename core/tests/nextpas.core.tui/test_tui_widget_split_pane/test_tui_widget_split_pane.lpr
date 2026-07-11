program test_tui_widget_split_pane;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base, nextpas.core.base.utils,
  nextpas.core.tui.base, nextpas.core.tui.color, nextpas.core.tui.style,
  nextpas.core.tui.buffer, nextpas.core.tui.widget.split_pane,
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
begin A := TRect.Make(0, 0, 40, 10); B := TBuffer.CreateEmpty(A); TSplitPane.Horizontal.Render(A, B); Check(True, 'horiz'); end;

procedure TestRenderVertical;
var B: TBuffer; A: TRect;
begin A := TRect.Make(0, 0, 40, 20); B := TBuffer.CreateEmpty(A); TSplitPane.Vertical.Render(A, B); Check(True, 'vert'); end;

procedure TestBuilderChaining;
var S: TStyle;
begin S.Fg := IndexedColor(1); Check(TSplitPane.Horizontal.WithMinSize1(10).WithMinSize2(10).WithDividerStyle(S).WithDividerChar('|') <> nil, 'chain'); end;

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
  if not T.Run then Halt(1);
end.
