program test_tui_widget_popover;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.popover,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestPopoverAnchorEnum;
begin
  Check(Ord(paAbove) = 0, 'paAbove should be 0');
  Check(Ord(paBelow) = 1, 'paBelow should be 1');
  Check(Ord(paLeft) = 2, 'paLeft should be 2');
  Check(Ord(paRight) = 3, 'paRight should be 3');
end;

procedure TestPopoverStateHidden;
var
  LState: TPopoverState;
begin
  LState := TPopoverState.Hidden;
  Check(not LState.Visible, 'Hidden state should not be visible');
  Check(LState.Selected = 0, 'Hidden state selected should be 0');
end;

procedure TestPopoverStateShow;
var
  LState: TPopoverState;
begin
  LState := TPopoverState.Hidden;
  LState.Show;
  Check(LState.Visible, 'State should be visible after Show');
end;

procedure TestPopoverStateHide;
var
  LState: TPopoverState;
begin
  LState := TPopoverState.Hidden;
  LState.Show;
  LState.Hide;
  Check(not LState.Visible, 'State should not be visible after Hide');
end;

procedure TestPopoverNew;
var
  LPopover: IPopover;
begin
  LPopover := TPopover.New(['Item 1', 'Item 2', 'Item 3']);
  Check(LPopover <> nil, 'New popover should not be nil');
end;

procedure TestPopoverNewEmpty;
var
  LPopover: IPopover;
begin
  LPopover := TPopover.New([]);
  Check(LPopover <> nil, 'New empty popover should not be nil');
end;

procedure TestPopoverWithWidth;
var
  LPopover: IPopover;
begin
  LPopover := TPopover.New(['Test']);
  LPopover := LPopover.WithWidth(20);
  Check(LPopover <> nil, 'WithWidth should return popover');
end;

procedure TestPopoverWithMaxHeight;
var
  LPopover: IPopover;
begin
  LPopover := TPopover.New(['Test']);
  LPopover := LPopover.WithMaxHeight(10);
  Check(LPopover <> nil, 'WithMaxHeight should return popover');
end;

procedure TestPopoverWithAnchor;
var
  LPopover: IPopover;
begin
  LPopover := TPopover.New(['Test']);
  LPopover := LPopover.WithAnchor(paBelow);
  Check(LPopover <> nil, 'WithAnchor should return popover');
end;

procedure TestPopoverWithStyle;
var
  LPopover: IPopover;
  LStyle: TStyle;
begin
  LPopover := TPopover.New(['Test']);
  LStyle.Fg := IndexedColor(1);
  LPopover := LPopover.WithStyle(LStyle);
  Check(LPopover <> nil, 'WithStyle should return popover');
end;

procedure TestPopoverWithHighlightStyle;
var
  LPopover: IPopover;
  LStyle: TStyle;
begin
  LPopover := TPopover.New(['Test']);
  LStyle.Fg := IndexedColor(2);
  LPopover := LPopover.WithHighlightStyle(LStyle);
  Check(LPopover <> nil, 'WithHighlightStyle should return popover');
end;

procedure TestPopoverWithBorder;
var
  LPopover: IPopover;
begin
  LPopover := TPopover.New(['Test']);
  LPopover := LPopover.WithBorder(True);
  Check(LPopover <> nil, 'WithBorder should return popover');
end;

procedure TestPopoverRender;
var
  LPopover: IPopover;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  LPopover := TPopover.New(['Item 1', 'Item 2']);
  LArea := TRect.Make(0, 0, 20, 10);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LPopover.Render(LArea, LBuffer);
    Check(True, 'Render should not raise exception');
  finally
    LBuffer.Free;
  end;
end;

procedure TestPopoverRenderStateful;
var
  LPopover: IPopover;
  LBuffer: TBuffer;
  LArea, LAnchor: TRect;
  LState: TPopoverState;
begin
  LPopover := TPopover.New(['Item 1', 'Item 2', 'Item 3']);
  LArea := TRect.Make(0, 0, 30, 15);
  LAnchor := TRect.Make(5, 5, 5, 1);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LState := TPopoverState.Hidden;
    LState.Show;
    LPopover.RenderStateful(LAnchor, LArea, LBuffer, LState);
    Check(True, 'RenderStateful should not raise exception');
  finally
    LBuffer.Free;
  end;
end;

procedure TestPopoverBuilderChaining;
var
  LPopover: IPopover;
  LStyle: TStyle;
begin
  LPopover := TPopover.New(['Item 1', 'Item 2']);
  LStyle.Fg := IndexedColor(1);
  LPopover := LPopover
    .WithWidth(20)
    .WithMaxHeight(10)
    .WithAnchor(paBelow)
    .WithStyle(LStyle)
    .WithHighlightStyle(LStyle)
    .WithBorder(True);
  Check(LPopover <> nil, 'Builder chaining should work');
end;

procedure TestPopoverRenderHidden;
var
  LPopover: IPopover;
  LBuffer: TBuffer;
  LArea, LAnchor: TRect;
  LState: TPopoverState;
begin
  LPopover := TPopover.New(['Item 1']);
  LArea := TRect.Make(0, 0, 20, 10);
  LAnchor := TRect.Make(5, 5, 5, 1);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LState := TPopoverState.Hidden;
    LPopover.RenderStateful(LAnchor, LArea, LBuffer, LState);
    Check(True, 'Render hidden popover should not raise');
  finally
    LBuffer.Free;
  end;
end;

procedure TestPopoverRenderEmpty;
var
  LPopover: IPopover;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  LPopover := TPopover.New([]);
  LArea := TRect.Make(0, 0, 15, 8);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LPopover.Render(LArea, LBuffer);
    Check(True, 'Render empty popover should not raise');
  finally
    LBuffer.Free;
  end;
end;

procedure TestPopoverRenderSmallArea;
var
  LPopover: IPopover;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  LPopover := TPopover.New(['X']);
  LArea := TRect.Make(0, 0, 3, 2);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LPopover.Render(LArea, LBuffer);
    Check(True, 'Render in small area should not raise');
  finally
    LBuffer.Free;
  end;
end;

procedure TestPopoverStateShowHideMultiple;
var
  LState: TPopoverState;
begin
  LState := TPopoverState.Hidden;
  LState.Show;
  Check(LState.Visible, 'Should be visible');
  LState.Hide;
  Check(not LState.Visible, 'Should be hidden');
  LState.Show;
  Check(LState.Visible, 'Should be visible again');
end;

{ PH33 P3：数据更新面——SetItems 原地替换弹层项（显示态绘制） }
procedure TestPopoverSetItems;
var LP: IPopover; LBuf: TBuffer; LArea, LAnchor: TRect;
    LState: TPopoverState; LAll: AnsiString; I: Integer;
begin
  LP := TPopover.New(['alpha', 'beta']);
  LArea := TRect.Make(0, 0, 30, 15);
  LAnchor := TRect.Make(2, 2, 8, 1);
  LBuf := TBuffer.CreateEmpty(LArea);
  try
    LP.SetItems(['delta', 'gamma']);
    LState := TPopoverState.Hidden;
    LState.Show;
    LP.RenderStateful(LAnchor, LArea, LBuf, LState);
    LAll := '';
    for I := 0 to 14 do LAll := LAll + LBuf.RowAsString(I);
    Check(Pos('gamma', LAll) > 0, 'new item gamma visible');
    Check(Pos('alpha', LAll) = 0, 'old alpha gone');
  finally LBuf.Free; end;
end;

procedure TestPopoverWithItemsChaining;
var LP: IPopover;
begin
  LP := TPopover.New(['a']).WithItems(['x', 'y', 'z']);
  Check(LP <> nil, 'WithItems chains and returns interface');
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.popover');
  T.Test('TPopoverAnchor enum', @TestPopoverAnchorEnum);
  T.Test('TPopoverState.Hidden', @TestPopoverStateHidden);
  T.Test('TPopoverState.Show', @TestPopoverStateShow);
  T.Test('TPopoverState.Hide', @TestPopoverStateHide);
  T.Test('TPopover.New', @TestPopoverNew);
  T.Test('TPopover.New empty', @TestPopoverNewEmpty);
  T.Test('TPopover.WithWidth', @TestPopoverWithWidth);
  T.Test('TPopover.WithMaxHeight', @TestPopoverWithMaxHeight);
  T.Test('TPopover.WithAnchor', @TestPopoverWithAnchor);
  T.Test('TPopover.WithStyle', @TestPopoverWithStyle);
  T.Test('TPopover.WithHighlightStyle', @TestPopoverWithHighlightStyle);
  T.Test('TPopover.WithBorder', @TestPopoverWithBorder);
  T.Test('TPopover.Render', @TestPopoverRender);
  T.Test('TPopover.RenderStateful', @TestPopoverRenderStateful);
  T.Test('TPopover builder chaining', @TestPopoverBuilderChaining);
  T.Test('TPopover render hidden', @TestPopoverRenderHidden);
  T.Test('TPopover render empty', @TestPopoverRenderEmpty);
  T.Test('TPopover render small area', @TestPopoverRenderSmallArea);
  T.Test('TPopoverState show hide multiple', @TestPopoverStateShowHideMultiple);
  T.Test('SetItems in-place update (PH33 P3)', @TestPopoverSetItems);
  T.Test('WithItems chaining (PH33 P3)', @TestPopoverWithItemsChaining);
  if not T.Run then Halt(1);
end.
