program demo_panel_layout;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.ext;

type
  TPanelScreen = class(TScreen)
  private
    FPanel: IPanel;
  public
    constructor Create;
    procedure Render(const AArea: TRect; ABuffer: TBuffer); override;
    procedure HandleEvent(const Ev: TEvent); override;
  end;

{ TPanelScreen }

constructor TPanelScreen.Create;
begin
  inherited Create;
  FPanel := TPanel.Grid(1, 2).WithEdges(PanelEdgesOuter);
end;

procedure TPanelScreen.Render(const AArea: TRect; ABuffer: TBuffer);
var
  Grid: TPanelGrid;
  Top, Bottom: TRect;
begin
  Grid := FPanel.RenderGrid(AArea, ABuffer);
  Top := PanelCell(Grid, 0, 0);
  Bottom := PanelCell(Grid, 0, 1);

  { Top section }
  ABuffer.SetString(Top.X, Top.Y,     '=== Panel Layout Demo ===', StyleDefault);
  ABuffer.SetString(Top.X, Top.Y + 2, 'This is a 2-row panel grid.', StyleDefault);
  ABuffer.SetString(Top.X, Top.Y + 3, 'Top panel: info and navigation.', StyleDefault);

  { Bottom section }
  ABuffer.SetString(Bottom.X, Bottom.Y,     'Bottom panel: log area', StyleDefault);
  ABuffer.SetString(Bottom.X, Bottom.Y + 2, 'Panels are created via TPanel.Grid + IPanel.', StyleDefault);
  ABuffer.SetString(Bottom.X, Bottom.Y + 3, 'Use PanelCell() to get each cell rect.', StyleDefault);

  ABuffer.SetString(0, AArea.Height - 1, 'Press Q or Esc to quit.', StyleDefault);
end;

procedure TPanelScreen.HandleEvent(const Ev: TEvent);
begin
  if IsQuit(Ev) then
    Stack.RequestQuit;
end;

var
  App: TApp;
begin
  App := TApp.Create;
  try
    App.Screens.Push(TPanelScreen.Create);
    App.Run;
  finally
    App.Free;
  end;
end.