program test_tui_input_wine;
{ Wine runtime smoke for ParseOne — pure byte parsing, no TTY.
  truth=wine-runtime-smoke; not real Windows console evidence. }

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.event,
  nextpas.core.tui.input,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestAscii;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := 'a';
  LResult := ParseOne(LBuf[1], Length(LBuf), True, LEvent, LConsumed);
  Check(LResult = prSuccess, 'ascii');
  Check(LEvent.Key.Code = kcChar, 'char');
  Check(LEvent.Key.Ch = Ord('a'), 'a');
end;

procedure TestCsiUp;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #27'[A';
  LResult := ParseOne(LBuf[1], Length(LBuf), True, LEvent, LConsumed);
  Check(LResult = prSuccess, 'csi');
  Check(LEvent.Key.Code = kcUp, 'up');
end;

procedure TestEnter;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
begin
  LBuf := #13;
  Check(ParseOne(LBuf[1], 1, True, LEvent, LConsumed) = prSuccess, 'enter');
  Check(LEvent.Key.Code = kcEnter, 'kcEnter');
end;

procedure TestUtf8Cjk;
var
  LBuf: array[0..2] of Byte;
  LEvent: TEvent;
  LConsumed: Integer;
begin
  LBuf[0] := $E4;
  LBuf[1] := $B8;
  LBuf[2] := $AD;
  Check(ParseOne(LBuf[0], 3, True, LEvent, LConsumed) = prSuccess, 'utf8');
  Check(LEvent.Key.Ch = $4E2D, 'U+4E2D');
end;

procedure TestKittyFlagsReply;
var
  LFlags, LConsumed: Integer;
  LBuf: AnsiString;
begin
  LBuf := #27'[?5u';
  Check(TryParseKittyKeyboardFlagsReply(LBuf[1], Length(LBuf), True, LFlags, LConsumed)
    = prSuccess, 'flags reply');
  CheckEqual(5, LFlags, 'flags=5');
end;

procedure TestInvalidThenAscii;
var
  LBuf: array[0..1] of Byte;
  LEvent: TEvent;
  LConsumed, LPos: Integer;
  LResult: TParseResult;
begin
  LBuf[0] := $FF;
  LBuf[1] := Ord('z');
  LPos := 0;
  LResult := ParseOne(LBuf[LPos], 2 - LPos, True, LEvent, LConsumed);
  Check(LResult = prInvalid, 'invalid lead');
  if LConsumed > 0 then Inc(LPos, LConsumed) else Inc(LPos);
  LResult := ParseOne(LBuf[LPos], 2 - LPos, True, LEvent, LConsumed);
  Check(LResult = prSuccess, 'recover');
  Check(LEvent.Key.Ch = Ord('z'), 'z');
end;

procedure TestFocusIn;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
begin
  LBuf := #27'[I';
  Check(ParseOne(LBuf[1], Length(LBuf), True, LEvent, LConsumed) = prSuccess, 'focus in');
  Check(LEvent.Kind = evFocus, 'evFocus');
  Check(LEvent.Focus.Kind = fkIn, 'fkIn');
end;

procedure TestFocusOut;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
begin
  LBuf := #27'[O';
  Check(ParseOne(LBuf[1], Length(LBuf), True, LEvent, LConsumed) = prSuccess, 'focus out');
  Check(LEvent.Kind = evFocus, 'evFocus');
  Check(LEvent.Focus.Kind = fkOut, 'fkOut');
end;

procedure TestArrowDown;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
begin
  LBuf := #27'[B';
  Check(ParseOne(LBuf[1], Length(LBuf), True, LEvent, LConsumed) = prSuccess, 'down');
  Check(LEvent.Key.Code = kcDown, 'kcDown');
end;

procedure TestTab;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
begin
  LBuf := #9;
  Check(ParseOne(LBuf[1], 1, True, LEvent, LConsumed) = prSuccess, 'tab');
  Check(LEvent.Key.Code = kcTab, 'kcTab');
end;

begin
  T := TTestSuite.Create('tui_input_wine');
  T.Test('ascii', @TestAscii);
  T.Test('csi up', @TestCsiUp);
  T.Test('enter', @TestEnter);
  T.Test('utf8 cjk', @TestUtf8Cjk);
  T.Test('kitty flags reply', @TestKittyFlagsReply);
  T.Test('invalid then ascii', @TestInvalidThenAscii);
  T.Test('focus in', @TestFocusIn);
  T.Test('focus out', @TestFocusOut);
  T.Test('arrow down', @TestArrowDown);
  T.Test('tab', @TestTab);
  if not T.Run then Halt(1);
end.
