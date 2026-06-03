program demo_hello;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.ext;

type
  THelloScreen = class(TScreen)
  public
    procedure Render(const AArea: TRect; ABuffer: TBuffer); override;
    procedure HandleEvent(const Ev: TEvent); override;
  end;

procedure THelloScreen.Render(const AArea: TRect; ABuffer: TBuffer);
begin
  ABuffer.SetString(0, 0, 'Hello from nextpas.core.tui.ext!', StyleDefault);
  ABuffer.SetString(0, 2, 'This demo uses TApp + TScreen.', StyleDefault);
  ABuffer.SetString(0, 4, 'Press Q or Esc to quit.', StyleDefault);
end;

procedure THelloScreen.HandleEvent(const Ev: TEvent);
begin
  if IsQuit(Ev) then
    Stack.RequestQuit;
end;

var
  App: TApp;

begin
  App := TApp.Create;
  try
    App.Screens.Push(THelloScreen.Create);
    App.Run;
  finally
    App.Free;
  end;
end.
