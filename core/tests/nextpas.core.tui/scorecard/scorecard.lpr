program scorecard;
{**
 * tui Scorecard SC1–SC27 (PARITY-GO-RUST Wave Q1–Q15 + M1)
 *
 * Fixed scenarios for Ready reports:
 *   SC1 Diff 200x50 identical
 *   SC2 Diff 200x50 10 dirty rows
 *   SC3 ParseOne ASCII / CSI arrow batch
 *   SC4 VerticalSplit 3 + Grid 4x4 correctness
 *   SC5 Frame Begin/End empty (test runtime)
 *   SC6 ParseOne focus CSI I/O (DECSET 1004)
 *   SC7 Wide CJK cell width correctness
 *   SC8 Truecolor env-attested profile
 *   SC9 Overlay merge
 *   SC10 SGR mouse parse
 *   SC11 Bracketed paste 200~/201~
 *   SC12 Kitty flags-reply Verified
 *   SC13 Bracketed paste session enable
 *   SC14 HorizontalSplit correctness
 *   SC15 Input resilience (NeedMore + recovery)
 *   SC16 Diff single-cell upper bound
 *   SC17 Backend mouse Enter/Leave alternate sequences
 *   SC18 ResizeEvent helpers
 *   SC19 PercentageConstraint vertical split
 *   SC20 SGR truecolor FG emit
 *   SC21 DrawPatches adjacent style reuse
 *   SC22 RatioConstraint vertical split
 *   SC23 SGR indexed FG/BG
 *   SC24 DrawPatches style-change reapply
 *   SC25 FocusManager Tab cycle
 *   SC26 Keybind BindKey + HandleKey
 *   SC27 FrameBudget not over after BeginFrame
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.time,
  nextpas.core.text.builder,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.event,
  nextpas.core.tui.input,
  nextpas.core.tui.layout,
  nextpas.core.tui.layout.grid,
  nextpas.core.tui.overlay,
  nextpas.core.tui.ansi,
  nextpas.core.tui.backend.ansi,
  nextpas.core.tui.focus,
  nextpas.core.tui.keybind,
  nextpas.core.tui.frame_budget,
  nextpas.core.tui.terminal;

const
  W = 200;
  H = 50;
  SC_ITERS = 2000;
  SC_WARMUP = 50;
  SC3_ITERS = 50000;
  SC3_WARMUP = 1000;
  SC5_ITERS = 500;
  SC5_WARMUP = 20;

type
  TScoreRow = record
    Id: string;
    Subject: string;
    NsPerOp: Int64;
    Ops: UInt64;
    Ok: Boolean;
    Note: string;
  end;

var
  GRows: array of TScoreRow;
  GRowCount: Integer;
  GFailed: Integer;
  GKeybindActionCalled: Boolean;

procedure AddRow(const AId, ASubject: string; ANsPerOp: Int64; AOps: UInt64;
  AOk: Boolean; const ANote: string);
begin
  if GRowCount >= Length(GRows) then
    SetLength(GRows, GRowCount + 8);
  GRows[GRowCount].Id := AId;
  GRows[GRowCount].Subject := ASubject;
  GRows[GRowCount].NsPerOp := ANsPerOp;
  GRows[GRowCount].Ops := AOps;
  GRows[GRowCount].Ok := AOk;
  GRows[GRowCount].Note := ANote;
  Inc(GRowCount);
  if not AOk then
    Inc(GFailed);
end;

function NsPerOp(AStart, AEnd: UInt64; AOps: UInt64): Int64;
begin
  if AOps = 0 then
    Exit(0);
  Result := Int64((AEnd - AStart) div AOps);
end;

procedure FillBase(ABuf: TBuffer);
var
  Y: Integer;
begin
  for Y := 0 to H - 1 do
    ABuf.SetString(0, Y, 'base content row', StyleDefault);
end;

procedure MarkDirtyRows(ABuf: TBuffer);
var
  I: Integer;
begin
  for I := 0 to 9 do
    ABuf.SetString(0, I * 5, 'DIRTY', StyleDefault);
end;

procedure RunSC1;
var
  LPrev, LSame: TBuffer;
  LPatches: TDiffEntries;
  LCount, I: Integer;
  LStart, LEnd: UInt64;
  LOk: Boolean;
begin
  WriteLn('SC1 Diff identical 200x50 ...');
  LOk := True;
  LPrev := TBuffer.CreateEmpty(TRect.Make(0, 0, W, H));
  LSame := TBuffer.CreateEmpty(TRect.Make(0, 0, W, H));
  try
    FillBase(LPrev);
    FillBase(LSame);
    for I := 1 to SC_WARMUP do
      LPrev.DiffInto(LSame, LPatches);
    LStart := platform_monotonic_ns;
    for I := 1 to SC_ITERS do
    begin
      LCount := LPrev.DiffInto(LSame, LPatches);
      if LCount <> 0 then
        LOk := False;
    end;
    LEnd := platform_monotonic_ns;
    AddRow('SC1', 'diff_identical', NsPerOp(LStart, LEnd, SC_ITERS), SC_ITERS, LOk,
      'patches=0');
  finally
    LPrev.Free;
    LSame.Free;
  end;
end;

procedure RunSC2;
var
  LPrev, LCurr: TBuffer;
  LPatches: TDiffEntries;
  LCount, I: Integer;
  LStart, LEnd: UInt64;
  LOk: Boolean;
begin
  WriteLn('SC2 Diff dirty 10 rows 200x50 ...');
  LOk := True;
  LPrev := TBuffer.CreateEmpty(TRect.Make(0, 0, W, H));
  LCurr := TBuffer.CreateEmpty(TRect.Make(0, 0, W, H));
  try
    FillBase(LPrev);
    FillBase(LCurr);
    MarkDirtyRows(LCurr);
    for I := 1 to SC_WARMUP do
      LPrev.DiffInto(LCurr, LPatches);
    LStart := platform_monotonic_ns;
    for I := 1 to SC_ITERS do
    begin
      LCount := LPrev.DiffInto(LCurr, LPatches);
      if (LCount <= 0) or (LCount >= W * H) then
        LOk := False;
    end;
    LEnd := platform_monotonic_ns;
    AddRow('SC2', 'diff_dirty10', NsPerOp(LStart, LEnd, SC_ITERS), SC_ITERS, LOk,
      '0<patches<full');
  finally
    LPrev.Free;
    LCurr.Free;
  end;
end;

procedure RunSC3;
var
  LEvent: TEvent;
  LConsumed, I: Integer;
  LResult: TParseResult;
  LStart, LEnd: UInt64;
  LOk: Boolean;
  LAscii: array[0..0] of Byte;
  LCsi: array[0..2] of Byte;
begin
  WriteLn('SC3 ParseOne batch ...');
  LOk := True;
  LAscii[0] := Ord('a');
  LCsi[0] := 27;
  LCsi[1] := Ord('[');
  LCsi[2] := Ord('A');

  for I := 1 to SC3_WARMUP do
  begin
    ParseOne(LAscii[0], 1, True, LEvent, LConsumed);
    ParseOne(LCsi[0], 3, True, LEvent, LConsumed);
  end;

  LStart := platform_monotonic_ns;
  for I := 1 to SC3_ITERS do
  begin
    LResult := ParseOne(LAscii[0], 1, True, LEvent, LConsumed);
    if (LResult <> prSuccess) or (LEvent.Kind <> evKey) then
      LOk := False;
  end;
  LEnd := platform_monotonic_ns;
  AddRow('SC3a', 'parse_ascii', NsPerOp(LStart, LEnd, SC3_ITERS), SC3_ITERS, LOk,
    'kcChar a');

  LOk := True;
  LStart := platform_monotonic_ns;
  for I := 1 to SC3_ITERS do
  begin
    LResult := ParseOne(LCsi[0], 3, True, LEvent, LConsumed);
    if (LResult <> prSuccess) or (LEvent.Key.Code <> kcUp) then
      LOk := False;
  end;
  LEnd := platform_monotonic_ns;
  AddRow('SC3b', 'parse_csi_up', NsPerOp(LStart, LEnd, SC3_ITERS), SC3_ITERS, LOk,
    'arrow up');
end;

procedure RunSC4;
var
  LArea: TRect;
  LRects: TRectArray;
  LGrid: TGridResult;
  LAreaSum, I, R, C: Integer;
  LOk: Boolean;
  LCell: TRect;
begin
  WriteLn('SC4 Layout correctness ...');
  LOk := True;
  LArea := TRect.Make(0, 0, 200, 60);
  LRects := VerticalSplit(LArea, [
    LengthConstraint(3), MinConstraint(0), LengthConstraint(3)]);
  if Length(LRects) <> 3 then
    LOk := False
  else
  begin
    LAreaSum := 0;
    for I := 0 to High(LRects) do
      Inc(LAreaSum, LRects[I].Width * LRects[I].Height);
    if LAreaSum <> LArea.Width * LArea.Height then
      LOk := False;
    if LRects[0].Height <> 3 then
      LOk := False;
    if LRects[2].Height <> 3 then
      LOk := False;
  end;
  AddRow('SC4a', 'vsplit3', 0, 1, LOk, 'area conserve + heights');

  LOk := True;
  LGrid := Grid(LArea, 4, 4);
  LAreaSum := 0;
  for R := 0 to 3 do
    for C := 0 to 3 do
    begin
      LCell := LGrid.Cell(R, C);
      if LCell.IsEmpty then
        LOk := False;
      Inc(LAreaSum, LCell.Width * LCell.Height);
    end;
  if LAreaSum <> LArea.Width * LArea.Height then
    LOk := False;
  AddRow('SC4b', 'grid4x4', 0, 1, LOk, '16 cells cover area');
end;

procedure RunSC5;
var
  LTerm: TTerminal;
  LFrame: TFrame;
  I: Integer;
  LStart, LEnd: UInt64;
  LOk: Boolean;
begin
  WriteLn('SC5 Frame Begin/End empty ...');
  LOk := True;
  LTerm := TTerminal.Create;
  try
    LTerm.InitializeFrameRuntimeForTest(TRect.Make(0, 0, 40, 12));
    for I := 1 to SC5_WARMUP do
    begin
      LFrame := LTerm.BeginFrame;
      LTerm.EndFrame(LFrame);
    end;
    LStart := platform_monotonic_ns;
    for I := 1 to SC5_ITERS do
    begin
      LFrame := LTerm.BeginFrame;
      if LFrame.Buffer = nil then
        LOk := False;
      LTerm.EndFrame(LFrame);
    end;
    LEnd := platform_monotonic_ns;
    AddRow('SC5', 'frame_empty', NsPerOp(LStart, LEnd, SC5_ITERS), SC5_ITERS, LOk,
      'Begin/End test runtime');
  finally
    LTerm.Free;
  end;
end;

procedure RunSC6;
var
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
  LOk: Boolean;
  LIn, LOut: array[0..2] of Byte;
begin
  WriteLn('SC6 ParseOne focus CSI I/O ...');
  LIn[0] := 27;
  LIn[1] := Ord('[');
  LIn[2] := Ord('I');
  LOut[0] := 27;
  LOut[1] := Ord('[');
  LOut[2] := Ord('O');

  LOk := True;
  LResult := ParseOne(LIn[0], 3, True, LEvent, LConsumed);
  if (LResult <> prSuccess) or (LEvent.Kind <> evFocus) or
     (LEvent.Focus.Kind <> fkIn) or (LConsumed <> 3) then
    LOk := False;
  AddRow('SC6a', 'parse_focus_in', 0, 1, LOk, 'CSI I → fkIn');

  LOk := True;
  LResult := ParseOne(LOut[0], 3, True, LEvent, LConsumed);
  if (LResult <> prSuccess) or (LEvent.Kind <> evFocus) or
     (LEvent.Focus.Kind <> fkOut) or (LConsumed <> 3) then
    LOk := False;
  AddRow('SC6b', 'parse_focus_out', 0, 1, LOk, 'CSI O → fkOut');
end;

procedure RunSC7;
var
  LBuf: TBuffer;
  LLead, LTail: PCell;
  LOk: Boolean;
begin
  WriteLn('SC7 Wide CJK cell width ...');
  LOk := True;
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 8, 1));
  try
    LBuf.SetString(0, 0, #$E4#$B8#$AD, StyleDefault);
    LLead := LBuf.CellAt(0, 0);
    LTail := LBuf.CellAt(1, 0);
    if (LLead = nil) or (LTail = nil) then
      LOk := False
    else if (LLead^.Width <> 2) or (not LTail^.Skip) or (LTail^.Width <> 0) then
      LOk := False;
  finally
    LBuf.Free;
  end;
  AddRow('SC7', 'cjk_width2', 0, 1, LOk, 'lead w=2 + skip tail');
end;


procedure RunSC8;
var
  LProfile: TTuiTerminalCapabilityProfile;
  LOk: Boolean;
begin
  WriteLn('SC8 Truecolor env-attested profile ...');
  LOk := True;
  LProfile := TTerminal.DetectCapabilityProfileFromHints(
    'truecolor', '', '', '', '');
  if (not LProfile.Truecolor.Detected) or (not LProfile.Truecolor.Active) or
     (not LProfile.Truecolor.Verified) then
    LOk := False;
  AddRow('SC8a', 'truecolor_env', 0, 1, LOk, 'COLORTERM truecolor R+D+A+V');

  LOk := True;
  LProfile := TTerminal.DetectCapabilityProfileFromHints(
    '24bit', '', '', '', '');
  if (not LProfile.Truecolor.Verified) or (not LProfile.Truecolor.Active) then
    LOk := False;
  AddRow('SC8b', 'truecolor_24bit', 0, 1, LOk, 'COLORTERM 24bit verified');

  LOk := True;
  LProfile := TTerminal.DetectCapabilityProfileFromHints(
    '', '', '', '', '');
  if LProfile.Truecolor.Detected or LProfile.Truecolor.Active or
     LProfile.Truecolor.Verified then
    LOk := False;
  AddRow('SC8c', 'truecolor_absent', 0, 1, LOk, 'no COLORTERM → not verified');
end;


procedure RunSC9;
var
  LBase, LDest: TBuffer;
  LOv: TOverlayBuffer;
  LLines: TBufferLines;
  LOk: Boolean;
begin
  WriteLn('SC9 Overlay merge ...');
  LOk := True;
  LBase := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LDest := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 1));
  try
    LBase.SetString(0, 0, 'base', StyleDefault);
    LDest.SetString(0, 0, 'base', StyleDefault);
    LOv.MergeInto(LBase, LDest);
    LLines := LDest.AsLines;
    if LLines[0] <> 'base' then
      LOk := False;
  finally
    LBase.Free; LDest.Free; LOv.Free;
  end;
  AddRow('SC9a', 'overlay_transparent', 0, 1, LOk, 'empty overlay passthrough');

  LOk := True;
  LBase := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LDest := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, 4, 1));
  try
    LBase.SetString(0, 0, 'aaaa', StyleDefault);
    LDest.SetString(0, 0, 'aaaa', StyleDefault);
    LOv.SetString(1, 0, 'XY', StyleDefault);
    LOv.MergeInto(LBase, LDest);
    LLines := LDest.AsLines;
    if LLines[0] <> 'aXYa' then
      LOk := False;
  finally
    LBase.Free; LDest.Free; LOv.Free;
  end;
  AddRow('SC9b', 'overlay_overwrite', 0, 1, LOk, 'marked cells overwrite');
end;

procedure RunSC10;
var
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
  LOk: Boolean;
  LDown: array[0..8] of Byte;
  LScroll: array[0..9] of Byte;
begin
  WriteLn('SC10 ParseOne SGR mouse ...');
  { CSI < 0;5;3M — left down at (4,2) 0-based }
  LDown[0] := 27;
  LDown[1] := Ord('[');
  LDown[2] := Ord('<');
  LDown[3] := Ord('0');
  LDown[4] := Ord(';');
  LDown[5] := Ord('5');
  LDown[6] := Ord(';');
  LDown[7] := Ord('3');
  LDown[8] := Ord('M');

  LOk := True;
  LResult := ParseOne(LDown[0], 9, True, LEvent, LConsumed);
  if (LResult <> prSuccess) or (LEvent.Kind <> evMouse) or
     (LEvent.Mouse.Kind <> mkDown) or (LEvent.Mouse.X <> 4) or
     (LEvent.Mouse.Y <> 2) or (LConsumed <> 9) then
    LOk := False;
  AddRow('SC10a', 'sgr_mouse_down', 0, 1, LOk, 'CSI < 0;5;3M → mkDown');

  { CSI < 64;5;3M — scroll up at (4,2) }
  LScroll[0] := 27;
  LScroll[1] := Ord('[');
  LScroll[2] := Ord('<');
  LScroll[3] := Ord('6');
  LScroll[4] := Ord('4');
  LScroll[5] := Ord(';');
  LScroll[6] := Ord('5');
  LScroll[7] := Ord(';');
  LScroll[8] := Ord('3');
  LScroll[9] := Ord('M');

  LOk := True;
  LResult := ParseOne(LScroll[0], 10, True, LEvent, LConsumed);
  if (LResult <> prSuccess) or (LEvent.Kind <> evMouse) or
     (LEvent.Mouse.Kind <> mkScrollUp) or (LConsumed <> 10) then
    LOk := False;
  AddRow('SC10b', 'sgr_scroll_up', 0, 1, LOk, 'CSI < 64;5;3M → mkScrollUp');
end;

procedure RunSC11;
var
  LEvent: TEvent;
  LConsumed: Integer;
  LResult: TParseResult;
  LOk: Boolean;
  LStart, LEnd: array[0..5] of Byte;
begin
  WriteLn('SC11 ParseOne bracketed paste ...');
  { CSI 200~ }
  LStart[0] := 27;
  LStart[1] := Ord('[');
  LStart[2] := Ord('2');
  LStart[3] := Ord('0');
  LStart[4] := Ord('0');
  LStart[5] := Ord('~');

  LOk := True;
  LResult := ParseOne(LStart[0], 6, True, LEvent, LConsumed);
  if (LResult <> prSuccess) or (LEvent.Kind <> evPaste) or (LConsumed <> 6) then
    LOk := False;
  AddRow('SC11a', 'paste_start', 0, 1, LOk, 'CSI 200~ → evPaste');

  { CSI 201~ — swallowed as None }
  LEnd[0] := 27;
  LEnd[1] := Ord('[');
  LEnd[2] := Ord('2');
  LEnd[3] := Ord('0');
  LEnd[4] := Ord('1');
  LEnd[5] := Ord('~');

  LOk := True;
  LResult := ParseOne(LEnd[0], 6, True, LEvent, LConsumed);
  if (LResult <> prSuccess) or (LEvent.Kind = evPaste) or (LConsumed <> 6) then
    LOk := False;
  AddRow('SC11b', 'paste_end_swallow', 0, 1, LOk, 'CSI 201~ not evPaste');
end;

procedure RunSC12;
var
  LTerm: TTerminal;
  LEv: TEvent;
  LReply: array[0..4] of Byte;
  LOk: Boolean;
begin
  WriteLn('SC12 Kitty flags-reply Verified ...');
  LOk := True;
  LTerm := TTerminal.Create;
  try
    LTerm.InitializeFrameRuntimeForTest(TRect.Make(0, 0, 4, 2));
    LTerm.NegotiateKittyKeyboardForTest(True);
    if LTerm.CapabilityProfile.KittyKeyboard.Verified then
      LOk := False;
    { CSI ? 5 u }
    LReply[0] := 27;
    LReply[1] := Ord('[');
    LReply[2] := Ord('?');
    LReply[3] := Ord('5');
    LReply[4] := Ord('u');
    LTerm.InjectInputBytesForTest(LReply);
    if LTerm.PollQueuedEventForTest(True, LEv) then
      LOk := False;
    if (not LTerm.CapabilityProfile.KittyKeyboard.Active) or
       (not LTerm.CapabilityProfile.KittyKeyboard.Verified) then
      LOk := False;
  finally
    LTerm.Free;
  end;
  AddRow('SC12a', 'kitty_verified', 0, 1, LOk, 'CSI ? 5 u → Verified');

  LOk := True;
  LTerm := TTerminal.Create;
  try
    LTerm.InitializeFrameRuntimeForTest(TRect.Make(0, 0, 4, 2));
    LTerm.NegotiateKittyKeyboardForTest(True);
    LReply[0] := 27;
    LReply[1] := Ord('[');
    LReply[2] := Ord('?');
    LReply[3] := Ord('0');
    LReply[4] := Ord('u');
    LTerm.InjectInputBytesForTest(LReply);
    if LTerm.PollQueuedEventForTest(True, LEv) then
      LOk := False;
    if (not LTerm.HasKittyKeyboard) or
       LTerm.CapabilityProfile.KittyKeyboard.Verified then
      LOk := False;
  finally
    LTerm.Free;
  end;
  AddRow('SC12b', 'kitty_flags_zero', 0, 1, LOk, 'CSI ? 0 u Active, not Verified');
end;

procedure RunSC13;
var
  LTerm: TTerminal;
  LOpts: TTerminalOptions;
  LPending: AnsiString;
  LOk: Boolean;
begin
  WriteLn('SC13 Bracketed paste session ...');
  LOk := True;
  LTerm := TTerminal.Create;
  try
    LOpts := TTerminalOptions.EditorDefault;
    LOpts.BracketedPaste := True;
    LTerm.Options := LOpts;
    LTerm.InitializeFrameRuntimeForTest(TRect.Make(0, 0, 4, 2));
    LPending := LTerm.BackendPendingForTest;
    if Pos(#27'[?2004h', LPending) = 0 then
      LOk := False;
  finally
    LTerm.Free;
  end;
  AddRow('SC13a', 'paste_session_on', 0, 1, LOk, 'opt-in emits 2004h');

  LOk := True;
  LTerm := TTerminal.Create;
  try
    LTerm.InitializeFrameRuntimeForTest(TRect.Make(0, 0, 4, 2));
    LPending := LTerm.BackendPendingForTest;
    if Pos('2004', LPending) > 0 then
      LOk := False;
  finally
    LTerm.Free;
  end;
  AddRow('SC13b', 'paste_session_off', 0, 1, LOk, 'default no 2004');
end;

procedure RunSC14;
var
  LArea: TRect;
  LRects: TRectArray;
  LAreaSum, I: Integer;
  LOk: Boolean;
begin
  WriteLn('SC14 HorizontalSplit correctness ...');
  LOk := True;
  LArea := TRect.Make(0, 0, 200, 60);
  LRects := HorizontalSplit(LArea, [
    LengthConstraint(10), MinConstraint(0), LengthConstraint(10)]);
  if Length(LRects) <> 3 then
    LOk := False
  else
  begin
    LAreaSum := 0;
    for I := 0 to High(LRects) do
      Inc(LAreaSum, LRects[I].Width * LRects[I].Height);
    if LAreaSum <> LArea.Width * LArea.Height then
      LOk := False;
    if LRects[0].Width <> 10 then
      LOk := False;
    if LRects[2].Width <> 10 then
      LOk := False;
  end;
  AddRow('SC14a', 'hsplit3', 0, 1, LOk, 'area conserve + widths');
end;

procedure RunSC15;
var
  LEvent: TEvent;
  LConsumed, LPos: Integer;
  LResult: TParseResult;
  LOk: Boolean;
  LCsi: array[0..2] of Byte;
  LBad: array[0..1] of Byte;
begin
  WriteLn('SC15 Input resilience ...');
  LCsi[0] := 27;
  LCsi[1] := Ord('[');
  LCsi[2] := Ord('A');

  LOk := True;
  LResult := ParseOne(LCsi[0], 2, False, LEvent, LConsumed);
  if LResult <> prNeedMore then
    LOk := False;
  LResult := ParseOne(LCsi[0], 3, False, LEvent, LConsumed);
  if (LResult <> prSuccess) or (LEvent.Kind <> evKey) or
     (LEvent.Key.Code <> kcUp) or (LConsumed <> 3) then
    LOk := False;
  AddRow('SC15a', 'csi_need_more', 0, 1, LOk, 'ESC[ NeedMore then CSI A');

  LOk := True;
  LBad[0] := $FF;
  LBad[1] := Ord('z');
  LPos := 0;
  LResult := ParseOne(LBad[LPos], 2 - LPos, True, LEvent, LConsumed);
  if LResult <> prInvalid then
    LOk := False
  else
  begin
    if LConsumed <= 0 then
      Inc(LPos)
    else
      Inc(LPos, LConsumed);
    LResult := ParseOne(LBad[LPos], 2 - LPos, True, LEvent, LConsumed);
    if (LResult <> prSuccess) or (LEvent.Kind <> evKey) or
       (LEvent.Key.Code <> kcChar) or (LEvent.Key.Ch <> Ord('z')) then
      LOk := False;
  end;
  AddRow('SC15b', 'invalid_recover', 0, 1, LOk, '0xFF then z recovers');
end;

procedure RunSC16;
var
  Prev, Curr: TBuffer;
  LPatches: TDiffEntries;
  N: Integer;
  LOk: Boolean;
begin
  WriteLn('SC16 Diff single-cell upper bound ...');
  LOk := True;
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, W, H));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, W, H));
  try
    Prev.SetString(0, 0, 'base', StyleDefault);
    Curr.SetString(0, 0, 'base', StyleDefault);
    N := Prev.DiffInto(Curr, LPatches);
    if N <> 0 then
      LOk := False;
    Curr.SetString(3, 0, 'X', StyleDefault);
    N := Prev.DiffInto(Curr, LPatches);
    if (N <= 0) or (N >= (W * H) div 4) then
      LOk := False;
  finally
    Prev.Free;
    Curr.Free;
  end;
  AddRow('SC16a', 'diff_single_cell', 0, 1, LOk, '1 cell dirty patches << full');
end;

function BackendPendingStr(ABackend: TAnsiBackend): AnsiString;
var
  LLen: Integer;
begin
  Result := '';
  LLen := ABackend.PendingLength;
  SetLength(Result, LLen);
  if LLen > 0 then
    Move(ABackend.PendingBytes^, Result[1], LLen);
end;

procedure RunSC17;
var
  LBE: TAnsiBackend;
  LPending: AnsiString;
  LOk: Boolean;
begin
  WriteLn('SC17 Backend mouse Enter/Leave alternate ...');
  LOk := True;
  LBE := TAnsiBackend.Create(-1);
  try
    LBE.EnterAlternate(amMouseFull, False);
    LPending := BackendPendingStr(LBE);
    if (Pos(#27'[?1003h', LPending) = 0) or (Pos(#27'[?1006h', LPending) = 0) or
       (Pos(#27'[?1049h', LPending) = 0) then
      LOk := False;
    LBE.DiscardPending;
    LBE.LeaveAlternate(amMouseFull, False);
    LPending := BackendPendingStr(LBE);
    if (Pos(#27'[?1003l', LPending) = 0) or (Pos(#27'[?1006l', LPending) = 0) or
       (Pos(#27'[?1049l', LPending) = 0) then
      LOk := False
    else if Pos(#27'[?1003l', LPending) > Pos(#27'[?1049l', LPending) then
      LOk := False; { disable modes before leave alt }
  finally
    LBE.Free;
  end;
  AddRow('SC17a', 'mouse_alt_modes', 0, 1, LOk, '1003/1006 enter+leave order');
end;

procedure RunSC18;
var
  LEv: TEvent;
  LOk: Boolean;
begin
  WriteLn('SC18 ResizeEvent helpers ...');
  LOk := True;
  LEv := ResizeEvent(80, 24);
  if (LEv.Kind <> evResize) or (LEv.Resize.Width <> 80) or
     (LEv.Resize.Height <> 24) or (not IsResize(LEv)) or IsKey(LEv) then
    LOk := False;
  AddRow('SC18a', 'resize_event', 0, 1, LOk, 'ResizeEvent 80x24 + IsResize');
end;

procedure RunSC19;
var
  LArea: TRect;
  LRects: TRectArray;
  LAreaSum, I: Integer;
  LOk: Boolean;
begin
  WriteLn('SC19 PercentageConstraint VSplit ...');
  LOk := True;
  LArea := TRect.Make(0, 0, 200, 60);
  LRects := VerticalSplit(LArea, [
    PercentageConstraint(50), PercentageConstraint(50)]);
  if Length(LRects) <> 2 then
    LOk := False
  else
  begin
    LAreaSum := 0;
    for I := 0 to High(LRects) do
      Inc(LAreaSum, LRects[I].Width * LRects[I].Height);
    if LAreaSum <> LArea.Width * LArea.Height then
      LOk := False;
    if LRects[0].Height + LRects[1].Height <> LArea.Height then
      LOk := False;
  end;
  AddRow('SC19a', 'pct_vsplit50', 0, 1, LOk, '50/50 height sum + area');
end;

function ScorecardStyledCell(ACh: AnsiChar; const AStyle: TStyle): TCell;
begin
  CellReset(Result);
  CellSetSymbolAscii(Result, ACh);
  CellApplyStyle(Result, AStyle);
end;

procedure RunSC20;
var
  B: TStringBuilder;
  LOk: Boolean;
begin
  WriteLn('SC20 SGR truecolor FG emit ...');
  LOk := True;
  B.Init(64);
  try
    AnsiSgrFg(B, RgbColor(10, 20, 30));
    if B.ToString <> #27'[38;2;10;20;30m' then
      LOk := False;
  finally
    B.Done;
  end;
  AddRow('SC20a', 'sgr_rgb_fg', 0, 1, LOk, 'CSI 38;2;10;20;30m');
end;

procedure RunSC21;
var
  LBE: TAnsiBackend;
  LPatches: TDiffEntries;
  LPending: AnsiString;
  LOk: Boolean;
begin
  WriteLn('SC21 DrawPatches adjacent style reuse ...');
  LOk := True;
  LBE := TAnsiBackend.Create(-1);
  SetLength(LPatches, 2);
  try
    LPatches[0].X := 0;
    LPatches[0].Y := 0;
    LPatches[0].Cell := ScorecardStyledCell('A', StyleDefault.WithFg(TUI_RED));
    LPatches[1].X := 1;
    LPatches[1].Y := 0;
    LPatches[1].Cell := ScorecardStyledCell('B', StyleDefault.WithFg(TUI_RED));
    LBE.DrawPatchesN(LPatches, 2);
    LPending := BackendPendingStr(LBE);
    if LPending <> #27'[1;1H'#27'[0m'#27'[31mAB' then
      LOk := False;
  finally
    LBE.Free;
  end;
  AddRow('SC21a', 'draw_adjacent', 0, 1, LOk, 'MoveTo+shared SGR+AB');
end;

procedure RunSC22;
var
  LArea: TRect;
  LRects: TRectArray;
  LAreaSum, I: Integer;
  LOk: Boolean;
begin
  WriteLn('SC22 RatioConstraint VSplit ...');
  LOk := True;
  LArea := TRect.Make(0, 0, 200, 60);
  LRects := VerticalSplit(LArea, [
    RatioConstraint(1, 3), FillConstraint(1)]);
  if Length(LRects) < 2 then
    LOk := False
  else
  begin
    LAreaSum := 0;
    for I := 0 to High(LRects) do
      Inc(LAreaSum, LRects[I].Width * LRects[I].Height);
    if LAreaSum <> LArea.Width * LArea.Height then
      LOk := False;
  end;
  AddRow('SC22a', 'ratio_vsplit', 0, 1, LOk, '1:3 + fill area conserve');
end;

procedure RunSC23;
var
  B: TStringBuilder;
  LOk: Boolean;
begin
  WriteLn('SC23 SGR indexed FG/BG ...');
  LOk := True;
  B.Init(64);
  try
    AnsiSgrFg(B, IndexedColor(200));
    if B.ToString <> #27'[38;5;200m' then
      LOk := False;
    B.Clear;
    AnsiSgrBg(B, IndexedColor(2));
    if B.ToString <> #27'[42m' then
      LOk := False;
  finally
    B.Done;
  end;
  AddRow('SC23a', 'sgr_indexed', 0, 1, LOk, '38;5;200 + bg 42');
end;

procedure RunSC24;
var
  LBE: TAnsiBackend;
  LPatches: TDiffEntries;
  LPending: AnsiString;
  LOk: Boolean;
begin
  WriteLn('SC24 DrawPatches style-change reapply ...');
  LOk := True;
  LBE := TAnsiBackend.Create(-1);
  SetLength(LPatches, 2);
  try
    LPatches[0].X := 0;
    LPatches[0].Y := 0;
    LPatches[0].Cell := ScorecardStyledCell('A', StyleDefault.WithFg(TUI_RED));
    LPatches[1].X := 1;
    LPatches[1].Y := 0;
    LPatches[1].Cell := ScorecardStyledCell('B', StyleDefault.WithFg(TUI_BLUE));
    LBE.DrawPatchesN(LPatches, 2);
    LPending := BackendPendingStr(LBE);
    if LPending <> #27'[1;1H'#27'[0m'#27'[31mA'#27'[0m'#27'[34mB' then
      LOk := False;
  finally
    LBE.Free;
  end;
  AddRow('SC24a', 'draw_style_chg', 0, 1, LOk, 'reapply SGR no extra MoveTo');
end;

procedure RunSC25;
var
  LFocus: TFocusManager;
  LId1, LId2, LId3: TFocusId;
  LKey: TKeyEvent;
  LOk: Boolean;
begin
  WriteLn('SC25 FocusManager Tab cycle ...');
  LOk := True;
  LFocus := TFocusManager.Create;
  try
    LId1 := LFocus.Register(TRect.Make(0, 0, 10, 1));
    LId2 := LFocus.Register(TRect.Make(0, 2, 10, 1));
    LId3 := LFocus.Register(TRect.Make(0, 4, 10, 1));
    if LFocus.FocusedId <> LId1 then
      LOk := False;
    LKey.Code := kcTab;
    LKey.Modifiers := [];
    LKey.Ch := 0;
    if not LFocus.HandleKey(LKey) then
      LOk := False;
    if LFocus.FocusedId <> LId2 then
      LOk := False;
    if not LFocus.HandleKey(LKey) then
      LOk := False;
    if LFocus.FocusedId <> LId3 then
      LOk := False;
    LKey.Modifiers := [kmShift];
    if not LFocus.HandleKey(LKey) then
      LOk := False;
    if LFocus.FocusedId <> LId2 then
      LOk := False;
  finally
    LFocus.Free;
  end;
  AddRow('SC25a', 'focus_tab', 0, 1, LOk, 'Tab forward + Shift+Tab back');
end;

procedure ScorecardKeybindAction;
begin
  GKeybindActionCalled := True;
end;

procedure RunSC26;
var
  LMgr: TKeybindManager;
  LKey: TKeyEvent;
  LOk: Boolean;
begin
  WriteLn('SC26 Keybind BindKey + HandleKey ...');
  LOk := True;
  GKeybindActionCalled := False;
  LMgr := TKeybindManager.Create;
  try
    LMgr.BindKey(kmNormal, kcEnter, @ScorecardKeybindAction, 'Confirm');
    if LMgr.BindingCount <> 1 then
      LOk := False;
    LKey.Code := kcEnter;
    LKey.Ch := 0;
    LKey.Modifiers := [];
    if not LMgr.HandleKey(LKey) then
      LOk := False;
    if not GKeybindActionCalled then
      LOk := False;
  finally
    LMgr.Free;
  end;
  AddRow('SC26a', 'keybind_enter', 0, 1, LOk, 'BindKey+HandleKey fires action');
end;

procedure RunSC27;
var
  LBudget: TFrameBudget;
  LOk: Boolean;
begin
  WriteLn('SC27 FrameBudget not over after BeginFrame ...');
  LOk := True;
  LBudget := TFrameBudget.Create(16.0);
  LBudget.BeginFrame;
  if LBudget.IsOverBudget then
    LOk := False;
  AddRow('SC27a', 'frame_budget', 0, 1, LOk, 'BeginFrame not over 16ms');
end;

procedure PrintTable;
var
  I: Integer;
  LStatus: string;
begin
  WriteLn;
  WriteLn('ID     Subject            ns/op     ops   ok  note');
  WriteLn('------ ------------------ --------- ------ --- ----------------');
  for I := 0 to GRowCount - 1 do
  begin
    if GRows[I].Ok then
      LStatus := 'Y'
    else
      LStatus := 'N';
    Write(GRows[I].Id:6, '  ');
    Write(GRows[I].Subject:18, '  ');
    Write(GRows[I].NsPerOp:9, '  ');
    Write(GRows[I].Ops:6, '  ');
    Write(LStatus:3, '  ');
    WriteLn(GRows[I].Note);
  end;
  WriteLn;
  if GFailed = 0 then
    WriteLn('scorecard: ALL PASS (', GRowCount, ' rows)')
  else
    WriteLn('scorecard: FAILED rows=', GFailed);
end;

begin
  SetLength(GRows, 72);
  GRowCount := 0;
  GFailed := 0;
  WriteLn('=== nextpas.core.tui scorecard SC1-SC27 ===');
  RunSC1;
  RunSC2;
  RunSC3;
  RunSC4;
  RunSC5;
  RunSC6;
  RunSC7;
  RunSC8;
  RunSC9;
  RunSC10;
  RunSC11;
  RunSC12;
  RunSC13;
  RunSC14;
  RunSC15;
  RunSC16;
  RunSC17;
  RunSC18;
  RunSC19;
  RunSC20;
  RunSC21;
  RunSC22;
  RunSC23;
  RunSC24;
  RunSC25;
  RunSC26;
  RunSC27;
  PrintTable;
  if GFailed > 0 then
    Halt(1);
end.
