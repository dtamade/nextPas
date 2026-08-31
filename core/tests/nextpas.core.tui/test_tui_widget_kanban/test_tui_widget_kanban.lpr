program test_tui_widget_kanban;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.kanban,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestKanbanCardMake;
var
  LCard: TKanbanCard;
begin
  LCard := TKanbanCard.Make('Task 1');
  Check(LCard.Title = 'Task 1', 'Should set title');
end;

procedure TestKanbanCardWithTag;
var
  LCard: TKanbanCard;
begin
  LCard := TKanbanCard.Make('Bug fix').WithTag('urgent');
  Check(LCard.Tag = 'urgent', 'Should set tag');
end;

procedure TestKanbanStateEmpty;
var
  LState: TKanbanState;
begin
  LState := TKanbanState.Empty;
  Check(LState.ActiveCol = 0, 'Should start at column 0');
  Check(LState.ActiveCard = 0, 'Should start at card 0');
end;

procedure TestKanbanStateMoveRight;
var
  LState: TKanbanState;
begin
  LState := TKanbanState.Empty;
  LState.MoveRight(3);
  Check(LState.ActiveCol = 1, 'Should move to column 1');
  LState.MoveRight(3);
  Check(LState.ActiveCol = 2, 'Should move to column 2');
end;

procedure TestKanbanStateMoveLeft;
var
  LState: TKanbanState;
begin
  LState := TKanbanState.Empty;
  LState.ActiveCol := 2;
  LState.MoveLeft;
  Check(LState.ActiveCol = 1, 'Should move to column 1');
  LState.MoveLeft;
  Check(LState.ActiveCol = 0, 'Should move to column 0');
end;

procedure TestKanbanStateMoveLeftBoundary;
var
  LState: TKanbanState;
begin
  LState := TKanbanState.Empty;
  LState.MoveLeft;
  Check(LState.ActiveCol = 0, 'Should stay at column 0');
end;

procedure TestKanbanStateMoveDown;
var
  LState: TKanbanState;
begin
  LState := TKanbanState.Empty;
  LState.MoveDown(5);
  Check(LState.ActiveCard = 1, 'Should move to card 1');
end;

procedure TestKanbanStateMoveUp;
var
  LState: TKanbanState;
begin
  LState := TKanbanState.Empty;
  LState.ActiveCard := 3;
  LState.MoveUp;
  Check(LState.ActiveCard = 2, 'Should move to card 2');
end;

procedure TestKanbanNew;
var
  LKanban: IKanban;
begin
  LKanban := TKanban.New([
    MakeColumn('Todo', [TKanbanCard.Make('Task 1')]),
    MakeColumn('Doing', [TKanbanCard.Make('Task 2')]),
    MakeColumn('Done', [TKanbanCard.Make('Task 3')])
  ]);
  Check(LKanban <> nil, 'Should create kanban instance');
end;

procedure TestKanbanWithStyle;
var
  LKanban: IKanban;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(1);
  LKanban := TKanban.New([MakeColumn('Col', [])]).WithStyle(LStyle);
  Check(LKanban <> nil, 'Should set style');
end;

procedure TestKanbanWithHeaderStyle;
var
  LKanban: IKanban;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(2);
  LKanban := TKanban.New([MakeColumn('Col', [])]).WithHeaderStyle(LStyle);
  Check(LKanban <> nil, 'Should set header style');
end;

procedure TestKanbanWithCardStyle;
var
  LKanban: IKanban;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(3);
  LKanban := TKanban.New([MakeColumn('Col', [])]).WithCardStyle(LStyle);
  Check(LKanban <> nil, 'Should set card style');
end;

procedure TestKanbanWithActiveCardStyle;
var
  LKanban: IKanban;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(4);
  LKanban := TKanban.New([MakeColumn('Col', [])]).WithActiveCardStyle(LStyle);
  Check(LKanban <> nil, 'Should set active card style');
end;

procedure TestKanbanRenderStateful;
var
  LKanban: IKanban;
  LState: TKanbanState;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LKanban := TKanban.New([
    MakeColumn('Todo', [TKanbanCard.Make('Task 1')]),
    MakeColumn('Done', [TKanbanCard.Make('Task 2')])
  ]);
  LState := TKanbanState.Empty;
  LArea := TRect.Make(0, 0, 60, 10);
  LBuf := TBuffer.CreateEmpty(LArea);
  try
    LKanban.RenderStateful(LArea, LBuf, LState);
    Check(True, 'Should render stateful kanban');
  finally
    LBuf.Free;
  end;
end;

procedure TestKanbanRenderEmpty;
var
  LKanban: IKanban;
  LState: TKanbanState;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LKanban := TKanban.New([MakeColumn('Col', [])]);
  LState := TKanbanState.Empty;
  LArea := TRect.Make(0, 0, 30, 5);
  LBuf := TBuffer.CreateEmpty(LArea);
  try
    LKanban.RenderStateful(LArea, LBuf, LState);
    Check(True, 'Should render empty kanban');
  finally
    LBuf.Free;
  end;
end;

procedure TestKanbanRenderSmallArea;
var
  LKanban: IKanban;
  LState: TKanbanState;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LKanban := TKanban.New([MakeColumn('Col', [TKanbanCard.Make('Task')])]);
  LState := TKanbanState.Empty;
  LArea := TRect.Make(0, 0, 5, 2);
  LBuf := TBuffer.CreateEmpty(LArea);
  try
    LKanban.RenderStateful(LArea, LBuf, LState);
    Check(True, 'Should render in small area');
  finally
    LBuf.Free;
  end;
end;

procedure TestKanbanStateMoveDownBoundary;
var
  LState: TKanbanState;
begin
  LState := TKanbanState.Empty;
  LState.MoveDown(3);
  LState.MoveDown(3);
  LState.MoveDown(3);
  Check(LState.ActiveCard <= 3, 'Should not exceed card count');
end;

procedure TestKanbanStateMoveUpBoundary;
var
  LState: TKanbanState;
begin
  LState := TKanbanState.Empty;
  LState.MoveUp;
  Check(LState.ActiveCard = 0, 'Should stay at card 0');
end;

procedure TestKanbanBuilderChaining;
var
  LKanban: IKanban;
  LStyle, LHeaderStyle, LCardStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(1);
  LHeaderStyle.Fg := IndexedColor(2);
  LCardStyle.Fg := IndexedColor(3);
  LKanban := TKanban.New([
    MakeColumn('Backlog', [
      TKanbanCard.Make('Task 1').WithTag('feature'),
      TKanbanCard.Make('Task 2').WithTag('bug')
    ]),
    MakeColumn('In Progress', [TKanbanCard.Make('Task 3')]),
    MakeColumn('Done', [])
  ])
    .WithStyle(LStyle)
    .WithHeaderStyle(LHeaderStyle)
    .WithCardStyle(LCardStyle)
    .WithActiveCardStyle(LCardStyle);
  Check(LKanban <> nil, 'Should chain builder calls');
end;

{ PH33 P3：数据更新面——AddCard 向指定列追加卡片；列越界静默忽略 }
procedure TestKanbanAddCard;
var
  LKanban: IKanban;
  LState: TKanbanState;
  LBuf: TBuffer;
  LAll: AnsiString;
  I: Integer;
begin
  LKanban := TKanban.New([MakeColumn('Todo', []), MakeColumn('Done', [])]);
  LKanban.AddCard(0, TKanbanCard.Make('fresh-card'));
  { 越界/负索引静默忽略（对齐 MarkRead 惯例），不得崩溃也不得入列 }
  LKanban.AddCard(99, TKanbanCard.Make('dropped-x'));
  LKanban.AddCard(-1, TKanbanCard.Make('dropped-y'));
  LState := TKanbanState.Empty;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 60, 10));
  try
    LKanban.RenderStateful(TRect.Make(0, 0, 60, 10), LBuf, LState);
    LAll := '';
    for I := 0 to 9 do LAll := LAll + LBuf.RowAsString(I);
    Check(Pos('fresh-card', LAll) > 0, 'added card visible');
    Check(Pos('dropped-x', LAll) = 0, 'out-of-range col ignored');
    Check(Pos('dropped-y', LAll) = 0, 'negative col ignored');
  finally
    LBuf.Free;
  end;
end;

begin
  T := TTestSuite.Create('tui_widget_kanban');
  T.Test('TKanbanCard.Make', @TestKanbanCardMake);
  T.Test('TKanbanCard.WithTag', @TestKanbanCardWithTag);
  T.Test('TKanbanState.Empty', @TestKanbanStateEmpty);
  T.Test('TKanbanState.MoveRight', @TestKanbanStateMoveRight);
  T.Test('TKanbanState.MoveLeft', @TestKanbanStateMoveLeft);
  T.Test('TKanbanState.MoveLeft boundary', @TestKanbanStateMoveLeftBoundary);
  T.Test('TKanbanState.MoveDown', @TestKanbanStateMoveDown);
  T.Test('TKanbanState.MoveUp', @TestKanbanStateMoveUp);
  T.Test('TKanban.New creates instance', @TestKanbanNew);
  T.Test('TKanban.WithStyle', @TestKanbanWithStyle);
  T.Test('TKanban.WithHeaderStyle', @TestKanbanWithHeaderStyle);
  T.Test('TKanban.WithCardStyle', @TestKanbanWithCardStyle);
  T.Test('TKanban.WithActiveCardStyle', @TestKanbanWithActiveCardStyle);
  T.Test('TKanban.RenderStateful', @TestKanbanRenderStateful);
  T.Test('TKanban builder chaining', @TestKanbanBuilderChaining);
  T.Test('TKanban render empty', @TestKanbanRenderEmpty);
  T.Test('TKanban render small area', @TestKanbanRenderSmallArea);
  T.Test('TKanbanState.MoveDown boundary', @TestKanbanStateMoveDownBoundary);
  T.Test('TKanbanState.MoveUp boundary', @TestKanbanStateMoveUpBoundary);
  T.Test('AddCard append + out-of-range ignore (PH33 P3)', @TestKanbanAddCard);
  if not T.Run then Halt(1);
end.
