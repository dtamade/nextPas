program scorecard;
{**
 * tui Scorecard SC1–SC9 (PARITY-GO-RUST Wave Q1–Q6)
 *
 * Fixed scenarios for Ready reports:
 *   SC1 Diff 200x50 identical
 *   SC2 Diff 200x50 10 dirty rows
 *   SC3 ParseOne ASCII / CSI arrow batch
 *   SC4 VerticalSplit 3 + Grid 4x4 correctness
 *   SC5 Frame Begin/End empty (test runtime)
 *   SC6 ParseOne focus CSI I/O (DECSET 1004)
 *   SC7 Wide CJK cell width correctness
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.platform.time,
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
  SetLength(GRows, 16);
  GRowCount := 0;
  GFailed := 0;
  WriteLn('=== nextpas.core.tui scorecard SC1-SC9 ===');
  RunSC1;
  RunSC2;
  RunSC3;
  RunSC4;
  RunSC5;
  RunSC6;
  RunSC7;
  RunSC8;
  RunSC9;
  PrintTable;
  if GFailed > 0 then
    Halt(1);
end.
