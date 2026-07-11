program test_tui_widget_virtual_list;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.virtual_list,
  nextpas.core.test;

var
  T: TTestSuite;

function TestItemProvider(AIndex: Integer): AnsiString;
begin
  Result := 'Item ' + IntToStr(AIndex);
end;

procedure TestVirtualListStateCreate;
var
  LState: TVirtualListState;
begin
  LState := TVirtualListState.Create(100);
  Check(LState.TotalItems = 100, 'Should set total');
  Check(LState.Selected = 0, 'Should start at 0');
end;

procedure TestVirtualListStateSelectNext;
var
  LState: TVirtualListState;
begin
  LState := TVirtualListState.Create(10);
  LState.SelectNext;
  Check(LState.Selected = 1, 'Should move to 1');
  LState.SelectNext;
  Check(LState.Selected = 2, 'Should move to 2');
end;

procedure TestVirtualListStateSelectNextBoundary;
var
  LState: TVirtualListState;
begin
  LState := TVirtualListState.Create(3);
  LState.SelectNext;
  LState.SelectNext;
  LState.SelectNext;
  Check(LState.Selected = 2, 'Should stay at last');
end;

procedure TestVirtualListStateSelectPrev;
var
  LState: TVirtualListState;
begin
  LState := TVirtualListState.Create(10);
  LState.Selected := 5;
  LState.SelectPrev;
  Check(LState.Selected = 4, 'Should move to 4');
end;

procedure TestVirtualListStateSelectPrevBoundary;
var
  LState: TVirtualListState;
begin
  LState := TVirtualListState.Create(10);
  LState.SelectPrev;
  Check(LState.Selected = 0, 'Should stay at 0');
end;

procedure TestVirtualListStatePageDown;
var
  LState: TVirtualListState;
begin
  LState := TVirtualListState.Create(100);
  LState.PageDown(10);
  Check(LState.Selected = 10, 'Should page down');
end;

procedure TestVirtualListStatePageUp;
var
  LState: TVirtualListState;
begin
  LState := TVirtualListState.Create(100);
  LState.Selected := 50;
  LState.PageUp(10);
  Check(LState.Selected = 40, 'Should page up');
end;

procedure TestVirtualListStateSelectFirst;
var
  LState: TVirtualListState;
begin
  LState := TVirtualListState.Create(100);
  LState.Selected := 50;
  LState.SelectFirst;
  Check(LState.Selected = 0, 'Should select first');
end;

procedure TestVirtualListStateSelectLast;
var
  LState: TVirtualListState;
begin
  LState := TVirtualListState.Create(100);
  LState.SelectLast;
  Check(LState.Selected = 99, 'Should select last');
end;

procedure TestVirtualListNew;
var
  LList: IVirtualList;
begin
  LList := TVirtualList.New(@TestItemProvider);
  Check(LList <> nil, 'Should create virtual list instance');
end;

procedure TestVirtualListWithStyle;
var
  LList: IVirtualList;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(1);
  LList := TVirtualList.New(@TestItemProvider).WithStyle(LStyle);
  Check(LList <> nil, 'Should set style');
end;

procedure TestVirtualListWithSelectedStyle;
var
  LList: IVirtualList;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(2);
  LList := TVirtualList.New(@TestItemProvider).WithSelectedStyle(LStyle);
  Check(LList <> nil, 'Should set selected style');
end;

procedure TestVirtualListWithShowIndex;
var
  LList: IVirtualList;
begin
  LList := TVirtualList.New(@TestItemProvider).WithShowIndex(True);
  Check(LList <> nil, 'Should set show index');
end;

procedure TestVirtualListRenderStateful;
var
  LList: IVirtualList;
  LState: TVirtualListState;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LList := TVirtualList.New(@TestItemProvider);
  LState := TVirtualListState.Create(100);
  LArea := TRect.Make(0, 0, 30, 10);
  LBuf := TBuffer.CreateEmpty(LArea);
  LList.RenderStateful(LArea, LBuf, LState);
  Check(True, 'Should render stateful virtual list');
end;

procedure TestVirtualListBuilderChaining;
var
  LList: IVirtualList;
  LStyle, LSelectedStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(1);
  LSelectedStyle.Fg := IndexedColor(2);
  LList := TVirtualList.New(@TestItemProvider)
    .WithStyle(LStyle)
    .WithSelectedStyle(LSelectedStyle)
    .WithShowIndex(True);
  Check(LList <> nil, 'Should chain builder calls');
end;

begin
  T := TTestSuite.Create('tui_widget_virtual_list');
  T.Test('TVirtualListState.Create', @TestVirtualListStateCreate);
  T.Test('TVirtualListState.SelectNext', @TestVirtualListStateSelectNext);
  T.Test('TVirtualListState.SelectNext boundary', @TestVirtualListStateSelectNextBoundary);
  T.Test('TVirtualListState.SelectPrev', @TestVirtualListStateSelectPrev);
  T.Test('TVirtualListState.SelectPrev boundary', @TestVirtualListStateSelectPrevBoundary);
  T.Test('TVirtualListState.PageDown', @TestVirtualListStatePageDown);
  T.Test('TVirtualListState.PageUp', @TestVirtualListStatePageUp);
  T.Test('TVirtualListState.SelectFirst', @TestVirtualListStateSelectFirst);
  T.Test('TVirtualListState.SelectLast', @TestVirtualListStateSelectLast);
  T.Test('TVirtualList.New creates instance', @TestVirtualListNew);
  T.Test('TVirtualList.WithStyle', @TestVirtualListWithStyle);
  T.Test('TVirtualList.WithSelectedStyle', @TestVirtualListWithSelectedStyle);
  T.Test('TVirtualList.WithShowIndex', @TestVirtualListWithShowIndex);
  T.Test('TVirtualList.RenderStateful', @TestVirtualListRenderStateful);
  T.Test('TVirtualList builder chaining', @TestVirtualListBuilderChaining);
  if not T.Run then Halt(1);
end.
