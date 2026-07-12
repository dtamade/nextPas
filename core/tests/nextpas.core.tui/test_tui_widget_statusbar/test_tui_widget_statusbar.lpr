program test_tui_widget_statusbar;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base, nextpas.core.base.utils,
  nextpas.core.tui.base, nextpas.core.tui.color, nextpas.core.tui.modifier,
  nextpas.core.tui.style, nextpas.core.tui.cell, nextpas.core.tui.buffer,
  nextpas.core.tui.widget.statusbar, nextpas.core.test;

var T: TTestSuite;

procedure TestSegmentMake;
var S: TStatusSegment;
begin S := TStatusSegment.Make('Ready'); Check(S.Text = 'Ready', 'text'); end;

procedure TestSegmentWithStyle;
var S: TStatusSegment; St: TStyle;
begin St.Fg := IndexedColor(1); S := TStatusSegment.Make('OK').WithStyle(St); Check(S.Text = 'OK', 'text'); end;

procedure TestNew;
begin Check(TStatusBar.New <> nil, 'New'); end;

procedure TestWithStyle;
var S: TStyle;
begin S.Fg := IndexedColor(1); Check(TStatusBar.New.WithStyle(S) <> nil, 'WithStyle'); end;

procedure TestWithLeft;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 60, 1); B := TBuffer.CreateEmpty(A);
  try
    TStatusBar.New.WithLeft([TStatusSegment.Make('File'), TStatusSegment.Make('Line 10')]).Render(A, B);
    Check(True, 'WithLeft');
  finally B.Free; end;
end;

procedure TestWithCenter;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 60, 1); B := TBuffer.CreateEmpty(A);
  try
    TStatusBar.New.WithCenter([TStatusSegment.Make('Status')]).Render(A, B);
    Check(True, 'WithCenter');
  finally B.Free; end;
end;

procedure TestWithRight;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 60, 1); B := TBuffer.CreateEmpty(A);
  try
    TStatusBar.New.WithRight([TStatusSegment.Make('UTF-8')]).Render(A, B);
    Check(True, 'WithRight');
  finally B.Free; end;
end;

procedure TestRender;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 80, 1); B := TBuffer.CreateEmpty(A);
  try
    TStatusBar.New.WithLeft([TStatusSegment.Make('L')]).WithCenter([TStatusSegment.Make('C')]).WithRight([TStatusSegment.Make('R')]).Render(A, B);
    Check(True, 'Render');
  finally B.Free; end;
end;

procedure TestRenderEmpty;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 40, 1); B := TBuffer.CreateEmpty(A);
  try
    TStatusBar.New.Render(A, B);
    Check(True, 'Render empty');
  finally B.Free; end;
end;

procedure TestBuilderChaining;
var S: TStyle;
begin
  S.Fg := IndexedColor(1);
  Check(TStatusBar.New.WithStyle(S).WithLeft([TStatusSegment.Make('L')]).WithCenter([TStatusSegment.Make('C')]).WithRight([TStatusSegment.Make('R')]) <> nil, 'chain');
end;

{ === New tests === }

procedure TestLeftContentVisible;
var B: TBuffer; A: TRect; LRow: AnsiString;
begin
  A := TRect.Make(0, 0, 40, 1); B := TBuffer.CreateEmpty(A);
  try
    TStatusBar.New.WithLeft([TStatusSegment.Make('Hello')]).Render(A, B);
    LRow := B.RowAsString(0);
    Check(Pos('Hello', LRow) > 0, 'left content visible');
  finally B.Free; end;
end;

procedure TestRightContentVisible;
var B: TBuffer; A: TRect; LRow: AnsiString;
begin
  A := TRect.Make(0, 0, 40, 1); B := TBuffer.CreateEmpty(A);
  try
    TStatusBar.New.WithRight([TStatusSegment.Make('End')]).Render(A, B);
    LRow := B.RowAsString(0);
    Check(Pos('End', LRow) > 0, 'right content visible');
  finally B.Free; end;
end;

procedure TestCenterContentVisible;
var B: TBuffer; A: TRect; LRow: AnsiString;
begin
  A := TRect.Make(0, 0, 40, 1); B := TBuffer.CreateEmpty(A);
  try
    TStatusBar.New.WithCenter([TStatusSegment.Make('Mid')]).Render(A, B);
    LRow := B.RowAsString(0);
    Check(Pos('Mid', LRow) > 0, 'center content visible');
  finally B.Free; end;
end;

procedure TestMultipleSegments;
var B: TBuffer; A: TRect; LRow: AnsiString;
begin
  A := TRect.Make(0, 0, 60, 1); B := TBuffer.CreateEmpty(A);
  try
    TStatusBar.New
      .WithLeft([TStatusSegment.Make('A'), TStatusSegment.Make(' B')])
      .WithRight([TStatusSegment.Make('C'), TStatusSegment.Make(' D')])
      .Render(A, B);
    LRow := B.RowAsString(0);
    Check(Pos('A', LRow) > 0, 'multi left A');
    Check(Pos('B', LRow) > 0, 'multi left B');
  finally B.Free; end;
end;

procedure TestWideContentClips;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 5, 1); B := TBuffer.CreateEmpty(A);
  try
    TStatusBar.New.WithLeft([TStatusSegment.Make('VeryLongText')]).Render(A, B);
    Check(True, 'wide content clips without crash');
  finally B.Free; end;
end;

procedure TestEmptyArea;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 0, 0); B := TBuffer.CreateEmpty(A);
  try
    TStatusBar.New.WithLeft([TStatusSegment.Make('X')]).Render(A, B);
    Check(True, 'empty area no crash');
  finally B.Free; end;
end;

procedure TestSegmentStyleApplied;
var B: TBuffer; A: TRect; LCell: PCell;
begin
  A := TRect.Make(0, 0, 20, 1); B := TBuffer.CreateEmpty(A);
  try
    TStatusBar.New.WithLeft([TStatusSegment.Make('X').WithStyle(TStyle.Default.WithFg(TUI_RED))]).Render(A, B);
    LCell := B.CellAt(0, 0);
    Check(LCell <> nil, 'cell exists');
    Check(ColorEquals(TUI_RED, LCell^.Fg), 'segment style applied');
  finally B.Free; end;
end;

begin
  T := TTestSuite.Create('tui_widget_statusbar');
  T.Test('SegmentMake', @TestSegmentMake);
  T.Test('SegmentWithStyle', @TestSegmentWithStyle);
  T.Test('New', @TestNew);
  T.Test('WithStyle', @TestWithStyle);
  T.Test('WithLeft', @TestWithLeft);
  T.Test('WithCenter', @TestWithCenter);
  T.Test('WithRight', @TestWithRight);
  T.Test('Render', @TestRender);
  T.Test('Render empty', @TestRenderEmpty);
  T.Test('Builder chaining', @TestBuilderChaining);
  T.Test('Left content visible', @TestLeftContentVisible);
  T.Test('Right content visible', @TestRightContentVisible);
  T.Test('Center content visible', @TestCenterContentVisible);
  T.Test('Multiple segments', @TestMultipleSegments);
  T.Test('Wide content clips', @TestWideContentClips);
  T.Test('Empty area', @TestEmptyArea);
  T.Test('Segment style applied', @TestSegmentStyleApplied);
  if not T.Run then Halt(1);
end.
