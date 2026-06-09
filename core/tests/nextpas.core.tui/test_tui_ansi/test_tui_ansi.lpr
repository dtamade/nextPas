program test_tui_ansi;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.builder,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.ansi,
  nextpas.core.testing;

var
  T: TTestRunner;
  B: TStringBuilder;

procedure Setup;
begin
  B.Init(256);
end;

procedure Teardown;
begin
  B.Done;
end;

function BufStr: string;
begin
  Result := B.ToString;
end;

procedure TestHideCursor;
begin
  Setup;
  AnsiHideCursor(B);
  CheckEqual(#27'[?25l', BufStr, 'hide cursor');
  Teardown;
end;

procedure TestShowCursor;
begin
  Setup;
  AnsiShowCursor(B);
  CheckEqual(#27'[?25h', BufStr, 'show cursor');
  Teardown;
end;

procedure TestMoveTo;
begin
  Setup;
  AnsiMoveTo(B, 4, 2);  { 0-based -> wire 5;3 }
  CheckEqual(#27'[3;5H', BufStr, 'move to (4,2) -> row 3 col 5');
  Teardown;
end;

procedure TestClearScreen;
begin
  Setup;
  AnsiClearScreen(B);
  CheckEqual(#27'[2J', BufStr, 'clear screen');
  Teardown;
end;

procedure TestAltScreen;
begin
  Setup;
  AnsiEnterAltScreen(B);
  CheckEqual(#27'[?1049h', BufStr, 'enter alt');
  B.Clear;
  AnsiLeaveAltScreen(B);
  CheckEqual(#27'[?1049l', BufStr, 'leave alt');
  Teardown;
end;

procedure TestSgrReset;
begin
  Setup;
  AnsiSgrReset(B);
  CheckEqual(#27'[0m', BufStr, 'sgr reset');
  Teardown;
end;

procedure TestSgrFgIndexed;
begin
  Setup;
  AnsiSgrFg(B, IndexedColor(1));  { red = SGR 31 }
  CheckEqual(#27'[31m', BufStr, 'fg red');
  B.Clear;
  AnsiSgrFg(B, IndexedColor(9));  { bright red = SGR 91 }
  CheckEqual(#27'[91m', BufStr, 'fg bright red');
  B.Clear;
  AnsiSgrFg(B, IndexedColor(200));  { 256-color }
  CheckEqual(#27'[38;5;200m', BufStr, 'fg 256-color 200');
  Teardown;
end;

procedure TestSgrBgIndexed;
begin
  Setup;
  AnsiSgrBg(B, IndexedColor(2));  { green = SGR 42 }
  CheckEqual(#27'[42m', BufStr, 'bg green');
  B.Clear;
  AnsiSgrBg(B, IndexedColor(10));  { bright green = SGR 102 }
  CheckEqual(#27'[102m', BufStr, 'bg bright green');
  Teardown;
end;

procedure TestSgrFgRgb;
begin
  Setup;
  AnsiSgrFg(B, RgbColor(10, 20, 30));
  CheckEqual(#27'[38;2;10;20;30m', BufStr, 'fg rgb');
  Teardown;
end;

procedure TestSgrFgReset;
begin
  Setup;
  AnsiSgrFg(B, ResetColor);
  CheckEqual(#27'[39m', BufStr, 'fg reset');
  Teardown;
end;

procedure TestSgrUnderlineColor;
begin
  Setup;
  AnsiSgrUl(B, TUI_BLUE);
  CheckEqual(#27'[58;5;4m', BufStr, 'underline indexed blue');
  B.Clear;
  AnsiSgrUl(B, RgbColor(10, 20, 30));
  CheckEqual(#27'[58;2;10;20;30m', BufStr, 'underline rgb');
  B.Clear;
  AnsiSgrUl(B, ResetColor);
  CheckEqual(#27'[59m', BufStr, 'underline reset');
  Teardown;
end;

procedure TestSgrModifierAdd;
begin
  Setup;
  AnsiSgrModifierAdd(B, [mbBold]);
  CheckEqual(#27'[1m', BufStr, 'bold');
  B.Clear;
  AnsiSgrModifierAdd(B, [mbItalic, mbUnderlined]);
  CheckEqual(#27'[3m'#27'[4m', BufStr, 'italic+underline');
  Teardown;
end;

procedure TestSgrModifierClear;
begin
  Setup;
  AnsiSgrModifierClear(B, [mbBold]);
  CheckEqual(#27'[22m', BufStr, 'clear bold');
  B.Clear;
  AnsiSgrModifierClear(B, [mbItalic]);
  CheckEqual(#27'[23m', BufStr, 'clear italic');
  Teardown;
end;

procedure TestMouseTracking;
begin
  Setup;
  AnsiEnableMouseTracking(B);
  CheckEqual(#27'[?1003h'#27'[?1006h', BufStr, 'enable mouse tracking');
  B.Clear;
  AnsiDisableMouseTracking(B);
  CheckEqual(#27'[?1003l'#27'[?1006l', BufStr, 'disable mouse tracking');
  Teardown;
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.ansi');
  T.Run('hide cursor', @TestHideCursor);
  T.Run('show cursor', @TestShowCursor);
  T.Run('move to', @TestMoveTo);
  T.Run('clear screen', @TestClearScreen);
  T.Run('alt screen', @TestAltScreen);
  T.Run('sgr reset', @TestSgrReset);
  T.Run('sgr fg indexed', @TestSgrFgIndexed);
  T.Run('sgr bg indexed', @TestSgrBgIndexed);
  T.Run('sgr fg rgb', @TestSgrFgRgb);
  T.Run('sgr fg reset', @TestSgrFgReset);
  T.Run('sgr underline color', @TestSgrUnderlineColor);
  T.Run('sgr modifier add', @TestSgrModifierAdd);
  T.Run('sgr modifier clear', @TestSgrModifierClear);
  T.Run('mouse tracking', @TestMouseTracking);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
