program nn_bench;
{$I nextpas.core.settings.inc}{$Q-}{$R-}
uses nextpas.core.bench, nextpas.core.bench.intf,
  nextpas.core.simd.nn, nextpas.core.simd.dispatch, nextpas.core.simd.types;
const N = 64; C = 32; H = 32; W = 32;
var GInput, GOutput, GKernel: array of Single;
procedure InitData;
var LI: Integer;
begin
  SetLength(GInput, N * C * H * W); SetLength(GOutput, N * C * H * W); SetLength(GKernel, 9);
  for LI := 0 to N * C * H * W - 1 do GInput[LI] := LI * 0.001;
  for LI := 0 to 8 do GKernel[LI] := 0.111;
end;
procedure BenchConv2DScalar(const ACtx: IBenchContext);
begin Conv2DScalar(@GInput[0], @GKernel[0], @GOutput[0], N, C, H, W, 3); ACtx.SetBytes(N * C * H * W * 4 * 2); end;
procedure BenchConv2DAVX2(const ACtx: IBenchContext);
begin if not CpuHasAVX2 then begin ACtx.Skip; Exit; end; Conv2DAVX2(@GInput[0], @GKernel[0], @GOutput[0], N, C, H, W, 3); ACtx.SetBytes(N * C * H * W * 4 * 2); end;
procedure BenchMaxPool2DScalar(const ACtx: IBenchContext);
begin MaxPool2DScalar(@GInput[0], @GOutput[0], N, C, H, W, 2); ACtx.SetBytes(N * C * H * W * 4); end;
procedure BenchMaxPool2DAVX2(const ACtx: IBenchContext);
begin if not CpuHasAVX2 then begin ACtx.Skip; Exit; end; MaxPool2DAVX2(@GInput[0], @GOutput[0], N, C, H, W, 2); ACtx.SetBytes(N * C * H * W * 4); end;
procedure BenchBatchNorm2DScalar(const ACtx: IBenchContext);
var LGamma, LBeta, LMean, LVar: array of Single;
begin
  SetLength(LGamma, C); SetLength(LBeta, C); SetLength(LMean, C); SetLength(LVar, C);
  BatchNorm2DScalar(@GInput[0], @GOutput[0], @LGamma[0], @LBeta[0], @LMean[0], @LVar[0], N, C, H, W, 1e-5);
  ACtx.SetBytes(N * C * H * W * 4);
end;
procedure BenchBatchNorm2DAVX2(const ACtx: IBenchContext);
var LGamma, LBeta, LMean, LVar: array of Single;
begin
  if not CpuHasAVX2 then begin ACtx.Skip; Exit; end;
  SetLength(LGamma, C); SetLength(LBeta, C); SetLength(LMean, C); SetLength(LVar, C);
  BatchNorm2DAVX2(@GInput[0], @GOutput[0], @LGamma[0], @LBeta[0], @LMean[0], @LVar[0], N, C, H, W, 1e-5);
  ACtx.SetBytes(N * C * H * W * 4);
end;
procedure BenchSigmoidScalar(const ACtx: IBenchContext);
begin SigmoidScalar(@GInput[0], @GOutput[0], N * C * H * W); ACtx.SetBytes(N * C * H * W * 4); end;
procedure BenchSigmoidAVX2(const ACtx: IBenchContext);
begin if not CpuHasAVX2 then begin ACtx.Skip; Exit; end; SigmoidAVX2(@GInput[0], @GOutput[0], N * C * H * W); ACtx.SetBytes(N * C * H * W * 4); end;
procedure BenchSoftmaxScalar(const ACtx: IBenchContext);
begin SoftmaxScalar(@GInput[0], @GOutput[0], N * C); ACtx.SetBytes(N * C * 4); end;
procedure BenchSoftmaxAVX2(const ACtx: IBenchContext);
begin if not CpuHasAVX2 then begin ACtx.Skip; Exit; end; SoftmaxAVX2(@GInput[0], @GOutput[0], N * C); ACtx.SetBytes(N * C * 4); end;
procedure BenchResidualAddScalar(const ACtx: IBenchContext);
begin ResidualAddScalar(@GInput[0], @GOutput[0], @GInput[0], N * C * H * W); ACtx.SetBytes(N * C * H * W * 4 * 3); end;
procedure BenchResidualAddAVX2(const ACtx: IBenchContext);
begin if not CpuHasAVX2 then begin ACtx.Skip; Exit; end; ResidualAddAVX2(@GInput[0], @GOutput[0], @GInput[0], N * C * H * W); ACtx.SetBytes(N * C * H * W * 4 * 3); end;
var LSuite: IBenchSuite;
begin
  InitData;
  LSuite := TBenchSuite.Create('nn');
  LSuite.Add('Conv2D/Scalar', @BenchConv2DScalar).Add('Conv2D/AVX2', @BenchConv2DAVX2)
    .Add('MaxPool2D/Scalar', @BenchMaxPool2DScalar).Add('MaxPool2D/AVX2', @BenchMaxPool2DAVX2)
    .Add('BatchNorm2D/Scalar', @BenchBatchNorm2DScalar).Add('BatchNorm2D/AVX2', @BenchBatchNorm2DAVX2)
    .Add('Sigmoid/Scalar', @BenchSigmoidScalar).Add('Sigmoid/AVX2', @BenchSigmoidAVX2)
    .Add('Softmax/Scalar', @BenchSoftmaxScalar).Add('Softmax/AVX2', @BenchSoftmaxAVX2)
    .Add('ResidualAdd/Scalar', @BenchResidualAddScalar).Add('ResidualAdd/AVX2', @BenchResidualAddAVX2);
  WriteLn(LSuite.Run.PrintToConsole);
end.
