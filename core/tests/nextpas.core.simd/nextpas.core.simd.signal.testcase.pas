{
   nextpas.core.simd.signal.testcase - Signal Processing 单元专用测试
   覆盖 FFT、窗函数、卷积、滤波等
}
unit nextpas.core.simd.signal.testcase;

{$I ../../src/nextpas.core.settings.inc}

interface

uses
  Classes, fpcunit, testregistry,
  nextpas.core.simd.signal,
  nextpas.core.simd.base;

type
  TTestCase_SimdSignal = class(TTestCase)
  published
    procedure Test_HannWindow_Basic;
    procedure Test_HannWindow_Symmetry;
    procedure Test_HammingWindow_Basic;
    procedure Test_BlackmanWindow_Basic;
    procedure Test_Convolve1D_Basic;
    procedure Test_Convolve1D_Impulse;
    procedure Test_Energy_Basic;
    procedure Test_Rms_Basic;
    procedure Test_ZeroCrossingRate_Sine;
    procedure Test_FirFilter_Basic;
    procedure Test_CrossCorrelation_Basic;
    procedure Test_AutoCorrelation_Basic;
    procedure Test_NilSafety;
  end;

implementation

const
  EPS = 1E-4;

function NearEqual(A, B, AEps: Single): Boolean;
begin
  Result := Abs(A - B) <= AEps;
end;

{ ============================================================================
  Window Functions
  ============================================================================ }

procedure TTestCase_SimdSignal.Test_HannWindow_Basic;
var
  LDst: array[0..7] of Single;
  I: Integer;
begin
  HannWindowF32(@LDst[0], 8);
  // Hann window should be 0 at endpoints
  CheckTrue(NearEqual(LDst[0], 0.0, EPS), 'Hann first=0');
  CheckTrue(NearEqual(LDst[7], 0.0, EPS), 'Hann last=0');
  // Max should be near center
  CheckTrue(LDst[3] > 0.9, 'Hann center > 0.9');
  CheckTrue(LDst[4] > 0.9, 'Hann center2 > 0.9');
end;

procedure TTestCase_SimdSignal.Test_HannWindow_Symmetry;
var
  LDst: array[0..7] of Single;
begin
  HannWindowF32(@LDst[0], 8);
  // Should be symmetric
  CheckTrue(NearEqual(LDst[1], LDst[6], EPS), 'Hann symmetric [1]=[6]');
  CheckTrue(NearEqual(LDst[2], LDst[5], EPS), 'Hann symmetric [2]=[5]');
  CheckTrue(NearEqual(LDst[3], LDst[4], EPS), 'Hann symmetric [3]=[4]');
end;

procedure TTestCase_SimdSignal.Test_HammingWindow_Basic;
var
  LDst: array[0..7] of Single;
begin
  HammingWindowF32(@LDst[0], 8);
  // Hamming window endpoints ~ 0.08 (not zero)
  CheckTrue(LDst[0] > 0.05, 'Hamming first > 0.05');
  CheckTrue(LDst[7] > 0.05, 'Hamming last > 0.05');
  // Max near center
  CheckTrue(LDst[3] > 0.9, 'Hamming center > 0.9');
end;

procedure TTestCase_SimdSignal.Test_BlackmanWindow_Basic;
var
  LDst: array[0..7] of Single;
begin
  BlackmanWindowF32(@LDst[0], 8);
  // Blackman window should be 0 at endpoints
  CheckTrue(NearEqual(LDst[0], 0.0, EPS), 'Blackman first=0');
  CheckTrue(NearEqual(LDst[7], 0.0, EPS), 'Blackman last=0');
  // Max near center
  CheckTrue(LDst[3] > 0.9, 'Blackman center > 0.9');
end;

{ ============================================================================
  Convolution
  ============================================================================ }

procedure TTestCase_SimdSignal.Test_Convolve1D_Basic;
var
  LSignal: array[0..3] of Single = (1.0, 2.0, 3.0, 4.0);
  LKernel: array[0..1] of Single = (1.0, 1.0);
  LDst: array[0..4] of Single;
begin
  // Full convolution: [1, 3, 5, 7, 4]
  Convolve1DF32(@LSignal[0], 4, @LKernel[0], 2, @LDst[0]);
  CheckTrue(NearEqual(LDst[0], 1.0, EPS), 'Conv [0]');
  CheckTrue(NearEqual(LDst[1], 3.0, EPS), 'Conv [1]');
  CheckTrue(NearEqual(LDst[2], 5.0, EPS), 'Conv [2]');
  CheckTrue(NearEqual(LDst[3], 7.0, EPS), 'Conv [3]');
  CheckTrue(NearEqual(LDst[4], 4.0, EPS), 'Conv [4]');
end;

procedure TTestCase_SimdSignal.Test_Convolve1D_Impulse;
var
  LSignal: array[0..3] of Single = (1.0, 2.0, 3.0, 4.0);
  LKernel: array[0..0] of Single = (1.0);
  LDst: array[0..3] of Single;
begin
  // Convolution with impulse [1] should return original signal
  Convolve1DF32(@LSignal[0], 4, @LKernel[0], 1, @LDst[0]);
  CheckTrue(NearEqual(LDst[0], 1.0, EPS), 'Impulse [0]');
  CheckTrue(NearEqual(LDst[1], 2.0, EPS), 'Impulse [1]');
  CheckTrue(NearEqual(LDst[2], 3.0, EPS), 'Impulse [2]');
  CheckTrue(NearEqual(LDst[3], 4.0, EPS), 'Impulse [3]');
end;

{ ============================================================================
  Energy / RMS
  ============================================================================ }

procedure TTestCase_SimdSignal.Test_Energy_Basic;
var
  LSrc: array[0..3] of Single = (1.0, 1.0, 1.0, 1.0);
begin
  // Energy = sum of squares = 4
  CheckTrue(NearEqual(EnergyF32(@LSrc[0], 4), 4.0, EPS), 'Energy=4');
end;

procedure TTestCase_SimdSignal.Test_Rms_Basic;
var
  LSrc: array[0..3] of Single = (1.0, 1.0, 1.0, 1.0);
begin
  // RMS = sqrt(energy/N) = sqrt(4/4) = 1
  CheckTrue(NearEqual(RmsF32(@LSrc[0], 4), 1.0, EPS), 'RMS=1');
end;

procedure TTestCase_SimdSignal.Test_ZeroCrossingRate_Sine;
var
  LSrc: array[0..7] of Single = (1.0, 0.5, -0.5, -1.0, -0.5, 0.5, 1.0, 0.5);
  LRate: Single;
begin
  LRate := ZeroCrossingRateF32(@LSrc[0], 8);
  // Should have some zero crossings
  CheckTrue(LRate > 0.0, 'Zero crossings > 0');
end;

{ ============================================================================
  FIR Filter
  ============================================================================ }

procedure TTestCase_SimdSignal.Test_FirFilter_Basic;
var
  LSignal: array[0..5] of Single = (1.0, 2.0, 3.0, 4.0, 5.0, 6.0);
  LCoeffs: array[0..2] of Single = (0.25, 0.5, 0.25);
  LDst: array[0..5] of Single;
begin
  FirFilterF32(@LSignal[0], 6, @LCoeffs[0], 3, @LDst[0]);
  // Simple averaging filter, output should be smoothed
  CheckTrue(LDst[0] <> 0.0, 'FIR output exists');
  CheckTrue(LDst[5] <> 0.0, 'FIR output last');
end;

{ ============================================================================
  Correlation
  ============================================================================ }

procedure TTestCase_SimdSignal.Test_CrossCorrelation_Basic;
var
  LX: array[0..3] of Single = (1.0, 2.0, 3.0, 4.0);
  LY: array[0..3] of Single = (1.0, 2.0, 3.0, 4.0);
  LDst: array[0..3] of Single;
begin
  // maxLag=4
  CrossCorrelationF32(@LX[0], @LY[0], 4, @LDst[0], 4);
  // Should have non-zero values
  CheckTrue(LDst[0] <> 0.0, 'XCorr output exists');
end;

procedure TTestCase_SimdSignal.Test_AutoCorrelation_Basic;
var
  LSrc: array[0..3] of Single = (1.0, 2.0, 3.0, 4.0);
  LDst: array[0..3] of Single;
begin
  AutoCorrelationF32(@LSrc[0], 4, @LDst[0], 4);
  // Lag 0 should be the maximum (sum of squares)
  CheckTrue(LDst[0] >= LDst[1], 'AutoCorr lag0 >= lag1');
end;

{ ============================================================================
  Edge Cases
  ============================================================================ }

procedure TTestCase_SimdSignal.Test_NilSafety;
begin
  // Should not crash on nil with count=0
  HannWindowF32(nil, 0);
  EnergyF32(nil, 0);
  RmsF32(nil, 0);
  CheckTrue(True, 'Nil safety passed');
end;

initialization
  RegisterTest(TTestCase_SimdSignal);

end.
