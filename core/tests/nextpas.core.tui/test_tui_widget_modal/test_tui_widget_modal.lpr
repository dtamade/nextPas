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

{ PH33 P2：边框开启且外框 ≥3×3 时 ContentArea = 居中区 内缩 1 }
procedure TestContentAreaBorderInset;
var M: IModal; R: TRect;
begin
  M := TModal.New.WithSize(10, 6).WithBorder(True);
  R := M.ContentArea(TRect.Make(0, 0, 40, 20));
  CheckEqual(Int64(8), Int64(R.Width), 'border inset w');
  CheckEqual(Int64(4), Int64(R.Height), 'border inset h');
  CheckEqual(Int64(16), Int64(R.X), 'border inset x');
  CheckEqual(Int64(8), Int64(R.Y), 'border inset y');
end;

{ PH33 P2：外框 <3×3 时退化——ContentArea = 外框本身 }
procedure TestContentAreaBorderTiny;
var M: IModal; R: TRect;
begin
  M := TModal.New.WithSize(2, 2).WithBorder(True);
  R := M.ContentArea(TRect.Make(0, 0, 40, 20));
  CheckEqual(Int64(2), Int64(R.Width), 'tiny keeps outer w');
  CheckEqual(Int64(2), Int64(R.Height), 'tiny keeps outer h');
end;

{ PH33 P2：WithTitle/WithBorder 渲染——边框角与标题落在外框顶行 }
procedure TestRenderTitleBorder;
var
  M: IModal;
  LBuf: TBuffer;
  LArea: TRect;
  LRow: AnsiString;
begin
  M := TModal.New.WithSize(20, 6).WithVisible(True)
    .WithDimBackground(False).WithBorder(True).WithTitle('Hi');
  LArea := TRect.Make(0, 0, 40, 12);
  LBuf := TBuffer.CreateEmpty(LArea);
  try
    M.Render(LArea, LBuf);
    LRow := LBuf.RowAsString(3);   { 外框 [10..29]x[3..8]，顶行 y=3 }
    Check(Pos('┌', LRow) > 0, 'top-left border glyph on outer top row');
    Check(Pos('Hi', LRow) > 0, 'title text on border top row');
  finally LBuf.Free; end;
end;

{ PH33 P2：默认无标题无边框 = 既有行为（不画边框角）}
procedure TestRenderDefaultNoBorder;
var
  M: IModal;
  LBuf: TBuffer;
  LArea: TRect;
begin
  M := TModal.New.WithSize(10, 4).WithVisible(True).WithDimBackground(False);
  LArea := TRect.Make(0, 0, 40, 12);
  LBuf := TBuffer.CreateEmpty(LArea);
  try
    M.Render(LArea, LBuf);
    Check(Pos('┌', LBuf.RowAsString(4)) = 0, 'default render draws no border');
  finally LBuf.Free; end;
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
  T.Test('ContentArea border inset (PH33 P2)', @TestContentAreaBorderInset);
  T.Test('ContentArea border tiny (PH33 P2)', @TestContentAreaBorderTiny);
  T.Test('Render title+border (PH33 P2)', @TestRenderTitleBorder);
  T.Test('Render default no border (PH33 P2)', @TestRenderDefaultNoBorder);
  T.Test('Dim background applied', @TestDimBackgroundApplied);
  T.Test('Render empty area', @TestRenderEmptyArea);
  if not T.Run then Halt(1);
end.
