program nextpas.core.simd.test_domain_full;

{$I ../../src/nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Math,
  nextpas.core.simd,
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.alloc,
  nextpas.core.simd.arrays.typed,
  nextpas.core.simd.stats,
  nextpas.core.simd.nn,
  nextpas.core.simd.linalg,
  nextpas.core.simd.signal,
  nextpas.core.simd.image;

var
  g_Checks: Integer = 0;
  g_Fails: Integer = 0;

procedure Check(const aName: string; aExpected, aActual: Double; aTol: Double = 1e-3);
begin
  Inc(g_Checks);
  if System.Abs(aExpected - aActual) > aTol * Max(System.Abs(aExpected), 1e-6) then
  begin
    WriteLn('[FAIL] ', aName, ': expected ', aExpected:0:6, ' got ', aActual:0:6);
    Inc(g_Fails);
  end;
end;

procedure CheckBool(const aName: string; aOK: Boolean);
begin
  Inc(g_Checks);
  if not aOK then begin WriteLn('[FAIL] ', aName); Inc(g_Fails); end;
end;

{ === STATS MODULE === }
procedure TestStats;
var
  X, Y, Dst: array[0..99] of Single;
  W: array[0..3] of Single;
  Bins: array[0..9] of Single;
  Counts: array[0..9] of Int32;
  i: Integer;
  LOnline: TSimdF32OnlineStats;
  LOnline2: TSimdF32OnlineStats;
begin
  for i := 0 to 99 do X[i] := i;
  for i := 0 to 99 do Y[i] := 100 - i;

  // WeightedSum: [0,1,2,3] dot [1,1,1,1] = 6
  W[0] := 1; W[1] := 1; W[2] := 1; W[3] := 1;
  Check('WeightedSum', 6, WeightedSumF32(@X[0], @W[0], 4));

  // WeightedMean: [1,2,3,4] dot [1,2,1,2] / (1+2+1+2) = (1+4+3+8)/6
  W[0] := 1; W[1] := 2; W[2] := 1; W[3] := 2;
  Check('WeightedMean', (1+4+3+8)/6, WeightedMeanF32(@X[1], @W[0], 4), 0.01);

  // Variance & StdDev
  Check('Variance', 833.25, VarianceF32(@X[0], 100, False), 1);
  Check('StdDev', System.Sqrt(833.25), StdDevF32(@X[0], 100, False), 0.1);

  // Covariance & Correlation
  CheckBool('Covariance<0', CovarianceF32(@X[0], @Y[0], 100, False) < 0);
  Check('Correlation', -1, CorrelationF32(@X[0], @Y[0], 100), 0.01);

  // OnlineStats (Welford)
  LOnline.Clear;
  CheckBool('Online count=0', LOnline.Count = 0);
  LOnline.Add(2); LOnline.Add(4); LOnline.Add(6);
  Check('Online mean', 4, LOnline.GetMean);
  Check('Online var', 4, LOnline.GetVariance);
  Check('Online stddev', 2, LOnline.GetStdDev);
  LOnline.Clear;
  LOnline.AddBatch(@X[0], 100);
  CheckBool('Online batch count=100', LOnline.Count = 100);
  Check('Online batch mean', 49.5, LOnline.GetMean, 0.01);

  // OnlineStats Merge
  LOnline.Clear; LOnline2.Clear;
  LOnline.AddBatch(@X[0], 50);
  LOnline2.AddBatch(@X[50], 50);
  LOnline.Merge(LOnline2);
  CheckBool('Merge count=100', LOnline.Count = 100);
  Check('Merge mean', 49.5, LOnline.GetMean, 0.01);

  // Median & Percentile
  Check('Median', 49.5, MedianF32(@X[0], 100));
  Check('Percentile(25)', 24.75, PercentileF32(@X[0], 100, 25), 1e-2);
  Check('Percentile(75)', 74.25, PercentileF32(@X[0], 100, 75), 1e-2);

  // Histogram
  HistogramF32(@X[0], 100, @Bins[0], @Counts[0], 10, 0, 100);
  Check('Histogram bin0', 10, Counts[0]);
  Check('Histogram bin9', 10, Counts[9]);

  // MovingAverage & EMA
  MovingAverageF32(@X[0], @Dst[0], 100, 5);
  Check('MA[4]', 2, Dst[4], 0.1);
  ExponentialMovingAverageF32(@X[0], @Dst[0], 100, 0.5);
  Check('EMA[0]', 0, Dst[0]);
  CheckBool('EMA monotone', Dst[99] > Dst[50]);

  // MinMaxNormalize & ZScoreNormalize
  MinMaxNormalizeF32(@X[0], @Dst[0], 100);
  Check('MinMax[0]', 0, Dst[0]);
  Check('MinMax[99]', 1, Dst[99]);
  ZScoreNormalizeF32(@X[0], @Dst[0], 100);
  Check('ZScore mean~0', 0, ReduceSumF32(@Dst[0], 100) / 100, 0.1);

  WriteLn('  stats: OK (19/19 APIs)');
end;

{ === NN MODULE === }
procedure TestNN;
var
  Src, Dst: array[0..15] of Single;
  Weight, Bias, Output: array[0..15] of Single;
  Kernel: array[0..2] of Single;
  Signal, Conv: array[0..9] of Single;
  Grad: array[0..9] of Single;
  Mean, Variance, Gamma, Beta: array[0..3] of Single;
  i: Integer;
  LNorm, LSum: Single;
begin
  // Sigmoid: sigmoid(0)=0.5, sigmoid(large)→1, sigmoid(-large)→0
  Src[0] := 0; Src[1] := 10; Src[2] := -10; Src[3] := 1;
  SigmoidF32(@Src[0], @Dst[0], 4);
  Check('Sigmoid(0)', 0.5, Dst[0]);
  CheckBool('Sigmoid(10)>0.99', Dst[1] > 0.99);
  CheckBool('Sigmoid(-10)<0.01', Dst[2] < 0.01);

  // Softmax: output sums to 1
  Src[0] := 1; Src[1] := 2; Src[2] := 3; Src[3] := 4;
  SoftmaxF32(@Src[0], @Dst[0], 4);
  LSum := Dst[0] + Dst[1] + Dst[2] + Dst[3];
  Check('Softmax sum=1', 1.0, LSum, 0.01);
  CheckBool('Softmax monotone', (Dst[3] > Dst[2]) and (Dst[2] > Dst[1]));

  // LayerNorm: normalized output should have mean≈0
  Src[0] := 1; Src[1] := 2; Src[2] := 3; Src[3] := 4;
  Gamma[0] := 1; Gamma[1] := 1; Gamma[2] := 1; Gamma[3] := 1;
  Beta[0] := 0; Beta[1] := 0; Beta[2] := 0; Beta[3] := 0;
  LayerNormF32(@Src[0], @Gamma[0], @Beta[0], @Dst[0], 4);
  LSum := (Dst[0] + Dst[1] + Dst[2] + Dst[3]) / 4;
  Check('LayerNorm mean~0', 0, LSum, 0.01);

  // SiLU: SiLU(0)=0, SiLU(x)≈x for large x
  Src[0] := 0; Src[1] := 5; Src[2] := -5; Src[3] := 1;
  SiLUF32(@Src[0], @Dst[0], 4);
  Check('SiLU(0)', 0, Dst[0]);
  CheckBool('SiLU(5)>4.9', Dst[1] > 4.9);
  CheckBool('SiLU(-5)~0', System.Abs(Dst[2]) < 0.1);

  // GELU: GELU(0)=0
  Src[0] := 0; Src[1] := 3; Src[2] := -3; Src[3] := 1;
  GeluApproxF32(@Src[0], @Dst[0], 4);
  Check('GELU(0)', 0, Dst[0]);
  CheckBool('GELU(3)>2.9', Dst[1] > 2.9);

  // BatchNorm
  Src[0] := 10; Src[1] := 20; Src[2] := 30; Src[3] := 40;
  Mean[0] := 20; Mean[1] := 30;
  Variance[0] := 100; Variance[1] := 100;
  Gamma[0] := 1; Gamma[1] := 1;
  Beta[0] := 0; Beta[1] := 0;
  BatchNormF32(@Src[0], 2, 2, @Mean[0], @Variance[0], @Gamma[0], @Beta[0], 1e-5, @Dst[0]);
  Check('BatchNorm[0]', (10-20)/10, Dst[0], 0.01);
  Check('BatchNorm[1]', (20-30)/10, Dst[1], 0.01);

  // LinearLayer
  for i := 0 to 3 do Src[i] := i + 1;
  FillChar(Weight, SizeOf(Weight), 0);
  Weight[0] := 1; Weight[7] := 1;
  Bias[0] := 10; Bias[1] := 20;
  LinearLayerF32(@Src[0], @Weight[0], @Bias[0], @Output[0], 1, 4, 2);
  Check('Linear[0]', 11, Output[0]);
  Check('Linear[1]', 24, Output[1]);

  // Conv1D
  for i := 0 to 9 do Signal[i] := 1;
  Kernel[0] := 1; Kernel[1] := 1; Kernel[2] := 1;
  Conv1DF32(@Signal[0], @Kernel[0], @Conv[0], 10, 3, 8);
  Check('Conv1D[2]', 3, Conv[2]);

  // Dropout: with rate=0, output=input
  for i := 0 to 9 do Src[i] := 5;
  DropoutF32(@Src[0], @Dst[0], 10, 0.0, 12345);
  Check('Dropout(rate=0)', 5, Dst[0]);

  // Dropout: with rate=1, output=all zeros
  DropoutF32(@Src[0], @Dst[0], 10, 1.0, 12345);
  Check('Dropout(rate=1)', 0, Dst[0]);
  Check('Dropout(rate=1)[9]', 0, Dst[9]);

  // ClipGrad
  for i := 0 to 9 do Grad[i] := 10;
  ClipGradF32(@Grad[0], 10, 5.0);
  LNorm := System.Sqrt(ReduceDotF32(@Grad[0], @Grad[0], 10));
  Check('ClipGrad norm', 5.0, LNorm, 0.1);

  // ArrayLinearReLUF32 (fused dispatch slot)
  for i := 0 to 7 do Src[i] := i - 3;
  ArrayLinearReLUF32(@Src[0], @Dst[0], 8, 2.0, -1.0);
  Check('LinearReLU[0] max(2*(-3)-1,0)=0', 0, Dst[0]);
  Check('LinearReLU[3] max(2*0-1,0)=0', 0, Dst[3]);
  Check('LinearReLU[5] max(2*2-1,0)=3', 3, Dst[5]);
  Check('LinearReLU[7] max(2*4-1,0)=7', 7, Dst[7]);

  // HardSigmoid: clamp(x/6 + 0.5, 0, 1)
  Src[0] := 0; Src[1] := 6; Src[2] := -6; Src[3] := 3;
  HardSigmoidF32(@Src[0], @Dst[0], 4);
  Check('HardSigmoid(0)', 0.5, Dst[0], 0.01);
  Check('HardSigmoid(6)', 1.0, Dst[1]);
  Check('HardSigmoid(-6)', 0.0, Dst[2]);
  Check('HardSigmoid(3)', 1.0, Dst[3]);

  // HardSwish: x * HardSigmoid(x)
  Src[0] := 0; Src[1] := 6; Src[2] := -6; Src[3] := 3;
  HardSwishF32(@Src[0], @Dst[0], 4);
  Check('HardSwish(0)', 0, Dst[0]);
  Check('HardSwish(6)', 6, Dst[1]);
  Check('HardSwish(-6)', 0, Dst[2]);
  Check('HardSwish(3)', 3, Dst[3]);

  // ELU: x>=0 → x, x<0 → alpha*(exp(x)-1)
  Src[0] := 0; Src[1] := 2; Src[2] := -1; Src[3] := -3;
  ELUF32(@Src[0], @Dst[0], 4, 1.0);
  Check('ELU(0)', 0, Dst[0]);
  Check('ELU(2)', 2, Dst[1]);
  Check('ELU(-1)', System.Exp(-1.0)-1, Dst[2], 0.01);
  CheckBool('ELU(-3)<0', Dst[3] < 0);
  CheckBool('ELU(-3)>-1', Dst[3] > -1);

  // LogSoftmax: all outputs <= 0, exp(outputs) sums to 1
  Src[0] := 1; Src[1] := 2; Src[2] := 3; Src[3] := 4;
  LogSoftmaxF32(@Src[0], @Dst[0], 4);
  CheckBool('LogSoftmax[0]<=0', Dst[0] <= 0);
  CheckBool('LogSoftmax[3]<=0', Dst[3] <= 0);
  CheckBool('LogSoftmax monotone', Dst[3] > Dst[0]);
  LSum := System.Exp(Dst[0]) + System.Exp(Dst[1]) + System.Exp(Dst[2]) + System.Exp(Dst[3]);
  Check('exp(LogSoftmax) sum=1', 1.0, LSum, 0.01);

  // Softplus: log(1+exp(x)), smooth ReLU
  Src[0] := 0; Src[1] := 10; Src[2] := -10; Src[3] := 1;
  SoftplusF32(@Src[0], @Dst[0], 4);
  Check('Softplus(0)', Ln(2.0), Dst[0], 0.01);
  Check('Softplus(10)~10', 10, Dst[1], 0.01);
  CheckBool('Softplus(-10)~0', Dst[2] < 0.001);
  CheckBool('Softplus(1)>1', Dst[3] > 1);

  // RMSNorm: output should have RMS ≈ 1 (when gamma=1)
  Src[0] := 1; Src[1] := 2; Src[2] := 3; Src[3] := 4;
  Gamma[0] := 1; Gamma[1] := 1; Gamma[2] := 1; Gamma[3] := 1;
  RMSNormF32(@Src[0], @Gamma[0], @Dst[0], 4);
  LNorm := System.Sqrt((Dst[0]*Dst[0] + Dst[1]*Dst[1] + Dst[2]*Dst[2] + Dst[3]*Dst[3]) / 4);
  Check('RMSNorm output RMS~1', 1.0, LNorm, 0.01);

  WriteLn('  nn: OK (17/17 APIs)');
end;

{ === LINALG MODULE === }
procedure TestLinalg;
var
  A, B, C, L, U, Inv: TSimdF32Matrix;
  X, Y, V: TSimdF32Array;
  RowArr, ColArr: TSimdF32Array;
  WrapMat: TSimdF32Matrix;
  RawData: array[0..3] of Single;
  det, trace, frob: Single;
  ok: Boolean;
begin
  A := TSimdF32Matrix.Create(2, 2);
  A.Put(0,0,1); A.Put(0,1,2); A.Put(1,0,3); A.Put(1,1,4);
  B := TSimdF32Matrix.Create(2, 2);
  B.Put(0,0,5); B.Put(0,1,6); B.Put(1,0,7); B.Put(1,1,8);

  // MatMul
  C := MatMulF32(A, B);
  Check('MatMul[0,0]', 19, C.Get(0,0));
  Check('MatMul[1,1]', 50, C.Get(1,1));
  C.Free;

  // MatAdd
  C := MatAddF32(A, B);
  Check('MatAdd[0,0]', 6, C.Get(0,0));
  C.Free;

  // MatScale
  C := MatScaleF32(A, 2.0);
  Check('MatScale[1,1]', 8, C.Get(1,1));
  C.Free;

  // Trace & Frobenius
  trace := MatTraceF32(A);
  Check('Trace', 5, trace);
  frob := MatFrobeniusNormF32(A);
  Check('Frobenius', System.Sqrt(30), frob);

  // Transpose
  C := A.Transpose;
  Check('Transpose[0,1]', 3, C.Get(0,1));
  C.Free;

  // Row & Col
  RowArr := A.Row(0);
  Check('Row[0].Data[0]', 1, RowArr.Data[0]);
  Check('Row[0].Data[1]', 2, RowArr.Data[1]);
  ColArr := A.Col(1);
  Check('Col[1][0]', 2, ColArr.Data[0]);

  // Wrap
  RawData[0] := 10; RawData[1] := 20; RawData[2] := 30; RawData[3] := 40;
  WrapMat := TSimdF32Matrix.Wrap(@RawData[0], 2, 2);
  Check('Wrap[0,0]', 10, WrapMat.Get(0,0));
  Check('Wrap[1,1]', 40, WrapMat.Get(1,1));

  // MatVecMul
  X := TSimdF32Array.Create(2);
  X.Data[0] := 1; X.Data[1] := 2;
  Y := MatVecMulF32(A, X);
  Check('MatVecMul[0]', 5, Y.Data[0]);
  Check('MatVecMul[1]', 11, Y.Data[1]);
  Y.Free; X.Free;

  // GEMV
  X := TSimdF32Array.Create(2);
  X.Data[0] := 1; X.Data[1] := 1;
  Y := TSimdF32Array.Create(2);
  Y.Data[0] := 10; Y.Data[1] := 20;
  GemvF32(2.0, A, X, 1.0, Y);
  Check('GEMV[0]', 16, Y.Data[0]);
  Check('GEMV[1]', 34, Y.Data[1]);
  Y.Free; X.Free;

  // GEMM
  C := TSimdF32Matrix.Zeros(2, 2);
  C.Put(0,0,1); C.Put(1,1,1);
  GemmF32(1.0, A, B, 1.0, C);
  Check('GEMM[0,0]', 20, C.Get(0,0));
  C.Free;

  // LU Decompose
  ok := LUDecomposeF32(A, L, U);
  CheckBool('LU ok', ok);
  Check('L[1,0]', 3, L.Get(1,0));
  Check('U[1,1]', -2, U.Get(1,1));
  L.Free; U.Free;

  // SolveLinear
  A.Put(0,0,2); A.Put(0,1,1); A.Put(1,0,5); A.Put(1,1,7);
  V := TSimdF32Array.Create(2);
  V.Data[0] := 11; V.Data[1] := 13;
  X := SolveLinearF32(A, V);
  Check('Solve[0]', 64/9, X.Data[0], 0.01);
  Check('Solve[1]', -29/9, X.Data[1], 0.01);
  X.Free; V.Free;

  // Determinant
  det := MatDeterminantF32(A);
  Check('Det', 9, det);

  // Inverse
  Inv := MatInverseF32(A);
  Check('Inv[0,0]', 7.0/9, Inv.Get(0,0), 0.01);
  Check('Inv[1,1]', 2.0/9, Inv.Get(1,1), 0.01);
  Inv.Free;

  // Identity
  C := TSimdF32Matrix.Identity(3);
  Check('Identity[1,1]', 1, C.Get(1,1));
  Check('Identity[0,1]', 0, C.Get(0,1));

  // Diag: extract diagonal of Identity → [1,1,1]
  V := C.Diag;
  CheckBool('Diag count=3', V.Count = 3);
  Check('Diag[0]', 1, V.Data[0]);
  Check('Diag[2]', 1, V.Data[2]);
  V.Free;
  C.Free;

  // FromDiag: [2,3,4] → diagonal matrix
  V := TSimdF32Array.Create(3);
  V.Data[0] := 2; V.Data[1] := 3; V.Data[2] := 4;
  C := TSimdF32Matrix.FromDiag(V);
  Check('FromDiag[0,0]', 2, C.Get(0,0));
  Check('FromDiag[1,1]', 3, C.Get(1,1));
  Check('FromDiag[2,2]', 4, C.Get(2,2));
  Check('FromDiag[0,1]', 0, C.Get(0,1));
  C.Free; V.Free;

  A.Free; B.Free;

  // Singular matrix: LU should fail, no leak
  A := TSimdF32Matrix.Create(2, 2);
  A.Put(0,0,1); A.Put(0,1,2); A.Put(1,0,2); A.Put(1,1,4);
  ok := LUDecomposeF32(A, L, U);
  CheckBool('Singular LU fails', not ok);
  det := MatDeterminantF32(A);
  Check('Singular det=0', 0, det);
  A.Free;

  // OuterProduct: [1,2,3] ⊗ [4,5] = [[4,5],[8,10],[12,15]]
  X := TSimdF32Array.Create(3);
  X.Data[0] := 1; X.Data[1] := 2; X.Data[2] := 3;
  Y := TSimdF32Array.Create(2);
  Y.Data[0] := 4; Y.Data[1] := 5;
  C := OuterProductF32(X, Y);
  CheckBool('Outer rows=3', C.Rows = 3);
  CheckBool('Outer cols=2', C.Cols = 2);
  Check('Outer[0,0]', 4, C.Get(0,0));
  Check('Outer[1,1]', 10, C.Get(1,1));
  Check('Outer[2,0]', 12, C.Get(2,0));
  Check('Outer[2,1]', 15, C.Get(2,1));
  C.Free; X.Free; Y.Free;

  WriteLn('  linalg: OK (23/23 APIs + boundary)');
end;

{ === SIGNAL MODULE === }
procedure TestSignal;
var
  Src, Dst: array[0..63] of Single;
  Complex: array[0..63] of TSimdComplexF32;
  XCorr: array[0..31] of Single;
  i: Integer;
begin
  // FftRadix2 (direct)
  for i := 0 to 7 do begin Complex[i].Re := 0; Complex[i].Im := 0; end;
  Complex[0].Re := 1; Complex[1].Re := 1; Complex[2].Re := 1; Complex[3].Re := 1;
  FftRadix2F32(@Complex[0], 8, sfdForward);
  Check('FFT DC', 4, Complex[0].Re);
  CheckBool('FFT non-DC<DC', System.Abs(Complex[1].Re) < 4);

  // RealFft
  for i := 0 to 63 do Src[i] := Sin(2 * Pi * 4 * i / 64);
  RealFftF32(@Src[0], @Complex[0], 64);
  CheckBool('RFFT peak at bin 4', System.Abs(Complex[4].Re) + System.Abs(Complex[4].Im) > 10);

  // Convolve1D (centered convolution, output length = signal length)
  for i := 0 to 9 do Src[i] := 0;
  Src[3] := 1;  // impulse at position 3
  Dst[0] := 1; Dst[1] := 2; Dst[2] := 3;  // kernel, LHalf=1
  Convolve1DF32(@Src[0], 10, @Dst[0], 3, @Src[10]);
  Check('Convolve impulse[3]', 2, Src[10+3]);  // signal[2]*1+signal[3]*2+signal[4]*3=2
  Check('Convolve impulse[4]', 1, Src[10+4]);  // signal[3]*1+signal[4]*2+signal[5]*3=1

  // Window functions
  HannWindowF32(@Dst[0], 64);
  Check('Hann[0]', 0, Dst[0], 0.01);
  CheckBool('Hann[32]>0.9', Dst[32] > 0.9);

  HammingWindowF32(@Dst[0], 64);
  CheckBool('Hamming[0]>0', Dst[0] > 0.05);
  CheckBool('Hamming[32]>0.9', Dst[32] > 0.9);

  BlackmanWindowF32(@Dst[0], 64);
  Check('Blackman[0]~0', 0, Dst[0], 0.01);
  CheckBool('Blackman[32]>0.9', Dst[32] > 0.9);

  // FIR
  for i := 0 to 63 do Src[i] := i;
  Dst[0] := 1.0;
  FirFilterF32(@Src[0], 64, @Dst[0], 1, @Src[0]);
  Check('FIR identity[10]', 10, Src[10]);

  // Resample
  for i := 0 to 9 do Src[i] := i * 10;
  ResampleLinearF32(@Src[0], 10, @Dst[0], 19);
  Check('Resample[0]', 0, Dst[0]);
  Check('Resample[18]', 90, Dst[18]);

  // CrossCorrelation
  for i := 0 to 15 do Src[i] := 0;
  Src[4] := 1;
  for i := 0 to 15 do Dst[i] := 0;
  Dst[4] := 1;
  CrossCorrelationF32(@Src[0], @Dst[0], 16, @XCorr[0], 8);
  Check('XCorr lag=0 peak', 1, XCorr[0]);

  // Energy & RMS
  for i := 0 to 63 do Src[i] := 2;
  Check('Energy', 256, EnergyF32(@Src[0], 64));
  Check('RMS', 2, RmsF32(@Src[0], 64));

  // ZeroCrossingRate: alternating sign → rate = 1.0
  for i := 0 to 63 do if i mod 2 = 0 then Src[i] := 1 else Src[i] := -1;
  Check('ZCR alternating', 1.0, ZeroCrossingRateF32(@Src[0], 64), 0.01);
  // All positive → rate = 0
  for i := 0 to 63 do Src[i] := i + 1;
  Check('ZCR all positive', 0, ZeroCrossingRateF32(@Src[0], 64));

  // PowerSpectrum: |1+0i|² = 1, |3+4i|² = 25
  Complex[0].Re := 1; Complex[0].Im := 0;
  Complex[1].Re := 3; Complex[1].Im := 4;
  PowerSpectrumF32(@Complex[0], 2, @Src[0]);
  Check('PowerSpectrum[0]', 1, Src[0]);
  Check('PowerSpectrum[1]', 25, Src[1]);

  WriteLn('  signal: OK (13/13 APIs)');
end;

{ === IMAGE MODULE === }
procedure TestImage;
var
  Src, Dst, Rgba, Gray: TSimdImage;
  WrapImg: TSimdImage;
  RawBuf: array[0..255] of Byte;
  Kern: array[0..8] of Single;
  x: Integer;
begin
  // Create + properties
  Src := TSimdImage.Create(10, 5, spfGray8);
  CheckBool('Width=10', Src.Width = 10);
  CheckBool('Height=5', Src.Height = 5);
  CheckBool('Format=Gray8', Src.Format = spfGray8);
  CheckBool('StrideBytes>=10', Src.StrideBytes >= 10);
  CheckBool('Data<>nil', Src.Data <> nil);

  // PixelPtr
  Src.RowPtr(0)[3] := 42;
  CheckBool('PixelPtr', Src.PixelPtr(3, 0)^ = 42);

  // Wrap
  FillChar(RawBuf, SizeOf(RawBuf), 128);
  WrapImg := TSimdImage.Wrap(@RawBuf[0], 8, 4, 8, spfGray8);
  Check('Wrap pixel', 128, WrapImg.RowPtr(2)[5]);

  // ThresholdGray
  Dst := TSimdImage.Create(10, 1, spfGray8);
  Src.Free;
  Src := TSimdImage.Create(10, 1, spfGray8);
  for x := 0 to 9 do Src.RowPtr(0)[x] := x * 25;
  ThresholdGray(Src, Dst, 128);
  Check('Threshold[0]', 0, Dst.RowPtr(0)[0]);
  Check('Threshold[9]', 255, Dst.RowPtr(0)[9]);

  // InvertGray
  InvertGray(Src, Dst);
  Check('Invert[0]', 255, Dst.RowPtr(0)[0]);
  Check('Invert[9]', 255 - 225, Dst.RowPtr(0)[9]);

  // FlipHorizontal
  FlipHorizontal(Src);
  Check('FlipH[0]', 225, Src.RowPtr(0)[0]);
  Check('FlipH[9]', 0, Src.RowPtr(0)[9]);

  // FlipVertical
  Src.Free; Dst.Free;
  Src := TSimdImage.Create(4, 3, spfGray8);
  for x := 0 to 3 do Src.RowPtr(0)[x] := 10;
  for x := 0 to 3 do Src.RowPtr(1)[x] := 20;
  for x := 0 to 3 do Src.RowPtr(2)[x] := 30;
  FlipVertical(Src);
  Check('FlipV row0', 30, Src.RowPtr(0)[0]);
  Check('FlipV row2', 10, Src.RowPtr(2)[0]);

  // BrightnessContrast
  Dst := TSimdImage.Create(4, 3, spfGray8);
  for x := 0 to 3 do Src.RowPtr(0)[x] := 128;
  BrightnessContrast(Src, Dst, 10, 1.0);
  Check('Brightness+10', 138, Dst.RowPtr(0)[0]);
  Src.Free; Dst.Free;

  // RgbaToGray
  Rgba := TSimdImage.Create(4, 1, spfRGBA32);
  Gray := TSimdImage.Create(4, 1, spfGray8);
  for x := 0 to 3 do
  begin
    Rgba.RowPtr(0)[x*4+0] := 255;  // R
    Rgba.RowPtr(0)[x*4+1] := 0;    // G
    Rgba.RowPtr(0)[x*4+2] := 0;    // B
    Rgba.RowPtr(0)[x*4+3] := 255;  // A
  end;
  RgbaToGray(Rgba, Gray);
  CheckBool('RgbaToGray red', Gray.RowPtr(0)[0] > 70);  // 0.299*255≈76

  // GrayToRgba
  for x := 0 to 3 do Gray.RowPtr(0)[x] := 100;
  GrayToRgba(Gray, Rgba);
  Check('GrayToRgba R', 100, Rgba.RowPtr(0)[0]);
  Check('GrayToRgba A', 255, Rgba.RowPtr(0)[3]);
  Rgba.Free; Gray.Free;

  // Convolve3x3 (identity kernel)
  Src := TSimdImage.Create(5, 5, spfGray8);
  Dst := TSimdImage.Create(5, 5, spfGray8);
  FillChar(Src.Data^, 5 * Src.StrideBytes, 0);
  Src.RowPtr(2)[2] := 100;
  for x := 0 to 8 do Kern[x] := 0;
  Kern[4] := 1.0;  // center = 1, identity kernel
  Convolve3x3(Src, Dst, @Kern[0]);
  Check('Conv3x3 center', 100, Dst.RowPtr(2)[2]);
  Check('Conv3x3 edge', 0, Dst.RowPtr(0)[0]);
  Src.Free; Dst.Free;

  // ResizeBilinear
  Src := TSimdImage.Create(4, 4, spfGray8);
  for x := 0 to 3 do Src.RowPtr(0)[x] := 0;
  for x := 0 to 3 do Src.RowPtr(3)[x] := 255;
  Src.RowPtr(1)[0] := 85; Src.RowPtr(1)[1] := 85;
  Src.RowPtr(1)[2] := 85; Src.RowPtr(1)[3] := 85;
  Src.RowPtr(2)[0] := 170; Src.RowPtr(2)[1] := 170;
  Src.RowPtr(2)[2] := 170; Src.RowPtr(2)[3] := 170;
  Dst := TSimdImage.Create(8, 8, spfGray8);
  ResizeBilinear(Src, Dst);
  Check('Resize[0,0]', 0, Dst.RowPtr(0)[0]);
  CheckBool('Resize[7,7]>200', Dst.RowPtr(7)[7] > 200);
  Src.Free; Dst.Free;

  WriteLn('  image: OK (19/19 APIs)');
end;

begin
  WriteLn('[Domain Module Full Tests — 100% API Coverage]');
  WriteLn('Backend: ', GetBackendInfo(GetActiveBackend).Name);
  WriteLn('');

  TestStats;
  TestNN;
  TestLinalg;
  TestSignal;
  TestImage;

  WriteLn('');
  WriteLn('[SUMMARY] checks=', g_Checks, ' failures=', g_Fails);
  if g_Fails > 0 then
  begin
    WriteLn('[RESULT] FAIL');
    Halt(1);
  end;
  WriteLn('[RESULT] PASS');
end.
