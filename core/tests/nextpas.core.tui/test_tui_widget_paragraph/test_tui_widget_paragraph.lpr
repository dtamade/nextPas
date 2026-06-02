program test_tui_widget_paragraph;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.buffer,
  nextpas.core.tui.borders,
  nextpas.core.tui.text,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.paragraph,
  nextpas.core.testing;
var T: TTestRunner;

procedure TestSimpleRender;
var LP: IParagraph; LBuf: TBuffer; LLines: TBufferLines;
begin
  LP := TParagraph.FromString('Hello');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LP.Render(TRect.Make(0, 0, 10, 1), LBuf);
    LLines := LBuf.AsLines;
    Check(Pos('Hello', LLines[0]) > 0, 'contains Hello');
  finally LBuf.Free; end;
end;

procedure TestCenterAlignment;
var LP: IParagraph; LBuf: TBuffer; LLines: TBufferLines;
begin
  LP := TParagraph.New(TText.Raw('Hi')).WithAlignment(caCenter);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LP.Render(TRect.Make(0, 0, 10, 1), LBuf);
    LLines := LBuf.AsLines;
    { 'Hi' width 2, area 10 -> offset 4 -> starts at col 4 }
    Check(LLines[0][5] = 'H', 'H at col 4 (1-indexed 5)');
  finally LBuf.Free; end;
end;

procedure TestWithBlock;
var LP: IParagraph; LBuf: TBuffer; LLines: TBufferLines;
begin
  LP := TParagraph.FromString('AB')
    .WithBlock(TBlock.New.WithBorders(BORDERS_ALL));
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 3));
  try
    LP.Render(TRect.Make(0, 0, 6, 3), LBuf);
    LLines := LBuf.AsLines;
    { 中间行应含 AB（在边框内） }
    Check(Pos('AB', LLines[1]) > 0, 'AB inside block');
  finally LBuf.Free; end;
end;

procedure TestWrapTrim;
var LP: IParagraph; LBuf: TBuffer; LLines: TBufferLines;
begin
  { 'hello world' width 11, area width 6 -> wraps to 'hello' + 'world' }
  LP := TParagraph.FromString('hello world').WithWrap(WRAP_TRIM);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 3));
  try
    LP.Render(TRect.Make(0, 0, 6, 3), LBuf);
    LLines := LBuf.AsLines;
    Check(Pos('hello', LLines[0]) > 0, 'first line hello');
    Check(Pos('world', LLines[1]) > 0, 'second line world');
  finally LBuf.Free; end;
end;

procedure TestScrollY;
var LP: IParagraph; LBuf: TBuffer; LLines: TBufferLines;
begin
  LP := TParagraph.New(TText.FromString('line1'#10'line2'#10'line3'))
    .WithScrollY(1);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 2));
  try
    LP.Render(TRect.Make(0, 0, 10, 2), LBuf);
    LLines := LBuf.AsLines;
    { scroll 1 -> first visible is 'line2' }
    Check(Pos('line2', LLines[0]) > 0, 'scrolled to line2');
    Check(Pos('line3', LLines[1]) > 0, 'line3 visible');
  finally LBuf.Free; end;
end;

procedure TestAsIWidget;
var LW: IWidget; LBuf: TBuffer;
begin
  LW := TParagraph.FromString('x');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  try
    LW.Render(TRect.Make(0, 0, 5, 1), LBuf);
    Check(LBuf.RowAsString(0) <> '     ', 'rendered via IWidget');
  finally LBuf.Free; end;
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.widget.paragraph');
  T.Run('simple render', @TestSimpleRender);
  T.Run('center alignment', @TestCenterAlignment);
  T.Run('with block', @TestWithBlock);
  T.Run('wrap trim', @TestWrapTrim);
  T.Run('scroll y', @TestScrollY);
  T.Run('as IWidget', @TestAsIWidget);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
