program test_tui_input;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.event,
  nextpas.core.tui.input,
  nextpas.core.test;

var
  T: TTestSuite;

procedure TestParseOnePrintableAscii;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := 'a';
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'Should parse printable ASCII');
  Check(LEvent.Kind = evKey, 'Should be key event');
  Check(LEvent.Key.Code = kcChar, 'Should be kcChar');
  Check(LEvent.Key.Ch = Ord('a'), 'Char should be a');
  Check(LConsumed = 1, 'Should consume 1 byte');
end;

procedure TestParseOneDigit;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := '5';
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'Should parse digit');
  Check(LEvent.Key.Ch = Ord('5'), 'Char should be 5');
end;

procedure TestParseOneEnter;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #13;
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'Should parse Enter');
  Check(LEvent.Key.Code = kcEnter, 'Should be kcEnter');
end;

procedure TestParseOneLF;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #10;
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'Should parse LF');
  Check(LEvent.Key.Code = kcEnter, 'LF should be kcEnter');
end;

procedure TestParseOneTab;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #9;
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'Should parse Tab');
  Check(LEvent.Key.Code = kcTab, 'Should be kcTab');
end;

procedure TestParseOneBackspace;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #127;
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'Should parse Backspace');
  Check(LEvent.Key.Code = kcBackspace, 'Should be kcBackspace');
end;

procedure TestParseOneCtrlBackspaceByte;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  { ^H（0x08）= Ctrl+Backspace——现代终端（xterm 等）Backspace 键发
    0x7f(DEL)、Ctrl+Backspace 发 0x08；并入 [] 会让词删除不可达 }
  LBuf := #8;
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'Ctrl+Backspace byte parses');
  Check(LEvent.Key.Code = kcBackspace, 'Ctrl+Backspace is kcBackspace');
  Check(kmCtrl in LEvent.Key.Modifiers, 'Ctrl+Backspace keeps ctrl mod');
  Check(not (kmCtrl in LEvent.Key.Modifiers) = False, 'sanity');
end;

procedure TestParseOneCtrlA;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #1;
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'Should parse Ctrl+A');
  Check(LEvent.Key.Code = kcChar, 'Should be kcChar');
  Check(LEvent.Key.Ch = Ord('a'), 'Char should be a');
  Check(kmCtrl in LEvent.Key.Modifiers, 'Should have Ctrl modifier');
end;

procedure TestParseOneEscAtEOF;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #27;
  LResult := ParseOne(LBuf[1], Length(LBuf), True, LEvent, LConsumed);
  Check(LResult = prSuccess, 'Should parse Esc at EOF');
  Check(LEvent.Key.Code = kcEsc, 'Should be kcEsc');
end;

procedure TestParseOneEscNeedMore;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #27;
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prNeedMore, 'Esc without EOF should need more');
end;

procedure TestParseOneArrowUp;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #27'[A';
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'Should parse arrow up');
  Check(LEvent.Key.Code = kcUp, 'Should be kcUp');
  Check(LConsumed = 3, 'Should consume 3 bytes');
end;

procedure TestParseOneArrowDown;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #27'[B';
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'Should parse arrow down');
  Check(LEvent.Key.Code = kcDown, 'Should be kcDown');
end;

procedure TestParseOneArrowRight;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #27'[C';
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'Should parse arrow right');
  Check(LEvent.Key.Code = kcRight, 'Should be kcRight');
end;

procedure TestParseOneArrowLeft;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #27'[D';
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'Should parse arrow left');
  Check(LEvent.Key.Code = kcLeft, 'Should be kcLeft');
end;

procedure TestParseOneHome;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #27'[H';
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'Should parse Home');
  Check(LEvent.Key.Code = kcHome, 'Should be kcHome');
end;

procedure TestParseOneEnd;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #27'[F';
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'Should parse End');
  Check(LEvent.Key.Code = kcEnd, 'Should be kcEnd');
end;

procedure TestParseOneEmpty;
var
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LResult := ParseOne(LEvent, 0, False, LEvent, LConsumed);
  Check(LResult = prNeedMore, 'Empty buffer should need more');
end;

procedure TestParseOneDelete;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #27'[3~';
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'Should parse Delete');
  Check(LEvent.Key.Code = kcDelete, 'Should be kcDelete');
end;

procedure TestParseOnePageUp;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #27'[5~';
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'Should parse PageUp');
  Check(LEvent.Key.Code = kcPageUp, 'Should be kcPageUp');
end;

procedure TestParseOnePageDown;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #27'[6~';
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'Should parse PageDown');
  Check(LEvent.Key.Code = kcPageDown, 'Should be kcPageDown');
end;

procedure TestParseOneInsert;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #27'[2~';
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'Should parse Insert');
  Check(LEvent.Key.Code = kcInsert, 'Should be kcInsert');
end;

procedure TestParseOneEscKey;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  // Esc alone (at EOF) should produce kcEsc
  LBuf := #27;
  LResult := ParseOne(LBuf[1], Length(LBuf), True, LEvent, LConsumed);
  Check(LResult = prSuccess, 'Esc at EOF should succeed');
  Check(LEvent.Key.Code = kcEsc, 'Should be kcEsc');
end;

procedure TestParseOneCtrlC;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #3; // Ctrl+C
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'Should parse Ctrl+C');
  Check(LEvent.Key.Code = kcChar, 'Ctrl+C should be kcChar');
  Check(LEvent.Key.Ch = Ord('c'), 'Char should be c');
  Check(kmCtrl in LEvent.Key.Modifiers, 'Should have Ctrl modifier');
end;

{ Wave Q1: recovery / corpus — pure ParseOne stream semantics }

procedure AdvanceOrDrop(var Pos: Integer; AConsumed: Integer);
begin
  if AConsumed > 0 then
    Inc(Pos, AConsumed)
  else
    Inc(Pos); { prInvalid with Consumed=0: drop one byte }
end;

procedure TestInvalidByteThenAsciiRecovers;
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
  Check(LResult = prInvalid, 'lone 0xFF is invalid UTF-8 lead');
  AdvanceOrDrop(LPos, LConsumed);
  LResult := ParseOne(LBuf[LPos], 2 - LPos, True, LEvent, LConsumed);
  Check(LResult = prSuccess, 'following ASCII still parses');
  Check(LEvent.Key.Code = kcChar, 'recovered event is char');
  Check(LEvent.Key.Ch = Ord('z'), 'recovered char is z');
end;

procedure TestIncompleteCsiNeedsMoreThenCompletes;
var
  LBuf: array[0..2] of Byte;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf[0] := 27;
  LBuf[1] := Ord('[');
  LBuf[2] := Ord('A');
  LResult := ParseOne(LBuf[0], 2, False, LEvent, LConsumed);
  Check(LResult = prNeedMore, 'ESC[ without final needs more');
  LResult := ParseOne(LBuf[0], 3, False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'full CSI up succeeds');
  Check(LEvent.Key.Code = kcUp, 'CSI A is up');
  Check(LConsumed = 3, 'consumes 3');
end;

procedure TestOverlongCsiParamsNoCrash;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
  I: Integer;
begin
  { ESC [ + many digits + ; + digits + A — must not hang/crash }
  LBuf := #27'[';
  for I := 1 to 80 do
    LBuf := LBuf + '9';
  LBuf := LBuf + ';';
  for I := 1 to 40 do
    LBuf := LBuf + '1';
  LBuf := LBuf + 'A';
  LResult := ParseOne(LBuf[1], Length(LBuf), True, LEvent, LConsumed);
  Check((LResult = prSuccess) or (LResult = prInvalid),
    'overlong CSI resolves without hang');
  Check(LConsumed >= 0, 'consumed non-negative');
end;

procedure TestParseOneUtf8Cjk;
var
  LBuf: array[0..2] of Byte;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  { U+4E2D 中 = E4 B8 AD }
  LBuf[0] := $E4;
  LBuf[1] := $B8;
  LBuf[2] := $AD;
  LResult := ParseOne(LBuf[0], 3, True, LEvent, LConsumed);
  Check(LResult = prSuccess, 'UTF-8 CJK parses');
  Check(LEvent.Key.Code = kcChar, 'CJK is kcChar');
  Check(LEvent.Key.Ch = $4E2D, 'codepoint U+4E2D');
  Check(LConsumed = 3, 'consumes 3 bytes');
end;

procedure TestIncompleteUtf8NeedsMore;
var
  LBuf: array[0..0] of Byte;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf[0] := $E4; { lead of 3-byte sequence }
  LResult := ParseOne(LBuf[0], 1, False, LEvent, LConsumed);
  Check(LResult = prNeedMore, 'truncated UTF-8 needs more when not EOF');
end;

procedure TestKittyCsiUShiftEnter;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #27'[13;2u'; { Enter + shift }
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'Kitty CSI u Shift+Enter');
  Check(LEvent.Key.Code = kcEnter, 'keycode enter');
  Check(kmShift in LEvent.Key.Modifiers, 'shift modifier');
  Check(LConsumed = Length(LBuf), 'consumes full sequence');
end;

procedure TestKittyInterleavedWithClassicCsi;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed, LPos: Integer;
  LResult: TParseResult;
  LGotUp, LGotKitty: Boolean;
begin
  { classic up then Kitty Shift+Enter then 'x' }
  LBuf := #27'[A' + #27'[13;2u' + 'x';
  LPos := 1;
  LGotUp := False;
  LGotKitty := False;
  while LPos <= Length(LBuf) do
  begin
    LResult := ParseOne(LBuf[LPos], Length(LBuf) - LPos + 1, True, LEvent, LConsumed);
    if LResult = prSuccess then
    begin
      if LEvent.Key.Code = kcUp then
        LGotUp := True
      else if (LEvent.Key.Code = kcEnter) and (kmShift in LEvent.Key.Modifiers) then
        LGotKitty := True
      else if (LEvent.Key.Code = kcChar) and (LEvent.Key.Ch = Ord('x')) then
        ; { ok }
      if LConsumed <= 0 then
        Inc(LPos)
      else
        Inc(LPos, LConsumed);
    end
    else
      AdvanceOrDrop(LPos, LConsumed);
  end;
  Check(LGotUp, 'classic CSI up in mixed stream');
  Check(LGotKitty, 'Kitty CSI u in mixed stream');
end;

procedure TestModifiedArrowShiftUp;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #27'[1;2A';
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'modified CSI arrow');
  Check(LEvent.Key.Code = kcUp, 'up');
  Check(kmShift in LEvent.Key.Modifiers, 'shift');
end;

procedure TestParseOneBackTab;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #27'[Z';
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'CSI Z');
  Check(LEvent.Key.Code = kcBackTab, 'BackTab');
end;

procedure TestParseOneF1;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #27'[11~';
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'CSI 11~');
  Check(LEvent.Key.Code = kcF, 'F key');
  Check(LEvent.Key.F = 1, 'F1');
end;

procedure TestInvalidCsiAtEofFallsBackToEsc;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  { ESC [ Q  — not a recognised CSI final; AtEOF → bare Esc + drop rest later }
  LBuf := #27'[Q';
  LResult := ParseOne(LBuf[1], Length(LBuf), True, LEvent, LConsumed);
  Check(LResult = prSuccess, 'invalid CSI at EOF yields success path');
  Check(LEvent.Key.Code = kcEsc, 'falls back to Esc');
  Check(LConsumed = 1, 'only consumes Esc byte');
end;

procedure TestSs3F1;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #27'OP';
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'SS3 F1');
  Check(LEvent.Key.Code = kcF, 'legacy F key');
  Check(LEvent.Key.F = 1, 'legacy F1');
  Check(LConsumed = 3, 'consumes 3');
end;


procedure TestParseOneFocusIn;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #27'[I';
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'focus in parses');
  Check(LEvent.Kind = evFocus, 'evFocus');
  Check(LEvent.Focus.Kind = fkIn, 'fkIn');
  Check(LConsumed = 3, 'consumes 3');
end;

procedure TestParseOneFocusOut;
var
  LBuf: AnsiString;
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
begin
  LBuf := #27'[O';
  LResult := ParseOne(LBuf[1], Length(LBuf), False, LEvent, LConsumed);
  Check(LResult = prSuccess, 'focus out parses');
  Check(LEvent.Kind = evFocus, 'evFocus');
  Check(LEvent.Focus.Kind = fkOut, 'fkOut');
end;

procedure TestFocusHelpers;
var
  LIn, LOut: TEvent;
begin
  LIn := FocusEvent(fkIn);
  LOut := FocusEvent(fkOut);
  Check(IsFocus(LIn), 'IsFocus in');
  Check(IsFocusIn(LIn), 'IsFocusIn');
  Check(not IsFocusOut(LIn), 'not out');
  Check(IsFocusOut(LOut), 'IsFocusOut');
  Check(not IsKey(LIn), 'not key');
end;


begin
  T := TTestSuite.Create('tui_input');
  T.Test('ParseOne printable ASCII', @TestParseOnePrintableAscii);
  T.Test('ParseOne digit', @TestParseOneDigit);
  T.Test('ParseOne Enter', @TestParseOneEnter);
  T.Test('ParseOne LF', @TestParseOneLF);
  T.Test('ParseOne Tab', @TestParseOneTab);
  T.Test('ParseOne Backspace', @TestParseOneBackspace);
  T.Test('ParseOne Ctrl+Backspace byte', @TestParseOneCtrlBackspaceByte);
  T.Test('ParseOne Ctrl+A', @TestParseOneCtrlA);
  T.Test('ParseOne Esc at EOF', @TestParseOneEscAtEOF);
  T.Test('ParseOne Esc need more', @TestParseOneEscNeedMore);
  T.Test('ParseOne Arrow Up', @TestParseOneArrowUp);
  T.Test('ParseOne Arrow Down', @TestParseOneArrowDown);
  T.Test('ParseOne Arrow Right', @TestParseOneArrowRight);
  T.Test('ParseOne Arrow Left', @TestParseOneArrowLeft);
  T.Test('ParseOne Home', @TestParseOneHome);
  T.Test('ParseOne End', @TestParseOneEnd);
  T.Test('ParseOne empty buffer', @TestParseOneEmpty);
  T.Test('ParseOne Delete', @TestParseOneDelete);
  T.Test('ParseOne PageUp', @TestParseOnePageUp);
  T.Test('ParseOne PageDown', @TestParseOnePageDown);
  T.Test('ParseOne Insert', @TestParseOneInsert);
  T.Test('ParseOne Esc key', @TestParseOneEscKey);
  T.Test('ParseOne Ctrl+C', @TestParseOneCtrlC);
  T.Test('invalid byte then ASCII recovers', @TestInvalidByteThenAsciiRecovers);
  T.Test('incomplete CSI needs more then completes', @TestIncompleteCsiNeedsMoreThenCompletes);
  T.Test('overlong CSI params no crash', @TestOverlongCsiParamsNoCrash);
  T.Test('ParseOne UTF-8 CJK', @TestParseOneUtf8Cjk);
  T.Test('incomplete UTF-8 needs more', @TestIncompleteUtf8NeedsMore);
  T.Test('Kitty CSI u Shift+Enter', @TestKittyCsiUShiftEnter);
  T.Test('Kitty interleaved with classic CSI', @TestKittyInterleavedWithClassicCsi);
  T.Test('modified arrow Shift+Up', @TestModifiedArrowShiftUp);
  T.Test('ParseOne BackTab', @TestParseOneBackTab);
  T.Test('ParseOne F1', @TestParseOneF1);
  T.Test('invalid CSI at EOF falls back to Esc', @TestInvalidCsiAtEofFallsBackToEsc);
  T.Test('SS3 F1', @TestSs3F1);
    T.Test('ParseOne focus in', @TestParseOneFocusIn);
  T.Test('ParseOne focus out', @TestParseOneFocusOut);
  T.Test('focus helpers', @TestFocusHelpers);
if not T.Run then Halt(1);
end.
