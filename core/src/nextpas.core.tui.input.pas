unit nextpas.core.tui.input;

// Byte stream -> TEvent.  Pure function over a byte buffer; no IO.
//
// Every call to ParseOne tries to consume the prefix of `Buf` and
// produce one TEvent.  Three outcomes:
//
//   prSuccess : Out_ holds an event, Consumed = bytes consumed
//   prNeedMore: input is a prefix of a longer sequence (e.g. ESC
//               with no follow-up yet) — caller must read more
//               bytes and call again
//   prInvalid : input doesn't match any recognised pattern;
//               caller should drop one byte and try again
//
// Supported patterns:
//   - Printable ASCII / control bytes -> kcChar, kcEnter, kcTab,
//     kcBackspace, ctrl-letter combinations
//   - UTF-8 multi-byte -> kcChar with full UCS-4 codepoint
//   - ESC alone (with AtEOF hint) -> kcEsc
//   - ESC <ch> -> Alt + kcChar(ch) or Alt + kcEnter etc.
//   - CSI A/B/C/D -> arrows; CSI H/F -> Home/End
//   - CSI 1~..6~ -> Home/Insert/Delete/End/PageUp/PageDown
//   - CSI 11~..24~ -> F1..F12; CSI Z -> BackTab
//   - CSI 1;<mods> letter -> arrows/Home/End with modifiers
//   - CSI <keycode>;<mods>u -> kitty keyboard protocol (Shift+Enter etc)
//   - SS3 P/Q/R/S -> F1..F4 (legacy)
//   - SGR mouse (CSI < b;x;y M/m) -> mkDown/mkUp/mkMoved/mkDrag/mkScrollUp/mkScrollDown
//     with button (left/middle/right/none) and modifiers

{$I nextpas.core.settings.inc}



interface

uses
  nextpas.core.tui.event,
  nextpas.core.text.utf8;

type
  TParseResult = (prSuccess, prNeedMore, prInvalid);

// Parse one event from Buf[0..Len-1].
// AtEOF tells the parser that no more bytes will arrive; this
// changes the bare-ESC handling — without AtEOF a lone ESC is
// prNeedMore (it might be the start of a CSI), with AtEOF it
// resolves to kcEsc.
function ParseOne(const Buf; Len: Integer; AtEOF: Boolean;
  out Out_: TEvent; out Consumed: Integer): TParseResult;

implementation

// Read byte at index I from Buf (treated as PByte).
function ByteAt(const Buf; I: Integer): Byte; inline;
begin
  Result := PByte(@Buf)[I];
end;

// Parse a decimal number starting at Pos within Buf[0..Len-1].
// Returns the parsed value via Value, advances Pos past the digits.
// Returns False if no digit at the position.
function ParseDecimal(const Buf; Len: Integer; var Pos: Integer;
  out Value: Integer): Boolean;
var
  B: Byte;
begin
  Result := False;
  Value := 0;
  while Pos < Len do
  begin
    B := ByteAt(Buf, Pos);
    if (B < Ord('0')) or (B > Ord('9')) then Break;
    if Value > 100000 then
    begin
      Inc(Pos);
      Continue;
    end;
    Value := Value * 10 + Integer(B - Ord('0'));
    Inc(Pos);
    Result := True;
  end;
end;

// xterm-style modifier byte:
//   1 = none
//   2 = shift
//   3 = alt
//   4 = shift+alt
//   5 = ctrl
//   6 = shift+ctrl
//   7 = alt+ctrl
//   8 = shift+alt+ctrl
function ModsFromByte(M: Integer): TKeyModifiers;
begin
  Result := [];
  if M < 2 then Exit;
  Dec(M);
  if (M and 1) <> 0 then Include(Result, kmShift);
  if (M and 2) <> 0 then Include(Result, kmAlt);
  if (M and 4) <> 0 then Include(Result, kmCtrl);
end;

function IncompleteStatus(AtEOF: Boolean): TParseResult; inline;
begin
  if AtEOF then
    Result := prInvalid
  else
    Result := prNeedMore;
end;

function MissingOrInvalid(Pos, Len: Integer; AtEOF: Boolean): TParseResult; inline;
begin
  if Pos >= Len then
    Result := IncompleteStatus(AtEOF)
  else
    Result := prInvalid;
end;

// Parse a CSI body starting after `ESC [`.  Buf[0..Len-1] is the
// whole input including the leading ESC; Body starts at index 2.
// Returns prSuccess + number of bytes consumed (including ESC[ and
// the final letter), prNeedMore if the body is not yet complete,
// or prInvalid for unrecognised forms.
function ParseCSI(const Buf; Len: Integer; AtEOF: Boolean;
  out Out_: TEvent; out Consumed: Integer): TParseResult;
var
  Pos: Integer;
  Param1, Param2, Param3, B: Integer;
  HaveP1, HaveP2: Boolean;
  Mods: TKeyModifiers;
  Final: Byte;
  IsRelease: Boolean;
  MouseX, MouseY: Word;
begin
  Out_ := NoneEvent;
  Consumed := 0;
  Pos := 2;     // skip ESC [

  // Detect SGR mouse: ESC [ < ...
  if (Pos < Len) and (ByteAt(Buf, Pos) = Ord('<')) then
  begin
    Inc(Pos);
    if not ParseDecimal(Buf, Len, Pos, Param1) then
      Exit(MissingOrInvalid(Pos, Len, AtEOF));
    if (Pos >= Len) or (ByteAt(Buf, Pos) <> Ord(';')) then
      Exit(MissingOrInvalid(Pos, Len, AtEOF));
    Inc(Pos);
    if not ParseDecimal(Buf, Len, Pos, Param2) then
      Exit(MissingOrInvalid(Pos, Len, AtEOF));
    if (Pos >= Len) or (ByteAt(Buf, Pos) <> Ord(';')) then
      Exit(MissingOrInvalid(Pos, Len, AtEOF));
    Inc(Pos);
    if not ParseDecimal(Buf, Len, Pos, Param3) then
      Exit(MissingOrInvalid(Pos, Len, AtEOF));
    if Pos >= Len then Exit(IncompleteStatus(AtEOF));
    Final := ByteAt(Buf, Pos);
    if (Final <> Ord('M')) and (Final <> Ord('m')) then Exit(prInvalid);
    Inc(Pos);
    IsRelease := Final = Ord('m');
    Consumed := Pos;
    // SGR wire coordinates are 1-based; fafafa.tui events are 0-based Word.
    if (Param2 < 1) or (Param3 < 1) or
       (Param2 > 65536) or (Param3 > 65536) then
      Exit(prInvalid);
    MouseX := Word(Param2 - 1);
    MouseY := Word(Param3 - 1);
    // SGR mouse button encoding:
    //   bits 0-1: button (0=left, 1=middle, 2=right, 3=release/none)
    //   bit 2 (4): shift
    //   bit 3 (8): alt/meta
    //   bit 4 (16): ctrl
    //   bit 5 (32): motion (drag or move)
    //   bits 6-7 (64,128): 64=scroll up, 65=scroll down
    Mods := [];
    if (Param1 and 4)  <> 0 then Include(Mods, kmShift);
    if (Param1 and 8)  <> 0 then Include(Mods, kmAlt);
    if (Param1 and 16) <> 0 then Include(Mods, kmCtrl);

    B := Param1 and 3;       // button bits
    if (Param1 and 64) <> 0 then
    begin
      // Scroll events.
      if B = 0 then
        Out_ := MouseEvent(mkScrollUp, mbNone, MouseX, MouseY, Mods)
      else
        Out_ := MouseEvent(mkScrollDown, mbNone, MouseX, MouseY, Mods);
    end
    else if (Param1 and 32) <> 0 then
    begin
      // Motion event (bit 5 set).
      // If button bits = 3, it's a pure move (no button held).
      // Otherwise it's a drag with that button held.
      if B = 3 then
        Out_ := MouseEvent(mkMoved, mbNone, MouseX, MouseY, Mods)
      else
      begin
        case B of
          0: Out_ := MouseEvent(mkDrag, mbLeft,   MouseX, MouseY, Mods);
          1: Out_ := MouseEvent(mkDrag, mbMiddle, MouseX, MouseY, Mods);
          2: Out_ := MouseEvent(mkDrag, mbRight,  MouseX, MouseY, Mods);
        else
          Out_ := MouseEvent(mkDrag, mbLeft, MouseX, MouseY, Mods);
        end;
      end;
    end
    else if IsRelease then
    begin
      // Button release.
      case B of
        0: Out_ := MouseEvent(mkUp, mbLeft,   MouseX, MouseY, Mods);
        1: Out_ := MouseEvent(mkUp, mbMiddle, MouseX, MouseY, Mods);
        2: Out_ := MouseEvent(mkUp, mbRight,  MouseX, MouseY, Mods);
      else
        Out_ := MouseEvent(mkUp, mbLeft, MouseX, MouseY, Mods);
      end;
    end
    else
    begin
      // Button press.
      case B of
        0: Out_ := MouseEvent(mkDown, mbLeft,   MouseX, MouseY, Mods);
        1: Out_ := MouseEvent(mkDown, mbMiddle, MouseX, MouseY, Mods);
        2: Out_ := MouseEvent(mkDown, mbRight,  MouseX, MouseY, Mods);
      else
        Out_ := MouseEvent(mkDown, mbLeft, MouseX, MouseY, Mods);
      end;
    end;
    Result := prSuccess;
    Exit;
  end;

  // CSI Z = BackTab (Shift-Tab) — special, no parameters.
  if (Pos < Len) and (ByteAt(Buf, Pos) = Ord('Z')) then
  begin
    Out_ := KeyCodeEvent(kcBackTab, []);
    Consumed := Pos + 1;
    Exit(prSuccess);
  end;

  // Parse `Param1[;Param2]` then a final letter.  Param1 defaults
  // to 1 when missing (matches xterm behaviour).
  HaveP1 := ParseDecimal(Buf, Len, Pos, Param1);
  if not HaveP1 then Param1 := 1;

  HaveP2 := False;
  Param2 := 1;
  if (Pos < Len) and (ByteAt(Buf, Pos) = Ord(';')) then
  begin
    Inc(Pos);
    HaveP2 := ParseDecimal(Buf, Len, Pos, Param2);
    if not HaveP2 then Exit(MissingOrInvalid(Pos, Len, AtEOF));
  end;

  if Pos >= Len then Exit(IncompleteStatus(AtEOF));
  Final := ByteAt(Buf, Pos);
  Inc(Pos);
  Consumed := Pos;
  Mods := ModsFromByte(Param2);

  case Final of
    Ord('A'): Out_ := KeyCodeEvent(kcUp,    Mods);
    Ord('B'): Out_ := KeyCodeEvent(kcDown,  Mods);
    Ord('C'): Out_ := KeyCodeEvent(kcRight, Mods);
    Ord('D'): Out_ := KeyCodeEvent(kcLeft,  Mods);
    Ord('H'): Out_ := KeyCodeEvent(kcHome,  Mods);
    Ord('F'): Out_ := KeyCodeEvent(kcEnd,   Mods);
    Ord('~'):
      case Param1 of
        1, 7: Out_ := KeyCodeEvent(kcHome, Mods);
        2:    Out_ := KeyCodeEvent(kcInsert, Mods);
        3:    Out_ := KeyCodeEvent(kcDelete, Mods);
        4, 8: Out_ := KeyCodeEvent(kcEnd, Mods);
        5:    Out_ := KeyCodeEvent(kcPageUp, Mods);
        6:    Out_ := KeyCodeEvent(kcPageDown, Mods);
        11..15:
          begin
            B := Param1 - 10;        // 11..15 -> F1..F5
            Out_ := KeyFunctionEvent(B, Mods);
          end;
        17..21:
          begin
            B := Param1 - 11;        // 17..21 -> F6..F10
            Out_ := KeyFunctionEvent(B, Mods);
          end;
        23, 24:
          begin
            B := Param1 - 12;        // 23,24 -> F11,F12
            Out_ := KeyFunctionEvent(B, Mods);
          end;
      else
        Exit(prInvalid);
      end;
    Ord('u'):
      // CSI u (kitty keyboard protocol): ESC [ <keycode> ; <mods> u
      // Param1 = Unicode codepoint or special key code.
      case Param1 of
        13: Out_ := KeyCodeEvent(kcEnter, Mods);     // Enter
        9:  Out_ := KeyCodeEvent(kcTab, Mods);       // Tab
        27: Out_ := KeyCodeEvent(kcEsc, Mods);       // Esc
        127: Out_ := KeyCodeEvent(kcBackspace, Mods);// Backspace
      else
        // Generic codepoint with modifiers.
        if Param1 >= 32 then
          Out_ := KeyCharEvent(LongWord(Param1), Mods)
        else
          Exit(prInvalid);
      end;
  else
    Exit(prInvalid);
  end;

  Result := prSuccess;
end;

// Parse SS3 sequence: ESC O <letter> -> F1..F4 legacy.
function ParseSS3(const Buf; Len: Integer; AtEOF: Boolean;
  out Out_: TEvent; out Consumed: Integer): TParseResult;
var
  B: Byte;
begin
  Out_ := NoneEvent;
  Consumed := 0;
  if Len < 3 then Exit(IncompleteStatus(AtEOF));
  B := ByteAt(Buf, 2);
  case B of
    Ord('P'): Out_ := KeyFunctionEvent(1, []);
    Ord('Q'): Out_ := KeyFunctionEvent(2, []);
    Ord('R'): Out_ := KeyFunctionEvent(3, []);
    Ord('S'): Out_ := KeyFunctionEvent(4, []);
    Ord('H'): Out_ := KeyCodeEvent(kcHome, []);
    Ord('F'): Out_ := KeyCodeEvent(kcEnd, []);
  else
    Exit(prInvalid);
  end;
  Consumed := 3;
  Result := prSuccess;
end;

// Translate a single byte read directly (not part of an escape) into
// an event.  Returns prInvalid if the byte doesn't map to anything
// — caller drops it.
function ParseSingleByte(B: Byte; out Out_: TEvent): TParseResult;
begin
  Out_ := NoneEvent;
  case B of
    9:        Out_ := KeyCodeEvent(kcTab, []);
    10, 13:   Out_ := KeyCodeEvent(kcEnter, []);
    127, 8:   Out_ := KeyCodeEvent(kcBackspace, []);
    32..126:
      Out_ := KeyCharEvent(B, []);
    1..7, 11..12, 14..26, 28..31:
      // Ctrl-A..G/K..L/N..Z/\..^/_  — Ctrl + lowercase letter.
      // Ctrl-A is byte 1, Ctrl-Z is 26.  Ctrl-Space is 0 (NUL) but
      // we don't surface that.
      Out_ := KeyCharEvent(LongWord(B + Ord('a') - 1), [kmCtrl]);
  else
    Exit(prInvalid);
  end;
  Result := prSuccess;
end;

function ParseOne(const Buf; Len: Integer; AtEOF: Boolean;
  out Out_: TEvent; out Consumed: Integer): TParseResult;
var
  B0, B1: Byte;
  R: TParseResult;
  LDec: TUTF8DecodeResult;
  Need: Integer;
begin
  Out_ := NoneEvent;
  Consumed := 0;
  if Len <= 0 then Exit(prNeedMore);

  B0 := ByteAt(Buf, 0);
  if B0 <> 27 then
  begin
    // ASCII range: single-byte dispatch.
    if B0 < $80 then
    begin
      Consumed := 1;
      Exit(ParseSingleByte(B0, Out_));
    end;
    // UTF-8 multi-byte: decode the codepoint and emit as kcChar.
    // If the sequence is truncated (not enough bytes), report NeedMore
    // so the caller reads more before retrying.
    LDec := UTF8Decode(PByte(@Buf), Len);
    if LDec.ByteLen = 0 then
    begin
      // Could be truncated UTF-8 or genuinely invalid.
      if      (B0 and $E0) = $C0 then Need := 2
      else if (B0 and $F0) = $E0 then Need := 3
      else if (B0 and $F8) = $F0 then Need := 4
      else Need := 1;
      if Need > Len then Exit(IncompleteStatus(AtEOF));
      Consumed := 1;
      Exit(prInvalid);
    end;
    Out_ := KeyCharEvent(LDec.CodePoint, []);
    Consumed := LDec.ByteLen;
    Exit(prSuccess);
  end;

  // ESC sequences.
  if Len = 1 then
  begin
    if AtEOF then
    begin
      Out_ := KeyCodeEvent(kcEsc, []);
      Consumed := 1;
      Exit(prSuccess);
    end;
    Exit(prNeedMore);
  end;

  B1 := ByteAt(Buf, 1);
  case B1 of
    Ord('['):
      Exit(ParseCSI(Buf, Len, AtEOF, Out_, Consumed));
    Ord('O'):
      Exit(ParseSS3(Buf, Len, AtEOF, Out_, Consumed));
    27:
      begin
        // ESC ESC -> bare ESC + reparse remainder on next call.
        Out_ := KeyCodeEvent(kcEsc, []);
        Consumed := 1;
        Exit(prSuccess);
      end;
  else
    // ESC <byte> -> Alt-modified version of <byte>.
    R := ParseSingleByte(B1, Out_);
    if R = prSuccess then
    begin
      // Add Alt to the modifier set.
      if Out_.Kind = evKey then
        Include(Out_.Key.Modifiers, kmAlt);
      Consumed := 2;
      Exit(prSuccess);
    end;
    Exit(prInvalid);
  end;
end;

end.
