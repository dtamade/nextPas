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

begin
  T := TTestSuite.Create('tui_input');
  T.Test('ParseOne printable ASCII', @TestParseOnePrintableAscii);
  T.Test('ParseOne digit', @TestParseOneDigit);
  T.Test('ParseOne Enter', @TestParseOneEnter);
  T.Test('ParseOne LF', @TestParseOneLF);
  T.Test('ParseOne Tab', @TestParseOneTab);
  T.Test('ParseOne Backspace', @TestParseOneBackspace);
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
  if not T.Run then Halt(1);
end.
