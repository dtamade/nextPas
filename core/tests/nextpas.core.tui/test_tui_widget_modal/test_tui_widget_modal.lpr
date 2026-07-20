program test_tui_widget_modal;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base, nextpas.core.base.utils,
  nextpas.core.tui.base, nextpas.core.tui.color, nextpas.core.tui.modifier,
  nextpas.core.tui.style, nextpas.core.tui.cell, nextpas.core.tui.buffer,
  nextpas.core.tui.widget.modal, nextpas.core.test;

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
  try
    TModal.New.WithSize(20, 5).WithVisible(True).Render(A, B);
    Check(True, 'Render');
  finally B.Free; end;
end;

procedure TestRenderNotVisible;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 40, 20); B := TBuffer.CreateEmpty(A);
  try
    TModal.New.WithVisible(False).Render(A, B);
    Check(True, 'Render not visible');
  finally B.Free; end;
end;

procedure TestBuilderChaining;
var S: TStyle;
begin
  S.Fg := IndexedColor(1);
  Check(TModal.New.WithSize(60, 20).WithDimBackground(True).WithStyle(S).WithVisible(True) <> nil, 'chain');
end;

procedure TestContentAreaCentered;
var M: IModal; C, R: TRect;
begin
  M := TModal.New.WithSize(10, 6);
  C := TRect.Make(0, 0, 40, 20);
  R := M.ContentArea(C);
  CheckEqual(Int64(10), Int64(R.Width), 'centered w');
  CheckEqual(Int64(6), Int64(R.Height), 'centered h');
  CheckEqual(Int64(15), Int64(R.X), 'centered x');
  CheckEqual(Int64(7), Int64(R.Y), 'centered y');
end;

procedure TestContentAreaPercent;
var M: IModal; C, R: TRect;
begin
  M := TModal.New.WithSizePercent(50, 50);
  C := TRect.Make(0, 0, 40, 20);
  R := M.ContentArea(C);
  CheckEqual(Int64(20), Int64(R.Width), 'pct w');
  CheckEqual(Int64(10), Int64(R.Height), 'pct h');
  CheckEqual(Int64(10), Int64(R.X), 'pct x');
  CheckEqual(Int64(5), Int64(R.Y), 'pct y');
end;

procedure TestContentAreaOversize;
var M: IModal; C, R: TRect;
begin
  M := TModal.New.WithSize(100, 100);
  C := TRect.Make(0, 0, 40, 20);
  R := M.ContentArea(C);
  CheckEqual(Int64(40), Int64(R.Width), 'clip w');
  CheckEqual(Int64(20), Int64(R.Height), 'clip h');
end;

procedure TestContentAreaMinimum;
var M: IModal; C, R: TRect;
begin
  M := TModal.New.WithSize(0, 0);
  C := TRect.Make(0, 0, 40, 20);
  R := M.ContentArea(C);
  Check(R.Width >= 1, 'min w >= 1');
  Check(R.Height >= 1, 'min h >= 1');
end;

procedure TestContentAreaSmallContainer;
var M: IModal; C, R: TRect;
begin
  M := TModal.New.WithSize(20, 10);
  C := TRect.Make(5, 5, 3, 2);
  R := M.ContentArea(C);
  Check(R.Width <= 3, 'small clip w');
  Check(R.Height <= 2, 'small clip h');
end;

procedure TestDimBackgroundApplied;
var B: TBuffer; A: TRect; LCell: PCell;
begin
  A := TRect.Make(0, 0, 10, 5); B := TBuffer.CreateEmpty(A);
  try
    TModal.New.WithSize(4, 2).WithDimBackground(True).WithVisible(True).Render(A, B);
    LCell := B.CellAt(0, 0);
    Check(LCell <> nil, 'cell exists');
    Check(mbDim in LCell^.Modifier, 'dim applied');
  finally B.Free; end;
end;

procedure TestRenderEmptyArea;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 0, 0); B := TBuffer.CreateEmpty(A);
  try
    TModal.New.WithSize(10, 5).WithVisible(True).Render(A, B);
    Check(True, 'empty area no crash');
  finally B.Free; end;
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
  T.Test('ContentArea centered', @TestContentAreaCentered);
  T.Test('ContentArea percent', @TestContentAreaPercent);
  T.Test('ContentArea oversize clips', @TestContentAreaOversize);
  T.Test('ContentArea minimum 1x1', @TestContentAreaMinimum);
  T.Test('ContentArea small container', @TestContentAreaSmallContainer);
  T.Test('Dim background applied', @TestDimBackgroundApplied);
  T.Test('Render empty area', @TestRenderEmptyArea);
  if not T.Run then Halt(1);
end.
