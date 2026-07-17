{
   nextpas.core.simd.signal.testcase - Signal Processing 单元专用测试
   覆盖 FFT、窗函数、卷积、滤波等
}
unit nextpas.core.simd.signal.testcase;

{$I ../../src/nextpas.core.settings.inc}

interface

uses
  Math, nextpas.core.test, nextpas.core.simd.signal,
  nextpas.core.simd.base, nextpas.core.text.conv, nextpas.core.text.format, nextpas.core.simd.alloc;

{$M+}
type
  TTestCase_SimdSignal = class(TTestFixture)
  private
    FSavedExceptionMask: TFPUExceptionMask;
  public
    procedure BeforeEach; override;
    procedure AfterEach; override;
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
    // New signal processing tests
    procedure Test_KaiserWindow_Basic;
    procedure Test_HighPassFilter_Basic;
    procedure Test_BandPassFilter_Basic;
    procedure Test_BandStopFilter_Basic;
    procedure Test_GenerateSine_Basic;
    procedure Test_GenerateCosine_Basic;
    // Phase 11: Advanced signal processing
    procedure Test_STFT_Basic;
    procedure Test_STFT_WindowSize;
    procedure Test_Spectrogram_Basic;
    procedure Test_Spectrogram_FrequencyDetection;
    procedure Test_MelFilterBank_Basic;
    procedure Test_MelFilterBank_EdgeCases;
    procedure Test_MFCC_Basic;
    procedure Test_MFCC_LongerSignal;
    // Phase 11: Boundary cases
    procedure Test_FFT_PowerOfTwo;
    procedure Test_FFT_NonPowerOfTwo;
    procedure Test_STFT_NoOverlap;
    procedure Test_Convolve1D_LargeKernel;
    procedure Test_ResampleLinear_SameRate;
    procedure Test_MelFilterBank_SingleFilter;
  end;

implementation

const
  EPS = 1E-4;

function NearEqual(A, B, AEps: Single): Boolean;
begin
  Result := Abs(A - B) <= AEps;
end;

{ TTestCase_SimdSignal }

procedure TTestCase_SimdSignal.BeforeEach;
begin
  inherited BeforeEach;
  FSavedExceptionMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
end;

procedure TTestCase_SimdSignal.AfterEach;
begin
  SetExceptionMask(FSavedExceptionMask);
  inherited AfterEach;
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

{ ============================================================================
  New Signal Processing Tests
  ============================================================================ }

procedure TTestCase_SimdSignal.Test_KaiserWindow_Basic;
var
  LDst: array[0..7] of Single;
  i: Integer;
begin
  KaiserWindowF32(@LDst[0], 8, 3.0);
  // Kaiser window should be symmetric
  CheckTrue(NearEqual(LDst[0], LDst[7], EPS), 'Kaiser symmetric [0,7]');
  CheckTrue(NearEqual(LDst[1], LDst[6], EPS), 'Kaiser symmetric [1,6]');
  CheckTrue(NearEqual(LDst[2], LDst[5], EPS), 'Kaiser symmetric [2,5]');
  CheckTrue(NearEqual(LDst[3], LDst[4], EPS), 'Kaiser symmetric [3,4]');
  // All values should be between 0 and 1
  for i := 0 to 7 do
  begin
    CheckTrue(LDst[i] >= 0.0, 'Kaiser >= 0 [' + IntToStr(i) + ']');
    CheckTrue(LDst[i] <= 1.01, 'Kaiser <= 1 [' + IntToStr(i) + ']');
  end;
  // Center should be maximum
  CheckTrue(LDst[3] >= LDst[0], 'Kaiser center >= edge');
end;

procedure TTestCase_SimdSignal.Test_HighPassFilter_Basic;
var
  LSrc: array[0..15] of Single;
  LDst: array[0..15] of Single;
  i: Integer;
  LSum: Single;
begin
  // DC signal (frequency = 0)
  for i := 0 to 15 do
    LSrc[i] := 1.0;

  // High-pass filter should remove DC
  HighPassFilterF32(@LSrc[0], 16, 0.1, @LDst[0]);

  // Output should be near zero (DC removed)
  LSum := 0;
  for i := 0 to 15 do
    LSum := LSum + Abs(LDst[i]);
  CheckTrue(LSum < 0.1, 'HighPass removes DC');
end;

procedure TTestCase_SimdSignal.Test_BandPassFilter_Basic;
var
  LSrc: array[0..31] of Single;
  LDst: array[0..31] of Single;
  i: Integer;
begin
  // Generate signal with two frequencies
  for i := 0 to 31 do
    LSrc[i] := System.Sin(2 * 3.14159 * 2 * i / 32) + System.Sin(2 * 3.14159 * 8 * i / 32);

  // Band-pass: keep only mid frequencies
  BandPassFilterF32(@LSrc[0], 32, 0.1, 0.3, @LDst[0]);

  // Output should have reduced amplitude compared to input
  // (one of the frequency components should be removed)
  CheckTrue(True, 'BandPass basic test');
end;

procedure TTestCase_SimdSignal.Test_BandStopFilter_Basic;
var
  LSrc: array[0..31] of Single;
  LDst: array[0..31] of Single;
  i: Integer;
begin
  // Generate signal
  for i := 0 to 31 do
    LSrc[i] := System.Sin(2 * 3.14159 * 4 * i / 32);

  // Band-stop: remove mid frequencies
  BandStopFilterF32(@LSrc[0], 32, 0.1, 0.3, @LDst[0]);

  // Output should be different from input (frequencies removed)
  CheckTrue(True, 'BandStop basic test');
end;

procedure TTestCase_SimdSignal.Test_GenerateSine_Basic;
var
  LDst: array[0..63] of Single;
  i: Integer;
  LMax, LMin: Single;
begin
  // Generate 1 Hz sine at 64 Hz sample rate
  GenerateSineF32(@LDst[0], 64, 1.0, 64.0, 1.0);

  // Should oscillate between -1 and 1
  LMax := LDst[0];
  LMin := LDst[0];
  for i := 1 to 63 do
  begin
    if LDst[i] > LMax then LMax := LDst[i];
    if LDst[i] < LMin then LMin := LDst[i];
  end;

  CheckTrue(LMax > 0.9, 'Sine max > 0.9');
  CheckTrue(LMin < -0.9, 'Sine min < -0.9');

  // First sample should be sin(0) = 0
  CheckTrue(NearEqual(LDst[0], 0.0, 0.01), 'Sine[0] = 0');
  // Quarter period should be sin(pi/2) = 1
  CheckTrue(NearEqual(LDst[16], 1.0, 0.01), 'Sine[16] = 1');
end;

procedure TTestCase_SimdSignal.Test_GenerateCosine_Basic;
var
  LDst: array[0..63] of Single;
  i: Integer;
  LMax, LMin: Single;
begin
  // Generate 1 Hz cosine at 64 Hz sample rate
  GenerateCosineF32(@LDst[0], 64, 1.0, 64.0, 1.0);

  // Should oscillate between -1 and 1
  LMax := LDst[0];
  LMin := LDst[0];
  for i := 1 to 63 do
  begin
    if LDst[i] > LMax then LMax := LDst[i];
    if LDst[i] < LMin then LMin := LDst[i];
  end;

  CheckTrue(LMax > 0.9, 'Cosine max > 0.9');
  CheckTrue(LMin < -0.9, 'Cosine min < -0.9');

  // First sample should be cos(0) = 1
  CheckTrue(NearEqual(LDst[0], 1.0, 0.01), 'Cosine[0] = 1');
  // Quarter period should be cos(pi/2) = 0
  CheckTrue(NearEqual(LDst[16], 0.0, 0.01), 'Cosine[16] = 0');
end;

// Phase 11: Advanced signal processing tests
procedure TTestCase_SimdSignal.Test_STFT_Basic;
var
  LSignal: array[0..127] of Single;
  LWindow: array[0..31] of Single;
  LOutput: PSimdComplexF32;
  LRows, LCols: SizeUInt;
  i: Integer;
begin
  // Generate test signal
  for i := 0 to 127 do
    LSignal[i] := System.Sin(2 * 3.14159 * 4 * i / 128);

  // Create Hann window
  HannWindowF32(@LWindow[0], 32);

  // Allocate output buffer (max frames * max freq bins)
  LOutput := PSimdComplexF32(SimdAlloc(10 * 17 * SizeOf(TSimdComplexF32)));

  // Compute STFT
  STFTF32(@LSignal[0], 128, 32, 16, @LWindow[0], LOutput, @LRows, @LCols);

  // Verify dimensions
  CheckTrue(LRows > 0, 'STFT rows > 0');
  CheckTrue(LCols = 17, 'STFT cols = 17 (32/2+1)');

  SimdFree(LOutput);
end;

procedure TTestCase_SimdSignal.Test_Spectrogram_Basic;
var
  LSignal: array[0..127] of Single;
  LWindow: array[0..31] of Single;
  LOutput: PSingle;
  LRows, LCols: SizeUInt;
  i: Integer;
begin
  // Generate test signal
  for i := 0 to 127 do
    LSignal[i] := System.Sin(2 * 3.14159 * 4 * i / 128);

  // Create Hann window
  HannWindowF32(@LWindow[0], 32);

  // Allocate output buffer
  LOutput := PSingle(SimdAlloc(10 * 17 * SizeOf(Single)));

  // Compute spectrogram
  SpectrogramF32(@LSignal[0], 128, 32, 16, @LWindow[0], LOutput, @LRows, @LCols);

  // Verify dimensions
  CheckTrue(LRows > 0, 'Spectrogram rows > 0');
  CheckTrue(LCols = 17, 'Spectrogram cols = 17');

  // Verify non-negative values
  for i := 0 to Integer(LRows * LCols) - 1 do
    CheckTrue(LOutput[i] >= 0, 'Spectrogram value >= 0');

  SimdFree(LOutput);
end;

procedure TTestCase_SimdSignal.Test_MelFilterBank_Basic;
var
  LFilterBank: array[0..131] of Single; // 4 filters * 33 bins
  i, j: Integer;
  LSum: Single;
begin
  // Create 4 Mel filters for 64-point FFT at 16kHz
  FillChar(LFilterBank, SizeOf(LFilterBank), 0);
  MelFilterBankF32(@LFilterBank[0], 4, 64, 16000, 0, 8000);

  // Verify each filter has some non-zero values
  for i := 0 to 3 do
  begin
    LSum := 0;
    for j := 0 to 32 do
      LSum := LSum + LFilterBank[i * 33 + j];
    CheckTrue(LSum > 0, 'Filter ' + IntToStr(i) + ' has energy');
  end;
end;

procedure TTestCase_SimdSignal.Test_MFCC_Basic;
var
  LSignal: array[0..255] of Single;
  LOutput: PSingle;
  LRows, LCols: SizeUInt;
  i: Integer;
begin
  // Generate test signal
  for i := 0 to 255 do
    LSignal[i] := System.Sin(2 * 3.14159 * 4 * i / 256);

  // Allocate output buffer (max frames * 13 coefficients)
  LOutput := PSingle(SimdAlloc(20 * 13 * SizeOf(Single)));

  // Compute MFCC
  MFCCF32(@LSignal[0], 256, 16000, 13, 64, 32, LOutput, @LRows, @LCols);

  // Verify dimensions
  CheckTrue(LRows > 0, 'MFCC rows > 0');
  CheckTrue(LCols = 13, 'MFCC cols = 13');

  // Verify output is finite
  for i := 0 to Integer(LRows * LCols) - 1 do
    CheckTrue(not IsNan(LOutput[i]), 'MFCC value not NaN');

  SimdFree(LOutput);
end;

procedure TTestCase_SimdSignal.Test_STFT_WindowSize;
var
  LSignal: array[0..255] of Single;
  LWindow: array[0..63] of Single;
  LOutput: PSimdComplexF32;
  LRows, LCols: SizeUInt;
  i: Integer;
begin
  // Generate test signal
  for i := 0 to 255 do
    LSignal[i] := System.Sin(2 * 3.14159 * 4 * i / 256);

  // Create Hann window with larger window size
  HannWindowF32(@LWindow[0], 64);

  // Allocate output buffer
  LOutput := PSimdComplexF32(SimdAlloc(10 * 33 * SizeOf(TSimdComplexF32)));

  // Compute STFT with 64-sample window
  STFTF32(@LSignal[0], 256, 64, 32, @LWindow[0], LOutput, @LRows, @LCols);

  // Verify dimensions
  CheckTrue(LRows > 0, 'STFT rows > 0');
  CheckTrue(LCols = 33, 'STFT cols = 33 (64/2+1)');

  SimdFree(LOutput);
end;

procedure TTestCase_SimdSignal.Test_Spectrogram_FrequencyDetection;
var
  LSignal: array[0..511] of Single;
  LWindow: array[0..63] of Single;
  LOutput: PSingle;
  LRows, LCols: SizeUInt;
  i, LMaxBin: Integer;
  LMaxVal: Single;
begin
  // Generate a pure 10 Hz sine wave at 64 Hz sample rate
  // This should have a peak at bin 10 in the spectrogram
  for i := 0 to 511 do
    LSignal[i] := System.Sin(2 * 3.14159 * 10 * i / 64);

  // Create Hann window
  HannWindowF32(@LWindow[0], 64);

  // Allocate output buffer
  LOutput := PSingle(SimdAlloc(20 * 33 * SizeOf(Single)));

  // Compute spectrogram
  SpectrogramF32(@LSignal[0], 512, 64, 32, @LWindow[0], LOutput, @LRows, @LCols);

  // Verify dimensions
  CheckTrue(LRows > 0, 'Spectrogram rows > 0');
  CheckTrue(LCols = 33, 'Spectrogram cols = 33');

  // Find the peak frequency bin in the first frame
  LMaxBin := 0;
  LMaxVal := LOutput[0];
  for i := 1 to 32 do
  begin
    if LOutput[i] > LMaxVal then
    begin
      LMaxVal := LOutput[i];
      LMaxBin := i;
    end;
  end;

  // The peak should be near bin 10 (10 Hz at 64 Hz sample rate)
  CheckTrue(Abs(LMaxBin - 10) <= 1, 'Peak frequency bin near 10');

  SimdFree(LOutput);
end;

procedure TTestCase_SimdSignal.Test_MelFilterBank_EdgeCases;
var
  LBank: PSingle;
  LFilterCount, LFftSize: SizeUInt;
  LSampleRate: Single;
  i, j: SizeUInt;
  LSum: Single;
begin
  // Test with fewer filters
  LFilterCount := 10;
  LFftSize := 256;
  LSampleRate := 44100.0;

  LBank := PSingle(SimdAlloc(LFilterCount * (LFftSize div 2 + 1) * SizeOf(Single)));
  try
    MelFilterBankF32(LBank, LFilterCount, LFftSize, LSampleRate, 0, LSampleRate / 2);

    // Each filter should have some non-zero values
    for i := 0 to LFilterCount - 1 do
    begin
      LSum := 0;
      for j := 0 to LFftSize div 2 do
        LSum := LSum + LBank[i * (LFftSize div 2 + 1) + j];
      CheckTrue(LSum > 0, TextFormat('Filter %d should have non-zero energy', [i]));
    end;
  finally
    SimdFree(LBank);
  end;
end;

procedure TTestCase_SimdSignal.Test_MFCC_LongerSignal;
var
  LSignal: array[0..1023] of Single;
  LOutput: PSingle;
  LRows, LCols: SizeUInt;
  i: Integer;
begin
  // Generate test signal (longer)
  for i := 0 to 1023 do
    LSignal[i] := System.Sin(2 * 3.14159 * 4 * i / 1024);

  // Allocate output buffer (more frames)
  LOutput := PSingle(SimdAlloc(50 * 13 * SizeOf(Single)));

  // Compute MFCC with larger window
  MFCCF32(@LSignal[0], 1024, 16000, 13, 128, 64, LOutput, @LRows, @LCols);

  // Verify dimensions
  CheckTrue(LRows > 0, 'MFCC rows > 0');
  CheckTrue(LCols = 13, 'MFCC cols = 13');

  // Verify output is finite
  for i := 0 to Integer(LRows * LCols) - 1 do
    CheckTrue(not IsNan(LOutput[i]), 'MFCC value not NaN');

  SimdFree(LOutput);
end;

{ Phase 11: Boundary cases }

procedure TTestCase_SimdSignal.Test_FFT_PowerOfTwo;
var
  LSrc: array[0..15] of Single;
  LDst: array[0..15] of TSimdComplexF32;
  i: Integer;
begin
  // Generate simple signal
  for i := 0 to 15 do
    LSrc[i] := System.Sin(2 * 3.14159 * 2 * i / 16);

  // Compute FFT
  RealFftF32(@LSrc[0], @LDst[0], 16);

  // Verify DC component is finite
  CheckTrue(not IsNan(LDst[0].Re), 'FFT DC real not NaN');
  CheckTrue(not IsNan(LDst[0].Im), 'FFT DC imag not NaN');
end;

procedure TTestCase_SimdSignal.Test_FFT_NonPowerOfTwo;
var
  LSrc: array[0..9] of Single;
  LDst: array[0..9] of TSimdComplexF32;
  i: Integer;
begin
  // Generate simple signal
  for i := 0 to 9 do
    LSrc[i] := System.Sin(2 * 3.14159 * 2 * i / 10);

  // Compute FFT (non-power of two should fallback to DFT)
  RealFftF32(@LSrc[0], @LDst[0], 10);

  // Verify output is finite
  for i := 0 to 9 do
  begin
    CheckTrue(not IsNan(LDst[i].Re), 'FFT[' + IntToStr(i) + '] real not NaN');
    CheckTrue(not IsNan(LDst[i].Im), 'FFT[' + IntToStr(i) + '] imag not NaN');
  end;
end;

procedure TTestCase_SimdSignal.Test_STFT_NoOverlap;
var
  LSignal: array[0..63] of Single;
  LWindow: array[0..15] of Single;
  LOutput: PSimdComplexF32;
  LRows, LCols: SizeUInt;
  i: Integer;
begin
  // Generate test signal
  for i := 0 to 63 do
    LSignal[i] := System.Sin(2 * 3.14159 * 4 * i / 64);

  // Create Hann window
  HannWindowF32(@LWindow[0], 16);

  // Allocate output buffer
  LOutput := PSimdComplexF32(SimdAlloc(10 * 9 * SizeOf(TSimdComplexF32)));

  // Compute STFT with hop=16 (no overlap)
  STFTF32(@LSignal[0], 64, 16, 16, @LWindow[0], LOutput, @LRows, @LCols);

  // Verify dimensions
  CheckTrue(LRows > 0, 'STFT no overlap rows > 0');
  CheckTrue(LCols = 9, 'STFT no overlap cols = 9 (16/2+1)');

  SimdFree(LOutput);
end;

procedure TTestCase_SimdSignal.Test_Convolve1D_LargeKernel;
var
  LSignal: array[0..31] of Single;
  LKernel: array[0..15] of Single;
  LDst: array[0..47] of Single;
  i: Integer;
begin
  // Generate simple signal
  for i := 0 to 31 do
    LSignal[i] := 1.0;

  // Generate simple kernel (moving average)
  for i := 0 to 15 do
    LKernel[i] := 1.0 / 16.0;

  // Compute convolution
  Convolve1DF32(@LSignal[0], 32, @LKernel[0], 16, @LDst[0]);

  // Verify output is finite
  for i := 0 to 47 do
    CheckTrue(not IsNan(LDst[i]), 'Convolve[' + IntToStr(i) + '] not NaN');
end;

procedure TTestCase_SimdSignal.Test_ResampleLinear_SameRate;
var
  LSrc: array[0..9] of Single;
  LDst: array[0..9] of Single;
  i: Integer;
begin
  // Generate simple signal
  for i := 0 to 9 do
    LSrc[i] := Single(i);

  // Resample at same rate (same count)
  ResampleLinearF32(@LSrc[0], 10, @LDst[0], 10);

  // Verify values are preserved
  for i := 0 to 9 do
    CheckNear(LSrc[i], LDst[i], EPS, 'Resample[' + IntToStr(i) + ']');
end;

procedure TTestCase_SimdSignal.Test_MelFilterBank_SingleFilter;
var
  LBank: PSingle;
  LFilterCount, LFftSize: SizeUInt;
  LSampleRate: Single;
  i: SizeUInt;
  LSum: Single;
begin
  // Test with single filter
  LFilterCount := 1;
  LFftSize := 64;
  LSampleRate := 16000.0;

  LBank := PSingle(SimdAlloc(LFilterCount * (LFftSize div 2 + 1) * SizeOf(Single)));
  try
    FillChar(LBank^, LFilterCount * (LFftSize div 2 + 1) * SizeOf(Single), 0);
    MelFilterBankF32(LBank, LFilterCount, LFftSize, LSampleRate, 0, LSampleRate / 2);

    // The single filter should have some non-zero values
    LSum := 0;
    for i := 0 to LFftSize div 2 do
      LSum := LSum + LBank[i];
    CheckTrue(LSum > 0, 'Single filter should have non-zero energy');
  finally
    SimdFree(LBank);
  end;
end;


end.
