program demo_hello;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.buffer,
  nextpas.core.tui.borders,
  nextpas.core.tui.layout,
  nextpas.core.tui.terminal,
  nextpas.core.tui.event,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.paragraph,
  nextpas.core.tui.text;

var
  Term: TTerminal;
  Frame: TFrame;
  Ev: TEvent;
  Block: IBlock;
  Para: IParagraph;

begin
  Term := TTerminal.Create;
  if not Term.EnterTui then
  begin
    WriteLn('Not a terminal');
    Term.Free;
    Halt(1);
  end;

  Block := TBlock.New
    .WithBorders(BORDERS_ALL)
    .WithTitle('nextpas.core.tui')
    .WithBorderStyle(StyleDefault.WithFg(TUI_CYAN));

  Para := TParagraph.New(TText.FromString(
    'Hello from nextpas.core.tui!'#10 +
    ''#10 +
    'Press Q or Esc to quit.'))
    .WithBlock(Block);

  repeat
    Frame := Term.BeginFrame;
    Para.Render(Frame.Area, Frame.Buffer);
    Term.EndFrame(Frame);

    Ev := Term.PollEvent(100);
    if Ev.Kind = evKey then
    begin
      if (Ev.Key.Code = kcEsc) then Break;
      if (Ev.Key.Code = kcChar) and (Ev.Key.Ch = Ord('q')) then Break;
    end;
  until Term.ShouldQuit;

  Term.LeaveTui;
  Term.Free;
end.
