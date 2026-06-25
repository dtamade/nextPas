program bench_diff;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.bench;

var
  Prev, Curr, Same: TBuffer;
  Patches: TDiffEntries;

procedure BenchDiffChanged(AIters: Int64);
var LI: Int64;
begin
  for LI := 1 to AIters do
    Prev.DiffInto(Curr, Patches);
end;

procedure BenchDiffIdentical(AIters: Int64);
var LI: Int64;
begin
  for LI := 1 to AIters do
    Prev.DiffInto(Same, Patches);
end;

var
  LResults: IBenchResults;
  I: Integer;
begin
  Prev := TBuffer.CreateEmpty(TRect.Make(0, 0, 200, 50));
  Curr := TBuffer.CreateEmpty(TRect.Make(0, 0, 200, 50));
  Same := TBuffer.CreateEmpty(TRect.Make(0, 0, 200, 50));

  Prev.SetString(0, 0, 'base content', StyleDefault);
  Same.SetString(0, 0, 'base content', StyleDefault);
  Curr.SetString(0, 0, 'base content', StyleDefault);
  for I := 0 to 9 do
    Curr.SetString(I * 15, I + 1, 'changed!', StyleDefault.WithFg(TUI_RED));

  LResults := TBenchSuite.Create('DiffInto 200x50 (10 changed rows)')
    .AddLoop('DiffInto 200x50 (10 changed rows)', @BenchDiffChanged)
    .AddLoop('DiffInto 200x50 (identical)', @BenchDiffIdentical)
    .Run;
  WriteLn(LResults.PrintToConsole);
  Prev.Free; Curr.Free; Same.Free;
end.
