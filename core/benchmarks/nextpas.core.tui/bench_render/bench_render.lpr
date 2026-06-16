program bench_render;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.tui.full,
  nextpas.core.bench;

var
  Buf: TBuffer;
  Block: IBlock;
  Para: IParagraph;
  ListW: IListWidget;
  ListState: TListState;
  Gauge: IGauge;
  Areas, LeftRight: TRectArray;

procedure SetupWidgets;
begin
  Block := TBlock.New.WithBorders(BORDERS_ALL).WithTitle('Dashboard')
    .WithBorderStyle(StyleDefault.WithFg(TUI_CYAN));
  Para := TParagraph.New(TText.FromString(
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit.'#10 +
    'Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.'#10 +
    'Ut enim ad minim veniam, quis nostrud exercitation.'))
    .WithBlock(TBlock.New.WithBorders(BORDERS_ALL).WithTitle('Info'));
  ListW := TListWidget.FromStrings([
    'Item Alpha', 'Item Beta', 'Item Gamma', 'Item Delta',
    'Item Epsilon', 'Item Zeta', 'Item Eta', 'Item Theta'])
    .WithBlock(TBlock.New.WithBorders(BORDERS_ALL).WithTitle('List'))
    .WithHighlightStyle(StyleDefault.WithBg(TUI_BLUE))
    .WithHighlightSymbol('> ');
  ListState := TListState.Empty;
  ListState.Select(3);
  Gauge := TGauge.New.WithRatio(0.65).WithLabel('65%')
    .WithFilledStyle(StyleDefault.WithFg(TUI_GREEN));
end;

procedure BenchFullRender(AIters: Int64);
var LI: Int64;
begin
  for LI := 1 to AIters do
  begin
    Buf.Reset;
    Areas := V(Buf.Area, [Flex(), Fixed(3)]);
    LeftRight := H(Areas[0], [Pct(40), Flex()]);
    ListW.RenderStateful(LeftRight[0], Buf, ListState);
    Para.Render(LeftRight[1], Buf);
    Gauge.Render(Areas[1], Buf);
  end;
end;

procedure BenchBlockOnly(AIters: Int64);
var LI: Int64;
begin
  for LI := 1 to AIters do
  begin
    Buf.Reset;
    Block.Render(Buf.Area, Buf);
  end;
end;

procedure BenchSetString(AIters: Int64);
var LI: Int64; LY: Integer;
begin
  for LI := 1 to AIters do
  begin
    for LY := 0 to Buf.Height - 1 do
      Buf.SetString(0, LY, 'Hello World TUI Benchmark Test String!', StyleDefault);
  end;
end;

var
  Runner: TBenchRunner;
begin
  Buf := TBuffer.CreateEmpty(TRect.Make(0, 0, 120, 40));
  SetupWidgets;

  Runner := TBenchRunner.Create;
  Runner.Run('Full render 120x40 (block+list+para+gauge)', @BenchFullRender);
  Runner.Run('Block only 120x40', @BenchBlockOnly);
  Runner.Run('SetString 120x40 (40 rows)', @BenchSetString);
  Runner.Summary;

  Buf.Free;
end.
