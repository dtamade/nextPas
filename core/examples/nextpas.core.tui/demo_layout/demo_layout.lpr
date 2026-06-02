program demo_layout;
{$I nextpas.core.settings.inc}
uses
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
  nextpas.core.tui.text;

var
  Term: TTerminal;
  Frame: TFrame;
  Ev: TEvent;
  Areas: TRectArray;
  Header, Body, Footer: IBlock;
begin
  Term := TTerminal.Create;
  if not Term.EnterTui then begin WriteLn('Not a terminal'); Term.Free; Halt(1); end;

  Header := TBlock.New.WithBorders(BORDERS_ALL).WithTitle('Header')
    .WithBorderStyle(StyleDefault.WithFg(TUI_YELLOW));
  Body := TBlock.New.WithBorders(BORDERS_ALL).WithTitle('Body')
    .WithBorderStyle(StyleDefault.WithFg(TUI_GREEN));
  Footer := TBlock.New.WithBorders(BORDERS_ALL).WithTitle('Footer')
    .WithBorderStyle(StyleDefault.WithFg(TUI_CYAN));

  repeat
    Frame := Term.BeginFrame;
    Areas := V(Frame.Area, [Fixed(3), Flex(), Fixed(3)]);
    Header.Render(Areas[0], Frame.Buffer);
    Body.Render(Areas[1], Frame.Buffer);
    Footer.Render(Areas[2], Frame.Buffer);
    Term.EndFrame(Frame);

    Ev := Term.PollEvent(100);
    if (Ev.Kind = evKey) and ((Ev.Key.Code = kcEsc) or
       ((Ev.Key.Code = kcChar) and (Ev.Key.Ch = Ord('q')))) then Break;
  until Term.ShouldQuit;

  Term.LeaveTui;
  Term.Free;
end.
