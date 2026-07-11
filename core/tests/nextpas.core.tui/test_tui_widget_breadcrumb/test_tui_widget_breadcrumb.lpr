program test_tui_widget_breadcrumb;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.buffer,
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
  LCrumb.Render(LArea, LBuf);
  Check(True, 'Should render with custom separator');
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
  LArea := TRect.Make(0, 0, 40, 1);
  LCrumb.Render(LArea, LBuf);
  Check(True, 'Should render breadcrumb');
end;

procedure TestBreadcrumbRenderEmpty;
var
  LCrumb: IBreadcrumb;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LCrumb := TBreadcrumb.New([]);
  LArea := TRect.Make(0, 0, 20, 1); LBuf := TBuffer.CreateEmpty(LArea);
  LArea := TRect.Make(0, 0, 20, 1);
  LCrumb.Render(LArea, LBuf);
  Check(True, 'Should render empty breadcrumb');
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
  if not T.Run then Halt(1);
end.
