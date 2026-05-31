program demo_widgets;
{$I nextpas.core.settings.inc}
uses
  SysUtils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.buffer,
  nextpas.core.tui.borders,
  nextpas.core.tui.layout,
  nextpas.core.tui.layout.dsl,
  nextpas.core.tui.terminal,
  nextpas.core.tui.event,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.paragraph,
  nextpas.core.tui.widget.list,
  nextpas.core.tui.widget.gauge,
  nextpas.core.tui.text;

var
  Term: TTerminal;
  Frame: TFrame;
  Ev: TEvent;
  Areas, LeftRight: TRectArray;
  ListW: IListWidget;
  ListState: TListState;
  Gauge: TGauge;
  Para: IParagraph;
  Tick: Integer;
begin
  Term := TTerminal.Create;
  if not Term.EnterTui then begin WriteLn('Not a terminal'); Term.Free; Halt(1); end;

  ListW := TListWidget.FromStrings(['Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon'])
    .WithBlock(TBlock.New.WithBorders(BORDERS_ALL).WithTitle('Items'))
    .WithHighlightStyle(StyleDefault.WithBg(TUI_BLUE))
    .WithHighlightSymbol('> ');
  ListState := TListState.Empty;
  ListState.Select(0);

  Tick := 0;

  repeat
    Frame := Term.BeginFrame;

    Areas := V(Frame.Area, [Flex(), Fixed(3)]);
    LeftRight := H(Areas[0], [Pct(40), Flex()]);

    { 左：列表 }
    ListW.RenderStateful(LeftRight[0], Frame.Buffer, ListState);

    { 右：段落 }
    Para := TParagraph.New(TText.FromString(
      'Use Up/Down to navigate.'#10 +
      'Press Q to quit.'#10#10 +
      'Selected: ' + IntToStr(ListState.Selected)))
      .WithBlock(TBlock.New.WithBorders(BORDERS_ALL).WithTitle('Info'));
    Para.Render(LeftRight[1], Frame.Buffer);

    { 底部：进度条 }
    Gauge := TGauge.Default
      .WithRatio((Tick mod 100) / 100.0)
      .WithLabel(IntToStr(Tick mod 100) + '%')
      .WithFilledStyle(StyleDefault.WithFg(TUI_GREEN));
    Gauge.Render(Areas[1], Frame.Buffer);

    Term.EndFrame(Frame);

    Ev := Term.PollEvent(50);
    Inc(Tick);
    if Ev.Kind = evKey then
    begin
      case Ev.Key.Code of
        kcEsc: Break;
        kcChar: if Ev.Key.Ch = Ord('q') then Break;
        kcUp: if ListState.Selected > 0 then ListState.Select(ListState.Selected - 1);
        kcDown: if ListState.Selected < 4 then ListState.Select(ListState.Selected + 1);
      end;
    end;
  until Term.ShouldQuit;

  Term.LeaveTui;
  Term.Free;
end.
