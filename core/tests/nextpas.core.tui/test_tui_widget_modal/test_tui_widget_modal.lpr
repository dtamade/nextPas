program test_tui_widget_modal;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base, nextpas.core.base.utils,
  nextpas.core.tui.base, nextpas.core.tui.color, nextpas.core.tui.style,
  nextpas.core.tui.buffer, nextpas.core.tui.widget.modal,
  nextpas.core.test;

var T: TTestSuite;

procedure TestNew;
begin Check(TModal.New <> nil, 'New'); end;

procedure TestWithSize;
begin Check(TModal.New.WithSize(40, 10) <> nil, 'WithSize'); end;

procedure TestWithSizePercent;
begin Check(TModal.New.WithSizePercent(50, 30) <> nil, 'WithSizePercent'); end;

procedure TestWithDimBackground;
begin Check(TModal.New.WithDimBackground(True) <> nil, 'WithDimBackground'); end;

procedure TestWithStyle;
var S: TStyle;
begin S.Fg := IndexedColor(1); Check(TModal.New.WithStyle(S) <> nil, 'WithStyle'); end;

procedure TestWithVisible;
begin Check(TModal.New.WithVisible(True) <> nil, 'WithVisible'); end;

procedure TestRender;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 40, 20); B := TBuffer.CreateEmpty(A);
  TModal.New.WithSize(20, 5).WithVisible(True).Render(A, B);
  Check(True, 'Render');
end;

procedure TestRenderNotVisible;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 40, 20); B := TBuffer.CreateEmpty(A);
  TModal.New.WithVisible(False).Render(A, B);
  Check(True, 'Render not visible');
end;

procedure TestBuilderChaining;
var S: TStyle;
begin
  S.Fg := IndexedColor(1);
  Check(TModal.New.WithSize(60, 20).WithDimBackground(True).WithStyle(S).WithVisible(True) <> nil, 'chain');
end;

begin
  T := TTestSuite.Create('tui_widget_modal');
  T.Test('New', @TestNew);
  T.Test('WithSize', @TestWithSize);
  T.Test('WithSizePercent', @TestWithSizePercent);
  T.Test('WithDimBackground', @TestWithDimBackground);
  T.Test('WithStyle', @TestWithStyle);
  T.Test('WithVisible', @TestWithVisible);
  T.Test('Render', @TestRender);
  T.Test('Render not visible', @TestRenderNotVisible);
  T.Test('Builder chaining', @TestBuilderChaining);
  if not T.Run then Halt(1);
end.
