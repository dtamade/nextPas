program demo_widgets;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.tui.full;

type
  TWidgetsScreen = class(TScreen)
  private
    FItems: IListWidget;
    FListState: TListState;
    FTick: Integer;
    procedure MoveSelection(ADelta: Integer);
  public
    constructor Create;
    procedure Render(const AArea: TRect; ABuffer: TBuffer); override;
    procedure HandleEvent(const Ev: TEvent); override;
  end;

constructor TWidgetsScreen.Create;
begin
  inherited Create;
  FItems := TListWidget.FromStrings(['Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon'])
    .WithBlock(TBlock.New.WithBorders(BORDERS_ALL).WithTitle('Items'))
    .WithHighlightStyle(StyleDefault.WithBg(TUI_BLUE))
    .WithHighlightSymbol('> ');
  FListState := TListState.Empty;
  FListState.Select(0);
  FTick := 0;
end;

procedure TWidgetsScreen.MoveSelection(ADelta: Integer);
var
  LNext: Integer;
begin
  LNext := FListState.Selected + ADelta;
  if LNext < 0 then
    LNext := 0
  else if LNext > 4 then
    LNext := 4;
  FListState.Select(LNext);
end;

procedure TWidgetsScreen.Render(const AArea: TRect; ABuffer: TBuffer);
var
  Areas, LeftRight: TRectArray;
  Gauge: IGauge;
  Para: IParagraph;
  Percent: Integer;
begin
  Areas := V(AArea, [Flex(), Fixed(3)]);
  LeftRight := H(Areas[0], [Pct(40), Flex()]);

  FItems.RenderStateful(LeftRight[0], ABuffer, FListState);

  Para := TParagraph.New(TText.FromString(
    'Use Up/Down to navigate.'#10 +
    'Press Q or Esc to quit.'#10#10 +
    'Selected: ' + IntToStr(FListState.Selected)))
    .WithBlock(TBlock.New.WithBorders(BORDERS_ALL).WithTitle('Info'));
  Para.Render(LeftRight[1], ABuffer);

  Percent := FTick mod 100;
  Gauge := TGauge.New
    .WithRatio(Percent / 100.0)
    .WithLabel(IntToStr(Percent) + '%')
    .WithFilledStyle(StyleDefault.WithFg(TUI_GREEN));
  Gauge.Render(Areas[1], ABuffer);

  Inc(FTick);
end;

procedure TWidgetsScreen.HandleEvent(const Ev: TEvent);
begin
  if IsQuit(Ev) then
    Stack.RequestQuit
  else if IsKeyCode(Ev, kcUp) then
    MoveSelection(-1)
  else if IsKeyCode(Ev, kcDown) then
    MoveSelection(1);
end;

var
  App: TApp;

begin
  App := TApp.Create;
  try
    App.Screens.Push(TWidgetsScreen.Create);
    App.Run;
  finally
    App.Free;
  end;
end.
