program demo_multi_screen;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.ext,
  nextpas.core.tui.event;

type
  TAppSharedData = class
  public
    CurrentSelection: AnsiString;
    NavigationLog: AnsiString;
  end;

  TMainScreen = class(TScreen)
  public
    procedure Render(const AArea: TRect; ABuffer: TBuffer); override;
    procedure HandleEvent(const Ev: TEvent); override;
  end;

  TDetailScreen = class(TScreen)
  public
    procedure Render(const AArea: TRect; ABuffer: TBuffer); override;
    procedure HandleEvent(const Ev: TEvent); override;
  end;

{ TMainScreen }

procedure TMainScreen.Render(const AArea: TRect; ABuffer: TBuffer);
var
  LData: TAppSharedData;
begin
  LData := Self.specialize GetShared<TAppSharedData>;
  ABuffer.SetString(0, 0, '=== Multi-Screen Demo ===', StyleDefault);
  ABuffer.SetString(0, 2, 'Navigate items with 1/2/3, Enter for detail.', StyleDefault);
  if LData <> nil then
    ABuffer.SetString(0, 4, 'Log: ' + LData.NavigationLog, StyleDefault);
  ABuffer.SetString(0, 6, '1. Apple  2. Banana  3. Cherry', StyleDefault);
  ABuffer.SetString(0, 8, 'Q to quit.', StyleDefault);
end;

procedure TMainScreen.HandleEvent(const Ev: TEvent);
var
  LData: TAppSharedData;
begin
  if IsQuit(Ev) then
    Stack.RequestQuit
  else if Ev.Kind = evKey then
  begin
    LData := Self.specialize GetShared<TAppSharedData>;
    if LData = nil then Exit;
    if Ev.Key.Code = kcChar then
    begin
      case Chr(Ev.Key.Ch) of
        '1': begin LData.CurrentSelection := 'Apple';  LData.NavigationLog := LData.NavigationLog + 'Apple; '; end;
        '2': begin LData.CurrentSelection := 'Banana'; LData.NavigationLog := LData.NavigationLog + 'Banana; '; end;
        '3': begin LData.CurrentSelection := 'Cherry'; LData.NavigationLog := LData.NavigationLog + 'Cherry; '; end;
      end;
    end
    else if Ev.Key.Code = kcEnter then
      Stack.Push(TDetailScreen.Create);
  end;
end;

{ TDetailScreen }

procedure TDetailScreen.Render(const AArea: TRect; ABuffer: TBuffer);
var
  LData: TAppSharedData;
begin
  LData := Self.specialize GetShared<TAppSharedData>;
  ABuffer.SetString(0, 0, '=== Detail View ===', StyleDefault);
  if LData <> nil then
  begin
    ABuffer.SetString(0, 2, 'Selected: ' + LData.CurrentSelection, StyleDefault);
    ABuffer.SetString(0, 3, 'Log: ' + LData.NavigationLog, StyleDefault);
  end;
  ABuffer.SetString(0, 5, 'Esc to go back, Q to quit.', StyleDefault);
end;

procedure TDetailScreen.HandleEvent(const Ev: TEvent);
var
  Popped: TScreen;
begin
  if IsQuit(Ev) then
    Stack.RequestQuit
  else if Ev.Kind = evKey then
    if Ev.Key.Code = kcEsc then
    begin
      Popped := Stack.Pop;
      Popped.Free;
      Exit;
    end;
end;

var
  App: TApp;
begin
  App := TApp.Create;
  try
    App.SharedStateObject := TAppSharedData.Create;
    App.Screens.Push(TMainScreen.Create);
    App.Run;
  finally
    App.SharedStateObject.Free;
    App.Free;
  end;
end.