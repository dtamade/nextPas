program bench_raster;
{$mode objfpc}{$H+}
uses
  nextpas.core.base,
  nextpas.core.graphics.base,
  nextpas.core.graphics.path,
  nextpas.core.canvas,
  nextpas.core.bench,
  nextpas.core.bench.base,
  nextpas.core.bench.intf,
  nextpas.core.time.base,
  nextpas.core.simd.raster,
  nextpas.core.fs;

const
  W100 = 100;
  H100 = 100;
  W512 = 512;
  H512 = 512;
  W1K = 1024;
  H1K = 1024;
  W4K = 4096;
  H4K = 1024;
  RAW_PIXELS = 1024;
  RAW_512 = 512;
  RAW_4K = 4096;
  RAW_16K = 16384;
  GATE_NS_100 = 350.0;

var
  GRaw: array[0..RAW_PIXELS * 4 - 1] of Byte;
  GRawBig: array[0..RAW_16K * 4 - 1] of Byte;

procedure BenchFillPathOpaque(const ACtx: IBenchContext);
var C: ICanvas; P: TPath;
begin
  ACtx.SetBytes(W100 * H100 * 4);
  C := CreateRasterCanvas(W100, H100);
  P := TPath.New.MoveTo(10, 10).LineTo(90, 10).LineTo(90, 90).LineTo(10, 90).Close;
  C.FillPath(P, TBrush.Solid(Color32(255, 0, 0, 255)));
  BenchBlackBoxPtr(Pointer(C));
end;

procedure BenchFillPathOpaque512(const ACtx: IBenchContext);
var C: ICanvas; P: TPath;
begin
  ACtx.SetBytes(W512 * H512 * 4);
  C := CreateRasterCanvas(W512, H512);
  P := TPath.New.MoveTo(40, 40).LineTo(472, 40).LineTo(472, 472).LineTo(40, 472).Close;
  C.FillPath(P, TBrush.Solid(Color32(255, 0, 0, 255)));
  BenchBlackBoxPtr(Pointer(C));
end;

procedure BenchFillPathOpaque1K(const ACtx: IBenchContext);
var C: ICanvas; P: TPath;
begin
  ACtx.SetBytes(W1K * H1K * 4);
  C := CreateRasterCanvas(W1K, H1K);
  P := TPath.New.MoveTo(80, 80).LineTo(944, 80).LineTo(944, 944).LineTo(80, 944).Close;
  C.FillPath(P, TBrush.Solid(Color32(255, 0, 0, 255)));
  BenchBlackBoxPtr(Pointer(C));
end;

procedure BenchFillPathOpaque4K(const ACtx: IBenchContext);
var C: ICanvas; P: TPath;
begin
  ACtx.SetBytes(W4K * H4K * 4);
  C := CreateRasterCanvas(W4K, H4K);
  P := TPath.New.MoveTo(100, 100).LineTo(3996, 100).LineTo(3996, 924).LineTo(100, 924).Close;
  C.FillPath(P, TBrush.Solid(Color32(255, 0, 0, 255)));
  BenchBlackBoxPtr(Pointer(C));
end;

procedure BenchFillPathBlend(const ACtx: IBenchContext);
var C: ICanvas; P: TPath;
begin
  ACtx.SetBytes(W100 * H100 * 4);
  C := CreateRasterCanvas(W100, H100);
  P := TPath.New.MoveTo(10, 10).LineTo(90, 10).LineTo(90, 90).LineTo(10, 90).Close;
  C.FillPath(P, TBrush.Solid(Color32(255, 0, 0, 128)));
  BenchBlackBoxPtr(Pointer(C));
end;

procedure BenchFillPathBlend512(const ACtx: IBenchContext);
var C: ICanvas; P: TPath;
begin
  ACtx.SetBytes(W512 * H512 * 4);
  C := CreateRasterCanvas(W512, H512);
  P := TPath.New.MoveTo(40, 40).LineTo(472, 40).LineTo(472, 472).LineTo(40, 472).Close;
  C.FillPath(P, TBrush.Solid(Color32(255, 0, 0, 128)));
  BenchBlackBoxPtr(Pointer(C));
end;

procedure BenchStroke(const ACtx: IBenchContext);
var C: ICanvas; P: TPath;
begin
  ACtx.SetBytes(W100 * H100 * 4);
  C := CreateRasterCanvas(W100, H100);
  P := TPath.New.MoveTo(10, 10).LineTo(90, 10).LineTo(90, 90).LineTo(10, 90).Close;
  C.StrokePath(P, TBrush.Solid(Color32(0, 0, 255, 255)), TStrokeOptions.Create(2));
  BenchBlackBoxPtr(Pointer(C));
end;

procedure BenchStroke512(const ACtx: IBenchContext);
var C: ICanvas; P: TPath;
begin
  ACtx.SetBytes(W512 * H512 * 4);
  C := CreateRasterCanvas(W512, H512);
  P := TPath.New.MoveTo(40, 40).LineTo(472, 40).LineTo(472, 472).LineTo(40, 472).Close;
  C.StrokePath(P, TBrush.Solid(Color32(0, 0, 255, 255)), TStrokeOptions.Create(2));
  BenchBlackBoxPtr(Pointer(C));
end;

procedure BenchRawFillSolid(const ACtx: IBenchContext);
begin
  ACtx.SetBytes(RAW_PIXELS * 4);
  RasterFillSolid(@GRaw[0], RAW_PIXELS, 200, 100, 50, 255);
  BenchBlackBoxBytes(GRaw[0], SizeOf(GRaw));
end;

procedure BenchRawFillSolid512(const ACtx: IBenchContext);
begin
  ACtx.SetBytes(RAW_512 * 4);
  RasterFillSolid(@GRawBig[0], RAW_512, 200, 100, 50, 255);
  BenchBlackBoxBytes(GRawBig[0], RAW_512 * 4);
end;

procedure BenchRawFillSolid4K(const ACtx: IBenchContext);
begin
  ACtx.SetBytes(RAW_4K * 4);
  RasterFillSolid(@GRawBig[0], RAW_4K, 200, 100, 50, 255);
  BenchBlackBoxBytes(GRawBig[0], RAW_4K * 4);
end;

procedure BenchRawBlendSrcOver(const ACtx: IBenchContext);
begin
  ACtx.SetBytes(RAW_PIXELS * 4);
  RasterBlendSrcOver(@GRaw[0], RAW_PIXELS, 200, 100, 50, 128);
  BenchBlackBoxBytes(GRaw[0], SizeOf(GRaw));
end;

procedure BenchRawBlend512(const ACtx: IBenchContext);
begin
  ACtx.SetBytes(RAW_512 * 4);
  RasterBlendSrcOver(@GRawBig[0], RAW_512, 200, 100, 50, 128);
  BenchBlackBoxBytes(GRawBig[0], RAW_512 * 4);
end;

procedure BenchRawBlend4K(const ACtx: IBenchContext);
begin
  ACtx.SetBytes(RAW_4K * 4);
  RasterBlendSrcOver(@GRawBig[0], RAW_4K, 200, 100, 50, 128);
  BenchBlackBoxBytes(GRawBig[0], RAW_4K * 4);
end;

function IsVerifyMode: Boolean; inline;
var I: Integer;
begin
  Result := False;
  for I:=1 to ParamCount do
    if ParamStr(I)='--verify' then Exit(True);
end;

function CheckGate(const ARes: IBenchResults): Boolean;
var R: TBenchResult; Passed: Boolean;
begin
  Result := True;
  if ARes.TryGetByName('FillPath opaque 100x100', R) then
  begin
    Passed := R.NsPerOp < GATE_NS_100;
    if Passed then
      WriteLn('Gate FillPath 100x100 ', R.NsPerOp:0:1, ' ns/op < ', GATE_NS_100:0:1, ' PASS (tile 16 + SSE2 batch 4/8)')
    else
      WriteLn('Gate FillPath 100x100 ', R.NsPerOp:0:1, ' ns/op >= ', GATE_NS_100:0:1, ' FAIL (tile 16 + SSE2 batch 4/8)');
    Result := Passed;
  end;
end;

function VerifyTable(const ARes: IBenchResults): Boolean; inline;
var R: TBenchResult;
  Ok: Boolean;
begin
  Result := True;
  // single invocation no inner loop, framework calibrates; BytesPerOp = W*H*4 must be present for MB/s
  Ok := ARes.TryGetByName('FillPath opaque 100x100', R);
  if not Ok or (R.NsPerOp <= 0) or (R.BytesPerOp <> W100*H100*4) then
  begin
    WriteLn('Verify FillPath 100x100 ns/op+MB/s 1MB single FAIL (ns=',R.NsPerOp:0:1,' bytes=',R.BytesPerOp,')');
    Result := False;
  end;
  Ok := ARes.TryGetByName('RasterFillSolid 1K px', R);
  if not Ok or (R.NsPerOp <= 0) or (R.BytesPerOp <> RAW_PIXELS*4) then
  begin
    WriteLn('Verify RasterFillSolid 1K px ns/op+MB/s single FAIL');
    Result := False;
  end;
  Ok := ARes.TryGetByName('RasterBlendSrcOver 1K px', R);
  if not Ok or (R.NsPerOp <= 0) or (R.BytesPerOp <> RAW_PIXELS*4) then
  begin
    WriteLn('Verify RasterBlendSrcOver 1K px ns/op+MB/s single FAIL');
    Result := False;
  end;
  if Result then
    WriteLn('Verify CONTRACT 0.2.1 bench_raster single ns/op+MB/s PASS (Go1.22/tiny-skia0.11 locked)');
end;

var
  Suite: IBenchSuite;
  Res: IBenchResults;
  VerifyMode: Boolean;
  GateOk, TableOk: Boolean;
begin
  VerifyMode := IsVerifyMode;
  if VerifyMode then WriteLn('bench_raster --verify CONTRACT 0.2.1 single ns/op+MB/s Go1.22/tiny-skia0.11');
  Suite := TBenchSuite.Create('canvas.raster');
  Suite.SetQuiet(True);
  Suite.SetMinDuration(TDuration.FromMilliseconds(50));
  Suite.SetMinSamples(5);
  Suite.Add('FillPath opaque 100x100', @BenchFillPathOpaque);
  Suite.Add('FillPath opaque 512x512', @BenchFillPathOpaque512);
  Suite.Add('FillPath opaque 1024x1024', @BenchFillPathOpaque1K);
  Suite.Add('FillPath opaque 4096x1024', @BenchFillPathOpaque4K);
  Suite.Add('FillPath blend 100x100', @BenchFillPathBlend);
  Suite.Add('FillPath blend 512x512', @BenchFillPathBlend512);
  Suite.Add('StrokePath 100x100', @BenchStroke);
  Suite.Add('StrokePath 512x512', @BenchStroke512);
  Suite.Add('RasterFillSolid 512 px', @BenchRawFillSolid512);
  Suite.Add('RasterFillSolid 1K px', @BenchRawFillSolid);
  Suite.Add('RasterFillSolid 4K px', @BenchRawFillSolid4K);
  Suite.Add('RasterBlendSrcOver 512 px', @BenchRawBlend512);
  Suite.Add('RasterBlendSrcOver 1K px', @BenchRawBlendSrcOver);
  Suite.Add('RasterBlendSrcOver 4K px', @BenchRawBlend4K);
  Res := Suite.Run;
  WriteLn(Res.PrintToConsole);
  WriteLn(Res.ToSummary);
  WriteLn(Res.ToBenchstat);
  WriteLn(Res.ToJSON);
  ForceDirectories('build');
  Res.SaveToJSON('build/bench-raster.json');
  Res.SaveToHTML('build/bench-raster.html');
  WriteLn(Res.ToHTML);
  WriteLn('HTML report: build/bench-raster.html (incl SVG charts)');
  WriteLn('JSON report: build/bench-raster.json');
  GateOk := CheckGate(Res);
  TableOk := VerifyTable(Res);
  if VerifyMode then
  begin
    if GateOk and TableOk then
    begin
      WriteLn('--verify PASS');
      Halt(0);
    end else
    begin
      WriteLn('--verify FAIL');
      Halt(1);
    end;
  end else if not GateOk then Halt(1);
end.
