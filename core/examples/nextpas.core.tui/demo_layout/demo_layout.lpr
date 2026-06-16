program demo_layout;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.ext;

type
  TLayoutScreen = class(TScreen)
  private
    FPanel: IPanel;
    procedure DrawLabel(ABuffer: TBuffer; const ACell: TRect; const ALabel: AnsiString);
  public
    constructor Create;
    procedure Render(const AArea: TRect; ABuffer: TBuffer); override;
    procedure HandleEvent(const Ev: TEvent); override;
  end;

constructor TLayoutScreen.Create;
begin
  inherited Create;
  FPanel := TPanel.Grid(1, 3).WithEdges(PanelEdgesAll);
end;

procedure TLayoutScreen.DrawLabel(ABuffer: TBuffer; const ACell: TRect;
  const ALabel: AnsiString);
begin
  if ACell.IsEmpty then
    Exit;
  ABuffer.SetString(ACell.X, ACell.Y, ALabel, StyleDefault);
end;

procedure TLayoutScreen.Render(const AArea: TRect; ABuffer: TBuffer);
var
  Grid: TPanelGrid;
begin
  Grid := FPanel.RenderGrid(AArea, ABuffer);
  DrawLabel(ABuffer, PanelCell(Grid, 0, 0), 'Header');
  DrawLabel(ABuffer, PanelCell(Grid, 0, 1), 'Body');
  DrawLabel(ABuffer, PanelCell(Grid, 0, 2), 'Footer');
end;

procedure TLayoutScreen.HandleEvent(const Ev: TEvent);
begin
  if IsQuit(Ev) then
    Stack.RequestQuit;
end;

var
  App: TApp;

begin
  App := TApp.Create;
  try
    App.Screens.Push(TLayoutScreen.Create);
    App.Run;
  finally
    App.Free;
  end;
end.
