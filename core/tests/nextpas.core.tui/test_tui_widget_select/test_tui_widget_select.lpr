program test_tui_widget_select;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base, nextpas.core.base.utils,
  nextpas.core.tui.base, nextpas.core.tui.color, nextpas.core.tui.style,
  nextpas.core.tui.buffer, nextpas.core.tui.widget.select,
  nextpas.core.test;

var T: TTestSuite;

procedure TestStateEmpty;
var S: TSelectState;
begin S := TSelectState.Empty; Check(not S.Open, 'closed'); Check(S.Selected = -1, 'selected -1'); end;

procedure TestStateToggle;
var S: TSelectState;
begin
  S := TSelectState.Empty; S.Toggle; Check(S.Open, 'open'); S.Toggle; Check(not S.Open, 'closed');
end;

procedure TestStateMoveDown;
var S: TSelectState;
begin
  S := TSelectState.Empty; S.Open := True; S.HighlightIdx := 0;
  S.MoveDown(5); Check(S.HighlightIdx = 1, 'down1');
  S.MoveDown(5); Check(S.HighlightIdx = 2, 'down2');
end;

procedure TestStateMoveUp;
var S: TSelectState;
begin
  S := TSelectState.Empty; S.Open := True; S.HighlightIdx := 3;
  S.MoveUp; Check(S.HighlightIdx = 2, 'up1');
end;

procedure TestStateMoveUpBoundary;
var S: TSelectState;
begin
  S := TSelectState.Empty; S.Open := True; S.HighlightIdx := 0;
  S.MoveUp; Check(S.HighlightIdx = 0, 'boundary');
end;

procedure TestStateConfirm;
var S: TSelectState;
begin
  S := TSelectState.Empty; S.Open := True; S.HighlightIdx := 2;
  S.Confirm; Check(not S.Open, 'closed'); Check(S.Selected = 2, 'selected');
end;

procedure TestNew;
begin Check(TSelect.New(['A', 'B', 'C']) <> nil, 'New'); end;

procedure TestWithPlaceholder;
begin Check(TSelect.New(['A']).WithPlaceholder('Pick...') <> nil, 'WithPlaceholder'); end;

procedure TestWithWidth;
begin Check(TSelect.New(['A']).WithWidth(30) <> nil, 'WithWidth'); end;

procedure TestWithMaxDropHeight;
begin Check(TSelect.New(['A']).WithMaxDropHeight(5) <> nil, 'WithMaxDropHeight'); end;

procedure TestWithStyle;
var S: TStyle;
begin S.Fg := IndexedColor(1); Check(TSelect.New(['A']).WithStyle(S) <> nil, 'WithStyle'); end;

procedure TestWithHighlightStyle;
var S: TStyle;
begin S.Fg := IndexedColor(2); Check(TSelect.New(['A']).WithHighlightStyle(S) <> nil, 'WithHighlightStyle'); end;

procedure TestRender;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 20, 3);
  B := TBuffer.CreateEmpty(A);
  try
    TSelect.New(['A', 'B']).Render(A, B);
    Check(True, 'Render');
  finally
    B.Free;
  end;
end;

procedure TestRenderStateful;
var B: TBuffer; A: TRect; S: TSelectState;
begin
  A := TRect.Make(0, 0, 20, 8);
  B := TBuffer.CreateEmpty(A);
  try
    S := TSelectState.Empty;
    TSelect.New(['A', 'B', 'C']).RenderStateful(A, B, S);
    Check(True, 'RenderStateful');
  finally
    B.Free;
  end;
end;

procedure TestRenderEmpty;
var B: TBuffer; A: TRect; S: TSelectState;
begin
  A := TRect.Make(0, 0, 15, 3);
  B := TBuffer.CreateEmpty(A);
  try
    S := TSelectState.Empty;
    TSelect.New(['X']).RenderStateful(A, B, S);
    Check(True, 'Render empty select');
  finally
    B.Free;
  end;
end;

procedure TestRenderSmallArea;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 3, 1);
  B := TBuffer.CreateEmpty(A);
  try
    TSelect.New(['A']).Render(A, B);
    Check(True, 'Render in small area');
  finally
    B.Free;
  end;
end;

procedure TestStateMoveDownBoundary;
var S: TSelectState;
begin
  S := TSelectState.Empty;
  S.Open := True;
  S.HighlightIdx := 0;
  S.MoveDown(2);
  S.MoveDown(2);
  S.MoveDown(2);
  Check(S.HighlightIdx <= 2, 'Should not exceed item count');
end;

procedure TestStateConfirmWithoutOpen;
var S: TSelectState;
begin
  S := TSelectState.Empty;
  S.HighlightIdx := 1;
  S.Confirm;
  Check(S.Selected = 1, 'Should confirm even when closed');
end;

procedure TestBuilderChaining;
var S1, S2: TStyle;
begin
  S1.Fg := IndexedColor(1); S2.Fg := IndexedColor(2);
  Check(TSelect.New(['X', 'Y']).WithPlaceholder('Pick').WithWidth(25).WithMaxDropHeight(5).WithStyle(S1).WithHighlightStyle(S2) <> nil, 'chain');
end;

{ PH33 P3：数据更新面——SetItems 原地替换选项（闭合态首行显示选中项） }
procedure TestSelectSetItems;
var LS: ISelect; LBuf: TBuffer; LState: TSelectState; LRow: AnsiString;
begin
  LS := TSelect.New(['alpha', 'beta']);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 20, 5));
  try
    LS.SetItems(['delta', 'gamma']);
    LState := TSelectState.Empty;
    LState.Selected := 0;  { 闭合态首行显示选中项 }
    LS.RenderStateful(TRect.Make(0, 0, 20, 5), LBuf, LState);
    LRow := LBuf.RowAsString(0);
    Check(Pos('delta', LRow) > 0, 'closed state shows new selected delta');
    Check(Pos('alpha', LRow) = 0, 'old alpha gone');
  finally LBuf.Free; end;
end;

procedure TestSelectWithItemsChaining;
var LS: ISelect;
begin
  LS := TSelect.New(['a']).WithItems(['x', 'y', 'z']);
  Check(LS <> nil, 'WithItems chains and returns interface');
end;

begin
  T := TTestSuite.Create('tui_widget_select');
  T.Test('StateEmpty', @TestStateEmpty);
  T.Test('StateToggle', @TestStateToggle);
  T.Test('StateMoveDown', @TestStateMoveDown);
  T.Test('StateMoveUp', @TestStateMoveUp);
  T.Test('StateMoveUpBoundary', @TestStateMoveUpBoundary);
  T.Test('StateConfirm', @TestStateConfirm);
  T.Test('New', @TestNew);
  T.Test('WithPlaceholder', @TestWithPlaceholder);
  T.Test('WithWidth', @TestWithWidth);
  T.Test('WithMaxDropHeight', @TestWithMaxDropHeight);
  T.Test('WithStyle', @TestWithStyle);
  T.Test('WithHighlightStyle', @TestWithHighlightStyle);
  T.Test('Render', @TestRender);
  T.Test('RenderStateful', @TestRenderStateful);
  T.Test('Builder chaining', @TestBuilderChaining);
  T.Test('Render empty', @TestRenderEmpty);
  T.Test('Render small area', @TestRenderSmallArea);
  T.Test('StateMoveDown boundary', @TestStateMoveDownBoundary);
  T.Test('StateConfirm without open', @TestStateConfirmWithoutOpen);
  T.Test('SetItems in-place update (PH33 P3)', @TestSelectSetItems);
  T.Test('WithItems chaining (PH33 P3)', @TestSelectWithItemsChaining);
  if not T.Run then Halt(1);
end.
