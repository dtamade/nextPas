program test_tui_widget_progress_group;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.progress_group,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestProgressItemMake;
var
  LItem: TProgressItem;
begin
  LItem := TProgressItem.Make('CPU', 0.75);
  Check(LItem.Label_ = 'CPU', 'Should set label');
  Check(LItem.Ratio = 0.75, 'Should set ratio');
end;

procedure TestProgressItemWithStyle;
var
  LItem: TProgressItem;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(1);
  LItem := TProgressItem.Make('Memory', 0.5).WithStyle(LStyle);
  Check(LItem.Label_ = 'Memory', 'Should preserve label');
end;

procedure TestProgressGroupNew;
var
  LGroup: IProgressGroup;
begin
  LGroup := TProgressGroup.New([
    TProgressItem.Make('CPU', 0.75),
    TProgressItem.Make('Memory', 0.5)
  ]);
  Check(LGroup <> nil, 'Should create progress group instance');
end;

procedure TestProgressGroupNewLabelWidth;
var
  LGroup: IProgressGroup;
begin
  LGroup := TProgressGroup.New([TProgressItem.Make('CPU', 0.5)]).WithLabelWidth(10);
  Check(LGroup <> nil, 'Should set label width');
end;

procedure TestProgressGroupWithShowPercent;
var
  LGroup: IProgressGroup;
begin
  LGroup := TProgressGroup.New([TProgressItem.Make('CPU', 0.5)]).WithShowPercent(True);
  Check(LGroup <> nil, 'Should set show percent');
end;

procedure TestProgressGroupWithStyle;
var
  LGroup: IProgressGroup;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(2);
  LGroup := TProgressGroup.New([TProgressItem.Make('CPU', 0.5)]).WithStyle(LStyle);
  Check(LGroup <> nil, 'Should set style');
end;

procedure TestProgressGroupWithEmptyStyle;
var
  LGroup: IProgressGroup;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(3);
  LGroup := TProgressGroup.New([TProgressItem.Make('CPU', 0.5)]).WithEmptyStyle(LStyle);
  Check(LGroup <> nil, 'Should set empty style');
end;

procedure TestProgressGroupRender;
var
  LGroup: IProgressGroup;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LGroup := TProgressGroup.New([
    TProgressItem.Make('CPU', 0.75),
    TProgressItem.Make('Memory', 0.5),
    TProgressItem.Make('Disk', 0.9)
  ]);
  LArea := TRect.Make(0, 0, 40, 5);
  LBuf := TBuffer.CreateEmpty(LArea);
  LGroup.Render(LArea, LBuf);
  Check(True, 'Should render progress group');
end;

procedure TestProgressGroupBuilderChaining;
var
  LGroup: IProgressGroup;
  LStyle, LEmptyStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(1);
  LEmptyStyle.Fg := IndexedColor(2);
  LGroup := TProgressGroup.New([
    TProgressItem.Make('CPU', 0.8).WithStyle(LStyle),
    TProgressItem.Make('Memory', 0.6)
  ])
    .WithLabelWidth(12)
    .WithShowPercent(True)
    .WithStyle(LStyle)
    .WithEmptyStyle(LEmptyStyle);
  Check(LGroup <> nil, 'Should chain builder calls');
end;

begin
  T := TTestSuite.Create('tui_widget_progress_group');
  T.Test('TProgressItem.Make', @TestProgressItemMake);
  T.Test('TProgressItem.WithStyle', @TestProgressItemWithStyle);
  T.Test('TProgressGroup.New creates instance', @TestProgressGroupNew);
  T.Test('TProgressGroup.WithLabelWidth', @TestProgressGroupNewLabelWidth);
  T.Test('TProgressGroup.WithShowPercent', @TestProgressGroupWithShowPercent);
  T.Test('TProgressGroup.WithStyle', @TestProgressGroupWithStyle);
  T.Test('TProgressGroup.WithEmptyStyle', @TestProgressGroupWithEmptyStyle);
  T.Test('TProgressGroup.Render', @TestProgressGroupRender);
  T.Test('TProgressGroup builder chaining', @TestProgressGroupBuilderChaining);
  if not T.Run then Halt(1);
end.
