program bench_go_rust;
{**
 * nextPas side of TUI cross-lang microbench (Wave Q1).
 * Workloads align with scorecard SC1–SC3 constants.
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
  nextpas.core.tui.input;

const
  W = 200;
  H = 50;
  DIFF_ITERS = 2000;
  PARSE_ITERS = 50000;

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
  Patches: TDiffEntries;
  Ev: TEvent;
  Consumed, I: Integer;
  LStart, LEnd: UInt64;
  Ascii: array[0..0] of Byte;
  Csi: array[0..2] of Byte;
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
end.
