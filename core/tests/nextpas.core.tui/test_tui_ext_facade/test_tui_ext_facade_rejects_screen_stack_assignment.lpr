program test_tui_ext_facade_rejects_screen_stack_assignment;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.ext;

type
  TExtScreen = class(TScreen)
  public
    procedure Render(const AArea: TRect; ABuffer: TBuffer); override;
  end;

procedure TExtScreen.Render(const AArea: TRect; ABuffer: TBuffer);
begin
end;

var
  LApp: TApp;
  LScreen: TExtScreen;

begin
  LApp := TApp.Create;
  LScreen := TExtScreen.Create;
  try
    LScreen.Stack := LApp.Screens;
  finally
    LScreen.Free;
    LApp.Free;
  end;
end.
