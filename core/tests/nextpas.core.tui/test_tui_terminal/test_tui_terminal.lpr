program test_tui_terminal;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.event,
  nextpas.core.tui.interaction,
  nextpas.core.tui.terminal,
  nextpas.core.testing;

var
  T: TTestRunner;

{ 测试 terminal 的输入解析（通过 test seam，不需要真实 TTY） }

procedure TestParseAsciiKey;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([Ord('A')]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcChar, 'char code');
    CheckEqual(Int64(Ord('A')), Int64(LEv.Key.Ch), 'ch = A');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseEnter;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([13]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Key.Code = kcEnter, 'enter');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseEsc;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([27]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed at EOF');
    Check(LEv.Key.Code = kcEsc, 'esc');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseArrowUp;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI A = Up }
    LTerm.InjectInputBytesForTest([27, Ord('['), Ord('A')]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Key.Code = kcUp, 'up arrow');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseSgrMouse;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI < 0;5;3M = left button down at (4,2) 0-based }
    LTerm.InjectInputBytesForTest([27, Ord('['), Ord('<'),
      Ord('0'), Ord(';'), Ord('5'), Ord(';'), Ord('3'), Ord('M')]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evMouse, 'mouse event');
    Check(LEv.Mouse.Kind = mkDown, 'mouse down');
    Check(LEv.Mouse.Button = mbLeft, 'left button');
    CheckEqual(Int64(4), Int64(LEv.Mouse.X), 'x=4 (wire 5 - 1)');
    CheckEqual(Int64(2), Int64(LEv.Mouse.Y), 'y=2 (wire 3 - 1)');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCtrlC;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([3]);  { Ctrl-C = byte 3 }
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key');
    Check(kmCtrl in LEv.Key.Modifiers, 'ctrl modifier');
    CheckEqual(Int64(Ord('c')), Int64(LEv.Key.Ch), 'ch = c');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseUTF8;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { '中' = E4 B8 AD }
    LTerm.InjectInputBytesForTest([$E4, $B8, $AD]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key');
    CheckEqual(Int64($4E2D), Int64(LEv.Key.Ch), 'codepoint U+4E2D');
  finally
    LTerm.Free;
  end;
end;

procedure TestCaptureAutoRelease;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.Capture.Acquire(nil, mbLeft);
    Check(LTerm.Capture.Active, 'capture active');
    { Inject mouse up -> PostProcessEvent should auto-release }
    LTerm.InjectInputBytesForTest([27, Ord('['), Ord('<'),
      Ord('0'), Ord(';'), Ord('1'), Ord(';'), Ord('1'), Ord('m')]);
    LTerm.PollQueuedEventForTest(True, LEv);
    Check(not LTerm.Capture.Active, 'capture released on mouse up');
  finally
    LTerm.Free;
  end;
end;

procedure TestRequestQuit;
var
  LTerm: TTerminal;
begin
  LTerm := TTerminal.Create;
  try
    Check(not LTerm.ShouldQuit, 'not quit initially');
    LTerm.RequestQuit;
    Check(LTerm.ShouldQuit, 'quit after request');
  finally
    LTerm.Free;
  end;
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.terminal');
  T.Run('parse ascii key', @TestParseAsciiKey);
  T.Run('parse enter', @TestParseEnter);
  T.Run('parse esc', @TestParseEsc);
  T.Run('parse arrow up', @TestParseArrowUp);
  T.Run('parse sgr mouse', @TestParseSgrMouse);
  T.Run('parse ctrl-c', @TestParseCtrlC);
  T.Run('parse utf8', @TestParseUTF8);
  T.Run('capture auto release', @TestCaptureAutoRelease);
  T.Run('request quit', @TestRequestQuit);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
