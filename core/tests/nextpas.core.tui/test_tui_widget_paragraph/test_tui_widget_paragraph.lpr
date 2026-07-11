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
  nextpas.core.test;
var T: TTestSuite;

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

procedure TestRightAlignment;
var LP: IParagraph; LBuf: TBuffer; LLines: TBufferLines;
begin
  LP := TParagraph.New(TText.Raw('Hi')).WithAlignment(caRight);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LP.Render(TRect.Make(0, 0, 10, 1), LBuf);
    LLines := LBuf.AsLines;
    { 'Hi' width 2, area 10 -> right aligned -> starts at col 8 }
    Check(LLines[0][9] = 'H', 'H at col 8 (1-indexed 9)');
  finally LBuf.Free; end;
end;

procedure TestWrappedShortcut;
var LP: IParagraph; LBuf: TBuffer; LLines: TBufferLines;
begin
  LP := TParagraph.Wrapped('hello world');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 6, 3));
  try
    LP.Render(TRect.Make(0, 0, 6, 3), LBuf);
    LLines := LBuf.AsLines;
    Check(Pos('hello', LLines[0]) > 0, 'wrapped first line');
    Check(Pos('world', LLines[1]) > 0, 'wrapped second line');
  finally LBuf.Free; end;
end;

procedure TestEmptyText;
var LP: IParagraph; LBuf: TBuffer;
begin
  LP := TParagraph.FromString('');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 1));
  try
    LP.Render(TRect.Make(0, 0, 5, 1), LBuf);
    Check(True, 'empty text does not crash');
  finally LBuf.Free; end;
end;

procedure TestMultiLineNoWrap;
var LP: IParagraph; LBuf: TBuffer; LLines: TBufferLines;
begin
  LP := TParagraph.FromString('line1'#10'line2'#10'line3');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 3));
  try
    LP.Render(TRect.Make(0, 0, 10, 3), LBuf);
    LLines := LBuf.AsLines;
    Check(Pos('line1', LLines[0]) > 0, 'line1 rendered');
    Check(Pos('line2', LLines[1]) > 0, 'line2 rendered');
    Check(Pos('line3', LLines[2]) > 0, 'line3 rendered');
  finally LBuf.Free; end;
end;

procedure TestLeftAlignmentDefault;
var LP: IParagraph; LBuf: TBuffer; LLines: TBufferLines;
begin
  LP := TParagraph.FromString('Hi');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LP.Render(TRect.Make(0, 0, 10, 1), LBuf);
    LLines := LBuf.AsLines;
    // Left alignment: 'H' at col 0
    Check(LLines[0][1] = 'H', 'Left aligned: H at col 0');
  finally LBuf.Free; end;
end;

procedure TestWithStyle;
var LP: IParagraph; LBuf: TBuffer;
  LStyle: TStyle;
begin
  LStyle.Fg := IndexedColor(3);
  LP := TParagraph.FromString('styled').WithStyle(LStyle);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 1));
  try
    LP.Render(TRect.Make(0, 0, 10, 1), LBuf);
    Check(True, 'WithStyle renders without crash');
  finally LBuf.Free; end;
end;

procedure TestScrollYZero;
var LP: IParagraph; LBuf: TBuffer; LLines: TBufferLines;
begin
  LP := TParagraph.New(TText.FromString('first'#10'second'))
    .WithScrollY(0);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 2));
  try
    LP.Render(TRect.Make(0, 0, 10, 2), LBuf);
    LLines := LBuf.AsLines;
    Check(Pos('first', LLines[0]) > 0, 'ScrollY(0) shows first line');
  finally LBuf.Free; end;
end;

procedure TestScrollYBeyondContent;
var LP: IParagraph; LBuf: TBuffer;
begin
  LP := TParagraph.New(TText.FromString('only'))
    .WithScrollY(100);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 10, 2));
  try
    LP.Render(TRect.Make(0, 0, 10, 2), LBuf);
    Check(True, 'ScrollY beyond content does not crash');
  finally LBuf.Free; end;
end;

procedure TestWrapMultiLine;
var LP: IParagraph; LBuf: TBuffer; LLines: TBufferLines;
begin
  LP := TParagraph.Wrapped('ab cd ef gh');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 5, 4));
  try
    LP.Render(TRect.Make(0, 0, 5, 4), LBuf);
    LLines := LBuf.AsLines;
    Check(Pos('ab', LLines[0]) > 0, 'wrap: first line has ab');
    Check(Pos('cd', LLines[1]) > 0, 'wrap: second line has cd');
  finally LBuf.Free; end;
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.paragraph');
  T.Test('simple render', @TestSimpleRender);
  T.Test('center alignment', @TestCenterAlignment);
  T.Test('with block', @TestWithBlock);
  T.Test('wrap trim', @TestWrapTrim);
  T.Test('scroll y', @TestScrollY);
  T.Test('as IWidget', @TestAsIWidget);
  T.Test('right alignment', @TestRightAlignment);
  T.Test('wrapped shortcut', @TestWrappedShortcut);
  T.Test('empty text', @TestEmptyText);
  T.Test('multi-line no wrap', @TestMultiLineNoWrap);
  T.Test('left alignment default', @TestLeftAlignmentDefault);
  T.Test('with style', @TestWithStyle);
  T.Test('scroll y zero', @TestScrollYZero);
  T.Test('scroll y beyond content', @TestScrollYBeyondContent);
  T.Test('wrap multi-line', @TestWrapMultiLine);
  if not T.Run then Halt(1);
end.
