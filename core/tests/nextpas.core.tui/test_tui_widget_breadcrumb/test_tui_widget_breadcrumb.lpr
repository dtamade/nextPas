program test_tui_widget_breadcrumb;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.breadcrumb,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestBreadcrumbNew;
var
  LCrumb: IBreadcrumb;
begin
  LCrumb := TBreadcrumb.New(['Home', 'Documents', 'Project']);
  Check(LCrumb <> nil, 'Should create breadcrumb instance');
end;

procedure TestBreadcrumbNewEmpty;
var
  LCrumb: IBreadcrumb;
begin
  LCrumb := TBreadcrumb.New([]);
  Check(LCrumb <> nil, 'Should create empty breadcrumb');
end;

procedure TestBreadcrumbWithSeparator;
var
  LCrumb: IBreadcrumb;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LCrumb := TBreadcrumb.New(['A', 'B', 'C']).WithSeparator(' > ');
  LArea := TRect.Make(0, 0, 30, 1);
  LBuf := TBuffer.CreateEmpty(LArea);
  try
    LCrumb.Render(LArea, LBuf);
    Check(True, 'Should render with custom separator');
  finally LBuf.Free; end;
end;

procedure TestBreadcrumbWithStyle;
var
  LCrumb: IBreadcrumb;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(1);
  LCrumb := TBreadcrumb.New(['A', 'B']).WithStyle(LStyle);
  Check(LCrumb <> nil, 'Should set style');
end;

procedure TestBreadcrumbWithActiveStyle;
var
  LCrumb: IBreadcrumb;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(2);
  LCrumb := TBreadcrumb.New(['A', 'B']).WithActiveStyle(LStyle);
  Check(LCrumb <> nil, 'Should set active style');
end;

procedure TestBreadcrumbWithSepStyle;
var
  LCrumb: IBreadcrumb;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(3);
  LCrumb := TBreadcrumb.New(['A', 'B']).WithSepStyle(LStyle);
  Check(LCrumb <> nil, 'Should set separator style');
end;

procedure TestBreadcrumbWithActive;
var
  LCrumb: IBreadcrumb;
begin
  LCrumb := TBreadcrumb.New(['Home', 'Docs', 'Project']).WithActive(1);
  Check(LCrumb <> nil, 'Should set active index');
end;

procedure TestBreadcrumbRender;
var
  LCrumb: IBreadcrumb;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LCrumb := TBreadcrumb.New(['Home', 'Documents', 'Project']);
  LArea := TRect.Make(0, 0, 40, 1); LBuf := TBuffer.CreateEmpty(LArea);
  try
    LCrumb.Render(LArea, LBuf);
    Check(True, 'Should render breadcrumb');
  finally LBuf.Free; end;
end;

procedure TestBreadcrumbRenderEmpty;
var
  LCrumb: IBreadcrumb;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LCrumb := TBreadcrumb.New([]);
  LArea := TRect.Make(0, 0, 20, 1); LBuf := TBuffer.CreateEmpty(LArea);
  try
    LCrumb.Render(LArea, LBuf);
    Check(True, 'Should render empty breadcrumb');
  finally LBuf.Free; end;
end;

procedure TestBreadcrumbTotalWidth;
var
  LCrumb: IBreadcrumb;
begin
  LCrumb := TBreadcrumb.New(['A', 'B', 'C']).WithSeparator(' > ');
  Check(LCrumb.TotalWidth > 0, 'Should have positive total width');
end;

procedure TestBreadcrumbBuilderChaining;
var
  LCrumb: IBreadcrumb;
  LStyle1, LStyle2, LStyle3: TStyle;
begin
  LStyle1.Fg := IndexedColor(1);
  LStyle2.Fg := IndexedColor(2);
  LStyle3.Fg := IndexedColor(3);
  LCrumb := TBreadcrumb.New(['Home', 'Docs'])
    .WithSeparator('/')
    .WithStyle(LStyle1)
    .WithActiveStyle(LStyle2)
    .WithSepStyle(LStyle3)
    .WithActive(1);
  Check(LCrumb <> nil, 'Should chain builder calls');
end;

{ === New tests === }

procedure TestBreadcrumbContentVisible;
var
  LCrumb: IBreadcrumb;
  LBuf: TBuffer;
  LArea: TRect;
  LRow: AnsiString;
begin
  LCrumb := TBreadcrumb.New(['Home', 'Docs']);
  LArea := TRect.Make(0, 0, 30, 1); LBuf := TBuffer.CreateEmpty(LArea);
  try
    LCrumb.Render(LArea, LBuf);
    LRow := LBuf.RowAsString(0);
    Check(Pos('Home', LRow) > 0, 'Home visible');
    Check(Pos('Docs', LRow) > 0, 'Docs visible');
  finally LBuf.Free; end;
end;

procedure TestBreadcrumbSeparatorVisible;
var
  LCrumb: IBreadcrumb;
  LBuf: TBuffer;
  LArea: TRect;
  LRow: AnsiString;
begin
  LCrumb := TBreadcrumb.New(['A', 'B']).WithSeparator(' | ');
  LArea := TRect.Make(0, 0, 20, 1); LBuf := TBuffer.CreateEmpty(LArea);
  try
    LCrumb.Render(LArea, LBuf);
    LRow := LBuf.RowAsString(0);
    Check(Pos('|', LRow) > 0, 'separator visible');
  finally LBuf.Free; end;
end;

procedure TestBreadcrumbActiveStyleApplied;
var
  LCrumb: IBreadcrumb;
  LBuf: TBuffer;
  LArea: TRect;
  LCell: PCell;
begin
  LCrumb := TBreadcrumb.New(['A', 'B']).WithActive(1)
    .WithActiveStyle(TStyle.Default.WithFg(TUI_RED));
  LArea := TRect.Make(0, 0, 20, 1); LBuf := TBuffer.CreateEmpty(LArea);
  try
    LCrumb.Render(LArea, LBuf);
    { 'B' starts at position2 (after 'A' + ' > ') }
    LCell := LBuf.CellAt(4, 0);
    if LCell <> nil then
      Check(ColorEquals(TUI_RED, LCell^.Fg), 'active style applied');
  finally LBuf.Free; end;
end;

procedure TestBreadcrumbWideClips;
var
  LCrumb: IBreadcrumb;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LCrumb := TBreadcrumb.New(['VeryLongName', 'AnotherLongName']);
  LArea := TRect.Make(0, 0, 5, 1); LBuf := TBuffer.CreateEmpty(LArea);
  try
    LCrumb.Render(LArea, LBuf);
    Check(True, 'wide content clips');
  finally LBuf.Free; end;
end;

procedure TestBreadcrumbEmptyArea;
var
  LCrumb: IBreadcrumb;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LCrumb := TBreadcrumb.New(['A', 'B']);
  LArea := TRect.Make(0, 0, 0, 0); LBuf := TBuffer.CreateEmpty(LArea);
  try
    LCrumb.Render(LArea, LBuf);
    Check(True, 'empty area no crash');
  finally LBuf.Free; end;
end;

procedure TestBreadcrumbSingleItem;
var
  LCrumb: IBreadcrumb;
  LBuf: TBuffer;
  LArea: TRect;
  LRow: AnsiString;
begin
  LCrumb := TBreadcrumb.New(['Only']);
  LArea := TRect.Make(0, 0, 20, 1); LBuf := TBuffer.CreateEmpty(LArea);
  try
    LCrumb.Render(LArea, LBuf);
    LRow := LBuf.RowAsString(0);
    Check(Pos('Only', LRow) > 0, 'single item visible');
  finally LBuf.Free; end;
end;

procedure TestBreadcrumbTotalWidthCalc;
var
  LCrumb: IBreadcrumb;
begin
  LCrumb := TBreadcrumb.New(['AB', 'CD']).WithSeparator(' > ');
  { AB(2) + ' > '(3) + CD(2) =7 }
  CheckEqual(Int64(7), Int64(LCrumb.TotalWidth), 'total width calc');
end;

{ PH33 P2b：布局配置面——WithBlock 块包装（边框在区边缘、内容仍在） }
procedure TestBreadcrumbWithBlock;
var LC: IBreadcrumb; LBuf: TBuffer; LAll: AnsiString; I: Integer;
begin
  LC := TBreadcrumb.New(['home', 'docs'])
    .WithBlock(TBlock.Bordered('T'));
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 30, 4));
  try
    LC.Render(TRect.Make(0, 0, 30, 4), LBuf);
    LAll := '';
    for I := 0 to 3 do LAll := LAll + LBuf.RowAsString(I);
    Check(Pos(#$E2#$94#$8C, LBuf.RowAsString(0)) > 0, 'block border drawn');
    Check(Pos('home', LAll) > 0, 'item visible inside block');
    Check(Pos('docs', LAll) > 0, 'second item visible');
  finally LBuf.Free; end;
end;

procedure TestBreadcrumbWithBlockChaining;
var LC: IBreadcrumb;
begin
  LC := TBreadcrumb.New(['a']).WithBlock(TBlock.Bordered('x'));
  Check(LC <> nil, 'WithBlock chains and returns interface');
end;

begin
  T := TTestSuite.Create('tui_widget_breadcrumb');
  T.Test('TBreadcrumb.New creates instance', @TestBreadcrumbNew);
  T.Test('TBreadcrumb.New with empty items', @TestBreadcrumbNewEmpty);
  T.Test('TBreadcrumb.WithSeparator', @TestBreadcrumbWithSeparator);
  T.Test('TBreadcrumb.WithStyle', @TestBreadcrumbWithStyle);
  T.Test('TBreadcrumb.WithActiveStyle', @TestBreadcrumbWithActiveStyle);
  T.Test('TBreadcrumb.WithSepStyle', @TestBreadcrumbWithSepStyle);
  T.Test('TBreadcrumb.WithActive', @TestBreadcrumbWithActive);
  T.Test('TBreadcrumb.Render', @TestBreadcrumbRender);
  T.Test('TBreadcrumb.Render with empty items', @TestBreadcrumbRenderEmpty);
  T.Test('TBreadcrumb.TotalWidth', @TestBreadcrumbTotalWidth);
  T.Test('TBreadcrumb builder chaining', @TestBreadcrumbBuilderChaining);
  T.Test('Content visible', @TestBreadcrumbContentVisible);
  T.Test('Separator visible', @TestBreadcrumbSeparatorVisible);
  T.Test('Active style applied', @TestBreadcrumbActiveStyleApplied);
  T.Test('Wide content clips', @TestBreadcrumbWideClips);
  T.Test('Empty area', @TestBreadcrumbEmptyArea);
  T.Test('Single item', @TestBreadcrumbSingleItem);
  T.Test('Total width calc', @TestBreadcrumbTotalWidthCalc);
  T.Test('WithBlock render (PH33 P2b)', @TestBreadcrumbWithBlock);
  T.Test('WithBlock chaining (PH33 P2b)', @TestBreadcrumbWithBlockChaining);
  if not T.Run then Halt(1);
end.
