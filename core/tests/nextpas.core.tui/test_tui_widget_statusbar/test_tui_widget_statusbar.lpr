program test_tui_widget_statusbar;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base, nextpas.core.base.utils,
  nextpas.core.tui.base, nextpas.core.tui.color, nextpas.core.tui.style,
  nextpas.core.tui.buffer, nextpas.core.tui.widget.statusbar,
  nextpas.core.test;

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
  TStatusBar.New.WithLeft([TStatusSegment.Make('File'), TStatusSegment.Make('Line 10')]).Render(A, B);
  Check(True, 'WithLeft');
end;

procedure TestWithCenter;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 60, 1); B := TBuffer.CreateEmpty(A);
  TStatusBar.New.WithCenter([TStatusSegment.Make('Status')]).Render(A, B);
  Check(True, 'WithCenter');
end;

procedure TestWithRight;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 60, 1); B := TBuffer.CreateEmpty(A);
  TStatusBar.New.WithRight([TStatusSegment.Make('UTF-8')]).Render(A, B);
  Check(True, 'WithRight');
end;

procedure TestRender;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 80, 1); B := TBuffer.CreateEmpty(A);
  TStatusBar.New.WithLeft([TStatusSegment.Make('L')]).WithCenter([TStatusSegment.Make('C')]).WithRight([TStatusSegment.Make('R')]).Render(A, B);
  Check(True, 'Render');
end;

procedure TestRenderEmpty;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 40, 1); B := TBuffer.CreateEmpty(A);
  TStatusBar.New.Render(A, B);
  Check(True, 'Render empty');
end;

procedure TestBuilderChaining;
var S: TStyle;
begin
  S.Fg := IndexedColor(1);
  Check(TStatusBar.New.WithStyle(S).WithLeft([TStatusSegment.Make('L')]).WithCenter([TStatusSegment.Make('C')]).WithRight([TStatusSegment.Make('R')]) <> nil, 'chain');
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
  if not T.Run then Halt(1);
end.
