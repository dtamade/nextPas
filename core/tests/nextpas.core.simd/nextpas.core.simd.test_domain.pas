program nextpas.core.simd.test_domain;

{$mode objfpc}{$H+}
{$I ../../src/nextpas.core.settings.inc}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Math,
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

procedure Check(const aName: string; aExpected, aActual: Double; aTol: Double = 1e-4);
begin
  Inc(g_Checks);
  if System.Abs(aExpected - aActual) > aTol * Max(System.Abs(aExpected), 1e-7) then
  begin
    WriteLn('[FAIL] ', aName, ': expected ', aExpected:0:6, ' got ', aActual:0:6);
    Inc(g_Fails);
  end;
end;

procedure CheckBool(const aName: string; aExpected: Boolean);
begin
  Inc(g_Checks);
  if not aExpected then
  begin
    WriteLn('[FAIL] ', aName);
    Inc(g_Fails);
  end;
end;

procedure TestStats;
var
  X, Y, W: array[0..99] of Single;
  i: Integer;
  LOnline: TSimdF32OnlineStats;
begin
  for i := 0 to 99 do
  begin
    X[i] := i;
    Y[i] := 2 * i + 1;
    W[i] := 1.0;
  end;

  Check('WeightedSum', 4950, WeightedSumF32(@X[0], @W[0], 100));
  Check('WeightedMean', 49.5, WeightedMeanF32(@X[0], @W[0], 100));
  Check('Variance', 841.667, VarianceF32(@X[0], 100), 1e-2);
  Check('StdDev', 29.011, StdDevF32(@X[0], 100), 1e-2);
  Check('Correlation(X,Y)', 1.0, CorrelationF32(@X[0], @Y[0], 100), 1e-3);

  // Online stats
  LOnline.Clear;
  LOnline.AddBatch(@X[0], 100);
  Check('Online.Mean', 49.5, LOnline.GetMean, 1e-3);
  Check('Online.Variance', 841.667, LOnline.GetVariance, 1e-1);

  WriteLn('  stats: OK');
end;

procedure TestNN;
var
  Src, Dst: array[0..9] of Single;
  LSum: Single;
  i: Integer;
begin
  // Sigmoid
  for i := 0 to 9 do Src[i] := i - 5;
  SigmoidF32(@Src[0], @Dst[0], 10);
  Check('Sigmoid(0)', 0.5, Dst[5], 1e-3);
  CheckBool('Sigmoid(-5)<0.01', Dst[0] < 0.01);
  CheckBool('Sigmoid(4)>0.98', Dst[9] > 0.98);

  // Softmax
  for i := 0 to 9 do Src[i] := i;
  SoftmaxF32(@Src[0], @Dst[0], 10);
  LSum := 0;
  for i := 0 to 9 do LSum := LSum + Dst[i];
  Check('Softmax sum=1', 1.0, LSum, 1e-4);
  CheckBool('Softmax monotone', Dst[9] > Dst[8]);
  CheckBool('Softmax positive', Dst[0] > 0);

  // LayerNorm
  for i := 0 to 9 do Src[i] := i * 2;
  LayerNormF32(@Src[0], nil, nil, @Dst[0], 10);
  LSum := 0;
  for i := 0 to 9 do LSum := LSum + Dst[i];
  Check('LayerNorm mean~0', 0, LSum, 0.1);

  WriteLn('  nn: OK');
end;

procedure TestLinalg;
var
  A: TSimdF32Matrix;
  X, Y: TSimdF32Array;
  i: Integer;
begin
  // 3x3 identity * vector = vector
  A := TSimdF32Matrix.Identity(3);
  X := TSimdF32Array.Create(3);
  X.Data[0] := 1; X.Data[1] := 2; X.Data[2] := 3;

  Y := MatVecMulF32(A, X);
  Check('Identity*[1,2,3][0]', 1, Y.Data[0]);
  Check('Identity*[1,2,3][1]', 2, Y.Data[1]);
  Check('Identity*[1,2,3][2]', 3, Y.Data[2]);
  Y.Free;

  // 2x3 matrix * 3-vector
  A.Free;
  A := TSimdF32Matrix.Create(2, 3);
  A.Put(0, 0, 1); A.Put(0, 1, 2); A.Put(0, 2, 3);
  A.Put(1, 0, 4); A.Put(1, 1, 5); A.Put(1, 2, 6);

  Y := MatVecMulF32(A, X);
  Check('A*x[0]', 14, Y.Data[0]);  // 1*1+2*2+3*3=14
  Check('A*x[1]', 32, Y.Data[1]);  // 4*1+5*2+6*3=32
  Y.Free;

  // Row/Col access
  Check('A.Row(0).Sum', 6, A.Row(0).Sum);
  Check('A.Col(0).Sum', 5, A.Col(0).Sum);

  A.Free; X.Free;
  WriteLn('  linalg: OK');
end;

procedure TestSignal;
var
  Data: array[0..7] of TSimdComplexF32;
  Win: array[0..63] of Single;
  i: Integer;
begin
  // FFT of impulse: should give all 1s
  for i := 0 to 7 do begin Data[i].Re := 0; Data[i].Im := 0; end;
  Data[0].Re := 1;

  FftRadix2F32(@Data[0], 8, sfdForward);
  for i := 0 to 7 do
    Check(Format('FFT impulse[%d].Re', [i]), 1.0, Data[i].Re, 1e-4);

  // Inverse should recover impulse
  FftRadix2F32(@Data[0], 8, sfdInverse);
  Check('IFFT[0]', 1.0, Data[0].Re, 1e-4);
  Check('IFFT[1]', 0.0, Data[1].Re, 1e-4);

  // Window functions
  HannWindowF32(@Win[0], 64);
  Check('Hann[0]', 0, Win[0], 1e-4);
  Check('Hann[32]~1', 1.0, Win[32], 0.02);

  WriteLn('  signal: OK');
end;

procedure TestImage;
var
  Src, Dst: TSimdImage;
  x, y: Integer;
begin
  Src := TSimdImage.Create(4, 4, spfRGBA32);
  Dst := TSimdImage.Create(4, 4, spfGray8);

  // Fill with white (255,255,255,255)
  for y := 0 to 3 do
    for x := 0 to 3 do
    begin
      Src.PixelPtr(x, y)[0] := 255;
      Src.PixelPtr(x, y)[1] := 255;
      Src.PixelPtr(x, y)[2] := 255;
      Src.PixelPtr(x, y)[3] := 255;
    end;

  RgbaToGray(Src, Dst);
  Check('White→Gray', 255, Dst.PixelPtr(0, 0)[0]);

  // Fill with red (255,0,0)
  for y := 0 to 3 do
    for x := 0 to 3 do
    begin
      Src.PixelPtr(x, y)[0] := 255;
      Src.PixelPtr(x, y)[1] := 0;
      Src.PixelPtr(x, y)[2] := 0;
    end;

  RgbaToGray(Src, Dst);
  Check('Red→Gray~76', 76, Dst.PixelPtr(0, 0)[0], 2);

  Src.Free; Dst.Free;
  WriteLn('  image: OK');
end;

begin
  WriteLn('[Domain Module Tests]');
  WriteLn('Backend: ', GetBackendInfo(GetActiveBackend).Name);
  WriteLn('');

  TestStats;
  TestNN;
  TestLinalg;
  TestSignal;
  TestImage;

  WriteLn('');
  WriteLn(Format('[SUMMARY] checks=%d failures=%d', [g_Checks, g_Fails]));
  if g_Fails > 0 then
  begin
    WriteLn('[RESULT] FAIL');
    Halt(1);
  end;
  WriteLn('[RESULT] PASS');
end.
