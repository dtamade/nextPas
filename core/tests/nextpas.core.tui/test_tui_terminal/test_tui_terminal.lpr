program test_tui_terminal;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.event,
  nextpas.core.tui.error,
  nextpas.core.tui.image_cap,
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

procedure TestParseLineFeedAsEnter;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([10]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcEnter, 'line feed aliases enter');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseTab;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([9]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcTab, 'tab preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseBackspace;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([127]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcBackspace, 'backspace preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCtrlHBackspaceAlias;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([8]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcBackspace, 'ctrl-h aliases backspace');
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

procedure TestParseEscEscPreservesBothEscapes;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([27, 27]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'first esc parsed');
    Check(LEv.Kind = evKey, 'first esc is key event');
    Check(LEv.Key.Code = kcEsc, 'first esc preserved');
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'second esc parsed');
    Check(LEv.Kind = evKey, 'second esc is key event');
    Check(LEv.Key.Code = kcEsc, 'second esc preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseAltAscii;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { Alt+a = ESC a }
    LTerm.InjectInputBytesForTest([27, Ord('a')]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcChar, 'alt ascii stays char event');
    CheckEqual(Int64(Ord('a')), Int64(LEv.Key.Ch), 'char preserved');
    Check(kmAlt in LEv.Key.Modifiers, 'alt modifier preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseAltEnter;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { Alt+Enter = ESC CR }
    LTerm.InjectInputBytesForTest([27, 13]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcEnter, 'alt enter stays enter key');
    Check(kmAlt in LEv.Key.Modifiers, 'alt modifier preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseAltTab;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { Alt+Tab = ESC HT }
    LTerm.InjectInputBytesForTest([27, 9]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcTab, 'alt tab stays tab key');
    Check(kmAlt in LEv.Key.Modifiers, 'alt modifier preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseAltBackspace;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { Alt+Backspace = ESC DEL }
    LTerm.InjectInputBytesForTest([27, 127]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcBackspace, 'alt backspace stays backspace key');
    Check(kmAlt in LEv.Key.Modifiers, 'alt modifier preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseAltCtrlSpace;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { Alt+Ctrl+Space = ESC NUL }
    LTerm.InjectInputBytesForTest([27, 0]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcChar, 'alt ctrl-space stays char event');
    CheckEqual(Int64(Ord(' ')), Int64(LEv.Key.Ch), 'ctrl-space keeps literal space codepoint');
    Check(kmAlt in LEv.Key.Modifiers, 'alt modifier preserved');
    Check(kmCtrl in LEv.Key.Modifiers, 'ctrl modifier preserved');
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

procedure TestParseArrowDown;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI B = Down }
    LTerm.InjectInputBytesForTest([27, Ord('['), Ord('B')]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcDown, 'down arrow preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseArrowRight;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI C = Right }
    LTerm.InjectInputBytesForTest([27, Ord('['), Ord('C')]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcRight, 'right arrow preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseArrowLeft;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI D = Left }
    LTerm.InjectInputBytesForTest([27, Ord('['), Ord('D')]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcLeft, 'left arrow preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCSIArrowWithCtrlModifier;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 1;5A = Ctrl+Up }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('1'), Ord(';'), Ord('5'), Ord('A')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcUp, 'ctrl+up stays up key');
    Check(kmCtrl in LEv.Key.Modifiers, 'ctrl modifier preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCSIPageDownWithShiftAlt;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 6;4~ = Shift+Alt+PageDown }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('6'), Ord(';'), Ord('4'), Ord('~')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcPageDown, 'pagedown preserved');
    Check(kmShift in LEv.Key.Modifiers, 'shift modifier preserved');
    Check(kmAlt in LEv.Key.Modifiers, 'alt modifier preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCSIHomeWithShift;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 1;2H = Shift+Home }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('1'), Ord(';'), Ord('2'), Ord('H')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcHome, 'home preserved');
    Check(kmShift in LEv.Key.Modifiers, 'shift modifier preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCSIHomePlain;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI H = Home }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('H')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcHome, 'plain csi home preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCSIHomeLegacyTilde;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 1~ = legacy Home }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('1'), Ord('~')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcHome, 'legacy tilde home preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCSIHomeLegacy7Tilde;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 7~ = legacy Home alias }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('7'), Ord('~')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcHome, 'legacy 7-tilde home preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCSIEndWithCtrl;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 1;5F = Ctrl+End }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('1'), Ord(';'), Ord('5'), Ord('F')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcEnd, 'end preserved');
    Check(kmCtrl in LEv.Key.Modifiers, 'ctrl modifier preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCSIEndLegacyTilde;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 4~ = legacy End }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('4'), Ord('~')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcEnd, 'legacy tilde end preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCSIEndPlain;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI F = End }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('F')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcEnd, 'plain csi end preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCSIEndLegacy8Tilde;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 8~ = legacy End alias }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('8'), Ord('~')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcEnd, 'legacy 8-tilde end preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCSIF1LegacyTilde;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 11~ = legacy F1 }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('1'), Ord('1'), Ord('~')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcF, 'function key preserved');
    CheckEqual(Int64(1), Int64(LEv.Key.F), 'legacy tilde F1 preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCSIF4LegacyTilde;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 14~ = legacy F4 }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('1'), Ord('4'), Ord('~')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcF, 'function key preserved');
    CheckEqual(Int64(4), Int64(LEv.Key.F), 'legacy tilde F4 preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCSIF5WithShiftCtrl;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 15;6~ = Shift+Ctrl+F5 }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('1'), Ord('5'), Ord(';'), Ord('6'), Ord('~')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcF, 'function key preserved');
    CheckEqual(Int64(5), Int64(LEv.Key.F), 'F5 preserved');
    Check(kmShift in LEv.Key.Modifiers, 'shift modifier preserved');
    Check(kmCtrl in LEv.Key.Modifiers, 'ctrl modifier preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCSIF6LegacyTilde;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 17~ = legacy F6 }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('1'), Ord('7'), Ord('~')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcF, 'function key preserved');
    CheckEqual(Int64(6), Int64(LEv.Key.F), 'legacy tilde F6 preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCSIF9LegacyTilde;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 20~ = legacy F9 }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('2'), Ord('0'), Ord('~')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcF, 'function key preserved');
    CheckEqual(Int64(9), Int64(LEv.Key.F), 'legacy tilde F9 preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCSIF12WithAlt;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 24;3~ = Alt+F12 }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('2'), Ord('4'), Ord(';'), Ord('3'), Ord('~')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcF, 'function key preserved');
    CheckEqual(Int64(12), Int64(LEv.Key.F), 'F12 preserved');
    Check(kmAlt in LEv.Key.Modifiers, 'alt modifier preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCSIF11LegacyTilde;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 23~ = legacy F11 }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('2'), Ord('3'), Ord('~')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcF, 'function key preserved');
    CheckEqual(Int64(11), Int64(LEv.Key.F), 'legacy tilde F11 preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCSIInsert;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 2~ = Insert }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('2'), Ord('~')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcInsert, 'insert preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCSIDeleteWithCtrl;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 3;5~ = Ctrl+Delete }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('3'), Ord(';'), Ord('5'), Ord('~')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcDelete, 'delete preserved');
    Check(kmCtrl in LEv.Key.Modifiers, 'ctrl modifier preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCSIPageUpWithShift;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 5;2~ = Shift+PageUp }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('5'), Ord(';'), Ord('2'), Ord('~')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcPageUp, 'pageup preserved');
    Check(kmShift in LEv.Key.Modifiers, 'shift modifier preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCSIF10WithAltCtrl;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 21;7~ = Alt+Ctrl+F10 }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('2'), Ord('1'), Ord(';'), Ord('7'), Ord('~')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcF, 'function key preserved');
    CheckEqual(Int64(10), Int64(LEv.Key.F), 'F10 preserved');
    Check(kmAlt in LEv.Key.Modifiers, 'alt modifier preserved');
    Check(kmCtrl in LEv.Key.Modifiers, 'ctrl modifier preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseBracketedPasteStart;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 200~ = bracketed paste start; it should surface as evPaste }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('2'), Ord('0'), Ord('0'), Ord('~')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evPaste, 'paste start surfaces as paste event');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseSS3LegacyF1;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { SS3 P = legacy F1 }
    LTerm.InjectInputBytesForTest([
      27, Ord('O'), Ord('P')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcF, 'legacy function key preserved');
    CheckEqual(Int64(1), Int64(LEv.Key.F), 'legacy F1 preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseSS3LegacyF2;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { SS3 Q = legacy F2 }
    LTerm.InjectInputBytesForTest([
      27, Ord('O'), Ord('Q')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcF, 'legacy function key preserved');
    CheckEqual(Int64(2), Int64(LEv.Key.F), 'legacy F2 preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseSS3LegacyF3;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { SS3 R = legacy F3 }
    LTerm.InjectInputBytesForTest([
      27, Ord('O'), Ord('R')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcF, 'legacy function key preserved');
    CheckEqual(Int64(3), Int64(LEv.Key.F), 'legacy F3 preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseSS3LegacyF4;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { SS3 S = legacy F4 }
    LTerm.InjectInputBytesForTest([
      27, Ord('O'), Ord('S')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcF, 'legacy function key preserved');
    CheckEqual(Int64(4), Int64(LEv.Key.F), 'legacy F4 preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseSS3LegacyEnd;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { SS3 F = legacy End }
    LTerm.InjectInputBytesForTest([
      27, Ord('O'), Ord('F')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcEnd, 'legacy end preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseSS3LegacyHome;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { SS3 H = legacy Home }
    LTerm.InjectInputBytesForTest([
      27, Ord('O'), Ord('H')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key event');
    Check(LEv.Key.Code = kcHome, 'legacy home preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseSgrMouseDown;
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

procedure TestParseSgrMouseMiddleDown;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI < 1;5;3M = middle button down at (4,2) 0-based }
    LTerm.InjectInputBytesForTest([27, Ord('['), Ord('<'),
      Ord('1'), Ord(';'), Ord('5'), Ord(';'), Ord('3'), Ord('M')]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evMouse, 'mouse event');
    Check(LEv.Mouse.Kind = mkDown, 'mouse down');
    Check(LEv.Mouse.Button = mbMiddle, 'middle button preserved');
    CheckEqual(Int64(4), Int64(LEv.Mouse.X), 'x=4 (wire 5 - 1)');
    CheckEqual(Int64(2), Int64(LEv.Mouse.Y), 'y=2 (wire 3 - 1)');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseSgrMouseRightDown;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI < 2;5;3M = right button down at (4,2) 0-based }
    LTerm.InjectInputBytesForTest([27, Ord('['), Ord('<'),
      Ord('2'), Ord(';'), Ord('5'), Ord(';'), Ord('3'), Ord('M')]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evMouse, 'mouse event');
    Check(LEv.Mouse.Kind = mkDown, 'mouse down');
    Check(LEv.Mouse.Button = mbRight, 'right button preserved');
    CheckEqual(Int64(4), Int64(LEv.Mouse.X), 'x=4 (wire 5 - 1)');
    CheckEqual(Int64(2), Int64(LEv.Mouse.Y), 'y=2 (wire 3 - 1)');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseSgrMouseRelease;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI < 0;5;3m = left button release at (4,2) 0-based }
    LTerm.InjectInputBytesForTest([27, Ord('['), Ord('<'),
      Ord('0'), Ord(';'), Ord('5'), Ord(';'), Ord('3'), Ord('m')]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evMouse, 'mouse event');
    Check(LEv.Mouse.Kind = mkUp, 'mouse up');
    Check(LEv.Mouse.Button = mbLeft, 'release keeps left button identity');
    CheckEqual(Int64(4), Int64(LEv.Mouse.X), 'x=4 (wire 5 - 1)');
    CheckEqual(Int64(2), Int64(LEv.Mouse.Y), 'y=2 (wire 3 - 1)');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseSgrMouseMiddleRelease;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI < 1;5;3m = middle button release at (4,2) 0-based }
    LTerm.InjectInputBytesForTest([27, Ord('['), Ord('<'),
      Ord('1'), Ord(';'), Ord('5'), Ord(';'), Ord('3'), Ord('m')]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evMouse, 'mouse event');
    Check(LEv.Mouse.Kind = mkUp, 'mouse up');
    Check(LEv.Mouse.Button = mbMiddle, 'release keeps middle button identity');
    CheckEqual(Int64(4), Int64(LEv.Mouse.X), 'x=4 (wire 5 - 1)');
    CheckEqual(Int64(2), Int64(LEv.Mouse.Y), 'y=2 (wire 3 - 1)');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseSgrMouseRightRelease;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI < 2;5;3m = right button release at (4,2) 0-based }
    LTerm.InjectInputBytesForTest([27, Ord('['), Ord('<'),
      Ord('2'), Ord(';'), Ord('5'), Ord(';'), Ord('3'), Ord('m')]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evMouse, 'mouse event');
    Check(LEv.Mouse.Kind = mkUp, 'mouse up');
    Check(LEv.Mouse.Button = mbRight, 'release keeps right button identity');
    CheckEqual(Int64(4), Int64(LEv.Mouse.X), 'x=4 (wire 5 - 1)');
    CheckEqual(Int64(2), Int64(LEv.Mouse.Y), 'y=2 (wire 3 - 1)');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseSgrMouseMove;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI < 35;5;3M = motion-only move at (4,2) 0-based }
    LTerm.InjectInputBytesForTest([27, Ord('['), Ord('<'),
      Ord('3'), Ord('5'), Ord(';'), Ord('5'), Ord(';'), Ord('3'), Ord('M')]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evMouse, 'mouse event');
    Check(LEv.Mouse.Kind = mkMoved, 'motion-only event maps to move');
    Check(LEv.Mouse.Button = mbNone, 'motion-only event has no button');
    CheckEqual(Int64(4), Int64(LEv.Mouse.X), 'x=4 (wire 5 - 1)');
    CheckEqual(Int64(2), Int64(LEv.Mouse.Y), 'y=2 (wire 3 - 1)');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseSgrMouseMiddleDrag;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI < 33;5;3M = middle drag at (4,2) 0-based }
    LTerm.InjectInputBytesForTest([27, Ord('['), Ord('<'),
      Ord('3'), Ord('3'), Ord(';'), Ord('5'), Ord(';'), Ord('3'), Ord('M')]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evMouse, 'mouse event');
    Check(LEv.Mouse.Kind = mkDrag, 'motion with middle button maps to drag');
    Check(LEv.Mouse.Button = mbMiddle, 'drag keeps middle button identity');
    CheckEqual(Int64(4), Int64(LEv.Mouse.X), 'x=4 (wire 5 - 1)');
    CheckEqual(Int64(2), Int64(LEv.Mouse.Y), 'y=2 (wire 3 - 1)');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseSgrMouseRightDrag;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI < 34;5;3M = right drag at (4,2) 0-based }
    LTerm.InjectInputBytesForTest([27, Ord('['), Ord('<'),
      Ord('3'), Ord('4'), Ord(';'), Ord('5'), Ord(';'), Ord('3'), Ord('M')]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evMouse, 'mouse event');
    Check(LEv.Mouse.Kind = mkDrag, 'motion with right button maps to drag');
    Check(LEv.Mouse.Button = mbRight, 'drag keeps right button identity');
    CheckEqual(Int64(4), Int64(LEv.Mouse.X), 'x=4 (wire 5 - 1)');
    CheckEqual(Int64(2), Int64(LEv.Mouse.Y), 'y=2 (wire 3 - 1)');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseSgrMouseDragWithModifiers;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI < 44;5;3M = left drag + shift + alt at (4,2) 0-based }
    LTerm.InjectInputBytesForTest([27, Ord('['), Ord('<'),
      Ord('4'), Ord('4'), Ord(';'), Ord('5'), Ord(';'), Ord('3'), Ord('M')]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evMouse, 'mouse event');
    Check(LEv.Mouse.Kind = mkDrag, 'motion with button maps to drag');
    Check(LEv.Mouse.Button = mbLeft, 'drag keeps left button identity');
    Check(kmShift in LEv.Mouse.Modifiers, 'shift modifier preserved');
    Check(kmAlt in LEv.Mouse.Modifiers, 'alt modifier preserved');
    CheckEqual(Int64(4), Int64(LEv.Mouse.X), 'x=4 (wire 5 - 1)');
    CheckEqual(Int64(2), Int64(LEv.Mouse.Y), 'y=2 (wire 3 - 1)');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseSgrMouseScrollUp;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI < 64;5;3M = scroll up at (4,2) 0-based }
    LTerm.InjectInputBytesForTest([27, Ord('['), Ord('<'),
      Ord('6'), Ord('4'), Ord(';'), Ord('5'), Ord(';'), Ord('3'), Ord('M')]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evMouse, 'mouse event');
    Check(LEv.Mouse.Kind = mkScrollUp, 'scroll-up preserved');
    Check(LEv.Mouse.Button = mbNone, 'scroll has no button payload');
    CheckEqual(Int64(4), Int64(LEv.Mouse.X), 'x=4 (wire 5 - 1)');
    CheckEqual(Int64(2), Int64(LEv.Mouse.Y), 'y=2 (wire 3 - 1)');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseSgrMouseScrollDownWithCtrl;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI < 81;5;3M = scroll down + ctrl at (4,2) 0-based }
    LTerm.InjectInputBytesForTest([27, Ord('['), Ord('<'),
      Ord('8'), Ord('1'), Ord(';'), Ord('5'), Ord(';'), Ord('3'), Ord('M')]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evMouse, 'mouse event');
    Check(LEv.Mouse.Kind = mkScrollDown, 'scroll-down preserved');
    Check(LEv.Mouse.Button = mbNone, 'scroll has no button payload');
    Check(kmCtrl in LEv.Mouse.Modifiers, 'ctrl modifier preserved');
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

procedure TestParseCtrlA;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([1]);  { Ctrl-A = byte 1 }
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key');
    Check(kmCtrl in LEv.Key.Modifiers, 'ctrl modifier');
    CheckEqual(Int64(Ord('a')), Int64(LEv.Key.Ch), 'ch = a');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCtrlG;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([7]);  { Ctrl-G = byte 7 }
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key');
    Check(kmCtrl in LEv.Key.Modifiers, 'ctrl modifier');
    CheckEqual(Int64(Ord('g')), Int64(LEv.Key.Ch), 'ch = g');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCtrlK;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([11]);  { Ctrl-K = byte 11 }
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key');
    Check(kmCtrl in LEv.Key.Modifiers, 'ctrl modifier');
    CheckEqual(Int64(Ord('k')), Int64(LEv.Key.Ch), 'ch = k');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCtrlN;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([14]);  { Ctrl-N = byte 14 }
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key');
    Check(kmCtrl in LEv.Key.Modifiers, 'ctrl modifier');
    CheckEqual(Int64(Ord('n')), Int64(LEv.Key.Ch), 'ch = n');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCtrlZ;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([26]);  { Ctrl-Z = byte 26 }
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key');
    Check(kmCtrl in LEv.Key.Modifiers, 'ctrl modifier');
    CheckEqual(Int64(Ord('z')), Int64(LEv.Key.Ch), 'ch = z');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCtrlSpace;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([0]);  { Ctrl-Space = NUL }
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key');
    Check(LEv.Key.Code = kcChar, 'ctrl-space stays char event');
    Check(kmCtrl in LEv.Key.Modifiers, 'ctrl modifier');
    CheckEqual(Int64(Ord(' ')), Int64(LEv.Key.Ch), 'ch = space');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCtrlPunctuation;
const
  INPUT_BYTES: array[0..3] of Byte = (28, 29, 30, 31);
  EXPECTED_CHARS: array[0..3] of LongWord = (
    Ord('\'),
    Ord(']'),
    Ord('^'),
    Ord('_')
  );
var
  I: Integer;
  LTerm: TTerminal;
  LEv: TEvent;
begin
  for I := Low(INPUT_BYTES) to High(INPUT_BYTES) do
  begin
    LTerm := TTerminal.Create;
    try
      LTerm.InjectInputBytesForTest([INPUT_BYTES[I]]);
      Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
      Check(LEv.Kind = evKey, 'key');
      Check(LEv.Key.Code = kcChar, 'ctrl punctuation stays char event');
      Check(kmCtrl in LEv.Key.Modifiers, 'ctrl modifier');
      CheckEqual(Int64(EXPECTED_CHARS[I]), Int64(LEv.Key.Ch), 'control punctuation char');
    finally
      LTerm.Free;
    end;
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

procedure TestParseAltUTF8;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { Alt + '中' = ESC + E4 B8 AD }
    LTerm.InjectInputBytesForTest([27, $E4, $B8, $AD]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'key');
    Check(LEv.Key.Code = kcChar, 'alt utf8 stays char event');
    Check(kmAlt in LEv.Key.Modifiers, 'alt modifier preserved');
    CheckEqual(Int64($4E2D), Int64(LEv.Key.Ch), 'codepoint U+4E2D');
  finally
    LTerm.Free;
  end;
end;

procedure TestInvalidBytesRecoverFollowingUTF8;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([$80, $FF, $E4, $B8, $AD]);
    Check(LTerm.PollQueuedEventForTest(False, LEv),
      'scanner recovers after invalid bytes');
    Check(LEv.Kind = evKey, 'recovered event is key event');
    Check(LEv.Key.Code = kcChar, 'recovered unicode stays char event');
    CheckEqual(Int64($4E2D), Int64(LEv.Key.Ch),
      'invalid bytes are skipped before codepoint U+4E2D');
  finally
    LTerm.Free;
  end;
end;

procedure TestInvalidByteBetweenEventsIsSkipped;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([Ord('A'), $80, Ord('B')]);
    Check(LTerm.PollQueuedEventForTest(False, LEv), 'first event parsed');
    Check(LEv.Kind = evKey, 'first event is key event');
    Check(LEv.Key.Code = kcChar, 'first event stays char event');
    CheckEqual(Int64(Ord('A')), Int64(LEv.Key.Ch), 'first char preserved');

    Check(LTerm.PollQueuedEventForTest(False, LEv),
      'second event parses after invalid byte is skipped');
    Check(LEv.Kind = evKey, 'second event is key event');
    Check(LEv.Key.Code = kcChar, 'second event stays char event');
    CheckEqual(Int64(Ord('B')), Int64(LEv.Key.Ch),
      'invalid byte between events does not block following char');
  finally
    LTerm.Free;
  end;
end;

procedure TestLoneEscWaitsForMoreBeforeEOF;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([27]);
    Check(not LTerm.PollQueuedEventForTest(False, LEv), 'lone esc waits for more bytes before eof');
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'eof resolves buffered esc');
    Check(LEv.Kind = evKey, 'esc remains key event');
    Check(LEv.Key.Code = kcEsc, 'buffered esc preserved at eof');
  finally
    LTerm.Free;
  end;
end;

procedure TestIncompleteCSIWaitsForMore;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([27, Ord('[')]);
    Check(not LTerm.PollQueuedEventForTest(False, LEv), 'incomplete csi waits for more bytes');
    LTerm.InjectInputBytesForTest([Ord('A')]);
    Check(LTerm.PollQueuedEventForTest(False, LEv), 'completed csi parses once remainder arrives');
    Check(LEv.Kind = evKey, 'completed csi is key event');
    Check(LEv.Key.Code = kcUp, 'buffered csi resolves to up arrow');
  finally
    LTerm.Free;
  end;
end;

procedure TestIncompleteSS3WaitsForMore;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([27, Ord('O')]);
    Check(not LTerm.PollQueuedEventForTest(False, LEv), 'incomplete ss3 waits for more bytes');
    LTerm.InjectInputBytesForTest([Ord('P')]);
    Check(LTerm.PollQueuedEventForTest(False, LEv), 'completed ss3 parses once remainder arrives');
    Check(LEv.Kind = evKey, 'completed ss3 is key event');
    Check(LEv.Key.Code = kcF, 'buffered ss3 resolves to function key');
    CheckEqual(Int64(1), Int64(LEv.Key.F), 'buffered ss3 preserves F1');
  finally
    LTerm.Free;
  end;
end;

procedure TestIncompleteUTF8WaitsForMore;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([$E4]);
    Check(not LTerm.PollQueuedEventForTest(False, LEv), 'incomplete utf8 waits for more bytes');
    LTerm.InjectInputBytesForTest([$B8, $AD]);
    Check(LTerm.PollQueuedEventForTest(False, LEv), 'completed utf8 parses once remainder arrives');
    Check(LEv.Kind = evKey, 'completed utf8 is key event');
    CheckEqual(Int64($4E2D), Int64(LEv.Key.Ch), 'buffered utf8 preserves codepoint U+4E2D');
  finally
    LTerm.Free;
  end;
end;

procedure TestIncompleteAltUTF8WaitsForMore;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([27, $E4]);
    Check(not LTerm.PollQueuedEventForTest(False, LEv), 'incomplete alt utf8 waits for more bytes');
    LTerm.InjectInputBytesForTest([$B8, $AD]);
    Check(LTerm.PollQueuedEventForTest(False, LEv), 'completed alt utf8 parses once remainder arrives');
    Check(LEv.Kind = evKey, 'completed alt utf8 is key event');
    Check(LEv.Key.Code = kcChar, 'buffered alt utf8 stays char event');
    Check(kmAlt in LEv.Key.Modifiers, 'buffered alt utf8 preserves alt modifier');
    CheckEqual(Int64($4E2D), Int64(LEv.Key.Ch), 'buffered alt utf8 preserves codepoint U+4E2D');
  finally
    LTerm.Free;
  end;
end;

procedure TestIncompleteKittyKeyboardWaitsForMore;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('9'), Ord(';'), Ord('2')
    ]);
    Check(not LTerm.PollQueuedEventForTest(False, LEv),
      'incomplete kitty keyboard waits for more bytes');
    LTerm.InjectInputBytesForTest([Ord('u')]);
    Check(LTerm.PollQueuedEventForTest(False, LEv),
      'completed kitty keyboard parses once remainder arrives');
    Check(LEv.Kind = evKey, 'completed kitty keyboard is key event');
    Check(LEv.Key.Code = kcBackTab,
      'buffered kitty keyboard resolves to backtab');
    Check(not (kmShift in LEv.Key.Modifiers),
      'kitty backtab still strips synthetic shift modifier after buffering');
  finally
    LTerm.Free;
  end;
end;

procedure TestIncompleteSgrMouseWaitsForMore;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('<'), Ord('0'), Ord(';'), Ord('2'), Ord(';'), Ord('3')
    ]);
    Check(not LTerm.PollQueuedEventForTest(False, LEv),
      'incomplete sgr mouse waits for more bytes');
    LTerm.InjectInputBytesForTest([Ord('M')]);
    Check(LTerm.PollQueuedEventForTest(False, LEv),
      'completed sgr mouse parses once remainder arrives');
    Check(LEv.Kind = evMouse, 'completed sgr mouse is mouse event');
    Check(LEv.Mouse.Kind = mkDown, 'buffered sgr mouse resolves to mouse down');
    Check(LEv.Mouse.Button = mbLeft, 'buffered sgr mouse preserves left button');
    CheckEqual(Int64(1), Int64(LEv.Mouse.X), 'buffered sgr mouse preserves x');
    CheckEqual(Int64(2), Int64(LEv.Mouse.Y), 'buffered sgr mouse preserves y');
  finally
    LTerm.Free;
  end;
end;

procedure TestIncompleteKittyKeyboardPrefixPreservesEsc;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { ESC [ 9;2 timed out at EOF should still preserve the leading Esc. }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('9'), Ord(';'), Ord('2')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'esc still surfaces');
    Check(LEv.Kind = evKey, 'esc remains key event');
    Check(LEv.Key.Code = kcEsc, 'incomplete kitty keyboard falls back to bare esc');

    Check(LTerm.PollQueuedEventForTest(True, LEv), 'first remainder still parses');
    Check(LEv.Kind = evKey, 'first remainder remains key event');
    Check(LEv.Key.Code = kcChar, 'literal bracket stays char event');
    CheckEqual(Int64(Ord('[')), Int64(LEv.Key.Ch), 'literal bracket preserved');

    Check(LTerm.PollQueuedEventForTest(True, LEv), 'second remainder still parses');
    Check(LEv.Kind = evKey, 'second remainder remains key event');
    Check(LEv.Key.Code = kcChar, 'literal digit stays char event');
    CheckEqual(Int64(Ord('9')), Int64(LEv.Key.Ch), 'literal digit preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestIncompleteSgrMousePrefixPreservesEsc;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { ESC [ <0;2;3 timed out at EOF should still preserve the leading Esc. }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('<'), Ord('0'), Ord(';'), Ord('2'), Ord(';'), Ord('3')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'esc still surfaces');
    Check(LEv.Kind = evKey, 'esc remains key event');
    Check(LEv.Key.Code = kcEsc, 'incomplete sgr mouse falls back to bare esc');

    Check(LTerm.PollQueuedEventForTest(True, LEv), 'first remainder still parses');
    Check(LEv.Kind = evKey, 'first remainder remains key event');
    Check(LEv.Key.Code = kcChar, 'literal bracket stays char event');
    CheckEqual(Int64(Ord('[')), Int64(LEv.Key.Ch), 'literal bracket preserved');

    Check(LTerm.PollQueuedEventForTest(True, LEv), 'second remainder still parses');
    Check(LEv.Kind = evKey, 'second remainder remains key event');
    Check(LEv.Key.Code = kcChar, 'literal less-than stays char event');
    CheckEqual(Int64(Ord('<')), Int64(LEv.Key.Ch), 'literal less-than preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestIncompleteCSIPrefixPreservesEsc;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { ESC [ timed out at EOF should still preserve the leading Esc. }
    LTerm.InjectInputBytesForTest([27, Ord('[')]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'esc still surfaces');
    Check(LEv.Kind = evKey, 'esc remains key event');
    Check(LEv.Key.Code = kcEsc, 'incomplete CSI prefix falls back to bare esc');
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'remainder still parses');
    Check(LEv.Kind = evKey, 'remainder remains key event');
    Check(LEv.Key.Code = kcChar, 'literal remainder stays char event');
    CheckEqual(Int64(Ord('[')), Int64(LEv.Key.Ch), 'literal remainder preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestIncompleteSS3PrefixPreservesEsc;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { ESC O timed out at EOF should still preserve the leading Esc. }
    LTerm.InjectInputBytesForTest([27, Ord('O')]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'esc still surfaces');
    Check(LEv.Kind = evKey, 'esc remains key event');
    Check(LEv.Key.Code = kcEsc, 'incomplete SS3 prefix falls back to bare esc');
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'remainder still parses');
    Check(LEv.Kind = evKey, 'remainder remains key event');
    Check(LEv.Key.Code = kcChar, 'literal remainder stays char event');
    CheckEqual(Int64(Ord('O')), Int64(LEv.Key.Ch), 'literal remainder preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestIncompleteAltUTF8PrefixPreservesEsc;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { ESC + truncated UTF-8 lead byte should still preserve the leading Esc. }
    LTerm.InjectInputBytesForTest([27, $E4]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'esc still surfaces');
    Check(LEv.Kind = evKey, 'esc remains key event');
    Check(LEv.Key.Code = kcEsc, 'incomplete alt utf8 prefix falls back to bare esc');
  finally
    LTerm.Free;
  end;
end;

procedure TestInvalidAltUTF8LeadPreservesEsc;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { ESC + invalid UTF-8 continuation byte should still preserve the leading Esc. }
    LTerm.InjectInputBytesForTest([27, $80]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'esc still surfaces');
    Check(LEv.Kind = evKey, 'esc remains key event');
    Check(LEv.Key.Code = kcEsc, 'invalid alt utf8 lead falls back to bare esc');
  finally
    LTerm.Free;
  end;
end;

procedure TestBracketedPasteEndIsSwallowed;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 201~ = bracketed paste end; it should not surface as evNone }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('2'), Ord('0'), Ord('1'), Ord('~'),
      Ord('A')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'next real event still parses');
    Check(LEv.Kind = evKey, 'paste end marker stays invisible to consumers');
    Check(LEv.Key.Code = kcChar, 'next event is key char');
    CheckEqual(Int64(Ord('A')), Int64(LEv.Key.Ch), 'next event remains queued after paste end marker');
  finally
    LTerm.Free;
  end;
end;

procedure TestParseCSIBackTab;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI Z = xterm Shift+Tab / BackTab }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('Z')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'xterm backtab is key event');
    Check(LEv.Key.Code = kcBackTab, 'xterm backtab preserved');
    Check(not (kmShift in LEv.Key.Modifiers), 'backtab does not leak synthetic shift modifier');
  finally
    LTerm.Free;
  end;
end;

procedure TestKittyKeyboardShiftTabNormalizesToBackTab;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 9;2u = kitty keyboard Shift+Tab }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('9'), Ord(';'), Ord('2'), Ord('u')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'kitty shift-tab is key event');
    Check(LEv.Key.Code = kcBackTab, 'kitty shift-tab normalizes to backtab');
    Check(not (kmShift in LEv.Key.Modifiers), 'backtab does not leak synthetic shift modifier');
  finally
    LTerm.Free;
  end;
end;

procedure TestKittyKeyboardShiftAltTabNormalizesToBackTabWithAlt;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 9;4u = kitty keyboard Shift+Alt+Tab }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('9'), Ord(';'), Ord('4'), Ord('u')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'kitty shift-alt-tab is key event');
    Check(LEv.Key.Code = kcBackTab, 'kitty shift-alt-tab normalizes to backtab');
    Check(not (kmShift in LEv.Key.Modifiers),
      'backtab still strips synthetic shift modifier');
    Check(kmAlt in LEv.Key.Modifiers, 'alt modifier survives normalization');
  finally
    LTerm.Free;
  end;
end;

procedure TestKittyKeyboardShiftAltCtrlTabNormalizesToBackTabWithAltCtrl;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 9;8u = kitty keyboard Shift+Alt+Ctrl+Tab }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('9'), Ord(';'), Ord('8'), Ord('u')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'kitty shift-alt-ctrl-tab is key event');
    Check(LEv.Key.Code = kcBackTab,
      'kitty shift-alt-ctrl-tab normalizes to backtab');
    Check(not (kmShift in LEv.Key.Modifiers),
      'backtab still strips synthetic shift modifier');
    Check(kmAlt in LEv.Key.Modifiers, 'alt modifier survives normalization');
    Check(kmCtrl in LEv.Key.Modifiers, 'ctrl modifier survives normalization');
  finally
    LTerm.Free;
  end;
end;

procedure TestKittyKeyboardAltTabPreservesModifier;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 9;3u = kitty keyboard Alt+Tab }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('9'), Ord(';'), Ord('3'), Ord('u')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'kitty alt-tab is key event');
    Check(LEv.Key.Code = kcTab, 'kitty alt-tab stays tab key');
    Check(kmAlt in LEv.Key.Modifiers, 'alt modifier preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestKittyKeyboardShiftEnterPreservesModifier;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 13;2u = kitty keyboard Shift+Enter }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('1'), Ord('3'), Ord(';'), Ord('2'), Ord('u')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'kitty shift-enter is key event');
    Check(LEv.Key.Code = kcEnter, 'kitty shift-enter stays enter key');
    Check(kmShift in LEv.Key.Modifiers, 'shift modifier preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestKittyKeyboardCtrlEscPreservesModifier;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 27;5u = kitty keyboard Ctrl+Esc }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('2'), Ord('7'), Ord(';'), Ord('5'), Ord('u')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'kitty ctrl-esc is key event');
    Check(LEv.Key.Code = kcEsc, 'kitty ctrl-esc stays esc key');
    Check(kmCtrl in LEv.Key.Modifiers, 'ctrl modifier preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestKittyKeyboardAltBackspacePreservesModifier;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 127;3u = kitty keyboard Alt+Backspace }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('1'), Ord('2'), Ord('7'), Ord(';'), Ord('3'), Ord('u')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'kitty alt-backspace is key event');
    Check(LEv.Key.Code = kcBackspace, 'kitty alt-backspace stays backspace key');
    Check(kmAlt in LEv.Key.Modifiers, 'alt modifier preserved');
  finally
    LTerm.Free;
  end;
end;

procedure TestKittyKeyboardAltCodepointPreservesModifier;
var
  LTerm: TTerminal;
  LEv: TEvent;
begin
  LTerm := TTerminal.Create;
  try
    { CSI 97;3u = kitty keyboard Alt+a }
    LTerm.InjectInputBytesForTest([
      27, Ord('['), Ord('9'), Ord('7'), Ord(';'), Ord('3'), Ord('u')
    ]);
    Check(LTerm.PollQueuedEventForTest(True, LEv), 'parsed');
    Check(LEv.Kind = evKey, 'kitty alt+a is key event');
    Check(LEv.Key.Code = kcChar, 'kitty alt+a stays char event');
    CheckEqual(Int64(Ord('a')), Int64(LEv.Key.Ch), 'kitty generic codepoint preserved');
    Check(kmAlt in LEv.Key.Modifiers, 'alt modifier preserved');
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

procedure TestTerminalOptionsDefaultMatchesEditorDefault;
var
  LDefault: TTerminalOptions;
  LEditor: TTerminalOptions;
begin
  LDefault := TTerminalOptions.Default;
  LEditor := TTerminalOptions.EditorDefault;

  Check(Ord(LDefault.MouseMode) = Ord(LEditor.MouseMode),
    'default mouse mode matches editor default');
  Check(Ord(LDefault.WheelMode) = Ord(LEditor.WheelMode),
    'default wheel mode matches editor default');
  Check(Ord(LDefault.SelectionMode) = Ord(LEditor.SelectionMode),
    'default selection mode matches editor default');
  Check(Ord(LDefault.EffectiveMouseMode) = Ord(tmMouseFull),
    'editor default keeps full mouse mode active');
  Check(LDefault.RequestsMouseTracking,
    'editor default requests mouse tracking');
  Check(not LDefault.UsesAlternateScrollKeys,
    'editor default does not enable alternate scroll keys');
end;

procedure TestTerminalOptionsNativeSelectionWheelSuppressesMouseTracking;
var
  LOptions: TTerminalOptions;
begin
  LOptions := TTerminalOptions.NativeSelectionWheel;

  Check(Ord(LOptions.SelectionMode) = Ord(tsTerminalNative),
    'native selection wheel enables terminal-native selection');
  Check(Ord(LOptions.EffectiveMouseMode) = Ord(tmMouseNone),
    'native selection suppresses runtime mouse tracking');
  Check(not LOptions.RequestsMouseTracking,
    'native selection does not request mouse tracking');
  Check(LOptions.UsesAlternateScrollKeys,
    'native selection wheel enables alternate scroll keys');
end;

procedure TestTerminalOptionsApplicationSelectionPreservesConfiguredMouseMode;
var
  LOptions: TTerminalOptions;
begin
  LOptions.MouseMode := tmMouseDrag;
  LOptions.WheelMode := twWheelOff;
  LOptions.SelectionMode := tsApplication;

  Check(Ord(LOptions.EffectiveMouseMode) = Ord(tmMouseDrag),
    'application selection preserves configured mouse mode');
  Check(LOptions.RequestsMouseTracking,
    'application selection still requests mouse tracking');
  Check(not LOptions.UsesAlternateScrollKeys,
    'wheel-off keeps alternate scroll disabled');
end;

procedure TestCapabilityProfileSeparatesDetectedAndActiveStates;
var
  LProfile: TTuiTerminalCapabilityProfile;
begin
  LProfile := TTerminal.DetectCapabilityProfileFromHints(
    'truecolor',
    'kitty',
    'xterm-kitty',
    '',
    'kitty-window');

  Check(LProfile.Truecolor.Requested, 'truecolor requested by default');
  Check(LProfile.Truecolor.Detected, 'truecolor env hint is recorded');
  Check(LProfile.Truecolor.Active, 'truecolor becomes active when hint is sufficient');
  Check(not LProfile.Truecolor.Verified, 'truecolor is not yet verified');

  Check(LProfile.KittyKeyboard.Requested, 'kitty keyboard requested by default');
  Check(LProfile.KittyKeyboard.Detected, 'kitty keyboard env hint is recorded');
  Check(not LProfile.KittyKeyboard.Active, 'kitty keyboard stays inactive before negotiation');
  Check(Pos('negotiation', LProfile.KittyKeyboard.FallbackReason) > 0,
    'kitty keyboard fallback explains missing negotiation');

  Check(LProfile.ImageProtocol.Status.Requested, 'image protocol requested by default');
  Check(LProfile.ImageProtocol.Status.Detected, 'kitty image protocol is detected');
  Check(LProfile.ImageProtocol.Status.Active, 'kitty image protocol is active in current runtime');
  CheckEqual(Ord(ipKitty), Ord(LProfile.ImageProtocol.DetectedProtocol),
    'detected image protocol is kitty');
  CheckEqual(Ord(ipKitty), Ord(LProfile.ImageProtocol.ActiveProtocol),
    'active image protocol is kitty');
end;

procedure TestCapabilityProfileFallsBackConservatively;
var
  LProfile: TTuiTerminalCapabilityProfile;
begin
  LProfile := TTerminal.DetectCapabilityProfileFromHints('', '', '', '', '');

  Check(not LProfile.Truecolor.Detected, 'truecolor missing hints stays undetected');
  Check(not LProfile.Truecolor.Active, 'truecolor missing hints stays inactive');
  Check(Pos('env-hint-missing', LProfile.Truecolor.FallbackReason) > 0,
    'truecolor fallback reason is explicit');

  Check(not LProfile.KittyKeyboard.Detected, 'kitty keyboard missing hints stays undetected');
  Check(not LProfile.KittyKeyboard.Active, 'kitty keyboard missing hints stays inactive');

  Check(not LProfile.ImageProtocol.Status.Detected,
    'enhanced image protocol missing hints stays undetected');
  Check(not LProfile.ImageProtocol.Status.Active,
    'enhanced image protocol missing hints stays inactive');
  CheckEqual(Ord(ipHalfBlock), Ord(LProfile.ImageProtocol.DetectedProtocol),
    'detected image protocol falls back to half-block');
  CheckEqual(Ord(ipHalfBlock), Ord(LProfile.ImageProtocol.ActiveProtocol),
    'active image protocol falls back to half-block');
  Check(Pos('half-block-fallback', LProfile.ImageProtocol.Status.FallbackReason) > 0,
    'image fallback reason is explicit');
end;

procedure TestKittyKeyboardCandidateUsesKittyTerminalHints;
var
  LProfile: TTuiTerminalCapabilityProfile;
begin
  LProfile := TTerminal.DetectCapabilityProfileFromHints(
    '',
    '',
    'xterm-kitty',
    '',
    'kitty-window');

  Check(LProfile.KittyKeyboard.Requested, 'kitty keyboard requested by default');
  Check(LProfile.KittyKeyboard.Detected,
    'kitty terminal hints count as candidate support');
  Check(not LProfile.KittyKeyboard.Active,
    'kitty keyboard still stays inactive before negotiation');
  Check(Pos('negotiation', LProfile.KittyKeyboard.FallbackReason) > 0,
    'kitty terminal hints still report missing negotiation');
end;

procedure TestBeginFrameRequiresActiveTuiMode;
var
  LTerm: TTerminal;
begin
  LTerm := TTerminal.Create;
  try
    try
      LTerm.BeginFrame;
      Fail('begin frame without runtime: expected ETuiBackend');
    except
      on E: ETuiBackend do
        Check(Pos('requires active TUI mode', E.Message) > 0,
          'begin frame without runtime: unexpected message "' + E.Message + '"');
    end;
  finally
    LTerm.Free;
  end;
end;

procedure TestEndFrameRequiresActiveBeginFrame;
var
  LTerm: TTerminal;
  LFrame: TFrame;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InitializeFrameRuntimeForTest(TRect.Make(0, 0, 4, 2));
    FillChar(LFrame, SizeOf(LFrame), 0);
    LFrame.FrameId := 1;
    try
      LTerm.EndFrame(LFrame);
      Fail('end frame without begin frame: expected ETuiBackend');
    except
      on E: ETuiBackend do
        Check(Pos('called without active BeginFrame', E.Message) > 0,
          'end frame without begin frame: unexpected message "' + E.Message + '"');
    end;
  finally
    LTerm.Free;
  end;
end;

procedure TestBeginFrameRejectsActiveFrame;
var
  LTerm: TTerminal;
  LFrame: TFrame;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InitializeFrameRuntimeForTest(TRect.Make(0, 0, 4, 2));
    LFrame := LTerm.BeginFrame;
    Check(LFrame.FrameId <> 0, 'first begin frame returns a valid frame id');
    try
      LTerm.BeginFrame;
      Fail('begin frame rejects active frame: expected ETuiBackend');
    except
      on E: ETuiBackend do
        Check(Pos('active frame', E.Message) > 0,
          'begin frame rejects active frame: unexpected message "' + E.Message + '"');
    end;
  finally
    LTerm.Free;
  end;
end;

procedure TestEndFrameRejectsStaleFrame;
var
  LTerm: TTerminal;
  LFrame1, LFrame2: TFrame;
begin
  LTerm := TTerminal.Create;
  try
    LTerm.InitializeFrameRuntimeForTest(TRect.Make(0, 0, 4, 2));
    LFrame1 := LTerm.BeginFrame;
    LFrame2 := LFrame1;
    Inc(LFrame2.FrameId);
    try
      LTerm.EndFrame(LFrame2);
      Fail('end frame rejects stale frame: expected ETuiBackend');
    except
      on E: ETuiBackend do
        Check(Pos('stale frame', E.Message) > 0,
          'end frame rejects stale frame: unexpected message "' + E.Message + '"');
    end;
  finally
    LTerm.Free;
  end;
end;

procedure TestWezTermCapabilityProfileUsesKittyCompatibility;
var
  LProfile: TTuiTerminalCapabilityProfile;
begin
  LProfile := TTerminal.DetectCapabilityProfileFromHints(
    '24bit',
    'WezTerm',
    '',
    '',
    '');

  Check(LProfile.Truecolor.Detected,
    '24bit alias records truecolor support');
  Check(LProfile.Truecolor.Active,
    '24bit alias activates truecolor');
  Check(LProfile.KittyKeyboard.Detected,
    'wezterm counts as kitty-compatible keyboard candidate');
  Check(not LProfile.KittyKeyboard.Active,
    'wezterm kitty keyboard still requires negotiation');
  Check(Pos('negotiation', LProfile.KittyKeyboard.FallbackReason) > 0,
    'wezterm kitty keyboard fallback explains missing negotiation');
  Check(LProfile.ImageProtocol.Status.Detected,
    'wezterm image protocol is detected');
  Check(LProfile.ImageProtocol.Status.Active,
    'wezterm image protocol is active');
  CheckEqual(Ord(ipKitty), Ord(LProfile.ImageProtocol.DetectedProtocol),
    'wezterm detected image protocol is kitty');
  CheckEqual(Ord(ipKitty), Ord(LProfile.ImageProtocol.ActiveProtocol),
    'wezterm active image protocol is kitty');
end;

procedure TestGhosttyCapabilityProfileUsesKittyCompatibility;
var
  LProfile: TTuiTerminalCapabilityProfile;
begin
  LProfile := TTerminal.DetectCapabilityProfileFromHints(
    'truecolor',
    'ghostty',
    '',
    '',
    '');

  Check(LProfile.KittyKeyboard.Detected,
    'ghostty counts as kitty-compatible keyboard candidate');
  Check(not LProfile.KittyKeyboard.Active,
    'ghostty kitty keyboard still requires negotiation');
  Check(Pos('negotiation', LProfile.KittyKeyboard.FallbackReason) > 0,
    'ghostty kitty keyboard fallback explains missing negotiation');
  Check(LProfile.ImageProtocol.Status.Detected,
    'ghostty image protocol is detected');
  Check(LProfile.ImageProtocol.Status.Active,
    'ghostty image protocol is active');
  CheckEqual(Ord(ipKitty), Ord(LProfile.ImageProtocol.DetectedProtocol),
    'ghostty detected image protocol is kitty');
  CheckEqual(Ord(ipKitty), Ord(LProfile.ImageProtocol.ActiveProtocol),
    'ghostty active image protocol is kitty');
end;

procedure TestSixelCapabilityProfileDoesNotImplyKittyKeyboard;
var
  LProfile: TTuiTerminalCapabilityProfile;
begin
  LProfile := TTerminal.DetectCapabilityProfileFromHints(
    '',
    '',
    'foot',
    '',
    '');

  Check(not LProfile.KittyKeyboard.Detected,
    'sixel-only terminal does not imply kitty keyboard support');
  Check(not LProfile.KittyKeyboard.Active,
    'sixel-only terminal keeps kitty keyboard inactive');
  Check(Pos('env-hint-missing', LProfile.KittyKeyboard.FallbackReason) > 0,
    'sixel-only terminal keeps explicit kitty keyboard fallback reason');
  Check(LProfile.ImageProtocol.Status.Detected,
    'sixel-only terminal still detects enhanced image protocol');
  Check(LProfile.ImageProtocol.Status.Active,
    'sixel-only terminal keeps image protocol active');
  CheckEqual(Ord(ipSixel), Ord(LProfile.ImageProtocol.DetectedProtocol),
    'sixel-only terminal detects sixel image protocol');
  CheckEqual(Ord(ipSixel), Ord(LProfile.ImageProtocol.ActiveProtocol),
    'sixel-only terminal activates sixel image protocol');
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.terminal');
  T.Run('parse ascii key', @TestParseAsciiKey);
  T.Run('parse enter', @TestParseEnter);
  T.Run('parse line feed as enter', @TestParseLineFeedAsEnter);
  T.Run('parse tab', @TestParseTab);
  T.Run('parse backspace', @TestParseBackspace);
  T.Run('parse ctrl-h backspace alias', @TestParseCtrlHBackspaceAlias);
  T.Run('parse esc', @TestParseEsc);
  T.Run('parse esc esc preserves both escapes', @TestParseEscEscPreservesBothEscapes);
  T.Run('parse alt ascii', @TestParseAltAscii);
  T.Run('parse alt enter', @TestParseAltEnter);
  T.Run('parse alt tab', @TestParseAltTab);
  T.Run('parse alt backspace', @TestParseAltBackspace);
  T.Run('parse alt ctrl-space', @TestParseAltCtrlSpace);
  T.Run('parse arrow up', @TestParseArrowUp);
  T.Run('parse arrow down', @TestParseArrowDown);
  T.Run('parse arrow right', @TestParseArrowRight);
  T.Run('parse arrow left', @TestParseArrowLeft);
  T.Run('parse csi arrow with ctrl modifier', @TestParseCSIArrowWithCtrlModifier);
  T.Run('parse csi pagedown with shift alt', @TestParseCSIPageDownWithShiftAlt);
  T.Run('parse csi home with shift', @TestParseCSIHomeWithShift);
  T.Run('parse csi home plain', @TestParseCSIHomePlain);
  T.Run('parse csi home legacy tilde', @TestParseCSIHomeLegacyTilde);
  T.Run('parse csi home legacy 7 tilde', @TestParseCSIHomeLegacy7Tilde);
  T.Run('parse csi end with ctrl', @TestParseCSIEndWithCtrl);
  T.Run('parse csi end plain', @TestParseCSIEndPlain);
  T.Run('parse csi end legacy tilde', @TestParseCSIEndLegacyTilde);
  T.Run('parse csi end legacy 8 tilde', @TestParseCSIEndLegacy8Tilde);
  T.Run('parse csi f1 legacy tilde', @TestParseCSIF1LegacyTilde);
  T.Run('parse csi f4 legacy tilde', @TestParseCSIF4LegacyTilde);
  T.Run('parse csi f5 with shift ctrl', @TestParseCSIF5WithShiftCtrl);
  T.Run('parse csi f6 legacy tilde', @TestParseCSIF6LegacyTilde);
  T.Run('parse csi f9 legacy tilde', @TestParseCSIF9LegacyTilde);
  T.Run('parse csi f12 with alt', @TestParseCSIF12WithAlt);
  T.Run('parse csi f11 legacy tilde', @TestParseCSIF11LegacyTilde);
  T.Run('parse csi insert', @TestParseCSIInsert);
  T.Run('parse csi delete with ctrl', @TestParseCSIDeleteWithCtrl);
  T.Run('parse csi pageup with shift', @TestParseCSIPageUpWithShift);
  T.Run('parse csi f10 with alt ctrl', @TestParseCSIF10WithAltCtrl);
  T.Run('parse bracketed paste start', @TestParseBracketedPasteStart);
  T.Run('parse ss3 legacy f1', @TestParseSS3LegacyF1);
  T.Run('parse ss3 legacy f2', @TestParseSS3LegacyF2);
  T.Run('parse ss3 legacy f3', @TestParseSS3LegacyF3);
  T.Run('parse ss3 legacy f4', @TestParseSS3LegacyF4);
  T.Run('parse ss3 legacy end', @TestParseSS3LegacyEnd);
  T.Run('parse ss3 legacy home', @TestParseSS3LegacyHome);
  T.Run('parse sgr mouse down', @TestParseSgrMouseDown);
  T.Run('parse sgr mouse middle down', @TestParseSgrMouseMiddleDown);
  T.Run('parse sgr mouse right down', @TestParseSgrMouseRightDown);
  T.Run('parse sgr mouse release', @TestParseSgrMouseRelease);
  T.Run('parse sgr mouse middle release', @TestParseSgrMouseMiddleRelease);
  T.Run('parse sgr mouse right release', @TestParseSgrMouseRightRelease);
  T.Run('parse sgr mouse move', @TestParseSgrMouseMove);
  T.Run('parse sgr mouse middle drag', @TestParseSgrMouseMiddleDrag);
  T.Run('parse sgr mouse right drag', @TestParseSgrMouseRightDrag);
  T.Run('parse sgr mouse drag with modifiers', @TestParseSgrMouseDragWithModifiers);
  T.Run('parse sgr mouse scroll up', @TestParseSgrMouseScrollUp);
  T.Run('parse sgr mouse scroll down with ctrl', @TestParseSgrMouseScrollDownWithCtrl);
  T.Run('parse ctrl-a', @TestParseCtrlA);
  T.Run('parse ctrl-g', @TestParseCtrlG);
  T.Run('parse ctrl-c', @TestParseCtrlC);
  T.Run('parse ctrl-k', @TestParseCtrlK);
  T.Run('parse ctrl-n', @TestParseCtrlN);
  T.Run('parse ctrl-z', @TestParseCtrlZ);
  T.Run('parse ctrl-space', @TestParseCtrlSpace);
  T.Run('parse ctrl punctuation', @TestParseCtrlPunctuation);
  T.Run('parse utf8', @TestParseUTF8);
  T.Run('parse alt utf8', @TestParseAltUTF8);
  T.Run('invalid bytes recover following utf8',
    @TestInvalidBytesRecoverFollowingUTF8);
  T.Run('invalid byte between events is skipped',
    @TestInvalidByteBetweenEventsIsSkipped);
  T.Run('lone esc waits for more before eof', @TestLoneEscWaitsForMoreBeforeEOF);
  T.Run('incomplete csi waits for more', @TestIncompleteCSIWaitsForMore);
  T.Run('incomplete ss3 waits for more', @TestIncompleteSS3WaitsForMore);
  T.Run('incomplete utf8 waits for more', @TestIncompleteUTF8WaitsForMore);
  T.Run('incomplete alt utf8 waits for more', @TestIncompleteAltUTF8WaitsForMore);
  T.Run('incomplete kitty keyboard waits for more',
    @TestIncompleteKittyKeyboardWaitsForMore);
  T.Run('incomplete sgr mouse waits for more',
    @TestIncompleteSgrMouseWaitsForMore);
  T.Run('incomplete kitty keyboard prefix preserves esc',
    @TestIncompleteKittyKeyboardPrefixPreservesEsc);
  T.Run('incomplete sgr mouse prefix preserves esc',
    @TestIncompleteSgrMousePrefixPreservesEsc);
  T.Run('incomplete csi prefix preserves esc', @TestIncompleteCSIPrefixPreservesEsc);
  T.Run('incomplete ss3 prefix preserves esc', @TestIncompleteSS3PrefixPreservesEsc);
  T.Run('incomplete alt utf8 prefix preserves esc',
    @TestIncompleteAltUTF8PrefixPreservesEsc);
  T.Run('invalid alt utf8 lead preserves esc',
    @TestInvalidAltUTF8LeadPreservesEsc);
  T.Run('bracketed paste end is swallowed', @TestBracketedPasteEndIsSwallowed);
  T.Run('parse csi backtab', @TestParseCSIBackTab);
  T.Run('kitty keyboard shift-tab normalizes to backtab',
    @TestKittyKeyboardShiftTabNormalizesToBackTab);
  T.Run('kitty keyboard shift-alt-tab normalizes to backtab with alt',
    @TestKittyKeyboardShiftAltTabNormalizesToBackTabWithAlt);
  T.Run('kitty keyboard shift-alt-ctrl-tab normalizes to backtab with alt ctrl',
    @TestKittyKeyboardShiftAltCtrlTabNormalizesToBackTabWithAltCtrl);
  T.Run('kitty keyboard alt-tab preserves modifier',
    @TestKittyKeyboardAltTabPreservesModifier);
  T.Run('kitty keyboard shift-enter preserves modifier',
    @TestKittyKeyboardShiftEnterPreservesModifier);
  T.Run('kitty keyboard ctrl-esc preserves modifier',
    @TestKittyKeyboardCtrlEscPreservesModifier);
  T.Run('kitty keyboard alt-backspace preserves modifier',
    @TestKittyKeyboardAltBackspacePreservesModifier);
  T.Run('kitty keyboard alt-codepoint preserves modifier',
    @TestKittyKeyboardAltCodepointPreservesModifier);
  T.Run('capture auto release', @TestCaptureAutoRelease);
  T.Run('request quit', @TestRequestQuit);
  T.Run('terminal options default matches editor default',
    @TestTerminalOptionsDefaultMatchesEditorDefault);
  T.Run('terminal options native selection suppresses tracking',
    @TestTerminalOptionsNativeSelectionWheelSuppressesMouseTracking);
  T.Run('terminal options application selection preserves mouse mode',
    @TestTerminalOptionsApplicationSelectionPreservesConfiguredMouseMode);
  T.Run('capability profile separates detected and active states',
    @TestCapabilityProfileSeparatesDetectedAndActiveStates);
  T.Run('capability profile falls back conservatively',
    @TestCapabilityProfileFallsBackConservatively);
  T.Run('kitty keyboard candidate uses kitty terminal hints',
    @TestKittyKeyboardCandidateUsesKittyTerminalHints);
  T.Run('begin frame requires active tui mode',
    @TestBeginFrameRequiresActiveTuiMode);
  T.Run('end frame requires active begin frame',
    @TestEndFrameRequiresActiveBeginFrame);
  T.Run('begin frame rejects active frame',
    @TestBeginFrameRejectsActiveFrame);
  T.Run('end frame rejects stale frame',
    @TestEndFrameRejectsStaleFrame);
  T.Run('wezterm capability profile uses kitty compatibility',
    @TestWezTermCapabilityProfileUsesKittyCompatibility);
  T.Run('ghostty capability profile uses kitty compatibility',
    @TestGhosttyCapabilityProfileUsesKittyCompatibility);
  T.Run('sixel capability profile does not imply kitty keyboard',
    @TestSixelCapabilityProfileDoesNotImplyKittyKeyboard);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
