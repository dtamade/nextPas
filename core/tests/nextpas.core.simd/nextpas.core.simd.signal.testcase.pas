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
    procedure Test_FFT_ForwardInverse;
    procedure Test_FFT_DC_Component;
    procedure Test_RealFft_Basic;
    // P2 coverage
    procedure Test_ResampleLinear_Basic;
    procedure Test_PowerSpectrum_Basic;
    procedure Test_MagnitudeSpectrum_Basic;
    procedure Test_PowerToDecibel_Basic;
    procedure Test_PreEmphasis_Basic;
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
  LDst: array[0..3] of Single;
begin
  // Convolve1DF32 does "same" convolution with zero-padding
  // LHalf = 1, output: [1, 3, 5, 7]
  Convolve1DF32(@LSignal[0], 4, @LKernel[0], 2, @LDst[0]);
  CheckTrue(NearEqual(LDst[0], 1.0, EPS), 'Conv [0]');
  CheckTrue(NearEqual(LDst[1], 3.0, EPS), 'Conv [1]');
  CheckTrue(NearEqual(LDst[2], 5.0, EPS), 'Conv [2]');
  CheckTrue(NearEqual(LDst[3], 7.0, EPS), 'Conv [3]');
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
  FFT
  ============================================================================ }

procedure TTestCase_SimdSignal.Test_FFT_ForwardInverse;
var
  LOrig: array[0..3] of Single = (1.0, 2.0, 3.0, 4.0);
  LData: array[0..3] of TSimdComplexF32;
  I: Integer;
begin
  // Input: [1, 2, 3, 4] (real), imaginary = 0
  for I := 0 to 3 do
  begin
    LData[I].Re := LOrig[I];
    LData[I].Im := 0.0;
  end;
  // Forward FFT → Inverse FFT should recover original
  FftRadix2F32(@LData[0], 4, sfdForward);
  FftRadix2F32(@LData[0], 4, sfdInverse);
  for I := 0 to 3 do
    CheckTrue(NearEqual(LData[I].Re, LOrig[I], 0.1), 'FFT IFFT roundtrip');
end;

procedure TTestCase_SimdSignal.Test_FFT_DC_Component;
var
  LData: array[0..3] of TSimdComplexF32;
  I: Integer;
begin
  // Constant signal [3, 3, 3, 3] → DC component should be 3*4=12, others ~0
  for I := 0 to 3 do
  begin
    LData[I].Re := 3.0;
    LData[I].Im := 0.0;
  end;
  FftRadix2F32(@LData[0], 4, sfdForward);
  // DC bin (index 0) should contain sum of all samples
  CheckTrue(NearEqual(LData[0].Re, 12.0, 0.1), 'FFT DC = 12');
  // Other bins should be near zero
  CheckTrue(Abs(LData[1].Re) < 0.1, 'FFT bin1 Re ~ 0');
  CheckTrue(Abs(LData[1].Im) < 0.1, 'FFT bin1 Im ~ 0');
end;

{ ============================================================================
  RealFFT
  ============================================================================ }

procedure TTestCase_SimdSignal.Test_RealFft_Basic;
var
  LInput: array[0..3] of Single = (1.0, 2.0, 3.0, 4.0);
  LOutput: array[0..2] of TSimdComplexF32;  // N/2+1 complex outputs
begin
  RealFftF32(@LInput[0], @LOutput[0], 4);
  // DC component should be sum of all inputs = 10
  CheckTrue(NearEqual(LOutput[0].Re, 10.0, 0.1), 'RealFFT DC = 10');
  CheckTrue(NearEqual(LOutput[0].Im, 0.0, 0.1), 'RealFFT DC Im = 0');
  // Nyquist component (index N/2) should have Im = 0
  CheckTrue(NearEqual(LOutput[2].Im, 0.0, 0.1), 'RealFFT Nyquist Im = 0');
end;

{ ============================================================================
  P2 Coverage: Resample, PowerSpectrum, etc.
  ============================================================================ }

procedure TTestCase_SimdSignal.Test_ResampleLinear_Basic;
var
  LSrc: array[0..3] of Single = (1.0, 2.0, 3.0, 4.0);
  LDst: array[0..7] of Single;
begin
  // Upsample 4 → 8
  ResampleLinearF32(@LSrc[0], 4, @LDst[0], 8);
  // First and last should match
  CheckTrue(NearEqual(LDst[0], 1.0, EPS), 'Resample [0]');
  CheckTrue(NearEqual(LDst[7], 4.0, EPS), 'Resample [7]');
  // Output should be monotonically increasing
  CheckTrue(LDst[0] < LDst[4], 'Resample monotonic');
  CheckTrue(LDst[4] < LDst[7], 'Resample monotonic');
end;

procedure TTestCase_SimdSignal.Test_PowerSpectrum_Basic;
var
  LData: array[0..3] of TSimdComplexF32;
  LDst: array[0..3] of Single;
  I: Integer;
begin
  // Constant signal [1,1,1,1] → DC=4, others=0
  for I := 0 to 3 do
  begin
    LData[I].Re := 1.0;
    LData[I].Im := 0.0;
  end;
  FftRadix2F32(@LData[0], 4, sfdForward);
  PowerSpectrumF32(@LData[0], 4, @LDst[0]);
  // DC power = |4|^2 = 16
  CheckTrue(NearEqual(LDst[0], 16.0, 0.1), 'PowerSpectrum DC');
  // Other bins should be near zero
  CheckTrue(LDst[1] < 1.0, 'PowerSpectrum bin1');
end;

procedure TTestCase_SimdSignal.Test_MagnitudeSpectrum_Basic;
var
  LData: array[0..3] of TSimdComplexF32;
  LDst: array[0..3] of Single;
  I: Integer;
begin
  // Constant signal [1,1,1,1] → DC=4, others=0
  for I := 0 to 3 do
  begin
    LData[I].Re := 1.0;
    LData[I].Im := 0.0;
  end;
  FftRadix2F32(@LData[0], 4, sfdForward);
  MagnitudeSpectrumF32(@LData[0], 4, @LDst[0]);
  // DC magnitude = |4| = 4
  CheckTrue(NearEqual(LDst[0], 4.0, 0.1), 'MagnitudeSpectrum DC');
end;

procedure TTestCase_SimdSignal.Test_PowerToDecibel_Basic;
var
  LSrc: array[0..3] of Single = (1.0, 10.0, 100.0, 1000.0);
  LDst: array[0..3] of Single;
begin
  PowerToDecibelF32(@LSrc[0], @LDst[0], 4);
  // 10*log10(1) = 0 dB
  CheckTrue(NearEqual(LDst[0], 0.0, 0.1), 'PowerToDb 1');
  // 10*log10(10) ≈ 10 dB
  CheckTrue(NearEqual(LDst[1], 10.0, 0.1), 'PowerToDb 10');
  // 10*log10(100) ≈ 20 dB
  CheckTrue(NearEqual(LDst[2], 20.0, 0.1), 'PowerToDb 100');
end;

procedure TTestCase_SimdSignal.Test_PreEmphasis_Basic;
var
  LSrc: array[0..3] of Single = (1.0, 2.0, 3.0, 4.0);
  LDst: array[0..3] of Single;
begin
  // coeff=0.97: dst[i] = src[i] - 0.97 * src[i-1]
  PreEmphasisF32(@LSrc[0], @LDst[0], 4, 0.97);
  // dst[0] = src[0] = 1.0 (no previous)
  CheckTrue(NearEqual(LDst[0], 1.0, EPS), 'PreEmphasis [0]');
  // dst[1] = 2 - 0.97*1 = 1.03
  CheckTrue(NearEqual(LDst[1], 1.03, 0.01), 'PreEmphasis [1]');
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
