program bench_vector;
{$mode objfpc}{$H+}
uses
  nextpas.core.graphics.path,
  nextpas.core.vector.path,
  nextpas.core.vector.tess,
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.fs;

procedure BenchTessRect(const ACtx: IBenchContext);
var P: TPath; T: TTrapezoids;
begin
  P := TPath.New.MoveTo(0,0).LineTo(100,0).LineTo(100,100).LineTo(0,100).Close;
  T := Tessellate(P);
  BenchBlackBoxPtr(@T[0]);
  ACtx.SetBytes(100*100*4);
end;

var S: IBenchSuite; R: IBenchResults;
begin
  S:=TBenchSuite.Create('vector');
  S.SetQuiet(True);
  S.SetMinDuration(TDuration.FromMilliseconds(50));
  S.SetMinSamples(5);
  S.Add('Tess rect 100', @BenchTessRect);
  R:=S.Run;
  WriteLn(R.PrintToConsole);
  ForceDirectories('build');
  R.SaveToJSON('build/bench-vector.json');
  R.SaveToHTML('build/bench-vector.html');
end.
