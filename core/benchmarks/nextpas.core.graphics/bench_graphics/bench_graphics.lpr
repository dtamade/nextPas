program bench_graphics;
{$mode objfpc}{$H+}
{ bench_graphics: L1 graphics value-type gates (PathBuild/ColorConvert).
  Raster/Image gates are not duplicated here; they are covered in separate
  binaries core/benchmarks/nextpas.core.canvas/bench_raster/bench_raster.lpr
  (FillPath/Stroke/DrawBitmap 100..4096, Gate 350ns) and
  core/benchmarks/nextpas.core.image/bench_image/bench_image.lpr
  (Encode/Decode 512x512, Gate 800us) to keep this binary L0-L1 only. }
uses
  nextpas.core.graphics.base,
  nextpas.core.graphics.color,
  nextpas.core.graphics.path,
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.fs;

procedure BenchPathBuild1K(const ACtx: IBenchContext);
var P: TPath;
begin
  P := TPath.New;
  // single Reserve + Move inline zero-copy: avoids O(N^2); bench harness iterates externally
  P := P.Reserve(1000,1000);
  P := P.LineTo(1, 0.5);
  BenchBlackBoxPtr(@P);
  ACtx.SetBytes(SizeOf(TVec2));
end;

procedure BenchColorConvert(const ACtx: IBenchContext);
var C: TRgba;
begin
  C.R:=0.5; C.G:=0.2; C.B:=0.8; C.A:=1;
  C := ColorConvert(C, csSRGB, csLinear);
  BenchBlackBoxPtr(@C);
end;

var S: IBenchSuite; R: IBenchResults;
begin
  S:=TBenchSuite.Create('graphics');
  S.SetQuiet(True);
  S.SetMinDuration(TDuration.FromMilliseconds(50));
  S.SetMinSamples(5);
  S.Add('Path Build 1K', @BenchPathBuild1K);
  S.Add('ColorConvert 1K', @BenchColorConvert);
  R:=S.Run;
  WriteLn(R.PrintToConsole);
  ForceDirectories('build');
  R.SaveToJSON('build/bench-graphics.json');
  R.SaveToHTML('build/bench-graphics.html');
end.
