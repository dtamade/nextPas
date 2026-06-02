program bench_layout;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.tui.base,
  nextpas.core.tui.layout,
  nextpas.core.tui.layout.grid,
  nextpas.core.bench;

var
  Area: TRect;

procedure BenchVertical3(AIters: Int64);
var LI: Int64; R: TRectArray;
begin
  for LI := 1 to AIters do
    R := VerticalSplit(Area, [LengthConstraint(3), MinConstraint(0), LengthConstraint(3)]);
end;

procedure BenchHorizontal5(AIters: Int64);
var LI: Int64; R: TRectArray;
begin
  for LI := 1 to AIters do
    R := HorizontalSplit(Area, [
      PercentageConstraint(20), FillConstraint(1), FillConstraint(2),
      MaxConstraint(30), LengthConstraint(10)]);
end;

procedure BenchGrid4x4(AIters: Int64);
var LI: Int64; G: TGridResult;
begin
  for LI := 1 to AIters do
    G := Grid(Area, 4, 4);
end;

procedure BenchGrid8x8(AIters: Int64);
var LI: Int64; G: TGridResult;
begin
  for LI := 1 to AIters do
    G := Grid(Area, 8, 8);
end;

var
  Runner: TBenchRunner;
begin
  Area := TRect.Make(0, 0, 200, 60);
  Runner := TBenchRunner.Create;
  Runner.Run('VerticalSplit 3 constraints', @BenchVertical3);
  Runner.Run('HorizontalSplit 5 constraints', @BenchHorizontal5);
  Runner.Run('Grid 4x4 uniform', @BenchGrid4x4);
  Runner.Run('Grid 8x8 uniform', @BenchGrid8x8);
  Runner.Summary;
end.
