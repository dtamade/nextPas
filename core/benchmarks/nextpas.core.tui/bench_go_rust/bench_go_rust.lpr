program bench_go_rust;
{**
 * nextPas side of TUI cross-lang microbench (Wave Q1 / Q11).
 * Workloads align with scorecard SC1–SC3 + layout/overlay simplified kernels.
 * NOT full ratatui — Layout/Overlay use real nextPas APIs; Go/Rust use stubs.
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
  nextpas.core.tui.overlay;

const
  W = 200;
  H = 50;
  DIFF_ITERS = 2000;
  PARSE_ITERS = 50000;
  LAYOUT_ITERS = 100000;
  OVERLAY_ITERS = 20000;
  OV_W = 40;
  OV_H = 12;

procedure FillBase(ABuf: TBuffer);
var
  Y: Integer;
begin
  for Y := 0 to H - 1 do
    ABuf.SetString(0, Y, 'base content row', StyleDefault);
end;

procedure MarkDirty(ABuf: TBuffer);
var
  I: Integer;
begin
  for I := 0 to 9 do
    ABuf.SetString(0, I * 5, 'DIRTY', StyleDefault);
end;

procedure Report(const AName: string; AStart, AEnd: UInt64; AOps: UInt64);
var
  LNs: Int64;
  LOps: Double;
begin
  if AOps = 0 then
    LNs := 0
  else
    LNs := Int64((AEnd - AStart) div AOps);
  if LNs > 0 then
    LOps := 1.0e9 / LNs
  else
    LOps := 0;
  WriteLn('  ', AName:40, ' ', LNs:12, ' ns/op  ', LOps:12:0, ' ops/s');
end;

var
  Prev, Curr, Same: TBuffer;
  LBase, LDest: TBuffer;
  LOv: TOverlayBuffer;
  Patches: TDiffEntries;
  LRects: TRectArray;
  Ev: TEvent;
  Consumed, I, Sink: Integer;
  LStart, LEnd: UInt64;
  Ascii: array[0..0] of Byte;
  Csi: array[0..2] of Byte;
  LArea: TRect;
begin
  WriteLn('=== nextpas.core.tui bench_go_rust (Pascal) ===');

  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, W, H));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, W, H));
  Same := TBuffer.CreateEmpty(TRect.Make(0, 0, W, H));
  try
    FillBase(Prev);
    FillBase(Same);
    FillBase(Curr);
    MarkDirty(Curr);

    LStart := platform_monotonic_ns;
    for I := 1 to DIFF_ITERS do
      Prev.DiffInto(Same, Patches);
    LEnd := platform_monotonic_ns;
    Report('DiffIdentical 200x50', LStart, LEnd, DIFF_ITERS);

    LStart := platform_monotonic_ns;
    for I := 1 to DIFF_ITERS do
      Prev.DiffInto(Curr, Patches);
    LEnd := platform_monotonic_ns;
    Report('DiffDirty10 200x50', LStart, LEnd, DIFF_ITERS);
  finally
    Prev.Free;
    Curr.Free;
    Same.Free;
  end;

  Ascii[0] := Ord('a');
  Csi[0] := 27;
  Csi[1] := Ord('[');
  Csi[2] := Ord('A');

  LStart := platform_monotonic_ns;
  for I := 1 to PARSE_ITERS do
    ParseOne(Ascii[0], 1, True, Ev, Consumed);
  LEnd := platform_monotonic_ns;
  Report('ParseAscii', LStart, LEnd, PARSE_ITERS);

  LStart := platform_monotonic_ns;
  for I := 1 to PARSE_ITERS do
    ParseOne(Csi[0], 3, True, Ev, Consumed);
  LEnd := platform_monotonic_ns;
  Report('ParseCsiUp', LStart, LEnd, PARSE_ITERS);

  { Layout VSplit3 — real VerticalSplit API }
  LArea := TRect.Make(0, 0, 200, 60);
  Sink := 0;
  LStart := platform_monotonic_ns;
  for I := 1 to LAYOUT_ITERS do
  begin
    LRects := VerticalSplit(LArea, [
      LengthConstraint(3), MinConstraint(0), LengthConstraint(3)]);
    if Length(LRects) > 0 then
      Inc(Sink, LRects[0].Height);
  end;
  LEnd := platform_monotonic_ns;
  if Sink = 0 then
    Halt(2);
  Report('LayoutVSplit3', LStart, LEnd, LAYOUT_ITERS);

  { Layout HSplit3 — real HorizontalSplit API }
  LArea := TRect.Make(0, 0, 200, 60);
  Sink := 0;
  LStart := platform_monotonic_ns;
  for I := 1 to LAYOUT_ITERS do
  begin
    LRects := HorizontalSplit(LArea, [
      LengthConstraint(10), MinConstraint(0), LengthConstraint(10)]);
    if Length(LRects) > 0 then
      Inc(Sink, LRects[0].Width);
  end;
  LEnd := platform_monotonic_ns;
  if Sink = 0 then
    Halt(2);
  Report('LayoutHSplit3', LStart, LEnd, LAYOUT_ITERS);

  { Overlay merge — real TOverlayBuffer.MergeInto }
  LBase := TBuffer.CreateEmpty(TRect.Make(0, 0, OV_W, OV_H));
  LDest := TBuffer.CreateEmpty(TRect.Make(0, 0, OV_W, OV_H));
  LOv := TOverlayBuffer.Create(TRect.Make(0, 0, OV_W, OV_H));
  try
    LBase.SetString(0, 0, 'base-row-content', StyleDefault);
    LOv.SetString(2, 0, 'OV', StyleDefault);
    LStart := platform_monotonic_ns;
    for I := 1 to OVERLAY_ITERS do
      LOv.MergeInto(LBase, LDest);
    LEnd := platform_monotonic_ns;
    if Pos('OV', LDest.AsLines[0]) = 0 then
      Halt(2);
    Report('OverlayMerge 40x12', LStart, LEnd, OVERLAY_ITERS);
  finally
    LBase.Free;
    LDest.Free;
    LOv.Free;
  end;
end.
