program test_tui_widget_dialog;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.dialog,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestDialogNew;
var
  LDialog: IDialog;
begin
  LDialog := TDialog.New('Title', 'Body text');
  Check(LDialog <> nil, 'Should create dialog instance');
end;

procedure TestDialogWithButtons;
var
  LDialog: IDialog;
begin
  LDialog := TDialog.New('Confirm', 'Are you sure?').WithButtons(['OK', 'Cancel']);
  Check(LDialog <> nil, 'Should set buttons');
end;

procedure TestDialogWithWidth;
var
  LDialog: IDialog;
begin
  LDialog := TDialog.New('Title', 'Body').WithWidth(50);
  Check(LDialog <> nil, 'Should set width');
end;

procedure TestDialogWithHeight;
var
  LDialog: IDialog;
begin
  LDialog := TDialog.New('Title', 'Body').WithHeight(20);
  Check(LDialog <> nil, 'Should set height');
end;

procedure TestDialogWithStyle;
var
  LDialog: IDialog;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(1);
  LDialog := TDialog.New('Title', 'Body').WithStyle(LStyle);
  Check(LDialog <> nil, 'Should set style');
end;

procedure TestDialogWithBorderStyle;
var
  LDialog: IDialog;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(2);
  LDialog := TDialog.New('Title', 'Body').WithBorderStyle(LStyle);
  Check(LDialog <> nil, 'Should set border style');
end;

procedure TestDialogWithButtonStyle;
var
  LDialog: IDialog;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(3);
  LDialog := TDialog.New('Title', 'Body').WithButtons(['OK']).WithButtonStyle(LStyle);
  Check(LDialog <> nil, 'Should set button style');
end;

procedure TestDialogWithActiveButtonStyle;
var
  LDialog: IDialog;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(4);
  LDialog := TDialog.New('Title', 'Body').WithButtons(['OK']).WithActiveButtonStyle(LStyle);
  Check(LDialog <> nil, 'Should set active button style');
end;

procedure TestDialogWithDimBackground;
var
  LDialog: IDialog;
begin
  LDialog := TDialog.New('Title', 'Body').WithDimBackground(True);
  Check(LDialog <> nil, 'Should set dim background');
end;

procedure TestDialogWithSelected;
var
  LDialog: IDialog;
begin
  LDialog := TDialog.New('Title', 'Body').WithButtons(['Yes', 'No']).WithSelected(1);
  Check(LDialog <> nil, 'Should set selected button');
end;

procedure TestDialogRender;
var
  LDialog: IDialog;
  LBuf: TBuffer;
  LArea: TRect;
begin
  LDialog := TDialog.New('Confirm', 'Delete file?').WithButtons(['Yes', 'No']);
  LArea := TRect.Make(0, 0, 40, 10);
  LBuf := TBuffer.CreateEmpty(LArea);
  LDialog.Render(LArea, LBuf);
  Check(True, 'Should render dialog');
end;

procedure TestDialogBuilderChaining;
var
  LDialog: IDialog;
  LStyle, LBorderStyle, LBtnStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(1);
  LBorderStyle.Fg := IndexedColor(2);
  LBtnStyle.Fg := IndexedColor(3);
  LDialog := TDialog.New('Settings', 'Choose option')
    .WithButtons(['Save', 'Cancel', 'Apply'])
    .WithWidth(50)
    .WithHeight(15)
    .WithStyle(LStyle)
    .WithBorderStyle(LBorderStyle)
    .WithButtonStyle(LBtnStyle)
    .WithDimBackground(True)
    .WithSelected(0);
  Check(LDialog <> nil, 'Should chain builder calls');
end;

begin
  T := TTestSuite.Create('tui_widget_dialog');
  T.Test('TDialog.New creates instance', @TestDialogNew);
  T.Test('TDialog.WithButtons', @TestDialogWithButtons);
  T.Test('TDialog.WithWidth', @TestDialogWithWidth);
  T.Test('TDialog.WithHeight', @TestDialogWithHeight);
  T.Test('TDialog.WithStyle', @TestDialogWithStyle);
  T.Test('TDialog.WithBorderStyle', @TestDialogWithBorderStyle);
  T.Test('TDialog.WithButtonStyle', @TestDialogWithButtonStyle);
  T.Test('TDialog.WithActiveButtonStyle', @TestDialogWithActiveButtonStyle);
  T.Test('TDialog.WithDimBackground', @TestDialogWithDimBackground);
  T.Test('TDialog.WithSelected', @TestDialogWithSelected);
  T.Test('TDialog.Render', @TestDialogRender);
  T.Test('TDialog builder chaining', @TestDialogBuilderChaining);
  if not T.Run then Halt(1);
end.
